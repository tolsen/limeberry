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

class HttpController < ApplicationController

  before_filter :assert_resource_found, :only => [ :delete, :get ]

  def method_not_implemented
    raise MethodNotImplementedError
  end
  
  
  #HTTP 1.1 methods

  def delete
    #permissions checked in parent.unbind
    parent = Collection.parent_collection(@path)
    parent.unbind(File.basename(@path), @principal, *@if_locktokens)
    render :nothing => true, :status => 204
  rescue HttpError => @error
    raise if @error.resource.nil? or @error.url == @path
    render :template => "webdav/move.rxml", :status => 207
  end

  def get
    @resource.before_read_content @principal
    body = @resource.body
    
    set_validators

    if body.nil?
      render :nothing => true, :status => 204
    else
      headers['Content-Language'] = body.contentlanguage
      send_file body.full_path, :type => body.mimetype
    end
  end

  #HEAD = GET without body
  #Rails makes a check and does not send the body if the request method is HEAD.
  alias_method :head, :get

  def options
    logger.debug "options"

    headers['DAV'] = "1, 2, bind"
    headers['MS-Author-Via'] = "DAV"

    allowed = if @path == '*'
                %w(GET HEAD OPTIONS DELETE PUT PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK BIND UNBIND REBIND VERSION-CONTROL CHECKOUT CHECKIN)
              else
                raise NotFoundError if @resource.nil?
                @resource.before_read_properties @principal
                @resource.options
              end
    headers['Allow'] = allowed.join(', ')
    render :nothing => true
  end

  def put
    # todo:
    #   - incorrect file size in cadaver status mesg. -> bug in Mongrel
    
    status = 204

    Resource.transaction do
      if @resource.nil?
        status = 201
        parent = Collection.parent_collection_raises_conflict(@path)

        @resource = Resource.create!(:creator => @principal)
        parent.bind_and_set_acl_parent(@resource,
                                       File.basename(@path),
                                       @principal,
                                       true,
                                       *@if_locktokens)
      else
        @resource.before_write_content(@principal, *@if_locktokens)
      end

      Body.make(@contenttype, @resource, request.cgi.stdinput)

      @resource.after_put if @resource.respond_to? :after_put
    end

    set_validators
    render :nothing => true, :status => status
  end

  private

  def set_validators
    headers['ETag'] = "\"#{@resource.etag}\""
  rescue NotFoundError
  ensure
    headers['Last-Modified'] = @resource.lastmodified.httpdate
  end

end
