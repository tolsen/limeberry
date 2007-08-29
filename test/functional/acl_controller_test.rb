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
require 'acl_controller'

# Re-raise errors caught by the controller.
class AclController; def rescue_action(e) raise e end; end

class AclControllerTest < DavFunctionalTestCase
  
  def setup
    super
    @controller = AclController.new
    @request    = HttpTestRequest.new
    @response   = ActionController::TestResponse.new

    @joe = User.find_by_name 'joe'
    @ren = User.find_by_name 'ren'
    @stimpy = User.find_by_name 'stimpy'

    @res = Bind.locate '/acl/res'
    @dir = Bind.locate '/acl/dir'
    @inherits = Bind.locate '/acl/dir/inherits'
    @disowned = Bind.locate '/acl/dir/disowned'
  end

  def test_assert_dav_element_name
    bad_elements = [ nil,
                     root_element('<D:bar xmlns:D="DAV:"/>'),
                     root_element('<D:foo xmlns:D="WEB:"/>') ]

    good_element = root_element '<D:foo xmlns:D="DAV:"/>'
    
    bad_elements.each do |e|
      assert_raise BadRequestError do
        @controller.send :assert_dav_element_name, e, 'foo'
      end
    end

    assert_nothing_raised BadRequestError do
      @controller.send :assert_dav_element_name, good_element, 'foo'
    end
  end

  def test_assert_dav_namespace
    assert_nothing_raised BadRequestError do
      @controller.send :assert_dav_namespace, root_element('<D:bar xmlns:D="DAV:"/>')
    end

    assert_raise BadRequestError do
      @controller.send :assert_dav_namespace, root_element('<D:bar xmlns:D="WEB:"/>')
    end
  end

  def test_one_dav_child
    [ '<foo><bar/></foo>',
      '<D:foo xmlns:D="DAV:"/>',
      '<D:foo xmlns:D="DAV:"><D:bar/><D:baz/></D:foo>',
      '<D:foo xmlns:D="DAV:"><D:bar/><D:bar/></D:foo>' ].each do |xml|
      assert_raise BadRequestError, "#{xml} does not have exactly one dav child" do
        @controller.send :one_dav_child, root_element(xml)
      end
    end

    [ '<D:foo xmlns:D="DAV:"><D:bar/></D:foo>',
      '<foo><D:bar xmlns:D="DAV:"/></foo>' ].each do |xml|
      root = root_element xml
      expected_child = root.elements[1]
      assert_nothing_raised BadRequestError do
        assert_equal expected_child, @controller.send(:one_dav_child, root)
        assert_equal expected_child, @controller.send(:one_dav_child, root, 'bar')
      end
    end

    [ '<foo><bar/></foo>',
      '<D:foo xmlns:D="DAV:"/>',
      '<D:foo xmlns:D="DAV:"><D:bar/><D:bar/></D:foo>' ].each do |xml|
      assert_raise BadRequestError, "#{xml} does not have exactly one dav child named bar" do
        @controller.send :one_dav_child, root_element(xml), 'bar'
      end
    end

    assert_nothing_raised BadRequestError do
      root = root_element '<D:foo xmlns:D="DAV:"><D:bar/><D:baz/></D:foo>'
      assert_equal root.elements[1], @controller.send(:one_dav_child, root, 'bar')
    end
    
  end

  def test_one_child
    [ '<foo/>',
      '<foo><bar/><baz/></foo>',
      '<D:foo xmlns:D="DAV:"/>',
      '<D:foo xmlns:D="DAV:"><D:bar/><D:baz/></D:foo>',
      '<D:foo xmlns:D="DAV:"><D:bar/><D:bar/></D:foo>' ].each do |xml|
      assert_raise BadRequestError, "#{xml} does not have exactly one child" do
        @controller.send :one_child, root_element(xml)
      end
    end

    [ '<foo><bar/></foo>',
      '<D:foo xmlns:D="DAV:"><D:bar/></D:foo>',
      '<foo><D:bar xmlns:D="DAV:"/></foo>',
      '<D:foo xmlns:D="DAV:"><bar/></D:foo>' ].each do |xml|
      root = root_element xml
      assert_nothing_raised BadRequestError do
        assert_equal root.elements[1], @controller.send(:one_child, root)
      end
    end
  end

  def test_one_child_propkey
    expected_propkey = PropKey.get 'DAV:', 'bar'
    [ '<D:foo xmlns:D="DAV:"><D:bar/></D:foo>',
      '<foo><D:bar xmlns:D="DAV:"/></foo>' ].each do |xml|
      assert_equal(expected_propkey,
                   @controller.send(:one_child_propkey, root_element(xml)))
    end
  end

  # not using full hrefs in the parse_acl tests because
  # @rootcoll_url is not being sent because
  # no request is being made
  def test_parse_acl

    body = <<EOS
<D:acl xmlns:D="DAV:"> 
  <D:ace> 
    <D:principal> 
      <D:href>/users/ren</D:href> 
    </D:principal> 
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
      <D:privilege><D:write/></D:privilege>  
    </D:grant> 
  </D:ace> 
  <D:ace> 
    <D:principal> 
      <D:property><D:owner/></D:property>  
    </D:principal> 
    <D:grant> 
      <D:privilege><D:read-acl/></D:privilege> 
      <D:privilege><D:write-acl/></D:privilege>  
    </D:grant> 
  </D:ace> 
  <D:ace> 
    <D:principal><D:all/></D:principal> 
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
    </D:grant> 
  </D:ace>
  <D:ace>
    <D:principal>
      <D:href>/users/stimpy</D:href>
    </D:principal>
    <D:deny>
      <D:privilege><D:write/></D:privilege>
      <D:privilege><D:read/></D:privilege>
    </D:deny>
  </D:ace>
</D:acl>
EOS

    expected =
      [ [ @ren, Ace::GRANT, Privilege.priv_read, Privilege.priv_write ],
        [ PropKey.get('DAV:', 'owner'), Ace::GRANT,
          Privilege.priv_read_acl, Privilege.priv_write_acl ],
        [ Group.all, Ace::GRANT, Privilege.priv_read ],
        [ @stimpy, Ace::DENY, Privilege.priv_write, Privilege.priv_read ] ]

    @controller.send :parse_acl, body do |*args|
      assert_equal expected.shift, args
    end

    assert_equal [], expected
  end

  def test_parse_acl_principal_not_found
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>/users/nonexistant</D:href>
    </D:principal>
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
    </D:grant> 
  </D:ace>
</D:acl>
EOS
    assert_raise(ConflictError) { @controller.send :parse_acl, body }
  end

  def test_parse_acl_principal_not_a_principal
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>/home/ren</D:href>
    </D:principal>
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
    </D:grant> 
  </D:ace>
</D:acl>
EOS
    assert_raise(ForbiddenError) { @controller.send :parse_acl, body }
  end

  def test_parse_acl_principal_not_valid_element
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <foo/>
    </D:principal>
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
    </D:grant> 
  </D:ace>
</D:acl>
EOS
    assert_raise(BadRequestError) { @controller.send :parse_acl, body }
  end

  def test_parse_acl_no_action
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>/users/ren</D:href>
    </D:principal>
  </D:ace>
</D:acl>
EOS
    assert_raise(BadRequestError) { @controller.send :parse_acl, body }
  end

  def test_parse_acl_too_many_actions
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>/users/ren</D:href>
    </D:principal>
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
    </D:grant> 
    <D:deny> 
      <D:privilege><D:write/></D:privilege> 
    </D:deny> 
  </D:ace>
</D:acl>
EOS
    assert_raise(BadRequestError) { @controller.send :parse_acl, body }
  end

  def test_parse_acl_bad_privilege
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>/users/ren</D:href>
    </D:principal>
    <D:grant> 
      <D:privilege><D:read_badly/></D:privilege> 
    </D:grant> 
  </D:ace>
</D:acl>
EOS
    assert_raise(ForbiddenError) { @controller.send :parse_acl, body }

    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>/users/ren</D:href>
    </D:principal>
    <D:grant> 
      <D:privilege><E:read xmlns:E="namespaceE"/></D:privilege> 
    </D:grant> 
  </D:ace>
</D:acl>
EOS
    assert_raise(ForbiddenError) { @controller.send :parse_acl, body }
  end

  def test_parse_acl_invert
    body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:invert>
      <D:principal>
        <D:href>/users/ren</D:href>
      </D:principal>
    </D:invert>
    <D:grant> 
      <D:privilege><D:read/></D:privilege> 
    </D:grant> 
  </D:ace>
</D:acl>
EOS
    assert_raise(ForbiddenError) { @controller.send :parse_acl, body }
  end
  
  def test_acl
    @request.body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>http://test.host/users/joe</D:href>
    </D:principal>
    <D:grant>
      <D:privilege><D:read/></D:privilege>
      <D:privilege><D:write/></D:privilege>
    </D:grant>
  </D:ace>
  <D:ace>
    <D:principal><D:authenticated/></D:principal>
    <D:grant>
      <D:privilege><D:read-current-user-privilege-set/></D:privilege>
    </D:grant>
  </D:ace>
</D:acl>
EOS

    acl '/acl/res', 'ren'
    assert_response 200

    assert Privilege.priv_read.granted?(@res, @joe)
    assert Privilege.priv_write.granted?(@res, @joe)
    
    assert Privilege.priv_read_current_user_privilege_set.granted?(@res, @joe)
    assert Privilege.priv_read_current_user_privilege_set.granted?(@res, @stimpy)
    assert Privilege.priv_read_current_user_privilege_set.granted?(@res, Group.authenticated)
    assert Privilege.priv_read_current_user_privilege_set.denied?(@res, Principal.unauthenticated)
    
    # make sure protected ace wasn't overwritten
    assert Privilege.priv_all.granted?(@res, @ren)

    assert_equal 2, @res.unprotected_aces.size
    assert_equal 3, @res.aces.size
  end

  def test_acl_overwriting
    Privilege.priv_read.grant @res, @stimpy

    @request.body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>http://test.host/users/joe</D:href>
    </D:principal>
    <D:grant>
      <D:privilege><D:read/></D:privilege>
    </D:grant>
  </D:ace>
</D:acl>
EOS
    acl '/acl/res', 'ren'
    assert_response 200

    assert Privilege.priv_read.denied?(@res.reload, @stimpy)
    assert Privilege.priv_read.granted?(@res, @joe)
  end

  def test_acl_inheritance
    Privilege.priv_all.grant @dir, @joe
    
    assert Privilege.priv_read.granted?(@inherits, @joe)
    assert Privilege.priv_read.granted?(@inherits, @ren)
    assert Privilege.priv_read.granted?(@inherits, @stimpy)
    
    assert Privilege.priv_read.denied?(@disowned, @joe)
    assert Privilege.priv_read.denied?(@disowned, @ren)
    assert Privilege.priv_read.granted?(@disowned, @stimpy)
    
    @request.body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>http://test.host/users/joe</D:href>
    </D:principal>
    <D:deny>
      <D:privilege><D:read/></D:privilege>
    </D:deny>
  </D:ace>
  <D:ace>
    <D:principal>
      <D:href>http://test.host/users/ren</D:href>
    </D:principal>
    <D:deny>
      <D:privilege><D:read/></D:privilege>
    </D:deny>
  </D:ace>
  <D:ace>
    <D:principal>
      <D:href>http://test.host/users/stimpy</D:href>
    </D:principal>
    <D:deny>
      <D:privilege><D:read/></D:privilege>
    </D:deny>
  </D:ace>
</D:acl>
EOS
    acl '/acl/dir', 'ren'
    assert_response 200

    assert Privilege.priv_read.denied?(@inherits, @joe) # inherited but overridden
    assert Privilege.priv_read.granted?(@inherits, @ren) # inherited & protected
    assert Privilege.priv_read.granted?(@inherits, @stimpy) # protected

    assert Privilege.priv_read.denied?(@disowned, @joe)
    assert Privilege.priv_read.denied?(@disowned, @ren)
    assert Privilege.priv_read.granted?(@disowned, @stimpy)
  end

  def test_acl_insufficient_perms
    @request.body = <<EOS
<D:acl xmlns:D="DAV:">
  <D:ace>
    <D:principal>
      <D:href>http://test.host/users/stimpy</D:href>
    </D:principal>
    <D:grant>
      <D:privilege><D:read/></D:privilege>
    </D:grant>
  </D:ace>
</D:acl>
EOS
    acl '/acl/res', 'stimpy'
    assert_response 403

    assert Privilege.priv_read.denied?(@res, @stimpy)
  end

    
  
    
  
  # helpers
  def root_element(xml) REXML::Document.new(xml).root; end
  
end
