#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../../config/boot'

options = {:environment => "test"}
ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

require "benchmark"
include Benchmark

fname = ARGV.first
ARGV.shift
func = ARGV.first
ARGV.shift
N = Integer(ARGV.first)

bm(10) do |test|
  test.report() {
    N.times do
      system( 'ruby ' + RAILS_ROOT + fname + ' -n ' + func)
    end
  }
end
