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
require 'stringio'
require  File.dirname(__FILE__) + '/../../lib/errors'

class CollectionTest < DavTestCase

  def setup
    super
    @collectionpath = "/dir"
    @src_content = "content"
    @resourcepath = "/dir/src"

    @collection = Bind.locate(@collectionpath)
    @resource = Bind.locate(@resourcepath)

    @joe = User.find_by_name('joe')

    @dir1 = Bind.locate "/dir1"
    @dir2 = Bind.locate "/dir2"
    @dir3 = Bind.locate "/dir2/dir3"
    @res = Bind.locate "/dir2/res"
  end
  
  def test_mkcol_p
    Collection.mkcol_p("/a/b/c", @limeberry)
    assert_nothing_raised() {
      Bind.locate("/a")
      Bind.locate("/a/b")
      Bind.locate("/a/b/c")
    }
    util_put '/a/d', '012345'
    assert_raise(MethodNotAllowedError) {
      Collection.mkcol_p("/a/d/c", @limeberry)
    }
    assert_nothing_raised(MethodNotAllowedError) {
      Collection.mkcol_p("/a/b/d", @limeberry)
    }
    assert_nothing_raised() { Bind.locate("/a/b/d") }
  end

  def test_bind_and_set_acl_parent
    assert_equal @collection, @resource.acl_parent
    @root.bind_and_set_acl_parent(@resource, "src", @limeberry)
    assert_equal @root, @resource.acl_parent
  end

  def test_bind_simple
    num_original_binds = @root.children.length
    status = @root.bind(@resource,"newbind", @limeberry)
    assert_not_nil(Bind.find_by_name("newbind"))
    assert_equal(Bind.locate("/newbind"),@resource)
    assert_equal(status.code,201)
    @root.reload
    assert_equal(num_original_binds+1, @root.children.length)
    assert_equal 2, @resource.parents.length
  end
  
  def test_bind_overwrite
    util_put '/resource1', 'abcd'
    num_original_binds = @root.children.length
    status = @root.bind(@resource, "resource1", @limeberry)
    assert_equal(Bind.locate("/resource1"),@resource)
    assert_equal(status.code,200)
    @root.reload
    assert_equal(num_original_binds, @root.children.length)
  end

  def test_bind_recreate_error
    assert_raise(PreconditionFailedError) {
      @collection.bind(@resource, "src", @limeberry, false)
    }
  end
  
  def test_bind_privilege
    assert_raise(ForbiddenError) {
      @collection.bind(@resource,"newbind", @joe)
    }
    Privilege.priv_bind.grant(@collection,@joe)
    assert_nothing_raised() {
      @collection.bind(@resource,"newbind", @joe)
    }
    assert_equal(Bind.locate("/dir/newbind"),@resource)
  end

  def test_bind_overwrite_privilege
    res = Resource.create!(:creator => @joe)
    Privilege.priv_bind.grant(@collection,@joe)
    assert_raise(ForbiddenError) {
      @collection.bind(res, "src", @joe)
    }
    Privilege.priv_unbind.grant(@collection,@joe)
    assert_nothing_raised() {
      @collection.bind(@resource, "newbind", @joe)
    }
    assert_equal(Bind.locate("/dir/newbind"),@resource)
  end

  def test_bind_garbage_collection
    @root.bind(@dir2,"dir", @limeberry)
    assert_raise(NotFoundError) { Bind.locate("/dir/src") }
  end

  def test_bind_to_locked_collection
    lock = create_lock("/dir1")
    
    assert_raise(LockedError) {
      @dir1.bind(@dir2, "dir2", @limeberry)
    }
    
    assert_nothing_raised(LockedError) {
      @dir1.bind(@dir2, "dir2", @limeberry, true, lock.uuid)
    }
    
    assert_equal 1, @dir2.locks.length
    assert_equal 1, @res.locks.length
    assert_equal 1, @dir1.locks.length
  end
  
  def test_bind_to_depth0_locked_collection
    lock = create_lock("/dir1", @limeberry, 'X', '0')
    
    assert_raise(LockedError) {
      @dir1.bind(@dir2, "dir2", @limeberry)
    }
    
    assert_nothing_raised(LockedError) {
      @dir1.bind(@dir2, "dir2", @limeberry, true, lock.uuid)
    }
    
    assert_equal 0, @dir2.locks.length
    assert_equal 1, @dir1.locks.length
  end
  
  def test_bind_to_locked_collection_without_lock_privilege_on_resource
    Privilege.priv_all.grant @dir1, @joe
    
    lock = create_lock("/dir1", @joe)

    assert_raise(ForbiddenError) {
      @dir1.bind(@res, "res", @joe, true, lock.uuid)
    }
  end
  
  def test_bind_to_depth0_locked_collection_without_lock_privilege_on_resource
    Privilege.priv_all.grant @dir1, @joe
    
    lock = create_lock("/dir1", @joe, 'X', '0')

    assert_nothing_raised(ForbiddenError) {
      @dir1.bind(@res, "res", @joe, true, lock.uuid)
    }
  end
  
  def test_bind_to_indirectly_locked_collection
    lock = create_lock("/dir2")
    
    assert_raise(LockedError) {
      @dir3.bind(@dir1, "dir1", @limeberry)
    }
    
    assert_nothing_raised(LockedError) {
      @dir3.bind(@dir1, "dir1", @limeberry, true, lock.uuid)
    }
    
    assert_equal 1, @dir1.locks.length
  end
  
  def test_bind_locked_resource_to_locked_collection_fails
    lock1 = create_lock("/dir1")
    lock2 = create_lock("/dir2/res", @limeberry, 'X', '0')
    
    assert_raise(ConflictError) {
      @dir1.bind(@res, "res", @limeberry, true, lock1.uuid, lock2.uuid)
    }
  end
  
  def test_bind_locked_resource_to_locked_collection_shared_succeeds
    lock1 = create_lock("/dir1", @limeberry, 'S')
    lock2 = create_lock("/dir2/res", @limeberry, 'S', '0')

    assert_nothing_raised(ConflictError) {
      @dir1.bind(@res, "res", @limeberry, true, lock1.uuid, lock2.uuid)
    }
    
    assert_equal 2, @res.locks.length
  end
  
  def test_bind_resource_to_locked_collection_lock_owner_has_no_privilege
    Privilege.priv_all.grant @dir2, @joe
    
    lock1 = create_lock("/dir2", @joe, 'S')
    lock2 = create_lock("/dir2", @limeberry, 'S')

    assert_nothing_raised() {
      @dir3.bind(@dir1, "dir1", @limeberry, true, lock2.uuid)
    }
    
    assert_equal 2, @dir1.locks.length
    assert @dir1.locks.map{ |l| l.owner }.include?(@joe)
    assert !Privilege.priv_write_content.granted?(@dir1, @joe)
  end
  
  def test_locks_in_bind_overwrite_with_different_child_structure
    Collection.mkcol_p("/dir1/dir3", @limeberry)
    Collection.mkcol_p("/dir1/dir4", @limeberry)
    @dir2.bind(@dir3, "dir4", @limeberry)
    
    lock3 = create_lock("/dir1/dir3")
    lock4 = create_lock("/dir1/dir4")
    
    assert_raise(ConflictError) {
      @root.bind(@dir2, "dir1", @limeberry, true, lock3.uuid, lock4.uuid)
    }
  end
  
  def test_locks_transferred_in_bind_overwrite
    Privilege.priv_all.grant @root, @joe

    l0 = create_lock("/dir2/res", @limeberry, 'S', '0')
    l1 = create_lock("/dir2/res", @limeberry, 'S', '0')
    
    @root.bind(@res, "res", @limeberry)
    
    l2 = create_lock("/res", @limeberry, 'S', '0')
    
    assert_equal l1.resource, l2.resource
    
    assert_raise(LockedError) {
      @dir2.bind(@dir1, "res", @limeberry)
    }
    
    assert_raise(LockedError) {
      @dir2.bind(@dir1, "res", @joe, true, l0.uuid, l1.uuid, l2.uuid)
    }
    
    assert_raise(LockedError) {
      @dir2.bind(@dir1, "res", @limeberry, true, l2.uuid)
    }
    
    assert_nothing_raised() {
      @dir2.bind(@dir1, "res", @limeberry, true, l0.uuid)
    }
    
    assert_equal 1, Bind.locate("/res").locks.length
    assert_equal 2, Bind.locate("/dir2/res").locks.length
    
    l1.reload
    l2.reload
    assert_not_equal l1.resource, l2.resource
  end
  
  def test_locks_destroyed_in_bind_overwrite
    Privilege.priv_all.grant @root, @joe
    
    lock1 = create_lock("/dir2/res", @limeberry, 'S', '0')
    lock2 = create_lock("/dir2/res", @limeberry, 'S', '0')
    
    @root.bind(@dir2, "dir22", @limeberry)

    assert_raise(LockedError) {
      @root.bind(@dir1, "dir2", @limeberry, true, lock1.uuid)
    }
    assert_raise(LockedError) {
      @root.bind(@dir1, "dir2", @joe, true, lock1.uuid, lock2.uuid)
    }
    assert_nothing_raised() {
      @root.bind(@dir1, "dir2", @limeberry, true, lock1.uuid, lock2.uuid)
    }
    
    assert !Bind.locate("/dir22/res").locked?
  end
  
  def test_bind_overwrite_parent
    dir4 = Collection.mkcol_p("/dir2/dir3/dir4", @limeberry)
    
    l1 = create_lock("/dir1", @limeberry, 'S')
    l2 = create_lock("/dir2", @limeberry, 'S')
    l3 = create_lock("/dir2/dir3", @limeberry, 'S')
    l4 = create_lock("/dir2/dir3/dir4", @limeberry, 'S')
    
    @dir1.bind(@dir3, "dir3", @limeberry, true, l1.uuid)
    
    assert_nothing_raised() {
      @root.bind(@dir3, "dir2", @limeberry, true,
                 l2.uuid, l3.uuid, l4.uuid)
    }
    
    l2.reload
    assert_equal @dir3, l2.resource
    assert(!Lock.exists?(l3.id))
    assert(!Lock.exists?(l4.id))
  end
  
  def test_unbind_simple
    @root.unbind("dir2", @limeberry)
    assert !Bind.exists?("/dir2")
    assert !Bind.exists?("/dir2/dir3")
    assert Bind.exists?("/dir1")
  end
  
  def test_unbind_privilege
    assert_raise(ForbiddenError) {
      @collection.unbind("src", @joe)
    }
    Privilege.priv_unbind.grant @collection, @joe

    assert_nothing_raised { @collection.unbind("src", @joe) }
  end
  
  def test_unbind_parent_locked
    Privilege.priv_all.grant(@collection, @joe)

    lock = create_lock("/dir")
    
    assert_raise(LockedError) {
      @collection.unbind("src", @limeberry)
    }
    assert_raise(LockedError) {
      @collection.unbind("src", @joe)
    }
    assert_nothing_raised(LockedError) {
      @collection.unbind("src", @limeberry, lock.uuid)
    }
    assert_not_nil Lock.find_by_uuid(lock.uuid)
  end
  
  def test_unbind_descendant_locked_through_bind
    Privilege.priv_all.grant(@root, @joe)
    lock = create_lock("/dir/src")
    assert_raise(LockedError) { @root.unbind("dir", @limeberry) }
    assert_raise(LockedError) { @root.unbind("dir", @joe, lock.uuid) }
    assert_nothing_raised(LockedError) { @root.unbind("dir", @limeberry, lock.uuid) }
    assert_nil Lock.find_by_uuid(lock.uuid)
  end
  
  def test_unbind_descendant_locked_through_different_bind
    @root.bind(@resource, "src", @limeberry)
    lock = create_lock("/src")
    @collection.unbind("src", @limeberry, lock.uuid)
    assert_not_nil Lock.find_by_uuid(lock.uuid)
  end
  
  def test_rebind_simple
    assert_nothing_raised() { @root.rebind 'dir1', '/dir', @limeberry }
    assert Bind.exists?("/dir1")
    assert Bind.exists?("/dir1/src")
    assert !Bind.exists?("/dir")
  end
  
  def test_rebind_privilege
    assert_raise(ForbiddenError) { 
      @root.rebind 'src', '/dir/src', @joe
    }
    
    Privilege.priv_bind.grant @root, @joe
    assert_raise(ForbiddenError) { @root.rebind 'src', '/dir/src', @joe }
    
    Privilege.priv_bind.ungrant @root, @joe
    Privilege.priv_unbind.grant @collection, @joe
    assert_raise(ForbiddenError) { @root.rebind 'src', '/dir/src', @joe }
    
    Privilege.priv_bind.grant @root, @joe
    assert_nothing_raised(ForbiddenError) { @root.rebind 'src', '/dir/src', @joe }
  end
  
  def test_rebind_overwrite_false
    assert_raise(PreconditionFailedError){ @root.rebind 'dir1', '/dir/src', @limeberry, false }
    assert Bind.exists?("/dir/src")
  end
  
  def test_rebind_overwrite_true
    assert_nothing_raised(PreconditionFailedError){ @root.rebind 'dir1', '/dir/src', @limeberry }
    assert !Bind.exists?("/dir/src")
  end
  
  def test_rebind_ancestor_in_descendant
    # @dir2 is rebound to one of its descendants,
    # effectively disconnecting all the resources under it
    assert_nothing_raised() { @dir3.rebind 'dir2_in3', '/dir2', @limeberry }
    
    [@dir2, @dir3, @res].each { |r|
      assert_raise(ActiveRecord::RecordNotFound) {
        r.reload
      }
    }
  end
  
  def test_rebind_descendant_in_ancestor
    Collection.mkcol_p("/dir2/dir3/dir4", @limeberry)
    assert_nothing_raised() { @root.rebind 'dir2', '/dir2/dir3', @limeberry }
    assert !Bind.exists?("/dir2/dir3")
    assert !Bind.exists?("/dir2/res")
    assert Bind.exists?("/dir2/dir4")
  end
  
  def test_rebind_source_and_target_same
    assert_raise(ForbiddenError) { @collection.rebind 'src', '/dir/src', @limeberry }
  end
  
  def test_rebind_method_nonexistent_source
    assert_raise(ConflictError) { @root.rebind 'xyz', '/dir/abc', @limeberry }
  end
  
  def test_rebind_source_parent_not_collection
    assert_raise(ConflictError) { @root.rebind 'xyz', '/dir/src/abc', @limeberry }
  end
  
  def test_copy_infinite_to_descendant
    Collection.mkcol_p("/a/b", @limeberry)
    util_put '/a/a1', 'a1'
    util_put '/a/b/b1', 'b1'

    a = Bind.locate("/a")
    a.copy("/a/b/a", @limeberry, "infinity")

    a_in = nil
    assert_nothing_raised(NotFoundError) {
      a_in = Bind.locate("/a/b/a")
    }
    assert a_in.childbinds.length == 2

    b_in = nil
    assert_nothing_raised() {
      a_in.find_child_by_name("a1")
      b_in = a_in.find_child_by_name("b")
    }

    assert b_in.childbinds.length == 1
    assert_nothing_raised() {
      b_in.find_child_by_name("b1")
    }

    Bind.locate('/a/b/a').destroy

    Collection.mkcol_p("/a/b/a", @limeberry)
    util_put '/a/b/a/a2', 'a2'
    a.copy("/a/b/a", @limeberry, "infinity")

    a_in = nil
    assert_nothing_raised() {
      a_in = Bind.locate("/a/b/a")
    }
    assert a_in.childbinds.length == 2

    b_in = nil
    assert_nothing_raised() {
      a_in.find_child_by_name("a1")
      b_in = a_in.find_child_by_name("b")
    }

    assert b_in.childbinds.length == 2
    a_in_in = nil
    assert_nothing_raised() {
      b_in.find_child_by_name("b1")
      a_in_in = b_in.find_child_by_name("a")
    }

    assert a_in_in.childbinds.length == 1
    assert_nothing_raised() {
      a_in_in.find_child_by_name("a2")
    }


    Bind.locate('/a/b/a').destroy

    util_put '/a/b/a', 'a'
    a.copy("/a/b/a", @limeberry, "infinity")

    a_in = nil
    assert_nothing_raised() {
      a_in = Bind.locate("/a/b/a")
    }
    assert a_in.childbinds.length == 2

    b_in = nil
    assert_nothing_raised() {
      a_in.find_child_by_name("a1")
      b_in = a_in.find_child_by_name("b")
    }
    assert b_in.childbinds.length == 2

    a_in_in = nil
    assert_nothing_raised() {
      b_in.find_child_by_name("b1")
      a_in_in = b_in.find_child_by_name("a")
    }

    assert_equal a_in_in.body.stream.read, "a"
  end

  def test_copy_infinite_with_locks
    Collection.mkcol_p("/a",  @limeberry)
    util_put '/a/1.txt', '1'

    Collection.mkcol_p("/c", @limeberry)
    Collection.mkcol_p("/c/d", @limeberry)

    l0 = create_lock("/c", @limeberry, 'S')
    l1 = create_lock("/c/d", @limeberry, 'S')

    assert_raise(LockedError) {
      Resource.copy("/a", "/c/d", @limeberry)
    }

    assert_nothing_raised() {
      Resource.copy("/a", "/c/d", @limeberry,
                    'infinity', true, l1.uuid)
    }

    c1 = Bind.locate("/c/d/1.txt")
    assert c1.locks.include?(l1)

    assert_raise(LockedError) {
      Resource.copy("/a", "/c", @limeberry)
    }

    assert_nothing_raised(LockedError) {
      Resource.copy("/a", "/c", @limeberry, 'infinity', true, l0.uuid)
    }

    c1 = Bind.locate("/c/1.txt")
    assert c1.locks.include?(l0)
  end
  
  def test_check_descendants_lock_infinite_depth
    Privilege.priv_write_content.grant(@dir2, @joe)

    create_lock("/dir2/res", @limeberry, 'S', '0')
    create_lock("/dir2/dir3")
    
    error_map = @root.check_descendants_lock_infinite_depth(@joe, 'S')
    assert_equal ForbiddenError, error_map[@dir1].class
    assert_equal LockedError, error_map[@dir3].class
    assert !error_map.has_key?(@res)
  end
  
  def test_lock
    create_lock("/dir", @limeberry, 'S')
    create_lock("/dir", @limeberry, 'S')
    assert_equal 2, @collection.locks.length
    assert_equal 2, @resource.locks.length
    assert_equal 0, @resource.direct_locks.length
  end

  # move to functional tests
  #   def test_lock_and_unlock
  #     dav_setup
  #     opts = get_lock_args
  #     response1 = Resource.lock("/", opts)
  #     response2 = Resource.lock("/", opts)
  
  #     opts[:locktoken] = response1["Lock-Token"]
  #     Resource.unlock("/", opts)
  
  #     assert_equal 1, @root.direct_locks.length
  #     assert_equal 1, @collection.locks.length
  #     assert_equal 1, @resource.locks.length
  #   end
  
  def test_lock_collection_with_two_binds_to_same_resource
    @collection.bind @resource, 'src1', @limeberry
    create_lock "/dir"
    # is this done?
  end
  
  def test_lock_depth0
    create_lock("/dir", @limeberry, 'X', '0')
    assert_equal 1, @collection.locks.length
    assert_equal 0, @resource.locks.length
  end


  def test_lock_descendant_conflict
    lock1 = create_lock("/dir/src", @limeberry, 'S')

    assert_raise(ActiveRecord::RecordInvalid) do
      create_lock("/", @limeberry, 'X')
    end
    
    assert_equal 0, @root.locks.length
    assert_equal 0, @collection.locks.length
    assert_equal 1, @resource.locks.length
  end
  
  def test_lock_collection_conflict
    create_lock("/dir/src", @limeberry, 'S')

    assert_raise(ActiveRecord::RecordInvalid) do
      create_lock("/dir", @limeberry, 'X')
    end
    
    assert(!@collection.locked?)
    assert_equal(@resource.locks.length,1)

    assert_nothing_raised { create_lock("/dir", @limeberry, 'S') }
    
    @collection.reload
    @resource.reload
    assert(@collection.locked?)
    assert_equal(@resource.locks.length,2)
  end

  def test_find_child_by_name
    assert_equal @resource, @collection.find_child_by_name("src")
  end
  
  def test_parent_collection
    assert_raise(NotFoundError) {
      Collection.parent_collection("/absent/src")
    }
    assert_raise(NotFoundError) {
      Collection.parent_collection("/dir/src/abc")
    }
    par = nil
    assert_nothing_raised(NotFoundError) {
      par = Collection.parent_collection("/dir/src")
    }
    assert_equal @collection, par
  end
  
  def test_resourcetype
    out = ""
    xml = Builder::XmlMarkup.new(:target => out, :indent => 2)
    xml.instruct!

    @root.liveprops[PropKey.get('DAV:', 'resourcetype'), xml]
    
    expected_out = "<D:resourcetype><D:collection/></D:resourcetype>"
    assert_rexml_equal(expected_out, out)
  end
  
  def test_options
    expected_options = %w(COPY DELETE MOVE OPTIONS PROPFIND PROPPATCH LOCK UNLOCK BIND UNBIND REBIND ACL).sort
    assert_equal(expected_options, @root.options.sort)
  end
  
  
  def test_descendant_binds
    assert @dir1.descendant_binds.empty?
    dir2_desc_binds = @dir2.descendant_binds
    assert_equal 2, dir2_desc_binds.length
    assert dir2_desc_binds.include?(Bind.find_by_name("dir3"))
    assert dir2_desc_binds.include?(Bind.find_by_name("res"))
  end
  
  def test_descendants
    assert @dir1.descendant_binds.empty?
    dir2_descs = @dir2.descendants
    assert_equal 2, dir2_descs.length
    assert dir2_descs.include?(@dir3)
    assert dir2_descs.include?(@res)
  end
  
  def test_descendant_binds_with_path
    assert @dir1.descendant_binds_with_path("/dir1").empty?
    dir2_dbp = @dir2.descendant_binds_with_path("/dir2/")
    assert_equal 2, dir2_dbp.length
    assert dir2_dbp.has_key?(Bind.find_by_name("dir3"))
    assert dir2_dbp.has_key?(Bind.find_by_name("res"))
  end
  
  def test_descendant_binds_with_path_multiple_binds
    dir4 = Collection.mkcol_p("/dir2/dir3/dir4", @limeberry)
    dir4.bind @dir2, 'anscbind', @limeberry
    @dir2.bind dir4, 'newbind', @limeberry
    dir2_dbp = @dir2.descendant_binds_with_path("/dir2")
    assert_equal 5, dir2_dbp.length
    assert dir2_dbp.has_key?(Bind.find_by_name("dir3"))
    assert dir2_dbp.has_key?(Bind.find_by_name("dir4"))
    assert dir2_dbp.has_key?(Bind.find_by_name("res"))
    assert dir2_dbp.has_key?(Bind.find_by_name("anscbind"))
    assert dir2_dbp.has_key?(Bind.find_by_name("newbind"))
  end

  def test_supported_privilege_set
    expected = <<EOS
<D:supported-privilege-set>
  <D:supported-privilege>
    <D:privilege><D:all/></D:privilege>
    <D:description xml:lang="en">#{Privilege.priv_all.description}</D:description>
    <D:supported-privilege>
      <D:privilege><D:read/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:read-acl/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read_acl.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:read-current-user-privilege-set/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read_current_user_privilege_set.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write.description}</D:description>
      <D:supported-privilege>
        <D:privilege><D:write-properties/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_write_properties.description}</D:description>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege><D:bind/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_bind.description}</D:description>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege><D:unbind/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_unbind.description}</D:description>
      </D:supported-privilege>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write-acl/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write_acl.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:unlock/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_unlock.description}</D:description>
    </D:supported-privilege>
  </D:supported-privilege>
</D:supported-privilege-set>
EOS
    setup_xml
    @collection.supported_privilege_set @xml
    assert_rexml_equal expected, @xml_out
  end
  
  
end
