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
require 'bind_controller'

class BindController
  # Re-raise errors caught by the controller.
  def rescue_action(e) raise e end
  
  def reset() @segment = @href = nil; end
end

class BindControllerTest < DavFunctionalTestCase

  def setup
    super
    @controller = BindController.new
    @request    = HttpTestRequest.new
    @response   = ActionController::TestResponse.new

    @bindroot = Bind.locate '/bind2'
    @a = Bind.locate '/bind2/a'
    @b = Bind.locate '/bind2/a/b'
    @r = Bind.locate '/bind2/r'
    
    @ren = User.find_by_name 'ren'
  end

  def test_bind
    @request.body = bind_body 'z', '/bind2/r'
    bind '/bind2', 'limeberry'
    assert_response 201
    assert_equal @r, Bind.locate('/bind2/z')
    assert_equal 2, @r.binds.size
  end

  def test_bind_to_resource_in_different_dir
    @request.body = bind_body 'r', '/bind2/r'
    bind '/bind2/a', 'limeberry'
    assert_response 201
    assert_equal @r, Bind.locate('/bind2/a/r')
    assert_equal 2, @r.binds.size
  end
    
  
  def test_bind_implicit_overwrite
    @request.body = bind_body 'a', '/bind2/r'
    bind '/bind2', 'limeberry'
    assert_response 200
    assert_equal @r, Bind.locate('/bind2/a')
    assert_equal 2, @r.binds.size
    assert_raise(ActiveRecord::RecordNotFound) { @a.reload }
  end

  def test_bind_explicit_overwrite
    @request.env['HTTP_OVERWRITE'] = 'T'
    test_bind_implicit_overwrite
  end

  def test_bind_no_overwrite
    @request.env['HTTP_OVERWRITE'] = 'F'
    @request.body = bind_body 'a', '/bind2/r'
    bind '/bind2', 'limeberry'
    assert_response 412

    assert_nothing_raised(ActiveRecord::RecordNotFound) { @a.reload }
    assert_nothing_raised(ActiveRecord::RecordNotFound) { @r.reload }
    assert_equal 1, @r.binds.size
  end

  def test_bind_cycle
    @request.body = bind_body 'z', '/bind2/a'
    bind '/bind2/a', 'limeberry'
    assert_response 201
    assert_equal @a, Bind.locate('/bind2/a/z')
    assert_equal @a, Bind.locate('/bind2/a/z/z')
    assert_equal 2, @a.binds.size
  end

  def test_bind_longer_cycle
    @request.body = bind_body 'z', '/bind2'
    bind '/bind2/a', 'limeberry'
    assert_response 201
    assert_equal @bindroot, Bind.locate('/bind2/a/z')
    assert_equal @a, Bind.locate('/bind2/a/z/a')
    assert_equal @bindroot, Bind.locate('/bind2/a/z/a/z')
    assert_equal 2, @bindroot.binds.size
  end

  def test_bind_descendant
    @request.body = bind_body 'a', '/bind2/a/b'
    bind '/bind2', 'limeberry'
    assert_response 200
    assert_equal @b, Bind.locate('/bind2/a')
    assert_raise(ActiveRecord::RecordNotFound) { @a.reload }
    assert_nothing_raised(ActiveRecord::RecordNotFound) do
      assert_equal 1, @b.reload.binds.size
    end
    assert_raise(NotFoundError) { Bind.locate '/bind2/a/b' }
  end

  def test_bind_collection_not_found
    @request.body = bind_body 'r2', '/bind2/r'
    bind '/bind2/nothere', 'limeberry'
    assert_response 404

    assert_nothing_raised(ActiveRecord::RecordNotFound, NotFoundError) do
      assert_equal @r.reload, Bind.locate('/bind2/r')
    end

    assert_raise(NotFoundError) { Bind.locate '/bind2/nothere' }
  end

  def test_bind_href_not_found
    @request.body = bind_body 'y', '/bind2/z'
    bind '/bind2', 'limeberry'
    assert_response 409

    assert_raise(NotFoundError) { Bind.locate '/bind2/y' }
  end

  def test_bind_request_uri_not_collection
    @request.body = bind_body 'z', 'bind2/a'
    bind '/bind2/r', 'limeberry'
    assert_response 405

    assert_equal 1, @a.reload.binds.size
    assert_raise(NotFoundError) { Bind.locate '/bind2/r/z' }
  end

  def test_bind_permissions
    @request.body = bind_body 'z', '/bind2/r'
    bind '/bind2', 'ren'
    assert_response 403
    assert_valid_mappings '/bind2/r' => @r
    assert_equal 1, @r.binds.size

    @controller.reset
    Privilege.priv_bind.grant @bindroot, @ren
    @request.body = bind_body 'z', '/bind2/r'
    bind '/bind2', 'ren'
    assert_response 201
    assert_valid_mappings '/bind2/r' => @r, '/bind2/z' => @r
    assert_equal 2, @r.binds.size
  end

  def test_bind_permissions_overwrite
    Privilege.priv_bind.grant @bindroot, @ren
    @request.body = bind_body 'a', '/bind2/r'
    bind '/bind2', 'ren'
    assert_response 403
    assert_valid_mappings '/bind2/r' => @r, '/bind2/a' => @a, '/bind2/a/b' => @b
    assert_equal 1, @r.binds.size

    @controller.reset
    Privilege.priv_unbind.grant @bindroot, @ren
    @request.body = bind_body 'a', '/bind2/r'
    bind '/bind2', 'ren'
    assert_response 200
    assert_equal @r, Bind.locate('/bind2/a')
    assert_equal 2, @r.binds.size
    assert_raise(ActiveRecord::RecordNotFound) { @a.reload }
  end
  
  def test_unbind
    @request.body = unbind_body 'r'
    unbind '/bind2', 'limeberry'
    assert_response 200
    assert_raise(ActiveRecord::RecordNotFound) { @r.reload }
  end

  def test_unbind_hierarchy
    @request.body = unbind_body 'a'
    unbind '/bind2', 'limeberry'
    assert_response 200
    assert_raise(ActiveRecord::RecordNotFound) { @a.reload }
    assert_raise(ActiveRecord::RecordNotFound) { @b.reload }
  end

  def test_unbind_latest_bind
    @request.body = bind_body 'r2', '/bind2/r'
    bind '/bind2', 'limeberry'
    assert_equal 2, @r.binds.size
    r2 = nil
    assert_nothing_raised(NotFoundError) { r2 = Bind.locate '/bind2/r2' }

    @controller.reset
    @request.body = unbind_body 'r2'
    unbind '/bind2', 'limeberry'
    assert_response 200
    assert_nothing_raised(ActiveRecord::RecordNotFound) { r2.reload }
    assert_equal 1, @r.reload.binds.size
    assert_raise(NotFoundError) { Bind.locate '/bind2/r2' }

    @controller.reset
    @request.body = unbind_body 'r'
    unbind '/bind2', 'limeberry'
    assert_response 200
    assert_raise(ActiveRecord::RecordNotFound) { r2.reload }
    assert_raise(ActiveRecord::RecordNotFound) { @r.reload }
  end
  
  def test_unbind_first_bind
    @request.body = bind_body 'r2', '/bind2/r'
    bind '/bind2', 'limeberry'
    assert_equal 2, @r.binds.size

    @controller.reset
    @request.body = unbind_body 'r'
    unbind '/bind2', 'limeberry'
    assert_response 200
    assert_nothing_raised(ActiveRecord::RecordNotFound) { @r.reload }
    assert_nothing_raised(NotFoundError) { Bind.locate '/bind2/r2' }
    assert_equal 1, @r.binds.size
    assert_raise(NotFoundError) { Bind.locate '/bind2/r' }

    @controller.reset
    @request.body = unbind_body 'r2'
    unbind '/bind2', 'limeberry'
    assert_response 200
    assert_raise(ActiveRecord::RecordNotFound) { @r.reload }
    assert_raise(NotFoundError) { Bind.locate '/bind2/r2' }
  end

  def test_unbind_collection_not_found
    @request.body = unbind_body 'foo'
    unbind '/bind2/nothere', 'limeberry'
    assert_response 404
  end
  
  def test_unbind_source_not_found
    num_children = @bindroot.childbinds.size
    @request.body = unbind_body 'z'
    unbind '/bind2', 'limeberry'
    assert_response 409
    assert_equal num_children, @bindroot.reload.childbinds.size
  end

  def test_unbind_request_uri_not_collection
    @request.body = unbind_body 'z'
    unbind '/bind2/r', 'limeberry'
    assert_response 405
    assert_valid_mappings '/bind2/r' => @r
  end

  def test_unbind_permissions
    @request.body = unbind_body 'r'
    unbind '/bind2', 'ren'
    assert_response 403
    assert_valid_mappings '/bind2/r' => @r

    @controller.reset
    Privilege.priv_unbind.grant @bindroot, @ren
    @request.body = unbind_body 'r'
    unbind '/bind2', 'ren'
    assert_response 200
    assert_raise(ActiveRecord::RecordNotFound) { @r.reload }
  end
  
  def test_rebind
    assert_successful_rebind '/bind2/r', '/bind2/r2', @r
  end

  def test_rebind_implicit_overwrite
    @request.body = rebind_body 'a', '/bind2/r'
    rebind '/bind2', 'limeberry'
    assert_response 200

    assert_nothing_raised(ActiveRecord::RecordNotFound) { @r.reload }
    assert_equal 1, @r.binds.size

    assert_raise(NotFoundError) { Bind.locate '/bind2/r' }
    assert_nothing_raised(NotFoundError) do
      assert_equal @r, Bind.locate('/bind2/a')
    end

    assert_raise(ActiveRecord::RecordNotFound) { @a.reload }
    assert_raise(ActiveRecord::RecordNotFound) { @b.reload }
    assert_raise(NotFoundError) { Bind.locate '/bind2/a/b' }
  end

  def test_rebind_explicit_overwrite
    @request.env['HTTP_OVERWRITE'] = 'T'
    test_rebind_implicit_overwrite
  end
  
  def test_rebind_no_overwrite
    @request.env['HTTP_OVERWRITE'] = 'F'
    @request.body = rebind_body 'a', '/bind2/r'
    rebind '/bind2', 'limeberry'
    assert_response 412
    assert_valid_mappings '/bind2/r' => @r, '/bind2/a' => @a, '/bind2/a/b' => @b
  end
  
  def test_rebind_to_different_collection
    assert_successful_rebind '/bind2/r', '/bind2/a/z', @r
  end

  def test_rebind_collection_not_found
    @request.body = rebind_body 'r2', '/bind2/r'
    rebind '/bind2/z', 'limeberry'
    assert_response 404
    assert_valid_mappings '/bind2/r' => @r
  end

  def test_rebind_source_not_found
    @request.body = rebind_body 'z', '/bind2/y'
    rebind '/bind2', 'limeberry'
    assert_response 409
  end

  def test_rebind_request_uri_not_collection
    @request.body = rebind_body 'z', 'bind2/a'
    rebind '/bind2/r', 'limeberry'
    assert_response 405
    assert_equal 1, @a.reload.binds.size
    assert_raise(NotFoundError) { Bind.locate '/bind2/r/z' }
  end
  
  def test_rebind_permissions
    assert_failing_rebind '/bind2/r', '/bind2/r2', @r, 403, 'ren'
    
    @controller.reset
    Privilege.priv_bind.grant @bindroot, @ren
    assert_failing_rebind '/bind2/r', '/bind2/r2', @r, 403, 'ren'

    @controller.reset
    @bindroot.aces.find_all_by_principal_id(@ren.id).each { |p| p.destroy }
    Privilege.priv_unbind.grant @bindroot, @ren
    assert_failing_rebind '/bind2/r', '/bind2/r2', @r, 403, 'ren'

    @controller.reset
    Privilege.priv_bind.grant @bindroot, @ren
    assert_successful_rebind '/bind2/r', '/bind2/r2', @r, 'ren'
  end

  def test_rebind_permissions_different_collections
    assert_failing_rebind '/bind2/r', '/bind2/a/z', @r, 403, 'ren'
    
    @controller.reset
    Privilege.priv_bind.grant @a, @ren
    assert_failing_rebind '/bind2/r', '/bind2/a/z', @r, 403, 'ren'

    @controller.reset
    @a.aces.find_all_by_principal_id(@ren.id).each { |p| p.destroy }
    Privilege.priv_unbind.grant @bindroot, @ren
    assert_failing_rebind '/bind2/r', '/bind2/a/z', @r, 403, 'ren'

    @controller.reset
    Privilege.priv_bind.grant @a, @ren
    assert_successful_rebind '/bind2/r', '/bind2/a/z', @r, 'ren'
  end

  def test_rebind_permissions_overwrite
    @a.acl_parent = nil
    Privilege.priv_unbind.grant @bindroot, @ren
    Privilege.priv_bind.grant @a, @ren
    assert_failing_overwriting_rebind '/bind2/r', '/bind2/a/b', @r, @b, 403, 'ren'

    @controller.reset
    Privilege.priv_unbind.grant @a, @ren
    assert_successful_overwriting_rebind '/bind2/r', '/bind2/a/b', @r, @b, 'ren'
  end
  
  
  # helpers

  def bind_body(segment, href_path) request_body "bind", segment, href_path; end
  def unbind_body(segment) request_body "unbind", segment; end
  def rebind_body(segment, href_path) request_body "rebind", segment, href_path; end

  def request_body(method, segment, href_path = nil)
    body = <<EOS
<D:#{method} xmlns:D="DAV:">
  <D:segment>#{segment}</D:segment>
EOS
    body << "  <D:href>http://test.host#{href_path}</D:href>" unless href_path.nil?
    body << "</D:#{method}>"
  end


  def assert_rebind_status(src, dest, status, principal = 'limeberry')
    @request.body = rebind_body File.basename(dest), src
    rebind File.dirname(dest), principal
    assert_response status
  end

  def assert_rebind_common(resource, valid_path, invalid_path)
    assert_nothing_raised(ActiveRecord::RecordNotFound) { resource.reload }
    assert_equal 1, resource.binds.size

    assert_raise(NotFoundError) { Bind.locate invalid_path }
    assert_nothing_raised(NotFoundError) do
      assert_equal resource, Bind.locate(valid_path)
    end
  end

  def assert_failing_rebind(src, dest, resource, status, principal = 'limeberry')
    assert_rebind_status src, dest, status, principal
    assert_rebind_common resource, src, dest
  end
  
  def assert_successful_rebind(src, dest, resource, principal = 'limeberry')
    assert_rebind_status src, dest, 201, principal
    assert_rebind_common resource, dest, src
  end

  def assert_failing_overwriting_rebind(src, dest, src_res, dest_res, status, principal = 'limeberry')
    assert_rebind_status src, dest, status, principal
    assert_valid_mappings src => src_res, dest => dest_res
  end

  def assert_successful_overwriting_rebind(src, dest, src_res, dest_res, principal = 'limeberry')
    assert_rebind_status src, dest, 200, principal
    assert_raise(ActiveRecord::RecordNotFound) { dest_res.reload }
    assert_raise(NotFoundError) { Bind.locate src }
    assert_valid_mappings dest => src_res
  end

  def assert_valid_mappings(mappings)
    mappings.each do |path, r|
      assert_nothing_raised(ActiveRecord::RecordNotFound, NotFoundError) do
        assert_equal r.reload, Bind.locate(path)
      end
    end
  end    
  
end
