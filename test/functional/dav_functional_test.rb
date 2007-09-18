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

class DavFunctionalTestCase < Test::Unit::TestCase
  include DavTest

  def self.inherited sub
    super
    sub_name = sub.name.demodulize.underscore
    if sub_name.sub! /^([^_]*)_controller_test$/, '\1'
      request_class = sub_name.to_sym

      if Limeberry::REQUEST_METHODS.include? request_class
        Limeberry::REQUEST_METHODS[request_class].each do |name|
          name.gsub!(/-/, '_')
          name_sym = name.to_sym
          name_upcase = name.upcase
          sub.send(:define_method, name) do |*args|
            path, username = args
            @request.env['REQUEST_METHOD'] = name_upcase if defined?(@request)
            path_a = path.split('/').reject { |n| n.blank? }
            process(name_sym, { :path => path_a}, { :username => username })
          end

            
        end
      end
      
    end
  end
  
end
