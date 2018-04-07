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
    end

    banner "knife butler prepare"

    def run
      # Get config
      test_config = YAML.load_file('.kitchen.ci.yml')
      puts "CLOUDSTACK HOST: #{test_config['driver']['customize']['CLOUDSTACK_HOST']}"
      puts "CLOUDSTACK NETWORK_NAME: #{test_config['driver']['customize']['NETWORK_NAME']}"

    end

  end # class
end
