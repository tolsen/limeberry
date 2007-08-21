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

class PrivilegeTest < DavTestCase

  def setup
    super
    @collection = Bind.locate '/dir'
    @resource = Bind.locate '/dir/src'
    @joe = User.find_by_name 'joe'
    @alpha = Group.find_by_name 'alpha'
  end
  
  def test_grant
    Privilege.priv_write.grant(@resource,@joe)
    ace = @resource.aces[1]
    assert_equal @joe, ace.principal
    assert_equal Ace::GRANT, ace.grantdeny
    assert_equal [Privilege.priv_write], ace.privileges
  end

  def test_deny
    Privilege.priv_write.deny(@resource,@joe)
    ace = @resource.aces[1]
    assert_equal @joe, ace.principal
    assert_equal Ace::DENY, ace.grantdeny
    assert_equal [Privilege.priv_write], ace.privileges
  end
  
  #Tests Privilege#granted?
  def test_granted
    Privilege.priv_write.grant(@resource,@joe)
    assert Privilege.priv_write.granted?(@resource,@joe)
  end

  #Tests Privilege#denied?
  def test_denied
    assert Privilege.priv_write.denied?(@resource,@joe)
    Privilege.priv_write.grant(Bind.root_collection,@joe)
    assert !Privilege.priv_write.denied?(@resource,@joe)
    Privilege.priv_write.deny(@resource,@joe)
    assert Privilege.priv_write.denied?(@resource,@joe)
  end

  def test_ungrant
    Privilege.priv_all.grant(@resource,@joe)
    Privilege.priv_all.ungrant(@resource,@joe)
    assert Privilege.priv_all.denied?(@resource,@joe)
  end

  def test_undeny
    Privilege.priv_write.grant(Bind.root_collection,@joe)
    Privilege.priv_write.deny(@resource,@joe)
    Privilege.priv_write.undeny(@resource,@joe)
    assert !Privilege.priv_write.denied?(@resource,@joe)
  end

  def test_assert_granted_raises_unauthorized_error_correctly
    assert_raise(UnauthorizedError) {
      Privilege.priv_all.assert_granted(@resource, nil)
    }
    assert_raise(UnauthorizedError) {
      Privilege.priv_all.assert_granted(@resource, Principal.unauthenticated)
    }
    Privilege.priv_all.grant(@resource, Principal.unauthenticated)
    assert_nothing_raised(UnauthorizedError) {
      Privilege.priv_all.assert_granted(@resource, nil)
    }
  end

  def test_assert_granted_raises_forbidden_error_correctly
    assert_raise(ForbiddenError) {
      Privilege.priv_all.assert_granted(@resource, @joe)
    }
    Privilege.priv_read.grant(@resource, @joe)
    assert_raise(ForbiddenError) {
      Privilege.priv_all.assert_granted(@resource, @joe)
    }
    assert_nothing_raised(ForbiddenError) {
      Privilege.priv_read.assert_granted(@resource, @joe)
    }
  end

  def test_raise_permission_denied
    assert_raise(UnauthorizedError) {
      Privilege.raise_permission_denied(nil)
    }
    assert_raise(UnauthorizedError) {
      Privilege.raise_permission_denied(Principal.unauthenticated)
    }
    assert_raise(ForbiddenError) {
      Privilege.raise_permission_denied(@joe)
    }
  end

  def test_elem
    %w[all read read-acl read-current-user-privilege-set
       write write-properties write-content bind unbind write-acl unlock].each do |priv|
      out = ""
      Privilege.send('priv_' + priv).elem(Builder::XmlMarkup.new(:target => out))
      exp_out = "<D:privilege><D:"+priv+"/></D:privilege>"
      assert_rexml_equal exp_out, out
    end
  end

  # Removing a protected privilege should raise an error
  def test_remove_protected_privilege
    creator = Principal.make(:name => "test_creator")
    random_principal = Principal.make(:name => "random_principal")
    resource = Resource.create!(:creator => creator)

    # assert that creator has indeed been granted all privileges
    assert(Privilege.priv_all.granted?(resource,creator))

    # forbidden error to be raised if protected privilege is being ungranted with protected flag=false
    assert_raise(ForbiddenError) {
      Privilege.priv_all.ungrant(resource,creator)
    }

    # no error to be raised if privilege doesnt exist
    assert_nothing_raised() {
      Privilege.priv_all.ungrant(resource,random_principal)
    }

    Privilege.priv_read.grant resource,random_principal

    # check if read permission (protected=false) has been successfully granted
    assert(Privilege.priv_read.granted?(resource,random_principal))

    # no error should be raised because the privilege is not protected and
    # could have been removed if correct protected flag had been sent.
    assert_nothing_raised() {
      Privilege.priv_read.ungrant(resource,random_principal,true)
    }

    # check that privilege has not indeed been removed because
    # the privilege was to be removed only if it was protected
    assert(Privilege.priv_read.granted?(resource,random_principal))
  end

  def test_aces_position
    @prin = Principal.make(:name => "a1")
    Privilege.priv_write.deny(@resource, @joe, true)
    @resource.reload
    user_ace = limeberry_ace = nil
    @resource.aces.each { |ace|
      user_ace = ace if ace.principal == @joe
      limeberry_ace = ace if ace.principal == @limeberry
    }
    assert_not_equal user_ace.position, limeberry_ace.position
  end

  def test_find_by_propkey
    dav_read_pk = PropKey.get 'DAV:', 'read'
    assert_equal Privilege.priv_read, Privilege.find_by_propkey(dav_read_pk)
  end

  def test_find_by_propkey_bad_namespace
    e_read_pk = PropKey.get 'namespaceE', 'read'
    assert_nil Privilege.find_by_propkey(e_read_pk)
  end
  
  def test_find_by_propkey_bad_name
    dav_foo_pk = PropKey.get 'DAV:', 'foo'
    assert_nil Privilege.find_by_propkey(dav_foo_pk)
  end

  def test_inherited_protected_aces
    Privilege.priv_read.grant @collection, @joe, true
    assert Privilege.priv_read.granted?(@resource, @joe)
    Privilege.priv_read.deny @resource, @joe
    assert Privilege.priv_read.granted?(@resource, @joe)
    Privilege.priv_read.deny @resource, @joe, true
    assert Privilege.priv_read.denied?(@resource, @joe)
  end

  def test_cups
    Privilege.priv_read.grant @collection, @joe
    assert_equal [ Privilege.priv_read ], Privilege.cups(@collection, @joe)
  end

  def test_cups_aggregate_privs
    Privilege.priv_write.grant @collection, @joe
    expected = [ Privilege.priv_write, *Privilege.priv_write.children ].sort
    assert_equal expected, Privilege.cups(@collection, @joe).sort
  end

  def test_cups_through_group
    @alpha.add_member @joe
    Privilege.priv_read.grant @collection, @alpha
    Privilege.priv_read_acl.grant @collection, @alpha

    expected = [ Privilege.priv_read, Privilege.priv_read_acl ].sort
    assert_equal expected, Privilege.cups(@collection, @joe).sort
  end

  def test_cups_inherited
    Privilege.priv_read.grant @collection, @joe
    Privilege.priv_read_acl.grant @resource, @joe

    expected = [ Privilege.priv_read, Privilege.priv_read_acl ].sort
    assert_equal expected, Privilege.cups(@resource, @joe).sort
  end
  
  def test_cups_combo
    @alpha.add_member @joe
    Privilege.priv_write.grant @collection, @alpha
    Privilege.priv_read_current_user_privilege_set.grant @collection, @joe
    Privilege.priv_read_acl.grant @resource, @alpha
    Privilege.priv_write_acl.grant @resource, @joe

    expected = [ Privilege.priv_write, Privilege.priv_read_acl,
                 Privilege.priv_read_current_user_privilege_set,
                 Privilege.priv_write_acl, *Privilege.priv_write.children ].sort
    assert_equal expected, Privilege.cups(@resource, @joe).sort
  end

  def test_supported_privilege
    supported_privileges = %w(all read-acl unlock write write-properties bind).map do |name|
      Namespace.dav.privileges.find_by_name name
    end

    expected = <<EOS
<D:supported-privilege>
  <D:privilege><D:all/></D:privilege>
  <D:description xml:lang="en">#{Privilege.priv_all.description}</D:description>
  <D:supported-privilege>
    <D:privilege><D:read-acl/></D:privilege>
    <D:description xml:lang="en">#{Privilege.priv_read_acl.description}</D:description>
  </D:supported-privilege>
  <D:supported-privilege>
    <D:privilege><D:unlock/></D:privilege>
    <D:description xml:lang="en">#{Privilege.priv_unlock.description}</D:description>
  </D:supported-privilege>
  <D:supported-privilege>
    <D:privilege><D:write/></D:privilege>
    <D:description xml:lang="en">#{Privilege.priv_write.description}</D:description>
    <D:supported-privilege>
      <D:privilege><D:write-properties/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write_properties.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:bind/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_bind.description}</D:description>
    </D:supported-privilege>
  </D:supported-privilege>
</D:supported-privilege>
EOS
    
    setup_xml
    Privilege.priv_all.supported_privilege @xml, *supported_privileges
    assert_rexml_equal expected, @xml_out
  end
  
    
    
end
