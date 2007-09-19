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

class GroupTest < DavUnitTestCase

  def setup
    super
    @joe = User.find_by_name 'joe'
    @alpha = Group.find_by_name 'alpha'
  end

  def test_make
    g = Group.make(:name => "delta", :displayname => "d", :creator => @limeberry, :owner => @joe, :quota => 10)
    assert_equal "d", g.displayname
    assert_equal @limeberry, g.creator
    assert_equal @joe, g.owner
    assert_equal 10, g.total_quota
    assert_equal 0, @alpha.total_quota
    assert Bind.exists?(File.join(Group.groups_collection_path,"delta"))
    assert Bind.exists?(File.join(Principal.principals_collection_path,"delta"))
  end

  def test_put_create_group
    options = {:name => "test", :creator => @joe, :displayname => "test"}
    response = Group.put options
    assert_equal 201, response.status.code

    g = Group.find_by_name("test")
    assert_equal "test", g.displayname
  end
  
  def test_put_modify_group
    options ={:name => "joe", :displayname => "joe1", :owner => @limeberry}
    response = Group.put options
    assert_equal 204, response.status.code
    @joe.reload
    assert_equal "joe1", @joe.displayname
    assert_equal @limeberry, @joe.owner
  end

  def test_principal_url
    out = ""
    xml = Builder::XmlMarkup.new(:target => out)
    @alpha.principal_url(xml)

    assert_equal("<D:href>#{Group::GROUPS_COLLECTION_PATH}/alpha</D:href>", out)
  end

  def setup_group_member_set
    sharad = User.make(:name => 'sharad', :password => 'sharad')
    shubham = User.make(:name => 'shubham', :password => 'ilovecocacola')
    expected=""

    [ @joe, sharad, shubham].each { |m| @alpha.add_member(m) 
      expected << "<D:href>#{User.users_collection_path}/#{m.name}</D:href>"    
    }
    out = ""
    xml = Builder::XmlMarkup.new(:target => out)
    return expected, xml, out
  end 

  def test_group_member_set
    expected, xml, out = setup_group_member_set
    @alpha.group_member_set(xml)
    assert_equal(expected, out)
  end
  
  #tests group_member_set=
  def test_group_member_set_set
    expected, xml, out = setup_group_member_set
    expected.sub!("<D:href>#{User.users_collection_path}/joe</D:href>", "")
    prop_value="<D:group-member-set xmlns:D='DAV:'>"
    prop_value << expected
    prop_value << "</D:group-member-set>"
    @alpha.group_member_set = prop_value
    assert !@alpha.has_member?(@joe)
    %w[sharad shubham].each { |name|
      assert @alpha.has_member?(User.find_by_name(name))
    }
  end
  
  def test_add_member
    @alpha.add_member(@joe)
    assert @alpha.members.include?(@joe.principal_record)
  end

  def test_remove_member
    @alpha.add_member(@joe)
    @alpha.remove_member(@joe)
    assert !@alpha.members.include?(@joe.principal_record)
  end
  
  def test_has_member
    @alpha.add_member(@joe)
    assert @alpha.has_member?(@joe)
  end
  
  def test_membership
    g1 = Group.make(:name => "group1")
    g2 = Group.make(:name => "group2")
    p1 = Principal.make(:name => "principal1")

    g2.add_member(g1)
    g1.add_member(p1)

    assert(p1.member_of?(g1))
    assert(p1.member_of?(g2))
    assert(g1.member_of?(g2))

    g2.remove_member(g1)
    g1.reload
    p1.reload

    assert(!(g1.member_of?(g2)))
    assert(!(p1.member_of?(g2)))

  end
  
  ######### testing transitivity for the graph
  ##          g1
  ##         /
  ##        g2  g3
  ##        \  / \
  ##         g4   g5
  ##        /  \ /
  ##       g7   g6
  def test_transitive_closure
    g1 = Group.make(:name => "g1")
    g2 = Group.make(:name => "g2")
    g3 = Group.make(:name => "g3")
    g4 = Group.make(:name => "g4")
    g5 = Group.make(:name => "g5")
    g6 = Group.make(:name => "g6")
    g7 = Group.make(:name => "g7")

    g1.add_member g2
    g2.add_member g4
    g3.add_member g4
    g3.add_member g5
    g4.add_member g6
    g4.add_member g7
    g5.add_member g6

    [g1, g2, g3, g4, g5, g6, g7].each { |g| g.reload }

    assert( g3.has_member?( g7 ))
    assert( g1.has_member?( g7 ))
    assert( ! g5.has_member?( g7 ))
    assert( ! g1.has_member?( g3 ))
    assert( g1.has_member?( g7 ))

    g1.remove_member( g2 )
    assert( ! (g1.has_member?( g7 )))
  end
end
