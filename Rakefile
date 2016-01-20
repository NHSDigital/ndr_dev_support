require 'bundler/gem_tasks'
require 'rake/testtask'
require 'ndr_dev_support/tasks'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Run tests'
task default: :test
