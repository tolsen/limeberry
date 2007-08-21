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

class NamespaceTest < DavTestCase

  def setup
    super
    @dav_ns = Namespace.find_by_name 'DAV:'
  end

  def test_create
    assert_equal("DAV:", @dav_ns.name)
  end

  def test_create_invalid_name
    assert_raise(ActiveRecord::RecordInvalid) do
      Namespace.create!(:name => "DAV:")
    end
  end

  def test_find_or_create_by_name
    test_ns_name = "http://example.org/namespaces/test2"
    orig_num_namespaces = Namespace.count

    test_ns =
      Namespace.find_or_create_by_name!(test_ns_name)
    assert_equal(test_ns_name, test_ns.name)

    found_test_ns = Namespace.find_by_name(test_ns_name)
    assert_equal(test_ns, found_test_ns)
    
    assert_equal(orig_num_namespaces + 1, Namespace.count)

    test_ns_again =
      Namespace.find_or_create_by_name!(test_ns_name)
    assert_equal(test_ns, test_ns_again)
    assert_equal(orig_num_namespaces + 1, Namespace.count)
  end

end
