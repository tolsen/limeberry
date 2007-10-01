$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + '/../lib'

require 'test/unit'
require 'test_helper'
require 'httpauth/digest'

class DigestSessionTest < Test::Unit::TestCase

  def setup
    remove_tmpdir
    create_tmpdir
  end
  
  def test_simple
    password = 'secret'
    
    server_challenge = HTTPAuth::Digest::Challenge.new :realm => 'httpauth@example.com'
    client_challenge = HTTPAuth::Digest::Challenge.from_header server_challenge.to_header
    assert_equal server_challenge.h, client_challenge.h
    client_credentials = HTTPAuth::Digest::Credentials.from_challenge client_challenge,
      :uri => '/post/12', :username => 'Marcél', :password => password, :method => 'GET'
    server_credentials = HTTPAuth::Digest::Credentials.from_header client_credentials.to_header
    assert server_credentials.validate({
      :password => password, :method => 'GET'})
    server_auth_info = HTTPAuth::Digest::AuthenticationInfo.from_credentials server_credentials
    client_auth_info = HTTPAuth::Digest::AuthenticationInfo.from_header server_auth_info.to_header
  end
end
