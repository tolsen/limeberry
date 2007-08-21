#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../../config/boot'

options = {:environment => "test"}
ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

require "profile"

fname = ARGV.first
ARGV.shift
func = ARGV.first

if func.nil?
  system( 'ruby ' + RAILS_ROOT + fname)
else
  system( 'ruby ' + RAILS_ROOT + fname + ' -n ' + func)
end

