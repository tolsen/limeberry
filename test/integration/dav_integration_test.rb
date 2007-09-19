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

# $Id$
# $URL$

require 'test/test_helper'
require 'action_controller/integration'

class DavIntegrationSession < ActionController::Integration::Session
  Limeberry::REQUEST_METHODS.values.flatten.each do |name|
    name.gsub!(/-/, '_')
    define_method(name) do |*args|
      process(name.to_sym, *args)
    end
  end
end
  

class DavIntegrationTestCase < ActionController::IntegrationTest
  include DavTest

  def setup
    super
    AppConfig.authentication_scheme = "basic"
  end

  def auth_header username, password
    { "HTTP_AUTHORIZATION" => "Basic " + Base64.encode64("#{username}:#{password}") }
  end

  Limeberry::REQUEST_METHODS.values.flatten.each do |method|
    method.gsub!(/-/, '_')

    # COPIED from rails/actionpack/lib/action_controller/integration.rb
    define_method(method) do |*args|
      reset! unless @integration_session
      # reset the html_document variable, but only for new get/post calls
      @html_document = nil unless %w(cookies assigns).include?(method)
      returning @integration_session.send(method, *args) do
        copy_session_variables!
      end
    end
  end


  def open_session
    session = DavIntegrationSession.new

    # COPIED from rails/actionpack/lib/action_controller/integration.rb
    
    # delegate the fixture accessors back to the test instance
    extras = Module.new { attr_accessor :delegate, :test_result }
    self.class.fixture_table_names.each do |table_name|
      name = table_name.tr(".", "_")
      next unless respond_to?(name)
      extras.send(:define_method, name) { |*args| delegate.send(name, *args) }
    end

    # delegate add_assertion to the test case
    extras.send(:define_method, :add_assertion) { test_result.add_assertion }
    session.extend(extras)
    session.delegate = self
    session.test_result = @_result

    yield session if block_given?
    session
  end

end
