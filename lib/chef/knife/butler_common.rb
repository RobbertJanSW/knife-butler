module ButlerCommon
  require 'chef/knife/cosmic_ostype_list'
  Knifecosmic::CosmicOstypeList.load_deps

  def default_communicator_port(communicator_type)
    if communicator_type == 'winrm'
      '5985'
    elsif communicator_type == 'ssh'
      '22'
    end
  end
end