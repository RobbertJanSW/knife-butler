#
# Author:: Robbert-Jan Sperna Weiland (<rspernaweiland@schubergphilis.com>)
#

require 'chef/knife'
require 'json'

module KnifeButler
  class ButlerPrepare < Chef::Knife

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
      butler_data['server_name'] = "butler-#{str_random}"
      str_random = (0...4).map { [rand(10)] }.join
      butler_data['communicator_exposed_port'] = str_random
      str_random = (0...4).map { [rand(10)] }.join
      File.open('.butler.yml', 'w') {|f| f.write butler_data.to_yaml } #Store

      # Create VM
      server_create = Knifecosmic::CosmicServerCreate.new

      server_create.name_args = [butler_data['server_name']]
      server_create.config[:cosmic_networks] = [test_config['driver']['customize']['network_name']]
      server_create.config[:cosmic_template] = test_config['platforms'].first['driver_config']['box']
      server_create.config[:bootstrap] = false
      server_create.config[:public_ip] = false
      server_create.config[:cosmic_service] = test_config['driver']['customize']['service_offering_name']
      #server_create.config[:ipfwd_rules] = "#{butler_data['communicator_exposed_port']}:5985:TCP"
      server_create.config[:cosmic_password] = true
      server_create.config[:cosmic_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      server_create.config[:cosmic_api_key] = test_config['driver']['customize']['api_key']
      server_create.config[:cosmic_secret_key] = test_config['driver']['customize']['secret_key']
      puts "Creating VM..."
      server_create.run
      server_details = server_create.server
      puts "Done!...details:"
      puts server_details
      puts "IP OF SERVER: #{server_details['public_ip']}"
      puts "End of detalis"
      butler_data['server_ip'] = server_details['public_ip']
      butler_data['server_password'] = server_details['passwordenabled'] ? server_details['password'] : test_config['driver']['customize']['vm_password']
      File.open('.butler.yml', 'w') {|f| f.write butler_data.to_yaml } #Store

      # Wait for the VM to settle into existance
      sleep(5)

      # Create communicator forwardrule
      forwardingrule_create = Knifecosmic::CosmicForwardruleCreate.new

      forwardingrule_create.name_args = [butler_data['server_name'], "#{butler_data['communicator_exposed_port']}:5985:TCP"]
      forwardingrule_create.config[:vrip] = test_config['driver']['customize']['pf_ip_address']
      forwardingrule_create.config[:cosmic_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      forwardingrule_create.config[:cosmic_api_key] = test_config['driver']['customize']['api_key']
      forwardingrule_create.config[:cosmic_secret_key] = test_config['driver']['customize']['secret_key']
      puts "Creating forwarding rule..."
      forwardingrule_details = forwardingrule_create.run
      puts "Done!"

      # Firewall rule for communicator
      firewall_rule = Knifecosmic::CosmicFirewallruleCreate.new
      firewall_rule.config[:cosmic_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      firewall_rule.config[:cosmic_api_key] = test_config['driver']['customize']['api_key']
      firewall_rule.config[:cosmic_secret_key] = test_config['driver']['customize']['secret_key']
      firewall_rule.name_args = [butler_data['server_name']]
      test_config['driver']['customize']['pf_trusted_networks'].split(",").each do |cidr|
        firewall_rule.name_args.push("5985:5985:TCP:#{cidr}")
      end
      firewall_rule.config[:public_ip] = test_config['driver']['customize']['pf_ip_address']
      firewall_rule.run

      # Wait for communicator to become responsive:
      puts "Waiting for communicator port......"
      wait_for_port_open(test_config['driver']['customize']['pf_ip_address'], butler_data['communicator_exposed_port'])
      puts "Communicator available!"
      sleep(2)
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
