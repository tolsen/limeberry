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

require 'status'

class StaleLockNullError < StandardError; end
class BadPropertyHrefError < StandardError; end

class HttpError < StandardError
  # url can be different from resource in cases
  # such as unbind or bind privilege is forbidden
  attr_reader :resource
  attr_writer :url

  def initialize(*args)
    args.delete_if do |arg|
      if arg.is_a? Resource
        self.resource = arg
        true
      else
        false
      end
    end
    super(*args)
  end

  def resource=(new_resource)
    @resource = new_resource
    @url = new_resource.url if new_resource.url?
  end

  def url
    @url ||= @resource.url
  end
  
end

#client Failure Status Codes
# 400
class BadRequestError < HttpError
  def status; Status::HTTP_STATUS_BAD_REQUEST; end
end

# 401
class UnauthorizedError < HttpError
  def status; Status::HTTP_STATUS_UNAUTHORIZED; end
end

# 403
class ForbiddenError < HttpError
  def status; Status::HTTP_STATUS_FORBIDDEN; end
end

# 404
class NotFoundError < HttpError
  def status; Status::HTTP_STATUS_NOT_FOUND; end
end

# 405
class MethodNotAllowedError < HttpError
  def status; Status::HTTP_STATUS_METHOD_NOT_ALLOWED; end
end

# 408
class RequestTimeoutError < HttpError
  def status; Status::HTTP_STATUS_REQUEST_TIME_OUT; end
end

# 409
class ConflictError < HttpError
  def status; Status::HTTP_STATUS_CONFLICT; end
end

# 412
class PreconditionFailedError < HttpError
  def status; Status::HTTP_STATUS_PRECONDITION_FAILED; end
end

# 415
class UnsupportedMediaTypeError < HttpError
  def status; Status::HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE; end
end

# 423
class LockedError < HttpError
  def status; Status::HTTP_STATUS_LOCKED; end
end

# 424
class FailedDependencyError < HttpError
  def status; Status::HTTP_STATUS_FAILED_DEPENDENCY; end
end

# 500
class InternalServerError < HttpError
  def status; Status::HTTP_STATUS_INTERNAL_SERVER_ERROR; end
end


#server failure codes
# 501
class MethodNotImplementedError < HttpError #(NotImplementedError already taken by ruby)
  def status; Status::HTTP_STATUS_METHOD_NOT_IMPLEMENTED; end
end

# 502
class BadGatewayError < HttpError
  def status; Status::HTTP_STATUS_BAD_GATEWAY; end
end

# 503
class ServiceUnavailableError < HttpError
  def status; Status::HTTP_STATUS_SERVICE_UNAVAILABLE; end
end

# 506
class LoopDetectedError < HttpError
  def status; Status::HTTP_STATUS_LOOP_DETECTED; end
end

# 507
class InsufficientStorageError < HttpError
  def status; Status::HTTP_STATUS_INSUFFICIENT_STORAGE; end
end
