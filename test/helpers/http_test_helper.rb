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

require 'test/helpers/method_maker'

module HttpTestHelper

  def self.included(base)
    %w( get put delete head ).each do |method|
      base.send(:alias_method, "old_#{method}".to_sym, method.to_sym)
    end
  end

  %w( get put delete head options ).each do |m|
    class_eval(MethodMaker.http_method_body(m), __FILE__, __LINE__)
  end
    
  def assert_content_equals(expected, path, clear_headers = false)
    @request.clear_http_headers if clear_headers
    get path, 'limeberry'
    assert_response 200
    assert_equal expected, @response.binary_content
  end
  
    
end



