#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife'
require 'json'

module KnifeButler
  class ButlerClean < Chef::Knife

    deps do
      require 'chef/knife/bootstrap'
      # Depend on knife-cosmic:
      require 'chef/knife/cosmic_server_delete'
      require 'chef/knife/cosmic_firewallrule_delete'
      Knifecosmic::CosmicServerDelete.load_deps
      Knifecosmic::CosmicFirewallruleDelete.load_deps
      require 'yaml'
      require "erb"
    end

    banner "knife butler clean"

    def run
      # test_config = config_fetch
      butler_data = butler_data_fetch

      # Remove ACL rules
      butler_data['firewallrules_ids'].each do |firewallrule_id|
        firewallrule_delete = Knifecosmic::CosmicFirewallruleDelete.new
        firewallrule_delete.config[:cosmic_url] = "https://#{butler_data['test_config']['driver']['customize']['host']}/client/api"
        firewallrule_delete.config[:cosmic_api_key] = butler_data['test_config']['driver']['customize']['api_key']
        firewallrule_delete.config[:cosmic_secret_key] = butler_data['test_config']['driver']['customize']['secret_key']
        firewallrule_delete.name_args = [firewallrule_id]
        firewallrule_delete.run
      end

      # Destroy VM
      server_delete = Knifecosmic::CosmicServerDelete.new

      server_delete.name_args = [butler_data['server_name']]
      server_delete.config[:cosmic_url] = "https://#{butler_data['test_config']['driver']['customize']['host']}/client/api"
      server_delete.config[:cosmic_api_key] = butler_data['test_config']['driver']['customize']['api_key']
      server_delete.config[:cosmic_secret_key] = butler_data['test_config']['driver']['customize']['secret_key']
      server_delete.config[:yes] = true
      puts "Deleting VM..."
      begin
        vm_delete_details = server_delete.run
      rescue => ex
        puts "#{ex.backtrace}: #{ex.message} (#{ex.class})"
      end
      puts "Done!"

      # Wait for the VM do be deleted
      sleep(10)

      # Expunge!
      begin
        vm_delete_details = server_delete.run
      rescue
        nil
      end
      puts "Done!"
    end

    def butler_data_fetch
      # Get config
      butler_data_raw = File.read('.butler.yml')
      YAML.load(butler_data_raw)
    end

    def config_fetch
      # Get config
      test_config_raw = File.read('.kitchen.yml')
      test_config_evaluated = ERB.new(test_config_raw).result( binding )
      YAML.load(test_config_evaluated)
    end
  end # class
end
