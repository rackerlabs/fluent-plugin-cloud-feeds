$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = "fluentd-feeds-output"
  s.version = "1.0.0"
  s.authors = ["David Kowis", "Tyler Royal"]
  s.email= ["david.kowis@rackspace.com", "tyler.royal@rackspace.com"]
  s.homepage = "https://github.com/rackerlabs/fluentd-feeds-output"
  s.summary = "Fluentd plugin for output to Rackspace Cloud Feeds"
  s.description = "Fluentd plugin (fluentd.org) for output to Rackspace Cloud Feeds"

  #TODO: maybe add rubyforge_project
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]

  # sticking to the same version of ruby as fluentd
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  # dependencies
  s.add_dependency('net-http-persistent', '>= 2.7')

  # for help from RubyMine!
  s.add_runtime_dependency('fluentd', '0.12.7')

  s.add_development_dependency('rspec', '3.2.0')
  s.add_development_dependency('webmock', '1.21.0')
  s.add_development_dependency('simplecov', '0.10.0')
end