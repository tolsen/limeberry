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


# TODO: if we later want VCCs (version controlled collections, then
# we should refactor the common vcr stuff out into a separate module

class Vcr < Resource

  acts_as_proxy :for => :vcr_record, :foreign_key => "resource_id"

  def init_versioning(principal)
    #Create the VHR
    vhr = Vhr.make(self, principal)
    
    #Create the first version
    self.reload
    version = Version.make(self, principal, vhr)

    # Create the corresponding entry in the dav_vcrs table
    vcr_record = VcrRecord.create!(:vcr => self,
                                   :checked_version => version,
                                   :vhr => vhr,
                                   :checked_state => 'I')
    self.reload
  end
  
  def checked_in?
    self.checked_state == 'I'
  end
  
  def self.checkout(pathname, principal)
    Bind.locate(pathname).checkout(principal)
    DavResponse::CheckoutWebdavResponse.new Status::HTTP_STATUS_OK
  end
  
  def self.checkin(pathname, principal)
    Bind.locate(pathname).checkin(principal)
    DavResponse::CheckinWebdavResponse.new Status::HTTP_STATUS_OK
  end
  
  def checkout(principal)
    Privilege.priv_write_properties.assert_granted(self, principal)
    raise PreconditionFailedError unless self.checked_in?
    self.checked_state = 'O'
    self.save!
  end
  
  def checkin(principal)
    Privilege.priv_write_properties.assert_granted(self, principal)
    Vcr.transaction do
      raise PreconditionFailedError if self.checked_in?
      newversion = Version.make(self, principal)
      self.reload
      self.checked_state = 'I'
      self.checked_version = newversion
      self.save!
    end
  end
  
  def before_write_common(principal, *locktokens)
    super
    raise PreconditionFailedError if checked_in?
  end
  
    
  # TODO: implement options method
end
