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

# Usage ./simulation_m.rb <NUM USERS> <NUM GROUPS> <NUM LOGGED IN> p (-> for profiling)
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

threads = []
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
def users_principal
  if @session[:user].nil?
    Principal.unauthenticated
  else
    @session[:user].principal
  end
end

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

require 'mutex_m'
include Mutex_m

puts("LOGGING IN "+num_logged_in.to_s+" USERS\n")
bm(70) do |test|
  test.report("DOING FUNTIONS LIKE POPULATING DIRECTORIES, COPYING, MOVING, PRIVILEGES") {
    for i in 1...(num_logged_in + 1)
      threads << Thread.new(i) do |c|
        args = Hash.new
        Thread.current["user"] = user = @session[:user] = User.find(Principal.find_by_name( "U"+c.to_s ).id)
        Resource.make_directory( "U"+c.to_s, "wallpapers", user.principal )
        Resource.make_directory( "U"+c.to_s+"/wallpapers", "1", user.principal )
        Resource.make_directory( "U"+c.to_s+"/wallpapers", "2", user.principal )
        Resource.make_directory( "U"+c.to_s, "documents", user.principal )

        args[:principal] = user.principal
        args[:directory] = Bind.locate "U"+c.to_s+"/wallpapers/1"
        fname = RAILS_ROOT + "/test/performance/testfiles/1.jpg"
        args[:source] = fname
        args[:input] = "general"
        args[:bindname] = "1.jpg"
        Medium.make args

        args[:principal] = user.principal
        args[:directory] = Bind.locate "U"+c.to_s+"/wallpapers/2"
        fname = RAILS_ROOT + "/test/performance/testfiles/2.jpg"
        args[:source] = fname
        args[:input] = "general"
        args[:bindname] = "2.jpg"
        Medium.make args

        args[:principal] = user.principal
        args[:directory] = Bind.locate "U"+c.to_s+"/wallpapers"
        fname = RAILS_ROOT + "/test/performance/testfiles/a.html"
        args[:source] = fname
        args[:input] = "tinymce"
        args[:bindname] = "a.html"
        Medium.make args

        args[:principal] = user.principal
        args[:directory] = Bind.locate "U"+c.to_s+"/documents"
        fname = RAILS_ROOT + "/test/performance/testfiles/1.pdf"
        args[:source] = fname
        args[:input] = "general"
        args[:bindname] = "1.pdf"
        Medium.make args

        args[:principal] = user.principal
        args[:directory] = Bind.locate "U"+c.to_s+"/documents"
        fname = RAILS_ROOT + "/test/performance/testfiles/2.pdf"
        args[:source] = fname
        args[:input] = "general"
        args[:bindname] = "2.pdf"
        Medium.make args

        Resource.copy "U"+c.to_s+"/wallpapers/1/1.jpg", "U"+c.to_s+"/wallpapers/1.jpg", Principal.find_by_name( "U"+c.to_s )
        Resource.copy "U"+c.to_s+"/wallpapers/2/2.jpg", "U"+c.to_s+"/documents/2.jpg", Principal.find_by_name( "U"+c.to_s )
        Resource.copy "U"+c.to_s+"/documents/1.pdf", "U"+c.to_s+"/wallpapers/1/1.pdf", Principal.find_by_name( "U"+c.to_s )
        Resource.copy "U"+c.to_s+"/wallpapers/1/1.jpg", "U"+c.to_s+"/wallpapers/2/1.jpg", Principal.find_by_name( "U"+c.to_s )
        Resource.copy "U"+c.to_s+"/wallpapers/a.html", "U"+c.to_s+"/documents/a.html", Principal.find_by_name( "U"+c.to_s )

        if(c > 1)
          Bind.locate( "U"+c.to_s+"/wallpapers/1/1.pdf" ).grant_privilege AclPrivilege.find_by_name( 'DAV:read' ), Principal.find_by_name( "U"+(c-1).to_s )
          Bind.locate( "U"+c.to_s+"/documents/a.html" ).grant_privilege AclPrivilege.find_by_name( 'DAV:write' ), Principal.find_by_name( "U"+(c-1).to_s )
          Bind.locate( "U"+c.to_s+"/documents/2.pdf" ).deny_privilege AclPrivilege.find_by_name( 'DAV:all' ), Principal.find_by_name( "U"+(c-1).to_s )
          Bind.locate( "U"+c.to_s+"/wallpapers/2/2.jpg" ).deny_privilege AclPrivilege.find_by_name( 'DAV:all' ), Principal.find_by_name( "U"+(c-1).to_s )
        end

        # Version Control
        Bind.locate( "U"+c.to_s+"/wallpapers/2/1.jpg" ).version_control user.principal
        Bind.locate( "U"+c.to_s+"/wallpapers/2/1.jpg" ).vcr.checkout user.principal
        Bind.locate( "U"+c.to_s+"/wallpapers/2/1.jpg" ).vcr.checkin user.principal

        # Fetching directories
        bindname = "U"+c.to_s+"/wallpapers/1.jpg"
        bindresource = Bind.locate bindname
        if bindresource.medium.ondisk?
          filepath = Utility.get_content_path bindresource.medium
          File.read(filepath)
        else
          a = bindresource.medium.content.content
        end

        bindname = "U"+c.to_s+"/wallpapers/1/1.pdf"
        bindresource = Bind.locate bindname
        if bindresource.medium.ondisk?
          filepath = Utility.get_content_path bindresource.medium
          File.read(filepath)
        else
          a = bindresource.medium.content.content
        end

        bindname = "U"+c.to_s+"/documents/a.html"
        bindresource = Bind.locate bindname
        if bindresource.medium.ondisk?
          filepath = Utility.get_content_path bindresource.medium
          File.read(filepath)
        else
          a = bindresource.medium.content.content
        end

      end
    end
    threads.each {|thr| thr.join}
  }
end


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
