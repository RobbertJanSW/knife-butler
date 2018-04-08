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

      # Bootstrap our VM with the desired runlist
      bootstrap = Chef::Knife::BootstrapWindowsWinrm.new

      bootstrap.name_args = [butler_data['server_ip']]
      bootstrap.config[:winrm_port] = [butler_data['port_exposed']]
      bootstrap.config[:winrm_password] = [butler_data['password']]
      bootstrap.config[:winrm_transport] = true
      bootstrap.config[:winrm_user] = 'Administrator'

      puts "Starting bootstrap.."
      bootstrap
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
