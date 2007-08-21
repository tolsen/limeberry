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

######### getting time for addition and lookup for this graph
##          g1
##         / 
##        g2  g3
##        \  / \
##         g4   g5
##        /  \ / 
##       g7   g6
##       /    | 
##      g8    g9
##     /  \  /
##    g10  g11
##
#############################

require "benchmark"
include Benchmark

g1 = Principal.make(:name => "group1")
g2 = Principal.make(:name => "group2")
g3 = Principal.make(:name => "group3")
g4 = Principal.make(:name => "group4")
g5 = Principal.make(:name => "group5")
g6 = Principal.make(:name => "group6")
g7 = Principal.make(:name => "group7")
g8 = Principal.make(:name => "group8")
g9 = Principal.make(:name => "group9")
g10 = Principal.make(:name => "group10")
g11 = Principal.make(:name => "group11")

bmbm(10) do |test|
  test.report("TESTING LOOKUPS") {
    1.times do
      g1.add_member g2
      g2.add_member g4
      g3.add_member g4
      g3.add_member g5
      g4.add_member g6
      g4.add_member g7
      g5.add_member g6
      g7.add_member g8
      g6.add_member g9
      g8.add_member g10
      g8.add_member g11
      g9.add_member g11
      
      g7.is_member_of? g3
      g11.is_member_of? g1
      g10.is_member_of? g5
      g10.is_member_of? g3
      g9.is_member_of? g3
      g8.is_member_of? g3
      g8.is_member_of? g5
      g11.is_member_of? g3
    end
  }
end
