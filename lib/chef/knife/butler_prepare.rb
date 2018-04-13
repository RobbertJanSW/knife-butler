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
      # Depend on knife-cloudstack:
      require 'chef/knife/cs_server_create'
      Chef::KnifeCloudstack::CsServerCreate.load_deps
      Chef::KnifeCloudstack::CsForwardruleCreate.load_deps
      require 'yaml'
      require "erb"
      require 'socket'
      require 'timeout'
    end

    banner "knife butler prepare"

    def run
      test_config = config_fetch
      Chef::Log.debug("CLOUDSTACK HOST: #{test_config['driver']['customize']['host']}")
      Chef::Log.debug("CLOUDSTACK NETWORK_NAME: #{test_config['driver']['customize']['network_name']}")

      # Create unique data for this test environment:
      o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
      str_random = (0...8).map { o[rand(o.length)] }.join
      butler_data = {}
      butler_data['server_name'] = "butler-#{str_random}"
      str_random = (0...4).map { [rand(10)] }.join
      butler_data['port_exposed_winrm'] = str_random
      str_random = (0...4).map { [rand(10)] }.join
      butler_data['port_exposed_zipdata'] = str_random
      File.open('.butler.yml', 'w') {|f| f.write butler_data.to_yaml } #Store

      # Create VM
      server_create = Chef::KnifeCloudstack::CsServerCreate.new

      server_create.name_args = [butler_data['server_name']]
      server_create.config[:cloudstack_networks] = [test_config['driver']['customize']['network_name']]
      server_create.config[:cloudstack_template] = test_config['platforms'].first['driver_config']['box']
      server_create.config[:bootstrap] = false
      server_create.config[:public_ip] = false
      server_create.config[:cloudstack_service] = test_config['driver']['customize']['service_offering_name']
      #server_create.config[:ipfwd_rules] = "#{butler_data['port_exposed_winrm']}:5985:TCP"
      server_create.config[:cloudstack_password] = true
      server_create.config[:cloudstack_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      server_create.config[:cloudstack_api_key] = test_config['driver']['customize']['api_key']
      server_create.config[:cloudstack_secret_key] = test_config['driver']['customize']['secret_key']
      puts "Creating VM..."
      server_create.run
      server_details = server_create.server
      puts "Done!...details:"
      puts server_details
      puts "IP OF SERVER: #{server_details['public_ip']}"
      puts "End of detalis"
      butler_data['server_ip'] = server_details['public_ip']
      butler_data['server_password'] = server_details['password']
      File.open('.butler.yml', 'w') {|f| f.write butler_data.to_yaml } #Store

      # Wait for the VM to settle into existance
      sleep(5)

      # Create WinRM forwardrule
      forwardingrule_create = Chef::KnifeCloudstack::CsForwardruleCreate.new

      forwardingrule_create.name_args = [butler_data['server_name'], "#{butler_data['port_exposed_winrm']}:5985:TCP"]
      forwardingrule_create.config[:vrip] = test_config['driver']['customize']['pf_ip_address']
      forwardingrule_create.config[:cloudstack_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      forwardingrule_create.config[:cloudstack_api_key] = test_config['driver']['customize']['api_key']
      forwardingrule_create.config[:cloudstack_secret_key] = test_config['driver']['customize']['secret_key']
      puts "Creating forwarding rule..."
      forwardingrule_details = forwardingrule_create.run
      puts "Done!"

      # Create Payload forwardrule
      forwardingrule_create = Chef::KnifeCloudstack::CsForwardruleCreate.new

      forwardingrule_create.name_args = [butler_data['server_name'], "#{butler_data['port_exposed_zipdata']}:5999:TCP"]
      forwardingrule_create.config[:vrip] = test_config['driver']['customize']['pf_ip_address']
      forwardingrule_create.config[:cloudstack_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      forwardingrule_create.config[:cloudstack_api_key] = test_config['driver']['customize']['api_key']
      forwardingrule_create.config[:cloudstack_secret_key] = test_config['driver']['customize']['secret_key']
      puts "Creating forwarding rule..."
      forwardingrule_details = forwardingrule_create.run
      puts "Done!"

      # Firewall rule for zipdata
      firewall_rule = Chef::Knife::KnifeCloudstack::CsFirewallruleCreate.new
      firewall_rule.config[:cloudstack_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
      firewall_rule.config[:cloudstack_api_key] = test_config['driver']['customize']['api_key']
      firewall_rule.config[:cloudstack_secret_key] = test_config['driver']['customize']['secret_key']
      firewall_rule.name_args = [butler_data['server_name']]
      test_config['driver']['customize']['pf_trusted_networks'].split(",").each do |cidr|
        firewall_rule.name_args.push("5999:5999:TCP:#{cidr}")
      end
      firewall_rule.name_args.push("5999:5999:TCP:0.0.0.0/0")
      firewall_rule.config[:public_ip] = test_config['driver']['customize']['pf_ip_address']
      firewall_rule.run

      # Wait for WinRM to become responsive:
      puts "Waiting for WinRM......"
      wait_for_port_open(test_config['driver']['customize']['pf_ip_address'], butler_data['port_exposed_winrm'])
      puts "WinRM available!"
      puts "Sleeping two minutes..."
      sleep(120)
      puts "Rechecking.."
      wait_for_port_open(test_config['driver']['customize']['pf_ip_address'], butler_data['port_exposed_winrm'])
      puts "WinRM available!"
    end

    def config_fetch
      # Get config
      test_config_raw = File.read('.kitchen.ci.yml')
      test_config_evaluated = ERB.new(test_config_raw).result( binding )
      YAML.load(test_config_evaluated)
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
