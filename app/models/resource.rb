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
require 'rexml/document'
require 'set'
require 'uuidtools'
require 'web_dav_response'

class Resource < ActiveRecord::Base

  validates_presence_of :uuid, :owner, :creator
  validates_uniqueness_of :uuid
  validates_format_of :uuid, :with => /^[0-9a-f]{32}$/

  belongs_to :owner_record, :class_name => "PrincipalRecord", :foreign_key => "owner_id"
  belongs_to :creator_record, :class_name => "PrincipalRecord", :foreign_key => "creator_id"

  has_one :acl_node, :dependent => :destroy
  has_one :body, :dependent => :destroy

  has_many(:aces, :dependent => :destroy,
           :order => "protected DESC, position ASC") do
    def add principal, grantdeny, protected, *privileges
      ace = case principal
            when Principal
              find_or_create_by_grantdeny_and_principal_id_and_property_namespace_id_and_protected grantdeny, principal.id, nil, protected
            when PropKey
              ns = Namespace.find_by_name principal.ns
              find_or_create_by_grantdeny_and_property_name_and_property_namespace_id_and_protected grantdeny, principal.name, ns.id, protected
            when :self
              find_or_create_by_grantdeny_and_property_namespace_id_and_protected grantdeny, -1, protected
            else raise "invalid value for principal: #{principal.inspect}"
            end
      
      ace.privileges << privileges
      ace.save!
    end

    def remove principal, grantdeny, protected, *privileges
      acs = case principal
            when Principal
              find_all_by_grantdeny_and_principal_id grantdeny, principal.id
            when PropKey
              ns = Namespace.find_by_name principal.ns
              find_all_by_grantdeny_and_property_name_and_property_namespace_id grantdeny, principal.name, ns.id
            when :self
              find_all_by_grantdeny_and_property_namespace_id grantdeny, -1
            else raise "invalid value for principal: #{principal.inspect}"
            end

      raise(InternalServerError, "inconsistency in acl for #{self.inspect}") if acs.size > 2

      ace = acs.find{ |a| a.protected? == protected }

      if ace.nil?
        # TODO: specify (DAV:no-protected-ace-conflict) precondition
        raise ForbiddenError if !protected && acs.size == 1
        return
      end

      ace.privileges.delete *privileges
      ace.save!
    end
  end
  
  has_many(:unprotected_aces,
           :class_name => "Ace",
           :order => "position",
           :conditions => "protected = 0")

  has_many :binds, :dependent => :destroy
  has_many :parents, :through => :binds
  
  has_many(:properties,
           :dependent => :destroy) do

    # FIXME:  this may find cross-products of namespace and names in propkeys!!
    def find_any_by_propkey(*propkeys)
      namespaces, names = propkeys.map{ |pk| [pk.ns, pk.name]}.transpose

      namespaces_sql = namespaces.sql_in_condition

      names_sql = names.sql_in_condition{ |n| "'#{n}'" }

      find(:conditions =>
           "namespace_id IN #{namespaces_sql}" +
           " AND name IN #{names_sql} AND value IS NOT NULL")
    end
    
    def find_by_propkey(propkey)
      ns = Namespace.find_by_name(propkey.ns)
      return nil if ns.nil?
      prop = find_by_name_and_namespace_id(propkey.name, ns.id)
      return nil if prop.nil? || prop.value.nil?
      prop
    end

    def find_or_build_by_propkey(propkey)
      ns = Namespace.find_or_create_by_name!(propkey.ns)
      prop = find_by_name_and_namespace_id(propkey.name, ns.id)
      prop = build(:name => propkey.name, :namespace => ns) if prop.nil?
      prop
    end
    
  end

  has_and_belongs_to_many(:locks,
                          :join_table => "locks_resources",
                          :conditions => "expires_at > utc_timestamp()") do
    def depth_infinity
      find_all_by_depth('I')
    end
  end

  # NOTE: if you do a self.direct_locks.create! be sure to
  # pass in :resource => self .  otherwise, Lock#create! 
  # won't get the same instance of self and therefore won't
  # get any path_binds or url that may have been set via
  # Bind::locate()
  has_many(:direct_locks,
           :class_name => "Lock",
           :dependent => :destroy,
           :conditions => "expires_at > utc_timestamp()" )

  def before_validation_on_create
    # default to randomly generate UUID
    if self.uuid.nil? || self.uuid.empty?
      self.uuid = UUID.random_create.to_s.gsub('-','').downcase
    end
    # default creator to be limeberry
    self.creator_record ||= Principal.limeberry.principal_record
    # default owner_id to be same as creator_id
    self.owner_record ||= self.creator_record

    # convert null to empty string for displayname and comment
    self.displayname ||= ""
    self.comment ||= ""
  end

  def after_create
    owner_pk = PropKey.get 'DAV:', 'owner'
    Privilege.priv_all.grant(self, owner_pk, true)
    reload # otherwise owner may be stale
  end

  def destroy
    #Temporarily turn garbage collection off until the resource is deleted completely
    #(Otherwise garbage collector calls the destroy method on the same resource 
    # again when its binds are destroyed)
    Bind.with_garbage_collection_off { super }
    Bind.collect_garbage
  end

  def owner
    self.owner_record.principal
  end

  def owner=(new_owner)
    self.owner_record = new_owner.principal_record
    self.save! unless new_record?
    new_owner
  end

  def creator
    self.creator_record.principal
  end

  def creator=(new_creator)
    self.creator_record = new_creator.principal_record
    self.save! unless new_record?
    new_creator
  end

  def acl_parent=(parent)
    Resource.transaction do

      raise ForbiddenError if self == parent

      old_parent = acl_parent

      if parent.nil?
        orphan_acl
        return
      end

      # past this point, parent cannot be nil

      # start a new tree if parent is not in one
      if parent.acl_node.nil?
        parent.create_acl_node
        parent.acl_node.save!
      end
      # past this point, parent.acl_node cannot be nil

      if acl_node.nil?
        create_acl_node
        acl_node.save!
      elsif acl_node.parent == parent.acl_node
        # nothing to do
        return
      end
      # past this point, acl_node cannot be nil

      # destroy acl_node if it's jumping to a different tree
      #acl_node.destroy if acl_node.base != parent.acl_node.base

      acl_node.move_to_child_of(parent.acl_node)
      # acl_node is reloaded automatically by better_nested_set

      parent.acl_node.reload
    end
  end

  def acl_parent
    #return nil if it does not have a parent
    acl_node && acl_node.parent && acl_node.parent.resource
  end

  def orphan_acl
    return if acl_node.nil?

    if acl_node.children.empty?
      acl_node.destroy
      reload
    else
      acl_node.move_to_right_of(acl_node.roots[-1])
    end
  end

  # ACL
  def acl=
  end

  # MOVE
  def self.move(source_pathname, target_pathname, principal,
                overwrite = true, *locktokens)
    res = Bind.locate(source_pathname)
    raise NotFoundError if res.is_a?(LockNullResource)

    target_collection = Collection.parent_collection_raises_conflict(target_pathname)

    target_collection.rebind(File.basename(target_pathname), source_pathname,
                             principal, overwrite, *locktokens)
  end

  def copied_over(principal, *locktokens)
    self.properties.clear
  end

  def copy_over_existing_resource(target, principal, *locktokens)
    raise ForbiddenError if self == target

    target.copied_over(principal, *locktokens)

    Privilege.priv_write_content.assert_granted(target, principal)
    Privilege.priv_write_properties.assert_granted(target, principal)

    target.body = self.body.clone unless self.body.nil?

    copy_properties(target)

    target.save!
    target
  end

  def copy_to_new_resource(principal)
    copy_over_existing_resource(self.class.create!(:creator => principal), principal)
  end

  # COPY
  def copy(target_pathname, principal, depth = '0',
           overwrite = true, *locktokens)
    status = nil
    Privilege.priv_read.assert_granted(self, principal)

    Resource.transaction do
      target_parent = Collection.parent_collection_raises_conflict(target_pathname)

      target_basename = File.basename(target_pathname)
      target = target_parent.find_child_by_name(target_basename)

      if target.nil?
        # target does not exist
        # lock on parent checked in bind
        target = copy_to_new_resource(principal)
        status = Status::HTTP_STATUS_CREATED
      else
        raise PreconditionFailedError unless overwrite
        raise LockedError if target.locks_impede_modify?(principal, *locktokens)
        raise PreconditionFailedError if target.is_a?(Vcr) and target.checked_in?

        if self.instance_of?(target.class)
          copy_over_existing_resource(target, principal, *locktokens)
          response = DavResponse::CopyWebdavResponse.new Status::HTTP_STATUS_NO_CONTENT
          return response
        else
          # copying over different resource type. We can do a delete first. See
          # http://lists.w3.org/Archives/Public/w3c-dist-auth/2006JulSep/0070.html

          # FIXME???  maybe we should be keeping the same resource-id
          # and/or have all prior binds still intact (to new resource
          # -- if not keeping resource-id

          # Locks will be transferred and the old target will be unbound when bind is called.
          target = copy_to_new_resource(principal)
          status = Status::HTTP_STATUS_NO_CONTENT
        end
      end

      # priv_bind checked in Collection#bind
      target_parent.bind_and_set_acl_parent(target, target_basename,
                                            principal, true,
                                            *locktokens)
      
      DavResponse::CopyWebdavResponse.new status
    end
  end

  def self.num_props_sent_in_allprop
    self.liveprops.select { |k, v| v.allprop? }.size
  end

  

  def url_lastmodified= (lastmodified)
    @url_lastmodified = lastmodified
  end

  def url_lastmodified
    give_me_any_url if @url_lastmodified.nil?
    @url_lastmodified
  end
  
  def path_binds=(binds)
    @path_binds = binds
  end

  def path_binds
    give_me_any_url if @path_binds.nil?
    @path_binds
  end
  
  def url=(url)
    @url = url
  end
  
  def url
    return @url unless @url.nil?
    give_me_any_url
    @url
  end

  def url?
    !@url.nil?
  end

  def give_me_any_url
    logger.debug "giving any url to resource #{id}"
    @url = Bind.find_any_acyclic_path_to(self)
    better_self = Bind.locate @url
    path_binds = better_self.path_binds
    url_lastmodified = better_self.url_lastmodified
    logger.debug "giving url: #{@url}"
  end
  
  def self.find_by_dav_resource_id dav_resource_id
    uuid = Utility.urn_to_uuid dav_resource_id
    r = Resource.find_by_uuid(uuid)
    raise NotFoundError if r.nil?
    r
  end

  def msg_assign(msg)
    "#{msg.to_s}=".to_sym
  end
  private :msg_assign

  def copy_properties(target)
    # copy live properties that should be copied
    target.displayname = self.displayname
    target.comment = self.comment

    # now copy the dead properties
    target.properties << self.properties.map{ |p| p.clone}
  end

  # COPY
  def self.copy(source_pathname, target_pathname, principal,
                depth = 'infinity', overwrite = true, *locktokens)
    source = Bind.locate(source_pathname)
    response =  source.copy(target_pathname, principal, depth,
                            overwrite, *locktokens)
  end


  # Live Property Methods
  # TODO unescape assignment of liveprops where appropriate

  # RFC 2518
  def creationdate(xml)
    xml.D(:creationdate, created_at.httpdate)
  end

  def dav_displayname(xml)
    xml.tag_with_unescaped_text! "D:displayname", self.displayname
  end

  def dav_displayname=(new_displayname)
    self.displayname = new_displayname
    save!
  end

  def getcontentlanguage(xml)
    raise NotFoundError if body.nil?
    xml.D(:getcontentlanguage, body.contentlanguage)
  end

  def getcontentlanguage=(contentlanguage)
    raise NotFoundError if body.nil?
    body.contentlanguage = contentlanguage
    body.save!
  end

  def getcontentlength(xml)
    raise NotFoundError if body.nil?
    xml.D(:getcontentlength, body.size.to_s)
  end

  def getcontenttype(xml)
    raise NotFoundError if body.nil?
    xml.D(:getcontenttype, body.mimetype)
  end

  def getetag(xml)
    raise NotFoundError if body.nil?
    xml.D(:getetag, body.sha1)
  end

  # getlastmodified time is to be determined based on
  # the URL.  Take the max of the updated_at of all the binds
  # along the URL and the body's created_at
  def getlastmodified(xml)
    raise NotFoundError if body.nil?
    xml.D(:getlastmodified, lastmodified.httpdate)
  end

  def lastmodified
    cat = body.nil? ? created_at : body.created_at
    [cat, @url_lastmodified].compact.max
  end

  def lockdiscovery(xml)
    xml.D :lockdiscovery do
      locks.each { |l| l.activelock(xml) }
    end
  end

  def resourcetype(xml)
    xml.D :resourcetype
  end

  # empty for now
  def source(xml)
    xml.D :source
  end

  def supportedlock(xml)
    xml.D :supportedlock do
      xml.D :lockentry do
        xml.D :lockscope do
          xml.D :exclusive
        end
        xml.D :locktype do
          xml.D :write
        end
      end

      xml.D :lockentry do
        xml.D :lockscope do
          xml.D :shared
        end
        xml.D :locktype do
          xml.D :write
        end
      end
    end
  end

  # RFC 3253 (DeltaV)
  
  def dav_comment(xml)
    xml.D :comment, comment
  end

  def dav_comment=(new_comment)
    self.comment = new_comment
    save!
  end

  def creator_displayname(xml)
    xml.D(:"creator-displayname", creator.displayname)
  end
  
  def supported_live_property_set(xml)
    xml.D("supported-live-property-set".to_sym) do
      liveprops.propname do |pk|
        xml.D("supported-live-property".to_sym) do
          xml.D(:prop) { pk.xml(xml) }
        end
      end
    end
  end
  
  # RFC 3744 (ACL)

  def dav_owner(xml) xml.D(:owner) { owner.principal_url(xml) }; end
  def group(xml) xml.D(:group); end

  def supported_privilege_set(xml)
    xml.D :"supported-privilege-set" do
      Privilege.priv_all.supported_privilege xml, *supported_privileges
    end
  end
  
  # this is for reading (not setting) the acl
  def acl(xml)
    xml.D(:acl) { acl_inner(xml) }
  end

  def acl_inner(xml, inherited = false)
    aces.each { |ace| ace.elem(xml, inherited) }
    self.acl_parent.acl_inner(xml, true) if self.acl_parent
  end
  
  def current_user_privilege_set(xml, principal)
    xml.D :"current-user-privilege-set" do
      Privilege.cups(self, principal).each { |priv| priv.elem xml }
    end
  end

  # FIXME: prefix with BASE_WEBDAV_PATH
  def href(xml)
    xml.D(:href, url)
  end

  # BIND draft

  def dav_resource_id(xml)
    xml.D(:"resource-id") do
      xml.D(:href, Utility.uuid_to_urn(uuid))
    end
  end

  def parent_set(xml)
    xml.D(:"parent-set") do
      binds.each do |bind|
        xml.D :parent do
          bind.parent.href(xml)
          xml.D(:segment, bind.name)
        end
      end
    end
  end

  
  def xml_wrap_liveprop(propkey, method, xml = nil, principal = nil)
    method = self.method(method)
    
    if method.arity >= 1 || method.arity <= -2
      target = ""

      if xml.nil?
        xml = Builder::XmlMarkup.new(:indent => Limeberry::XML_INDENT,
                                     :target => target)
      end
      
      if method.arity >= 2 || method.arity <= -3
        method.call xml, principal
      else
        method.call xml
      end
      
      target
    else
      method.call
    end
    
  end  
  
  #generates propstats
  # propkeys may be :propname or :allprop
  def propfind(xml, principal, already_reported, *propkeys)
    success_status =
      already_reported ? Status::HTTP_STATUS_ALREADY_REPORTED : Status::HTTP_STATUS_OK

    if propkeys.empty? or propkeys[0] == :allprop
      propstat(xml, success_status) { propfind_allprop(xml) }
    elsif propkeys[0] == :propname
      propstat(xml, success_status) { propfind_propname(xml) }
    else
      status2propkeys = Hash.new{ |h, k| h[k] = [] }
      propkeys.each do |pk|
        status = propfind_status(pk, principal, success_status)
        status2propkeys[status] << pk
      end

      status2propkeys.each do |status, pks|
        propstat(xml, status) do
          if status == success_status # reporting values
            pks.each do |pk|
              if liveprops.include?(pk)
                liveprops[pk, xml]
              else
                value = properties.find_by_propkey(pk).value
                xml << value
              end
            end
          else # reporting error
            pks.each { |pk| pk.xml(xml) }
          end
        end
      end
      
    end
  end
  

  private


  def propfind_status(propkey, principal,
                      success_status = Status::HTTP_STATUS_OK)
    if liveprops.include?(propkey)
      liveprops.assert_read(propkey, principal)
    else
      property = properties.find_by_propkey(propkey)
      raise NotFoundError if property.nil?
    end
    success_status
  rescue HttpError => e
    e.status
  end

  def propstat(xml, status, &block)
    xml.D :propstat do
      xml.D(:prop, &block)
      xml.D(:status, status.to_s)
    end
  end
  
  def propfind_allprop(xml)
    liveprops.allprop(xml)
    properties.each { |p| xml << p.value }
  end

  # returns array of propkeys
  def propfind_propname(xml)
    liveprops.propname(xml)
    properties.each { |p| p.propkey.xml(xml) }
  end

  public
  
  def proppatch_remove_one(propkey)
    raise ForbiddenError if liveprops.include?(propkey)
    property = self.properties.find_by_propkey(propkey)
    properties.delete(property) unless property.nil?
  end

  # takes in REXML::Element
  def proppatch_set_one(element)
    element = REXML::Document.new(element).root if element.instance_of? String
    pk = element.propkey
    if liveprops.include?(pk)
      liveprops[pk] = element.innerXML
      self.save! # should possibly be moved elsewhere
    else
      value = ''
      element.write value
      property = properties.find_or_build_by_propkey(pk)
      property.value = value unless value.nil? # is the nil check still needed?
      property.save!
    end
  end

  def locked?
    !self.locks.empty?
  end

  # check whether resource can be locked or not?
  # with lock of scope 'lockscope' ( 'S' or 'X' )
  def assert_lockable(principal, lockscope)
    # check for privileges
    Privilege.priv_write_content.assert_granted(self, principal)

    # check if resource is locked?
    # and also for shared and exclusive
    if self.locked?
      raise LockedError unless
        (lockscope == 'S' && self.locks[0].scope == 'S')
    end
  end

  def options
    %w(GET HEAD OPTIONS DELETE PUT PROPFIND PROPPATCH COPY MOVE LOCK VERSION-CONTROL UNLOCK ACL)
  end

  def supported_privileges
    names_sql = supported_privilege_names.sql_in_condition{ |n| "'#{n}'" }

    Privilege.find(:all,
                   :conditions => "namespace_id = #{Namespace.dav.id}" +
                   " AND name IN #{names_sql}")
  end

  def locked_with?(token)
    return false if token.nil?
    !locks.find_by_uuid(token).nil?
  end

  def modified_since?(time)
    time < lastmodified
  end


  def locks_impede_modify?(principal, *locktokens)
    return Lock.locks_impede_modify?(self.locks, principal, *locktokens)
  end
  
  def descendant_binds
    []
  end

  def descendants
    []
  end
  
  def descendants_and_self
    descendants << self
  end
  

  # transfer direct_locks that have bind in lockroot_binds
  def transfer_direct_locks(destination, bind, principal, *locktokens)
    transaction do
      # find locks to transfer
      return [] if direct_locks.empty?
      
      locks_to_xfer = bind.locks.find(:all,
                                      :conditions =>
                                      "id IN #{direct_locks.sql_in_condition}")

      # Locktoken of any of the transferred locks is required
      raise LockedError if Lock.locks_impede_modify?(locks_to_xfer,
                                                     principal,
                                                     *locktokens)

      desc = destination.descendants
      
      begin
        locks_to_xfer.each { |lock| lock.transfer(destination, principal, *desc) }
        self.reload
      rescue LockedError
        raise ConflictError
      rescue StaleLockNullError # ignore
      end

      destination.reload

      return locks_to_xfer
    end
  end

  def mkcol(principal, *locktokens)
    raise MethodNotAllowedError
  end

  def before_acl(principal, *locktokens)
    Privilege.priv_write_acl.assert_granted(self, principal)
    before_write_common principal, *locktokens
  end
  
  def before_read_common(principal)
    Privilege.priv_read.assert_granted(self, principal)
  end
  
  def before_read_properties(principal)
    before_read_common principal
  end

  def before_read_content(principal)
    before_read_common principal
  end

  def before_read(principal)
    before_read_common principal
  end

  def before_write_common(principal, *locktokens)
    raise LockedError if locks_impede_modify?(principal, *locktokens)
  end

  def before_write_properties(principal, *locktokens)
    Privilege.priv_write_properties.assert_granted(self, principal)
    before_write_common principal, *locktokens
  end

  def before_write_content(principal, *locktokens)
    Privilege.priv_write_content.assert_granted(self, principal)
    before_write_common principal, *locktokens
  end

  def before_write(principal, *locktokens)
    Privilege.priv_write_content.assert_granted(self, principal)
    Privilege.priv_write_properties.assert_granted(self, principal)
    before_write_common principal, *locktokens
  end
  
  

  @liveprops = {}

  # [ namespace, name ]  =>
  #   [ method, protected?, allprop?, read priv ]
  
  {
    # RFC 2518
    %w(DAV: creationdate) => [ :creationdate, true, true ],
    %w(DAV: displayname) => [ :dav_displayname, false, true ],
    %w(DAV: getcontentlanguage) => [ :getcontentlanguage, false, true ],
    %w(DAV: getcontentlength) => [ :getcontentlength, true, true ],
    # can't set mimetype for now for security reasons
    %w(DAV: getcontenttype) => [ :getcontenttype, true, true ],
    %w(DAV: getetag) => [ :getetag, true, true ],
    %w(DAV: getlastmodified) => [ :getlastmodified, true, true ],
    %w(DAV: lockdiscovery) => [ :lockdiscovery, true, true ],
    %w(DAV: resourcetype) => [ :resourcetype, true, true ],
    %w(DAV: source) => [ :source, true, true ],
    %w(DAV: supportedlock) => [ :supportedlock, true, true ],

    # RFC 3253 (DeltaV)
    %w(DAV: comment) => [ :dav_comment, false , false],
    %w(DAV: creator-displayname) => [ :creator_displayname, true, false],
    # %w(DAV: supported-method-set) => [ :supported_method_set, true, false ],
    %w(DAV: supported-live-property-set) => [:supported_live_property_set, true, false],
    # %w(DAV: supported-report-set) => [ :supported_report_set, true, false ],

    # RFC 3744 (ACL)
    %w(DAV: owner) => [:dav_owner, true, false ],
    %w(DAV: group) => [:group, true, false ],
    %w(DAV: supported-privilege-set) => [ :supported_privilege_set, true, false ],
    %w(DAV: current-user-privilege-set) => [ :current_user_privilege_set, true, false,
                                             Privilege.priv_read_current_user_privilege_set ],
    %w(DAV: acl) => [ :acl, true, false, Privilege.priv_read_acl ],
#     %w(DAV: acl-restrictions) => [ :acl_restrictions, true, false ],
#     %w(DAV: inherited-acl-set) => [ :inherited_acl_set, true, false ],
#     %w(DAV: principal-collection-set) => [ :principal_collection_set, true, false ],
        
    # BIND draft
    %w(DAV: resource-id) => [ :dav_resource_id, true, false ],
    %w(DAV: parent-set) => [ :parent_set, true, false ],
    
  }.each do |k, v|
    @liveprops[PropKey.get(*k)] =
      LiveProps::LivePropInfo.new(*v)
  end

  @liveprops.freeze

  private

  def self.liveprops
    if @liveprops
      @liveprops
    elsif superclass.respond_to?(:liveprops)
      superclass.liveprops
    else
      nil
    end
  end

  def common_supported_privilege_names
    %w(all read read-acl read-current-user-privilege-set write write-properties write-acl unlock)
  end

  def supported_privilege_names
    common_supported_privilege_names.push "write-content"
  end

  public

  def liveprops
    @liveprops ||= LiveProps.new(self)
  end
  
  def self.version_control(pathname, principal)
    resource = Bind.locate(pathname)
    unless resource.is_a? Vcr 
      Resource.transaction do
        resource.convert_to_vcr(principal)
        resource = Resource.find(resource) # resource is now an object of class Vcr
        resource.init_versioning(principal)
      end
    end
    DavResponse::VersionControlWebdavResponse.new Status::HTTP_STATUS_OK
  end
  
  def convert_to_vcr(principal)
    Privilege.priv_write_properties.assert_granted(self, principal)
    self[:type] = 'Vcr'
    self.save!
  end
  
  def checkout(principal)
    raise MethodNotAllowedError
  end
  
  def checkin(principal)
    raise MethodNotAllowedError
  end
end
