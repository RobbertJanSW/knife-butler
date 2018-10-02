module ButlerCommon
  def communicator_type(test_config)
    if test_config['platforms'].first['driver_config']['communicator']
      communicator_type = test_config['platforms'].first['driver_config']['communicator']
    else
      communicator_type = 'ssh'
    end
    communicator_type
  end

  def default_communicator_port(communicator_type_arg)
    if communicator_type_arg == 'winrm'
      '5985'
    elsif communicator_type_arg == 'ssh'
      '22'
    end
  end
end
