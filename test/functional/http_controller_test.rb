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
require 'http_controller'

# Re-raise errors caught by the controller.
class HttpController; def rescue_action(e) raise e end; end

class HttpControllerTest < DavFunctionalTestCase

  def setup
    super
    @controller = HttpController.new
    @request    = HttpTestRequest.new
    @response   = ActionController::TestResponse.new
    
    @ren = User.find_by_name 'ren'
  end

  def test_delete
    @request.body = "test"
    put '/foo', 'limeberry'
    
    delete '/foo', 'limeberry'
    assert_response 204

    get '/foo', 'limeberry'
    assert_response 404
  end

  def test_delete_not_found
    delete '/foo', 'limeberry'
    assert_response 404
  end

  def test_delete_unbind_denied
    Privilege.priv_bind.grant(Bind.root_collection, @ren)
    @request.body = 'test'
    put '/foo', 'ren'
    
    delete '/foo', 'ren'
    assert_response 403
    assert_content_equals 'test', '/foo'
  end

  def test_delete_unbind_granted
    Privilege.priv_unbind.grant(Bind.root_collection, @ren)
    
    @request.body = 'test'
    put '/foo', 'limeberry'

    delete '/foo', 'ren'
    assert_response 204

    get '/foo', 'limeberry'
    assert_response 404
  end

  def test_delete_unmodified
    @request.body = 'test'
    put '/foo', 'limeberry'

    @request.env['HTTP_IF_UNMODIFIED_SINCE'] =
      @response.headers['Last-Modified']

    delete '/foo', 'limeberry'
    assert_response 204

    @request.clear_http_headers
    get '/foo', 'limeberry'
    assert_response 404
  end

  def test_delete_modified
    @request.body = 'test'
    put '/foo', 'limeberry'

    @request.env['HTTP_IF_UNMODIFIED_SINCE'] =
      Time.httpdate(@response.headers['Last-Modified']).ago(1).httpdate
    delete '/foo', 'limeberry'
    assert_response 412
    assert_content_equals 'test', '/foo', true
  end
  
  def test_delete_match
    @request.body = 'test1'
    put '/foo', 'limeberry'
    etag1 = @response.headers['ETag']
    
    @request.body = 'test2'
    put '/foo', 'limeberry'
    etag2 = @response.headers['ETag']

    @request.env['HTTP_IF_MATCH'] = etag1
    delete '/foo', 'limeberry'
    assert_response 412
    assert_content_equals 'test2', '/foo', true

    @request.env['HTTP_IF_MATCH'] = etag2
    delete '/foo', 'limeberry'
    assert_response 204
    
    @request.clear_http_headers
    get '/foo', 'limeberry'
    assert_response 404
  end

  # add delete tests against collections (inside webdav tests)
  
  def test_get
    @request.body = "test"
    put '/foo', 'limeberry'
    get '/foo', 'limeberry'

    assert_response 200
    assert_equal "test", @response.binary_content
  end

  def test_get_not_found
    get '/foo', 'limeberry'
    assert_response 404
  end

  def test_get_forbidden
    @request.body = "test"
    put '/foo', 'limeberry'
    get '/foo', 'ren'

    assert_response 403
  end

  def test_get_readable
    @request.body = "test"
    put '/foo', 'limeberry'
    foo = Bind.locate '/foo'
    Privilege.priv_read.grant(foo, @ren)
    
    get '/foo', 'ren'
    assert_response 200
  end

  def test_get_unmodified
    @request.body = "test"
    put '/foo', 'limeberry'

    @request.env['HTTP_IF_MODIFIED_SINCE'] =
      @response.headers['Last-Modified']

    get '/foo', 'limeberry'
    assert_response 304
  end

  def test_get_modified
    @request.body = "test"
    put '/foo', 'limeberry'

    @request.env['HTTP_IF_MODIFIED_SINCE'] =
      Time.httpdate(@response.headers['Last-Modified']).ago(1).httpdate

    get '/foo', 'limeberry'
    assert_response 200
  end

  def test_get_none_match
    @request.body = "test"
    put '/foo', 'limeberry'

    @request.env['HTTP_IF_NONE_MATCH'] = @response.headers['ETag']
    get '/foo', 'limeberry'
    assert_response 304
  end

  def test_get_none_match_false
    @request.body = "test1"
    put '/foo', 'limeberry'
    etag1 = @response.headers['ETag']

    @request.body = "test2"
    put '/foo', 'limeberry'
    
    @request.env['HTTP_IF_NONE_MATCH'] = etag1
    get '/foo', 'limeberry'
    assert_response 200
  end

  def test_get_collection
    get '/http', 'limeberry'
    assert_response 405
  end
  
  def test_head
    @request.body = "test"
    put '/foo', 'limeberry'
    head '/foo', 'limeberry'
    assert_response 200
  end

#  def test_options_star
#    options :options, :path => [ "*" ]
#  end

  def test_options_rootdir
    options '/', 'limeberry'
    assert_response 200

    expected_collection_options = %w(BIND UNBIND REBIND OPTIONS DELETE PROPFIND PROPPATCH COPY MOVE LOCK UNLOCK ACL).sort

    assert_equal expected_collection_options, @response.headers['Allow'].split(',').map{ |m| m.strip }.sort
  end
  
  def test_options_rootdir_unauth
    options '/'
    assert_response 401
  end

  def test_put_collection
    @request.body = "test"
    put '/http', 'limeberry'
    assert_response 405
    assert_instance_of Collection, Bind.locate('/http')
  end
  
  def test_put_conflict
    @request.body = "test"
    put '/foo/bar', 'limeberry'
    assert_response 409
  end

  def test_put_create
    @request.body = "test"
    put '/foo', 'limeberry'
    assert_response 201

    r = nil
    assert_nothing_raised(NotFoundError) { r = Bind.locate("/foo") }
    assert_equal "test", r.body.stream.read
  end

  def test_put_update
    @request.body = "test1"
    put '/foo', 'limeberry'
    @request.body = "test2"
    put '/foo', 'limeberry'
    assert_response 204
    
    r = nil
    assert_nothing_raised(NotFoundError) { r = Bind.locate("/foo") }
    assert_equal "test2", r.body.stream.read
  end

  def test_put_bind_permission_denied
    @request.body = "test"
    put '/foo', 'ren'
    assert_response 403

    get '/foo', 'limeberry'
    assert_response 404
  end

  def test_put_bind_permission_granted
    Privilege.priv_bind.grant(Bind.root_collection, @ren)
    @request.body = "test"
    put '/foo', 'ren'
    assert_response 201

    get '/foo', 'limeberry'
    assert_response 200
  end

  def test_put_get_same_etag
    @request.body = "test"
    put '/foo', 'limeberry'
    put_etag = @response.headers['ETag']

    get '/foo', 'limeberry'
    get_etag = @response.headers['ETag']

    assert_equal put_etag, get_etag
  end

  def test_put_unmodified
    @request.body = "test1"
    put '/foo', 'limeberry'

    @request.body = "test2"
    @request.env['HTTP_IF_UNMODIFIED_SINCE'] =
      @response.headers['Last-Modified']
    put '/foo', 'limeberry'
    assert_response 204

    @request.clear_http_headers
    get '/foo', 'limeberry'
    assert_equal "test2", @response.binary_content
  end

  def test_put_modified
    @request.body = "test1"
    put '/foo', 'limeberry'

    @request.body = "test2"
    @request.env['HTTP_IF_UNMODIFIED_SINCE'] =
      Time.httpdate(@response.headers['Last-Modified']).ago(1).httpdate

    put '/foo', 'limeberry'
    assert_response 412
    assert_content_equals "test1", '/foo', true
  end

  def test_put_match
    # IF-MATCH * with nothing there fails
    @request.body = "test1"
    @request.env['HTTP_IF_MATCH'] = '*'
    put '/foo', 'limeberry'
    assert_response 412

    @request.clear_http_headers
    get '/foo', 'limeberry'
    assert_response 404

    # IF-NONE-MATCH * with nothing there succeeds
    @request.body = "test2"
    @request.env['HTTP_IF_NONE_MATCH'] = '*'
    put '/foo', 'limeberry'
    assert_response 201
    assert_content_equals "test2", '/foo', true

    # IF-NONE-MATCH * with something there fails
    @request.body = "test3"
    @request.env['HTTP_IF_NONE_MATCH'] = '*'
    put '/foo', 'limeberry'
    assert_response 412
    assert_content_equals "test2", '/foo', true

    # IF-MATCH * with something there succeeds
    @request.body = "test4"
    @request.env['HTTP_IF_MATCH'] = '*'
    put '/foo', 'limeberry'
    assert_response 204
    assert_content_equals "test4", '/foo', true

    # IF-MATCH with same etag succeeds
    @request.body = "test5"
    etag1 = @request.env['HTTP_IF_MATCH'] = @response.headers['ETag']
    put '/foo', 'limeberry'
    assert_response 204
    assert_content_equals "test5", '/foo', true

    # IF-MATCH with different etag fails
    @request.body = "test6"
    @request.env['HTTP_IF_MATCH'] = etag1
    put '/foo', 'limeberry'
    assert_response 412
    assert_content_equals "test5", '/foo', true
  end
  
  def test_put_write_content_permission_denied
    @request.body = "test1"
    put '/foo', 'limeberry'

    @request.body = "test2"
    put '/foo', 'ren'
    assert_response 403
    assert_content_equals "test1", '/foo'
  end

  def test_put_write_content_permission_granted
    @request.body = "test1"
    put '/foo', 'limeberry'

    foo = Bind.locate '/foo'
    Privilege.priv_write_content.grant(foo, @ren)

    @request.body = "test2"
    put '/foo', 'ren'
    assert_response 204
    assert_content_equals 'test2', '/foo'
  end

  def test_put_quota
    @ren.total_quota = @ren.used_quota + 16
    @ren.save!
    Privilege.priv_all.grant(Bind.root_collection, @ren)

    # should have room for 10 bytes
    @request.body = "0123456789"
    put '/foo', 'ren'
    assert_response 201

    # 7 more though will go over quota
    @request.body = "0123456"
    put '/bar', 'ren'
    assert_response 507

    # should be able to replace original 10 with exactly 16 bytes
    @request.body = "0123456789012345"
    put '/foo', 'ren'
    assert_response 204
  end

  
end
