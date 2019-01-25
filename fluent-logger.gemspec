# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)
require 'fluent/logger/version'

Gem::Specification.new do |gem|
  version_file = "lib/fluent/logger/version.rb"
  version = Fluent::Logger::VERSION

  gem.name        = %q{fluent-logger}
  gem.version     = version
  # gem.platform  = Gem::Platform::RUBY
  gem.authors     = ["Sadayuki Furuhashi"]
  gem.email       = %q{frsyuki@gmail.com}
  gem.homepage    = %q{https://github.com/fluent/fluent-logger-ruby}
  gem.description = %q{fluent logger for ruby}
  gem.summary     = gem.description

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']
  gem.license       = "Apache-2.0"

  gem.add_dependency "msgpack", ">= 1.0.0", "< 2"
  gem.add_development_dependency 'rake', '>= 0.9.2'
  gem.add_development_dependency 'rspec', '>= 3.0.0'
  gem.add_development_dependency 'rspec-its', '>= 1.1.0'
  gem.add_development_dependency 'simplecov', '>= 0.5.4'
  gem.add_development_dependency 'timecop', '>= 0.3.0'
end
