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

options = {:environment => "test"}
ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

system( './' + RAILS_ROOT + '/db/drop_and_create_populated_database test' )

require "benchmark"
include Benchmark

u = User.make(:password => "pass",
              :name => "U",
              :displayname => "TESTUSER",
              :contentlanguage => "en",
              :comment => "TESTING FILESIZE PERFORMANCE",
              :quota => 100000000)


@session = Hash.new
args = Hash.new
def users_principal
  user = @session[:user]
  if user.nil?
    Principal.unauthenticated
  else
    @session[:user].principal
  end
end

puts "Uploading time"
bm(30) do |test|
  test.report("POPULATING USER DIRECTORIES") {
    1.times do
      user = @session[:user] = u
      Resource.make_directory( "U", "files", users_principal )
      args[:principal] = users_principal
      args[:directory] = Bind.locate "U/files"

      directory = RAILS_ROOT + "/test/performance/smallfiles"
      Dir.foreach(directory) do |filename|
        next if filename =~ /^\.\.?$/
        path = "#{directory}/#{filename}"
        args[:source] = path
        args[:input] = "general"
        args[:bindname] = filename
        Medium.make args
      end
    end
  }
end

puts "Downloading time"
bm(30) do |test|
  test.report("FETCHING USER DIRECTORIES") {
    1.times do
      user = @session[:user] = u
      directory = RAILS_ROOT + "/test/performance/smallfiles"
      Dir.foreach(directory) do |filename|
        next if filename =~ /^\.\.?$/
        bindname = "U/files/#{filename}"
        bindresource = Bind.locate bindname
        if bindresource.medium.ondisk?
          filepath = Utility.get_content_path bindresource.medium
          # puts filepath
          File.read(filepath)
          # send_file(filepath,
          # :disposition =>"inline",
          # :type => bindresource.medium.mimetype,
          # :filename=>Medium.base_part_of(bindname))
        else
          a = bindresource.medium.content.content
        end
      end
    end
  }
end

