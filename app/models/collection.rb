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
require 'set'
require 'web_dav_response'

class Collection < Resource

  has_many(:childbinds, :dependent => :destroy,
           :class_name => "Bind", :foreign_key => "collection_id")
  has_many :children, :through => :childbinds

  def bind_and_set_acl_parent(child, bind_name, principal,
                              overwrite = true, *locktokens)
    Collection.transaction do
      # bind and set acl parent
      # priv_bind checked in Collection#bind
      status = self.bind(child, bind_name, principal,
                         overwrite, *locktokens)
      child.acl_parent = self
      status
    end
  end


  def bind(child, bind_name, principal,
           overwrite = true, *locktokens)
    status = nil

    transaction do
      Privilege.priv_bind.assert_granted(self, principal)

      bind = self.childbinds.find_by_name( bind_name )

      if bind
        raise PreconditionFailedError unless overwrite
        Privilege.priv_unbind.assert_granted(self, principal)
      else
        raise LockedError if locks_impede_modify?(principal, *locktokens)
      end

      if bind

        Bind.with_garbage_collection_off do
          bind_url = File.join self.url, bind_name
          
          old_urls2paths = Path.find_or_create_by_url(bind_url).descendant_urls_and_paths

          old_locks = bind.locks.to_set

          # old_child gets replaced by child if
          #  I do old_child = old_bind.child
          old_child = find_child_by_name bind_name

          # Overwrite bind's child
          bind.child = child
          bind.save!

          new_urls2paths = Path.find_or_create_by_url(bind_url).descendant_urls_and_paths

          # Transfer direct-locks from old_child to new child
          transferred_locks =
            old_child.transfer_direct_locks(child, bind, principal, *locktokens).to_set

          # Transfer locks on descendants of old child to those of new child
          new_urls2paths.each do |url, new_path|
            next unless ((old_path = old_urls2paths[url]))
            transferred_locks +=
              old_path.bind.child.transfer_direct_locks(new_path.bind.child, old_path.bind,
                                                        principal, *locktokens)
          end

          locks_being_destroyed = old_locks - transferred_locks
          locks_being_destroyed.each do |l|
            raise LockedError unless l.token_given_and_owned?(principal, *locktokens)
            l.destroy
          end
        end
        

        Bind.collect_garbage

        status = Status::HTTP_STATUS_OK

        ## Not overwriting a bind
      else
        self.childbinds.create!( :child => child, :name => bind_name )
        status = Status::HTTP_STATUS_CREATED
      end
      
      # Transfer locks on target_parent to new descendants
      begin
        locks.depth_infinity.each do |l|
          l.regenerate_resources(principal)
        end
      rescue LockedError
        raise ConflictError
      end

      child.reload
      self.reload
    end
    return status
  rescue UnauthorizedError, ForbiddenError => e
    # the error should be reported on the child instead of the parent
    e.url = File.join(url, bind_name) if e.resource == self
    raise
  end

  def unbind(bind_name, principal, *locktokens)
    bind = nil
    transaction do
      bind = self.childbinds.find_by_name( bind_name )
      raise ConflictError unless bind
      Privilege.priv_unbind.assert_granted(self, principal)

      raise LockedError if locks_impede_modify?(principal, *locktokens)
      raise LockedError if bind.locks_impede_bind_deletion?(principal, *locktokens)

      bind.destroy

      desc = descendants
      begin
        locks.each { |l| l.regenerate_resources(principal, *desc) }
      rescue LockedError
        raise ConflictError
      end
    end
  rescue UnauthorizedError, ForbiddenError => e
    # the error should be reported on the child instead of the parent
    e.url = File.join(url, bind_name) if e.resource == self
    raise
  end

  def rebind(new_bind_name, old_path, principal, overwrite = true, *locktokens)

    old_parent = Collection.parent_collection_raises_conflict old_path
    old_bind_name = File.basename old_path

    raise ForbiddenError if old_parent == self && old_bind_name == new_bind_name

    status = nil

    Collection.transaction do
      resource = old_parent.find_child_by_name old_bind_name

      raise ConflictError if resource.nil?

      Bind.with_garbage_collection_off do
        old_parent.unbind(old_bind_name, principal, *locktokens)
        status = self.bind(resource, new_bind_name, principal,
                           overwrite, *locktokens)
      end

      Bind.collect_garbage
    end

    status
  end

  def find_child_by_name name
    childbind = self.childbinds.find_by_name( name )
    childbind && childbind.child
  end

  def put(stream, mimetype, principal, *locktokens)
    raise MethodNotAllowedError
  end

  def copied_over(principal, *locktokens)
    super

    childbinds.each { |bind|
      raise LockedError if bind.locks_impede_bind_deletion?(principal, *locktokens)
      bind.destroy
    }
  end

  def descendant_binds
    Bind.descendants(*childbinds) + childbinds
  end

  def descendants
    Bind.child_resources(*descendant_binds)
  end
  
  def descendant_binds_with_path(pathname)
    reachable_binds_with_path = {}
    new_reachable_binds = childbinds
    resource_and_path = {id => pathname}

    until new_reachable_binds.empty?

      new_reachable_binds.map! { |b|
        next if reachable_binds_with_path.has_key?(b)
        path = File.join(resource_and_path[b.collection_id],b.name)
        reachable_binds_with_path.merge!(b => path)
        resource_and_path.merge!(b.resource_id => path)
        b
      }.compact!
      break if new_reachable_binds.empty?
      
      conditions = "collection_id IN " + new_reachable_binds.sql_in_condition{ |b| b.resource_id }

      new_reachable_binds = Bind.find(:all,
                                      :conditions => conditions,
                                      :select => "DISTINCT binds.*",
                                      :include => :child)
    end
    reachable_binds_with_path
  end

  def options
    super - %w(GET HEAD PUT VERSION-CONTROL) + %w(BIND UNBIND REBIND)
  end

  def empty?
    children.empty?
  end
  
  def take_snapshot
    desc_binds = descendant_binds

    descendants= Bind.child_resources(*desc_binds)

    {:desc_binds => desc_binds, :descendants => descendants}
  end

  private

  def copy_infinite_depth(target_pathname, snapshot, principal)
    # bind privilege check not necessary
    # as this method is private and
    # the target directory should have been
    # created by the principal

    target = Bind.locate(target_pathname)

    response = DavResponse::CopyWebdavResponse.new Status::HTTP_STATUS_MULTISTATUS

    # Step 1: get descendant binds
    desc_binds = snapshot[:desc_binds]

    # Step 2: get all descendant resources
    descendants = snapshot[:descendants]
 
    # Step 3: create copies of all descendants
    #         maintain hash of old resource -> ( new resource | error )
    copy_map = {}
    infinite_locks_on_target = target.locks.depth_infinity
    descendants.each do |d|
      begin
        Privilege.priv_read.assert_granted(d,principal)
        copy_map[d] = d.copy_to_new_resource(principal)
        copy_map[d].locks << infinite_locks_on_target
      rescue HttpError => e
        copy_map[d] = e
      end
    end

    # Step 4: add self => target to hash
    copy_map[self] = target

    # Step 4.5: recreate acl_parent structure
    #
    # if acl_parent is in the copied tree, then the acl_parent of
    # the new node will point to the copy of the acl_parent.
    # otherwise, acl_parent of new node is the same as that
    # of the old node

    descendants.each do |d|
      unless d.acl_parent.nil? or copy_map[d].kind_of?(HttpError)
        if copy_map.include?(d.acl_parent)
          copy_map[d].acl_parent = copy_map[d.acl_parent]
        else
          copy_map[d].acl_parent = d.acl_parent
        end
      end
    end

    # Step 5: recreate bind structure for new resources
    desc_binds.each do |b|
      if copy_map[b.parent].kind_of?(Resource) &&
          copy_map[b.child].kind_of?(Resource)
        # both successfully copied. create bind
        new_bind = Bind.new(:name => b.name,
                            :parent => copy_map[b.parent],
                            :child => copy_map[b.child])
        new_bind.save!
      end
    end

    # Step 7: prepare multistatus errors
    #
    # Create an error for every acyclic href that we failed to
    # create or were garbage collected, except for those that have
    # no parent that were successfully made
    #
    # We report error for every href instead of just every resource
    # so that a client cannot detect if two binds are to the same
    # resource.  (It's possible the error occurred because the
    # client does not have read access on the resource so
    # DAV:resource-id would also not be visible
    #
    # See discussion at
    # http://lists.w3.org/Archives/Public/w3c-dist-auth/2006OctDec/0000.html

    # only care to enter the loop if there are any errors
    if (copy_map.values.reject {|v| v.kind_of?(Resource)}).length > 0

      desc_binds.each do |b|
        begin
          dest_parent = copy_map[b.parent]

          # parent itself couldn't be created
          next unless dest_parent.kind_of?(Collection)

          dest_parent.reload
        rescue ActiveRecord::RecordNotFound
          next # parent was garbage collected
        end
        dest_child = copy_map[b.child]
        next unless dest_child.kind_of?(HttpError)

        Bind.find_all_acyclic_paths_between(self, b.child).each do |p|
          response.set_url_status(File.join(target_pathname, p),dest_child.status)
        end
      end
    end

    response.has_body? ? response : nil
  end

  public

  # COPY
  def copy(target_pathname, principal, depth = 'infinity',
           overwrite = true, *locktokens)
    response = nil
    logger.debug "COPY: DEPTH: #{depth}"
    Collection.transaction do
      begin
        inf_depth = depth.kind_of?(String) && depth.upcase == 'INFINITY'

        #Suspend garbage collection until we copy the snapshot
        Bind.with_garbage_collection_off do
          snapshot = nil
          snapshot = take_snapshot if inf_depth
          
          response = super(target_pathname, principal,
                           '0', overwrite, *locktokens)
          
          if inf_depth
            # yuck, in that we just created the target directory and now
            # we're locating it again inside copy_infinite_depth; but we
            # shouldn't be doing too many infinite depth copies and the
            # locate will take up only a small part of it
            infinite_response = copy_infinite_depth(target_pathname, snapshot, principal)
            response = infinite_response || response
          end
        end
        Bind.collect_garbage
      end
    end

    response
  end


  def resourcetype(xml)
    xml.D(:resourcetype){ xml.D :collection }
  end

  ## Locks

  # Check what all desendants have problem to be locked
  def check_descendants_lock_infinite_depth(principal, lockscope)
    error_map = {}

    descendants.each do |d|
      begin
        d.assert_lockable(principal, lockscope)
      rescue HttpError => e
        error_map[d] = e
      end
    end

    error_map
  end


  def lock_descendants_lock_infinite_depth(target_pathname, error_map, lock)
    response = nil

    # Lock resources if error_map is empty,
    # o/w create Multi-status response
    if error_map.empty?
      descendants.each do |d|
        d.locks << lock
      end

      # response set to Status::HTTP_STATUS_OK as all the locks
      # (direct + indirect) created.
      # body of Status::HTTP_STATUS_OK is set in Resource.lock
      response = DavResponse::LockWebdavResponse.new Status::HTTP_STATUS_OK

    else
      # response is multistatus due to error creating indirect lock
      response = DavResponse::LockWebdavResponse.new Status::HTTP_STATUS_MULTISTATUS

      # error is for each path, not for each resource
      # because of multiple binds to a resource.
      descendants.each do |d|
        error = error_map[d]
        next if error.nil?
        Bind.find_all_acyclic_paths_between(self, d).each do |path|
          response.set_url_status(File.join(target_pathname, path), error.status)
        end
      end

      # Add root collection url and status
      response.set_url_status(target_pathname, Status::HTTP_STATUS_FAILED_DEPENDENCY)
    end

    response
  end
  private :lock_descendants_lock_infinite_depth

  #     def lock(target_pathname, path_binds, options)
  #       # depth is default 'infinity' for collections
  #       options = { :depth => 'infinity' }.merge(options)

  #       response = nil
  #       error_map = {}
  #       lock_object = nil
  #       Collection.transaction do

  #         # Step 1: Check whether you can create lock on all the descendants.
  #         if options[:depth].downcase == "infinity"
  #           error_map = check_descendants_lock_infinite_depth(options)
  #         end

  #         # Step 2: Lock the top collection (directly locked resource).
  #         #         Call locable? to raise error if this collection
  #         #         cannot be locked.
  #         xml_request = options[:xmlrequest]
  #         assert_lockable(options[:principal], xml_request[Limeberry::LOCKSCOPE_ELEM])

  #         if error_map.empty?
  #           ret_array = super(target_pathname, path_binds, options)
  #           lock_object = ret_array[:lock]
  #         end

  #         # Step 3: Lock the descendants if error_map is empty
  #         #         o/w create multistatus response.
  #         #         Let response be nil if depth is '0',
  #         #         Resource.lock will take care of response
  #         if options[:depth].downcase == "infinity"
  #           response = lock_descendants_lock_infinite_depth(target_pathname, error_map, lock_object)
  #         end

  #         # Send back 1. lock
  #         # 2. response - Ok or Multistatus
  #         self.reload
  #         {:lock => lock_object, :response => response}
  #       end

  #     end


  def self.mkcol_p(path, principal)
    path.split('/').reject{ |c|
      c.blank?
    }.inject(Bind.root_collection) do |parent, name|
      col = parent.find_child_by_name name
      if col.nil?
        col = Collection.create!(:creator => principal)
        parent.bind_and_set_acl_parent(col, name, principal, false)
      elsif !col.instance_of? Collection
        raise MethodNotAllowedError
      end

      col
    end
  end
  
        

  # gets parent_collection for pathname
  # throws NotFoundError if parent_collection
  # does not exist or is not a collection
  def self.parent_collection(pathname)
    parent = Bind.locate(File.dirname(pathname))

    raise NotFoundError unless parent.instance_of?(Collection)
    parent
  end

  def self.parent_collection_raises_conflict(pathname)
    parent_collection(pathname)
  rescue NotFoundError
    raise ConflictError
  end
  

  def href(xml)
    if self == Bind.root_collection
      xml.D(:href, '/')
    else
      super
    end
  end

  private

  def self.init_liveprops
    liveprops_to_remove = Hash.new
    [ 'getcontentlanguage',
      'getcontentlength',
      'getcontenttype',
      'getetag',
      'getlastmodified' ].each do |name|
      liveprops_to_remove[PropKey.get('DAV:', name)] = true
    end


    @liveprops = superclass.liveprops.reject do |k, v|
      liveprops_to_remove[k]
    end

    @liveprops.freeze
  end

  init_liveprops

  def supported_privilege_names
    common_supported_privilege_names + %w( bind unbind )
  end

end

