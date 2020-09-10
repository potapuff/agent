lib_dir = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH << lib_dir unless $LOAD_PATH.include?(lib_dir)

require 'agent/meta'

Gem::Specification.new do |s|
  s.name = "agent"
  s.version = Agent::VERSION
  s.summary = Agent::DESCRIPTION
  s.homepage = "https://github.com/potapuff/agent"

  s.author = "Kuzikov Borys"
  s.email = "potapuff@gmail.com"

  s.files = [
    'MIT-LICENSE', 'README.markdown', 'Changelog.markdown', 'Gemfile', 'Gemfile.lock'
  ] + Dir['lib/**/*'] #+ Dir['spec/**/*']

  s.executables = ['agent']
  s.licenses    = ['MIT']

  s.add_dependency 'commander', '~> 4.0'
  s.add_dependency 'vmstat', '~> 2.3', '>= 2.3.1'
  s.add_dependency 'json'

  s.add_development_dependency 'rspec', '~> 2.5'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'mocha'

end
