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

class LivePropsTest < DavUnitTestCase

  def setup
    super
    @resource = Bind.locate '/dir/src'
    @displaynamePropKey = PropKey.get('DAV:', 'displayname')
  end

  def test_create
    assert_equal(@resource, @resource.liveprops.instance_variable_get(:@resource))
    expected_liveprops = Resource.send(:liveprops)
    assert_equal(expected_liveprops, @resource.liveprops.instance_variable_get(:@liveprops))

  end

  def test_element_reference
    assert_liveprop_value_equals(@resource, @displaynamePropKey,
                                 "this is my displayname")
  end

  def test_element_assignment
    assert_nothing_raised do
      @resource.liveprops[@displaynamePropKey] = 'new displayname'
    end

    assert_liveprop_value_equals(@resource, @displaynamePropKey,
                                 'new displayname')
  end

  def test_element_assignment_protected
    etagPropKey = PropKey.get('DAV:', 'getetag')
    assert_raise(ForbiddenError) do
      @resource.liveprops[etagPropKey] = "abcdef"
    end
  end

  def test_include?
    assert(@resource.liveprops.include?(@displaynamePropKey))
    bogusPropKey = PropKey.get('bo', 'gus')
    assert(!@resource.liveprops.include?(bogusPropKey))
  end

  def test_allprop
    count = 0
    @resource.liveprops.allprop do |k, v|
      livepropinfo = Resource.send(:liveprops)[k]
      assert(livepropinfo.allprop?)
      count += 1
    end

    expected_count = Resource.send(:liveprops).select{ |k, v| v.allprop? }.size
    
    assert_equal(expected_count, count)
  end

  def test_propname
    count = 0
    @resource.liveprops.propname do |k|
      assert(Resource.send(:liveprops).include?(k))
      count += 1
    end

    expected_count = Resource.send(:liveprops).size
    assert_equal(expected_count, count)
  end

  def test_each_unprotected
    count = 0
    @resource.liveprops.each_unprotected do |k, v|
      livepropinfo = Resource.send(:liveprops)[k]
      assert(!livepropinfo.protected?)
      count += 1
    end

    expected_count = Resource.send(:liveprops).select{ |k, v| !v.protected? }.size
    assert_equal(expected_count, count)
  end

  # helpers

  def assert_liveprop_value_equals(resource, propkey, expected)
    expected_xml = Property.xml_wrap(propkey, expected)
    actual_xml = resource.liveprops[propkey]

    assert_rexml_equal(expected_xml, actual_xml)
  end
  

end
