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

class VhrTest < DavUnitTestCase

  def setup
    @resource = Bind.locate '/deltav/vcr3'
    @vhr = @resource.vhr
    @path = File.join("/!lime/vhrs", Body.file_path(@resource.uuid))
    @joe = User.find_by_name 'joe'
  end
  
  def test_make_simple
    assert @vhr.is_a?(Vhr)
    assert_equal @joe, @vhr.owner
    assert_equal @joe, @vhr.creator
    assert_equal @resource.displayname, @vhr.displayname
  end
  
  def test_make_bind_created
    assert_equal @vhr, Bind.locate(File.join(@path, "vhr"))
  end
  
  def test_make_privs_set
    assert_equal @resource, @vhr.acl_parent
    
    Privilege.priv_write.grant(@resource, @joe)
    assert Privilege.priv_write.granted?(@resource, @joe)
    assert Privilege.priv_write.denied?(@vhr, @joe)
    
    Privilege.priv_write_acl.grant(@resource, @joe)
    assert Privilege.priv_write_acl.granted?(@resource, @joe)
    assert Privilege.priv_write_acl.denied?(@vhr, @joe)
    
    Privilege.priv_write.grant(@vhr, @joe)
    assert Privilege.priv_write.denied?(@vhr, @joe)
  end
  
  def test_destroy
    assert_raise(ForbiddenError) { @vhr.destroy }
  end
  
  def test_delete
    assert_raise(ForbiddenError) { @vhr.delete }
  end
end
