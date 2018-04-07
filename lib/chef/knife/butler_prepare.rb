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
      test_config = config_fetch
      Chef::Log.debug("CLOUDSTACK HOST: #{test_config['driver']['customize']['host']}")
      Chef::Log.debug("CLOUDSTACK NETWORK_NAME: #{test_config['driver']['customize']['network_name']}")

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
