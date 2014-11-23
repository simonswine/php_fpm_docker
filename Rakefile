# coding: utf-8
require 'bundler/gem_tasks'

# rspec
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

# rubocop
begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
end

desc 'Run all tests'
task :test => [:spec, :rubocop]

task :default => :test
