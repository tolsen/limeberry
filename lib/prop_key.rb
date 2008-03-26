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

# Property keys
class PropKey

  # Namespace constants.
  LIMEDAV_NS     = 'http://namespace.limedav.com/limedav/1.0/'
  LIMEDAV_PREFIX = 'LS:'

  DAV_NS          = 'DAV:'

  # List of all supported DAV: properties.
  DAV_PROPERTIES = %w{getcontentlength   getcontenttype   creationdate
                      getlastmodified    displayname      resourcetype
                      getcontentlanguage getetag          lockdiscovery
                      source             supportedlock    owner
                      acl}

  attr_reader :ns, :name
  cattr_reader :keys
  @@keys = {}

  class << self # Class Methods

    # Creates singleton methods for DAV: properties so that they are easily
    # accessible.
    #
    # === Example:
    #  propkey = PropertyKey.lockdiscovery   ==>   #<PropertyKey:...>
    DAV_PROPERTIES.each do |propname|
      class_eval <<-"EOF"
        def #{propname}
          get(DAV_NS, :#{propname})
        end
      EOF
    end


    # Returns a property key
    #
    # Since the constructor is private, this method and the DAV: shortcut
    # methods are the only available avenues towards generating keys.
    
    def get(ns, name)
      name = name.to_s if name.is_a?(Symbol)
      if @@keys[ns + name].nil?
        @@keys[ns + name] = new(ns, name).freeze
      end
      @@keys[ns + name]
    end

  end # End Class Methods

  def tag_args xml
    if dav?
      args = [:D, name.to_sym]
      args.push "xmlns:D" => "DAV:" unless xml.dav_ns_declared!
      return args
    else
      return ["R:#{name}", { "xmlns:R" => ns }]
    end
  end
  
  
  def xml(xml, &block)
    if block_given?
      xml.tag!(*tag_args(xml), &block)
    else
      xml.tag!(*tag_args(xml))
    end
  end

  def xml_with_unescaped_text(xml, text)
    targs = tag_args(xml) << text
    xml.tag_with_unescaped_text!(*targs)
  end
  
  
  def to_s
    @ns + @name
  end

  def eql?(other)
    self.to_s == other.to_s
  end
  alias == eql?

  def dav?
    @ns == DAV_NS
  end

  def <=>(other)
    self.to_s <=> other.to_s
  end

  private

  def initialize(ns, name)
    @ns, @name = ns, name
  end

end
