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

class LockController < ApplicationController

  before_filter :assert_resource_found, :only => :unlock

  #webdav class 2 methods

  def lock
    timeout = parse_timeout(@timeout)
    status = 200

    reqxml = request.cgi.stdinput.read

    Resource.transaction do
      if reqxml.empty?
        # refresh lock

        raise NotFoundError if @resource.nil?

        # If-header should contain one and only one locktoken
        raise PreconditionFailedError if @if_locktokens.nil? || @if_locktokens.size != 1

        @lock = @resource.locks.find_by_uuid(@if_locktokens[0])
        Privilege.raise_permission_denied(@principal) unless @lock.owner == @principal
        @lock.refresh(timeout)

      else # create lock
        lock_params = parse_lock(reqxml)

        scope = case lock_params[:lockscope].downcase
                when 'exclusive' then 'X'
                when 'shared' then 'S'
                else raise BadRequestError
                end

        depth = case @depth
                when 0 then '0'
                when Limeberry::INFINITY then 'I'
                else raise BadRequestError
                end

        raise NotImplementedError unless lock_params[:locktype].downcase == 'write'

        @lock = Lock.new(:owner => @principal,
                         :scope => scope,
                         :depth => depth,
                         :expires_at => Time.now + timeout,
                         :owner_info => lock_params[:owner],
                         :lock_root => @path)
        @lock.save!


        status = 201 if @resource.nil?
        
        headers['Lock-Token'] = "<#{@lock.locktoken}>"
      end

    end

    render :status => status
  rescue ActiveRecord::RecordInvalid
    raise if @lock.dav_errors.empty?
    render :template => "lock/lock_multi.rxml", :status => 207
  end

  def unlock
    uuid = parse_lock_token
    
    Resource.transaction do
      lock = @resource.locks.find_by_uuid uuid
      raise ConflictError if lock.nil?

      # check for privileges and ownership
      # Unlocking is allowed
      #   - if lock owner is the current principal OR
      #   - authenticated principal has unlock privileges on all the
      #     resources locked by the provided locktoken.

      unless @principal == lock.owner
        lock.resources.each do |res|
          Privilege.priv_unlock.assert_granted(res, @principal)
        end
      end

      lock.destroy
    end

    render :nothing => true, :status => 204
    
  end

  private

  # Timeout & Depth are headers
  def parse_lock(reqxml)
    root = REXML::Document.new(reqxml).root
    raise BadRequestError unless (root.namespace == 'DAV:' and root.name == 'lockinfo')
    ret_hash = Hash.new

    root.each_element {|e|
      # check for "lockscope"
      if e.namespace == 'DAV:' and e.name == 'lockscope'
        raise BadRequestError unless ret_hash[e.name].nil?
        e.each_element{|f|
          if f.namespace == 'DAV:' and (f.name == 'exclusive' || f.name == 'shared')
            raise BadRequestError unless ret_hash[:lockscope].nil?
            ret_hash[:lockscope] = f.name
          end
        }
        # check for "locktype"
      elsif e.namespace == 'DAV:' and e.name == 'locktype'
        raise BadRequestError unless ret_hash[e.name].nil?
        e.each_element{|f|
          if f.namespace == 'DAV:' and f.name == 'write'
            raise BadRequestError unless ret_hash[:locktype].nil?
            ret_hash[:locktype] = f.name
          end
        }
        # check for "owner"
        # owner contains information in any format (href, mailto, text, etc)
      elsif e.namespace == 'DAV:' and e.name == 'owner'
        raise BadRequestError unless ret_hash[:owner].nil?
        # e.contents to take care of namespace of elements (if present) within element e.
        ret_hash[:owner] = e.innerXML
      end
    }
    # Owner elem is optional
    raise BadRequestError unless (ret_hash.has_key?(:lockscope) && ret_hash.has_key?(:locktype))

    ret_hash
  rescue REXML::ParseException
    raise BadRequestError
  end

  def parse_timeout(header)
    # -1 means unset
    # -2 means unset and infinite requested
    
    timeout = -1

    unless header.nil?
      header.split(/,\s*/).each do |timetype|
        timeout = case timetype.downcase
                  when /infinite/
                    timeout == -1 ? -2 : timeout
                  when /second-(\d+)/
                    [ timeout, $1.to_i ].max
                  end
        break if timeout >= 0
      end
    end

    if timeout == -1
      AppConfig.default_lock_timeout
    elsif timeout == -2 || timeout > AppConfig.max_lock_timeout
      AppConfig.max_lock_timeout
    else
      timeout
    end
    
  end

  # returns uuid
  def parse_lock_token
    lock_token = request.env["HTTP_LOCK_TOKEN"]
    raise BadRequestError if lock_token.nil? || lock_token.sub!(/^<(.*)>$/, '\1').nil?
    return Utility.locktoken_to_uuid(lock_token)
  end
  

end
