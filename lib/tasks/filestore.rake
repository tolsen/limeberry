# -*- rake -*-

# Copyright (c) 2007 Lime Spot LLC

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

namespace :filestore do
  desc "Clears filestore directories."
  task :clear => :environment do
    FileUtils.rm_rf(Dir["#{FILE_STORE_ROOT}/[^.]*/[^.]*"])
  end

  desc "Completely removes filestore directories."
  task :remove => :environment do
    FileUtils.rm_rf(Dir["#{FILE_STORE_ROOT}/[^.]*"])
  end

  desc "Creates filestore directories."
  task :create => :environment do
    FileUtils.mkdir_p(%W( #{FILE_STORE_ROOT}/sha1s #{FILE_STORE_ROOT}/tmp ))
  end

  desc "Removes and re-creates filestore directories."
  task :reset => ['filestore:remove', 'filestore:create']

  def backup_root
    FILE_STORE_ROOT.squeeze('/').chomp('/') + "-backup"
  end

  desc "Backs-up filestore directory to <dir>-backup/"
  task :backup => :environment do
    FileUtils.rm_rf backup_root
    FileUtils.cp_r FILE_STORE_ROOT, backup_root
  end

  desc "Restore filestore directory from backup"
  task :restore => :environment do
    out = `rsync -r --delete #{backup_root}/* #{FILE_STORE_ROOT} 2>&1`
    raise "rsync failed: #{out}" unless $? == 0
  end

  namespace :test do

    [ :clear, :remove, :create, :reset, :backup, :restore ].each do |t|
      tsk = Rake::Task["filestore:#{t.to_s}"]

      desc "#{tsk.comment} (test)"
      task t do
        RAILS_ENV = "test"
        tsk.invoke
      end

    end

  end

end
