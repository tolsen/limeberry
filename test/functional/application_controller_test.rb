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

require 'test/test_helper'
require 'application'

class ApplicationControllerTest < DavTestCase

  def setup
    super
    @controller = ApplicationController.new
  end

  def test_matches
    foo = util_put '/foo', 'arbit'
    etag = foo.body.sha1

    assert matches?(foo, "\"asdsad\", \"#{etag}\", \"qwe\"", @limeberry)
    assert !matches?(foo, "\"asdsad\", \"qwe\"", @limeberry)

    assert_raises(UnauthorizedError) do
      matches?(foo, "\"#{etag}\"", Principal.unauthenticated)
    end

    assert_nothing_raised(UnauthorizedError) do
      assert matches?(foo, "*", Principal.unauthenticated)
      assert !matches?(nil, "*", Principal.unauthenticated)
    end
  end

  def matches?(*args) @controller.send(:matches?, *args) end
  
end
