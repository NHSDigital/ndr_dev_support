namespace :ci do
  desc 'Housekeep cached and temporary files'
  task :housekeep do
    # If running in a Rails project we invoke the standard tmp/ and log/ clearing tasks
    Rake::Task['log:clear'].invoke if Rake::Task.task_defined?('log:clear')
    Rake::Task['tmp:clear'].invoke if Rake::Task.task_defined?('tmp:clear')
  end
end
