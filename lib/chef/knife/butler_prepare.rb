#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife'
require 'chef/knife/butler_common'
require 'chef/knife/butler_clean'
require 'json'

module KnifeButler
  class ButlerPrepare < Chef::Knife
    include ButlerCommon

    deps do
      require 'chef/knife/bootstrap'
      Chef::Knife::Bootstrap.load_deps
      # Depend on knife-cosmic:
      require 'chef/knife/cosmic_server_create'
      Knifecosmic::CosmicServerCreate.load_deps
      Knifecosmic::CosmicForwardruleCreate.load_deps
      require 'yaml'
      require "erb"
      require 'socket'
      require 'timeout'
      KnifeButler::ButlerClean.load_deps
    end

    banner "knife butler prepare"

    def run
      test_config = config_fetch
      Chef::Log.debug("cosmic HOST: #{test_config['driver']['customize']['host']}")
      Chef::Log.debug("cosmic NETWORK_NAME: #{test_config['driver']['customize']['network_name']}")

      # Create unique data for this test environment:
      o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
      str_random = (0...8).map { o[rand(o.length)] }.join
      butler_data = {}
      butler_data['test_config'] = test_config
      butler_data['server_name'] = "butler-#{str_random}"
      str_random = (0...4).map { [rand(10)] }.join
      butler_data['communicator_exposed_port'] = str_random
      str_random = (0...4).map { [rand(10)] }.join
      File.open('.butler.yml', 'w') {|f| f.write butler_data.to_yaml } #Store

      puts "Building ZIP with cookbook data in seperate thread"
      berks_thread = Thread.new() {
        berks_result = `berks package`
        berks_zip = berks_result.split(' to ').last.chomp("\n")
      }

      # Create VM
      server_details = vm_prepare(butler_data)

      puts "Done!...details:"
      puts server_details
      puts "IP OF SERVER: #{server_details['public_ip']}"
      puts "End of detalis"
      butler_data['server_ip'] = server_details['public_ip']
      butler_data['server_password'] = server_details['passwordenabled'] ? server_details['password'] : butler_data['test_config']['driver']['customize']['vm_password']

      # Wait for the VM to settle into existance
      sleep(2)

      forwardingrule_details = vm_portforward(butler_data)

      firewallrules_ids = vm_firewallrule(butler_data)
      butler_data['firewallrules_ids'] = firewallrules_ids

      berks_zip=berks_thread.join.value
      puts berks_zip
      sleep(30)
      butler_data['berks_zip'] = berks_zip

      File.open('.butler.yml', 'w') {|f| f.write butler_data.to_yaml } #Store

      # Wait for communicator to become responsive:
      puts "Waiting for communicator port......"
      wait_for_port_open(butler_data['test_config']['driver']['customize']['pf_ip_address'], butler_data['communicator_exposed_port'])
      puts "Communicator available!"
      sleep(2)
    end

    def vm_firewallrule(data)
      # Firewall rule for communicator
      begin
        test_config = config_fetch
        communicator_port = default_communicator_port(communicator_type(test_config))

        firewall_rule = Knifecosmic::CosmicFirewallruleCreate.new
        firewall_rule.config[:cosmic_url] = "https://#{data['test_config']['driver']['customize']['host']}/client/api"
        firewall_rule.config[:cosmic_api_key] = data['test_config']['driver']['customize']['api_key']
        firewall_rule.config[:cosmic_secret_key] = data['test_config']['driver']['customize']['secret_key']
        firewall_rule.name_args = [data['server_name']]
        data['test_config']['driver']['customize']['pf_trusted_networks'].split(",").each do |cidr|
          firewall_rule.name_args.push("#{communicator_port}:#{communicator_port}:TCP:#{cidr}")
        end
        firewall_rule.config[:public_ip] = data['test_config']['driver']['customize']['pf_ip_address']
        firewall_rule.run

        firewall_result = firewall_rule.rules_created

        # This way makes sure if the last one fails, the other one gets cleaned up:
        firewallrules_ids = []
        firewall_result.each do |el|
          firewallrules_ids << el['networkacl']['id']
        end
        puts "IDs:"
        puts firewallrules_ids
      rescue Exception => e
        # cleanup
        File.open('.butler.yml', 'w') {|f| f.write data.to_yaml } #Store
        cleanup = KnifeButler::ButlerClean.new()
        cleanup.run
        puts "#{e.class}: #{e.message}"
        puts e.backtrace
        raise 'Failed'
      end

      firewallrules_ids
    end

    def vm_portforward(data)
      test_config = config_fetch

      # Create communicator forwardrule
      communicator_port = default_communicator_port(communicator_type(test_config))

      forwardingrule_create = Knifecosmic::CosmicForwardruleCreate.new

      forwardingrule_create.name_args = [data['server_name'], "#{data['communicator_exposed_port']}:#{communicator_port}:TCP"]
      forwardingrule_create.config[:vrip] = data['test_config']['driver']['customize']['pf_ip_address']
      forwardingrule_create.config[:cosmic_url] = "https://#{data['test_config']['driver']['customize']['host']}/client/api"
      forwardingrule_create.config[:cosmic_api_key] = data['test_config']['driver']['customize']['api_key']
      forwardingrule_create.config[:cosmic_secret_key] = data['test_config']['driver']['customize']['secret_key']
      puts "Creating forwarding rule..."
      forwardingrule_details = forwardingrule_create.run
      puts "Done!"

      forwardingrule_details
    end

    def vm_prepare(data)
      server_create = Knifecosmic::CosmicServerCreate.new
      server_create.name_args = [data['server_name']]
      server_create.config[:cosmic_networks] = [data['test_config']['driver']['customize']['network_name']]
      server_create.config[:cosmic_template] = data['test_config']['platforms'].first['driver_config']['box']
      server_create.config[:bootstrap] = false
      server_create.config[:public_ip] = false
      server_create.config[:cosmic_service] = data['test_config']['driver']['customize']['service_offering_name']
      server_create.config[:cosmic_password] = true
      server_create.config[:cosmic_url] = "https://#{data['test_config']['driver']['customize']['host']}/client/api"
      server_create.config[:cosmic_api_key] = data['test_config']['driver']['customize']['api_key']
      server_create.config[:cosmic_secret_key] = data['test_config']['driver']['customize']['secret_key']
      puts "Creating VM..."
      server_create.run
      server_details = server_create.server

      server_details
    end

    def config_fetch
      # Get config
      test_config_raw = File.read('.kitchen.yml')
      test_config_evaluated = ERB.new(test_config_raw).result( binding )
      YAML.load(test_config_evaluated)
    end
    def wait_for_port_open(ip, port)
      port_open = false
      while !port_open
        begin
          puts "TRYING PORT....."
          thr = Thread.new {
            begin
              s=TCPSocket.open(ip, port)
              s.close
            rescue
              sleep(3)
            end
            Thread.exit
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