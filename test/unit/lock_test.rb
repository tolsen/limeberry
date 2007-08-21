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

class LockTest < DavTestCase

  def setup
    super

    @a = Bind.locate '/lock/a'
    @owner_info = "<href>http://dav.limedav.com/principals/limeberry</href>"
    @lock_a = @a.locks[0]

    @b = Bind.locate '/lock/b'
    @lock_b = @b.locks[0]

    @lockrootdir = Bind.locate '/lock'

    @expired = Resource.create!(:displayname => 'expired')
    @lockrootdir.bind(@expired, 'expired', @limeberry)
    @expired_lock = Lock.create!( :owner => @limeberry,
                                  :scope => 'X',
                                  :depth => '0',
                                  :expires_at => Time.now,
                                  :lock_root => '/lock/expired' )

    @c = Bind.locate('/lock/c')
    @z = Bind.locate('/lock/c/z')

    @joe = User.find_by_name 'joe'
  end

  # TODO: test Lock#activelock
  
  def test_create
    assert_equal(@a, @lock_a.resource)
    assert_equal(@limeberry, @lock_a.owner)
    assert_equal('X', @lock_a.scope)
    assert_equal('0', @lock_a.depth)
    assert_equal(Time.gm(2030), @lock_a.expires_at)
    assert_equal(@owner_info, @lock_a.owner_info)

    expected_binds = [@a.binds[0], @lockrootdir.binds[0]].sort_by{ |b| b.id }
    actual_binds = @lock_a.binds.sort_by{ |b| b.id }
    assert_equal(expected_binds, actual_binds )
  end
  
  def test_set_owner
    @lock_a.owner = @joe
    @lock_a.save!
    
    assert_equal(@joe, @lock_a.owner)
  end
  

  def test_token_given
    assert !@lock_a.token_given?
    assert !@lock_a.token_given?("11111")
    assert @lock_a.token_given?("11111", @lock_a.uuid)
  end

  def test_token_given_and_owned
    assert !@lock_a.token_given_and_owned?(@limeberry)
    assert @lock_a.token_given_and_owned?(@limeberry, "11111", @lock_a.uuid)

    assert !@lock_a.token_given_and_owned?(@joe, "11111", @lock_a.uuid)
  end

  # move to functional tests
  #   def test_unlock_expired_lock
  #     assert_raise(ConflictError) do
  #       Resource.unlock('/lock/expired', @limeberry, @expired_lock.uuid)
  #     end
  
  #   end

#   def test_expired_child
#     Collection.mkcol('/lock/d', @limeberry)
#     d = Bind.locate('/lock/d')
#     e = Resource.create!(:displayname => 'e')
#     d.bind(e, 'e', @limeberry)

#     Lock.create!( :owner => @limeberry,
#                   :scope => 'X',
#                   :depth => '0',
#                   :expires_at => Time.now,
#                   :resource => Bind.locate('/lock/d/e') )

    
#     assert_nothing_raised(LockedError) {
#       Resource.dav_delete("/lock/d", @limeberry)
#     }
#   end

  def test_lock_expired
    assert @expired.locks.empty?
    assert !(@expired.locks_impede_modify?(@limeberry))
  end



  def test_move_transfer_locks
    Resource.move('/lock/c', '/lock/b', @limeberry, true, @lock_b.uuid)
    b = Bind.locate('/lock/b')
    assert b.locked_with?(@lock_b.uuid)
  end

  def test_move_expired_lock
    assert_nothing_raised() {
      Resource.move("/lock/c", "/lock/expired", @limeberry)
    }
    assert !(Bind.locate("/lock/expired").locked?)
  end

  def test_move_target_locked
    assert_raise(LockedError) {
      Resource.move("/lock/c","/lock/a", @limeberry)
    }
    assert_nothing_raised(LockedError) {
      Resource.move("/lock/c","/lock/a", @limeberry, true, @lock_a.uuid)
    }
  end
  

  def test_move_source_locked
    assert_raise(LockedError) {
      Resource.move("/lock/a","/lock/c",@limeberry)
    }
    assert_nothing_raised(LockedError) {
      Resource.move("/lock/a","/lock/c", @limeberry, true, @lock_a.uuid)
    }
  end

  def test_move_target_and_source_locked
    assert_nothing_raised(ConflictError) do
      Resource.move("/lock/a","/lock/b", @limeberry, true, @lock_a.uuid, @lock_b.uuid)
    end
    
    assert_raise(ActiveRecord::RecordNotFound) do
      @lock_a.reload
    end

    assert_nothing_raised(ActiveRecord::RecordNotFound) do
      assert_equal [@lock_b.reload], @a.reload.locks
    end
  end
  
  
  # suppose we move /dir/subdir to /subdir then,
  #        root                                         root
  #        / \                                          /  \
  #     dir  subdir                -------------->    dir  subdir
  #      /     \                  (move /dir/subdir         \
  #   subdir   subres (l1:lock)     to /subdir)             subres (l1:lock)
  #     /
  #   subres

  def test_move_transfer_child_locks
    #create structure
    Collection.mkcol_p("/lock/dir/subdir", @limeberry)
    subdir = Bind.locate("/lock/dir/subdir")
    subres = Resource.create!(:displayname => 'subres')
    subdir.bind(subres, "subres", @limeberry)
    Resource.copy("/lock/dir/subdir","/lock/subdir", @limeberry)
    
    #lock /subdir/subres
    lock = create_lock("/lock/subdir/subres")

    #now move, without locktoken of /subdir/subres, LockedError should be raised
    assert_raise(LockedError) {
      Resource.move("/lock/dir/subdir","/lock/subdir", @limeberry)
    }

    #finally the move with the appropriate locktoken
    assert_nothing_raised(LockedError) {
      Resource.move("/lock/dir/subdir","/lock/subdir", @limeberry,
                    true, lock.uuid)
    }

    assert_raise(NotFoundError) {
      Bind.locate("/lock/dir/subdir")
    }
    
    resource = Bind.locate("/lock/subdir/subres")

    assert(resource.locked_with?(lock.uuid))

  end


  def test_lock_conflicts
    assert_raise(LockedError) do
      create_lock("/lock/a")
    end
  end

  def test_lock_depth_one
    assert_raise(ActiveRecord::RecordInvalid) do
      create_lock("/lock/c", @limeberry, 'X', '1')
    end
  end


  def test_lock_write_privilege
    assert_raise(ForbiddenError) { create_lock("/lock/c/z", @joe) }

    Privilege.priv_write_content.grant(@z, @joe)
    assert_nothing_raised(ForbiddenError) { create_lock("/lock/c/z", @joe) }
  end

  def test_lockable
    lock = create_lock("/lock/c/z", @limeberry, 'S')
    assert_raise_while_asserting_lockable(ForbiddenError, 'S')
    Privilege.priv_write_content.grant @z, @joe

    assert_nothing_raised(ForbiddenError) do
      @z.assert_lockable(@joe, 'S')
    end
    
    assert_raise_while_asserting_lockable(LockedError, 'X')
    lock.destroy
    lock = create_lock("/lock/c/z")
    @z.reload
    assert_raise_while_asserting_lockable(LockedError, 'S')
    assert_raise_while_asserting_lockable(LockedError, 'X')
  end

  def assert_raise_while_asserting_lockable(error, lockscope)
    assert_raise(error) do
      @z.assert_lockable(@joe, lockscope)
    end
  end

  def test_locked_infinite
    create_lock('/lock/c')

    assert @c.locked?
    assert @z.locked?
  end

  # TODO: move to functional tests
  #   def test_locked_empty_resource
  #     lock_args = get_lock_args
  #     lock_args[:depth] = "0"
  #     AppConfig.lock_unmapped_url = "LER"

  #     response = Resource.lock("/lock/emptyfile",lock_args)
  #     assert_equal 201, response.status.code

  #     emptyresource = Bind.locate("/lock/emptyfile")
  #     response = Resource.put("/lock/emptyfile", StringIO.new("123456"),
  #                                  "text/plain", :principal => @limeberry,
  #                                  :if_locktokens => [emptyresource.locks[0].uuid])
  #     assert_equal 204, response.status.code
  #     assert(emptyresource.locked?)
  #   end

  def test_locks_association_functions
    l1 = create_lock("/lock/c", @limeberry, 'S', 'I')
    l2 = create_lock("/lock/c", @limeberry, 'S', '0')
    l3 = create_lock("/lock/c", @limeberry, 'S', 'I')

    lokarr = @c.locks.depth_infinity
    assert(lokarr.include?(l1))
    assert(lokarr.include?(l3))
    assert_equal(lokarr.length, 2)
  end

  def test_move_shared_locked_parent
    y = Resource.create!(:displayname => 'y')
    @lockrootdir.bind(y, 'y', @limeberry)
    
    l1 = create_lock("/lock/c", @limeberry, 'S')
    
    assert_raise(LockedError) {
      Resource.move('/lock/y','/lock/c/y', @limeberry)
    }
    assert_nothing_raised() {
      Resource.move('/lock/y','/lock/c/y', @limeberry, true, l1.uuid)
    }
  end
  
end
