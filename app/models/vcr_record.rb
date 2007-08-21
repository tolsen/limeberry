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

class VcrRecord < ActiveRecord::Base

  set_table_name "vcrs"
  set_primary_key "resource_id"

  proxied_by :vcr, :foreign_key => "resource_id"
  
  belongs_to :vhr, :foreign_key => "vhr_id"

  belongs_to(:checked_version_record,
             :class_name => "VersionRecord",
             :foreign_key => "checked_id")

  def checked_version
    self.checked_version_record.version
  end

  def checked_version=(new_version)
    self.checked_version_record = new_version.version_record
  end

  #     # should only do this upon OBLITERATE
  #     #   before_destroy :delete_versions
  # 
  #     def delete_versions
  #       versions.each { |v| Resource.unbind_everywhere v.resource }
  #     end
  # 
  #     #change the state of vcr from checked-in to checked-out
  # 
  #     def checkout principal=Principal.unauthenticated
  #       if !(self.resource.privilege_granted? AclPrivilege.find_by_name("DAV:write-properties"), principal)
  #         raise UnauthorizedError
  #       end
  # 
  #       self.checked_state = 'O'
  #       self.save!
  #     end
  # 
  #     def self.obliterate vcr,principal=Principal.unauthenticated
  #       vhr = vcr.vhr
  #       vcr_versions=vcr.versions
  #       Resource.unbind_everywhere vcr.resource,principal
  #       Resource.unbind_everywhere vhr.resource,principal
  #       vcr_versions.each { |v| Resource.unbind_everywhere v.resource,principal }
  #     end
  # 
  # 
  #     #check-in a new version and make corresponding entry in Vcr
  #     def checkin principal=Principal.unauthenticated
  # 
  #       self.resource.locks.each do |lock|
  #         lock.checkin_on_unlock = 'f'
  #         lock.save!
  #       end
  # 
  #       if !(self.resource.privilege_granted? AclPrivilege.find_by_name("DAV:write-properties"), principal)
  #         raise UnauthorizedError
  #       end
  # 
  #       # puts "came in checkin"
  #       if self.checked_state == 'I'
  #         raise MethodNotAllowedError
  #       end
  # 
  #       currentres = self.resource #Resource.find_by_id(self.resource_id)
  # 
  #       #create a new resource and copy currentres in it
  #       #I have used the Resource.make here, so please check this later
  #       @number = self.current_version.number + 1
  #       @prevnumber = self.current_version.number
  # 
  #       newresdir = "!lime/ver/" + Utility::get_string_path(currentres.uuid)
  #       newresfile = newresdir + "/#@number"
  #       prevresfile = newresdir + "/#@prevnumber"
  # 
  #       newresdirres = Bind.locate newresdir
  #       newresdirres.remove_protected AclPrivilege.find_by_name("DAV:write"), Principal.all
  #       newresdirres.remove_protected AclPrivilege.find_by_name("DAV:write-acl"), Principal.all
  #       newresdirres.remove_protected AclPrivilege.find_by_name("DAV:unlock"), Principal.all
  #       newresdirres.grant_privilege AclPrivilege.find_by_name("DAV:write"), Principal.all
  #       newresdirres.grant_privilege AclPrivilege.find_by_name("DAV:write-acl"), Principal.all
  #       newresdirres.grant_privilege AclPrivilege.find_by_name("DAV:unlock"), Principal.all
  # 
  # 
  #       ######COPY everything from currentres to newres
  #       newres = currentres.copy newresfile, principal
  #       newres.type =  ResourceType.find_by_name("MediumVersion")
  #       currentres.adopt_privilege_child newres
  #       newres.deny_privilege AclPrivilege.find_by_name("DAV:write"), Principal.all
  #       newres.deny_privilege AclPrivilege.find_by_name("DAV:write-acl"), Principal.all
  #       newres.deny_privilege AclPrivilege.find_by_name("DAV:unlock"), Principal.all
  #       newres.set_protected AclPrivilege.find_by_name("DAV:write"), Principal.all
  #       newres.set_protected AclPrivilege.find_by_name("DAV:write-acl"), Principal.all
  #       newres.set_protected AclPrivilege.find_by_name("DAV:unlock"), Principal.all
  #       newres.deny_privilege AclPrivilege.find_by_name("DAV:write"), principal
  #       newres.deny_privilege AclPrivilege.find_by_name("DAV:write-acl"), principal
  #       newres.deny_privilege AclPrivilege.find_by_name("DAV:unlock"), principal
  #       newres.set_protected AclPrivilege.find_by_name("DAV:write"), principal
  #       newres.set_protected AclPrivilege.find_by_name("DAV:write-acl"), principal
  #       newres.set_protected AclPrivilege.find_by_name("DAV:unlock"), principal
  # 
  # 
  #       newres.save!
  # 
  #       newresdirres.deny_privilege AclPrivilege.find_by_name("DAV:write"), Principal.all
  #       newresdirres.deny_privilege AclPrivilege.find_by_name("DAV:write-acl"), Principal.all
  #       newresdirres.deny_privilege AclPrivilege.find_by_name("DAV:unlock"), Principal.all
  #       newresdirres.set_protected AclPrivilege.find_by_name("DAV:write"), Principal.all
  #       newresdirres.set_protected AclPrivilege.find_by_name("DAV:write-acl"), Principal.all
  #       newresdirres.set_protected AclPrivilege.find_by_name("DAV:unlock"), Principal.all
  # 
  #       self.current_version = self.versions.build( :number => @number )
  #       self.current_version.resource = newres
  #       self.checked_state = 'I'
  # 
  #       self.connection.execute 'set foreign_key_checks=0;'
  #       self.save!
  #       self.connection.execute 'set foreign_key_checks=1;'
  # 
  # 
  #       ############## Calculating delta file and storing in previous version
  #       begin
  #         prevres = Bind.locate(prevresfile)
  #       rescue StandardError => error
  #         error_handling error
  #         return
  #       end
  # 
  #       if (prevres.is_medium? && newres.is_medium?)
  #         if prevres.medium.ondisk? && newres.medium.ondisk?
  # 
  #           oldfilepath = Utility.get_content_path prevres.medium
  #           newfilepath = Utility.get_content_path newres.medium
  #           deltafile =  "#{RAILS_ROOT}/tmp/" + prevres.uuid.to_s + "-delta"
  #           #deltafile =  newfilepath+"-delta"
  # 
  #           system ("xdelta delta "+newfilepath+" "+oldfilepath+" "+deltafile)
  #           #puts ("xdelta delta "+newfilepath+" "+oldfilepath+" "+deltafile)
  # 
  #           prevres.remove_protected AclPrivilege.find_by_name("DAV:write"), principal
  #           prevres.remove_protected AclPrivilege.find_by_name("DAV:write-acl"), principal
  #           prevres.remove_protected AclPrivilege.find_by_name("DAV:unlock"), principal
  #           prevres.grant_privilege AclPrivilege.find_by_name("DAV:write"), principal
  #           prevres.grant_privilege AclPrivilege.find_by_name("DAV:write-acl"), principal
  #           prevres.grant_privilege AclPrivilege.find_by_name("DAV:unlock"), principal
  # 
  #           Medium.copy_source_to_existing_media "general",deltafile, prevres.medium, principal
  #           prevres.medium.mimetype = newres.medium.mimetype
  #           prevres.medium.save!
  # 
  #           prevres.deny_privilege AclPrivilege.find_by_name("DAV:write"), principal
  #           prevres.deny_privilege AclPrivilege.find_by_name("DAV:write-acl"), principal
  #           prevres.deny_privilege AclPrivilege.find_by_name("DAV:unlock"), principal
  #           prevres.set_protected AclPrivilege.find_by_name("DAV:write"), principal
  #           prevres.set_protected AclPrivilege.find_by_name("DAV:write-acl"), principal
  #           prevres.set_protected AclPrivilege.find_by_name("DAV:unlock"), principal
  # 
  #           #puts Utility.get_content_path self.versions[0].resource.medium
  #           #puts Utility.get_content_path self.versions[1].resource.medium
  #           #puts deltafile
  # 
  #           File.unlink deltafile
  #           #system ("rm -rf "+deltafile)
  #         end
  #       end
  #       #######################################
  # 
  #     end
  # 
  #     #give current version number
  #     def current_version_number
  #       @number = self.current_version.number
  #       @number
  #     end
  # 
  #     #revert the changes in working copy and copy current_version on it
  #     def uncheckout principal=Principal.unauthenticated
  # 
  #       if !(self.resource.privilege_granted? AclPrivilege.find_by_name("DAV:write-properties"), principal)
  #         raise UnauthorizedError
  #       end
  # 
  #       currentres = self.resource
  #       currentversionres = self.current_version.resource
  # 
  #       ######COPY everything from currentversion to currrentres
  #       Medium.copy_source_to_existing_media "medium", currentversionres.medium, currentres.medium, principal
  # 
  #       self.checked_state = 'I'
  #       self.save!
  #     end
  # 
  #     #revert the changes in working copy and copy current_version on it
  #     def uncheckout_versionnumber version_num, principal=Principal.unauthenticated
  # 
  #       if !(self.resource.privilege_granted? AclPrivilege.find_by_name("DAV:write-properties"), principal)
  #         raise UnauthorizedError
  #       end
  # 
  #       if self.current_version_number < version_num
  #         raise NotFoundError
  #       end
  # 
  #       currentres = self.resource
  #       currentversionres = self.versions[version_num].resource
  # 
  #       ######COPY everything from currentversion to currrentres
  #       Medium.copy_source_to_existing_media "medium", currentversionres.medium, currentres.medium, principal
  # 
  #       self.checked_state = 'I'
  #       self.save!
  #     end
  # 
  #     def autocheckout principal
  #       if self.checked_state == "O"
  #         return false
  #       end
  #       is_locked = Lock.check self.resource
  #       autoversiontype = self.autoversion.name
  #       if  (autoversiontype =~ /^(DAV:checkout-checkin)|(DAV:checkout-unlocked-checkin)|(DAV:checkout)$/) || ((autoversiontype == "DAV:locked-checkout") && (is_locked))
  #         if is_locked
  #           self.resource.locks.each do |lock|
  #             lock.checkin_on_unlock = 't'
  #             lock.save!
  #           end
  #         end
  #         self.checkout principal
  #         return true
  #       end
  #       return false
  #     end
  # 
  #     def autocheckin principal
  #       if self.checked_state == "I"
  #         return
  #       end
  #       autoversiontype = self.autoversion.name
  #       if (autoversiontype == "DAV:checkout-checkin")
  #         self.checkin principal
  #       elsif ((autoversiontype == "DAV:checkout-unlocked-checkin") && !(Lock.check self.resource))
  #         self.checkin principal
  #       end
  #     end
  # 
  #     ##############applying patch to get the required version
  #     def applypatch versionnum, filepath
  #       srcversion = self.current_version.number
  #       srcfile = Utility.get_content_path self.versions[srcversion-1].resource.medium
  #       deletefile = nil
  # 
  #       while srcversion!=versionnum
  #         #puts "#############source version "
  #         #puts srcversion
  # 
  #         destversion = srcversion - 1
  #         deltafile = Utility.get_content_path self.versions[destversion-1].resource.medium
  #         destfile = "#{RAILS_ROOT}/tmp/" + self.versions[destversion-1].resource.uuid.to_s + "-patch"
  # 
  #         system("xdelta patch " + deltafile + " " + srcfile + " " + destfile)
  #         #puts("xdelta patch " + deltafile + " " + srcfile + " " + deltafile +"-patch")
  # 
  #         srcversion = destversion
  #         srcfile = destfile
  #         #srcfile = deltafile +"-patch"
  #         if (deletefile!=nil)
  #           File.unlink deletefile
  #           #system("rm -rf "+deletefile)
  #         end
  #         deletefile=srcfile
  #       end
  # 
  #       puts "final file is "
  #       puts srcfile
  #       srcfile
  #     end
  # 
end
