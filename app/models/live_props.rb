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

require 'dav_xml_builder'

class LiveProps

  def initialize(resource)
    @liveprops = resource.class.send(:liveprops)
    @resource = resource
    @liveprops_allprop = @liveprops.find_all{ |pk, pi| pi.allprop? }
  end

  def [](propkey, xml = nil, principal = nil)
    dispatch_to_reader(propkey, @liveprops[propkey], xml, principal)
  end

  def []=(propkey, value, principal = nil)
    propinfo = @liveprops[propkey]
    if propinfo.protected?
      # TODO: 403 (Forbidden): The client has attempted to set a
      # protected property, such as DAV:getetag. If returning this
      # error, the server SHOULD use the precondition code
      # 'cannot-modify-protected-property' inside the response
      # body.
      raise ForbiddenError
    else
      @resource.send("#{propinfo.method}=", value)
    end
  end

  # this one will run in O(1) instead of Enumerable's O(n)
  def include?(propkey)
    @liveprops.include?(propkey)
  end

  def assert_read(propkey, principal)
    @liveprops[propkey].assert_read_granted(@resource, principal)
  end

  # all props that have allprop? set to true
  def allprop(xml = nil)
    @liveprops.each do |key, v|
      if v.allprop?
        begin
          value = self[key, xml]
          yield(key, value) if block_given?
        rescue NotFoundError, UnauthorizedError, ForbiddenError
        end
      end
    end
  end

  def propname(xml = nil)
    @liveprops.each do |key, v|
      key.xml(xml) unless xml.nil?
      yield key if block_given?
    end
  end

  def each_unprotected
    @liveprops.each do |key, v|
      unless v.protected?
        value = self[key]
        yield(key, value)
      end
    end
  end

  class LivePropInfo
    attr_reader :method

    # should not be used to check for regular DAV:read permission
    # this is for DAV:read-acl or DAV:read-current-user-privilege-set
    def assert_read_granted(resource, principal)
      @read_priv.assert_granted(resource, principal) unless @read_priv.nil?
    end
    
    def protected?
      @protected
    end

    def allprop?
      @allprop
    end

    def initialize(method, protected, allprop, read_priv = nil)
      @method = method
      @protected = protected
      @allprop = allprop
      @read_priv = read_priv
    end

  end

  private

  def dispatch_to_reader(propkey, propinfo, xml = nil, principal = nil)
    propinfo.assert_read_granted(@resource, principal)
    @resource.xml_wrap_liveprop(propkey, propinfo.method, xml, principal)
  end


end

