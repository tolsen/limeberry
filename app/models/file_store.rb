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

require 'singleton'
require 'thread'

class FileStore
  include Singleton

  SHA1_SEGMENT = "sha1s"
  
  attr_reader :dirty

  def initialize(root = FILE_STORE_ROOT)
    self.root = root
  end

  def root=(new_root)
    @root = new_root
    FileUtils.mkpath(@sha1_path = File.join(@root, SHA1_SEGMENT))
    @dirty = false
  end

  def put(stream,filepath)
    # TODO: use a hardlink instead when stream is a file
    # and is on filesystem
    fpath = full_path(filepath)
    @dirty = true
    FileUtils.mkpath(File.dirname(fpath))
    Utility.write_stream_to_file(stream, fpath)
  end

  def delete(filepath)
    @dirty = true
    File.delete(full_path(filepath))
  rescue Errno::ENOENT
    raise(InternalServerError, "couldn't find #{filepath} on disk")
  end


  def get(filepath)
    File.new(full_path(filepath))
  rescue Errno::ENOENT
    raise(InternalServerError, "couldn't find #{filepath} on disk")
  end

  def full_path path
    File.join(@sha1_path, path)
  end

  def self.dirty?
    instance.dirty
  end
  
end
