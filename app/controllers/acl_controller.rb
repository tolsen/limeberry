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
require 'rexml/xpath'

class AclController < ApplicationController
  before_filter :assert_resource_found

  @@dav_ns = { 'D' => 'DAV:' }
  
  def acl
    Resource.transaction do 
      @resource.before_acl(@principal, *@if_locktokens)
      @resource.unprotected_aces.clear
      parse_acl request.cgi.stdinput do |principal, action, *privileges|
        @resource.aces.add principal, action, false, *privileges
      end
    end

    render :nothing => true
  end

  private

  def parse_acl(reqbody)
    root = REXML::Document.new(reqbody).root
    assert_dav_element_name(root, 'acl')
    
    REXML::XPath.each root, 'D:ace', @@dav_ns do |ace|
      REXML::XPath.each ace, 'D:invert', @@dav_ns do |invert|
        raise ForbiddenError # precondition DAV:no-invert
      end
      principal_el = one_dav_child ace, 'principal'
      child = one_dav_child principal_el
      case child.name
      when 'all' then principal = Group.all
      when 'authenticated' then principal = Group.authenticated
      when 'unauthenticated' then principal = Principal.unauthenticated
      when 'self' then principal = :self
      when 'property' then principal = one_child_propkey child
      when 'href'
        url = validate_and_trim_full_url child.text
        principal = Bind.locate url
        raise ForbiddenError unless principal.is_a? Principal # DAV:recognized-principal
      else
        raise BadRequestError
      end

      deny_el = REXML::XPath.first ace, 'D:deny', @@dav_ns
      grant_el = REXML::XPath.first ace, 'D:grant', @@dav_ns
      action = Ace::DENY

      if grant_el.nil?
        raise BadRequestError if deny_el.nil?
        action_el = deny_el
      else
        raise BadRequestError unless deny_el.nil?
        action = Ace::GRANT
        action_el = grant_el
      end
      
      privileges = REXML::XPath.match(action_el, 'D:privilege', @@dav_ns).map do |privilege|
        p = Privilege.find_by_propkey one_child_propkey(privilege)
        raise ForbiddenError if p.nil? # DAV:not-supported-privilege
        p
      end

      yield principal, action, *privileges
    end
  rescue NotFoundError => e
    logger.debug e.to_s
    logger.debug e.backtrace.join("\n")
    raise ConflictError  # DAV:recognized-principal
  rescue BadGatewayError => e
    logger.debug e.to_s
    logger.debug e.backtrace.join("\n")
    raise ForbiddenError # DAV:recognized-principal
  end

  def assert_dav_element_name(element, expected_name)
    unless (!element.nil? &&
            element.name == expected_name &&
            element.namespace == 'DAV:' )
      raise BadRequestError
    end
  end

  def assert_dav_namespace element
    raise BadRequestError unless element.namespace == 'DAV:'
  end

  def one_dav_child element, name = nil
    if name.nil?
      children = element.elements
      raise BadRequestError unless children.size == 1
      child = children[1]
      assert_dav_namespace child
      return child
    else
      children = REXML::XPath.match element, "D:#{name}", @@dav_ns
      raise BadRequestError unless children.size == 1
      return children[0]
    end
  end


  def one_child element
    children = element.elements
    raise BadRequestError unless children.size == 1
    children[1]
  end

  def one_child_propkey element
    child = one_child element
    PropKey.get child.namespace, child.name
  end
  

end
