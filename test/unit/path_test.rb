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
require 'test/unit/dav_unit_test'

class PathTest < DavUnitTestCase

  def test_create
    Collection.mkcol_p("/a", @limeberry)
    assert_nothing_raised { Path.create!( :url => "/a" ) }
    assert_only_valid_paths("/", "/a")
  end

  def test_create_parent
    Collection.mkcol_p("/a/b", @limeberry)
    assert_nothing_raised { Path.create!( :url => "/a/b") }
    assert_only_valid_paths("/", "/a", "/a/b")
  end

  def test_create_ancestors
    Collection.mkcol_p("/a/b/c", @limeberry)
    assert_nothing_raised { Path.create!( :url => "/a/b/c") }
    assert_only_valid_paths("/", "/a", "/a/b", "/a/b/c")
  end

  def test_create_parent_exists
    Collection.mkcol_p("/a/b", @limeberry)
    assert_nothing_raised do
      Path.create!(:url => "/a")
      Path.create!(:url => "/a/b")
    end
    assert_only_valid_paths("/", "/a", "/a/b")
  end

  def test_create_descendants
    Collection.mkcol_p("/a/b", @limeberry)
    Path.create!(:url => "/a").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b")
  end

  def test_create_descendants_grandchild
    Collection.mkcol_p("/a/b/c", @limeberry)
    Path.create!(:url => "/a").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b", "/a/b/c")
  end

  def test_create_descendants_grandchild_of_child
    Collection.mkcol_p("/a/b/c/d", @limeberry)
    Path.create!(:url => "/a/b").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b", "/a/b/c", "/a/b/c/d")
  end

  def test_create_descendants_greatgreatgrandchild
    Collection.mkcol_p("/a/b/c/d/e", @limeberry)
    Path.create!(:url => "/a").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b", "/a/b/c", "/a/b/c/d", "/a/b/c/d/e")
  end

  def test_create_descendants_children
    Collection.mkcol_p("/a/b", @limeberry)
    Collection.mkcol_p("/a/c", @limeberry)
    Path.create!(:url => "/a").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b", "/a/c")
  end

  def test_create_descendants_children_and_grandchildren
    Collection.mkcol_p("/a/b/d", @limeberry)
    Collection.mkcol_p("/a/b/e", @limeberry)
    Collection.mkcol_p("/a/c/f", @limeberry)
    Collection.mkcol_p("/a/c/g", @limeberry)
    Path.create!(:url => "/a").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b", "/a/c", "/a/b/d",
                            "/a/b/e", "/a/c/f", "/a/c/g")
  end

  def test_create_descendants_diamond
    d = Collection.mkcol_p("/a/b/d", @limeberry)
    c = Collection.mkcol_p("/a/c", @limeberry)
    c.bind d, 'e', @limeberry
    
    Path.create!(:url => "/a").create_descendants
    assert_only_valid_paths("/", "/a", "/a/b", "/a/c",
                            "/a/b/d", "/a/c/e")
  end

  def test_create_descendants_double_diamond
    #   b   d
    #  / \c/ \e
    # a   X   >
    #  \ /g\ /i
    #   f   h

    e = Collection.mkcol_p("/a/b/c/d/e", @limeberry)
    f = Collection.mkcol_p("/a/f", @limeberry)
    c = Bind.locate '/a/b/c'
    f.bind c, 'g', @limeberry

    h = Collection.mkcol_p("/a/f/g/h", @limeberry)
    h.bind e, 'i', @limeberry

    Path.create!(:url => "/a").create_descendants

    assert_only_valid_paths("/", "/a", "/a/b", "/a/f",
                            "/a/b/c", "/a/f/g",
                            "/a/b/c/d", "/a/b/c/h",
                            "/a/f/g/d", "/a/f/g/h",
                            "/a/b/c/d/e", "/a/b/c/h/i",
                            "/a/f/g/d/e", "/a/f/g/h/i")
  end

  def test_create_descendants_double_diamond_with_cycle
    #    ____
    #   /    \
    #   |     j
    #  \|/   /
    #   b   d
    #  / \c/ \e
    # a   X   >
    #  \ /g\ /i
    #   f   h

    e = Collection.mkcol_p("/a/b/c/d/e", @limeberry)
    f = Collection.mkcol_p("/a/f", @limeberry)
    c = Bind.locate '/a/b/c'
    f.bind c, 'g', @limeberry
    h = Collection.mkcol_p("/a/f/g/h", @limeberry)
    h.bind e, 'i', @limeberry
    Bind.locate('/a/b/c/d').bind(Bind.locate('/a/b'), 'j', @limeberry)
    
    Path.create!(:url => "/a").create_descendants

    assert_only_valid_paths("/", "/a", "/a/b", "/a/f",
                            "/a/b/c", "/a/f/g",
                            "/a/b/c/d", "/a/b/c/h",
                            "/a/f/g/d", "/a/f/g/h",
                            "/a/b/c/d/e", "/a/b/c/h/i",
                            "/a/f/g/d/e", "/a/f/g/h/i",
                            "/a/b/c/d/j", "/a/f/g/d/j")
  end

  def test_create_slash
    assert_nothing_raised { Path.create!( :url => "/" ) }
    assert_only_valid_paths("/")
  end
  
  def test_descendant_urls_and_paths
    Collection.mkcol_p("/a/b/c", @limeberry)
    c_path = Path.create!(:url => "/a/b/c")
    b_path = c_path.parent
    a_path = b_path.parent

    assert_equal({}, c_path.descendant_urls_and_paths)
    
    assert_equal({ "/a/b/c" => c_path },
                 b_path.descendant_urls_and_paths)
    
    assert_equal({ "/a/b" => b_path, "/a/b/c" => c_path},
                 a_path.descendant_urls_and_paths)
  end

  def assert_only_valid_paths(*urls)
    assert_equal(urls.size, Path.count)
    assert_valid_paths(*urls)
  end
  
  def assert_valid_paths(*urls)
    urls.each do |u|
      p = Path.find_by_url(u)
      assert_not_nil(p)
      assert_equal (r = Bind.locate(p.url)), p.resource

      if p.parent.nil?
        assert_equal(Bind.root_collection, p.resource)
        assert_nil p.bind
        assert_equal '/', p.url
      else
        /^(.*)\/([^\/]+)$/.match(u)
        parent_url, bind_name = [$1, $2]
        parent_url = '/' if parent_url.empty?
        parent_path = Path.find_by_url(parent_url)
        assert_not_nil parent_path
        expected_bind = parent_path.resource.childbinds.find_by_name(bind_name)
        assert_equal expected_bind, p.bind
      end
      
    end
  end
  
end
