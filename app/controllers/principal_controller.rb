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

class PrincipalController < ApplicationController

  # PUT for principals
  
  def put_user 
    request.cgi.stdinput.rewind    
    reqxml = request.cgi.stdinput.read
    options=extract_headers
    path=File.join(User.users_collection_path, params[:name])
    if !Resource.evaluate_conditional_headers(path, options)
      set_error_response(:status => Status::HTTP_STATUS_PRECONDITION_FAILED) 
    else 
      parse_result = parse_put_user(params[:name], reqxml)
      @webdav_response = User.put(parse_result)
      #@webdav_response = DavResponse::PutWebdavResponse.new Status::HTTP_STATUS_CREATED
      #render :nothing => true
    end
  rescue HttpError => e
    set_error_response(:status => e.status)
  end
  
  def put_group 
    request.cgi.stdinput.rewind    
    reqxml = request.cgi.stdinput.read
    options=extract_headers
    path=File.join(Group.groups_collection_path, params[:name])
    if !Resource.evaluate_conditional_headers(path, options)
      set_error_response(:status => Status::HTTP_STATUS_PRECONDITION_FAILED) 
    else 
      parse_result = parse_put_group(params[:name], reqxml, options[:principal])
      @webdav_response = Group.put(parse_result)
      #render :nothing => true
    end
  rescue HttpError => e
    set_error_response(:status => e.status)
  end

end
