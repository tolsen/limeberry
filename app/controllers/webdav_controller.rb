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

require 'errors'
require 'rexml/document'
require 'rexml_fixes'

#Note : incoming request headers are part of the env hash(HTTP_header_name)
class WebdavController < ApplicationController

  before_filter :assert_resource_found, :except => :mkcol

  #Webdav class 1 methods
  def propfind
    @resource.before_read_properties @principal
    
    reqxml = request.cgi.stdinput
    @propkeys = parse_propfind(reqxml)
    @paths = [path = Path.find_or_create_by_url(@path)].to_set

    @paths.merge(case @depth
                 when 0
                   []
                 when 1
                   path.create_children
                 when Limeberry::INFINITY
                   path.create_descendants
                 else
                   raise BadRequestError
                 end)
    
    # take out paths user cannot read
    denied_paths = @paths.find_all { |p|
      r = p.resource
      next false if r == @resource # already checked
      Privilege.priv_read.denied?(r, @principal)
    }.to_set

    # FIXME (and test)  shouldn't this be flattened??
    denied_path_descendants = denied_paths.map { |p| p.descendants }.to_set
    @paths -= (denied_paths + denied_path_descendants)
    
    render :status => 207
  end

  def proppatch
    @resource.before_write_properties @principal, *@if_locktokens
    
    @success_props = []
    
    # hash from HttpError to array of propkeys
    @failed_props = Hash.new{ |h, k| h[k] = [] }

    begin
      Resource.transaction do
        parse_proppatch(request.cgi.stdinput) do |action, element|
          pk = element.propkey
          begin
            case action
            when :set then @resource.proppatch_set_one(element)
            when :remove then @resource.proppatch_remove_one(pk)
            end
            @success_props << pk
          rescue HttpError => e
            @failed_props[e] << pk
          end
        end

        # rollback if there are any failed props
        raise FailedDependencyError unless @failed_props.empty?
        
      end
    rescue FailedDependencyError => e
      # if any failed, then all successful props
      # become failed dependencies
      unless @success_props.empty?
        @failed_props[e].push(*@success_props) 
        @success_props.clear
      end
    end

    @success_props.uniq!
    render :status => 207
  end

  def mkcol
    #raise unsupported media type error if the request contains a body
    #MKCOL with weird body must fail (RFC2518:8.3.1)
    raise UnsupportedMediaTypeError unless request.cgi.stdinput.length == 0
    parent = Collection.parent_collection_raises_conflict @path

    Collection.transaction do
      if @resource.nil?
        bind_name = File.basename(@path)
        # permissions checked in Collection#bind
        collection = Collection.create!(:creator => @principal)
        parent.bind_and_set_acl_parent(collection, bind_name,
                                       @principal, false, *@if_locktokens)
      else
        @resource.mkcol(@principal, *@if_locktokens)
      end
    end

    render :nothing => true, :status => 201
  end

  def copy
    status = nil
    @error2urls = Hash.new{ |h, k| h[k] = [] }
    
    Resource.transaction do
      copy_map = {}
      snapshot = nil
      @resource.before_read @principal
      
      begin
        copy_move_prepare
        Bind.with_garbage_collection_off do
          snapshot = @resource.take_snapshot if
            @resource.is_a?(Collection) && @depth.infinite?

          if @dest.nil?
            # dest does not exist
            # lock on parent checked in bind
            @dest = @resource.copy_to_new_resource(@principal)
            status = 201
            @dest_parent.bind_and_set_acl_parent(@dest, @dest_basename,
                                                @principal, true,
                                                *@if_locktokens)
          else
            raise PreconditionFailedError unless @overwrite
            @dest.before_write @principal, *@if_locktokens

            status = 204

            if @resource.instance_of?(@dest.class)
              @resource.copy_over_existing_resource(@dest, @principal, *@if_locktokens)
            else
              # copying over different resource type. We can do a delete first. See
              # http://lists.w3.org/Archives/Public/w3c-dist-auth/2006JulSep/0070.html

              # FIXME???  maybe we should be keeping the same resource-id
              # and/or have all prior binds still intact (to new resource
              # -- if not keeping resource-id

              # Locks will be transferred and the old dest will be unbound when bind is called.
              @dest = @resource.copy_to_new_resource(@principal)

              @dest_parent.bind_and_set_acl_parent(@dest, @dest_basename,
                                                  @principal, true,
                                                  *@if_locktokens)
            end
          end

          if @depth.infinite? && @resource.is_a?(Collection)
            copy_map = copy_infinite_depth(@dest, snapshot[:desc_binds], snapshot[:descendants])
          end
        end
      rescue HttpError => e
        # multistatus if error is not on Request-URI
        raise if e.resource.nil? or e.url == @path
        @error2urls[e] << e.url
      end

      Bind.collect_garbage
      generate_copy_errors(copy_map, snapshot[:desc_binds]) if
        copy_map.any? {|k, v| v.kind_of? HttpError }
    end
    
    if @error2urls.empty?
      render :nothing => true, :status => status
    else
      render :status => 207
    end
    
  end

  def move
    status = nil
    Collection.transaction do
      copy_move_prepare
      raise MethodNotAllowedError if @resource.is_a? LockNullResource
      status = @dest_parent.rebind @dest_basename, @path, @principal, @overwrite, *@if_locktokens
    end

    if status == Status::HTTP_STATUS_OK
      render :nothing => true, :status => 204
    else
      render :nothing => true, :status => status.code
    end
  rescue HttpError => @error
    raise if @error.resource.nil? or @error.url == @path
    render :status => 207
  end

  private

  # yields action, REXML::Element for each child of <prop>
  # action is :set or :remove
  def parse_proppatch(reqbody)
    root = REXML::Document.new(reqbody).root
    raise BadRequestError unless (root.namespace == 'DAV:' and root.name == 'propertyupdate')
    root.each_element do |e|
      next unless (e.name =~ /^set|remove$/ and e.namespace == 'DAV:') #Move to the next element if this element is not a set or remove element
      action = e.name.to_sym
      propfound = false
      e.each_element do |f|
        next unless (f.namespace == 'DAV:' and f.name == 'prop')
        raise BadRequestError if propfound or !f.has_elements?
        propfound = true
        f.each_element { |g| yield action, g }
      end
      raise BadRequestError unless propfound
    end
  rescue REXML::ParseException
    raise BadRequestError
  end


  # returns :allprop, :propname, or list of propkeys
  def parse_propfind(reqxml)
    return :allprop if [:eof?, :empty?].any?{|tst|reqxml.respond_to?(tst) && reqxml.send(tst)}

    root = REXML::Document.new(reqxml).root;
    raise BadRequestError if root.nil? || root.name != 'propfind' || root.namespace != 'DAV:'
    propelem = nil
    root.each_element { |e|
      if e.namespace == 'DAV:' and e.name =~ /^prop|allprop|propname$/
        raise BadRequestError unless propelem.nil? #Only one of the three elements(prop, propname or allprop) should be present
        propelem = e
      end
    }
    raise BadRequestError if propelem.nil? #Atleast one of the three elments should be present

    return :allprop if propelem.name == 'allprop'
    return :propname if propelem.name == 'propname'

    raise BadRequestError if propelem.elements.empty?
    
    return propelem.elements.map { |e| PropKey.get(e.namespace, e.name) }
    
  rescue REXML::ParseException => e
    logger.debug e.backtrace.join("\n")
    raise BadRequestError
  end

  def copy_move_prepare
    @dest_path = validate_and_trim_full_url @destination

    if @depth.nil?
      @depth = Limeberry::INFINITY
    elsif !(@depth.zero? or @depth.infinite?)
      raise BadRequestError
    end

    @dest_parent = Collection.parent_collection_raises_conflict(@dest_path)

    @dest_basename = File.basename(@dest_path)
    @dest = @dest_parent.find_child_by_name(@dest_basename)
  end
  
  
  def copy_infinite_depth(dest, desc_binds, descendants)
    # create copies of all descendants
    # maintain hash of old resource -> ( new resource | error )
    copy_map = {}
    infinite_locks_on_dest = dest.locks.depth_infinity
    descendants.each do |d|
      begin
        Privilege.priv_read.assert_granted(d,@principal)
        copy_map[d] = d.copy_to_new_resource(@principal)
        copy_map[d].locks << infinite_locks_on_dest
      rescue HttpError => e
        copy_map[d] = e
      end
    end

    # add @resource => dest to hash
    copy_map[@resource] = dest

    # recreate acl_parent structure
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

    # recreate bind structure for new resources
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

    copy_map
  end

  def generate_copy_errors(copy_map, desc_binds)
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
    desc_binds.each do |b|
      begin
        dest_parent = copy_map[b.parent]

        # parent itself couldn't be created
        next unless dest_parent.kind_of?(Collection)

        dest_parent.reload
      rescue ActiveRecord::RecordNotFound
        next # parent was garbage collected
      end
      e = copy_map[b.child]
      next unless e.kind_of?(HttpError)

      Bind.find_all_acyclic_paths_between(@resource, b.child).each do |p|
        url = File.join((e.resource == b.child ? @path : @dest_path), p)
        @error2urls[e] << url
      end
    end
  end
    
end
