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

namespace :litmus do
  desc "Build litmus test suite"
  task :build => "test/litmus/Makefile"

  desc "Clean out litmus build"
  task :clean do
    Dir.chdir('test/litmus') do
      system 'make distclean'
    end
  end

  file "test/litmus/Makefile" do
    Dir.chdir('test/litmus') do
      system './configure --with-included-neon'
      system 'make'
    end
  end

  task :test => "test:litmus"

end

namespace :test do
  desc "Run litmus tests"
  task :litmus => [ "db:test:populate",
                    "litmus:build",
                    "mongrel:test:start" ] do
    Dir.chdir('test/litmus') do
      system 'make URL=http://localhost:3002/limeberry/home CREDS="user1 user1" check'
    end
    Rake::Task["mongrel:test:stop"].invoke
  end

end
