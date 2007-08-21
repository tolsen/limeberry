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
require 'dav_xml_builder'

class Group < Principal

  has_and_belongs_to_many(:members, :class_name => "PrincipalRecord",
                          :join_table => "membership",
                          :association_foreign_key => "member_id")

  has_and_belongs_to_many(:transitive_members,
                          :class_name => "PrincipalRecord",
                          :join_table => "transitive_membership",
                          :foreign_key => "group_id",
                          :association_foreign_key => "member_id")


  unless defined?(GROUPS_COLLECTION_PATH)
    GROUPS_COLLECTION_PATH = "/groups"
  end

  def self.groups_collection_path
    GROUPS_COLLECTION_PATH
  end

  def self.groups_collection
    Bind.locate(GROUPS_COLLECTION_PATH)
  end

  def self.recreate_closure

    connection.execute("delete from transitive_membership;")
    connection.execute("insert into transitive_membership select * from membership;")

    #### get all the nodes ... to build the adjacency matrix
    nodes = find_by_sql("select distinct(group_id) from membership;" )

    for node in nodes
      k = find(node.group_id)

      member_list = k.transitive_members
      parent_list = k.transitive_groups

      next if parent_list.empty?
      for parent in parent_list
        parent_member_list = parent.transitive_members
        new_member_list = member_list - parent_member_list
        for new_member in new_member_list
          parent.transitive_members << new_member
          parent.save!
        end
      end
    end
  end

  def update_closure
    Group.recreate_closure
    reload
  end


  def add_member principal
    raise RecordInvalid unless self.members << principal.principal_record
    update_closure
  end

  def remove_member principal
    members.delete(principal.principal_record)
    update_closure
  end

  def has_member? principal
    transitive_members.reload.include? principal.principal_record
  end

  def self.all
    find_by_name("all")
  end

  def self.authenticated
    find_by_name("authenticated")
  end


  # options: name (required)
  #          creator (defaults to limeberry)
  #          owner (defaults to creator)
  #          displayname
  #          quota (default 0)
  def self.make(options)
    self.transaction do
      resource_options = { :displayname => options[:displayname] }
      resource_options[:creator] = options[:creator] if options[:creator]
      resource_options[:owner] = options[:owner] if options[:owner]

      group = create!(resource_options)
      PrincipalRecord.create!(:name => options[:name],
                              :total_quota => options[:quota] || 0,
                              :principal => group)
      group
    end
  end

  def after_proxied_create
    super
    Group.groups_collection.bind(self, name, Principal.limeberry)
    #Privilege.priv_all.grant(self, self.creator, true)
  end

  # PUT Group (create or modify Group)
  def self.put(options)
    group = find_by_name(options[:name])
    if group.nil?
      make(options)
      response = DavResponse::PutWebdavResponse.new Status::HTTP_STATUS_CREATED
      return response
    end

    self.transaction do
      group.displayname=options[:displayname] if !options[:displayname].nil?
      group.owner=options[:owner] if !options[:owner].nil?
      group.save!
      response=DavResponse::PutWebdavResponse.new Status::HTTP_STATUS_NO_CONTENT
      return response
    end
  end

  @liveprops = { PropKey.get('DAV:', 'group-member-set') =>
    LiveProps::LivePropInfo.new(:group_member_set, false, false)
  }.merge(superclass.liveprops).freeze

  def group_member_set(xml)
    members.each { |m| m.principal_url(xml) }
  end

  def group_member_set=(options)
    # Do we really want to have XML parsing in Models. 
    # Currently the following request works. - 
    # g.proppatch_set_one("DAV:","group-member-set","<D:group-member-set xmlns:D='DAV:'><D:href>/users/user</D:href><D:href>/users/user1</D:href></D:group-member-set>")
    document = REXML::Document.new options 
    result = Array.new
    root = document.root
    raise BadRequestError unless (root.namespace == 'DAV:' and root.name == 'group-member-set') # Need to decide this. 
    
    transaction do 
      members.clear
      root.each_element {|e|
        if (e.namespace == 'DAV:' and e.name == 'href')
          user = Bind.locate(e.text)
          raise NotFoundError if user.nil?  
          self.members << user.principal_record
        elsif (e.name != 'href')
          raise BadRequestError
        end
      }
      
      update_closure
    end 
  rescue REXML::ParseException
    raise BadRequestError
  end

  def principal_url(xml)
    if self == Group.all
      xml.D(:all)
    elsif self == Group.authenticated
      xml.D(:authenticated)
    else
      xml.D(:href, File.join(GROUPS_COLLECTION_PATH, self.name))
    end
  end


end

