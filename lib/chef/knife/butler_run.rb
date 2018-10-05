#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife/butler_common'
require 'chef/knife'
require 'json'
require 'rubygems'

module KnifeButler
  class ButlerRun < Chef::Knife
    include ButlerCommon

    deps do
      require 'yaml'
      require 'erb'
      require 'socket'
      require 'winrm-fs'
    end

    banner "knife butler run"

    def run
      # test_config = config_fetch
      butler_data = butler_data_fetch

      # Prepare chef-solo files
      # 
      # exec ( "mkdir .\butler_bootstrap_data" )
      # exec ( "echo dbskjhdbskj > .\butler_bootstrap_data\testfile" )


      puts "Fetching windows butler runner file from gem path..."
      butler_runner_windows = Gem.find_files(File.join('chef', 'knife', 'resources', 'butler_runner_windows.ps1')).first
      butler_runner_windows_path = File.dirname(butler_runner_windows)
      puts "Done. Path: #{butler_runner_windows_path}"

      # Re-run bootstrap with new command (simply tailing butler run wrapper script logfile)
      # until that file is deleted, and then check exit_status of .butler exit status reporting file

      # Prepare ZIP with chef-solo run:
      puts "Building ZIP with cookbook data"
      berks_result = `bundle exec berks package`
      berks_zip = berks_result.split(' to ').last.chomp("\n")
      puts "ZIPFILE: #{berks_zip}"

      `tar -xvzf #{berks_zip}`

      `mkdir ./butler`
      `mv ./cookbooks ./butler/`
      `mkdir ./butler/checksums`
      `echo >> ./butler/checksums/dummy`
      `mkdir ./butler/cache`
      `echo >> ./butler/cache/dummy`
      `mkdir ./butler/backup`
      `echo >> ./butler/backup/dummy`
      `mkdir ./butler/data_bags`
      `echo >> ./butler/data_bags/dummy`
      `mkdir ./butler/environments`
      `echo >> ./butler/environments/dummy`
      `mkdir ./butler/nodes`
      `echo >> ./butler/nodes/dummy`
      `mkdir ./butler/roles`
      `echo >> ./butler/roles/dummy`

      # Push chef-solo.rb into the butler folder
      chef_solo_rb_path = Gem.find_files(File.join('chef', 'knife', 'resources', 'templates', 'chef-solo.rb')).first
      `cp #{chef_solo_rb_path} ./butler`

      # Push client.pem into the zip folder
      chef_client_pem = Gem.find_files(File.join('chef', 'knife', 'resources', 'client.pem')).first
      `cp #{chef_client_pem} ./butler`

      # Push cookbook folder to test VM
      sleep(1)
      puts "PUSHING FILES TO VM"

      if platform_family(butler_data) == 'windows'
        dest_path = "C:\\Programdata\\"
      else
        dest_path = "/tmp/"
      end
      files_send('butler', dest_path, butler_data)

      sleep(1)

      converge_runlist(butler_data)

      puts "Done!"
    end

    def folder_zip_recursive(zipfile, folder, subpath=nil)
      folder_list = subpath.nil? ? folder : File.join(folder, subpath)
      Dir.foreach(folder_list) do |item|
        next if item == '.' or item == '..'
        if File.file?(File.join(folder_list,item))
          internal_path = subpath.nil? ? item : File.join(subpath, item)
          zipfile.get_output_stream(internal_path) do |f|
            f.write(File.open(File.join(folder_list,item), 'rb').read)
          end
          # zipfile.add(internal_path, File.join(folder,item))
          #puts File.join(prefix,item)
        else
          forward_subpath = subpath.nil? ? item : File.join(subpath, item)
          folder_zip_recursive(zipfile, folder, forward_subpath)
        end
      end
    end

    def config_fetch
      # Get config
      test_config_raw = File.read('.kitchen.yml')
      test_config_evaluated = ERB.new(test_config_raw).result( binding )
      YAML.load(test_config_evaluated)
    end
    def butler_data_fetch
      # Get config
      butler_data_raw = File.read('.butler.yml')
      YAML.load(butler_data_raw)
    end
    def wait_for_port_open(ip, port)
      port_open = false
      while !port_open
        begin
          puts "TRYING PORT....."
          thr = Thread.new {
            s=TCPSocket.open(ip, port)
            s.close
          }
          sleep(2)
        rescue
          nil
        end
        if !thr.alive?
          puts "PORT IS OPEN!"
          port_open = true
          begin
            thr.exit
            while thr.status
              thr.exit
            end
          rescue
            nil
          end
        end
        thr.join
      end
    end

    def files_send(path_src, path_dest, butler_data)
      if communicator_type(butler_data['test_config']) == 'winrm'
        require 'chef/knife/winops_bootstrap_windows_winrm'
        Chef::Knife::BootstrapWindowsWinRM.load_deps
  
        opts = {
          endpoint: "http://#{butler_data['test_config']['driver']['customize']['pf_ip_address']}:#{butler_data['communicator_exposed_port']}/wsman",
          user: 'Administrator',
          password: butler_data['server_password']
        }
        connection = WinRM::Connection.new(opts)
        file_manager = WinRM::FS::FileManager.new(connection)
        file_manager.upload('butler', path_dest)
      elsif communicator_type(butler_data['test_config']) == 'ssh'
        require 'net/scp'

        puts "USING PASSWORD: #{butler_data['server_password']}"
        
        Net::SSH.start(butler_data['test_config']['driver']['customize']['pf_ip_address'],
          'root',
          :password => "#{butler_data['server_password']}",
          :port => butler_data['communicator_exposed_port']
        ) do |ssh|
          ssh.scp.upload! path_src, path_dest
        end

      end
    end

    def converge_runlist(butler_data)
      # Bootstrap our VM with the desired runlist
      if communicator_type(butler_data['test_config']) == 'winrm'
        puts "Configuring bootstrap call"
        bootstrap = Chef::Knife::BootstrapWindowsWinRM.new
  
        bootstrap.name_args = [butler_data['test_config']['driver']['customize']['pf_ip_address']]
        bootstrap.config[:winrm_port] = butler_data['communicator_exposed_port']
        bootstrap.config[:winrm_password] = butler_data['server_password']
        bootstrap.config[:winrm_user] = 'Administrator'
        bootstrap.config[:bootstrap_version] = butler_data['test_config']['provisioner']['require_chef_omnibus']
        bootstrap.config[:chef_node_name] = butler_data['server_name']
        bootstrap.config[:chef_server] = false
        bootstrap.config[:payload_folder] = butler_runner_windows_path
        repo_name=File.basename(Dir.pwd)
  
        runlist = butler_data['test_config']['suites'][0]['run_list'].join(",")
        bootstrap.config[:bootstrap_run_command] = "C:\\chef\\extra_files\\butler_runner_windows.ps1 #{repo_name} #{butler_data['test_config']['suites'][0]['attributes']['chef_environment']} \"#{runlist}\""
        bootstrap.config[:bootstrap_tail_file] = 'C:\chef\client.log'
        # bootstrap.config[:bootstrap_run_command] = 'get-childitem C:\chef\extra_files'

        puts "Starting bootstrap.."
        bootstrap.run
      elsif communicator_type(butler_data['test_config']) == 'ssh'
        # On Linux, we use bootstrap only to install the desired Chef version.
        puts "Configuring bootstrap call"
        bootstrap = Chef::Knife::Bootstrap.new

        bootstrap.name_args = [butler_data['test_config']['driver']['customize']['pf_ip_address']]
        bootstrap.config[:ssh_password] = butler_data['server_password']
        bootstrap.config[:bootstrap_version] = butler_data['test_config']['provisioner']['require_chef_omnibus']
        bootstrap.config[:chef_node_name] = butler_data['server_name']
        puts "Starting bootstrap.."
        bootstrap.run
        puts "Done"

        # Then, SSH into the box to kick off the Chef-zero run we want:
        # bla

      end
    end
  end # class
end
