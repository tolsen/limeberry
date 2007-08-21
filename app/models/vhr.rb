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

class Vhr < Resource
  has_many :version_records, :class_name => "VersionRecord", :order => :number
  has_many :vcr_records, :class_name => "VcrRecord"

  VHRS_COLLECTION_PATH = "/!lime/vhrs"

  def delete
    raise ForbiddenError
  end

  def destroy
    raise ForbiddenError
  end
  
  def versions
    version_records.map { |version_record| version_record.version }
  end
  
  def vcrs
    vcr_records.map { |vcr_record| vcr_record.vcr }
  end
  
  def after_create
    #Do not set owner privileges
  end
  
  def self.make(vcr, principal)
    vhr = self.create!(:owner => principal,
                       :creator => principal,
                       :displayname => vcr.displayname,
                       :comment => "Version History for resource #{vcr.uuid}")
    
    # Create bind
    path = File.join(VHRS_COLLECTION_PATH, Body.file_path(vcr.uuid))
    Collection.mkcol_p(path, Principal.limeberry)
    vhr_collection = Bind.locate(path)
    vhr_collection.bind(vhr, "vhr", Principal.limeberry)
    
    # Set acl parent
    vhr.acl_parent = vcr
    vhr.save!
    
    # Prevent modification of the vhr
    Privilege.priv_write.deny(vhr, Group.all, true)
    Privilege.priv_write_acl.deny(vhr, Group.all, true)
    
    vhr.reload
  end

end
