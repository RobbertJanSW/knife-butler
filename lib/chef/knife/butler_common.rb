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

  def files_send(path_src, path_dest, butler_data)
    if communicator_type == 'winrm'
      require 'chef/knife/winops_bootstrap_windows_winrm'
      Chef::Knife::BootstrapWindowsWinRM.load_deps

      opts = {
        endpoint: "http://#{butler_data['test_config']['driver']['customize']['pf_ip_address']}:#{butler_data['communicator_exposed_port']}/wsman",
        user: 'Administrator',
        password: butler_data['server_password']
      }
      connection = WinRM::Connection.new(opts)
      file_manager = WinRM::FS::FileManager.new(connection)
      file_manager.upload('butler', "C:\\Programdata\\")
    else
      require 'net/scp'

      Net::SCP.upload!(butler_data['test_config']['driver']['customize']['pf_ip_address'], 'Administrator',
        path_src, path_dest,
        :password => butler_data['server_password'])

    end
  end
end
