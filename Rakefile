
require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/*_test.rb']
  test.verbose = true
end

task :coverage do |t|
  require 'simplecov'
  SimpleCov.start do 
    add_filter 'test/'
  end
  Rake::Task["test"].invoke
  require 'pathname'
  $LOAD_PATH << '.'
  Pathname.glob('lib/**/*.rb').each do |file|
    require file.to_s.sub(/\.rb$/, '')
  end
end

task :default => :build

