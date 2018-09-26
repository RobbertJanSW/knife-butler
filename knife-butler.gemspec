Gem::Specification.new do |s|
  s.name = %q{knife-butler}
  s.version = "0.0.1"
  s.date = %q{2018-04-07}
  s.authors = ['Robbert-Jan Sperna Weiland']
  s.email = ['rspernaweiland@schubergphilis.com']
  s.summary = %q{A knife plugin for testing Chef cookbooks}
  s.homepage = %q{https://www.schubergphilis.com/}
  s.description = %q{A Knife plugin to test Chef cookbooks}

  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "CHANGES.rdoc" ]

  s.add_dependency "chef", "< 14"
  s.add_dependency "knife-cosmic", ">= 0"
  s.add_dependency "knife-windows", ">= 0"
  s.add_dependency "winrm-fs", ">= 0"
  s.add_dependency "rb-readline", "= 0.5.5"
  s.add_dependency "berkshelf", "< 7"
  s.add_dependency "dep_selector", "> 0"
  s.add_dependency "knife-solo", "> 0"
  s.require_path = 'lib'
  s.files = ["CHANGES.rdoc","README.rdoc"] + Dir.glob("lib/**/*")
end
