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

require 'stringio'

require 'test/test_helper'
require 'test/unit/dav_unit_test'

require 'errors'

class LockNullResourceTest < DavUnitTestCase

  def setup
    super
    @locknull = Bind.locate("/locknull")
    @lock = @locknull.locks[0]
  end


  # move to functional tests
#   def test_lnr
#     assert_raise(MethodNotAllowedError) {
#       @locknull.get(@limeberry)
#     }

#     assert_raise(MethodNotAllowedError) {
#       @locknull.copy("/locknull2", @limeberry)
#     }
#   end

  # This may be non-compliant to RFC 2518
  def test_copy
    Resource.copy("/dir/src","/locknull", @limeberry,
                  '0', true, @lock.uuid)
    newres = Bind.locate("/locknull")
    assert_instance_of(Resource, newres)
    assert newres.locked_with?(@lock.uuid)
  end

  def test_resourcetype
    setup_xml
    @locknull.resourcetype(@xml)
    assert_rexml_equal("<D:resourcetype xmlns:D='DAV:'><D:locknullresource/></D:resourcetype>", @xml_out)
  end

  def test_locknull_get_properties
    propkeys =
      [ PropKey.get("DAV:", "getcontentlanguage"),
        PropKey.get("DAV:", "getcontentlength"),
        PropKey.get("DAV:", "getcontenttype"),
        PropKey.get("DAV:", "getetag"),
        PropKey.get("DAV:", "getlastmodified") ]

    setup_xml

    @xml.tag_dav_ns! :dummyroot do
      @locknull.propfind(@xml, @limeberry, false, *propkeys)
    end

    expected_out = <<EOS
<dummyroot xmlns:D='DAV:'>
  <D:propstat>
    <D:prop>
      <D:getcontentlanguage/>
      <D:getcontentlength/>
      <D:getcontenttype/>
      <D:getetag/>
      <D:getlastmodified/>
    </D:prop>
    <D:status>HTTP/1.1 404 Not Found</D:status>
  </D:propstat>
</dummyroot>
EOS
    assert_rexml_equal(expected_out, @xml_out)
  end

  def test_missing_parent
    assert_raise(ConflictError) { create_lock "/alpha/abcd" }
  end

  # move to functional tests
  #   def test_unlock
  #     @locknull.unlock(@limeberry, @lock.uuid)
  #     assert_raise(ActiveRecord::RecordNotFound) { @locknull.reload }
  #   end

  #   def test_unlock_inside_locked_collection
  #     Collection.mkcol("/a", @limeberry)
  #     l0 = create_lock("/a/b", @limeberry, 'S')
  #     l1 = create_lock("/a", @limeberry, 'S', 'I')

  #     Resource.unlock("/a/b", @limeberry, l0.uuid)
  #     assert_raise(NotFoundError) { Bind.locate("/a/b") }
  #   end
  
#   def test_put
#     response = Resource.put("/locknull", StringIO.new("abcd"),
#                             "text/plain", @limeberry, @lock.uuid)
    
#     assert_equal 204,response.status.code

#     new_locknull = Bind.locate "/locknull"
#     assert_instance_of(Resource, new_locknull)
#     assert new_locknull.locked_with?(@lock.uuid)
#   end
#   def test_dav_delete
#     assert_raise(NotFoundError) do
#       Resource.dav_delete("/locknull", @limeberry, @lock.uuid)
#     end
#   end

#   def test_mkcol
#     response = Collection.mkcol("/locknull", @limeberry, @lock.uuid)

#     new_locknull = Bind.locate("/locknull")
#     assert_instance_of(Collection, new_locknull)
#     assert new_locknull.locked_with?(@lock.uuid)
#   end

  def test_move
    assert_raise(NotFoundError) do
      Resource.move("/locknull", "/foo", @limeberry, true, @lock.uuid)
    end
  end
  
  def test_locknull_expires_now
    Lock.create!(:owner => @limeberry,
                 :scope => 'X',
                 :depth => '0',
                 :expires_at => Time.now,
                 :lock_root => "/expires_now")
    
    assert_raise(NotFoundError) do
      Bind.locate("/expires_now")
    end
  end

  def test_locknull_expires_soon
    Lock.create!(:owner => @limeberry,
                 :scope => 'X',
                 :depth => '0',
                 :expires_at => Time.now + 2,
                 :lock_root => "/expires_soon")

    assert_raise(NotFoundError) do
      3.times do
        Bind.locate '/expires_soon'
        sleep 1
      end
    end
  end

  def test_independently_destroyed
    locknull2 = create_lock "/locknull2"

    @locknull.destroy
    assert !Bind.exists?("/locknull")
    assert Bind.exists?("/locknull2")

    locknull2.destroy
    assert !Bind.exists?("/locknull2")
  end
  
end
