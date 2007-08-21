require 'test/unit'
require 'rubygems'
require_gem 'activerecord'

database = {
  "adapter" => "mysql",
  "username" => ENV['BNST_USER'],
  "password" => ENV['BNST_PASS'],
  "host" => ENV['BNST_HOST'],
  "database" => ENV['BNST_DB'] }


ActiveRecord::Base.establish_connection(database)

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'better_nested_set'

ActiveRecord::Base.class_eval do
  include SymetrieCom::Acts::NestedSet
end

ActiveRecord::Base.connection.drop_table :nodes rescue nil

ActiveRecord::Base.connection.create_table :nodes do |t|
  t.column :parent_id, :integer
  t.column :lft, :integer
  t.column :rgt, :integer
  t.column :name, :string
end

class Node < ActiveRecord::Base
  acts_as_nested_set
end


class BetterNestedSetTest < Test::Unit::TestCase

  def setup
    Node.delete_all
  end


  def teardown
  end


  def test_basic_structure

    #          a
    #        / | \
    #       /  |  \
    #      /   |   \
    #     /    |    \
    #    b     c     d
    #   /|\   /|\   /|\
    #  e f g h i j k l m


    a,b,c,d,e,f,g,h,i,j,k,l,m = ('a'..'m').map do |x|
      Node.create(:name => x)
    end


    b.move_to_child_of(a)
    c.move_to_child_of(a)
    d.move_to_child_of(a)

    b.reload

    e.move_to_child_of(b)
#      f.move_to_child_of(b)
#      g.move_to_child_of(b)

#     h.move_to_child_of(c)
#     i.move_to_child_of(c)
#     j.move_to_child_of(c)

#     k.move_to_child_of(d)
#     l.move_to_child_of(d)
#     m.move_to_child_of(d)

    flunk

    assert_equal(a.lft, 1)
    assert_equal(a.rgt, 26)

    [b, c, d].each do |x|
      assert(x.lft + 7 == x.rgt)
    end

    ('e'..'m').each do |x|
      assert(x.lft + 1 == x.rgt)
    end

    assert(a.lft < b.lft)
    assert(a.lft < c.lft)
    assert(a.lft < d.lft)

    assert(a.rgt > b.rgt)
    assert(a.rgt > c.rgt)
    assert(a.rgt > d.rgt)

    assert(b.lft < e.lft)
    assert(b.lft < f.lft)
    assert(b.lft < g.lft)

    assert(b.rgt > e.rgt)
    assert(b.rgt > f.rgt)
    assert(b.rgt > g.rgt)

    assert(c.lft < h.lft)
    assert(c.lft < i.lft)
    assert(c.lft < j.lft)

    assert(c.rgt > h.rgt)
    assert(c.rgt > i.rgt)
    assert(c.rgt > j.rgt)

    assert(d.lft < k.lft)
    assert(d.lft < l.lft)
    assert(d.lft < m.lft)

    assert(d.rgt > k.rgt)
    assert(d.rgt > l.rgt)
    assert(d.rgt > m.rgt)
  end


end
