# -*- ruby -*-

namespace :db do
  namespace :test do

    desc 'copy data from development to test'
    task :clone_data => [ "db:fixtures:dump", "db:fixtures:load_without_constraints" ]

    desc 'prepare test db and filestore'
    task :populate => [ :prepare, "filestore:test:reset", :clone_data ] do
      RAILS_ENV = 'test'
      require 'db/populate_samples'

      Rake::Task["filestore:test:backup"].invoke
    end

  end
end
