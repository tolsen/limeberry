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

class BindController < ApplicationController

  before_filter :assert_resource_found, :parse_body
  before_filter :assert_valid_href, :except => :unbind
  
  # BIND draft

  # @resource can only be a collection because otherwise MethodNotAllowed
  # would have been raised earlier

  def bind
    child = locate_raising_conflict @href_path
    status = @resource.bind child, @segment, @principal, @overwrite, *@if_locktokens
    render :nothing => true, :status => status.code
  end
  

  def unbind
    @resource.unbind @segment, @principal, *@if_locktokens
    render :nothing => true  # 200
  end

  def rebind
    status = @resource.rebind @segment, @href_path, @principal, @overwrite, *@if_locktokens
    render :nothing => true, :status => status.code
  end

  private

  def parse_body
    root = REXML::Document.new(request.cgi.stdinput.read).root
    raise BadRequestError unless root.namespace == 'DAV:' and root.name == action_name
    set_segment_and_href root
    raise BadRequestError if @segment.nil?
    true
  rescue REXML::ParseException
    raise BadRequestError
  end

  def assert_valid_href
    @href_path = validate_and_trim_full_url @href
    true
  rescue BadGatewayError
    raise ForbiddenError
  end

  def set_segment_and_href(element)
    element.each_element do |e|
      next unless e.namespace == 'DAV:' 
      case e.name
      when 'segment'
        raise BadRequestError unless @segment.nil?
        @segment = e.text 
      when 'href'
        raise BadRequestError unless @href.nil?
        @href = e.text
      end
    end
  end

  def locate_raising_conflict(path)
    Bind.locate path
  rescue NotFoundError
    raise ConflictError
  end
  
  
end
