$:.unshift File.dirname(__FILE__) + '/../lib'

require 'test/unit'
require 'httpauth/basic'
require 'httpauth/exceptions'

class BasicTest < Test::Unit::TestCase
  def setup
    @secret_bob_credentials = 'Basic Ym9iOnNlY3JldA=='
    @authorizations = {
      @secret_bob_credentials => ['bob', 'secret'],
      'Basic bWFyY8OpbDpnb2Q=' => ["marc\303\251l", 'god']
      }
    @authentications = {
      "Basic realm=\"Admin\"" => 'Admin',
      "Basic realm=\"Admin Pages\"" => 'Admin Pages',
      "Basic realm=\"open=false\"" => 'open=false'
    }
  end
  
  def test_unpack_authorization
    @authorizations.each do |packed, unpacked|
      assert_equal unpacked, HTTPAuth::Basic.unpack_authorization(packed)
    end
  end
  
  def test_pack_authorization
    @authorizations.each do |packed, unpacked|
      assert_equal packed, HTTPAuth::Basic.pack_authorization(*unpacked)
    end
  end
  
  def test_get_credentials
    env = {'HTTP_AUTHORIZATION' => @secret_bob_credentials}
    assert_equal @authorizations[@secret_bob_credentials], HTTPAuth::Basic.get_credentials(env)
  end
  
  def test_pack_challenge
    @authentications.each do |packed, unpacked|
      assert_equal packed, HTTPAuth::Basic.pack_challenge(unpacked)
    end
  end
  
  def test_unpack_challenge
    @authentications.each do |packed, unpacked|
      assert_equal unpacked, HTTPAuth::Basic.unpack_challenge(packed)
    end
  end
  
  def test_invalid_input
    assert_raise(HTTPAuth::UnwellformedHeader) do
      HTTPAuth::Basic.unpack_challenge('Basic relm')
    end
    assert_raise(ArgumentError) do
      HTTPAuth::Basic.unpack_challenge('Digest data')
    end
    assert_raise(ArgumentError) do
      HTTPAuth::Basic.unpack_authorization('Digest data')
    end
  end
end