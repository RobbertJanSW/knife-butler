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
      require 'yaml'
      require "erb"
    end

    banner "knife butler prepare"

    def run
      # Get config
      test_config_raw = File.read('.kitchen.ci.yml')
      test_config_evaluated = ERB.new(test_config_raw).result( binding )
      puts "EVALUATED CONFIG: #{test_config_evaluated}"
      test_config = YAML.load(test_config_evaluated)
      puts "CLOUDSTACK HOST: #{test_config['driver']['customize']['host']}"
      puts "CLOUDSTACK NETWORK_NAME: #{test_config['driver']['customize']['network_name']}"

    end

  end # class
end
