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

  gem.metadata['changelog_uri'] = "https://github.com/fluent/fluent-logger-ruby/blob/master/ChangeLog"
  gem.metadata['source_code_uri'] = "https://github.com/fluent/fluent-logger-ruby"
  gem.metadata['bug_tracker_uri'] = "https://github.com/fluent/fluent-logger-ruby/issues"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']
  gem.license       = "Apache-2.0"

  gem.add_dependency "msgpack", ">= 1.0.0", "< 2"
  # logger gem that isn't default gems as of Ruby 3.5
  gem.add_dependency "logger", "~> 1.6"
end
