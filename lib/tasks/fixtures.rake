# -*- rake -*-

namespace :db do
  namespace :fixtures do
    desc 'Dump a database to yaml fixtures.  Set environment variables DB
          and DEST to specify the target database and destination path for the
          fixtures.  DB defaults to development and DEST defaults to RAILS_ROOT/
          test/fixtures.'

    task :dump => :environment do
      path = ENV['DEST'] || "#{RAILS_ROOT}/test/fixtures"
      db   = ENV['DB']   || 'development'
      sql  = 'SELECT * FROM %s'

      ActiveRecord::Base.establish_connection(db)
      ActiveRecord::Base.connection.select_values('show tables').each do |table_name|
        i = '000'
        File.open("#{path}/#{table_name}.yml", 'wb') do |file|
          file.write ActiveRecord::Base.connection.select_all(sql % table_name).inject({}) { |hash, record|
            hash["#{table_name}_#{i.succ!}"] = record
            hash
          }.to_yaml
        end
      end
    end

    desc "Loads fixtures whilst turning foreign key constraints checking off"
    task :load_without_constraints => :environment do
        require 'active_record/fixtures'

        # By default, the test database. Override with FIXTURE_ENV=xxx
        FIXTURE_ENV = ENV['FIXTURE_ENV'] ? ENV['FIXTURE_ENV'] : :test

        ActiveRecord::Base.establish_connection(FIXTURE_ENV.to_sym)
        ActiveRecord::Base.connection.update "SET FOREIGN_KEY_CHECKS = 0"
        Dir.glob(File.join(RAILS_ROOT, 'test', 'fixtures', '*.{yml,csv}')).each do |fixture_file|
            Fixtures.create_fixtures('test/fixtures', File.basename(fixture_file, '.*'))
        end
        ActiveRecord::Base.connection.update "SET FOREIGN_KEY_CHECKS = 1"
    end
  end
end
