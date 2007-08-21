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

# $URL$
# $Id$	


#httpauth plugin required
require 'httpauth/basic'
require 'httpauth/digest'


module Limeberry
  # Authentication tokens
  # implements methods
  # to_principal
  # header (For Digest authentication)

  REALM = ::AppConfig.authentication_realm
  
  ## Simple AuthToken
  class SimpleAuthToken 
    
    def initialize(username)
      @username = username
    end

    def to_principal
      if @username
        Principal.find_by_name(@username)
      else
        Principal.unauthenticated
      end
    end
    
  end
  
  
  ## Basic AuthToken
  class BasicAuthToken

    def initialize(auth_header)
      @username, @password = HTTPAuth::Basic.unpack_authorization(auth_header) unless auth_header.nil?
    end

    def to_principal
      return Principal.unauthenticated if @username.nil?
      principal = User.find_by_name(@username)
      raise UnauthorizedError unless (principal and principal.password_matches? @password)
      principal
    end
    
    def www_authenticate
      HTTPAuth::Basic.pack_challenge(REALM)
    end
    
  end


  #Digest Authenticate token provides Lemonade abstraction to httpauth 
  #httpauth does not allow match on pwhash which is stored in the UserRecord. We might need to
  #open Credentials class and provide a validate method on pwhash

  ## Digest AuthToken
  class DigestAuthToken
    include HTTPAuth::Digest

    def initialize(auth_header, method)
      @method = method.upcase
      @credentials = Credentials.from_header(auth_header)
    rescue HTTPAuth::UnwellformedHeader
      raise BadRequestError
    end
    
    def to_principal
      if @credentials
        principal = User.find_by_name(@credentials.username)
        
        raise UnauthorizedError unless principal && @credentials.validate_digest(principal.pwhash, :method => @method)      
        principal
      else
        Principal.unauthenticated
      end
    end

    def authentication_info
      return nil if @credentials.nil?
      (AuthenticationInfo.from_credentials @credentials).to_header
    end

    def www_authenticate
      Challenge.new(:realm=> REALM, :qop => ['auth']).to_header
    end

  end
end
