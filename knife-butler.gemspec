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

  s.add_dependency "chef", ">= 12.21.26"
  s.add_dependency "knife-cloudstack", ">= 0"
  s.add_dependency "knife-windows", ">= 0"
  s.require_path = 'lib'
  s.files = ["CHANGES.rdoc","README.rdoc"] + Dir.glob("lib/**/*")
end
