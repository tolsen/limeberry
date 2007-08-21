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

require 'constants'

class Ace < ActiveRecord::Base

  unless defined?(GRANT)
    GRANT = "g"
    DENY = "d"
  end

  validates_inclusion_of :grantdeny, :in => [ GRANT, DENY ]

  before_save :regenerate_principal

  belongs_to :resource
  belongs_to :principal
  has_and_belongs_to_many :privileges

  # if principal is of DAV:property type
  belongs_to(:property_namespace,
             :foreign_key => "property_namespace_id",
             :class_name => "Namespace")
  
  acts_as_list :scope => 'resource_id = #{resource_id} AND protected = #{protected}'

  def property_derived_principal?() !property_namespace.nil?; end

  def regenerate_principal
    case self.property_namespace_id
    when nil, 0
      return
    when -1   # DAV:self
      raise ForbiddenError unless self.resource.is_a? Principal
      self.principal = self.resource
      return
    end

    pk = propkey

    # special case DAV:owner for bootstrapping when creating initial resources
    # (/principals/limeberry bind does not exist yet)
    if pk == PropKey.get('DAV:', 'owner')
      self.principal = resource.owner
    elsif self.resource.liveprops.include? pk
      root = REXML::Document.new(self.resource.liveprops[pk]).root
      self.principal = Property.element_to_principal root
    else
      property = self.resource.properties.find_by_propkey(pk)
      raise BadPropertyHrefError if property.nil?
      self.principal = property.to_principal
    end
  rescue BadPropertyHrefError => e
    logger.debug "bad property href!"
    logger.debug e.backtrace.join("\n")
    principal = nil
  end

  def propkey() PropKey.get property_namespace.name, property_name; end

  # <ace> part of propfind on DAV:acl
  def elem(xml, inherited)
    xml.D :ace do

      xml.D(:principal) do
        case property_namespace_id
        when nil, 0
          principal.principal_url(xml)
        when -1
          xml.D :self
        else
          xml.D(:property){ propkey.xml(xml) }
        end
      end

      action = (grantdeny == GRANT) ? :grant : :deny
      xml.D(action) do
        privileges.each { |p| p.elem(xml) }
      end

      xml.D(:protected) if protected?

      if inherited
        xml.D(:inherited) { resource.href(xml) }
      end

    end
  end

  
end
