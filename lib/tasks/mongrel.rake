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

namespace :mongrel do

  # environments to ports
  ports = {
    "development" => 3001,
    "test"        => 3002
  }

  rule(/^tmp\/mongrel-.*\.pid$/) do |t|
    RAILS_ENV = t.name.sub(/tmp\/mongrel-(.*)\.pid/, '\1')
    system "mongrel_rails start -d -e #{RAILS_ENV} -P #{t.name} -p #{ports[RAILS_ENV]}"
  end

  desc "Start mongrel (port #{ports['development']})"
  task :start => "tmp/mongrel-development.pid"

  desc "Stop mongrel (port #{ports['development']})"
  task :stop do
    stop_mongrel
  end

  namespace :test do
    desc "Start mongrel using test environment (port #{ports['test']})"
    task :start => "tmp/mongrel-test.pid"

    desc "Stop mongrel using test enviroment (port #{ports['test']})"
    task :stop do
      RAILS_ENV = 'test'
      stop_mongrel
    end
  end

  def stop_mongrel
    pid_file = "tmp/mongrel-#{RAILS_ENV}.pid"
    system "mongrel_rails stop -P #{pid_file}" if File.exists? pid_file
  end
end
