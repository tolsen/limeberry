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

class UserTest < DavUnitTestCase

  def setup
    super
    @joe = User.find_by_name 'joe'
  end

  def test_make
    assert_equal @joe, User.find_by_name("joe")
    assert_equal @joe, Bind.locate(File.join(User::USERS_COLLECTION_PATH,"joe"))
    assert_equal @joe, Bind.locate(File.join(Principal::PRINCIPALS_COLLECTION_PATH,"joe"))
    assert_equal @joe, @joe.owner
    assert Group.authenticated.has_member?(@joe)
  end

  def test_make_home_folder
    home_folder = Bind.locate(File.join(User::HOME_COLLECTION_PATH,"joe"))
    assert_equal @joe, home_folder.owner
    assert Privilege.priv_all.granted?(home_folder, @joe)
  end

  def test_make_privileges
    assert Privilege.priv_read.granted?(@joe, @joe)
    assert Privilege.priv_write.granted?(@joe, @joe)
    assert Privilege.priv_read_acl.granted?(@joe, @joe)
    assert !Privilege.priv_write_acl.granted?(@joe, @joe)
  end

  def test_destroy
    collection = @joe.home_collection
    assert_nothing_raised { @joe.destroy }
    assert_nil User.find_by_name("joe")
  end

  def test_destroy_user_with_owned_resources
    Collection.mkcol_p("/home/joe/dir", @joe)
    @joe.destroy
    assert_equal Principal.limeorphanage, Bind.locate("/home/joe/dir").owner
  end

  def test_put_user
    options = {:name => "test", :password => "test", :displayname => "test"}
    response = User.put options
    assert_equal 201, response.status.code

    u=User.find_by_name(options[:name])
    assert_not_nil u

    options ={:name => "test", :displayname => "test1"}
    response = User.put options
    assert_equal 204, response.status.code
    u.reload
    assert_equal u.displayname,"test1"
    u.destroy
  end

  def test_principal_url
    out = ""
    xml = Builder::XmlMarkup.new(:target => out)
    @joe.principal_url(xml)
    assert_equal("<D:href>#{User::USERS_COLLECTION_PATH}/joe</D:href>", out)
  end

  def test_password
    assert_equal "", @joe.password
  end

  def test_password_assign
    @joe.password = "bob"
    assert_equal User.digest_auth_hash("joe", "bob"), @joe.pwhash
  end
  
  def test_password_matches
    assert @joe.password_matches?("joe")
    @joe.password = "bob"
    assert @joe.password_matches?("bob")
  end
  
  def test_authenticate
    assert !User.authenticate("shara", "joe")
    assert !User.authenticate("joe", "sixpackofbee")
    assert_equal @joe, User.authenticate("joe", "joe")
  end
  
  def test_digest_auth_hash
    expected = Digest::MD5.hexdigest("user:#{AppConfig.authentication_realm}:pass")
    output = User.digest_auth_hash("user", "pass")
    assert_equal expected, output
  end
end
