require 'rake'
require 'rake/testtask'
require 'rake/clean'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "fluent-logger"
    gemspec.summary = "Structured event logger"
    gemspec.author = "Sadayuki Furuhashi"
    gemspec.email = "frsyuki@gmail.com"
    gemspec.homepage = "http://fluent.github.com/"
    gemspec.has_rdoc = false
    gemspec.require_paths = ["lib"]
    gemspec.add_dependency "msgpack", "~> 0.4.4"
    gemspec.add_dependency "json", ">= 1.4.3"
    gemspec.add_dependency "rake", ">= 0.9.2"
    gemspec.test_files = Dir["test/**/*.rb"]
    gemspec.files = Dir["bin/**/*", "lib/**/*", "test/**/*.rb"]
    gemspec.executables = []
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

Rake::TestTask.new(:test) do |t|
  t.test_files = Dir['test/*_test.rb']
  t.ruby_opts = ['-rubygems'] if defined? Gem
  t.ruby_opts << '-I.'
end

VERSION_FILE = "lib/fluent/logger/version.rb"

file VERSION_FILE => ["VERSION"] do |t|
  version = File.read("VERSION").strip
  File.open(VERSION_FILE, "w") {|f|
    f.write <<EOF
module Fluent
module Logger

VERSION = '#{version}'

end
end
EOF
  }
end

task :default => [VERSION_FILE, :build]

