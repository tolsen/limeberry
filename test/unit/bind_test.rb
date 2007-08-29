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

class BindTest < DavUnitTestCase

  def setup
    super

    @bind = Bind.locate("/bind")
    @bind_bind = @root.childbinds.find_by_name 'bind'

    @a_bind, @a, @r_bind, @r, @j_bind, @j = %w( a r j ).map { |l|
      [@bind.childbinds.find_by_name(l), Bind.locate("/bind/#{l}")]
    }.flatten

    @bind_bind_j = @j.childbinds.find_by_name 'bind'
  end
  

  def test_create
    assert_not_nil(@r)
    assert_not_nil(@r_bind)
    assert_equal(@r, @r_bind.child)
    assert_equal(@bind, @r_bind.parent)
    assert_equal('r', @r_bind.name)
  end

  def test_root_collection
    assert_not_nil @root
    assert_match(Bind::ROOT_COLLECTION_UUID, @root.uuid )
  end

  def test_locate
    b = Collection.mkcol_p('/bind/a/b', @limeberry)
    
    r = Bind.locate("/bind/a/b")
    assert_equal b, r
    binds = r.path_binds
    assert_equal @root.childbinds.find_by_name("bind"), binds[0]
    assert_equal @bind.childbinds.find_by_name("a"), binds[1]
    assert_equal @a.childbinds.find_by_name("b"), binds[2]
  end
  
  def test_locate_root
    r = Bind.locate("/")
    assert_equal @root, r
    assert_equal [], r.path_binds
  end
  
  def test_find_acyclic_paths_one_path_no_cycles
    # /bind/a/b/c/d/e
    Collection.mkcol_p("/bind/a/b/c/d", @limeberry)
    util_put '/bind/a/b/c/d/e', 'hello'

    e = Bind.locate("/bind/a/b/c/d/e")
    assert_equal ["/bind/a/b/c/d/e"], Bind.find_all_acyclic_paths_to(e)
    assert_equal "/bind/a/b/c/d/e", Bind.find_any_acyclic_path_to(e)
  end


  #tests the garbage collector
  #/bind/a is C1 and /bind/a/b is R1
  # on unbind /bind/a, C1, R1, and bind 'b' should be destroyed along with bind 'a'
  def test_garbage_collector
    util_put '/bind/a/b', 'hello'
    b = Bind.locate("/bind/a/b")

    @bind.unbind("a", @limeberry)

    assert_nil @bind.find_child_by_name("a")
    assert_nil @bind.find_child_by_name("b")

    assert_raise(ActiveRecord::RecordNotFound) { @a.reload }
    assert_raise(ActiveRecord::RecordNotFound) { b.reload }
  end

  #test garbage collector when there is a cycle
  #suppose /bind/a and /bind/a/selfbind both point to C1 and we unbind /bind/a,
  #bind 'a',bind 'selfbind' and C1 should be destroyed
  def test_garbage_collector_with_cycle
    @a.bind(@a,"selfbind", @limeberry)

    @bind.unbind("a", @limeberry)

    assert_nil @bind.find_child_by_name("a")
    assert_nil @bind.find_child_by_name("selfbind")

    assert_raise(ActiveRecord::RecordNotFound) {
      @a.reload
    }
  end

  def test_garbage_collector_is_not_too_eager
    util_put '/bind/a/b', 'hello'
    @a.unbind 'b', @limeberry
    assert(Bind.exists?("/bind/a"))
  end
  
  def test_with_garbage_collection_off
    b = Collection.mkcol_p("/bind/a/b", @limeberry)
    Bind.with_garbage_collection_off {
      @bind.unbind("a", @limeberry)
    }
    assert_nil @bind.childbinds.find_by_name("a")
    assert_not_nil @a.childbinds.find_by_name("b")
    assert_nothing_raised {
      @a.reload
      b.reload 
    }
    assert Bind.garbage_collection_on?

    begin
      Bind.with_garbage_collection_off { raise Exception }
    rescue Exception
    end
    assert Bind.garbage_collection_on?
  end

  def test_find_acyclic_paths_multiple_paths
    # /bind/a/b/c/d/e
    # /bind/a/f/g is bound to /bind/a/b/c
    # /bind/a/b/c/h/i is bound to /bind/a/b/c/d/e

    #   b   d
    #  / \c/ \e
    # a   X   >
    #  \ /g\ /i
    #   f   h

    # there are 4 paths to e:
    # /bind/a/b/c/d/e
    # /bind/a/b/c/h/i
    # /bind/a/f/g/d/e
    # /bind/a/f/g/h/i

    f = Collection.mkcol_p("/bind/a/f", @limeberry)
    d = Collection.mkcol_p("/bind/a/b/c/d", @limeberry)
    h = Collection.mkcol_p("/bind/a/b/c/h", @limeberry)

    e = util_put '/bind/a/b/c/d/e', 'hello'
    f.bind Bind.locate('/bind/a/b/c'), 'g', @limeberry
    h.bind e, 'i', @limeberry

    e = Bind.locate("/bind/a/b/c/d/e")

    expected = ["/bind/a/b/c/d/e",
                "/bind/a/b/c/h/i",
                "/bind/a/f/g/d/e",
                "/bind/a/f/g/h/i"]

    assert_equal expected.sort, Bind.find_all_acyclic_paths_to(e).sort
    assert expected.include?(Bind.find_any_acyclic_path_to(e))

    # now bind /bind/a/b/c/d/j to /bind/a/b (forming a cycle)
    #    ____
    #   /    \
    #   |     j
    #  \|/   /
    #   b   d
    #  / \c/ \e
    # a   X   >
    #  \ /g\ /i
    #   f   h

    d.bind Bind.locate('/bind/a/b'), 'j', @limeberry

    # there should still only be 4 paths
    assert_equal expected.sort, Bind.find_all_acyclic_paths_to(e).sort
    assert expected.include?(Bind.find_any_acyclic_path_to(e))
  end

  def test_find_any_acyclic_path_to
    Collection.mkcol_p("/bind/a/b/c/d", @limeberry)
    col = Bind.locate("/bind/a/b/c/d")
    assert_equal "/bind/a/b/c/d", Bind.find_any_acyclic_path_to(col)
  end

#   def test_full_path_detailed
#     Collection.mkcol_p("/bind/a/b/c/d", @limeberry)
#     col = Bind.locate("/bind/a/b/c/d")

#     path, url_lastmodified, *binds = col.binds[0].full_path_detailed

#     assert_equal "/bind/a/b/c/d", path
#     assert_in_delta(Time.now, url_lastmodified, 60)
#     assert_equal 5, binds.size

#     assert_equal %w(bind a b c d), binds.map{ |b| b.name }
#   end

#   def test_prune_directory_sane_acl_inheritance
#     util_put '/bind/a/b', 'hello'

#     Resource.dav_delete("/bind/a", @limeberry)

#     # not finished yet
#   end


  def test_exists_with_garbage_collection
    Collection.mkcol_p("/bind/a/b", @limeberry)
    
    @bind.unbind 'a', @limeberry
    assert(!Bind.exists?("/bind/a/b"))
  end

  def test_exists
    assert(Bind.exists?('/bind/r'))
    assert(!Bind.exists?('/bind/r2'))
  end

  def test_locks_impede_bind_deletion
    # need to locate r in order to set path_binds and url
    r = Bind.locate('/bind/r')
    lock = Lock.create!( :owner => @limeberry,
                         :scope => 'X',
                         :depth => '0',
                         :expires_at => Time.now + 5.years,
                         :resource => r )
    
    joe = User.find_by_name 'joe'
    assert @r_bind.locks_impede_bind_deletion?(@limeberry)
    assert !@r_bind.locks_impede_bind_deletion?(@limeberry, lock.uuid)
    assert @r_bind.locks_impede_bind_deletion?(joe, lock.uuid)
  end

  def test_locks_impede_bind_deletion_shared_locks
    lock_a, lock_r1, lock_r2 = %w( a r r ).map do |name|
      Lock.create!(:lock_root => "/bind/#{name}",
                   :scope => 'S',
                   :depth => '0',
                   :expires_at => Time.now + 5.years,
                   :owner => @limeberry)
    end

    assert @bind_bind.locks_impede_bind_deletion?(@limeberry, lock_a.uuid)
    assert @bind_bind.locks_impede_bind_deletion?(@limeberry, lock_r1.uuid)
    assert @bind_bind.locks_impede_bind_deletion?(@limeberry, lock_r2.uuid)
    assert !@bind_bind.locks_impede_bind_deletion?(@limeberry, lock_a.uuid, lock_r1.uuid)
    assert !@bind_bind.locks_impede_bind_deletion?(@limeberry, lock_a.uuid, lock_r2.uuid)
  end

  def test_children_empty
    assert(Bind.children.empty?)
  end

  def test_children_one
    b = Resource.create!(:displayname => 'b')
    @a.bind(b, 'b', @limeberry)
    b_bind = @a.childbinds.find_by_name('b')
    assert_equal([b_bind], Bind.children(@a_bind))
  end

  def test_children_two
    b = Resource.create!(:displayname => 'b')
    c = Resource.create!(:displayname => 'c')

    @a.bind(b, 'b', @limeberry)
    @a.bind(c, 'c', @limeberry)

    expected_binds = @a.childbinds.sort_by{|b|b.id}
    actual_binds = Bind.children(@a_bind).sort_by{|b|b.id}

    assert_equal(expected_binds, actual_binds)
  end

  def test_children_two_collections
    Collection.mkcol_p('/bind/b', @limeberry)
    b = Bind.locate('/bind/b')
    c = Resource.create!(:displayname => 'c')
    d = Resource.create!(:displayname => 'd')

    @a.bind(c, 'c', @limeberry)
    b.bind(d, 'd', @limeberry)

    top_binds = ['a', 'b'].map do |name|
      @bind.childbinds.find_by_name(name)
    end

    expected_binds =
      [ @a.childbinds.find_by_name('c'),
        b.childbinds.find_by_name('d') ].sort_by{|b|b.id}

    actual_binds = Bind.children(*top_binds).sort_by{|b|b.id}

    assert_equal(expected_binds, actual_binds)
  end

  def test_descendants_empty
    assert(Bind.descendants.empty?)
  end

  def test_descendants_one
    b = Resource.create!(:displayname => 'b')
    @a.bind(b, 'b', @limeberry)
    b_bind = @a.childbinds.find_by_name('b')
    assert_equal([b_bind], Bind.descendants(@a_bind).to_a)
  end

  def test_descendants_two
    b = Resource.create!(:displayname => 'b')
    c = Resource.create!(:displayname => 'c')

    @a.bind(b, 'b', @limeberry)
    @a.bind(c, 'c', @limeberry)

    expected_binds = @a.childbinds.sort_by{|b|b.id}
    actual_binds = Bind.descendants(@a_bind).to_a.sort_by{|b|b.id}
    assert_equal(expected_binds, actual_binds)
  end

  def test_descendants_two_collections
    Collection.mkcol_p('/bind/b', @limeberry)
    b = Bind.locate('/bind/b')
    c = Resource.create!(:displayname => 'c')
    d = Resource.create!(:displayname => 'd')

    @a.bind(c, 'c', @limeberry)
    b.bind(d, 'd', @limeberry)

    top_binds = ['a', 'b'].map do |name|
      @bind.childbinds.find_by_name(name)
    end

    expected_binds =
      [ @a.childbinds.find_by_name('c'),
        b.childbinds.find_by_name('d') ].sort_by{|b|b.id}

    actual_binds = Bind.descendants(*top_binds).to_a.sort_by{|b|b.id}

    assert_equal(expected_binds, actual_binds)
  end

  def test_child_resources_empty
    assert(Bind.child_resources.empty?)
  end

  def test_child_resources_one_bind
    assert_equal([Bind.locate('/bind/a')],
                 Bind.child_resources(@a_bind))
  end

  def test_child_resources_two_binds
    Collection.mkcol_p('/bind/b', @limeberry)

    binds = ['a', 'b'].map do |name|
      @bind.childbinds.find_by_name(name)
    end

    expected_resources = [ @a, Bind.locate('/bind/b') ].sort_by{|r|r.id}

    actual_resources = Bind.child_resources(*binds).sort_by{|r|r.id}

    assert_equal(expected_resources, actual_resources)
  end

  def test_child_resources_two_binds_to_same_resource
    b = Resource.create!(:displayname => 'b')

    @a.bind(b, 'b1', @limeberry)
    @a.bind(b, 'b2', @limeberry)

    assert_equal([b], Bind.child_resources(*(@a.childbinds)))
  end

  def test_child_resources_two_binds_to_same_resource_different_parents
    Collection.mkcol_p('/bind/b', @limeberry)
    b = Bind.locate('/bind/b')
    
    c = Resource.create!(:displayname => 'c')

    @a.bind(c, 'c', @limeberry)
    b.bind(c, 'c', @limeberry)

    assert_equal([c], Bind.child_resources(*(@a.childbinds +
                                             b.childbinds)))
  end

  def test_paths_dependent_destroy
    @bind.bind(@r, 'r2', @limeberry)
    p = Path.create!(:url => '/bind/r')
    @r_bind.destroy
    assert_raise(ActiveRecord::RecordNotFound) { p.reload }
  end

  def test_update_destroys_paths
    p = Path.create!(:url => '/bind/r')
    @r_bind.name = 'r2'
    @r_bind.save!
    assert_raise(ActiveRecord::RecordNotFound) { p.reload }
  end

  def test_invalid_names
    [ ".", "..", "", "/", "?", "#", "%", "%%",
      "%0Z", "[", "]", " ", "bad name" ].each do |name|
      assert_raise(ActiveRecord::RecordInvalid, name) do
        Bind.create! :parent => @bind, :child => @r, :name => name
      end
    end
  end

  def test_valid_names
    [ "...", ".t", "..t", "!", "$", "&", "'",
      "(", ")", "*", "+", ",", ";", "=", ":",
      "@", "%20", "%0d", "%0E", "%54" ].each do |name|
      assert_nothing_raised(ActiveRecord::RecordInvalid, name) do
        Bind.create! :parent => @bind, :child => @r, :name => name
      end
    end
  end

  def test_normalize_name
    assert_equal "t", Bind.normalize_name("%74")
    assert_equal "~", Bind.normalize_name("%7e")
    assert_equal "good%20name", Bind.normalize_name("%67%6f%6F%64%20%6E%61%6d%65")
    valid_chars = "._~!$&'()*+,;=:@-"
    escaped_valid_chars = valid_chars.split(//).map{ |x| "%#{x[0].to_s(16)}" }.join ''
    assert_equal valid_chars, Bind.normalize_name(escaped_valid_chars)
  end

  def test_locate_binds_sanity
    assert @a_bind.id < @j_bind.id, "a should be bound before j is in order to properly test"
  end
  
  def test_locate_binds_order
    new_a = Bind.locate '/bind/j/bind/a'
    # it's easier to see what's wrong in a failing test if we just compare id's
    assert_equal([ @bind_bind, @j_bind, @bind_bind_j, @a_bind ].map{ |b| b.id },
                 new_a.path_binds.map{|b| b.id})
  end

  def test_locate_binds_cycle
    new_j = Bind.locate '/bind/j/bind/j'
    assert_equal([ @bind_bind, @j_bind, @bind_bind_j, @j_bind ].map{ |b| b.id },
                 new_j.path_binds.map{|b| b.id})
  end

  def test_locate_url_lastmodified
    Collection.mkcol_p "/bind/a/b", @limeberry
    b = Bind.locate "/bind/a/b"
    assert_in_delta Time.now, b.url_lastmodified, 60
  end

end
