$:.unshift File.dirname(__FILE__)
$:.unshift File.dirname(__FILE__) + '/../lib'

require 'test/unit'
require 'digest/md5'

require 'test_helper'
require 'httpauth/digest'

class DigestSessionTest < Test::Unit::TestCase

  def setup
    remove_tmpdir
    create_tmpdir
    @opaque = Digest::MD5.hexdigest Time.now.to_s
  end
  
  def test_session_create_and_load
    h = {:username => 'bob', :password => 'secret'}
    session = HTTPAuth::Digest::Session.new @opaque, :tmpdir => tmpdir
    session.save h
    
    session = HTTPAuth::Digest::Session.new @opaque, :tmpdir => tmpdir
    assert_equal h, session.load
    
    session = HTTPAuth::Digest::Session.new @opaque, :tmpdir => tmpdir
    assert_equal h, session.load
  end
  
  def test_session_load_without_session
    session = HTTPAuth::Digest::Session.new @opaque, :tmpdir => tmpdir
    h = nil
    assert_nothing_raised do
      h = session.load
    end
    assert_equal({}, h)
  end
end