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

require 'test/xml'

class TestXmlTest < Test::Unit::TestCase

  def test_root
    xml = "<foo/>"

    assert_xml_matches xml do |xml|
      xml.foo
    end

  end

  def test_root_wrong_name
    xml = "<foo/>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.bar
      end
    end
  end
  
  def test_two_level
    xml = "<foo><bar/></foo>"
    assert_xml_matches xml do |xml|
      xml.foo { xml.bar }
    end
  end

  def test_three_level
    xml = "<foo><bar><baz/></bar></foo>"
    assert_xml_matches xml do |xml|
      xml.foo { xml.bar { xml.baz } }
    end
  end

  def test_adjacent_elements
    xml = "<foo><bar/><baz/></foo>"
    assert_xml_matches xml do |xml|
      xml.foo { xml.bar; xml.baz }
    end
  end

  def test_adjacent_elements_out_of_order
    xml = "<foo><bar/><baz/></foo>"
    assert_xml_matches xml do |xml|
      xml.foo { xml.baz; xml.bar }
    end
  end

  def test_adjacent_elements_ordered
    xml = "<foo><bar/><baz/></foo>"
    assert_xml_matches xml do |xml|
      xml.ordered!
      xml.foo { xml.bar; xml.baz }
    end
  end

  def test_adjacent_elements_ordered_wrong
    xml = "<foo><bar/><baz/></foo>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.ordered!
        xml.foo { xml.baz; xml.bar }
      end
    end
  end

  def test_adjacent_elements_same
    xml = "<foo><bar/><bar/></foo>"
    assert_xml_matches xml do |xml|
      xml.foo { xml.bar; xml.bar }
    end
  end

  def test_adjacent_elements_too_many
    xml = "<foo><bar/><baz/></foo>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.foo { xml.bar; xml.baz; xml.bat }
      end
    end
  end

  def test_adjacent_elements_missing_one
    xml = "<foo><bar/><baz/></foo>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.foo { xml.bar }
      end
    end
  end

  def test_adjacent_elements_same_too_many
    xml = "<foo><bar/></foo>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.foo { xml.bar; xml.bar }
      end
    end
  end

  def test_adjacent_elements_same_not_enough
    xml = "<foo><bar/><bar/></foo>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.foo { xml.bar }
      end
    end
  end

  def test_text
    xml = "<foo>bar</foo>"
    assert_xml_matches(xml) { |xml| xml.foo "bar" }
  end

  def test_wrong_text
    xml = "<foo>bar</foo>"
    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches(xml) { |xml| xml.foo "baz" }
    end
  end

  def test_unordered_inside_ordered
    xml = "<foo><bar><bat/><bad/></bar><baz>ban</baz></foo>"

    assert_xml_matches xml do |xml|
      xml.foo do
        xml.ordered!
        xml.bar do
          xml.unordered!
          xml.bad
          xml.bat
        end
        xml.baz "ban"
      end
    end
  end

  def test_unordered_inside_ordered_wrong_order
    xml = "<foo><bar><bat/><bad/></bar><baz>ban</baz></foo>"

    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.foo do
          xml.ordered!
          xml.baz "ban"
          xml.bar do
            xml.unordered!
            xml.bat
            xml.bad
          end
        end
      end
    end
    
  end

  def test_default_ns
    xml = "<foo xmlns='bar'/>"

    assert_xml_matches xml do |xml|
      xml.xmlns! 'bar'
      xml.foo
    end
  end

  def test_prefixed_namespace
    xml = "<b:foo xmlns:b='bar'/>"

    assert_xml_matches xml do |xml|
      xml.xmlns! :b => 'bar'
      xml.b :foo
    end
  end

  def test_default_ns_with_prefixed_namespace
    xml = "<b:foo xmlns:b='bar'/>"

    assert_xml_matches xml do |xml|
      xml.xmlns! 'bar'
      xml.foo
    end
  end

  def test_prefixed_namespace_with_default_ns
    xml = "<foo xmlns='bar'/>"

    assert_xml_matches xml do |xml|
      xml.xmlns! :b => 'bar'
      xml.b :foo
    end
  end
  
  def test_wrong_ns
    xml = "<foo xmlns='baz'/>"
    assert_raise(Test::Unit::AssertionFailedError) do
      assert_xml_matches xml do |xml|
        xml.xmlns! 'bar'
        xml.foo
      end
    end
  end
  
    
  
  
end
