# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'

begin
  require 'juwelier'
  Juwelier::Tasks.new do |gem|
    # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
    gem.name = "gmail-britta"
    gem.homepage = "http://github.com/antifuchs/gmail-britta"
    gem.license = "MIT"
    gem.summary = %Q{Create complex gmail filtersets with a ruby DSL.}
    gem.description = %Q{This gem helps create large (>50) gmail filter chains by writing xml compatible with gmail's "import/export filters" feature.} #'
    gem.email = "asf@boinkor.net"
    gem.authors = ["Andreas Fuchs"]
    # dependencies defined in Gemfile
  end
  Juwelier::RubygemsDotOrgTasks.new
rescue LoadError
end

begin
  require 'rake/testtask'
  Rake::TestTask.new(:test) do |test|
    test.libs << 'lib' << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
  task :default => :test
rescue LoadError
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
end
