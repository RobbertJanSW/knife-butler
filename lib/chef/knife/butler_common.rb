module ButlerCommon
  require 'chef/knife/cosmic_ostype_list'
  Knifecosmic::CosmicOstypeList.load_deps

  def communicator_type(test_config)
    if test_config['platforms'].first['driver_config']['communicator']
      communicator_type = test_config['platforms'].first['driver_config']['communicator']
    else
      communicator_type = 'ssh'
    end
    communicator_type
  end

  def default_communicator_port(communicator_type)
    if communicator_type == 'winrm'
      '5985'
    elsif communicator_type == 'ssh'
      '22'
    end
  end
end
