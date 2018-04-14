#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife'
require 'json'
require 'rubygems'
require 'zip'

module KnifeButler
  class ButlerRun < Chef::Knife

    deps do
      require 'chef/knife/bootstrap_windows_winrm'
      Chef::Knife::BootstrapWindowsWinrm.load_deps
      require 'yaml'
      require 'erb'
      require 'socket'
    end

    banner "knife butler run"

    def run
      test_config = config_fetch
      butler_data = butler_data_fetch

      # Prepare chef-solo files
      # 
      # exec ( "mkdir .\butler_bootstrap_data" )
      # exec ( "echo dbskjhdbskj > .\butler_bootstrap_data\testfile" )


      puts "Fetching windows butler runner file from gem path..."
      butler_runner_windows = Gem.find_files(File.join('chef', 'knife', 'resources', 'butler_runner_windows.ps1')).first
      butler_runner_windows_path = File.dirname(butler_runner_windows)
      puts "Done. Path: #{butler_runner_windows_path}"


      # Bootstrap our VM with the desired runlist
      puts "Configuring bootstrap call"
      bootstrap = Chef::Knife::BootstrapWindowsWinrm.new

      bootstrap.name_args = [test_config['driver']['customize']['pf_ip_address']]
      bootstrap.config[:winrm_port] = butler_data['port_exposed_winrm']
      bootstrap.config[:winrm_password] = butler_data['server_password']
      bootstrap.config[:winrm_user] = 'Administrator'
      bootstrap.config[:chef_node_name] = butler_data['server_name']
      bootstrap.config[:chef_server] = false
      bootstrap.config[:payload_folder] = butler_runner_windows_path
      bootstrap.config[:bootstrap_run_command] = 'powershell.exe -file C:\chef\extra_files\butler_runner_windows.ps1'
      # bootstrap.config[:bootstrap_run_command] = 'get-childitem C:\chef\extra_files'

      puts "Starting bootstrap.."
      bootstrap.run
      puts "Done!"
      
      # Push ZIP (create it first) to VM over port 'port_exposed_zipdata'
      # Re-run bootstrap with new command (simply tailing butler run wrapper script logfile)
      # until that file is deleted, and then check exit_status of .butler exit status reporting file

      puts "Checking for open zipdata port #{test_config['driver']['customize']['pf_ip_address']} #{butler_data['port_exposed_zipdata']}...."
      wait_for_port_open(test_config['driver']['customize']['pf_ip_address'], butler_data['port_exposed_zipdata'])
      puts 'Available!!!'

      # Prepare ZIP with chef-solo run:
      puts "Building ZIP with cookbook data"
      berks_result = `berks package`
      berks_zip = berks_result.split(' to ').last.chomp("\n")
      puts "ZIPFILE: #{berks_zip}"

      `tar -xvzf #{berks_zip}`
      
      # Build normal zip from berls data
      folder = "."

      zipfile_name = "cookbooks.zip"

      Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
        folder_zip_recursive(zipfile, folder)
      end

      # Push file to test VM
      sleep(5)
      puts "PUSHING FILE TO VM"
      sock = TCPSocket.new(test_config['driver']['customize']['pf_ip_address'], butler_data['port_exposed_zipdata'])
      file = File.open(zipfile_name, "rb")
      while (zipfile_contents = file.read(2048)) do
        sock.write zipfile_contents
      end
      sock.close
      puts "DONE"

      
      puts "Done!"
      puts "Sleeping"
      sleep(3600)
    end

    def folder_zip_recursive(zipfile, folder, prefix='')
      if prefix == ''
        prefix = '.'
      end
      Dir.foreach(folder) do |item|
        next if item == '.' or item == '..'
        if File.file?(File.join(folder,item))
          zipfile.add(File.join(prefix,item), File.join(folder,item))
          #puts File.join(prefix,item)
        else
          folder_zip_recursive(zipfile, File.join(folder,item), File.join(prefix,item))
        end
      end
    end

    def config_fetch
      # Get config
      test_config_raw = File.read('.kitchen.ci.yml')
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
  end # class
end
