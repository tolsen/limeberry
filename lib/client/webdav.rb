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

require 'net/https'

#Adding Webdav specific method to HTTP Libraries
module Net

  #
  #Reopen HTTP and add classes and methods for WebDAV
  #
  class HTTP
    #
    #Additional WebDav methods not a part of Net::HTTP
    #

    #sends a REPORT request to the +path+ and gets a response,
    #as an HTTPResponse object
    def report(path, body, initheader = nil)
      request(Report.new(path, initheader), body)
    end
    
    #sends a VERSION-CONTROL request to the +path+ and gets a response,
    #as an HTTPResponse object
    def version_control(path, body, initheader = nil)
      request(VersionControl.new(path, initheader), body)
    end
    
    #sends a CHECKOUT request to the +path+ and gets a response,
    #as an HTTPResponse object
    def checkout(path, body, initheader = nil)
      request(Checkout.new(path, initheader), body)
    end
    
    #sends a CHECKIN request to the +path+ and gets a response,
    #as an HTTPResponse object
    def checkin(path, body, initheader = nil)
      request(Checkin.new(path, initheader), body)
    end
    
    #sends a UNCHECKOUT request to the +path+ and gets a response,
    #as an HTTPResponse object
    def uncheckout(path, body, initheader = nil)
      request(Uncheckout.new(path, initheader), body)
    end
    
    #sends a MKWORKSPACE request to the +path+ and gets a response,
    #as an HTTPResponse object
    def mkworkspace(path, body, initheader = nil)
      request(Mkworkspace.new(path, initheader), body)
    end
    
    #sends a UPDATE request to the +path+ and gets a response,
    #as an HTTPResponse object
    def update(path, body, initheader = nil)
      request(Update.new(path, initheader), body)
    end

    #sends a LABEL request to the +path+ and gets a response,
    #as an HTTPResponse object
    def label(path, body, initheader = nil)
      request(Label.new(path, initheader), body)
    end

    #sends a MERGE request to the +path+ and gets a response,
    #as an HTTPResponse object
    def merge(path, body, initheader = nil)
      request(Merge.new(path, initheader), body)
    end

    #sends a BASELINE-CONTROL request to the +path+ and gets a response,
    #as an HTTPResponse object
    def baseline_control(path, body, initheader = nil)
      request(BaselineControl.new(path, initheader), body)
    end

    #sends a MKACTIVITY request to the +path+ and gets a response,
    #as an HTTPResponse object
    def mkactivity(path, body, initheader = nil)
      request(Mkactivity.new(path, initheader), body)
    end

    #sends a ACL request to the +path+ and gets a response,
    #as an HTTPResponse object
    def acl(path, body, initheader = nil)
      request(Acl.new(path, initheader), body)
    end

    #sends a MKREDIRECTREF request to the +path+ and gets a response,
    #as an HTTPResponse object
    def mkredirectref(path, body, initheader = nil)
      request(Mkredirectref.new(path, initheader), body)
    end


    #sends a UPDATEREDIRECTREF request to the +path+ and gets a response,
    #as an HTTPResponse object
    def updateredirectref(path, body, initheader = nil)
      request(Updateredirectref.new(path, initheader), body)
    end


    
    #
    #WebDAV Authoring Basic methods(DeltaV) -- draft-ietf-webdav-rfc2518bis-15
    #Additional classes for each WebDAV method
    #
    
    class Report < HTTPRequest
      METHOD = 'REPORT'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class VersionControl < HTTPRequest
      METHOD = 'VERSION-CONTROL'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    class Checkout < HTTPRequest
      METHOD = 'CHECKOUT'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    class Checkin < HTTPRequest
      METHOD = 'CHECKIN'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    class Uncheckout < HTTPRequest
      METHOD = 'UNCHECKOUT'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    class Mkworkspace < HTTPRequest
      METHOD = 'MKWORKSPACE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    class Update < HTTPRequest
      METHOD = 'UPDATE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    class Label < HTTPRequest
      METHOD = 'LABEL'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    #
    #DeltaV Advanced Methods
    #
    
    class Merge < HTTPRequest
      METHOD = 'MERGE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end
    
    class BaselineControl < HTTPRequest
      METHOD = 'BASELINE-CONTROL'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    class Mkactivity < HTTPRequest
      METHOD = 'MKACTIVITY'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    #
    #Access control methods
    #
    
    class Acl < HTTPRequest
      METHOD = 'ACL'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = false
    end

    #
    #Bind methods
    #
    #
    #BIND adds a new binding to an existing resource.
    #The newly created binding can be used to access the resource.
    class Bind < HTTPRequest
      METHOD = 'BIND'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = false
    end

    #
    #UNBIND removes the specified binding of the resource.
    #Note: if all bindings to a resource are removed, the server may delete the resource.
    #
    #
    class Unbind < HTTPRequest
      METHOD = 'UNBIND'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = false
    end

    #
    #Removes a binding to some resource and associates it with another binding.
    #
    class Rebind < HTTPRequest
      METHOD = 'REBIND'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = false
    end

    #
    #Redirect Reference methods
    #

    class Mkredirectref < HTTPRequest
      METHOD = 'MKREDIRECTREF'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Updateredirectref < HTTPRequest
      METHOD = 'UPDATEREDIRECTREF'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end


    #
    #Search Methods
    #
    class Search < HTTPRequest
      METHOD = 'SEARCH'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

  end
  
  #Responses
  class HTTPMultiStatus < HTTPSuccess                # 207
    HAS_BODY = true
  end

  
end
