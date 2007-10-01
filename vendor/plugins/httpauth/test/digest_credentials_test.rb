$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + '/../lib'

require 'test_helper'
require 'httpauth/digest'

class DigestCredentialsTest < Test::Unit::TestCase
  fixtures :credentials
  
  def setup
    remove_tmpdir
    create_tmpdir
  end
  
  def test_empty_initialization_from_header
    assert_raise HTTPAuth::UnwellformedHeader do
      HTTPAuth::Digest::Credentials.from_header nil, :tmpdir => tmpdir
    end
    assert_raise HTTPAuth::UnwellformedHeader do
      HTTPAuth::Digest::Credentials.from_header '', :tmpdir => tmpdir
    end
  end
  
  def test_initialization_from_header
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_marcel], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert_equal @@credentials[:from_marcel][:username], credentials.username
    assert_equal @@credentials[:from_marcel][:realm], credentials.realm
  end
  
  def test_validate
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_safari2], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert credentials.validate(:method => 'GET', :password => 'secret')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_safari2], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert credentials.validate(:method => 'GET', :digest => '659ac260760c38dce4d67663b74a71d2')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_safari2], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert !credentials.validate(:method => 'GET', :digest => '659ac260760c38dce4d67663b74')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_thijs], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert !credentials.validate(:method => 'GET', :password => 'secret')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_thijs], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert credentials.validate(:method => 'GET', :password => 'wrong')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_safari], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert !credentials.validate(:method => 'GET', :password => 'wrong')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_safari], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert credentials.validate(:method => 'GET', :password => 'secret')  
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_mustafa], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert credentials.validate(:method => 'GET', :password => 'Circle Of Life')
    
    directives = HTTPAuth::Digest::Utils.encode_directives(@@credentials[:from_safari], :credentials)
    credentials = HTTPAuth::Digest::Credentials.from_header directives, :tmpdir => tmpdir
    assert credentials.validate(:method => 'GET', :password => 'secret')
  end
  
  def test_from_blank
    credentials = HTTPAuth::Digest::Credentials.new :nc=>1,
      :uri=>"/",
      :opaque=>"0cf3b80a175d023ce40e7ad878dd4a2b",
      :realm=>"Admin pages",
      :nonce=>"MjAwNi0wOS0wNCAxNDoxNTo1Nzo2MjcyNDA6NDJmZDNjY2NiNzQ3ZjU1MDlhNTIyYTI1MWI1MTkzZm",
      :algorithm=>"MD5",
      :username=>"admin",
      :digest=>"659ac260760c38dce4d67663b74a71d2",
      :method=>"GET",
      :response=>"5e7bbe24dac88a1936edf1a89cae6168",
      :cnonce=>"30b49be53eab919d",
      :qop=>"auth"
    assert credentials.validate({})
  end
end