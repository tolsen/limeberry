$:.unshift File.dirname(__FILE__) + '/../lib'

require 'test/unit'
require 'httpauth/digest'
require 'base64'

class DigestUtilsTest < Test::Unit::TestCase
  def setup
    @data = {
      :credentials => {
        'Digest username="marcél", realm="testrealm@host.com", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", uri="/dir/index.html", qop=auth, nc=00000001, cnonce="0a4f113b", response="6629fae49393a05397450978507c4ef1", opaque="5ccc069c403ebaf9f0171e9517f40e41"' => {:username => 'marcél', :realm => 'testrealm@host.com', :nonce => 'dcd98b7102dd2f0e8b11d0f600bfb0c093', :uri => '/dir/index.html', :qop => 'auth', :nc => 1, :cnonce => '0a4f113b', :response => '6629fae49393a05397450978507c4ef1', :opaque => '5ccc069c403ebaf9f0171e9517f40e41'}
      },
      :challenge => {
        'Digest realm="mp@mount.dwerg.net", nonce="QG4LS2UcBAA=b978f6e632f6b9f7a8927ab48e20ef61d967552b", algorithm=MD5, qop="auth"' => {:realm => 'mp@mount.dwerg.net', :nonce => 'QG4LS2UcBAA=b978f6e632f6b9f7a8927ab48e20ef61d967552b', :algorithm => 'MD5', :qop => ['auth']}
      },
      :auth => {
        'nextnonce=00000001' => { :nextnonce => 1 },
        'nextnonce=00000002, qop=auth, cnonce="0a4f113b", nc=00000001' => {
          :nextnonce => 2, :qop => 'auth', :cnonce => '0a4f113b', :nc => 1 },
        'nextnonce=00000002, qop=auth, cnonce="0a4f113b", nc=00000001, rspauth="5ccc069c403ebaf9f0171e9517f40e41"' => {
          :nextnonce => 2, :qop => 'auth', :cnonce => '0a4f113b', :nc => 1,
          :rspauth => '5ccc069c403ebaf9f0171e9517f40e41' }
      }
    }
  end
  
  def test_filter_h_on
    assert_equal({1=>1,2=>2}, HTTPAuth::Digest::Utils.filter_h_on({1=>1,2=>2,3=>3}, [1,2]))
    assert_equal({1=>1}, HTTPAuth::Digest::Utils.filter_h_on({1=>1,2=>2}, [1]))
    assert_equal({2=>2}, HTTPAuth::Digest::Utils.filter_h_on({1=>1,2=>2}, [2]))
    assert_equal({}, HTTPAuth::Digest::Utils.filter_h_on({1=>1,2=>2}, []))
    assert_equal({}, HTTPAuth::Digest::Utils.filter_h_on({}, []))
  end
  
  def test_encode_directives
    @data.each do |k,v|
      v.each do |encoded, directives|
        assert_equal encoded.length, HTTPAuth::Digest::Utils.encode_directives(directives, k).length, "In #{k}, in #{encoded}"
      end
    end
  end
  
  def test_decode_directives
    @data.each do |k,v|
      v.each do |encoded, directives|
        assert_equal directives, HTTPAuth::Digest::Utils.decode_directives(encoded, k), "In #{k}, in #{encoded}"
      end
    end
  end
  
  def test_decode_hacks
    # Test to see if the IE and Safari directive encode problems are HACKed around
    directives = HTTPAuth::Digest::Utils.decode_directives("Digest qop=\"auth\", algorithm=\"MD5\"", :credentials)
    assert_equal 'auth', directives[:qop]
    assert_equal 'MD5', directives[:algorithm]
  end
  
  def test_encode_decode_mirror
    @data.each do |k,v|
      v.each do |_, directives|
        assert_equal directives,  
          HTTPAuth::Digest::Utils.decode_directives(
            HTTPAuth::Digest::Utils.encode_directives(directives, k),
          k), "In #{k}, in #{directives.inspect}"
      end
    end
  end
  
  def test_digest_concat
    assert_equal '', HTTPAuth::Digest::Utils.digest_concat
    assert_equal 'a', HTTPAuth::Digest::Utils.digest_concat('a')
    assert_equal 'a:b:c', HTTPAuth::Digest::Utils.digest_concat('a', 'b', 'c')
  end
  
  def test_digest_h
    assert_raise(TypeError) do
      HTTPAuth::Digest::Utils.digest_h(nil)
    end
    assert_equal 32, HTTPAuth::Digest::Utils.digest_h('a').length
  end
  
  def test_digest_kd
    assert_equal 32, HTTPAuth::Digest::Utils.digest_kd(nil, nil).length
    assert_equal 32, HTTPAuth::Digest::Utils.digest_kd(nil, 'b').length
    assert_equal 32, HTTPAuth::Digest::Utils.digest_kd('a', nil).length
    assert_equal 32, HTTPAuth::Digest::Utils.digest_kd('a', 'b').length
  end
  
  def test_digest_a1
    [
      ['742ec081c96652ff7aed5d819ea0061b', {:username => 'marcél',
        :realm => 'testrealm@host.com',
        :password => 'secret'
      }, {}],
      ['0630c5b7ea77f10dcca9bbcabb574cf9', {:username => 'marcél',
        :realm => 'testrealm@host.com',
        :password => 'secret',
        :nonce => 'dcd98b7102dd2f0e8b11d0f600bfb0c093',
        :cnonce => '0a4f113b',
        :algorithm => 'MD5-sess'
      }, {}],
      ['18c37cbf78f82ee4fcce3d457d02091a', {:username => 'Mustafa',
        :realm => 'testrealm@host.com',
        :password => 'Circle Of Life',
        :nonce => 'dcd98b7102dd2f0e8b11d0f600bfb0c093',
        :cnonce => '0a4f113b',
        :algorithm => 'MD5-sess'
      }, {}],
      ['4501c091b0366d76ea3218b6cfdd8097', {}, {:digest => '742ec081c96652ff7aed5d819ea0061b'}],
      ['52cac169f0b9ffbc38f91a50fdc86097', {:nonce => 'dcd98b7102dd2f0e8b11d0f600bfb0c093',
        :cnonce => '0a4f113b',
        :algorithm => 'MD5-sess'
      }, {:digest => '742ec081c96652ff7aed5d819ea0061b'}]
    ].each_with_index do |expected, i|
      assert_equal expected[0], HTTPAuth::Digest::Utils.digest_a1(expected[1], expected[2]), "In #{i}:"
    end
  end
  
  def test_request_digest_a2
    [
      ['bfdaff59f040a7a7e2a96fc32841dcf7', { :method => 'GET', :uri => '/posts/1'}],
      ['7c79b99028e43d5bdb6110a6b579344e', { :method => 'POST', :uri => '/posts/4'}],
      ['1db0cc6a00afef1763eb73abf5a0b151', { :method => 'TRACE', :uri => '/posts', :request_body => "I'm a request body!"}],
      ['e73cf9345dfdd81c1c649d5c2eb46566', { :method => 'TRACE', :uri => '/posts', :request_body => "I'm a request body!", :qop => 'auth-int'}]
    ].each_with_index do |expected,i|
      assert_equal expected[0], HTTPAuth::Digest::Utils.request_digest_a2(expected[1]), "In #{i}:"
    end
  end
  
  def test_create_nonce
    salt = 'My secret salt'
    assert HTTPAuth::Digest::Utils.create_nonce(salt).length > 32
    assert HTTPAuth::Digest::Utils.create_nonce(salt) != HTTPAuth::Digest::Utils.create_nonce(salt)
  end
  
  def test_create_opaque
    assert_equal 32, HTTPAuth::Digest::Utils.create_opaque.length
    assert HTTPAuth::Digest::Utils.create_opaque != HTTPAuth::Digest::Utils.create_opaque
  end
end
