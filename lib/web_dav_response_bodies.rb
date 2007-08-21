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

require "rexml_fixes"
require 'status'
require 'constants'


#converts an REXML xml document to a string
def self.xml_to_string doc
  xmldecl = REXML::XMLDecl.new(doc.version,doc.encoding)
  doc << xmldecl
  body = String.new
  doc.write body
  body
end


#module for creation of Responses
module DavResponse
  #Prop class : has namespace,name & value
  class Prop
    attr_reader :name,:namespace,:value

    def initialize namespace,name,value=nil
      @name = name
      @namespace = namespace
      @value = value
    end

    def == prop
      name == prop.name && namespace == prop.namespace && value == prop.value
    end

  end


  #corresponds to a propstat: has an array of props and
  #a status
  class Propstat
    include Enumerable
    attr_reader :status

    def initialize status
      @status = status
      @proplist = Array.new
    end

    def each
      @proplist.each do |prop|
        yield(prop)
      end
    end

    def prop_present? namespace,name,value
      if @proplist.nil?
        return false
      end
      @proplist.member? Prop.new(namespace,name,value)
    end

    def add_prop namespace,name,value=nil
      @proplist << Prop.new(namespace,name,value)
    end

    def concat propstat
      propstat.each do |prop|
        @proplist << prop
      end
    end

    def length
      @proplist.length
    end

  end

  #corresponds to a collection of propstats, for every
  #url we have one propstatcollection
  class PropstatCollection
    include Enumerable
    def initialize
      @prophash = Hash.new
    end
    def add_prop status,namespace,name,value=nil
      @prophash[status] ||= Propstat.new status
      @prophash[status].add_prop namespace,name,value
    end

    def set_all_status status
      newhash = Hash.new
      newhash[status] = Propstat.new status
      @prophash.each do |iter_status,propstat|
        newhash[status].concat propstat
      end
      @prophash = newhash
    end

    def [] status
      @prophash[status]
    end

    def each
      @prophash.each do |key,value|
        yield(key,value)
      end
    end
  end


  class Activelock
    include REXML
    attr_accessor :lockscope,:depth,:owner,:timeout,:locktoken,:lockroot

    def initialize( options = {} )
      @lockscope = options[:lockscope]
      @depth     = options[:depth]
      @owner     = options[:owner]
      @timeout   = options[:timeout]
      @locktoken = options[:locktoken]
      @lockroot  = options[:lockroot]
    end

    def to_s
      activelock_element = Element.new "D:#{Limeberry::ACTIVELOCK_ELEM}"
      activelock_element.add_namespace("#{Limeberry::XMLNS_ATTR}:D",Limeberry::DAV_NS)

      locktype_element = Element.new "D:#{Limeberry::LOCKTYPE_ELEM}",activelock_element
      locktype_element.add_element "D:#{Limeberry::WRITE_ELEM}"

      lockscope_element = Element.new "D:#{Limeberry::LOCKSCOPE_ELEM}",activelock_element
      lockscope_string = (@lockscope == 'X')?(Limeberry::EXCLUSIVE_ELEM):(Limeberry::SHARED_ELEM)
      scope_element = Element.new "D:#{lockscope_string}",lockscope_element

      depth_element = Element.new "D:#{Limeberry::DEPTH_ELEM}",activelock_element
      depth_string = (@depth == 'I')?("Infinity"):("0")
      depth_element.add_text depth_string

      unless @owner.nil?
        owner_element = Element.new "D:#{Limeberry::OWNER_ELEM}",activelock_element
        owner_info = Document.new @owner
        owner_element.add_element owner_info
      end

      unless @timeout.nil?
        timeout_element = Element.new "D:#{Limeberry::TIMEOUT_ELEM}",activelock_element
        timeout_element.add_text @timeout
      end
      unless @locktoken.nil?
        locktoken_element = Element.new "D:#{Limeberry::LOCKTOKEN_ELEM}",activelock_element
        lt_href_element = Element.new "D:#{Limeberry::HREF_ELEM}",locktoken_element
        lt_href_element.add_text @locktoken.to_s
      end

      lockroot_element = Element.new "D:#{Limeberry::LOCKROOT_ELEM}",activelock_element
      lr_href_element = Element.new "D:#{Limeberry::HREF_ELEM}",lockroot_element
      lr_href_element.add_text @lockroot.to_s
      activelock_element.to_s
    end
  end


  module MultiStatusResponseBody
    include REXML
    attr_reader :propstathash
    attr_reader :multistatushash
    attr_accessor :responsedescription
    def init_body
      @multistatushash = Hash.new
      @propstathash = Hash.new
    end

    def has_body?
      !((@multistatushash.nil? || @multistatushash.empty?) && (@propstathash.nil? || @propstathash.empty?))
    end

    def body
      return (has_body? ? to_xml : nil)
    end

    def body_stream
      return (has_body? ? StringIO.new(body) : nil)
    end

    def set_url_status url,status
      @multistatushash[status] ||= Array.new
      @multistatushash[status] << url
    end

    def add_prop url,status,namespace,name,value=nil
      @propstathash[url] ||= PropstatCollection.new
      @propstathash[url].add_prop status,namespace,name,value
    end

    def set_all_prop_status url,status
      unless @propstathash[url].nil?
        @propstathash[url].set_all_status status
      end
    end

    def each_url
      @propstathash.each {|url,propstatcollection| yield(url,propstatcollection)}
    end

    def merge propstatbody
      propstatbody.each_url do |url,propstatcollection|
        @propstathash[url] ||= propstatcollection
      end
    end

    private

    def to_xml
      doc = Document.new
      multistatus_element = Element.new "D:#{Limeberry::MULTISTATUS_ELEM}",doc
      multistatus_element.add_namespace("#{Limeberry::XMLNS_ATTR}:D",Limeberry::DAV_NS)

      @multistatushash.each do |status,urllist|
        response_element = Element.new "D:#{Limeberry::RESPONSE_ELEM}",multistatus_element
        urllist.each do |url|
          url_element = Element.new "D:#{Limeberry::HREF_ELEM}",response_element
          url_element.add_text url
        end
        status_element = Element.new "D:#{Limeberry::STATUS_ELEM}",response_element
        status_element.add_text status.write
      end

      @propstathash.each do |url,propstatcollection|
        response_element = Element.new "D:#{Limeberry::RESPONSE_ELEM}",multistatus_element
        url_element = Element.new "D:#{Limeberry::HREF_ELEM}",response_element
        #url = (url[0] == 47) ? "#{BASE_WEBDAV_PATH}#{url}" : "#{BASE_WEBDAV_PATH}/#{url}"
        url = File.join(BASE_WEBDAV_PATH,url)
        url_element.add_text url
        propstatcollection.each do |status,propstat|
          propstat_element = propstat_to_xml propstat
          response_element.add_element propstat_element
        end
      end

      unless @responsedescription.nil?
        description_element = Element.new "D:#{Limeberry::RESPONSEDESCRIPTION_ELEM}",multistatus_element
        description_element.add_text @responsedescription
      end
      string = Dav.xml_to_string doc
    end

    def propstat_to_xml propstat
      propstat_element = Element.new "D:#{Limeberry::PROPSTAT_ELEM}"
      prop_element = Element.new "D:#{Limeberry::PROP_ELEM}",propstat_element
      propstat.each do |prop|
        propname_element = prop_to_xml prop
        prop_element.add_element propname_element
      end
      status_element = Element.new "D:#{Limeberry::STATUS_ELEM}",propstat_element
      status_element.add_text propstat.status.write
      propstat_element
    end

    def prop_to_xml prop
      propname_element = nil

      if prop.namespace == Limeberry::DAV_NS
        propname_element = Element.new "D:#{prop.name}"
      else
        propname_element = Element.new prop.name
        propname_element.add_namespace(prop.namespace)
      end

      unless prop.value.nil?
        value = sanitize_if_date prop.namespace,prop.name,prop.value
        propname_element.innerXML= value.to_s
      end
      propname_element
    end

    def sanitize_if_date namespace,name,value
      return value unless value.is_a? Time
      value.utc
      if namespace == Limeberry::DAV_NS and name == Limeberry::CREATIONDATE_LIVEPROP
        value = value.strftime("%Y-%m-%dT%H:%M:%SZ") #ISO8601
      else
        value = value.strftime("%a, %d %b %Y %H:%M:%S %Z") #RFC 1123
      end
      value
    end
  end


  module LockResponseBody
    include REXML
    include MultiStatusResponseBody
    def body
      return (has_body? ? to_xml : nil)
    end

    def body_stream
      return (has_body? ? StringIO.new(body) : nil)
    end

    def add_activelock activelock
      @locks ||= Array.new
      @locks << activelock
    end

    def has_body?
      super || !@locks.nil?
    end

    private
    def to_xml
      return super if @locks.nil?
      doc = Document.new
      lockprop_element = Element.new "D:#{Limeberry::PROP_ELEM}",doc
      lockprop_element.add_namespace("#{Limeberry::XMLNS_ATTR}:D",Limeberry::DAV_NS)
      lockdiscovery_element = Element.new "D:#{Limeberry::LOCKDISCOVERY_ELEM}",lockprop_element
      @locks.each {|lock|
        activelock_element = Document.new lock.to_s
        lockdiscovery_element.add_element activelock_element
      }
      string = Dav.xml_to_string doc
    end
  end

end

