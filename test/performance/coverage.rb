#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../../config/boot'

options = {:environment => "test"}
ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

s = ""
until ARGV.first.nil? do
  s = s + RAILS_ROOT + ARGV.first + " "
  ARGV.shift
end

system( 'rcov ' + s)

