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

class VcrTest < DavTestCase

  def setup
    super
    @resource = Bind.locate '/deltav/res'
    @vcr = Bind.locate '/deltav/vcr'
    @vhr = @vcr.vhr
    @joe = User.find_by_name 'joe'

    @vcr2 = Bind.locate '/deltav/vcr2'
    @vhr2 = @vcr2.vhr
  end

  def test_init_versioning
    @resource.convert_to_vcr(@limeberry)
    @resource = Resource.find(@resource)
    @resource.init_versioning(@joe)
    vhr = @resource.vhr
    assert_not_nil vhr
    assert_equal vhr.versions.first, @resource.checked_version
    assert_equal @resource.body.stream.read, vhr.versions.first.body.stream.read
  end

  def test_destroy
    @vcr.destroy
    assert_nothing_raised() { @vhr.reload }
    assert_not_nil @vhr
  end

  def test_checkout
    assert_raise(ForbiddenError) { @vcr.checkout(@joe) }
    Privilege.priv_write_properties.grant(@vcr, @joe)
    assert_nothing_raised(ForbiddenError) { @vcr.checkout(@joe) }
    assert_equal 'O', @vcr.checked_state
    assert_raise(PreconditionFailedError) { @vcr.checkout(@joe) }
  end

  def test_checkin_preconds_and_privs
    assert_raise(PreconditionFailedError) { @vcr.checkin(@limeberry) }
    @vcr.checkout(@limeberry)
    assert_raise(ForbiddenError) { @vcr.checkin(@joe) }
    Privilege.priv_write_properties.grant(@vcr, @joe)
    assert_nothing_raised(ForbiddenError) { @vcr.checkin(@joe) }
  end
  
  def test_copy_to
    assert_raise(PreconditionFailedError) {
      Resource.copy("/deltav/res", "/deltav/vcr", @limeberry)
    }
    @vcr.checkout(@limeberry)
    assert_nothing_raised(PreconditionFailedError) {
      Resource.copy("/deltav/res", "/deltav/vcr", @limeberry)
    }
  end

  def test_checkin_checked_state
    assert_equal 'I', @vcr2.checked_state
  end
  
  def test_checkin_versions
    assert_equal 2, @vhr2.versions.length
    assert_equal @vcr2.checked_version, @vhr2.versions[1]
  end

  def test_checkin_props
    version1 = @vhr2.versions[0]
    version2 = @vhr2.versions[1]
    assert_equal 0, version1.properties.length
    assert_equal 1, version2.properties.length
    assert_equal "ns", version2.properties[0].namespace.name
    assert_equal "name", version2.properties[0].name
    assert_equal "<N:name xmlns:N='ns'>value</N:name>", version2.properties[0].value
  end
  
  def test_checkin_content
    version1 = @vhr2.versions[0]
    version2 = @vhr2.versions[1]
    assert_equal "randomcontent", version2.body.stream.read
    tmp_path = File.join(Body::TEMP_FOLDER, "patched")
    system("xdelta patch #{version1.body.stream.path} #{version2.body.stream.path} #{tmp_path}")
    assert_equal "vcr2", File.new(tmp_path).read
    File.delete(tmp_path)
  end

  # move to functional tests
#   def test_put
#     setup_versioning
#     stream, contenttype = get_put_args
#     assert_raise(PreconditionFailedError) {
#       Resource.put("/dir/src", stream, contenttype, @limeberry)
#     }
#     @vcr.checkout(@limeberry)
#     assert_nothing_raised(PreconditionFailedError) {
#       Resource.put("/dir/src", stream, contenttype, @limeberry)
#     }
#   end
  
  
end
