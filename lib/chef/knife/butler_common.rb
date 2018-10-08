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

  def platform_family(butler_data)
    # Very dirty quicky
    if communicator_type(butler_data['test_config']) == 'winrm'
      'windows'
    else
      'linux'
    end
  end

  def command_run(command, butler_data)
    if communicator_type(butler_data['test_config']) == 'winrm'
      require 'winrm'

      winrm = Chef::Knife::Winrm.new
      puts "Running shell command #{command}"
      winrm.name_args = [ butler_data['test_config']['driver']['customize']['pf_ip_address'], command ]
      if butler_data['test_config']['driver']['customize']['vm_user'].nil?
        winrm.config[:winrm_user] = 'Administrator'
      else
        winrm.config[:winrm_user] = butler_data['test_config']['driver']['customize']['vm_user']
      end
      winrm.config[:winrm_password] = butler_data['server_password']
      winrm.config[:winrm_port] = butler_data['communicator_exposed_port']
      winrm.config[:suppress_auth_failure] = true
      winrm.config[:manual] = true
      winrm.run
    elsif communicator_type(butler_data['test_config']) == 'ssh'
      require 'net/ssh'

      Net::SSH.start(butler_data['test_config']['driver']['customize']['pf_ip_address'],
        'bootstrap',
        { password: "#{butler_data['server_password']}", port: butler_data['communicator_exposed_port'] }
      ) do |ssh|
        ssh.exec!(command) do |ch, stream, data|
          if stream == :stderr
            puts "ERROR: #{data}"
          else
            puts data
          end
        end
      end
    end
  end
end
