# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  version_file = "lib/fluent/logger/version.rb"
  version = File.read("VERSION").strip
  File.open(version_file, "w") {|f|
    f.write <<EOF
module Fluent
module Logger

VERSION = '#{version}'

end
end
EOF
  }

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

  gem.add_dependency 'msgpack', '~> 0.4.4'
  gem.add_dependency 'json', '>= 1.4.3'
  gem.add_development_dependency 'rake', '>= 0.9.2'
end
