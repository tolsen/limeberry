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

require 'rexml/document'
require 'stringio'

require 'test/test_helper'
require 'test/unit/dav_unit_test'

require 'errors'
require 'if_header'

require 'test/xml'

class ResourceTest < DavUnitTestCase

  def setup
    super
    @collectionpath = "/dir"
    @src_content = "content"
    @resourcepath = "/dir/src"

    @collection = Bind.locate(@collectionpath)
    @resource = Bind.locate(@resourcepath)

    @joe = User.find_by_name('joe')

    @pk1 = PropKey.get("randomns1", "randomname1")
    @pk2 = PropKey.get("randomns2", "randomname2")
  end

  def test_acl_grandparent_adopts_grandchild
    r1, r2, r3 = resources_without_acl_parent(3)

    r2.acl_parent = r1
    r3.acl_parent = r2

    r1.acl_node.reload
    r3.acl_parent = r1

    [r1, r2, r3].each { |r| assert_not_nil(r.reload.acl_node) }

    assert_equal(r1, r2.acl_parent)
    assert_equal(r1, r3.acl_parent)
  end

  def test_acl_inheritance
    g1 = Group.make(:name => "group1")
    g1.add_member(@joe)
    r1 = Resource.create!(:creator => g1)
    r2 = Resource.create!(:creator => @limeberry)
    r3 = Resource.create!(:creator => @limeberry)
    r2.acl_parent= r1
    r3.acl_parent= r2
    assert Privilege.priv_all.granted?(r2,g1)
    assert Privilege.priv_all.granted?(r3,g1)
    assert Privilege.priv_all.granted?(r1,@joe)
    assert Privilege.priv_all.granted?(r2,@joe)
    assert Privilege.priv_all.granted?(r3,@joe)
  end

  def test_acl_node_changes_parent
    r1, r2, r3, r4 = resources_without_acl_parent(4)

    r2.acl_parent = r1
    r4.acl_parent = r3

    r4.acl_parent = r1

    [r1, r2, r4].each { |r| assert_not_nil(r.reload.acl_node) }

    assert_nil(r3.reload.acl_node)

    assert_equal(r1, r2.acl_parent)
    assert_equal(r1, r4.acl_parent)
  end

  def test_acl_node_children_die_with_parent
    r1, r2, r3 = resources_without_acl_parent(3)

    r2.acl_parent = r1
    r3.acl_parent = r1

    a1 = r1.acl_node
    r1.destroy

    assert_raise(ActiveRecord::RecordNotFound) do
      AclNode.find(a1.id)
    end

    assert_nothing_raised do
      r2.reload
      r3.reload
    end

    assert_nil(r2.acl_node)
    assert_nil(r3.acl_node)
  end

  def test_acl_node_initially_nil
    r1 = resources_without_acl_parent(1)[0]
    assert_nil(r1.acl_node)
  end

  def test_acl_parent_already_in_tree
    r1, r2, r3 = resources_without_acl_parent(3)

    r2.acl_parent = r1
    r3.acl_parent = r2

    [r1, r2, r3].each { |r| assert_not_nil(r.reload.acl_node) }
    assert_equal(r2, r3.acl_parent)
  end

  def test_acl_parent_not_yet_in_tree
    r1, r2 = resources_without_acl_parent(2)


    r2.acl_parent = r1

    assert_not_nil(r1.acl_node)
    assert_not_nil(r2.acl_node)

    assert_equal(r1, r2.acl_parent)
    assert_nil(r1.acl_parent)
    assert(r1.acl_node.children.include?(r2.acl_node))
  end

  def test_etag
    assert_equal @resource.body.sha1, @resource.etag
  end

  def test_etag_no_body
    res_no_body = Resource.create!
    assert_raise(NotFoundError) { res_no_body.etag }
  end

  def test_locked_with
    lock = create_lock("/", @limeberry, 'X', '0')
    assert !(Bind.root_collection.locked_with?("randomtoken"))
    assert (Bind.root_collection.locked_with?(lock.uuid))
  end

  def test_getcontentlanguage
    setup_xml
    assert_raise(NotFoundError) do
      @collection.getcontentlanguage(@xml)
    end

    cl = @resource.body.contentlanguage
    assert_liveprop_direct_method_equal(:getcontentlanguage,
                                        "getcontentlanguage",
                                        cl)
  end

  def test_getcontentlanguage_set
    assert_raise(NotFoundError) do
      @collection.getcontentlanguage = 'te'
    end

    @resource.getcontentlanguage = 'te'
    assert_equal 'te', @resource.body.contentlanguage

    assert_liveprop_direct_method_equal(:getcontentlanguage,
                                        "getcontentlanguage",
                                        'te')
  end

  def test_getcontentlength
    setup_xml
    assert_raise(NotFoundError) { @collection.getcontentlength(@xml) }
    setup_xml
    @resource.getcontentlength(@xml)
    assert_rexml_equal("<D:getcontentlength xmlns:D='DAV:'>#{@src_content.size}</D:getcontentlength>", @xml_out)
  end

  def test_copy_resource_over_collection
    Collection.mkcol_p("/newdir", @limeberry)
    Privilege.priv_read.grant(@resource,@joe)
    Privilege.priv_bind.grant(Bind.root_collection,@joe)
    assert_raise(ForbiddenError) {
      Resource.copy(@resourcepath,"/newdir", @joe)
    }

    Privilege.priv_unbind.grant(Bind.root_collection,@joe)
    Resource.copy(@resourcepath,"/newdir", @joe)

    destination = Bind.locate("/newdir")
    assert(destination.is_a?(Resource))
    #  ensure
    #    Bind.locate("/newdir").destroy rescue StandardError
  end

  def test_copy_target_locks
    Collection.mkcol_p("/b", @limeberry)
    lock = create_lock("/b")

    assert_raise(LockedError) {
      Resource.copy("/dir/src","/b/src", @limeberry)
    }
    assert_nothing_raised() {
      Resource.copy("/dir/src","/b/src", @limeberry, 'I', true, lock.uuid)
    }
    assert(Bind.locate("/b/src").locked?)
  end

  def test_creator_displayname
    assert_liveprop_direct_method_equal(:creator_displayname,
                                        "creator-displayname",
                                        @limeberry.displayname)
  end
  
  def test_dav_resource_id_does_not_alter_uuid
    foo = Bind.locate("/dir/src")

    uuid1 = foo.uuid.clone
    setup_xml
    urn = foo.dav_resource_id(@xml)
    uuid2 = foo.uuid.clone

    assert_equal(uuid1, uuid2)
  end

  def test_default_priv
    p = Principal.make(:name => "Brazil")
    r = Resource.create!(:creator => p,
                         :displayname => "World Cup Winners")

    r.reload
    Privilege.priv_all.granted?( r, p )
  end

  def test_descendant_binds
    assert_equal(0, @resource.descendant_binds.size)
  end

  def test_getetag
    setup_xml
    assert_raise(NotFoundError) { @collection.getetag(@xml) }

    assert_liveprop_direct_method_equal(:getetag, "getetag",
                                        "\"#{@resource.etag}\"")
  end


  def test_find_by_dav_resource_id
    urn = Utility.uuid_to_urn(@resource.uuid)
    assert_equal @resource, Resource.find_by_dav_resource_id(urn)
  end

  def test_properties_find_by_propkey
    random_pk = PropKey.get("randomns1", "randomname1")
    prop = @resource.properties.find_by_propkey(random_pk)
    assert_equal "randomns1", prop.namespace.name
    assert_equal "randomname1", prop.name
    assert_equal "<N:randomname1 xmlns:N='randomns1'>randomvalue1</N:randomname1>", prop.value
  end

  def test_url
    assert_equal "/", @root.url
    assert_equal "/dir", @collection.url
    assert_equal "/dir/src", @resource.url
  end

  def test_getlastmodified
    sleep 1 unless @resource.created_at < Time.now
    @root.bind @resource, 'src', @limeberry
    assert_two_resources_lpdm_not_equal(Bind.locate("/dir/src"),
                                        Bind.locate("/src"),
                                        :getlastmodified)
    assert_two_resources_lpdm_equal(@resource,
                                    Bind.locate("/dir/src"),
                                    :getlastmodified)
    
    src = util_put('/dir/src', '012345')
    src.body.created_at += 1

    assert_two_resources_lpdm_equal(Bind.locate("/dir/src"),
                                    Bind.locate("/src"),
                                    :getlastmodified)
    
    assert_two_resources_lpdm_not_equal(@resource,
                                        Bind.locate("/dir/src"),
                                        :getlastmodified)
  end

  def test_liveprops
    Resource.send(:liveprops).each_pair do |k, v|
      assert_instance_of(PropKey, k)
      assert_instance_of(LiveProps::LivePropInfo, v)
    end
    assert_instance_of(LiveProps, Resource.create!.liveprops)
  end

  def test_acl
    Privilege.priv_read_acl.grant(@resource, @joe)
    Bind.locate("/dir").acl_parent = nil

    expected = <<EOS
<D:ace>
  <D:principal>
    <D:property><D:owner/></D:property>
  </D:principal>
  <D:grant>
    <D:privilege><D:all/></D:privilege>
  </D:grant>
  <D:protected/>
</D:ace>
<D:ace>
  <D:principal>
    <D:href>/users/joe</D:href>
  </D:principal>
  <D:grant>
    <D:privilege><D:read-acl/></D:privilege>
  </D:grant>
</D:ace>
<D:ace>
  <D:principal>
    <D:property><D:owner/></D:property>
  </D:principal>
  <D:grant>
    <D:privilege><D:all/></D:privilege>
  </D:grant>
  <D:protected/>
  <D:inherited>
    <D:href>/dir</D:href>
  </D:inherited>
</D:ace>
EOS
    assert_liveprop_direct_method_equal(:acl, "acl", expected)
  end

  def test_locks_impede_modify
    assert !@collection.locks_impede_modify?(@limeberry)

    l0 = create_lock(@collectionpath)

    assert @collection.reload.locks_impede_modify?(@limeberry)
    assert !@collection.locks_impede_modify?(@limeberry, "asd", l0.uuid, "qwe")
    assert @collection.locks_impede_modify?(@joe, "asd", l0.uuid, "qwe")
  end

  def test_make_resource_defaults
    resource = Resource.create!(:creator => @limeberry,
                                :displayname => "test resource")
    assert_instance_of( Resource, resource )
    assert_match( /^[0-9A-Fa-f]{32}$/, resource.uuid )
    assert_equal( @limeberry, resource.creator )
    assert_equal( @limeberry, resource.owner )
    assert( @limeberry.owned_resources.include?( resource ))
    assert( @limeberry.created_resources.include?( resource ))
    assert_equal("", resource.comment)
    assert_equal( "test resource", resource.displayname )
  end

  def test_make_resource_fully_specified
    creator = Principal.make(:name => "test_creator")
    owner = Principal.make(:name => "test_owner")
    resource = Resource.create!(:creator => creator,
                                :owner => owner,
                                :displayname => "test resource",
                                :comment => "test comment",
                                :uuid => "0123456789abcdef0123456789abcdef")

    assert_instance_of( Resource, resource )
    assert_equal( "0123456789abcdef0123456789abcdef",
                  resource.uuid )
    assert_equal( creator, resource.creator )
    assert_equal( owner, resource.owner )
    assert( owner.owned_resources.include?( resource ))
    assert( creator.created_resources.include?( resource ))
    assert_equal( "test comment", resource.comment )
    assert_equal( "test resource", resource.displayname )
    assert Privilege.priv_all.granted?(resource, owner)
    assert !Privilege.priv_all.granted?(resource, creator)
  end

  def test_getcontenttype
    setup_xml
    assert_raise(NotFoundError) { @collection.getcontenttype(@xml) }
    
    assert_liveprop_direct_method_equal(:getcontenttype, "getcontenttype",
                                        "text/plain")
  end

  def test_modified_since
    t1 = Time.now - 1
    foo = util_put('/foo', 'arbit')
    t2 = Time.now + 1

    assert foo.modified_since?(t1)
    assert !foo.modified_since?(t2)
  end

  def test_options
    expected_options = %w(GET HEAD OPTIONS DELETE PUT PROPFIND PROPPATCH COPY MOVE LOCK UNLOCK VERSION-CONTROL ACL).sort
    assert_equal(expected_options, @resource.options.sort)
  end


  def test_options_locked
    create_lock("/dir/src")
    expected_options = %w(GET HEAD OPTIONS DELETE PUT PROPFIND PROPPATCH COPY MOVE LOCK VERSION-CONTROL UNLOCK ACL).sort
    assert_equal(expected_options, @resource.options.sort)
  end

  def test_orphan_acl_node_is_nil
    r1 = resources_without_acl_parent(1)[0]
    assert_nil(r1.acl_node)
    assert_nothing_raised { r1.orphan_acl }
    assert_nil(r1.acl_node)
  end

  def test_orphan_acl_with_children
    r1, r2 = resources_without_acl_parent(2)

    r1.acl_parent = Bind.root_collection
    r2.acl_parent = r1

    r1.acl_parent = nil

    assert_not_nil(r1.acl_node)
    assert_nil(r1.acl_parent)
    assert_not_nil(r2.acl_node)
    assert_equal(r1, r2.acl_parent)
  end

  def test_orphan_acl_without_children
    r1 = resources_without_acl_parent(1)[0]
    r1.acl_parent = Bind.root_collection
    r1.acl_parent = nil
    assert_nil(r1.acl_node)
  end

  def test_parent_set
    root = Bind.root_collection
    root.bind(@resource, "foo1", @limeberry)
    root.bind(@collection, "dir1", @limeberry)
    @collection.bind(@resource, "foo1", @limeberry)

    setup_xml
    @resource.parent_set(@xml)
    doc = REXML::Document.new(@xml_out)

    assert_equal 1, doc.elements.size
    parent_set_element = doc.elements[1]
    
    urls = []
    parent_set_element.each_element do |parent_element|
      href = nil
      segment = nil
      parent_element.each_element do |element|
        if element.name == "href"
          href = element.text
        elsif element.name == "segment"
          segment = element.text
        end
      end

      assert_not_nil(href)
      assert_not_nil(segment)

      url = File.join(href, segment)
      urls << url
      assert_equal(@resource, Bind.locate(File.join(href, segment)))
    end

    assert_equal(3, urls.uniq.size)
    
  end

  def test_propfind_allprop
  # FINISH!
  end

  def test_propfind_status
    assert_equal(Status::HTTP_STATUS_OK,
                 @resource.send(:propfind_status, @pk1, @limeberry))
  end

  def test_propfind_status_already_reported
    assert_equal(Status::HTTP_STATUS_ALREADY_REPORTED,
                 @resource.send(:propfind_status, @pk1, @limeberry,
                                Status::HTTP_STATUS_ALREADY_REPORTED))
  end

  def test_propfind_status_liveprop
    displayname_pk = PropKey.get('DAV:', 'displayname')
    assert_equal(Status::HTTP_STATUS_OK,
                 @resource.send(:propfind_status, displayname_pk,
                                @limeberry))
  end

  def test_propfind_status_error
    pk3 = PropKey.get("randomns3", "randomname3")
    assert_equal(Status::HTTP_STATUS_NOT_FOUND,
                 @resource.send(:propfind_status, pk3, @limeberry))
  end

  def test_propfind_status_liveprop_error
    acl_pk = PropKey.get('DAV:', 'acl')
    assert_equal(Status::HTTP_STATUS_FORBIDDEN,
                 @resource.send(:propfind_status, acl_pk, @joe))
  end
  
  def test_propfind
    Privilege.priv_read.grant(@resource, @joe)

    displayname_pk = PropKey.get('DAV:', 'displayname')
    acl_pk = PropKey.get('DAV:', 'acl')
    
    setup_xml
    @xml.tag_dav_ns! :dummyroot  do
      @resource.propfind(@xml, @joe, false, @pk1, @pk2,
                         acl_pk, displayname_pk)
    end

    expected_out = <<EOS
<dummyroot xmlns:D='DAV:'>
  <D:propstat>
    <D:prop>
      <D:acl/>
    </D:prop>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:propstat>
  <D:propstat>
    <D:prop>
      <N:randomname1 xmlns:N="randomns1">randomvalue1</N:randomname1>
      <N:randomname2 xmlns:N="randomns2">randomvalue2</N:randomname2>
      <D:displayname xmlns:D='DAV:'>this is my displayname</D:displayname>
    </D:prop>
    <D:status>HTTP/1.1 200 OK</D:status>
  </D:propstat>
</dummyroot>
EOS

    assert_rexml_equal(expected_out, @xml_out)
  end
  
  # move to functional tests
  #   def test_propfind_loops
  #     @collection.bind(@collection,"self", @limeberry)
  #     assert_raise(LoopDetectedError) {
  #       @collection.propfind("/dir", 'infinity',
  #                            :allprop => true,
  #                            :principal => @limeberry)
  #     }
  #     assert_nothing_raised() {
  #       @collection.propfind("/dir", 'infinity',
  #                            :allprop => true,
  #                            :principal => @limeberry,
  #                            :dav => "1, 2, bind")
  #     }
  #   end

  def test_propfind_propname
    setup_xml

    @xml.tag_dav_ns! :dummyroot do
      @resource.send(:propfind_propname, @xml)
    end

    expected_out = <<EOS
<dummyroot xmlns:D='DAV:'>
  <D:creationdate/>
  <D:displayname/>
  <D:getcontentlanguage/>
  <D:getcontentlength/>
  <D:getcontenttype/>
  <D:getetag/>
  <D:getlastmodified/>
  <D:lockdiscovery/>
  <D:resourcetype/>
  <D:source/>
  <D:supportedlock/>
  <D:comment/>
  <D:creator-displayname/>
  <D:supported-live-property-set/>
  <D:owner/>
  <D:group/>
  <D:supported-privilege-set/>
  <D:current-user-privilege-set/>
  <D:acl/>
  <D:resource-id/>
  <D:parent-set/>
  <R:randomname1 xmlns:R="randomns1"/>
  <R:randomname2 xmlns:R="randomns2"/>
</dummyroot>
EOS

    assert_rexml_equal(expected_out, @xml_out)
  end

  def test_resource_id
    setup_xml
    @resource.dav_resource_id(@xml)
    expected_urn = Utility.uuid_to_urn(@resource.uuid)
    expected_out = "<D:resource-id xmlns:D='DAV:'><D:href>#{expected_urn}</D:href></D:resource-id>"
    assert_rexml_equal(expected_out, @xml_out)
  end

  def test_proppatch_remove_one
    @resource.proppatch_remove_one(@pk1)
    assert_equal 1, @resource.properties.size
    assert_equal @pk2, @resource.properties[0].propkey
  end

  def test_proppatch_remove_one_liveprop
    assert_raise(ForbiddenError) do
      @resource.proppatch_remove_one(PropKey.get('DAV:', 'displayname'))
    end
  end

  def test_proppatch_remove_one_nonexistant_prop
    assert_nothing_raised do
      @resource.proppatch_remove_one(PropKey.get('newns', 'neverbeforeseen'))
    end
    assert_equal 2, @resource.properties.size
  end

  def test_proppatch_set_one_new_prop
    element = REXML::Document.new('<S:randomname3 xmlns:S="randomns3">randomvalue3</S:randomname3>').root
    @resource.proppatch_set_one(element)
    assert_equal 3, @resource.properties.size
    prop = @resource.properties.find_by_propkey(PropKey.get('randomns3', 'randomname3'))
    assert_not_nil prop
    assert_equal "<S:randomname3 xmlns:S='randomns3'>randomvalue3</S:randomname3>", prop.value
  end

  def test_proppatch_set_one_preexisting_prop
    element = REXML::Document.new('<N:randomname2 xmlns:N="randomns2">newrandomvalue</N:randomname2>').root
    @resource.proppatch_set_one(element)
    assert_equal 2, @resource.properties.size
    prop = @resource.properties.find_by_propkey(@pk2)
    assert_equal "<N:randomname2 xmlns:N='randomns2'>newrandomvalue</N:randomname2>", prop.value
  end

  def test_proppatch_set_one_liveprop
    xml = '<D:displayname xmlns:D="DAV:">foobar</D:displayname>'
    @resource.proppatch_set_one(REXML::Document.new(xml).root)
    assert_equal 2, @resource.properties.size
    assert_equal("foobar", @resource.displayname)
  end

  def test_proppatch_set_one_liveprop_protected
    xml = '<D:getetag xmlns:D="DAV:">newetag</D:getetag>'
    assert_raise(ForbiddenError) do
      @resource.proppatch_set_one(REXML::Document.new(xml).root)
    end
  end

  # move to functional tests
#   def test_put_locked_parent
#     stream,contenttype = get_put_args
#     lock = create_lock("/dir")

#     assert_raise(LockedError) {
#       Resource.put("/dir/src",stream ,contenttype, @limeberry)
#     }

#     Privilege.priv_write.grant(@resource,@joe)
#     assert_raise(LockedError) {
#       Resource.put("/dir/src", stream, contenttype, @joe, lock.uuid)
#     }

#     assert_nothing_raised {
#       Resource.put("/dir/src", stream, contenttype, @limeberry, lock.uuid)
#     }
#     assert(@resource.locked?)
#   end

#   def test_put_new_res_in_locked_parent
#     stream,contenttype = get_put_args
#     lock = create_lock("/dir")

#     assert_raise(LockedError) {
#       Resource.put("/dir/bar", stream, contenttype, @limeberry)
#     }

#     response = nil

#     assert_nothing_raised(LockedError) do
#       response = Resource.put("/dir/bar", stream, contenttype,
#                               @limeberry, lock.uuid)
#     end
    
#     assert_equal 201, response.status.code
#   end

  def test_resourcetype
    setup_xml
    @resource.resourcetype(@xml)
    assert_rexml_equal("<D:resourcetype xmlns:D='DAV:'/>", @xml_out)
  end

  def test_supportedlock
    expected = <<EOS
<D:lockentry>
  <D:lockscope><D:exclusive/></D:lockscope>
  <D:locktype><D:write/></D:locktype>
</D:lockentry>
<D:lockentry>
  <D:lockscope><D:shared/></D:lockscope>
  <D:locktype><D:write/></D:locktype>
</D:lockentry>
EOS

    assert_liveprop_direct_method_equal(:supportedlock, "supportedlock", expected)
  end


  def setup_transfer_direct_locks
    Collection.mkcol_p("/dir4", @limeberry)
    @foo = util_put '/dir4/foo', '123'

    @bind = @foo.binds[0]
    @l1 = create_lock("/dir4/foo", @limeberry, 'S', '0')
    @l2 = create_lock("/dir4/foo", @limeberry, 'S', 'I')
  end
  
  def test_transfer_direct_locks
    setup_transfer_direct_locks
    
    lock = create_lock(@collectionpath, @limeberry, 'S', '0')

    assert_raise(LockedError) do
      @foo.transfer_direct_locks(@collection, @bind, @limeberry, lock.uuid)
    end
    
    @foo.transfer_direct_locks(@collection, @bind, @limeberry, @l1.uuid)
    @resource.reload
    assert @resource.locked_with?(@l2.uuid)
    assert @foo.locks.empty?
    assert @foo.direct_locks.empty?

    assert_equal 3, @collection.locks.size

    [@l1, @l2, lock].each { |l| assert @collection.locked_with?(l.uuid) }
  end

  def test_transfer_direct_locks_conflicting
    setup_transfer_direct_locks
    
    lock = create_lock(@collectionpath, @limeberry, 'X', '0')
    
    assert_raise(ConflictError) do
      @foo.transfer_direct_locks(@collection, @bind, @limeberry, @l1.uuid)
    end
  end

  def test_transfer_direct_locks_priv
    Privilege.priv_write_content.grant(@resource, @joe)
    lock = create_lock(@resourcepath, @joe)

    a = Resource.create!(:displayname => 'a')
    @root.bind(a, 'a', @limeberry)

    bind = @resource.binds[0]

    assert_raise(ForbiddenError) do
      @resource.transfer_direct_locks(a, bind, @joe, lock.uuid)
    end

    assert @resource.locked_with?(lock.uuid)
  end

  def test_supported_live_property_set
    [Resource, Collection, Principal, User,
     Group, Vcr, Version, Vhr].each do |klass|
      setup_xml
      klass.new.supported_live_property_set(@xml)

      expected_out = "<D:supported-live-property-set xmlns:D='DAV:'>"
      klass.liveprops.each do |propkey, live_prop_info|
        expected_out << "<D:supported-live-property><D:prop>"
        expected_out << "<D:#{propkey.name}/>"
        expected_out << "</D:prop></D:supported-live-property>"
      end
      expected_out << "</D:supported-live-property-set>"
      assert_rexml_equal(expected_out, @xml_out)
    end
  end
  
  def test_version_control
    Resource.version_control("/dir/src", @limeberry)
    
    @resource = Resource.find(@resource)
    assert @resource.is_a?(Vcr)
    
    vhr_path = File.join("/!lime/vhrs/", Body.file_path(@resource.uuid))
    
    vhr = Bind.locate(File.join(vhr_path, "vhr"))
    assert vhr.is_a?(Vhr)
    assert_equal @resource, vhr.vcrs[0]
    
    version1 = Bind.locate(File.join(vhr_path, "1"))
    assert_equal vhr.versions[0], version1
    assert version1.is_a?(Version)
    assert_equal vhr, version1.vhr
  end
  
  def test_version_control_second_time
    Resource.version_control("/dir/src", @limeberry)
    @resource = Resource.find(@resource)
    assert_nothing_raised() { 
      Resource.version_control("/dir/src", @limeberry)
    }
    assert_equal @resource.vhr, @resource.reload.vhr
  end

  def test_convert_to_vcr
    assert_raise(ForbiddenError) { @resource.convert_to_vcr(@joe) }
    assert_nothing_raised(ForbiddenError) { @resource.convert_to_vcr(@limeberry) }
    assert Resource.find(@resource).is_a?(Vcr)
  end

  def test_unprotected_aces
    assert_equal 1, @collection.aces.size
    assert_equal 0, @collection.unprotected_aces.size

    protected_ace = @collection.aces[0]

    Privilege.priv_read.grant @collection, @joe

    assert_equal 2, @collection.aces(true).size
    assert_equal 1, @collection.unprotected_aces(true).size

    @collection.unprotected_aces.clear

    assert_equal 1, @collection.aces(true).size
    assert_equal 0, @collection.unprotected_aces(true).size

    assert_nothing_raised(ActiveRecord::RecordNotFound) do
      assert_equal protected_ace.reload, @collection.aces[0]
    end
  end

  def test_current_user_privilege_set
    Privilege.priv_write.grant @resource, @joe
    setup_xml
    @resource.current_user_privilege_set @xml, @joe

    assert_xml_matches @xml_out do |xml|
      xml.send :"current-user-privilege-set" do
        %w( write write-properties write-content bind unbind ).each do |priv|
          xml.privilege { xml.send priv.to_sym }
        end
      end
    end

  end

  def test_group
    setup_xml
    @resource.group @xml
    assert_rexml_equal "<D:group xmlns:D='DAV:'/>", @xml_out
  end

  def test_supported_privileges
    expected = %w(all read read-acl read-current-user-privilege-set write
                  write-properties write-content write-acl unlock).map do |name|
      Namespace.dav.privileges.find_by_name name
    end

    assert_equal expected.sort, @resource.supported_privileges.sort
  end
  
  def test_supported_privilege_set
    expected = <<EOS
<D:supported-privilege-set xmlns:D='DAV:'>
  <D:supported-privilege>
    <D:privilege><D:all/></D:privilege>
    <D:description xml:lang="en">#{Privilege.priv_all.description}</D:description>
    <D:supported-privilege>
      <D:privilege><D:read/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:read-acl/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read_acl.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:read-current-user-privilege-set/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_read_current_user_privilege_set.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write.description}</D:description>
      <D:supported-privilege>
        <D:privilege><D:write-properties/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_write_properties.description}</D:description>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege><D:write-content/></D:privilege>
        <D:description xml:lang="en">#{Privilege.priv_write_content.description}</D:description>
      </D:supported-privilege>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write-acl/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_write_acl.description}</D:description>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:unlock/></D:privilege>
      <D:description xml:lang="en">#{Privilege.priv_unlock.description}</D:description>
    </D:supported-privilege>
  </D:supported-privilege>
</D:supported-privilege-set>
EOS
    setup_xml
    @resource.supported_privilege_set @xml
    assert_rexml_equal expected, @xml_out
  end
  
  
    
  # helpers

  def assert_liveprop_direct_method_equal(method, propname, expected)
    setup_xml
    @resource.send(method, @xml)
    actual_out = @xml_out

    setup_xml
    PropKey.get('DAV:', propname).xml_with_unescaped_text(@xml, expected)

    expected_out = @xml_out
    
    assert_rexml_equal(expected_out, actual_out)
  end

  def assert_two_resources_lpdm_equal(res1, res2, method)
    assert_two_resources_lpdm(:assert_equal, res1, res2, method)
  end

  def assert_two_resources_lpdm_not_equal(res1, res2, method)
    assert_two_resources_lpdm(:assert_not_equal, res1, res2, method)
  end

  def assert_lockable_error(error, lockscope)
    if error.nil?
      assert_nothing_raised() {
        @resource.lockable?(@joe, lockscope)
      }
    else
      assert_raise(error) {
        @resource.lockable?(@joe, lockscope)
      }
    end
  end
  
  def assert_two_resources_lpdm(assert_method, res1, res2, direct_method)
    setup_xml
    res1.send(direct_method, @xml)
    res1_out = @xml_out

    setup_xml
    res2.send(direct_method, @xml)
    res2_out = @xml_out

    self.send(assert_method, res1_out, res2_out)
  end
  
  def resources_without_acl_parent(num)
    (1..num).map do |n|
      name = "r#{n}"

      r = Resource.create!(:displayname => name)
      Bind.root_collection.bind(r, name, @limeberry)
      r.reload
    end
  end

end

