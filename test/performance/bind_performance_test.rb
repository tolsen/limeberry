#!/usr/bin/env ruby

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

require File.dirname(__FILE__) + '/../../config/boot'
require 'optparse'

options = { :environment => (ENV['RAILS_ENV'] || "development").dup , :prepare => false, :num => 1000}

ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

OptionParser.new do |opts|
  opts.banner = "Usage: script [options]"
  opts.on('-p', '--prepare',"Populates the database.") { |options[:prepare]| }
  opts.on('-t', "--times [NUM]", Integer, 'Number of times to run the benchmark') { |options[:num]| }
  opts.on("-h", "--help",
          "Show this help message.") { puts opts; exit }
  opts.parse!(ARGV)
end


if(options[:prepare])

  1.upto(5) do |i|
    puts "Var#{i}"
    Resource.make_directory "/", "Level1_#{i}", Principal.limeberry
    1.upto(5) do |j|
      Resource.make_directory "/Level1_#{i}", "Level2_#{j}", Principal.limeberry
      1.upto(5) do |k|
        Resource.make_directory "/Level1_#{i}/Level2_#{j}", "Level3_#{k}", Principal.limeberry
        1.upto(5) do |l|
          Resource.make_directory "/Level1_#{i}/Level2_#{j}/Level3_#{k}", "Level4_#{l}", Principal.limeberry
          1.upto(5) do |m|
            Resource.make_directory "/Level1_#{i}/Level2_#{j}/Level3_#{k}/Level4_#{l}", "Level5_#{m}", Principal.limeberry
          end
        end
      end
    end
  end
end

uri = "\'/Level1_1/Level2_3/Level3_2/Level4_5/Level5_1\'"

exec RAILS_ROOT + "/script/performance/benchmarker #{options[:num]} "+ '"Bind.locate_by_ruby(' + uri +')" "Bind.locate(' + uri + ')"'
