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


# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'auth_tokens'
require 'errors'
require 'if_header'
require 'web_dav_response'
require 'web_dav_xml_util'

class ApplicationController < ActionController::Base

#  include WebDavXmlUtil

  session(:off,
          :if => proc {
            AppConfig.authentication_scheme != "simple"
          })

#  SERVER = 'Mongrel-Rails+Webdav/0.13.3 ()'

  before_filter :set_path, :extract_headers

  around_filter :render_error, :authenticate

  before_filter(:locate_resource,
                :evaluate_if_headers,
                :evaluate_conditional_headers)

  before_filter do |c|
    c.request.cgi.stdinput.rewind if c.request.cgi.stdinput.respond_to? :rewind
  end

  private

  def set_path
    logger.debug "set_path"
    @rootcoll_url = "http://#{request.host_with_port}/#{BASE_WEBDAV_PATH}"
    @path = ("/" + params[:path].join('/')).sub(/^#{BASE_WEBDAV_PATH}/, '')
    true
  end


  def extract_headers
    logger.debug "extract_headers"
    
    @contenttype = request.env["CONTENT_TYPE"]
    
    @if_match = request.env["HTTP_IF_MATCH"]
    @if_modified_since = request.env["HTTP_IF_MODIFIED_SINCE"]
    @if_none_match = request.env["HTTP_IF_NONE_MATCH"]
    @if_unmodified_since = request.env["HTTP_IF_UNMODIFIED_SINCE"]

    @dav = if request.env["HTTP_DAV"].nil?
             nil
           else
             request.env["HTTP_DAV"].split(',').map{ |s| s.lowercase.intern }.to_set
           end

    @depth = case request.env["HTTP_DEPTH"]
             when '0', 0 then 0.0
             when '1', 1 then 1.0
             when /infinity/i, nil then Limeberry::INFINITY
             else request.env["HTTP_DEPTH"]
             end
    
               
    @destination = request.env["HTTP_DESTINATION"]
    
    @if = request.env["HTTP_IF"]
    @timeout = request.env["HTTP_TIMEOUT"]
    
    @overwrite = case request.env["HTTP_OVERWRITE"]
                 when /t/i, nil then true
                 when /f/i then false
                 else nil
                 end
    true
  end
  
  def render_error
    yield
  rescue HttpError => e
    logger.debug("Error processing request:status: #{e.status}")
    logger.debug e.backtrace.join("\n")
    render :nothing => true, :status => e.status.code
  end

  # sets @principal
  def authenticate
    logger.debug "authenticate begin"
    scheme = AppConfig.authentication_scheme

    logger.debug("AUTHENTICATION_SCHEME #{scheme}")

    auth_token = nil
    case scheme #set the appropriate token
    when "simple"
      auth_token = Limeberry::SimpleAuthToken.new(session[:username])
    when "basic"
      auth_token = Limeberry::BasicAuthToken.new(request.env["HTTP_AUTHORIZATION"])
    when "digest"
      auth_token = Limeberry::DigestAuthToken.new(request.env["HTTP_AUTHORIZATION"], request.method.to_s)
      headers["Authentication-Info"] = auth_token.authentication_info
    end
    @principal = auth_token.principal
    yield
  rescue UnauthorizedError => e
    logger.debug("User Unauthorized.")
    headers['WWW-Authenticate'] = auth_token.www_authenticate if
      auth_token.respond_to? :www_authenticate
    logger.debug "WWW-Authenticate: #{headers['WWW-Authenticate']}"
    raise
  end

  def locate_resource
    logger.debug "locate_resource"
    @resource = Bind.locate(@path)
    unless @resource.options.include? request.method.to_s.upcase
      @resource.before_read_properties @principal
      headers['Allow'] = @resource.options.join(', ')
      raise MethodNotAllowedError
    end
  rescue NotFoundError
    @resource = nil
  end

  def evaluate_if_headers
    logger.debug "evaluate_if_headers"
    unless @if.nil?
      if_parse_result = IfHeaderParser::parse_if_header(@if)
      @if_locktokens = if_parse_result.lock_tokens.map {|locktoken| Utility.locktoken_to_uuid(locktoken)}

      raise PreconditionFailedError unless if_parse_result.evaluate(@resource, @principal)
      
    end
  end
  
  def evaluate_conditional_headers
    logger.debug "evaluate_conditional_headers"
    # HTTP 1.1 conditional headers

    # FIXME! from HTTP 1.1:
    #   "If the request would, without the If-Match header field, result in anything other than a 2xx or 412 status, then the If-Match header MUST be ignored."
    #   "If the request would, without the If-None-Match header field, result in anything other than a 2xx or 304 status, then the If-None-Match header MUST be ignored."


    # disallow undefined combinations
    if ((@if_none_match || @if_modified_since) &&
        (@if_match || @if_unmodified_since))
      raise BadRequestError
    end

    # check if_match
    raise PreconditionFailedError if @if_match && !matches?(@resource, @if_match, @principal)

    # check if_none_match
    return respond_unmodified if @if_none_match && matches?(@resource, @if_none_match, @principal)


    unless @resource.nil?
      # check if_unmodified_since
      raise PreconditionFailedError if @if_unmodified_since && @resource.modified_since?(Time.httpdate(@if_unmodified_since))

      # if_modified_since only applies if if_none_match was not set
      return respond_unmodified if @if_none_match.nil? && @if_modified_since && !@resource.modified_since?(Time.httpdate(@if_modified_since))
    end
  end

  def assert_resource_found
    raise NotFoundError if @resource.nil?
    true
  end

  # helpers

  def get_filetype filename
    filename.path.split(".").last.upcase
  end

  def validate_and_trim_full_url url
    raise BadRequestError if url.nil?
    raise BadGatewayError unless /^#{@rootcoll_url}/.match(url)
    url.sub(/#{@rootcoll_url}/,"")
  end

  def matches?(resource, match_header, principal)
    return false if resource.nil? or resource.body.nil?
    return true if match_header == '*'

    # check permission to read the etag property
    Privilege.priv_read.assert_granted(resource, principal)
    
    matching_etags = match_header.split(',').map do |quoted_etag|
      #Removes quotes and 'W/'(if it exists)
      quoted_etag.split('"')[1]
    end

    matching_etags.include? resource.etag
  end

  def respond_unmodified
    # 304 in case of GET or HEAD
    if request.get? || request.head?
      Privilege.priv_read.assert_granted(@resource, @principal)
      render :nothing => true, :status => 304
      return false
    end

    # otherwise 412
    raise PreconditionFailedError
  end

end
