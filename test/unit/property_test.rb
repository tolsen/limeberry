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

class PropertyTest < DavTestCase

  def setup
    super
    @test_ns_name = "http://example.org/namespaces/test"
    @test_ns = Namespace.find_by_name @test_ns_name

    @resource = Bind.locate '/prop/test'
    @prop = @resource.properties[0]

    @bob = Principal.find_by_name 'bob'
    @bobs_resource = Bind.locate '/prop/bobs'
  end

  def test_create
    assert_equal(@resource, @prop.resource)
    assert_equal(@test_ns, @prop.namespace)
    assert_equal("testprop", @prop.name)
    assert_equal("<N:testprop xmlns:N='http://example.org/namespaces/test'>testvalue</N:testprop>", @prop.value)

    assert_equal(@prop,
                 @resource.properties.find_by_name_and_namespace_id("testprop",
                                                                    @test_ns.id))
  end

  def test_create_same_name_ns_and_resource
    assert_raise(ActiveRecord::RecordInvalid) do
      Property.create!(:namespace => @test_ns,
                       :resource => @resource,
                       :name => "testprop",
                       :value => "testvalue2")
    end
  end

  def test_create_using_propkey
    propkey = PropKey.get(@test_ns_name, "testprop2")
    prop2 = Property.create!(:propkey => propkey,
                             :resource => @resource,
                             :value => "testvalue2")
    assert_not_nil prop2
    assert_equal(@test_ns, prop2.namespace)
    assert_equal(@resource, prop2.resource)
    assert_equal("testprop2", prop2.name)
    assert_equal("testvalue2", prop2.value)
  end
  
  def test_propkey
    propkey = PropKey.get(@test_ns_name, "testprop")
    assert_equal(propkey, @prop.propkey)
  end

  def test_under_quota
    assert_nothing_raised(InsufficientStorageError) do
      Property.create!(:namespace => @test_ns,
                       :name => "bobs testprop",
                       :resource => @bobs_resource,
                       :value => "12345")
    end
  end

  def test_over_quota
    assert_raise(InsufficientStorageError) do
      Property.create!(:namespace => @test_ns,
                       :name => "bobs testprop",
                       :resource => @bobs_resource,
                       :value => "123456")
    end
  end

  def test_two_props_under_quota
    Property.create!(:namespace => @test_ns,
                     :name => "bobs testprop",
                     :resource => @bobs_resource,
                     :value => "123")


    assert_nothing_raised(InsufficientStorageError) do
      Property.create!(:namespace => @test_ns,
                       :name => "bobs testprop2",
                       :resource => @bobs_resource,
                       :value => "45")
    end
  end
  
  def test_two_props_over_quota
    Property.create!(:namespace => @test_ns,
                     :name => "bobs testprop",
                     :resource => @bobs_resource,
                     :value => "123")


    assert_raise(InsufficientStorageError) do
      Property.create!(:namespace => @test_ns,
                       :name => "bobs testprop2",
                       :resource => @bobs_resource,
                       :value => "456")
    end
  end
    
end
