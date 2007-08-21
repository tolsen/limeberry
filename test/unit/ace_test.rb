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

class AceTest < DavTestCase

  def setup
    super

    @collectionpath = "/dir"
    @src_content = "content"
    @resourcepath = "/dir/src"

    @collection = Bind.locate @collectionpath
    @resource = Bind.locate @resourcepath

    @joe = User.find_by_name 'joe'
    @ren = User.find_by_name 'ren'
    @alpha = Group.find_by_name 'alpha'

    Privilege.priv_read.grant @resource, @joe

    @ace_owner = @resource.aces[0]
    @ace_joe = @resource.aces[1]
  end

  def test_property_derived_principal
    assert @ace_owner.property_derived_principal?
    assert !@ace_joe.property_derived_principal?
  end

  def test_regenerate_principal_href
    @ace_joe.regenerate_principal
    assert_equal @joe, @ace_joe.principal
  end

  def test_regenerate_principal_self
    ace = @alpha.aces.create! :property_namespace_id => -1, :grantdeny => Ace::GRANT
    assert_equal @alpha, ace.principal
  end

  def test_regenerate_principal_property_liveprop
    @resource.displayname = "<D:href>/users/ren</D:href>"
    @resource.save!
    ace = @resource.aces.create!(:grantdeny => Ace::GRANT,
                                 :property_namespace => Namespace.dav,
                                 :property_name => 'displayname')
    assert_equal @ren, ace.principal

    @resource.displayname = "<D:href>/users/joe</D:href>"
    @resource.save!
    ace.reload.save!
    assert_equal @joe, ace.principal
  end

  def test_regenerate_principal_property_deadprop
    ns1 = Namespace.find_by_name "randomns1"
    ace = @resource.aces.create!(:grantdeny => Ace::GRANT,
                                 :property_namespace => ns1,
                                 :property_name => "randomname1")
    assert_nil ace.principal

    @resource.proppatch_set_one <<EOS
<N:randomname1 xmlns:N="randomns1">
  <D:href xmlns:D="DAV:">/users/ren</D:href>
</N:randomname1>
EOS
    ace.reload.save!
    assert_equal @ren, ace.principal

    @resource.proppatch_set_one <<EOS
<N:randomname1 xmlns:N="randomns1">
  <D:href xmlns:D="DAV:">/users/joe</D:href>
</N:randomname1>
EOS
    ace.reload.save!
    assert_equal @joe, ace.principal
  end
  
    

    
end
