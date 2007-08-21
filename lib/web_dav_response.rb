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

require 'web_dav_response_bodies'
require 'status'

module DavResponse

  #Base response class
  class WebdavResponse
    attr_reader :headers
    attr_accessor :status
    
    def initialize status,initheaders={}
      @status= status
      @headers = Hash.new
      initheaders.each {|key,value|
        add_header(key,value)
      }
      init_body
    end
    
    def [](key)
      value = @headers[key.to_s.downcase] or return nil
      value.join(", ")
    end
    
    #overwrites value, if key present.
    def []=(key, val)
      unless val
        @headers.delete key.downcase
        return val 
      end
      @headers[key.downcase] = [val.to_str]
    end
    
    #adding a value(does not replace existing value, concats instead)
    def add_header(key, val)
      return if val.nil? || key.nil?
      @headers[key.to_s.downcase] ||= Array.new
      @headers[key.to_s.downcase] += [val.to_str]
    end
    
    def remove_header(key, val)
      return if @headers[key.to_s.downcase].nil?
      @headers[key.to_s.downcase].delete(val.to_str)
      @headers.remove_key(key.to_s.downcase) if @headers[key.to_s.downcase].empty?
    end
    
    def each_header
      return nil if @headers.nil?
      @headers.each_key{|key|yield key} 
    end
    
    def body
      nil
    end

    def body_stream
      nil
    end

    def stream?
      false
    end
    
    def each
      return nil if @headers.nil?
      @headers.each {|key,value| yield(key,value)}
    end

    def init_body
      #A general response has no body. So do nothing
    end
    
    def has_body?
      false
    end
  end

  class CopyWebdavResponse < WebdavResponse
    include MultiStatusResponseBody
  end
  
  class MoveWebdavResponse < WebdavResponse ; end


  class PropfindWebdavResponse < WebdavResponse
    include MultiStatusResponseBody
  end

  class ProppatchWebdavResponse < WebdavResponse
    include MultiStatusResponseBody
  end
  
  class MkcolWebdavResponse < WebdavResponse ; end
  
  class PutWebdavResponse < WebdavResponse ; end

  class LockWebdavResponse < WebdavResponse 
    include LockResponseBody
    def locktoken= locktoken
      add_header("Lock-Token","<#{locktoken}>")
    end
  end
  
  class BindWebdavResponse < WebdavResponse ; end
  
  class UnbindWebdavResponse < WebdavResponse ; end
  
  class RebindWebdavResponse < WebdavResponse ; end

  class UnlockWebdavResponse < WebdavResponse ; end
  
  class ErrorWebdavResponse < WebdavResponse ; end
  
  class OptionsWebdavResponse < WebdavResponse
    def initialize 
      super(Status::HTTP_STATUS_OK, {'DAV' => "1,2,bind", 'MS-Author-Via' => "DAV"})
      #The set of methods for a normal (non-collection, non-locked etc.) resource. We can add or remove from this as required
      ["COPY", "DELETE", "GET", "HEAD", "MOVE", "OPTIONS", "POST",
       "PROPFIND", "PROPPATCH", "PUT", "LOCK", "VERSION-CONTROL"].each { |method|
        add_header('allow', method)
      }
    end

  end
  
  class VersionControlWebdavResponse < WebdavResponse ; end
  
  class CheckoutWebdavResponse < WebdavResponse 
    def initialize
      super
      add_header("cache-control" => "no-cache")
    end
  end
  
  class CheckinWebdavResponse < WebdavResponse ; end
end
