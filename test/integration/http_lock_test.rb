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

require 'rexml/document'

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

  # WebDAV book (L. Dusseault) pp. 186-87 8.4.3
  def test_delete_if_etag_and_lock
    old_etag_if_hdr = if_header @a, @a_lock

    put '/httplock/a', 'hello', @ren_auth.merge(if_header(@a_lock))
    assert_response 204

    delete '/httplock/a', nil, @ren_auth.merge(old_etag_if_hdr)
    assert_response 412

    head '/httplock/a', nil, @ren_auth
    assert_response 200

    delete '/httplock/a', nil, @ren_auth.merge(if_header(@a.reload, @a_lock))
    assert_response 204

    head '/httplock/a', nil, @ren_auth
    assert_response 404
  end

  # WebDAV book (L. Dusseault) pp. 186-88 8.4.4
  def test_delete_if_backed_up
    copy '/httplock/b', nil, @ren_auth.merge(dest_header('/httplock/b-backup'))
    assert_response 201

    copy '/httplock/b', nil, @ren_auth.merge(dest_header('/httplock/b1'))
    assert_response 201

    put '/httplock/b', 'hello', @ren_auth
    assert_response 204

    copy '/httplock/b', nil, @ren_auth.merge(dest_header('/httplock/b-backup2'))
    assert_response 201

    b_backup = Bind.locate '/httplock/b-backup'
    b_backup2 = Bind.locate '/httplock/b-backup2'

    delete '/httplock/b', nil, @ren_auth.merge(if_header([b_backup],[b_backup2]))
    assert_response 204

    head '/httplock/b', nil, @ren_auth
    assert_response 404

    delete '/httplock/b1', nil, @ren_auth.merge(if_header([b_backup],[b_backup2]))
    assert_response 204

    head '/httplock/b1', nil, @ren_auth
    assert_response 404
  end

  # WebDAV book (L. Dusseault) pp. 188-90 8.4.5 (Listing 8-8)
  def test_move_under_single_lock
    locktoken = request_and_assert_lock '/httplock/hr', 200, 'I' 

    move_headers = @ren_auth.merge(dest_header('/httplock/hr/archives/resumes'))
    move '/httplock/hr/recruiting/resumes', nil, move_headers
    assert_response 423

    assert Bind.exists?('/httplock/hr/recruiting/resumes')
    assert !Bind.exists?('/httplock/hr/archives/resumes')

    move_headers.merge! 'HTTP_IF' => "(<#{locktoken}>)"
    move '/httplock/hr/recruiting/resumes', nil, move_headers
    assert_response 201

    assert !Bind.exists?('/httplock/hr/recruiting/resumes')
    assert Bind.exists?('/httplock/hr/archives/resumes')
  end

  # WebDAV book (L. Dusseault) pp. 188-90 8.4.5 (Listing 8-9)
  def test_move_between_locks
    resumes_locktoken = request_and_assert_lock '/httplock/hr/recruiting/resumes', 200, 'I'
    archives_locktoken = request_and_assert_lock '/httplock/hr/archives', 200, 'I'

    move_headers = @ren_auth.merge(dest_header('/httplock/hr/archives/resumes'))
    assert_move_response = lambda do |*args|
      expected_response, if_hdr = args
      
      headers = move_headers
      headers['HTTP_IF'] = if_hdr unless if_hdr.nil?
      move '/httplock/hr/recruiting/resumes', nil, headers
      assert_response expected_response

      success = expected_response / 100 == 2
      
      assert success ^ Bind.exists?('/httplock/hr/recruiting/resumes')
      assert success ^ !Bind.exists?('/httplock/hr/archives/resumes')
    end

    assert_move_response.call 423
    assert_move_response.call 423, "(<#{resumes_locktoken}>)"
    assert_move_response.call 412, "(<#{archives_locktoken}>)"
    assert_move_response.call 412, "(<#{resumes_locktoken}> <#{archives_locktoken}>)"

    assert_move_response.call 201, "(<#{resumes_locktoken}>) (<#{archives_locktoken}>)"
  end

  def dest_header path
    { 'HTTP_DESTINATION' => "http://www.example.com#{path}" }
  end

  def discover_locktoken xmlbody
    doc = REXML::Document.new xmlbody
    REXML::XPath.first doc, '/prop/lockdiscovery/activelock/locktoken/href/text()', { '' => 'DAV:' }
  end
  
      
  def if_header *args
    args = [ args ] unless args[0].is_a? Array
    header = args.map{ |tkns| "(" + tkns.map{ |t| t.delimited_token }.join(' ') + ")" }.join ' '
    { 'HTTP_IF' => header }
  end

  def locktoken_header lock
    { 'HTTP_LOCK_TOKEN' => lock.delimited_token }
  end

  def request_lock(path, depth = '0', timeout = nil, body = exclusive_lock_body)
    depth = 'infinity' if depth == 'I'
    headers = {}
    headers['HTTP_TIMEOUT'] = timeout unless timeout.nil?
    headers['HTTP_DEPTH'] = depth
    headers.merge! @ren_auth
    lock path, body, headers
  end

  def request_and_assert_lock(path, expected_response = 200, depth = '0', timeout = nil, body = exclusive_lock_body)
    request_lock path, depth, timeout, body
    assert_response expected_response
    discover_locktoken response.body
  end
    
  Lock.class_eval do
    def delimited_token() "<#{locktoken}>"; end
  end

  Resource.class_eval do
    def delimited_token() "[\"#{etag}\"]"; end
  end

    
end
