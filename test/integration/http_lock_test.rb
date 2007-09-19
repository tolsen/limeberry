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

require "test/test_helper"
require "test/integration/dav_integration_test.rb"

class HttpLockTest < DavIntegrationTestCase

  def setup
    super
    @ren_auth = auth_header 'ren', 'ren'
  end
  
  # test that my modified integration test case works
  def test_dav_integration_test
    put '/httplock/foo', 'hello', @ren_auth
    assert_response 201

    get '/httplock/foo', nil, @ren_auth
    assert_response 200
    assert_equal 'hello', response.binary_content
  end

  def test_put_lock
    put '/httplock/a', 'hello', @ren_auth
    assert_response 423

    a_lock = Bind.locate('/httplock/a').locks[0]
    put '/httplock/a', 'hello', @ren_auth.merge(if_header(a_lock))
    assert_response 204

    get '/httplock/a', nil, @ren_auth
    assert_response 200
    assert_equal 'hello', response.binary_content
  end

  def if_header *args
    { 'HTTP_IF' => "(<#{args[0].locktoken}>)" }
  end
    
end
