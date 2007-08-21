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

class AddConstraints < ActiveRecord::Migration
  def self.up
    # primary key definitions for join tables
    
    execute "alter table aces_privileges add constraint pk_ai_pi
             primary key (ace_id,privilege_id)"
    
    execute "alter table membership add constraint pk_gi_mi
             primary key (group_id,member_id)"
    
    execute "alter table transitive_membership add constraint pk_tgi_tmi
             primary key (group_id,member_id)"

    execute "alter table locks_resources add constraint pk_li_ri
             primary key (lock_id,resource_id)"

    execute "alter table lockroot_binds add constraint pk_bi_li
             primary key (lock_id,bind_id)"
        
    #foreign key constraints
    
#    execute "alter table aces add constraint fk_rp_principal
#           foreign key (principal_id) references principals(resource_id)"
    execute "alter table aces add constraint fk_rp_resource
           foreign key (resource_id) references resources(id)"
    
    execute "alter table aces_privileges add constraint fk_ap_ace 
             foreign key (ace_id) references aces (id)"
    execute "alter table aces_privileges add constraint fk_ap_pr 
             foreign key (privilege_id) references privileges (id)"
    
    execute "alter table binds  add constraint fk_bi_collection
             foreign key (collection_id) references resources (id)"
    execute "alter table binds add constraint fk_bi_resource
             foreign key (resource_id) references resources (id)"
    
    execute "alter table membership add constraint fk_gm_group
             foreign key (group_id) references principals (resource_id)"
    execute "alter table membership add constraint fk_gm_member
             foreign key (member_id) references principals (resource_id)"
    
    execute "alter table transitive_membership add constraint fk_tgm_group
             foreign key (group_id) references principals (resource_id)"
    execute "alter table transitive_membership add constraint fk_tgm_member
             foreign key (member_id) references principals (resource_id)"

    execute "alter table locks_resources add constraint fk_lr_lo
             foreign key (lock_id) references  locks(id)"
    execute "alter table locks_resources add constraint fk_lr_re
             foreign key (resource_id) references  resources(id)"
    
    execute "alter table lockroot_binds add constraint fk_bl_lk
             foreign key (lock_id) references  locks(id)"
    execute "alter table lockroot_binds add constraint fk_bl_bi
             foreign key (bind_id) references  binds(id)"
    
    execute "alter table locks add constraint fk_li_on
             foreign key (owner_id) references principals(resource_id)"
    execute "alter table locks add constraint fk_li_re
             foreign key (resource_id) references resources(id)"

    execute "alter table bodies add constraint fk_fi_resource
             foreign key (resource_id) references resources (id)"

    execute "alter table principals add constraint fk_pp_resource
             foreign key (resource_id) references  resources(id)"
    
    execute "alter table properties add constraint fk_pr_namespace
             foreign key (namespace_id) references namespaces(id)"
    execute "alter table properties add constraint fk_pr_resource
             foreign key (resource_id) references  resources(id)"

    execute "alter table privileges add constraint fk_priv_namespace
             foreign key (namespace_id) references namespaces(id)"

    execute "alter table redirects  add constraint fk_rd_resource
             foreign key (resource_id) references resources(id)"
    
    execute "alter table resources add constraint fk_re_creator
             foreign key (creator_id) references  principals(resource_id)"
    execute "alter table resources add constraint fk_re_owner
             foreign key (owner_id) references  principals(resource_id)"
    
    execute "alter table acl_inheritance add constraint fk_ai_resource
             foreign key (resource_id) references resources(id)"
    
    execute "alter table users add constraint fk_us_principal
             foreign key (principal_id) references  principals(resource_id)"

    execute "alter table vcrs add constraint fk_vc_vhr
             foreign key (vhr_id) references  resources(id)"
    execute "alter table vcrs add constraint fk_vc_resource
             foreign key (resource_id) references  resources(id)"
    execute "alter table vcrs add constraint fk_vc_checked
             foreign key (checked_id) references  versions(resource_id)"
    
    execute "alter table versions  add constraint fk_ve_resource
             foreign key (resource_id) references  resources(id)"
    execute "alter table versions  add constraint fk_ve_vhr
             foreign key (vhr_id) references  resources(id)"

  end

  def self.down
    
    # drop foreign key constraints

#    execute "alter table aces drop foreign key fk_rp_principal"
    execute "alter table aces drop foreign key fk_rp_resource"
    
    execute "alter table aces_privileges drop foreign key fk_ap_ace" 
    execute "alter table aces_privileges drop foreign key fk_ap_pr "
    
    execute "alter table binds  drop foreign key fk_bi_collection"
    execute "alter table binds drop foreign key fk_bi_resource"
    
    execute "alter table membership drop foreign key fk_gm_group"
    execute "alter table membership drop foreign key fk_gm_member"
    
    execute "alter table transitive_membership drop foreign key fk_tgm_group"
    execute "alter table transitive_membership drop foreign key fk_tgm_member"

    execute "alter table locks_resources drop foreign key fk_lr_lo"
    execute "alter table locks_resources drop foreign key fk_lr_re"
    
    execute "alter table lockroot_binds drop foreign key fk_bl_lk"
    execute "alter table lockroot_binds drop foreign key fk_bl_bi"
    
    execute "alter table locks drop foreign key fk_li_on"
    execute "alter table locks drop foreign key fk_li_re"

    execute "alter table bodies drop foreign key fk_fi_resource"

    execute "alter table principals drop foreign key fk_pp_resource"
    
    execute "alter table properties drop foreign key fk_pr_namespace"
    execute "alter table properties drop foreign key fk_pr_resource"

    execute "alter table privileges drop foreign key fk_priv_namespace"

    execute "alter table redirects  drop foreign key fk_rd_resource"
    
    execute "alter table resources drop foreign key fk_re_creator"
    execute "alter table resources drop foreign key fk_re_owner"
    
    execute "alter table acl_inheritance drop foreign key fk_ai_resource"
    
    execute "alter table users drop foreign key fk_us_principal"

    execute "alter table vcrs drop foreign key fk_vc_vhr"
    execute "alter table vcrs drop foreign key fk_vc_resource"
    execute "alter table vcrs drop foreign key fk_vc_checked"
    
    execute "alter table versions drop foreign key fk_ve_resource"
    execute "alter table versions drop foreign key fk_ve_vhr"
    
    # drop primary key constraints
    
    execute "alter table aces_privileges drop primary key"
    execute "alter table membership drop primary key"
    execute "alter table transitive_membership drop primary key"
    execute "alter table locks_resources drop primary key"
    execute "alter table lockroot_binds drop primary key"

  end
end
