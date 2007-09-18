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

class VersionTest < DavUnitTestCase

  def setup
    super
    @pk = PropKey.get("ns", "name")
    @pk2 = PropKey.get("ns", "name2")
    @resourcepath = '/deltav/vcr3'
    @resource = Bind.locate @resourcepath
    @src_content = 'vcr3'
    @vhr = @resource.vhr
    @path = File.join("/!lime/vhrs", Body.file_path(@resource.uuid))
    @version = @vhr.versions.first
    @joe = User.find_by_name 'joe'
  end
  
  
  def test_make_first_simple
    assert @version.is_a?(Version)
    assert_equal @joe, @version.owner
    assert_equal @joe, @version.creator
    assert_equal @resource.displayname, @version.displayname
    assert_equal 1, @version.number
    assert_equal @vhr, @version.vhr
  end
  
  def test_make_first_content_and_props_copied
    assert_equal @resource.body.stream.read, @version.body.stream.read
    assert_equal "<N:name xmlns:N='ns'>value</N:name>", @version.properties.find_by_propkey(@pk).value
  end
  
  def test_make_first_bind_created
    assert_equal @version, Bind.locate(File.join(@path, "1"))
  end
  
  def test_make_first_privs_set
    assert_equal @resource, @version.acl_parent
    
    Privilege.priv_write.grant(@resource, @joe)
    assert Privilege.priv_write.granted?(@resource, @joe)
    assert Privilege.priv_write.denied?(@version, @joe)
    
    Privilege.priv_write_acl.grant(@resource, @joe)
    assert Privilege.priv_write_acl.granted?(@resource, @joe)
    assert Privilege.priv_write_acl.denied?(@version, @joe)
    
    Privilege.priv_write.grant(@version, @joe)
    assert Privilege.priv_write.denied?(@version, @joe)
  end
  
  def test_create_new_version
    @resource.checkout(@limeberry)
    util_put @resourcepath, "#{@src_content}a"
    @resource.proppatch_set_one("<N:name2 xmlns:N='ns'>value</N:name2>")
    @resource.checkin(@limeberry)
    @vhr.reload
    new_version = @vhr.versions[1]
    prev_version = @vhr.versions[0]
    
    assert_equal (@src_content+"a"), new_version.body.stream.read
    assert_equal 1, prev_version.properties.length
    assert_equal 2, new_version.properties.length
    assert_equal prev_version.number+1, new_version.number
    
    tmp_path = File.join(Body::TEMP_FOLDER, "patched")
    system("xdelta patch #{prev_version.body.stream.path} #{new_version.body.stream.path} #{tmp_path}")
    assert_equal @src_content, File.new(tmp_path).read
    File.delete(tmp_path)
  end
  
  def test_destroy
    version = @vhr.versions[0]
    assert_raise(ForbiddenError) { version.destroy }
  end
  
  def test_delete
    version = @vhr.versions[0]
    assert_raise(ForbiddenError) { version.delete }
  end
end
