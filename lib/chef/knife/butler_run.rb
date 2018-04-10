#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife'
require 'json'

module KnifeButler
  class ButlerRun < Chef::Knife

    deps do
      require 'chef/knife/bootstrap_windows_winrm'
      Chef::Knife::BootstrapWindowsWinrm.load_deps
      require 'yaml'
      require "erb"
    end

    banner "knife butler run"

    def run
      test_config = config_fetch
      butler_data = butler_data_fetch
      
      # Prepare chef-solo files
      # 
      exec ( "mkdir .\butler_bootstrap_data" )
      exec ( "echo dbskjhdbskj > .\butler_bootstrap_data\testfile" )

      # Bootstrap our VM with the desired runlist
      bootstrap = Chef::Knife::BootstrapWindowsWinrm.new

      bootstrap.name_args = [test_config['driver']['customize']['pf_ip_address']]
      bootstrap.config[:winrm_port] = butler_data['port_exposed']
      bootstrap.config[:winrm_password] = butler_data['server_password']
      bootstrap.config[:winrm_user] = 'Administrator'
      bootstrap.config[:chef_node_name] = butler_data['server_name']
      bootstrap.config[:chef_server] = false
      bootstrap.config[:payload_folder] = '.\butler_bootstrap_data'

      puts "Starting bootstrap.."
      bootstrap.run
      puts "Done!"
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
  end # class
end
