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

class PrincipalRecord < ActiveRecord::Base

  unless defined?(DEFAULT_QUOTA)
    DEFAULT_QUOTA = 2**30
  end

  set_table_name "principals"
  set_primary_key "resource_id"

  before_save :check_quota

  validates_presence_of :name, :used_quota, :total_quota
  validates_uniqueness_of :name

  proxied_by :principal, :foreign_key => "resource_id"

  has_many(:owned_resources,
           :class_name => "Resource",
           :foreign_key => "owner_id")
  
  has_many(:created_resources,
           :class_name => "Resource",
           :foreign_key => "creator_id")

  has_many(:locks,
           :class_name => "Lock",
           :foreign_key => "owner_id",
           :dependent => :destroy)

  #             :finder_sql => 'SELECT * FROM dav_locks dl ' +
  #                            'WHERE dl.owner_id = #{id} AND ' +
  #                            'dl.expires_at > now()'

  has_many :aces, :dependent => :destroy, :foreign_key => 'principal_id'

  has_and_belongs_to_many( :groups, :join_table => "membership",
                           :foreign_key => "member_id" )


  has_and_belongs_to_many( :transitive_groups,
                           :class_name => "Group",
                           :join_table => "transitive_membership",
                           :foreign_key => "member_id",
                           :association_foreign_key => "group_id" )



  def before_validation_on_create
    self.total_quota ||= DEFAULT_QUOTA
  end

  def check_quota
    raise InsufficientStorageError if (total_quota >= 0) && (used_quota > total_quota)# negative total quota means infinite quota
  end

  def after_create
    principal.after_proxied_create
  end

  def before_destroy
    owned_resources.reload
    Principal.limeorphanage.owned_resources << owned_resources

    created_resources.reload
    Principal.limeorphanage.created_resources << created_resources

    connection.execute("set foreign_key_checks=0")
  end

  def after_destroy
    connection.execute("set foreign_key_checks=1")
  end


  # lookup if self is contained(transitively) in group principal?
  def member_of? group
    transitive_groups.include? group
  end

  def principal_url(xml)
    principal.principal_url(xml)
  end

end

