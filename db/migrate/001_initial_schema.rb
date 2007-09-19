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

class InitialSchema < ActiveRecord::Migration
  def self.up

    create_table "aces", :force => true do |t|
      t.column "grantdeny",    :string, :limit => 1, :null => false
      t.column "position",     :integer,                               :null => false
      t.column "protected",    :boolean, :default => false, :null => false
      t.column "resource_id",  :integer,                               :null => false
      t.column "principal_id", :integer
      t.column "property_namespace_id", :integer
      t.column "property_name",         :string,  :limit => 4096
    end

    add_index "aces", ["resource_id"], :name => "fk_rp_resource"
    add_index "aces", ["principal_id"], :name => "fk_rp_principal"

    create_table "aces_privileges", :id => false, :force => true do |t|
      t.column "ace_id",       :integer, :null => false
      t.column "privilege_id", :integer, :null => false
    end

    add_index "aces_privileges", ["ace_id"], :name => "fk_ap_ace"
    add_index "aces_privileges", ["privilege_id"], :name => "fk_ap_pr"

    create_table "acl_inheritance", :id => false, :force => true do |t|
      t.column "resource_id", :integer,                :null => false
      t.column "parent_id",   :integer
      t.column "lft",         :integer, :default => 1
      t.column "rgt",         :integer, :default => 2
    end

    add_index "acl_inheritance", ["resource_id"], :name => "fk_ai_resource"
    add_index "acl_inheritance", ["parent_id"], :name => "fk_ai_parent"
    add_index "acl_inheritance", ["lft"], :name => "ix_ai_lft"
    add_index "acl_inheritance", ["rgt"], :name => "ix_ai_rgt"

    create_table "binds", :force => true do |t|
      t.column "name",          :string,   :limit => 1024, :default => "", :null => false
      t.column "collection_id", :integer,                                  :null => false
      t.column "resource_id",   :integer,                                  :null => false
      t.column "updated_at",    :datetime,                                 :null => false
    end

    add_index "binds", ["collection_id"], :name => "fk_bi_collection"
    add_index "binds", ["resource_id"], :name => "fk_bi_resource"

    create_table "lockroot_binds", :id => false, :force => true do |t|
      t.column "lock_id", :integer, :null => false
      t.column "bind_id", :integer, :null => false
    end

    add_index "lockroot_binds", ["lock_id"], :name => "fk_bl_lk"
    add_index "lockroot_binds", ["bind_id"], :name => "fk_bl_bi"

    create_table "bodies", :id => false, :force => true do |t|
      t.column "resource_id",     :integer
      t.column "size",            :integer,  :limit => 20,                   :null => false
      t.column "contentlanguage", :string,                 :default => "en"
      t.column "mimetype",        :string
      t.column "sha1",            :string,   :limit => 40, :default => "",   :null => false
      t.column "created_at",      :datetime,                                 :null => false
    end

    add_index "bodies", ["resource_id"], :name => "fk_fi_resource"

    create_table "locks", :force => true do |t|
      t.column "uuid",        :string,   :limit => 32, :default => "",  :null => false
      t.column "resource_id", :integer,                                 :null => false
      t.column "owner_id",    :integer,                                 :null => false
      t.column "scope",        :string,   :limit => 1,  :default => "X", :null => false
      t.column "depth",       :string,   :limit => 1,  :default => "0", :null => false
      t.column "expires_at",  :datetime,                                :null => false
      t.column "owner_info",  :text
      t.column "lock_root",   :text,                   :default => "",  :null => false
    end

    add_index "locks", ["resource_id"], :name => "fk_li_re"
    add_index "locks", ["owner_id"], :name => "fk_li_on"
    add_index "locks", ["expires_at"], :name => "ix_locks_expires_at"

    create_table "locks_resources", :id => false, :force => true do |t|
      t.column "lock_id",     :integer, :null => false
      t.column "resource_id", :integer, :null => false
    end

    add_index "locks_resources", ["lock_id"], :name => "fk_lr_lo"
    add_index "locks_resources", ["resource_id"], :name => "fk_lr_re"

    create_table "membership", :id => false, :force => true do |t|
      t.column "group_id",  :integer, :null => false
      t.column "member_id", :integer, :null => false
    end

    add_index "membership", ["group_id"], :name => "fk_gm_group"
    add_index "membership", ["member_id"], :name => "fk_gm_member"

    create_table "namespaces", :force => true do |t|
      t.column "name", :string, :limit => 4096, :default => "", :null => false
    end

    create_table "principals", :id => false, :force => true do |t|
      t.column "resource_id",  :integer,                                 :null => false
      t.column "used_quota",   :integer, :limit => 20,   :default => 0,  :null => false
      t.column "total_quota",  :integer, :limit => 20,   :default => 0,  :null => false
      t.column "name",         :string,  :limit => 1024, :default => "", :null => false
      t.column "lock_version", :integer,                 :default => 0
    end

    add_index "principals", ["resource_id"], :name => "fk_pp_resource"

    create_table "privileges", :force => true do |t|
      t.column "name",      :string,               :default => "",  :null => false
      t.column "namespace_id", :integer, :null => false
      t.column "parent_id", :integer
      t.column "lft",       :integer
      t.column "rgt",       :integer
      t.column "description", :string, :limit => 1024, :default => "", :null => false
    end

    add_index "privileges", ["namespace_id"], :name => "fk_priv_namespace"
    add_index "privileges", ["parent_id"], :name => "fk_pr_parent"
    add_index "privileges", ["lft"], :name => "ix_pr_lft"
    add_index "privileges", ["rgt"], :name => "ix_pr_rgt"

    create_table "properties", :force => true do |t|
      t.column "namespace_id", :integer,                                 :null => false
      t.column "name",         :string,  :limit => 4096, :default => "", :null => false
      t.column "resource_id",  :integer,                                 :null => false
      t.column "value",        :text,                    :default => ""
    end

    add_index "properties", ["resource_id"], :name => "fk_pr_resource"
    add_index "properties", ["namespace_id"], :name => "fk_pr_namespace"

    create_table "redirects", :id => false, :force => true do |t|
      t.column "resource_id", :integer,                                  :null => false
      t.column "lifetime",    :string,  :limit => 1,    :default => "T", :null => false
      t.column "target",      :string,  :limit => 4096, :default => "",  :null => false
    end

    add_index "redirects", ["resource_id"], :name => "fk_rd_resource"

    create_table "resources", :force => true do |t|
      t.column "uuid",         :string,   :limit => 32,   :default => "", :null => false
      t.column "created_at",   :datetime,                                 :null => false
      t.column "displayname",  :string,   :limit => 1024, :default => "", :null => false
      t.column "comment",      :text, :null => false, :default => ""
      t.column "type",         :string,   :limit => 50,   :default => "", :null => false
      t.column "owner_id",     :integer,                                  :null => false
      t.column "creator_id",   :integer,                                  :null => false
      t.column "lock_version", :integer,                  :default => 0
    end

    add_index "resources", ["owner_id"], :name => "fk_re_owner"
    add_index "resources", ["creator_id"], :name => "fk_re_creator"

    create_table "transitive_membership", :id => false, :force => true do |t|
      t.column "group_id",  :integer, :null => false
      t.column "member_id", :integer, :null => false
    end

    add_index "transitive_membership", ["group_id"], :name => "fk_tgm_group"
    add_index "transitive_membership", ["member_id"], :name => "fk_tgm_member"

    create_table "users", :id => false, :force => true do |t|
      t.column "principal_id", :integer,                               :null => false
      t.column "pwhash",       :string,  :limit => 32, :default => "", :null => false
      t.column "lock_version", :integer,               :default => 0
    end

    add_index "users", ["principal_id"], :name => "fk_us_principal"

    create_table "vcrs", :id => false, :force => true do |t|
      t.column "resource_id",       :integer,                               :null => false
      t.column "checked_id",        :integer,                               :null => false
      t.column "vhr_id",            :integer,                               :null => false
      t.column "checked_state",     :string,  :limit => 1, :default => "I", :null => false
      t.column "auto_version",      :string
      t.column "checkin_on_unlock", :boolean, :default => false, :null => false
    end

    add_index "vcrs", ["resource_id"], :name => "fk_vc_resource"
    add_index "vcrs", ["checked_id"], :name => "fk_vc_checked"
    add_index "vcrs", ["vhr_id"], :name => "fk_vc_vhr"

    create_table "versions", :id => false, :force => true do |t|
      t.column "resource_id", :integer, :null => false
      t.column "number",      :integer, :null => false
      t.column "vhr_id",      :integer, :null => false
    end

    add_index "versions", ["resource_id"], :name => "fk_ve_resource"
    add_index "versions", ["vhr_id"], :name => "fk_ve_vhr"
    
  end

  def self.down
    drop_table "aces"
    drop_table "aces_privileges"
    drop_table "acl_inheritance"
    drop_table "binds"
    drop_table "lockroot_binds"
    drop_table "bodies"
    drop_table "locks"
    drop_table "locks_resources"
    drop_table "membership"
    drop_table "namespaces"
    drop_table "principals"
    drop_table "privileges"
    drop_table "properties"
    drop_table "redirects"
    drop_table "resources"
    drop_table "transitive_membership"
    drop_table "users"
    drop_table "vcrs"
    drop_table "versions"

  end
end
