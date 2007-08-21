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

options = { :environment => "test"}

ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

require "benchmark"
include Benchmark

count = 0
bmbm(10) do |test|
  test.report("MAKING RESOURCES") {
    100.times do
      Resource.make(  :creator =>Principal.limeberry,
                      :displayname => "check"+count.to_s )
      count += 1
    end
  }
end
