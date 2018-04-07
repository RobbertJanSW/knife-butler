#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife'
require 'json'

module KnifeButler
  class ButlerClean < Chef::Knife

    deps do
      require 'chef/knife/bootstrap'
      # Depend on knife-cloudstack:
      require 'chef/knife/cs_server_delete'
      Chef::KnifeCloudstack::CsServerDelete.load_deps
      require 'yaml'
      require "erb"
    end

    banner "knife butler clean"

    def run
      test_config = config_fetch
      butler_data = butler_data_fetch

      # Destroy VM
      server_delete = Chef::KnifeCloudstack::CsServerDelete.new

      server_delete.name_args = [butler_data['server_name']]
      server_delete.config[:cloudstack_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      server_delete.config[:cloudstack_api_key] = test_config['driver']['customize']['api_key']
      server_delete.config[:cloudstack_secret_key] = test_config['driver']['customize']['secret_key']
      puts "Deleting VM..."
      vm_delete_details = server_delete.run
      puts "Done!"

      # Wait for the VM do be deleted
      sleep(15)
      
      # Expunge!
      vm_delete_details = server_delete.run
    end

    def butler_data_fetch
      # Get config
      butler_data_raw = File.read('.butler.yml')
      YAML.load(butler_data_raw)
    end

    def config_fetch
      # Get config
      test_config_raw = File.read('.kitchen.ci.yml')
      test_config_evaluated = ERB.new(test_config_raw).result( binding )
      puts "EVALUATED CONFIG: #{test_config_evaluated}"
      YAML.load(test_config_evaluated)
    end
  end # class
end
