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
require 'test/functional/dav_functional_test'
require 'lock_controller'

# Re-raise errors caught by the controller.
class LockController; def rescue_action(e) raise e end; end

class LockControllerTest < DavFunctionalTestCase
  
  def setup
    super
    @controller = LockController.new
    @request    = HttpTestRequest.new
    @response   = ActionController::TestResponse.new

    @a = Bind.locate '/lock/a'
    @c = Bind.locate '/lock/c'
    @d = Bind.locate '/lock/d'
    @z = Bind.locate '/lock/c/z'
    
    @ren, @stimpy, @joe = ['ren', 'stimpy', 'joe'].map{ |u| User.find_by_name u }
  end

  def test_parse_lock
    lockinfo = <<EOS
<D:lockinfo xmlns:D='DAV:'> 
  <D:lockscope><D:exclusive/></D:lockscope> 
  <D:locktype><D:write/></D:locktype> 
  <D:owner> 
    <D:href>http://example.org/~ejw/contact.html</D:href> 
  </D:owner> 
</D:lockinfo>
EOS
    result = @controller.send :parse_lock, lockinfo

    expected = {
      :lockscope => 'exclusive',
      :locktype => 'write',
      :owner => '<D:href>http://example.org/~ejw/contact.html</D:href>'
    }

    assert result.include?(:owner)
    result[:owner].strip!

    assert_equal expected, result
  end

  def test_config_timeout
    assert_not_nil AppConfig.default_lock_timeout
    assert_not_nil AppConfig.max_lock_timeout
  end
  
  
  def test_parse_timeout_unset
    result = @controller.send(:parse_timeout, nil)
    assert_equal AppConfig.default_lock_timeout,  result
  end

  def test_parse_timeout_reasonable
    requested = AppConfig.max_lock_timeout - 1
    result = @controller.send(:parse_timeout, "Second-#{requested}")
    assert_equal requested, result
  end
  
  def test_parse_timeout_infinite
    result = @controller.send(:parse_timeout, "Infinite")
    assert_equal AppConfig.max_lock_timeout, result
  end

  def test_parse_timeout_unreasonable
    requested = AppConfig.max_lock_timeout + 1
    result = @controller.send(:parse_timeout, "Second-#{requested}")
    assert_equal AppConfig.max_lock_timeout, result
  end

  def test_parse_timeout_rfc_example
    result = @controller.send(:parse_timeout, "Infinite, Second-4100000000")
    expected = [4100000000, AppConfig.max_lock_timeout].min
    assert_equal expected, result
  end

  def test_lock
    request_lock '/lock/d'
    assert_proper_lock_response @d, ExpectedLock.new('/lock/d')
  end

  def test_lock_specified_time
    request_lock '/lock/d', 'Second-1000'
    assert_proper_lock_response @d, ExpectedLock.new('/lock/d', :timeout => 1000)
  end

  def test_lock_refresh
    request_lock '/lock/d', 'Second-1000'
    assert_response 200
    token = @d.direct_locks.last.locktoken

    @request.env['HTTP_IF'] = "(<#{token}>)"
    request_lock '/lock/d', 'Second-10000', ""
    assert_proper_lock_response @d, ExpectedLock.new('/lock/d', :timeout => 10000)
  end

  def test_lock_locked_resource
    request_lock '/lock/a'
    assert_response 423
  end

  def test_lock_twice
    request_lock '/lock/d', 'Second-1000'
    assert_response 200
    token = @d.direct_locks.last.locktoken

    @request.env['HTTP_IF'] = "(<#{token}>)"
    request_lock '/lock/d'
    assert_response 423
  end

  def test_shared_locks
    request_lock '/lock/d', 'Second-1000', shared_lock_body
    expected_lock = ExpectedLock.new('/lock/d', :timeout => 1000, :scope => :shared)
    assert_proper_lock_response(@d,  expected_lock)

    request_lock '/lock/d', 'Second-1000', shared_lock_body
    assert_proper_lock_response @d.reload, expected_lock, expected_lock

    request_lock '/lock/d', 'Second-1000'
    assert_response 423
  end

  def test_shared_locks_different_owners
    Privilege.priv_write_content.grant @d, @ren
    Privilege.priv_write_content.grant @d, @stimpy
    Privilege.priv_write_content.grant @d, @joe

    expected_lock = ExpectedLock.new('/lock/d', :timeout => 1000, :scope => :shared)

    request_lock '/lock/d', 'Second-1000', shared_lock_body, 'ren'
    assert_proper_lock_response @d, expected_lock

    request_lock '/lock/d', 'Second-1000', shared_lock_body, 'stimpy'
    assert_proper_lock_response @d.reload, expected_lock, expected_lock

    request_lock '/lock/d', 'Second-1000', exclusive_lock_body, 'joe'
    assert_response 423
  end
    
  def test_shared_lock_after_exclusive_lock
    request_lock '/lock/d', 'Second-1000'
    request_lock '/lock/d', 'Second-1000', shared_lock_body
    assert_response 423
  end

  def test_lock_permission_denied
    request_lock '/lock/d', 'Second-1000', exclusive_lock_body, 'ren'
    assert_response 403
  end

  def test_lock_conflict
    request_lock '/lock/y/z', 'Second-1000'
    assert_response 409
  end

  def test_lock_refresh_wrong_token
    request_lock '/lock/d', 'Second-1000'

    wrong_token = @a.direct_locks.last.locktoken
    @request.env['HTTP_IF'] = "(<#{wrong_token}>)"
    request_lock '/lock/d', 'Second-10000', ""
    assert_response 412
    assert_timeout_close_enough 1000, @d.reload.direct_locks.last.seconds_left
  end

  def test_lock_refresh_wrong_owner
    Privilege.priv_all.grant @d, @ren
    Privilege.priv_all.grant @d, @stimpy
    request_lock '/lock/d', 'Second-1000', exclusive_lock_body, 'ren'
    token = @d.direct_locks.last.locktoken
    @request.env['HTTP_IF'] = "(<#{token}>)"
    request_lock '/lock/d', 'Second-10000', "", 'stimpy'
    assert_response 403
  end

  def test_locknull
    request_lock '/lock/z'
    z = Bind.locate '/lock/z'
    assert_instance_of LockNullResource, z
    assert_proper_lock_unmapped_response z, ExpectedLock.new('/lock/z')
  end

  def test_lockempty
    AppConfig.lock_unmapped_url = 'LER'
    Lock.load_unmapped_class
    request_lock '/lock/z'
    z = Bind.locate '/lock/z'
    assert_instance_of Resource, z
    assert_proper_lock_unmapped_response z, ExpectedLock.new('/lock/z')
  ensure
    AppConfig.lock_unmapped_url = 'LNR'
    Lock.load_unmapped_class
  end

  def test_lock_zero_depth_resource
    @request.env['HTTP_DEPTH'] = '0'
    request_lock '/lock/d'
    assert_proper_lock_response @d, ExpectedLock.new('/lock/d', :depth => 0)
  end
    
  def test_lock_zero_depth_collection
    @request.env['HTTP_DEPTH'] = '0'
    request_lock '/lock/c'
    assert_proper_lock_response @c, ExpectedLock.new('/lock/c', :depth => 0)

    # this should not conflict
    request_lock '/lock/c/z'
    assert_proper_lock_response @z, ExpectedLock.new('/lock/c/z', :depth => 0)
  end
  
  def test_lock_infinite_depth_collection
    request_lock '/lock/c'
    assert_proper_lock_response @c, ExpectedLock.new('/lock/c')

    assert_equal @c.direct_locks, @c.locks
    assert_equal @c.locks, @z.locks
    assert_equal 0, @z.direct_locks.size

    request_lock '/lock/c/z'
    assert_response 423

    request_lock '/lock/c/z', "Second-1000", shared_lock_body
    assert_response 423
  end

  def test_lock_explicit_infinite_depth_collection
    @request.env['HTTP_DEPTH'] = 'infinity'
    request_lock '/lock/c'
    assert_proper_lock_response @c, ExpectedLock.new('/lock/c')

    assert_equal @c.direct_locks, @c.locks
    assert_equal @c.locks, @z.locks
    assert_equal 0, @z.direct_locks.size
  end

  def test_lock_infinite_depth_collection_shared
    request_lock '/lock/c', 'Second-1000', shared_lock_body
    expected_lock_c = ExpectedLock.new('/lock/c', :timeout => 1000, :scope => :shared)
    assert_proper_lock_response @c, expected_lock_c
    
    request_lock '/lock/c/z'
    assert_response 423

    request_lock '/lock/c/z', 'Second-1000', shared_lock_body
    expected_lock_z = ExpectedLock.new('/lock/c/z', :timeout => 1000, :scope => :shared)
    assert_proper_lock_response @z, expected_lock_c, expected_lock_z
  end
  
  def test_lock_infinite_permission_denied_child
    Privilege.priv_write_content.grant @c, @ren
    Privilege.priv_write_content.deny @z, @ren

    request_lock '/lock/c', 'Second-1000', exclusive_lock_body, 'ren'
    assert_response 207

    assert_dav_xml(@response.body,
                   :multistatus =>
                   { :response => 
                     [ { :href => "/lock/c/z", 
                         :status => "HTTP/1.1 403 Forbidden"
                       },
                       { :href => "/lock/c",
                         :status => "HTTP/1.1 424 Failed Dependency"
                       }
                     ]
                   })
  end

  def test_lock_infinite_permission_denied_children
    e, f, g, h, i = ['e', 'e/f', 'e/g', 'e/g/h', 'e/i' ].map { |p| Bind.locate "/lock/#{p}" }

    Privilege.priv_write_content.grant e, @ren
    Privilege.priv_write_content.grant i, @ren
    Privilege.priv_write_content.deny f, @ren
    Privilege.priv_write_content.deny g, @ren
    Privilege.priv_write_content.deny h, @ren

    request_lock '/lock/e', 'Second-1000', exclusive_lock_body, 'ren'
    assert_response 207

    assert_dav_xml(@response.body,
                   :multistatus =>
                   { :response => 
                     [ { :href => "/lock/e/f", 
                         :status => "HTTP/1.1 403 Forbidden"
                       },
                       { :href => "/lock/e/g", 
                         :status => "HTTP/1.1 403 Forbidden"
                       },
                       { :href => "/lock/e/g/h", 
                         :status => "HTTP/1.1 403 Forbidden"
                       },
                       { :href => "/lock/e",
                         :status => "HTTP/1.1 424 Failed Dependency"
                       }
                     ]
                   })
  end

  def test_lock_match
    @request.env['HTTP_IF_NONE_MATCH'] = '*'
    request_lock '/lock/d'
    assert_response 412

    @request.clear_http_headers
    @request.env['HTTP_IF_MATCH'] = '*'
    request_lock '/lock/d'
    assert_proper_lock_response @d, ExpectedLock.new('/lock/d')
  end

  def test_locknull_match
    @request.env['HTTP_IF_MATCH'] = '*'
    request_lock '/lock/z'
    assert_response 412

    @request.clear_http_headers
    @request.env['HTTP_IF_NONE_MATCH'] = '*'
    request_lock '/lock/z'
    assert_proper_lock_unmapped_response '/lock/z', ExpectedLock.new('/lock/z')
  end

  def test_unlock
    set_locktoken_header @a.locks[0]
    unlock '/lock/a', 'limeberry'
    assert_response 204
    assert !@a.reload.locked?
  end

  def test_unlock_not_found
    set_locktoken_header @a.locks[0]
    unlock '/lock/z', 'limeberry'

    assert_response 404
    assert @a.reload.locked?
  end

  def test_unlock_bad_request
    unlock '/lock/a', 'limeberry'
    assert_response 400
    assert @a.reload.locked?

    @request.env['HTTP_LOCK_TOKEN'] = "<badlocktoken>"
    assert_response 400
    assert @a.reload.locked?
  end

  def test_unlock_forbidden
    set_locktoken_header @a.locks[0]
    unlock '/lock/a', 'ren'
    assert_response 403
    assert @a.reload.locked?

    Privilege.priv_write_content.grant @a, @ren
    set_locktoken_header @a.locks[0]
    unlock '/lock/a', 'ren'
    assert_response 403
    assert @a.reload.locked?

    Privilege.priv_unlock.grant @a, @ren
    set_locktoken_header @a.locks[0]
    unlock '/lock/a', 'ren'
    assert_response 204
    assert !@a.reload.locked?
  end

  def test_lock_unlock
    Privilege.priv_write_content.grant @d, @ren
    request_lock '/lock/d', 'Second-1000', exclusive_lock_body, 'ren'
    assert @d.locked?

    set_locktoken_header @d.locks[0]
    unlock '/lock/d', 'ren'
    assert_response 204
    assert !@d.reload.locked?
  end

  def test_unlock_locknull
    locknull = Bind.locate '/locknull'
    set_locktoken_header locknull.locks[0]
    unlock '/locknull', 'limeberry'
    assert_response 204
    assert_raise(ActiveRecord::RecordNotFound) { locknull.reload }
  end

  def test_lock_unlock_locknull
    request_lock '/lock/z'
    z = Bind.locate '/lock/z'
    set_locktoken_header z.locks[0]
    unlock '/lock/z', 'limeberry'
    assert_response 204
    assert_raise(ActiveRecord::RecordNotFound) { z.reload }
  end

  def test_lock_unlock_lockempty
    AppConfig.lock_unmapped_url = 'LER'
    Lock.load_unmapped_class
    request_lock '/lock/z'
    z = Bind.locate '/lock/z'
    assert z.locked?
    set_locktoken_header z.locks[0]
    unlock '/lock/z', 'limeberry'
    assert_response 204
    assert_nothing_raised(ActiveRecord::RecordNotFound) { z.reload }
    assert !z.locked?
  ensure
    AppConfig.lock_unmapped_url = 'LNR'
    Lock.load_unmapped_class
  end

  def test_unlock_collection_infinite_depth
    request_lock '/lock/c'
    assert @c.locked?
    assert @z.locked?

    set_locktoken_header @c.locks[0]
    unlock '/lock/c', 'limeberry'
    assert_response 204
    assert !@c.reload.locked?
    assert !@z.reload.locked?
  end

  def test_unlock_collection_infinite_depth_indirectly
    request_lock '/lock/c'
    assert @c.locked?
    assert @z.locked?

    set_locktoken_header @c.locks[0]
    unlock '/lock/c/z', 'limeberry'
    assert_response 204
    assert !@c.reload.locked?
    assert !@z.reload.locked?
  end

  def test_unlock_collection_zero_depth_does_not_interfere_with_child_locks
    @request.env['HTTP_DEPTH'] = '0'
    request_lock '/lock/c'
    request_lock '/lock/c/z'

    assert @c.locked?
    assert @z.locked?

    set_locktoken_header @c.locks[0]
    unlock '/lock/c', 'limeberry'
    assert_response 204

    assert !@c.reload.locked?
    assert @z.reload.locked?
  end

  def test_unlock_shared
    Privilege.priv_write_content.grant @d, @ren
    Privilege.priv_write_content.grant @d, @stimpy
    
    request_lock '/lock/d', 'Second-1000', shared_lock_body, 'ren'
    request_lock '/lock/d', 'Second-1000', shared_lock_body, 'stimpy'
    assert @d.locked?

    set_locktoken_header @d.locks[0]
    unlock '/lock/d', 'ren'
    assert_response 204
    assert @d.reload.locked?

    set_locktoken_header @d.locks[0]
    unlock '/lock/d', 'stimpy'
    assert_response 204
    assert !@d.reload.locked?
  end

  def test_unlock_shared_infinite_depth
    Privilege.priv_write_content.grant @c, @ren
    Privilege.priv_write_content.grant @z, @ren
    Privilege.priv_write_content.grant @z, @stimpy

    request_lock '/lock/c', 'Second-1000', shared_lock_body, 'ren'
    request_lock '/lock/c/z', 'Second-1000', shared_lock_body, 'stimpy'

    assert_equal 1, @c.locks.size
    assert_equal 1, @c.direct_locks.size
    assert_equal 2, @z.locks.size
    assert_equal 1, @z.direct_locks.size
  
    set_locktoken_header @c.locks[0]
    unlock '/lock/c', 'ren'
    assert_response 204

    assert !@c.reload.locked?
    assert_equal 1, @z.reload.locks.size
    assert_equal 1, @z.direct_locks.size

    set_locktoken_header @z.locks[0]
    unlock '/lock/c/z', 'stimpy'
    assert_response 204
    
    assert !@c.reload.locked?
    assert !@z.reload.locked?
  end

  def test_unlock_conflict
    set_locktoken_header @a.locks[0]
    unlock '/lock/d', 'limeberry'
    assert_response 409
    
    set_locktoken_header @a.locks[0]
    unlock '/lock/b', 'limeberry'
    assert_response 409
  end
  
    
  # helpers

  def assert_dav_xml(text, hsh = {})
    root = REXML::Document.new(text, TEST_REXML_DOC_CTX).root
    assert_dav_doc root, hsh
  end
  

  def depth_one_size(hsh)
    hsh.inject(0){ |sum, (k, v)| sum + (v.is_a?(Array) ? v.size : 1) }
  end

  def assert_dav_doc(element, hsh = {}, root = true)
    children = nil
    if root
      children = [element]
      assert_equal 1, hsh.size
    else
      children = element.elements
      assert_equal depth_one_size(hsh), children.size
    end
    
    assert_equal 'DAV:', element.namespace

    hsh2 = hsh.clone
    children.each do |child|
      key = child.name.to_sym
      assert hsh2.include?(key)
      value = hsh2[key]
      assert_not_equal [], value, "#{child.name} already seen"
      hsh2[key] = [] unless value.is_a? Array

      case value
      when Proc
        value.call child
      when Hash
        assert_dav_doc child, value, false
      when Array # one must match
        assert_dav_matches_any child, value
        #        assert_dav_doc child, value.inject({}){|h,s|h[s] = nil}, false
      when Symbol
        assert_dav_doc child, { value => nil }, false
      when String
        assert_equal value, child.text
      when nil # pass
      else raise "invalid value for #{key}"
      end
    end

    hsh2.each{ |c, v| assert_equal [], v, "#{c} not present" }
  end

  def assert_dav_matches_any(element, hashes)
    hashes.each_index do |i|
      return hashes.delete_at(i) if dav_matches?(element, hashes[i])
    end
    flunk "none of the #{hashes.size} hashes matched #{element.name}"
  end

  def dav_matches?(element, hsh)
    assert_dav_doc element, hsh, false
    return true
  rescue Test::Unit::AssertionFailedError
    return false
  end
  
  def request_lock(path, timeout = nil, body = exclusive_lock_body, principal = 'limeberry')
    @request.env['HTTP_TIMEOUT'] = timeout unless timeout.nil?
    @request.body = body
    lock path, principal
  end
  
  def assert_proper_lock_response(path_or_resource, *expected_locks)
    assert_proper_lock_response_common 200, path_or_resource, *expected_locks
  end

  def assert_proper_lock_unmapped_response(path_or_resource, *expected_locks)
    assert_proper_lock_response_common 201, path_or_resource, *expected_locks
  end
  
    
  def assert_proper_lock_response_common(status, path_or_resource, *expected_locks)
    assert_response status
    resource = path_or_resource.is_a?(Resource) ? path_or_resource : Bind.locate(path_or_resource)
    assert_equal("<#{resource.direct_locks.last.locktoken}>",
                 @response.headers['Lock-Token'])

    uuid = Utility.locktoken_to_uuid(@response.headers['Lock-Token'].sub(/<(.*)>/, '\1'))
    assert resource.locked_with?(uuid)
    assert_equal expected_locks.size, resource.locks.size
    
    assert_dav_xml(@response.body, expected_lock_response(*expected_locks))
  end

  def expected_lock_response(*expected_locks)
    token = nil
    path = nil

    assert_token_matches_path = lambda do |sym|
      lambda do |e|
        case sym
        when :token then token = e.text
        when :path then path = e.text
        else raise "sym must be :token or :path"
        end

        return if token.nil? || path.nil? # not ready to check yet
        assert Bind.locate(path).locked_with?(Utility.locktoken_to_uuid(token))
        token = path = nil
      end
    end

    { :prop =>
      { :lockdiscovery =>
        { :activelock =>
          expected_locks.map { |elock|
            { :locktype => :write,
              :lockscope => elock.scope,
              :depth => elock.depth,
              :owner => { :href => "http://example.org/~ejw/contact.html" },
              :timeout => lambda { |c|
                assert c.text =~ /^Second-(\d+)$/
                assert_timeout_close_enough elock.timeout, $1
              },
              :locktoken => { :href => assert_token_matches_path.call(:token) },
              :lockroot => { :href => assert_token_matches_path.call(:path) }
            }
          }
        }
      }
    }
  end

  TIMEOUT_TOLERANCE = 20
  def assert_timeout_close_enough(expected, actual)
    assert_in_delta expected - TIMEOUT_TOLERANCE, actual, TIMEOUT_TOLERANCE
  end

  class ExpectedLock
    attr_reader :path, :timeout, :scope, :depth

    def initialize(path, opts = {})
      @path = path
      @timeout = opts[:timeout] || AppConfig.default_lock_timeout
      @scope = opts[:scope] || :exclusive
      @depth = (opts[:depth] || "infinity").to_s
    end

  end

  def set_locktoken_header(lock)
    @request.env['HTTP_LOCK_TOKEN'] = "<#{lock.locktoken}>"
  end
  
  
end
