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

require 'stringio'

require 'lib/errors'
require 'test/test_helper'
require 'test/unit/dav_unit_test'

class FileStoreTest < DavUnitTestCase

  # tests that a put on the filestore actually creates a file on the disk
  # at filestore_root/sha1_segment/path_provided, also tests for overwrite
  def test_put
    string = "test string"
    path = "/a/b/c"
    
    FileStore.instance.put(StringIO.new(string),path)
    string2 = nil
    
    assert_nothing_raised(Errno::ENOENT) {
      string2 = File.new(filestore_path(path)).read
    }
    assert_equal string,string2

    # overwrite
    
    string = "new string"
    FileStore.instance.put(StringIO.new(string),path)

    assert_nothing_raised(Errno::ENOENT) {
      string2 = File.new(filestore_path(path)).read
    }
    assert_equal string,string2
  end

  # tests that get works correctly on the filestore. Assuming we have a file
  # at filestore_root/sha1_segment/some_path, get(some_path) should return 
  # the correct stream, also checks that error is raised if file doesnt exist
  def test_get
    path,string = util_file_setup

    string2 = nil
    assert_nothing_raised(InternalServerError) {
      string2 = FileStore.instance.get(path).read
    }
    
    assert_equal string,string2
    
    # get non existing file
    
    File.delete(filestore_path(path))
    
    assert_raise(InternalServerError) {
      FileStore.instance.get(path)
    }
  end

  # tests that delete works correctly on filestore. delete(some_path) should
  # delete the file at filestore_root/sha1_segment/some_path and raise error 
  # if no such file exists
  def test_delete
    path,string = util_file_setup
    FileStore.instance.delete(path)
    
    assert_raise(Errno::ENOENT) {
      File.new(filestore_path(path))
    }
    
    # delete non existing file

    assert_raise(InternalServerError) {
      FileStore.instance.delete(path)
    }
  end
  
  private 
  
  def util_file_setup
    string = "test string"
    path = "/a"

    File.open(filestore_path(path),"w") {|f|
      f.write(string)
    }
    
    return path,string
  end
  
  def filestore_path path
    File.join(@filestore_root,FileStore::SHA1_SEGMENT,path)
  end

end
