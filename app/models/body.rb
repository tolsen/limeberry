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
require 'digest/sha1'
require 'shared-mime-info'
require 'stringio'
require 'tempfile'


# bodies are immutable

class Body < ActiveRecord::Base

  TEMP_FOLDER = File.join(RAILS_ROOT,"tmp")

  set_primary_key "resource_id"

  after_create :deplete_quota

  validates_presence_of :mimetype, :contentlanguage
  validates_format_of :sha1, :with => /^[0-9a-f]{40}$/
  
  belongs_to :resource

  def sha1count
    Body.count(:conditions => "sha1 = \"#{self.sha1}\"")
  end


  def destroy
    transaction do
      replenish_quota
      connection.execute("UPDATE bodies SET `resource_id` = NULL" +
                         " WHERE resource_id = #{id}")
      self.class.destroy_nulled if Bind.garbage_collection_on?
    end
  end

  def self.destroy_nulled
    transaction do
      filestore_trash.each{ |b| FileStore.instance.delete(b.file_path) }

      # now remove all nulled rows
      delete_all("resource_id IS NULL")
    end
  end
  
  # contents can be a string or stream
  def self.make(mimetype, resource, contents, contentlanguage = 'en')
    stream = nil

    if (contents.instance_of?(String))
      stream = StringIO.new(contents)
    elsif (contents.respond_to?(:read))
      stream = contents
    else
      raise "contents must be a String or respond_to read()"
    end

    stream.rewind if stream.respond_to?(:rewind)

    transaction do
      Tempfile.open("body", TEMP_FOLDER) do |f|
        bsize = Utility.stream_blksize(stream, f)
        digest = Digest::SHA1.new
        while s = stream.read(bsize)
          digest << s
          f.write s
        end

        sha1 = digest.hexdigest
        size = f.size

        if mimetype.blank?
          f.rewind
          mt = MIME::check_magics(f)
          mimetype = mt.nil? ? 'application/octet-stream' : mt.type
        end

        # TODO: fix needless deletes on filesystem
        # when body is staying the same (same sha1)

        resource.body.destroy unless resource.body.nil?
        resource.build_body(:mimetype => mimetype,
                            :size => size,
                            :sha1 => sha1,
                            :contentlanguage => contentlanguage)
        resource.body.save!

        unless resource.body.sha1count > 1
          f.rewind
          FileStore.instance.put(f, resource.body.file_path)
        end
      end
    end
    

    resource.body
  end

  def self.get_diff_body(from_body, to_body)
    from_file = from_body.stream
    to_file = to_body.stream
    diff_file_path = File.join(TEMP_FOLDER, "#{to_body.resource.uuid}-delta")
    create_diff_file(from_file.path, to_file.path, diff_file_path)
    Body.make('', to_body.resource, File.new(diff_file_path))
  end

  def self.create_diff_file(from_file_path, to_file_path, diff_file_path)
    system("xdelta delta -q #{from_file_path} #{to_file_path} #{diff_file_path}")
    File.new(diff_file_path)
  end

  def stream
    FileStore.instance.get(file_path)
  end


  def file_path
    self.class.file_path(sha1)
  end
  
  # Maybe we should move this to utility.rb since other classes use this
  def self.file_path str
    str.sub /^(\w\w)(\w\w)(\w\w)(\w\w)/, '\1/\2/\3/\4/'
  end

  def full_path
    FileStore.instance.full_path(file_path)
  end

  private

  def self.filestore_trash
    find_by_sql("SELECT b1.sha1 FROM bodies b1 INNER JOIN" +
                " (SELECT sha1, COUNT(sha1) FROM bodies" +
                " GROUP BY sha1 HAVING COUNT(sha1) = 1) b2" +
                " ON b1.sha1 = b2.sha1" +
                " WHERE b1.resource_id IS NULL;")
  end

  def replenish_quota
    owner = resource.owner
    owner.replenish_quota size
    owner.save!
  end

  def deplete_quota
    owner = resource.owner
    owner.deplete_quota size
    owner.save!
  end
  
  
end
