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

require 'base64'
require File.expand_path(File.dirname(__FILE__) + "/../config/request_methods")

raise 'require\'d test/test_helper twice!, you broke it!' if
  ENV['RAILS_ENV'] == 'test'

ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'rexml/document'
require 'stringio'

$: << 'test' unless $:.include? 'test'

class Test::Unit::TestCase
  def deny(x, m=nil); assert ! x, m; end

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
end

module DavTest

  def self.register_profiler
    at_exit do
    end
  end

  if ENV['PROFILE'] then
    @@times = {}
    at_exit do # this runs BEFORE the tests run
      at_exit do # this should run AFTER the tests run
        puts
        puts "Time:"
        @@times.sort_by {|n,t| -t}.each do |name, time|
          puts "%6.2f %s" % [time, name]
        end
      end
    end
  end

  def test_dummy
    assert true
  end

  def setup
    @t = Time.now if ENV['PROFILE']
    super
    file_store_setup
    @limeberry = Principal.limeberry
    @root = Bind.root_collection
  end

  def teardown
    super
    Path.destroy_all unless use_transactional_fixtures?
    @@times[self.name] = Time.now - @t if ENV['PROFILE']
  end

  def self.expanded_file(path)
    File.expand_path(File.join(RAILS_ROOT, path))
  end

  def expanded_file(path) DavTest.expanded_file(path) end

  FILESTORE_TEST_BACKUP = expanded_file "filestore/test-backup"
  def file_store_setup
    raise "filestore/test-backup directory not present! Did you remember to run \"rake db:test:populate\" ?" unless
      File.directory? FILESTORE_TEST_BACKUP
    
    @filestore_root = expanded_file "tmp/test/#{$$}"

    unless File.directory?(@filestore_root) && !FileStore.dirty?
      `which rsync`
      if $? == 0
        out = `rsync -r --delete #{FILESTORE_TEST_BACKUP}/* #{@filestore_root} 2>&1`
        raise "rsync failed: #{out}" unless $? == 0
      else
        FileUtils.rm_rf(@filestore_root)
        FileUtils.cp_r FILESTORE_TEST_BACKUP, @filestore_root
      end
    end

    FileStore.instance.root = @filestore_root
  end

  def assert_prop_present(response,url,status,namespace,name,value=nil)
    found = nil
    assert_nothing_raised() {
      found = response.propstathash[url][status].member? DavResponse::Prop.new(namespace,name,value)
    }
    assert found
  end

  def assert_restricted_methods(obj, bad_methods)
    assert((obj.methods & bad_methods).empty?,
           "#{obj.class} shouldn't have methods: #{bad_methods.inspect}")
  end

  def assert_rexml_equal(expected, actual, message=nil)
    assert_equal(normalize_xml(expected), normalize_xml(actual), message)
  end

  TEST_REXML_INDENT = 2
  TEST_REXML_DOC_CTX = {
    :compress_whitespace => :all,
    :ignore_whitespace_nodes => :all
  }
  
  def normalize_xml(doc)
    REXML::Document.new(doc, TEST_REXML_DOC_CTX).sort_r.to_s(TEST_REXML_INDENT)
  end
  

  def create_lock(lock_root, owner = @limeberry, scope = 'X', depth = 'I')
    Lock.create!(:lock_root => lock_root,
                 :owner => owner,
                 :scope => scope,
                 :depth => depth,
                 :expires_at => Time.now + 5.years)
  end

  def setup_xml
    @xml_out = ""
    @xml = Builder::XmlMarkup.new(:target => @xml_out, :indent => 2)
  end

  def util_get(path)
    Bind.locate(path).body.stream.read
  end    
  
  def util_put(path, content, principal = @limeberry)
    collection = Bind.locate(File.dirname(path))
    basename = File.basename(path)
    resource = collection.find_child_by_name(basename)

    if resource.nil?
      resource = Resource.create!(:displayname => basename)
      collection.bind_and_set_acl_parent(resource, basename, principal)
    end
    
    Body.make('text/plain', resource, content)
    resource.reload
  end

  def assert_content_equals(expected, path, clear_headers = false)
    @request.clear_http_headers if clear_headers
    get path, 'limeberry'
    assert_response 200
    assert_equal expected, @response.binary_content
  end
  
end

class HttpTestRequest < ActionController::TestRequest
  attr_reader :cgi

  def initialize
    super
    self.body = ""
  end
  
  def body=(body)
    @cgi ||= FakeCgi.new
    @cgi.stdinput = StringIO.new(body)
  end

  def rewind_body
    @cgi.stdinput.rewind
  end

  class FakeCgi
    attr_accessor :stdinput
  end

  def clear_http_headers
    env.delete_if { |k, v| k =~ /^HTTP_/ }
  end
  
end

