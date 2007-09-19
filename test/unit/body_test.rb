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
require 'test/unit/dav_unit_test'

require 'fileutils'

class BodyTest < DavUnitTestCase

  def setup
    super
    @string = "hello world"
    @testroot = Bind.locate("/body")
    @resource = Bind.locate("/body/r")
    @body = @resource.body
  end

  #TODO: write test for replacing body of a resource
  
  def test_make_body
    assert_equal(@resource.body.stream.read, @string)
    sha1_path = @resource.body.full_path
    assert(File.exists?(sha1_path))
  end

  def test_destroy_bodys_resource
    sha1_path = @resource.body.full_path
    @resource.destroy
    assert(!File.exists?(sha1_path))
  end

  def test_make_two_resources_two_bodies_same_content
    resource2 = Resource.create!(:creator => @limeberry)

    body2 = Body.make("text/plain", resource2, @string)

    r1_sha1_path = @resource.body.full_path
    r2_sha1_path = resource2.body.full_path

    assert_equal(r1_sha1_path, r2_sha1_path)
    assert(File.exists?(r1_sha1_path))

    @testroot.bind(@resource, "res1", @limeberry)
    @testroot.bind(resource2, "res2", @limeberry)

    assert_equal 2, resource2.body.sha1count

    # now destroy one resource
    @resource.destroy

    assert(File.exists?(r2_sha1_path))

    assert_equal 1, resource2.body.sha1count
    # destroy the other resource
    resource2.destroy

    assert(!File.exists?(r2_sha1_path))
  end

  def test_file_path
    b = Body.new( :sha1 => '0123456789abcdef0123456789abcdef01234567' )
    assert_equal '01/23/45/67/89abcdef0123456789abcdef01234567', b.file_path
  end


  def test_get_diff_body
    from_res = Bind.locate("/body/from")
    to_res = Bind.locate("/body/to")
    
    diff_body = Body.get_diff_body(from_res.body, to_res.body)
    
    patched_file_path = File.join(Body::TEMP_FOLDER, "patched")
    system("xdelta patch #{diff_body.stream.path} #{from_res.body.stream.path} #{patched_file_path}")
    assert_equal "abcd", File.new(patched_file_path).read
    
    File.delete(diff_body.stream.path, patched_file_path)
  end
  
  def test_create_diff_file
    from_file_path = File.join(Body::TEMP_FOLDER, "from")
    to_file_path = File.join(Body::TEMP_FOLDER, "to")
    diff_file_path = File.join(Body::TEMP_FOLDER, "diff")
    patched_file_path = File.join(Body::TEMP_FOLDER, "patched")
    
    from_file = File.new(from_file_path, File::CREAT|File::TRUNC|File::RDWR)
    from_file.write("abc")
    to_file = File.new(to_file_path, File::CREAT|File::TRUNC|File::RDWR)
    to_file.write("abcd")
    from_file.close
    to_file.close
    
    Body.create_diff_file(from_file_path, to_file_path, diff_file_path)
    
    system("xdelta patch #{diff_file_path} #{from_file_path} #{patched_file_path}")
    assert_equal "abcd", File.new(patched_file_path).read
    
    File.delete(from_file_path, to_file_path, diff_file_path, patched_file_path)
  end
  
end
