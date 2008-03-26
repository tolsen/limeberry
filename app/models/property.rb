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

require 'rexml/document'
require 'errors'
require 'uri'

class Property < ActiveRecord::Base

  before_save { |p| p.resource.owner.save! }  # makes sure enough quota is available
  before_destroy { |p| @owner = p.resource.owner }
  after_destroy { |p| @owner.replenish_quota(p.value.size) ; @owner.save! }
  
  validates_uniqueness_of :name, :scope => [ :namespace_id, :resource_id ]

  belongs_to :namespace
  belongs_to :resource

  def propkey
    PropKey.get(namespace.name, name)
  end
  
  def propkey=(propkey)
    self.namespace = Namespace.find_or_create_by_name!(propkey.ns)
    self.name = propkey.name
  end

  # takes in xml string
  def xml=(xml)
    self.element = REXML::Document.new(xml).root
  end

  def element
    REXML::Document.new(value).root
  end

  # takes in REXML::Element
  def element=(element)
    self.namespace = Namespace.find_or_create_by_name!(element.namespace)
    self.name = element.name
    self.value = Utility.xml_print element
  end

  def resource=(newresource)
    unless self.value.nil?
      valuesize = self.value.size
      self.resource.owner.replenish_quota valuesize unless
        self.resource.nil? or
        self.resource.owner == newresource.owner
      newresource.owner.deplete_quota valuesize
    end
    write_attribute("resource_id", newresource.id)
  end
    
  def value=(newvalue)
    unless resource.nil?
      old_size = self.value.nil? ? 0 : self.value.size
      self.resource.owner.used_quota += (newvalue.size - old_size)
    end
    write_attribute("value", newvalue)
  end

  def to_principal
    Property.element_to_principal element
  end

  private

  def after_save
    resource.aces.select{ |ace| ace.property_derived_principal?}.each do |ace|
      ace.regenerate_principal
    end
  end

  public

  class << self
    def xml_wrap(propkey, contents, xml = nil)
      target = ""

      if xml.nil?
        xml = Builder::XmlMarkup.new(:indent => Limeberry::XML_INDENT,
                                     :target => target)
      end
      
      propkey.xml_with_unescaped_text(xml, contents)
      target
    end

    def element_to_principal(element)
      href = element.elements[1, 'D:href']
      raise BadPropertyHrefError if href.nil?
      url = href.text
      full_path = url.match(/^http:\/\//) ? URI.split(url)[6] : url
      path = full_path.sub /^#{BASE_WEBDAV_PATH}/, ''
      principal = Bind.locate path
      raise BadPropertyHrefError unless principal.is_a? Principal
      principal
    rescue REXML::ParseException, URI::InvalidURIError, NotFoundError => e
      raise BadPropertyHrefError
    end
      
  end

end

