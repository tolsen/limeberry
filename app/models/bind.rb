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

require 'enumerator'
require 'errors'
require 'generator'
require 'set'
require 'utility'

class Bind < ActiveRecord::Base
  numbers = "0123456789"
  alphabet = "abcdefghijklmnopqrstuvwxyz"
  @@allowed_chars = numbers + alphabet + alphabet.upcase + "._~!$&'()*+,;=:@-"

  before_validation :normalize_name
  before_destroy { |b| b.locks.destroy_all }
  before_update { |b| b.paths.destroy_all }
  after_destroy { Bind.collect_garbage }

  validates_uniqueness_of :name, :scope => :collection_id
  validates_length_of :name, :in => 1..1024
  validates_exclusion_of :name, :in => [ '.', '..' ]
  validates_format_of :name, :with => /^([#{@@allowed_chars}]|(%[0-9A-F]{2}))+$/

  belongs_to :parent, :class_name => "Collection", :foreign_key => "collection_id"
  belongs_to :child, :class_name => "Resource", :foreign_key => "resource_id"

  # Join table of binds and locks
  # For keeping track of binds along a lock's lockroot
  has_and_belongs_to_many(:locks,
                          :join_table => "lockroot_binds",
                          :conditions => "expires_at > now()")

  has_many :paths, :dependent => :destroy

  def normalize_name
    self.name = self.class.normalize_name(self.name) unless self.name.nil?
  end

  def self.normalize_name(name)
    name.gsub(/%([0-9A-Fa-f]{2})/) do |match|
      charcode = $1.to_i(16)
      if @@allowed_chars.include? charcode
        charcode.chr
      else
        $&.upcase
      end
    end
  end
  
  @@garbage_level = 0
  def self.with_garbage_collection_off
    @@garbage_level += 1
    yield
  ensure
    @@garbage_level -= 1
  end
  
  def self.garbage_collection_on?
    @@garbage_level == 0
  end
  
  @@collect_garbage_again = false
  # Thread safety and optimization yet to be done
  def self.collect_garbage
    unless garbage_collection_on?
      @@collection_garbage_again = true
      return
    end

    # TODO: instantiating all these objects is expensive. just pass around ids!
    with_garbage_collection_off do
      LockNullResource.with_stale_ok do
        reachable_resources = Bind.root_collection.descendants.to_set << Bind.root_collection
        all_resources = Resource.find(:all).to_set
        orphaned_resources = all_resources - reachable_resources
        
        logger.debug("collecting garbage: " + (orphaned_resources.inject(""){|str, r| str + "#{r.id} "}))

        # deletion of any record can cause a cascade of deletion of
        # binds and more records.  We reload each orphaned_resource
        # in case it gets deleted out from under us, in which case
        # we ignore the RecordNotFound exception
        #
        # some cascading of deletions is cut down by only running
        # the meat of this method once
        orphaned_resources.each do |r|
          begin
            r.reload.destroy
          rescue ActiveRecord::RecordNotFound
          end
        end

        Body.destroy_nulled
      end
    end
    # If collect garbage had been called when the above code ran,
    # that would mean that it's possible some new resources were orphaned.
    # These have to be garbage collected
    if @@collect_garbage_again
      @@collect_garbage_again = false
      collect_garbage
    end
  end

  ROOT_COLLECTION_UUID = "49421d7c1eae44c3b8a74eb61ebc5cc6"
  def self.root_collection
    @@root = Resource.find_by_uuid(ROOT_COLLECTION_UUID) unless defined? @@root
    @@root.reload
  end

  def self.locate path
    logger.debug "PATH: #{path}"

    bindings = path.is_a?(Array) ? path : path.split('/')
    bindings.reject! { |b| b.blank? }
    pathname = '/'  + bindings.join('/')
      

    parent = root_collection
    raise "root_collection was nil" if parent.nil?

    resource = nil

    if bindings.empty?
      resource = root_collection
      resource.path_binds = []
      resource.url = '/'
      return resource
    end

    size = bindings.size

    # Create a query that similar to this:
    # SELECT ids.cnt, b.id, b.name, b.collection_id, b.resource_id, MAX(b.updated_at) updated_at
    # FROM (SELECT cnt,
    #       CASE
    #         WHEN cnt = 1 THEN id1
    #         WHEN cnt = 2 THEN id2
    #         WHEN cnt = 3 THEN id3
    #         WHEN cnt = 4 THEN id4
    #         WHEN cnt = 5 THEN id5
    #         ELSE NULL
    #       END cnt_id
    #      FROM (SELECT 1 cnt UNION ALL
    #            SELECT 2 cnt UNION ALL
    #            SELECT 3 cnt UNION ALL
    #            SELECT 4 cnt UNION ALL
    #            SELECT 5 cnt) cnts
    #          CROSS JOIN
    #          (SELECT b1.id id1, b2.id id2, b3.id id3, b4.id id4, b5.id id5
    #           FROM binds b1
    #           INNER JOIN binds b2
    #           ON b1.resource_id = b2.collection_id
    #           INNER JOIN binds b3
    #           ON b2.resource_id = b3.collection_id
    #           INNER JOIN binds b4
    #           ON b3.resource_id = b4.collection_id
    #           INNER JOIN binds b5
    #           ON b4.resource_id = b5.collection_id
    #           WHERE b1.collection_id = 2 AND
    #             b1.name = "a" AND
    #             b2.name = "b" AND 
    #             b3.name = "c" AND 
    #             b4.name = "d" AND
    #             b5.name = "e") segments) ids
    # INNER JOIN binds b
    # ON ids.cnt_id = b.id
    # GROUP BY ids.cnt WITH ROLLUP;

    
    sql =
      "SELECT ids.cnt, b.id, b.name, b.collection_id, b.resource_id, MAX(b.updated_at) updated_at\n" +
      "FROM (SELECT cnt, \n" +
      "CASE " + (1..size).map{|n| "WHEN cnt = #{n} THEN id#{n} "}.join + "ELSE NULL END cnt_id\n" +
      "FROM (" + (1..size).map{|n| "SELECT #{n} cnt"}.join(' UNION ALL ') + ") cnts \n" +
      "CROSS JOIN" +
      "(SELECT " + (1..size).map{|n| "b#{n}.id id#{n}"}.join(', ') + " FROM binds b1\n" +
      (2..size).map{|n| "INNER JOIN binds b#{n} ON b#{n-1}.resource_id = b#{n}.collection_id"}.join(' ') +
      "\n WHERE b1.collection_id = 2 AND " +
      (1..size).map{|n| "b#{n}.name = '#{bindings[n-1]}'"}.join(' AND ') + ") segments) ids \n" +
      "INNER JOIN binds b ON ids.cnt_id = b.id GROUP BY ids.cnt WITH ROLLUP"

    logger.debug(sql)
    binds = Bind.find_by_sql(sql)
    raise NotFoundError, "Could not locate #{pathname}" if binds.empty?

    # MySQL will automatically sort when given a GROUP BY
    # (in this case on ids.cnt)
    # this way we know the first size results are the bindings in order
    # the last result has the maximum updated_at

    resource = Resource.find binds[-2].resource_id

    resource.url_lastmodified = binds[-1].updated_at
    resource.path_binds = binds[0..-2]
    resource.url = pathname
    resource
  rescue StaleLockNullError
    raise NotFoundError
  end

  def self.exists? binding
    Bind.locate binding
    true
  rescue NotFoundError
    false
  end

  # returns an array of paths (strings)

  def self.find_all_acyclic_paths_between(collection, resource)
    find_acyclic_paths_between(collection, resource)
  end

  def self.find_all_acyclic_paths_to(resource)
    find_all_acyclic_paths_between(root_collection, resource).map{ |p| "/#{p}" }
  end

  def self.find_any_acyclic_path_between(collection, resource)
    singleton_path = find_acyclic_paths_between(collection, resource, false)
    singleton_path.empty? ? "" : singleton_path[0]
  end

  def self.find_any_acyclic_path_to(resource)
    "/#{find_any_acyclic_path_between(root_collection, resource)}"
  end

  # iterates over ancestors, yielding a set of new ancestors
  # repeatedly until no new ones are found
  def self.iterate_ancestors(*binds, &block)
    binds_seen = binds.to_set

    while true
      new_binds = parents(*binds) - binds_seen
      break if new_binds.empty?
      yield new_binds
    end
  end

  def locks_impede_bind_deletion?(principal, *locktokens)
    locks.map{ |l| l.resource }.uniq.any? do |r|
      r.locks_impede_modify? principal, *locktokens
    end
  end

  def self.parents(*binds)
    return [] if binds.empty?
    binds_str = binds.sql_in_condition { |bind| bind.collection_id }
    Bind.find(:all,
              :conditions => "resource_id IN #{binds_str}",
              :select => "DISTINCT *")
  end
  
  def self.children(*binds)
    return [] if binds.empty?

    binds_str = binds.sql_in_condition { |bind| bind.resource_id }

    Bind.find(:all,
              :conditions => "collection_id IN #{binds_str}",
              :select => "DISTINCT *",
              :include => :child)
  end

  def self.descendants(*binds)
    desc = [].to_set
    new_desc = children(*binds).to_set

    until desc.size == new_desc.size
      desc = new_desc
      new_desc += children(*desc)
    end

    desc
  end
  

  def self.child_resources(*binds)
    (binds.map { |b| b.child }).uniq
  end
  

  def self.binds_name_intersection(binds1, binds2)
    return [] if binds1.empty? || binds2.empty?

    binds1_str = binds1.sql_in_condition
    binds2_str = binds2.sql_in_condition

    Bind.find(:all, :select => 'b1.id bind1, b2.id bind2',
              :joins => 'AS b1 INNER JOIN binds AS b2',
              :conditions =>
              "b1 IN #{binds1.sql_in_condition}" +
              " AND b2 IN #{binds2.sql_in_condition}" +
              " AND b1.name = b2.name")


  end

  private

  # returns list of bindpath reachable from list of binds
  # a bindpath is a list of binds in order
  def self.descendant_bindpaths(binds, binds_seen = [].to_set)
    return [] if binds.empty?

    binds_seen += binds

    binds_str = binds.sql_in_condition
    binds_seen_str = binds_seen.sql_in_condition

    bindpairs = Bind.find(:all,
                          :select => 'b1.* child, b2.* parent',
                          :joins =>
                          'AS b1 INNER JOIN binds AS b2' +
                          ' ON b1.collection_id = b2.resource_id',
                          :conditions =>
                          "b2.id IN #{binds_str}" +
                          " AND b1.id NOT IN #{binds_seen_str}",
                          :order => 'b1.resource_id, b1.collection_id')


    

    bindpaths = childbinds

    childbindpaths = descendant_bindspaths(childbinds, binds_seen)

    # both childbinds and childsubpaths should already be sorted
    childbindpath_generator = Generator.new childbindpaths

    # now join
    unless childbindpath_generator.end?
      childbinds.each do |childbind|

        while childbind_regex.match(childbindpath_generator.current)
          bindpaths << "#{childbind.parent_name}/#{childbindpath_generator.next}"
          break if childbindpath_generator.end?
        end
        break if childbindpath_generator.end?
      end
    end
    
    bindpaths 
  end
  
  def self.find_acyclic_paths_between(collection, resource, all = true, resources_seen = [collection].to_set)
    paths = []

    # go through all parentbinds looking for
    #  1. any binds to the collection we're looking for
    #     if found, prefix the bind names to paths
    #  2. any new parents to search

    #new_resources_seen is the set of resources that have already been seen before
    #this iteration + resources_seen in this iteration
    new_resources_seen = resources_seen + resource.parents
    
    resource.binds.each do |b|
      parent_resource = b.parent

      if parent_resource == collection
        # found a new path to the collection
        paths << b.name
        return paths unless all
        next
      elsif resources_seen.include?(parent_resource)
        # don't follow back-edges (avoid cycles)
        next
      else
        paths += find_acyclic_paths_between(collection, parent_resource, all,
                                            new_resources_seen).map do |subpath|
          File.join(subpath, b.name)
        end
      end
    end
    paths
  end
  
end
