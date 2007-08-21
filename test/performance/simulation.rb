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

# Usage ./simulation.rb <NUM USERS> <NUM GROUPS> <NUM LOGGED IN> p (-> for profiling)
require File.dirname(__FILE__) + '/../../config/boot'

options = {:environment => "test"}
ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

system( './' + RAILS_ROOT + '/db/drop_and_create_populated_database test' )

require "benchmark"
include Benchmark

num_users = Integer(ARGV.first)
ARGV.shift
num_groups = Integer(ARGV.first)
ARGV.shift
num_logged_in = Integer(ARGV.first)
ARGV.shift
p = ARGV.first

require "profile" if p == 'p'

puts("CREATING "+num_users.to_s+" USERS\n")
count = 1
bm(15) do |test|
  test.report("MAKING USERS") {
    num_users.times do
      User.make(:password => "pass"+count.to_s,
                :name => "U"+count.to_s,
                :displayname => "check"+count.to_s,
                :comment => "Creating Plenty of Users",
                :quota => 100000000)
      count += 1
    end
  }
end

puts("\n\n")

puts("CREATING "+num_groups.to_s+" GROUPS\n")
count = 1
bm(15) do |test|
  test.report("MAKING GROUPS") {
    num_groups.times do
      Principal.make(
                     :name => "G"+count.to_s,
                     :type_name => "Group")
      count += 1
    end
  }
end

puts("\n\n")

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

#
# Directory hierarchy of each logged in user
#
#               <USER_DIRECTORY>
#                       |
#                ----------------
#                |              |
#           wallpapers      documents
#                |              |
#          ------------    -----------
#          |     |    |    |         |
#          1     2  a.html |         |
#          |     |       1.pdf     2.pdf
#       1.jpg  2.jpg
#
#

puts("LOGGING IN "+num_logged_in.to_s+" USERS\n")
count = 1
bm(30) do |test|
  test.report("POPULATING USER DIRECTORIES") {
    num_logged_in.times do
      user = @session[:user] = User.find(Principal.find_by_name( "U"+count.to_s ).id)
      Resource.make_directory( "U"+count.to_s, "wallpapers", users_principal )
      Resource.make_directory( "U"+count.to_s+"/wallpapers", "1", users_principal )
      Resource.make_directory( "U"+count.to_s+"/wallpapers", "2", users_principal )

      Resource.make_directory( "U"+count.to_s, "documents", users_principal )

      args[:principal] = users_principal
      args[:directory] = Bind.locate "U"+count.to_s+"/wallpapers/1"
      fname = RAILS_ROOT + "/test/performance/testfiles/1.jpg"
      args[:source] = fname
      args[:input] = "general"
      args[:bindname] = "1.jpg"
      Medium.make args

      args[:principal] = users_principal
      args[:directory] = Bind.locate "U"+count.to_s+"/wallpapers/2"
      fname = RAILS_ROOT + "/test/performance/testfiles/2.jpg"
      args[:source] = fname
      args[:input] = "general"
      args[:bindname] = "2.jpg"
      Medium.make args

      args[:principal] = users_principal
      args[:directory] = Bind.locate "U"+count.to_s+"/wallpapers"
      fname = RAILS_ROOT + "/test/performance/testfiles/a.html"
      args[:source] = fname
      args[:input] = "tinymce"
      args[:bindname] = "a.html"
      Medium.make args

      args[:principal] = users_principal
      args[:directory] = Bind.locate "U"+count.to_s+"/documents"
      fname = RAILS_ROOT + "/test/performance/testfiles/1.pdf"
      args[:source] = fname
      args[:input] = "general"
      args[:bindname] = "1.pdf"
      Medium.make args

      args[:principal] = users_principal
      args[:directory] = Bind.locate "U"+count.to_s+"/documents"
      fname = RAILS_ROOT + "/test/performance/testfiles/2.pdf"
      args[:source] = fname
      args[:input] = "general"
      args[:bindname] = "2.pdf"
      Medium.make args

      count += 1
    end
  }
end

puts("\n\n")

puts("ADDING GROUP MEMBERS\n")
count = 1
bm(20) do |test|
  test.report("MAKING GROUP MEMBERS") {
    num_groups.times do
      Principal.find_by_name( "G"+count.to_s ).add_member Principal.find_by_name( "U"+count.to_s )
      Principal.find_by_name( "G"+count.to_s ).add_member Principal.find_by_name( "U"+(count+1).to_s )
      Principal.find_by_name( "G"+count.to_s ).add_member Principal.find_by_name( "U"+(count+2).to_s )
      count += 1
    end
  }
end

puts("\n\n")

#
# Directory hierarchy of each logged in user after copying
#
#               <USER_DIRECTORY>
#                       |
#                ----------------
#                |              |
#           wallpapers      documents
#                |              |
#          ------------    -----------
#          |     |    |    |         |
#          1     2  a.html |         |
#          |     |  1.jpg  |         |
#       1.jpg  2.jpg     1.pdf     2.pdf
#       1.pdf                      2.jpg
#

count = 1
bm(10) do |test|
  test.report("COPYING FILES") {
    num_logged_in.times do
      Resource.copy "U"+count.to_s+"/wallpapers/1/1.jpg", "U"+count.to_s+"/wallpapers/1.jpg", Principal.find_by_name( "U"+count.to_s )
      Resource.copy "U"+count.to_s+"/wallpapers/2/2.jpg", "U"+count.to_s+"/documents/2.jpg", Principal.find_by_name( "U"+count.to_s )
      Resource.copy "U"+count.to_s+"/documents/1.pdf", "U"+count.to_s+"/wallpapers/1/1.pdf", Principal.find_by_name( "U"+count.to_s )
      count += 1
    end
  }
end

puts("\n\n")

#
# Directory hierarchy of each logged in user after moving
#
#               <USER_DIRECTORY>
#                       |
#                ----------------
#                |              |
#           wallpapers      documents
#                |              |
#          ------------    -----------
#          |     |    |    |    |    |
#          1     2  1.jpg  |    |    |
#          |     |         |  a.html |
#       1.pdf  2.jpg     1.pdf     2.pdf
#              1.jpg               2.jpg
#

count = 1
bm(10) do |test|
  test.report("MOVING FILES") {
    num_logged_in.times do
      Resource.move "U"+count.to_s+"/wallpapers/1/1.jpg", "U"+count.to_s+"/wallpapers/2/1.jpg", Principal.find_by_name( "U"+count.to_s )
      Resource.move "U"+count.to_s+"/wallpapers/a.html", "U"+count.to_s+"/documents/a.html", Principal.find_by_name( "U"+count.to_s )
      count += 1
    end
  }
end

puts("\n\n")

count = 1
bm(10) do |test|
  test.report("Limeberry::GRANTING AND Limeberry::DENYING PRIVILEGES") {
    num_logged_in.times do
      Bind.locate( "U"+count.to_s+"/wallpapers/1/1.pdf" ).grant_privilege AclPrivilege.find_by_name( 'DAV:read' ), Principal.find_by_name( "U"+(count+1).to_s )
      Bind.locate( "U"+count.to_s+"/documents/a.html" ).grant_privilege AclPrivilege.find_by_name( 'DAV:write' ), Principal.find_by_name( "U"+(count+1).to_s )
      Bind.locate( "U"+count.to_s+"/documents/2.pdf" ).deny_privilege AclPrivilege.find_by_name( 'DAV:all' ), Principal.find_by_name( "U"+(count+1).to_s )
      Bind.locate( "U"+count.to_s+"/wallpapers/2/2.jpg" ).deny_privilege AclPrivilege.find_by_name( 'DAV:all' ), Principal.find_by_name( "U"+(count+1).to_s )
      count += 1
    end
  }
end

puts("\n\n")

count = 1
bm(10) do |test|
  test.report("VERSION CONTROL") {
    num_logged_in.times do
      user = @session[:user] = User.find(Principal.find_by_name( "U"+count.to_s ).id)
      Bind.locate( "U"+count.to_s+"/wallpapers/2/1.jpg" ).version_control users_principal
      Bind.locate( "U"+count.to_s+"/wallpapers/2/1.jpg" ).vcr.checkout users_principal
      Bind.locate( "U"+count.to_s+"/wallpapers/2/1.jpg" ).vcr.checkin users_principal
      count += 1
    end
  }
end

puts("\n\n")

count = 1
bm(25) do |test|
  test.report("FETCHING USER DIRECTORIES") {
    num_logged_in.times do
      user = @session[:user] = User.find(Principal.find_by_name( "U"+count.to_s ).id)
      bindname = "U"+count.to_s+"/wallpapers/1.jpg"
      bindresource = Bind.locate bindname
      if bindresource.medium.ondisk?
        filepath = Utility.get_content_path bindresource.medium
        File.read(filepath)
      else
        a = bindresource.medium.content.content
      end

      bindname = "U"+count.to_s+"/wallpapers/1/1.pdf"
      bindresource = Bind.locate bindname
      if bindresource.medium.ondisk?
        filepath = Utility.get_content_path bindresource.medium
        File.read(filepath)
      else
        a = bindresource.medium.content.content
      end

      bindname = "U"+count.to_s+"/documents/a.html"
      bindresource = Bind.locate bindname
      if bindresource.medium.ondisk?
        filepath = Utility.get_content_path bindresource.medium
        File.read(filepath)
      else
        a = bindresource.medium.content.content
      end
      count += 1
    end
  }
end
