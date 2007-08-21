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


class Status

  attr_reader :code, :msg
  
  def initialize(code, msg, version = "HTTP/1.1")
    @version = version
    @code = code
    @msg = msg
  end

  def to_s(write_version = true)
    (write_version ? "#{@version} " : "") + "#{@code.to_s} #{@msg}"
  end

  alias_method :write, :to_s

  HTTP_STATUS_BAD_REQUEST = Status.new(400,"Bad Request").freeze
  HTTP_STATUS_UNAUTHORIZED = Status.new(401,"Unauthorized").freeze
  HTTP_STATUS_FORBIDDEN = Status.new(403,"Forbidden").freeze
  HTTP_STATUS_NOT_FOUND = Status.new(404,"Not Found").freeze
  HTTP_STATUS_METHOD_NOT_ALLOWED = Status.new(405,"Method Not Allowed").freeze
  HTTP_STATUS_REQUEST_TIME_OUT = Status.new(408,"Request Time Out").freeze
  HTTP_STATUS_CONFLICT = Status.new(409,"Conflict").freeze
  HTTP_STATUS_PRECONDITION_FAILED = Status.new(412,"Precondition Failed").freeze
  HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE = Status.new(415,"Unsupported Media Type").freeze
  HTTP_STATUS_LOCKED = Status.new(423,"Locked").freeze
  HTTP_STATUS_FAILED_DEPENDENCY = Status.new(424,"Failed Dependency").freeze
  HTTP_STATUS_INTERNAL_SERVER_ERROR = Status.new(500,"Internal Server Error").freeze
  HTTP_STATUS_METHOD_NOT_IMPLEMENTED = Status.new(501,"Method Not Implemented").freeze
  HTTP_STATUS_BAD_GATEWAY = Status.new(502, "Bad Gateway").freeze
  HTTP_STATUS_SERVICE_UNAVAILABLE = Status.new(503,"Service Unavailable").freeze
  HTTP_STATUS_LOOP_DETECTED = Status.new(506,"Loop Detected").freeze
  HTTP_STATUS_INSUFFICIENT_STORAGE = Status.new(507,"Insufficient Storage").freeze
  HTTP_STATUS_CREATED = Status.new(201,"Created").freeze
  HTTP_STATUS_OK = Status.new(200,"OK").freeze
  HTTP_STATUS_NO_CONTENT = Status.new(204,"No Content").freeze
  HTTP_STATUS_MULTISTATUS = Status.new(207,"Multi-Status").freeze
  HTTP_STATUS_ALREADY_REPORTED = Status.new(208,"Already Reported").freeze

end

