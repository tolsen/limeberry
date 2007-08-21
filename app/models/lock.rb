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

require 'uuidtools'

class Lock < ActiveRecord::Base
  after_save :destroy_expired_locks
  after_destroy :destroy_lock_null_resource

  validates_presence_of :uuid, :resource_id, :owner_record

  validates_inclusion_of :scope, :in => [ 'S', 'X' ]
  validates_inclusion_of :depth, :in => [ 'I', '0' ]

  validates_format_of :uuid, :with => /^[0-9a-f]{32}$/
  validates_format_of :lock_root, :with => /^\//

  belongs_to(:owner_record,
             :class_name => "PrincipalRecord",
             :foreign_key => "owner_id")

  # resource which is *directly* locked
  belongs_to :resource

  # all locks, direct and indirect
  has_and_belongs_to_many :resources

  # binds covered by the lockroot
  has_and_belongs_to_many :binds, :join_table => "lockroot_binds"
  
  def before_validation_on_create
    @dav_errors = Hash.new { |h, k| h[k] = [] }
    
    self.uuid = UUID.random_create.to_s.gsub('-','').downcase

    if self.lock_root.blank?
      self.lock_root = self.resource.url
    else
      begin
        self.resource = Bind.locate(self.lock_root)
      rescue NotFoundError
        LockNullResource.with_stale_ok do
          res = @@locked_unmapped_class.create!(:creator => self.owner)
          parent = Collection.parent_collection_raises_conflict(self.lock_root)
          parent.bind_and_set_acl_parent(res,
                                         File.basename(lock_root),
                                         self.owner, false, :unmapped)

          # locating to get path_binds
          self.resource = Bind.locate(self.lock_root)
        end
      end
    end
  end

  # TODO: move dav_errors into a common class
  # or monkey patch into ActiveRecord
  attr_reader :dav_errors
  
  def validate_on_create
    resource.assert_lockable(owner, scope)

    if infinite? && resource.kind_of?(Collection)
      resource.descendants.each do |r|
        begin
          r.assert_lockable(owner, scope)
        rescue HttpError => e
          Bind.find_all_acyclic_paths_between(resource, r).each do |p|
            @dav_errors[e] << "#{resource.url}/#{p}"
          end
          errors.add_to_base("cannot lock descendant: #{r.url}")
        end
      end
    end
    
  end

  def after_create
    self.resources << resource
    self.resources << resource.descendants if infinite?
    self.binds = resource.path_binds
    reload
  end
  
  def owner= new_owner
    self.owner_record = new_owner.principal_record
    self.save! unless new_record?
    new_owner
  end


  def owner
    self.owner_record.principal
  end

  def token_given?(*tokens)
    tokens.include? self.uuid
  end

  def token_given_and_owned?(principal, *tokens)
    token_given?(*tokens) && (self.owner == principal)
  end

  def infinite?
    depth == 'I'
  end

  def self.destroy_expired_locks()
    LockNullResource.with_stale_ok do
      destroy_all(["expires_at <= ?",  Time.now])
    end
  end
  def destroy_expired_locks() self.class.destroy_expired_locks; end

  def destroy_lock_null_resource
    LockNullResource.with_stale_ok do
      unless (direct_resource = self.resource).nil?
        direct_resource.destroy if
          (direct_resource.direct_locks.empty? && direct_resource.is_a?(LockNullResource))
      end
    end
  end

  def activelock(xml)
    xml.D :activelock do
      xml.D :locktype do
        xml.D :write
      end
      xml.D :lockscope do
        xml.D(scope == 'X' ? :exclusive : :shared)
      end
      xml.D(:depth, (depth == 'I') ? 'infinity' : '0')
      xml.D :owner do
        xml << owner_info
      end
      xml.D(:timeout, "Second-#{seconds_left}")
      xml.D(:locktoken) { xml.D(:href, locktoken) }
      xml.D :lockroot do
        xml.D(:href, File.join(BASE_WEBDAV_PATH, lock_root))
      end
    end
  end

  def seconds_left
    (self.expires_at - Time.now).to_i
  end
  
  # timeout
  def refresh(timeout)
    self.expires_at = Time.now + timeout
    save!
  end

  def transfer(resource, principal, *descendants)
    transaction do
      resource.assert_lockable(principal, scope)
      self.resource = resource
      regenerate_resources(principal, *descendants)
      regenerate_binds
      save!
    end
  end

  # this only asserts lockable on descendants, not self
  def regenerate_resources(principal, *descendants)
    transaction do
      self.resources.clear
      desc = descendants.empty? ? resource.descendants : descendants
      desc.each{ |r| r.assert_lockable(principal, scope) }
      self.resources = desc << self.resource
    end
  end
  
  
  def regenerate_binds
    transaction { self.binds = Bind.locate(lock_root).path_binds }
  end

  def locktoken
    Utility.uuid_to_locktoken uuid
  end

  def urn
    Utility.uuid_to_urn uuid
  end

  def self.locks_impede_modify?(locks, principal, *locktokens)
    return false if locks.empty? || locktokens.include?(:unmapped)
    return true if locktokens.empty?

    locks_str = locks.sql_in_condition
    locktokens_str = locktokens.sql_in_condition{ |t| "\"#{t}\"" }
    
    lock = self.find(:first, :conditions =>
                     "owner_id = #{principal.id}" +
                     " AND id IN #{locks_str}" +
                     " AND uuid IN #{locktokens_str}")

    # if no locks match then we can't modify
    return lock.nil?
  end

  def self.load_unmapped_class
    @@locked_unmapped_class = AppConfig.lock_unmapped_url == "LNR" ? LockNullResource : Resource
  end

  load_unmapped_class

end
