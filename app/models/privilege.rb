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

class Privilege < ActiveRecord::Base

  validates_uniqueness_of :name
  
  acts_as_nested_set
  belongs_to :namespace
  has_and_belongs_to_many :aces

  # Privilege.priv_*
  # example: Privilege.priv_all

  # standard dav privileges:
  #
  #     DAV:all
  #      DAV:read
  #      DAV:read-acl
  #      DAV:read-current-user-privilege-set
  #      DAV:write
  #         DAV:write-properties
  #         DAV:write-content
  #         DAV:bind
  #         DAV:unbind
  #      DAV:write-acl
  #      DAV:unlock
  def self.method_missing( method_id, *arguments )
    return super unless /priv_\w*/.match( method_id.to_s )

    priv_name = method_id.to_s.sub( /^priv_(\w*)/, '\1' ).gsub( /_/, '-' )
    priv = find_by_name_and_namespace_id( priv_name, Namespace.dav.id )
    return super if priv.nil?
    priv
  end

  def self.find_by_propkey propkey
    ns = Namespace.find_by_name(propkey.ns)
    return nil if ns.nil?
    ns.privileges.find_by_name propkey.name
  end

  def grant resource, principal, protected = false
    resource.aces.add principal, Ace::GRANT, protected, self
  end

  def deny resource, principal, protected = false
    resource.aces.add principal, Ace::DENY, protected, self
  end

  def ungrant resource, principal, protected = false
    resource.aces.remove principal, Ace::GRANT, protected, self
  end

  def undeny resource, principal, protected = false
    resource.aces.remove principal, Ace::DENY, protected, self
  end

  def assert_granted(resource, principal)
    principal ||= Principal.unauthenticated
    Privilege.raise_permission_denied(principal) unless
      granted?(resource, principal)
    true
  rescue HttpError => e
    e.resource = resource
    raise e
  end

  def self.raise_permission_denied(principal)
    if principal.nil? || principal == Principal.unauthenticated
      raise UnauthorizedError
    else
      raise ForbiddenError
    end
  end

  # is this privilege granted on resource to principal?
  def granted?(resource, principal)

    # LimeBerry principal can do anything
    return true if principal == Principal.limeberry

    # consisting of the transitive group membership
    membership_str =
      "(SELECT group_id, member_id FROM transitive_membership\n" +
      "WHERE member_id = :principal_id\n" +
      "UNION\n" +
      # and a pseudo-membership where principal is a member of
      # itself
      "SELECT :principal_id group_id, :principal_id member_id) membership\n"

    # be sure to check aggregate privileges which may contain this one
    privs_str = "(SELECT par_priv.id par_priv_id\n" +
      "FROM privileges par_priv\n" +
      "INNER JOIN\n" + # privileges joins with itself
      "privileges chi_priv\n" +
      "ON par_priv.lft <= chi_priv.lft AND par_priv.rgt >= chi_priv.rgt\n" +
      "WHERE chi_priv.namespace_id = :namespace_id AND chi_priv.id = :privilege_id ) privs\n"

    # join aces to the resource in question
    # and any resources it may inherit ACLs from
    inherited_res_str = "(SELECT par_res.resource_id resource_id, par_res.rgt par_res_rgt\n" +
      "FROM acl_inheritance par_res\n" +
      "INNER JOIN acl_inheritance chi_res\n" +
      "ON (\n" +
      #"par_res.base_id = chi_res.base_id AND\n" +
      "par_res.lft < chi_res.lft AND par_res.rgt > chi_res.rgt)\n" +
      "WHERE chi_res.resource_id = :resource_id\n" +
      "UNION\n" +
      "SELECT :resource_id resource_id, -1 par_res_rgt)\n" +
      "inherited_res\n"

    sql_query = "SELECT aces.id, aces.grantdeny, aces.protected FROM aces aces \n" +
      "INNER JOIN aces_privileges ap\n" +
      "ON aces.id = ap.ace_id\n" +
      "INNER JOIN\n" +
      membership_str +
      "ON aces.principal_id = membership.group_id\n" +
      "INNER JOIN\n" +
      privs_str +
      "ON ap.privilege_id = privs.par_priv_id\n" +
      "INNER JOIN\n" +
      inherited_res_str +
      "ON aces.resource_id = inherited_res.resource_id\n" +
      "ORDER BY aces.protected DESC, par_res_rgt ASC, aces.position ASC\n" +
      "LIMIT 1;"

    values = {
      :namespace_id => self.namespace_id,
      :principal_id => principal.id,
      :privilege_id => self.id,
      :resource_id => resource.id
    }

    aces = Ace.find_by_sql( [ sql_query, values ])

    return false if aces.empty?

    aces[0].grantdeny == Ace::GRANT

  end

  def denied? resource, principal
    ! granted?( resource, principal )
  end

  # <privilege> part of DAV:acl property
  def elem(xml)
    xml.D :privilege do
      # FIXME: handle non-DAV privileges as well
      xml.D(name.to_sym)
    end
  end

  def supported_privilege xml, *privilege_mask
    xml.D :"supported-privilege" do
      elem xml
      xml.tag!("D:description", self.description, "xml:lang" => "en")
      (self.children & privilege_mask).each do |p|
        p.supported_privilege xml, *privilege_mask
      end
    end
  end

  # current-user-privilege-set on resource for principal
  # returns list of privileges
  def self.cups resource, principal

    sql_query = <<EOS
SELECT 
 privs.*, 
 GROUP_CONCAT(aces.grantdeny 
              ORDER BY aces.protected DESC, par_res_rgt, aces.position) action_concat 
FROM aces aces 
INNER JOIN aces_privileges ap ON aces.id = ap.ace_id 
INNER JOIN 
  (SELECT group_id, member_id FROM transitive_membership
   WHERE member_id = :principal_id
   UNION
   SELECT :principal_id group_id, :principal_id member_id) membership
ON aces.principal_id = membership.group_id 
INNER JOIN 
 (SELECT chi_priv.*, par_priv.id ancestor_id FROM privileges chi_priv 
  INNER JOIN privileges par_priv 
  ON par_priv.lft <= chi_priv.lft AND par_priv.rgt >= chi_priv.rgt) privs 
ON ap.privilege_id = privs.ancestor_id 
INNER JOIN 
 (SELECT par_res.resource_id resource_id, par_res.rgt par_res_rgt 
  FROM acl_inheritance par_res 
  INNER JOIN acl_inheritance chi_res 
  ON (par_res.lft < chi_res.lft AND par_res.rgt > chi_res.rgt) 
  WHERE chi_res.resource_id = :resource_id 
  UNION 
  SELECT :resource_id resource_id, -1 par_res_rgt) inherited_res 
ON aces.resource_id = inherited_res.resource_id 
GROUP BY privs.id 
HAVING LEFT(action_concat, 1) = :grant ;
EOS
    Privilege.find_by_sql([ sql_query, 
                            { :resource_id => resource.id,
                              :principal_id => principal.id,
                              :grant => Ace::GRANT } ])
  end
  
end
