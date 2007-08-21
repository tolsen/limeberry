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

class PrincipalTest < DavTestCase

  def setup
    super
    @principal = Principal.find_by_name 'principal'
  end
  
  def test_make_default_args
    Principal.make(:name => "someprincipal")
    prin = Principal.find_by_name("someprincipal")
    assert_equal "", prin.displayname
    assert_equal 0, prin.total_quota
    assert_equal @limeberry, prin.creator
    assert_equal prin, prin.owner
  end

  def test_make_args_specified
    Principal.make(:name => "someprincipal",
                   :displayname => "sp",
                   :quota => '10',
                   :creator => @principal,
                   :owner => @limeberry)
    prin = Principal.find_by_name("someprincipal")
    assert_equal "sp", prin.displayname
    assert_equal 10, prin.total_quota
    assert_equal @principal, prin.creator
    assert_equal @limeberry, prin.owner
  end

  def test_after_proxied_create
    Principal.make(:name => "someprincipal")
    assert_nothing_raised() {
      Bind.locate("/principals/someprincipal")
    }
  end

  def test_duplicate_names

    name1 = Principal.make(:name => "duplicatename",
                           :displayname => "Duplicate Name 1")

    name2 = nil
    assert_raise (ActiveRecord::RecordInvalid) do
      name2 = Principal.make(:name => "duplicatename",
                             :displayname => "Duplicate Name 2")
    end

    assert_not_nil( Principal.find_by_name( "duplicatename" ))
    assert_not_nil( Principal.find_by_displayname( "Duplicate Name 1" ))
    assert_equal( Principal.find_all_by_name( "duplicatename" ).size, 1)
    assert_nil( Principal.find_by_displayname( "Duplicate Name 2" ))
  end

  def test_copy_fail
    principal1 = Principal.make(:name => "principal1")
    assert_raise(MethodNotAllowedError) {
      principal1.copy("/principals/principal2",
                      :principal => @limeberry)
    }
  end

  def test_destroy
    d = Principal.make(:name => "testprincipal")
    d.destroy

    p = Principal.find_by_name("testprincipal")
    assert_nil(p)
  end

  def test_principal_url
    out = ""
    xml = Builder::XmlMarkup.new(:target => out)
    @principal.principal_url(xml)

    assert_equal("<D:href>#{Principal::PRINCIPALS_COLLECTION_PATH}/principal</D:href>", out)
  end

  def test_resourcetype
    setup_xml
    @limeberry.resourcetype(@xml)
    assert_rexml_equal('<D:resourcetype><D:principal/></D:resourcetype>',
                       @xml_out)
  end
  
  def test_check_quota
    foo = Principal.make(:name => "foo",
                         :quota => 10)
    assert_nothing_raised() {
      foo.used_quota += 10
      foo.save
    }
    
    assert_raise(InsufficientStorageError) {
      foo.used_quota += 1
      foo.save
    }
    
    assert_nothing_raised() {
      @limeberry.used_quota += 2**20
      @limeberry.save
    }
  end
  
  def test_principals_collection
    assert_equal Bind.locate("/principals"), Principal.principals_collection
  end
  
  def test_principals_collection_path
    assert_equal "/principals", Principal.principals_collection_path
  end

  def test_supported_privilege_set
    expected = <<EOS
<D:supported-privilege-set>
  <D:supported-privilege>
    <D:privilege><D:all/></D:privilege>
    <D:description xml:lang="en">#{Privilege.priv_all.description}</D:description>
    <D:supported-privilege>
      <D:privilege><D:read/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:read-acl/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read_acl.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:read-current-user-privilege-set/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read_current_user_privilege_set.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write.description}</D:description>
      <D:supported-privilege>
        <D:privilege><D:write-properties/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_write_properties.description}</D:description>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege><D:write-content/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_write_content.description}</D:description>
      </D:supported-privilege>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write-acl/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write_acl.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:unlock/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_unlock.description}</D:description>
    </D:supported-privilege>
  </D:supported-privilege>
</D:supported-privilege-set>
EOS
    setup_xml
    @principal.supported_privilege_set @xml
    assert_rexml_equal expected, @xml_out
  end
  
end
