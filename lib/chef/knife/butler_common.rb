module ButlerCommon
  require 'chef/knife/cosmic_ostype_list'
  Knifecosmic::CosmicOstypeList.load_deps

  def get_server_ostype(server_details, test_config)
    ostype_list = Knifecosmic::CosmicOstypeList.new

    ostype_list.config[:cosmic_url] = "https://#{test_config['driver']['customize']['host']}/client/api"
    ostype_list.config[:cosmic_api_key] = test_config['driver']['customize']['api_key']
    ostype_list.config[:cosmic_secret_key] = test_config['driver']['customize']['secret_key']
    list = ostype_list.run

    list.each do |item|
      if item['id'] == server_details['ostypeid']
        if item['description'].downcase.include? "windows"
          ostype = 'windows'
        else
          ostype = 'linux'
        end
      end
    end
    ostype
  end

  def default_communicator_for_ostype(os_type)
    if os_type == 'windows'
      'winrm'
    elsif os_type == 'linux'
      'ssh'
    end
  end

  def default_communicator_port(communicator_type)
    if communicator_type == 'winrm'
      '5985'
    elsif communicator_type == 'ssh'
      '22'
    end
  end
end