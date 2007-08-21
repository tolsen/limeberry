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

# $URL$
# $Id$

require 'constants'
require 'errors'
require 'set'
require 'web_dav_response'

class LockNullResource < Resource

  ## Information regarding LNR
  # - Shared locks on a lock-null resource are allowed
  # - What when I lock a collection having lock-null
  #   resources with infinite depth?
  #   Ans: Not possible to lock if any of lnr is exclusive.
  # - Adding LNR to a infinite depth locked collection
  #   Ans: Allowed depending upon type of lock

  @@stale_ok_level = 0

  def self.with_stale_ok
    @@stale_ok_level += 1
    yield
  ensure
    @@stale_ok_level -= 1
  end

  def self.stale_ok?() @@stale_ok_level != 0; end
  
  def after_find
    self.class.with_stale_ok do
      raise StaleLockNullError if self.direct_locks.empty?
    end unless self.class.stale_ok?
  end
  def options
    %w(OPTIONS PUT PROPFIND MKCOL LOCK UNLOCK)
  end

  def before_read_content(principal)
    raise NotFoundError
  end

  def before_read(principal)
    raise NotFoundError
  end

  def after_put
    self[:type] = ""
    save!
  end

  def mkcol(principal, *locktokens)
    raise LockedError if locks_impede_modify?(principal, *locktokens)
    self[:type] = 'Collection'
    save!
  end

  def copy(target_pathname, principal, depth = '0',
           overwrite = true, *locktokens)
    raise MethodNotAllowedError
  end

  # move, bind, rebind -> taken care in bind
  # unbind, dav_delete -> taken care in unbind
  # lock, lock-refresh, unlock, mkcol, propfind -> in their respective methods

  def resourcetype(xml)
    xml.D(:resourcetype){ xml.D :locknullresource }
  end

  private

  def self.init_liveprops
    liveprops_to_remove =
      %w(getcontentlanguage getcontentlength getcontenttype getetag getlastmodified
         owner supported-privilege-set current-user-privilege-set acl
         acl-restrictions inherited-acl-set principal-collection-set)

    @liveprops = superclass.liveprops.reject do |k, v|
      k.ns == 'DAV:' && liveprops_to_remove.include?(k.name)
    end

    @liveprops.freeze
  end

  init_liveprops

end

