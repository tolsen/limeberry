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

require 'test/test_helper'
require 'webdav_controller'


# Re-raise errors caught by the controller.
class WebdavController; def rescue_action(e) raise e end; end

class WebdavControllerTest < DavFunctionalTestCase
  
  def setup
    super
    @controller = WebdavController.new
    @request    = HttpTestRequest.new
    @response   = ActionController::TestResponse.new

    @foopath = '/webdav/foo'
    @dir1path = '/webdav/dir1'
    @dir2path = '/webdav/dir1/dir2'
    @barpath = '/webdav/dir1/dir2/bar'
    @dir3path = '/webdav/dir3'
    
    @foo, @dir1, @dir2, @bar, @dir3 =
      [@foopath, @dir1path, @dir2path,
       @barpath, @dir3path].map{ |p| Bind.locate p }

    @bar_uuid = @bar.uuid
    @webdavcol = Bind.locate '/webdav'
    @ren = User.find_by_name 'ren'
  end

  def test_parse_propfind_empty
    assert_equal :allprop, @controller.send(:parse_propfind,"")
  end

  def test_parse_propfind_allprop
    body = <<EOS
<?xml version="1.0" ?> 
<propfind xmlns="DAV:"> 
  <allprop/>
</propfind> 
EOS
    assert_equal :allprop, @controller.send(:parse_propfind, body)
  end

  def test_parse_propfind_propname
    body = <<EOS
<?xml version="1.0" ?> 
<propfind xmlns="DAV:"> 
  <propname/>
</propfind> 
EOS
    assert_equal :propname, @controller.send(:parse_propfind, body)
  end
  
  def test_parse_propfind_props
    body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop xmlns:R="http://ns.example.com/boxschema/"> 
    <R:bigbox/> 
    <R:author/> 
    <R:DingALing/> 
    <R:Random/> 
  </D:prop> 
</D:propfind>
EOS
    expected = [ 'bigbox', 'author', 'DingALing', 'Random' ].map do |name|
      PropKey.get("http://ns.example.com/boxschema/", name)
    end

    assert_equal expected.sort, @controller.send(:parse_propfind, body).sort
  end
  
  def test_propfind_root_displayname
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <D:displayname/>
  </D:prop>
</D:propfind>
EOS
    expected = <<EOS
<?xml version="1.0" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/</D:href> 
    <D:propstat> 
      <D:prop>
        <D:displayname>Root Collection</D:displayname>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DEPTH'] = '0'
    propfind '/', 'limeberry'
    assert_multistatus expected
  end

  def test_propfind_root_propname
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:propname/>
</D:propfind>
EOS
    expected = <<EOS
<?xml version="1.0" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/</D:href> 
    <D:propstat>
      <D:prop>
        <D:resource-id/>
        <D:acl/>
        <D:displayname/>
        <D:parent-set/>
        <D:lockdiscovery/>
        <D:current-user-privilege-set/>
        <D:creationdate/>
        <D:comment/>
        <D:resourcetype/>
        <D:source/>
        <D:supportedlock/>
        <D:creator-displayname/>
        <D:supported-live-property-set/>
        <D:owner/>
        <D:group/>
        <D:supported-privilege-set/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DEPTH'] = '0'
    propfind '/', 'limeberry'
    assert_multistatus expected
  end

  def test_propfind_root_allprop
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:allprop/>
</D:propfind>
EOS
    
    @request.env['HTTP_DEPTH'] = '0'
    propfind '/', 'limeberry'
    expected = multistatus_wrap(expected_allprop_dir(@root))
    assert_multistatus expected
  end

  def test_propfind_resource_allprop
    extra_props =
      '<N:randomname1 xmlns:N="randomns1">randomvalue1</N:randomname1>' +
      '<N:randomname2 xmlns:N="randomns2">randomvalue2</N:randomname2>'

    expected = multistatus_wrap(expected_allprop_resource(@foo, extra_props))
    
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:allprop/>
</D:propfind>
EOS

    assert_propfind_resource_matches expected
  end

  def test_propfind_hierarchy_allprop
    dir1_extra_props =
      '<N:prop1 xmlns:N="ns1">value1</N:prop1>' +
      '<N:prop2 xmlns:N="ns2">value2</N:prop2>'

    dir1_extra, dir2_extra, bar_extra =
      [[1, 2], [3, 4], [5, 6]].map do |m, n|
      "<N:prop#{m} xmlns:N=\"ns#{m}\">value#{m}</N:prop#{m}>" +
      "<N:prop#{n} xmlns:N=\"ns#{n}\">value#{n}</N:prop#{n}>"
    end
        
    dir1_expected = expected_allprop_dir @dir1, dir1_extra
    dir2_expected = expected_allprop_dir @dir2, dir2_extra
    bar_expected = expected_allprop_resource @bar, bar_extra

    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:allprop/>
</D:propfind>
EOS

    assert_propfind_hierarchy_matches(dir1_expected, dir2_expected, bar_expected)
  end

  def test_propfind_resource_propname
    extra_props = "<R:randomname1 xmlns:R='randomns1'/>\n<R:randomname2 xmlns:R='randomns2'/>"

    expected = multistatus_wrap(expected_propname_resource(@foo, extra_props))
    
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:propname/>
</D:propfind>
EOS

    assert_propfind_resource_matches expected
  end
  

  def test_propfind_hierarchy_propname
    dir1_extra_props =
      '<R:prop1 xmlns:R="ns1">value1</R:prop1>' +
      '<R:prop2 xmlns:R="ns2">value2</R:prop2>'

    dir1_extra, dir2_extra, bar_extra =
      [[1, 2], [3, 4], [5, 6]].map do |m, n|
      "<R:prop#{m} xmlns:R=\"ns#{m}\"/>\n<R:prop#{n} xmlns:R=\"ns#{n}\"/>"
    end
        
    dir1_expected = expected_propname_dir @dir1, dir1_extra
    dir2_expected = expected_propname_dir @dir2, dir2_extra
    bar_expected = expected_propname_resource @bar, bar_extra
    
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:propname/>
</D:propfind>
EOS
    assert_propfind_hierarchy_matches(dir1_expected, dir2_expected, bar_expected)
  end


  def test_propfind_resource_liveprop
    @foo.displayname = "Foo Bar"
    @foo.save!
    
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <D:displayname/>
  </D:prop>
</D:propfind>
EOS
    expected = <<EOS
<?xml version="1.0" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat> 
      <D:prop>
        <D:displayname>Foo Bar</D:displayname>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    
    assert_propfind_resource_matches expected
  end

  def test_propfind_hierarchy_liveprop
    dir1_expected, dir2_expected, bar_expected =
      [ [ @dir1, "Dir1 Smith"],
        [ @dir2, "Dir2 Johnson"],
        [ @bar, "Foo Bar"] ].map do |r, n|
      r.displayname = n
      r.save!
<<EOS
  <D:response>
    <D:href>#{r.url}</D:href> 
    <D:propstat> 
      <D:prop>
        <D:displayname>#{n}</D:displayname>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
EOS
    end
    
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:displayname/>
  </D:prop>
</D:propfind>
EOS

    assert_propfind_hierarchy_matches(dir1_expected, dir2_expected, bar_expected)
  end


  def test_propfind_resource_deadprop
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <N:randomname1 xmlns:N="randomns1"/>
  </D:prop>
</D:propfind>
EOS
    expected = <<EOS
<?xml version="1.0" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat> 
      <D:prop>
        <N:randomname1 xmlns:N="randomns1">randomvalue1</N:randomname1>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    
    assert_propfind_resource_matches expected
  end
  
  def test_propfind_hierarchy_deadprop
    pk = PropKey.get('ns', 'name')
    
    dir1_expected, dir2_expected, bar_expected =
      [ [ @dir1, "valueA"],
        [ @dir2, "valueB"],
        [ @bar, "valueC"] ].map do |r, v|
      r.properties.create!(:xml => "<N:name xmlns:N='ns'>#{v}</N:name>")
<<EOS
  <D:response>
    <D:href>#{r.url}</D:href> 
    <D:propstat> 
      <D:prop>
        <N:name xmlns:N="ns">#{v}</N:name>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
EOS
    end
    
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <N:name xmlns:N="ns"/>
  </D:prop>
</D:propfind>
EOS

    assert_propfind_hierarchy_matches(dir1_expected, dir2_expected, bar_expected)
  end

  def test_propfind_forbidden
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <R:randomname1 xmlns:R="randomns1"/>
  </D:prop>
</D:propfind>
EOS
    @request.env['HTTP_DEPTH'] = '0'
    propfind @foopath, 'ren'
    assert_response 403
  end

  def test_propfind_missing
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <R:randomname1 xmlns:R="randomns1"/>
  </D:prop>
</D:propfind>
EOS
    @request.env['HTTP_DEPTH'] = '0'
    propfind '/webdav/missing', 'limeberry'
    assert_response 404
  end

  def test_propfind_missing_prop
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <R:randommissing xmlns:R="randomns1"/>
  </D:prop>
</D:propfind>
EOS

    expected = <<EOS
<?xml version="1.0" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat> 
      <D:prop>
        <R:randommissing xmlns:R="randomns1"/>
      </D:prop> 
      <D:status>HTTP/1.1 404 Not Found</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DEPTH'] = '0'
    propfind @foopath, 'limeberry'
    assert_multistatus expected
  end

  def test_propfind_found_missing_mix
    @request.body = <<EOS
<?xml version="1.0" ?> 
<D:propfind xmlns:D="DAV:"> 
  <D:prop>
    <R:randomname1 xmlns:R="randomns1"/>
    <R:randommissing xmlns:R="randomns1"/>
  </D:prop>
</D:propfind>
EOS

    expected = <<EOS
<?xml version="1.0" ?> 
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat> 
      <D:prop>
        <N:randomname1 xmlns:N="randomns1">randomvalue1</N:randomname1>
      </D:prop> 
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
    <D:propstat> 
      <D:prop>
        <R:randommissing xmlns:R="randomns1"/>
      </D:prop> 
      <D:status>HTTP/1.1 404 Not Found</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DEPTH'] = '0'
    propfind @foopath, 'limeberry'
    assert_multistatus expected
  end

  def test_proppatch_dead_set
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://www.w3.com/standards/z39.50/">
  <D:set>
    <D:prop>
      <Z:authors>
        <Z:Author>Jim Whitehead</Z:Author>
        <Z:Author>Roy Fielding</Z:Author>
      </Z:authors>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:authors xmlns:R="http://www.w3.com/standards/z39.50/"/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    pk_authors = PropKey.get('http://www.w3.com/standards/z39.50/', 'authors')
    expected = <<EOS
<Z:authors>
  <Z:Author>Jim Whitehead</Z:Author>
  <Z:Author>Roy Fielding</Z:Author>
</Z:authors>
EOS
    actual = @foo.properties.find_by_propkey(pk_authors).value
    assert_rexml_equal expected, actual
  end

  def test_proppatch_live_set
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:set>
    <D:prop>
      <D:displayname>new name for foo</D:displayname>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <D:displayname/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    assert_equal 'new name for foo', @foo.reload.displayname
  end

  def test_proppatch_mixed_set
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://www.w3.com/standards/z39.50/">
  <D:set>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>
      <D:displayname>Display name for Dav</D:displayname>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:title xmlns:R="http://purl.org/dc/elements/1.1/"/>
        <D:displayname/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    assert_equal 'Display name for Dav', @foo.reload.displayname

    pk_title = PropKey.get('http://purl.org/dc/elements/1.1/', 'title')
    
    expected = '<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>'
    actual = @foo.properties.find_by_propkey(pk_title).value
    assert_rexml_equal expected, actual
  end

  def test_proppatch_remove_dead
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://www.w3.com/standards/z39.50/">
  <D:remove>
    <D:prop>
      <Z:randomname1 xmlns:Z="randomns1"/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:randomname1 xmlns:R="randomns1"/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    pk = PropKey.get 'randomns1', 'randomname1'
    assert_nil @foo.properties.find_by_propkey(pk)
  end

  def test_proppatch_set_remove_different_props
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://www.w3.com/standards/z39.50/">
  <D:set>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>
      <D:displayname>Display name for Dav</D:displayname>
    </D:prop>
  </D:set>
  <D:remove>
    <D:prop>
      <Z:randomname1 xmlns:Z="randomns1"/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:title xmlns:R="http://purl.org/dc/elements/1.1/"/>
        <D:displayname/>
        <R:randomname1 xmlns:R="randomns1"/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    assert_equal 'Display name for Dav', @foo.reload.displayname

    pk_title = PropKey.get('http://purl.org/dc/elements/1.1/', 'title')
    
    expected = '<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>'
    actual = @foo.properties.find_by_propkey(pk_title).value
    assert_rexml_equal expected, actual

    pk = PropKey.get 'randomns1', 'randomname1'
    assert_nil @foo.properties.find_by_propkey(pk)
  end

  def test_proppatch_set_remove_same_props
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:set>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>
    </D:prop>
  </D:set>
  <D:remove>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/"/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:title xmlns:R="http://purl.org/dc/elements/1.1/"/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    pk_title = PropKey.get('http://purl.org/dc/elements/1.1/', 'title')
    assert_nil @foo.properties.find_by_propkey(pk_title)
  end

  def test_proppatch_remove_set_same_props
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:remove>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/"/>
    </D:prop>
  </D:remove>
  <D:set>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:title xmlns:R="http://purl.org/dc/elements/1.1/"/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS

    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    pk_title = PropKey.get('http://purl.org/dc/elements/1.1/', 'title')
    expected = '<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>'
    actual = @foo.properties.find_by_propkey(pk_title).value
    assert_rexml_equal expected, actual
  end

  def test_proppatch_remove_non_existing_prop
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:remove>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/"/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS

    # RFC says this is not an error
    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <R:title xmlns:R="http://purl.org/dc/elements/1.1/"/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    proppatch @foopath, 'limeberry'
    assert_multistatus expected
  end

  def test_proppatch_set_protected_prop
    orig_etag = @foo.etag
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:set>
    <D:prop>
      <D:getetag>"etagofmychoosing"</D:getetag>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <D:getetag/>
      </D:prop>
      <D:status>HTTP/1.1 403 Forbidden</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    assert_equal orig_etag, @foo.reload.etag
  end

  def test_proppatch_remove_protected_prop
    orig_creationdate = @foo.created_at
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:remove>
    <D:prop>
      <D:creationdate/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <D:creationdate/>
      </D:prop>
      <D:status>HTTP/1.1 403 Forbidden</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    assert_equal orig_creationdate, @foo.reload.created_at
  end

  def test_proppatch_remove_unprotected_live_prop
    orig_displayname = @foo.displayname 
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:remove>
    <D:prop>
      <D:displayname/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <D:displayname/>
      </D:prop>
      <D:status>HTTP/1.1 403 Forbidden</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    assert_equal orig_displayname, @foo.reload.displayname
  end

  def test_proppatch_failed_dependency
    @request.body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propertyupdate xmlns:D="DAV:">
  <D:set>
    <D:prop>
      <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Title for Dublin Core</dc:title>
      <N:randomname1 xmlns:N="randomns1">newvalue</N:randomname1>
      <D:displayname>my new displayname</D:displayname>
      <D:getetag>"iwishicouldchangemyetag"</D:getetag>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOS

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>#{@foopath}</D:href> 
    <D:propstat>
      <D:prop>
        <D:getetag/>
      </D:prop>
      <D:status>HTTP/1.1 403 Forbidden</D:status> 
    </D:propstat>
    <D:propstat>
      <D:prop>
        <R:title xmlns:R="http://purl.org/dc/elements/1.1/"/>
        <R:randomname1 xmlns:R="randomns1"/>
        <D:displayname/>
      </D:prop>
      <D:status>HTTP/1.1 424 Failed Dependency</D:status> 
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    proppatch @foopath, 'limeberry'
    assert_multistatus expected

    pk_title = PropKey.get 'http://purl.org/dc/elements/1.1/', 'title'
    pk_random1 = PropKey.get 'randomns1', 'randomname1'

    assert_nil @foo.reload.properties.find_by_propkey(pk_title)
    assert_rexml_equal "<N:randomname1 xmlns:N='randomns1'>randomvalue1</N:randomname1>", @foo.properties.find_by_propkey(pk_random1).value
    assert_equal 'foo', @foo.displayname
  end
  
  def test_mkcol
    mkcol '/webdav/col', 'limeberry'
    assert_response 201

    assert_nothing_raised(NotFoundError) do
      assert_instance_of Collection, Bind.locate('/webdav/col')
    end
  end

  def test_mkcol_conflict
    mkcol '/webdav/missing/col', 'limeberry'
    assert_response 409
    assert_raise(NotFoundError) { Bind.locate '/webdav/missing' }
  end

  def test_mkcol_bind_denied
    mkcol '/webdav/col', 'ren'
    assert_response 403
    assert_raise(NotFoundError) { Bind.locate '/webdav/col' }
  end

  def test_mkcol_bind_granted
    Privilege.priv_bind.grant @webdavcol, @ren
    mkcol '/webdav/col', 'ren'
    assert_response 201
    
    assert_nothing_raised(NotFoundError) do
      assert_instance_of Collection, Bind.locate('/webdav/col')
    end
  end

  def test_mkcol_method_not_allowed
    mkcol '/webdav/foo', 'limeberry'
    assert_response 405
    assert_instance_of Resource, Bind.locate('/webdav/foo')
  end

  def test_mkcol_unsupported_media_type
    @request.body = "body"
    mkcol '/webdav/col', 'limeberry'
    assert_response 415
    assert_raise(NotFoundError) { Bind.locate '/webdav/col' }
  end

  
  def test_copy
    sleep 1 if @foo.created_at == Time.now
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    copy '/webdav/foo', 'limeberry'
    assert_response 201

    @foo.reload
    foo2 = Bind.locate '/webdav/foo2'

    assert foo2.created_at > @foo.created_at
    assert_resource_copied @foo, foo2
  end

  def test_copy_conflict
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA/foo2'
    copy '/webdav/foo', 'limeberry'
    assert_response 409

    assert_raise(NotFoundError) { Bind.locate '/webdav/dirA' }
  end

  def test_copy_read_denied
    Privilege.priv_bind.grant @webdavcol, @ren
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    copy '/webdav/foo', 'ren'
    assert_response 403
  end
  
  def test_copy_bind
    Privilege.priv_read.grant @foo, @ren

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/foo2</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS
    
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    copy '/webdav/foo', 'ren'
    assert_multistatus expected

    assert_raise(NotFoundError) { Bind.locate '/webdav/foo2' }

    Privilege.priv_bind.grant @webdavcol, @ren

    @request.clear_http_headers
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    copy '/webdav/foo', 'ren'
    assert_response 201

    assert_nothing_raised(NotFoundError) { Bind.locate '/webdav/foo2' }
  end

  def test_copy_overwrite_fail
    @request.env['HTTP_OVERWRITE'] = 'F'
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    copy '/webdav/foo', 'limeberry'
    assert_response 412
    assert_copy_overwrite_failed
  end

  def test_copy_overwrite_succeeds
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    copy '/webdav/foo', 'limeberry'
    assert_copy_overwrite_succeeded
  end

  def test_copy_overwrite_write_content_not_granted
    Privilege.priv_read.grant @foo, @ren
    Privilege.priv_write_properties.grant @bar, @ren

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/dir1/dir2/bar</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS
    
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    copy '/webdav/foo', 'ren'
    assert_multistatus expected

    assert_copy_overwrite_failed
  end

  def test_copy_overwrite_write_properties_not_granted
    Privilege.priv_read.grant @foo, @ren
    Privilege.priv_write_content.grant @bar, @ren

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/dir1/dir2/bar</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS
    
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    copy '/webdav/foo', 'ren'
    assert_multistatus expected

    assert_copy_overwrite_failed
  end

  def test_copy_overwrite_write_granted
    Privilege.priv_read.grant @foo, @ren
    Privilege.priv_write.grant @bar, @ren

    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    copy '/webdav/foo', 'ren'
    assert_copy_overwrite_succeeded
  end

  def test_copy_same_resource
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo'
    copy '/webdav/foo', 'limeberry'
    assert_response 403
  end

  def test_copy_to_different_server
    @request.env['HTTP_DESTINATION'] = 'http://test.host2/bar'
    copy '/webdav/foo', 'limeberry'
    assert_response 502
  end

  def test_copy_over_quota
    Privilege.priv_read.grant @foo, @ren
    Privilege.priv_bind.grant @webdavcol, @ren
    @ren.total_quota = @ren.used_quota + 1
    @ren.save!

    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    copy '/webdav/foo', 'ren'
    assert_response 507
    assert_raise(NotFoundError) { Bind.locate '/webdav/foo2' }
  end

  def test_copy_collection_depth_zero
    @request.env['HTTP_DEPTH'] = '0'
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA'
    copy '/webdav/dir1', 'limeberry'
    assert_response 201

    dirA = Bind.locate '/webdav/dirA'
    assert_instance_of Collection, dirA
    assert_equal 0, dirA.childbinds.size

    assert_not_nil dirA.properties.find_by_propkey(PropKey.get('ns1', 'prop1'))
  end

  def test_copy_collection_depth_zero_overwrite
    @request.env['HTTP_DEPTH'] = '0'
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1'
    copy '/webdav/dir3', 'limeberry'
    assert_response 204

    assert_raise(ActiveRecord::RecordNotFound) { @dir2.reload }
    assert_raise(ActiveRecord::RecordNotFound) { @bar.reload }
    assert_raise(NotFoundError) { Bind.locate '/webdav/dir1/a' }

    assert_equal @dir1.uuid, @dir1.reload.uuid
    assert_equal 0, @dir1.childbinds.size

    assert_separate_but_equal_properties @dir3, @dir1
  end

  def test_copy_collection_depth_infinity
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA'
    copy '/webdav/dir3', 'limeberry'
    assert_response 201

    dirA = nil
    assert_nothing_raised(NotFoundError) do
      dirA = Bind.locate '/webdav/dirA'
    end
    assert_separate_but_equal_properties @dir3, dirA
    
    a1, b1, c1 = %w( a b c ).map{ |name| @dir3.find_child_by_name name }

    a2, b2, c2 = %w( a b c ).map do |name|
      col = dirA.find_child_by_name name
      assert_not_nil col
      col
    end
    
    [[a1, a2], [b1, b2], [c1, c2]].each do |r1, r2|
      assert_separate_but_equal_properties r1, r2
    end

    { 'a' => %w( d e f ),
      'b' => %w( g h i ),
      'c' => %w( j k l ) }.each do |dirname, filenames|
      filenames.each do |filename|
        r1 = Bind.locate "/webdav/dir3/#{dirname}/#{filename}"
        r2 = nil
        assert_nothing_raised(NotFoundError) do
          r2 = Bind.locate "/webdav/dirA/#{dirname}/#{filename}"
        end
        assert_resource_copied r1, r2
      end
    end
    
  end

  def test_copy_collection_depth_infinity_source_failure
    Privilege.priv_bind.grant @webdavcol, @ren
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA'
    copy '/webdav/dir3', 'ren'
    assert_response 403

    assert_raises(NotFoundError) { Bind.locate '/webdav/dirA' }
  end

  def test_copy_collection_depth_infinity_dest_failure
    Privilege.priv_read.grant @dir3, @ren

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/dirA</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA'
    copy '/webdav/dir3', 'ren'
    assert_multistatus expected

    assert_raises(NotFoundError) { Bind.locate '/webdav/dirA' }
  end

  def test_copy_collection_depth_infinity_partial_failure
    Privilege.priv_read.grant @dir3, @ren
    b = Bind.locate '/webdav/dir3/b'
    Privilege.priv_read.deny b, @ren
    Privilege.priv_bind.grant @webdavcol, @ren

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/dir3/b</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA'
    copy '/webdav/dir3', 'ren'
    assert_multistatus expected

    dirA = nil
    assert_nothing_raised(NotFoundError) do
      dirA = Bind.locate '/webdav/dirA'
    end

    assert_separate_but_equal_properties @dir3, dirA
    
    a1, c1 = %w( a c ).map{ |name| @dir3.find_child_by_name name }

    a2, c2 = %w( a c ).map do |name|
      col = dirA.find_child_by_name name
      assert_not_nil col
      col
    end

    assert_nil dirA.find_child_by_name('b')
    
    [[a1, a2], [c1, c2]].each do |r1, r2|
      assert_separate_but_equal_properties r1, r2
    end

    { 'a' => %w( d e f ),
      'c' => %w( j k l ) }.each do |dirname, filenames|
      filenames.each do |filename|
        r1 = Bind.locate "/webdav/dir3/#{dirname}/#{filename}"
        r2 = nil
        assert_nothing_raised(NotFoundError) do
          r2 = Bind.locate "/webdav/dirA/#{dirname}/#{filename}"
        end
        assert_resource_copied r1, r2
      end
    end
    
  end


  def test_move
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    move '/webdav/foo', 'limeberry'
    assert_response 201

    assert_raise(NotFoundError) { Bind.locate '/webdav/foo' }
    foo2 = Bind.locate '/webdav/foo2'

    assert_equal @foo.reload, foo2
  end

  def test_move_quota
    Privilege.priv_bind.grant @webdavcol, @ren
    Privilege.priv_unbind.grant @webdavcol, @ren
    util_put '/webdav/rensres', 'content', @ren
    old_quota = @ren.reload.used_quota
    
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/rensres2'
    move '/webdav/rensres', 'ren'
    assert_response 201

    assert_equal old_quota, @ren.reload.used_quota
  end
  
  def test_move_unbind_denied
    Privilege.priv_bind.grant @webdavcol, @ren
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    move '/webdav/foo', 'ren'
    assert_response 403
    assert_move_failed
  end

  def test_move_bind_denied
    Privilege.priv_unbind.grant @webdavcol, @ren

    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/foo2</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    move '/webdav/foo', 'ren'
    assert_multistatus expected
    assert_move_failed
  end
  

  def test_move_different_parents
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/foo2'
    move '/webdav/foo', 'limeberry'
    assert_response 201

    assert_raise(NotFoundError) { Bind.locate '/webdav/foo' }
    foo2 = Bind.locate '/webdav/dir1/foo2'

    assert_equal @foo.reload, foo2
  end
    
  def test_move_overwrite
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    move '/webdav/foo', 'limeberry'
    assert_response 204

    assert_raise(NotFoundError) { Bind.locate '/webdav/foo' }
    assert_raise(ActiveRecord::RecordNotFound) { @bar.reload }
    new_bar = Bind.locate '/webdav/dir1/dir2/bar'

    assert_equal @foo.reload, new_bar
  end

  def test_move_overwrite_fail
    @request.env['HTTP_OVERWRITE'] = 'F'
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    move '/webdav/foo', 'limeberry'
    assert_response 412
    assert_move_overwrite_failed
  end

  def test_move_overwrite_unbind_denied
    Privilege.priv_unbind.grant @webdavcol, @ren
    Privilege.priv_bind.grant @dir2, @ren
    Privilege.priv_unbind.deny @dir2, @ren
    
    expected = <<EOS
<D:multistatus xmlns:D="DAV:"> 
  <D:response>
    <D:href>/webdav/dir1/dir2/bar</D:href>
    <D:status>HTTP/1.1 403 Forbidden</D:status>
  </D:response>
</D:multistatus>
EOS

    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1/dir2/bar'
    move '/webdav/foo', 'ren'
    assert_multistatus expected

    assert_move_overwrite_failed
  end

  def test_move_overwrite_hierarchy
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1'
    move '/webdav/foo', 'limeberry'
    assert_response 204

    [@dir1, @dir2, @bar].each do |r|
      assert_raise(ActiveRecord::RecordNotFound) { r.reload }
    end

    assert_nothing_raised(ActiveRecord::RecordNotFound) { @foo.reload }
    new_dir1 = nil
    assert_nothing_raised(NotFoundError) do
      new_dir1 = Bind.locate '/webdav/dir1'
    end

    assert_equal @foo, new_dir1
  end

  def test_move_collection
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA'
    move '/webdav/dir1', 'limeberry'
    assert_response 201

    [@dir1, @dir2, @bar].each do |r|
      assert_nothing_raised(ActiveRecord::RecordNotFound) { r.reload }
    end

    assert_nothing_raised(NotFoundError) do
      assert_equal @dir1, Bind.locate('/webdav/dirA')
    end
  end

  def test_move_same_resource
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo'
    move '/webdav/foo', 'limeberry'
    assert_response 403
  end
    
  def test_move_conflict
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dirA/foo2'
    move '/webdav/foo', 'limeberry'
    assert_response 409

    assert_raise(NotFoundError) { Bind.locate '/webdav/dirA' }
  end

  def test_move_to_different_server
    @request.env['HTTP_DESTINATION'] = 'http://test.host2/bar'
    move '/webdav/foo', 'limeberry'
    assert_response 502
  end

  def test_move_over_ancestor
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/dir1'
    move '/webdav/dir1/dir2', 'limeberry'
    assert_response 204

    assert_raise(ActiveRecord::RecordNotFound) { @dir1.reload }

    assert_nothing_raised(NotFoundError, ActiveRecord::RecordNotFound) do
      assert_equal @dir2.reload, Bind.locate('/webdav/dir1')
      assert_equal @bar.reload, Bind.locate('/webdav/dir1/bar')
    end

    assert_raise(NotFoundError) { Bind.locate '/webdav/dir1/dir2' }
  end

  def test_move_not_found
    @request.env['HTTP_DESTINATION'] = 'http://test.host/webdav/foo2'
    move '/webdav/foo3', 'limeberry'
    assert_response 404
  end
  
  # helpers

  def multistatus_wrap(s)
    "<D:multistatus xmlns:D=\"DAV:\">\n#{s}</D:multistatus>"
  end

  def expected_allprop_common(resource, extra_props = "")
    return <<EOS
<D:response>
  <D:href>#{resource.url}</D:href>
  <D:propstat>
    <D:prop>
      <D:supportedlock>
        <D:lockentry>
          <D:lockscope>
            <D:exclusive/>
          </D:lockscope>
          <D:locktype>
            <D:write/>
          </D:locktype>
        </D:lockentry>
        <D:lockentry>
          <D:lockscope>
            <D:shared/>
          </D:lockscope>
          <D:locktype>
            <D:write/>
          </D:locktype>
        </D:lockentry>
      </D:supportedlock>
      <D:source/>
      <D:displayname>#{resource.displayname}</D:displayname>
      <D:lockdiscovery>
      </D:lockdiscovery>
      <D:creationdate>#{resource.created_at.httpdate}</D:creationdate>
#{extra_props}
    </D:prop>
    <D:status>HTTP/1.1 200 OK</D:status>
  </D:propstat>
</D:response>
EOS
  end
  
  
  def expected_allprop_dir(resource, extra_props = "")
    extra_props2 = "<D:resourcetype><D:collection/></D:resourcetype>\n#{extra_props}"
    expected_allprop_common(resource, extra_props2)
  end
  
  def expected_allprop_resource(resource, extra_props = "")
    extra_props2 = <<EOS
      <D:resourcetype/>
      <D:getcontentlanguage>#{resource.body.contentlanguage}</D:getcontentlanguage>
      <D:getcontentlength>#{resource.body.size}</D:getcontentlength>
      <D:getcontenttype>#{resource.body.mimetype}</D:getcontenttype>
      <D:getlastmodified>#{resource.body.created_at.httpdate}</D:getlastmodified>
      <D:getetag>"#{resource.etag}"</D:getetag>
#{extra_props}
EOS
    expected_allprop_common resource, extra_props2
  end

  def expected_propname_dir(resource, extra_props = "")
    return <<EOS
  <D:response>
    <D:href>#{resource.url}</D:href> 
    <D:propstat>
      <D:prop>
        <D:resource-id/>
        <D:acl/>
        <D:displayname/>
        <D:parent-set/>
        <D:lockdiscovery/>
        <D:current-user-privilege-set/>
        <D:creationdate/>
        <D:comment/>
        <D:resourcetype/>
        <D:source/>
        <D:supportedlock/>
        <D:creator-displayname/>
        <D:supported-live-property-set/>
        <D:owner/>
        <D:group/>
        <D:supported-privilege-set/>
#{extra_props}
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status> 
    </D:propstat>
  </D:response>
EOS
  end

  def expected_propname_resource(resource, extra_props = "")
    extra_props2 = <<EOS
      <D:getcontentlanguage/>
      <D:getcontentlength/>
      <D:getcontenttype/>
      <D:getlastmodified/>
      <D:getetag/>
#{extra_props}
EOS
    expected_propname_dir resource, extra_props2
  end

  def assert_multistatus(expected)
    assert_response 207
    assert_rexml_equal expected, @response.body
  end
  
  def assert_propfind_hierarchy_matches(dir1_expected, dir2_expected, bar_expected)
    expected = multistatus_wrap(dir1_expected)
    @request.env['HTTP_DEPTH'] = '0'
    propfind '/webdav/dir1', 'limeberry'
    assert_multistatus expected

    expected = multistatus_wrap(dir1_expected + dir2_expected)
    @request.rewind_body
    @request.env['HTTP_DEPTH'] = '1'
    propfind '/webdav/dir1', 'limeberry'
    assert_multistatus expected

    expected = multistatus_wrap(dir1_expected + dir2_expected + bar_expected)
    @request.rewind_body
    @request.env['HTTP_DEPTH'] = 'infinity'
    propfind '/webdav/dir1', 'limeberry'
    assert_multistatus expected
  end

  def assert_propfind_resource_matches(expected)
    @request.env['HTTP_DEPTH'] = '0'
    propfind '/webdav/foo', 'limeberry'
    assert_multistatus expected

    @request.rewind_body
    @request.env['HTTP_DEPTH'] = '1'
    propfind '/webdav/foo', 'limeberry'
    assert_multistatus expected

    @request.rewind_body
    @request.env['HTTP_DEPTH'] = 'infinity'
    propfind '/webdav/foo', 'limeberry'
    assert_multistatus expected
  end

  def assert_copy_overwrite_succeeded
    assert_response 204
    assert_equal @bar_uuid, @bar.reload.uuid

    assert_equal @foo.displayname, @bar.displayname
    assert_not_equal @foo.body, @bar.body
    assert_equal @foo.body.stream.read, @bar.body.stream.read
    assert_separate_but_equal_properties @foo, @bar
  end
  
  def assert_copy_overwrite_failed
    assert_equal 'barcontent', @bar.reload.body.stream.read
    assert_nil @bar.properties.find_by_propkey(PropKey.get('randomns1', 'randomname1'))
    assert_not_nil @bar.properties.find_by_propkey(PropKey.get('ns5', 'prop5'))
  end

  def assert_separate_but_equal_properties(r1, r2)
    assert_equal r1.properties.size, r2.properties.size

    r1.properties.each do |r1_prop|
      r2_prop = r2.properties.find_by_propkey r1_prop.propkey
      assert_not_equal r1_prop, r2_prop
      assert_equal r1_prop.value, r2_prop.value
    end
  end

  def assert_resource_copied(r1, r2)
    assert_not_equal r1, r2
    assert_not_equal r1.uuid, r2.uuid

    assert_equal r1.displayname, r2.displayname
    assert_not_equal r1.body, r2.body
    assert_equal r1.body.stream.read, r2.body.stream.read
    assert_separate_but_equal_properties r1, r2
  end

  def assert_move_failed
    assert_nothing_raised(NotFoundError) { Bind.locate '/webdav/foo' }
    assert_nothing_raised(ActiveRecord::RecordNotFound) { @foo.reload }
    assert_raise(NotFoundError) { Bind.locate '/webdav/foo2' }
  end

  def assert_move_overwrite_failed
    assert_nothing_raised(NotFoundError) { Bind.locate '/webdav/foo' }
    assert_nothing_raised(ActiveRecord::RecordNotFound) { @bar.reload }
    assert_not_equal @foo.reload, @bar
  end
  
    
end
