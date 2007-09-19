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
    @a = Bind.locate '/httplock/a'
    @a_lock = @a.locks[0]
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

    put '/httplock/a', 'hello', @ren_auth.merge(if_header(@a_lock))
    assert_response 204

    get '/httplock/a', nil, @ren_auth
    assert_response 200
    assert_equal 'hello', response.binary_content
  end

  def test_put_lock_expired
    if_hdr = if_header @a_lock
    unlock '/httplock/a', nil, @ren_auth.merge(locktoken_header(@a_lock))
    assert_response 204

    put '/httplock/a', 'hello', @ren_auth.merge(if_hdr)
    assert_response 412

    put '/httplock/a', 'hello', @ren_auth
    assert_response 204

    get '/httplock/a', nil, @ren_auth
    assert_response 200
    assert_equal 'hello', response.binary_content
  end

  def failing_test_delete_if_etag_and_lock
    old_etag_if_hdr = if_header @a, @a_lock

    put '/httplock/a', 'hello', @ren_auth.merge(if_header(@a_lock))
    assert_response 204

    puts old_etag_if_hdr['HTTP_IF']
    delete '/httplock/a', 'hello', @ren_auth.merge(old_etag_if_hdr)
    assert_response 412

    head '/httplock/a', nil, @ren_auth
    assert_response 200

    delete '/httplock/a', nil, @ren_auth.merge(if_header(@a, @a_lock))
    assert_response 204

    head '/httplock/a', nil, @ren_auth
    assert_response 404
  end
  

  def if_header *args
    { 'HTTP_IF' => "(" + args.map{ |a| a.delimited_token }.join(' ') + ")" }
  end

  def locktoken_header lock
    { 'HTTP_LOCK_TOKEN' => lock.delimited_token }
  end

    
  Resource.class_eval do
    def delimited_token() "[#{body.sha1}]"; end
  end

  Lock.class_eval do
    def delimited_token() "<#{locktoken}>"; end
  end
      
  
    
end
