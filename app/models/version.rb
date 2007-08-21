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

class Version < Resource
  acts_as_proxy :for => :version_record, :foreign_key => "resource_id"
  
  # Creates a new version of a version-controlled resource
  def self.make(vcr, principal, vhr=vcr.vhr)
    # Create the resource corresponding to the version
    version = Version.create!(:owner => principal,
                              :creator => principal,
                              :displayname => vcr.displayname)
    version.init(vcr, principal, vhr)
  end
  
  def after_create
    #Do not set owner privileges
  end
  
  def init(vcr, principal, vhr)
    # Create the version record
    version_record = VersionRecord.create!(:version => self,
                                           :vhr => vhr)
    
    # Copy the body
    self.body = Body.make(vcr.body.mimetype, self, vcr.body.stream)

    # Copy dead properties
    vcr.copy_properties(self)
    
    # Give proper privileges
    self.acl_parent = vcr
    self.save!
    Privilege.priv_write.deny(self, Group.all, true)
    Privilege.priv_write_acl.deny(self, Group.all, true)
    
    # Create bind
    path = File.join(Vhr::VHRS_COLLECTION_PATH, Body.file_path(vcr.uuid))
    Bind.locate(path).bind(self, version_record.number.to_s,
                           Principal.limeberry)
    
    unless self.first?
      previous = self.previous
      previous.body = Body.get_diff_body(self.body, previous.body)
    end
    
    self.reload
  end
  
  def previous
    higher_item.version
  end
  
end
