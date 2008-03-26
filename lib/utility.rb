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

require 'constants'
require 'digest/sha1'
require 'rexml/document'


Enumerable.module_eval do
  def sql_in_condition
    "( " + map { |e| block_given? ? yield(e) : e.id }.uniq.join(', ') + " )"
  end
end

module Utility

  srand ( Time.now.to_i * $$ ) % 2**30 # don't rollover into a bignum

  class << self
    
    ## Extracts the base part of a filename (removing the leading directory names)
    def base_part_of(file_name)
      myname = File.basename(file_name)
      myname.gsub(/[^\w._-]/,'')
    end

    # filters out keys in hash that are not in filter
    # sets key/value pair in hash for those not in hash
    # but have a non-nil value in filter

    # returns a hash with same key, value pairs as filter
    # but with values replaced with matching key in options
    # (unless value is nil)
    def filter_and_default_options(options, filter)
      result = {}
      filter.each { |k, v| result[k] = options[k] || v }
      result
    end

    ## Checks the validity of a file/dir/redirect name.
    ## follows UNIX file name compatibility ('/' reserved,max 255 characters)
    def valid_file_name?( file_name )
      file_name.match(/\//).nil? && file_name.length <= 255
    end

    # these blksize methods are copied from the private section of
    # Ruby's fileutils library.  I figured it would be better
    # to copy them here rather than use Object#send to call
    # a method in FileUtils that is not part of the public API
    # and may be subject to change

    DEFAULT_BLKSIZE = 1024 unless defined?(DEFAULT_BLKSIZE)

    def stream_blksize(*streams)
      streams.each do |s|
        next unless s.respond_to?(:stat)
        size = blksize(s.stat)
        return size if size
      end
      DEFAULT_BLKSIZE
    end

    def blksize(st)
      s = st.blksize
      return nil unless s
      return nil if s == 0
      s
    end

    ## mktemp
    def mktemp(temp_directory)
      `mktemp #{temp_directory}/XXXXXXXXXX`.chomp
    end

    def write_stream_to_file(stream, filepath)
      File.open(filepath,"w") {|f|
        bsize = stream_blksize(stream,f)
        while s = stream.read(bsize)
          f.write s
        end
      }
    end

    ## Methods to process UUIDs

    def dashify_uuid uuid
      dashed_uuid = uuid.sub(/^([[:xdigit:]]{8})([[:xdigit:]]{4})([[:xdigit:]]{4})([[:xdigit:]]{4})([[:xdigit:]]{12})$/, '\1-\2-\3-\4-\5')

      # raise error if uuid cannot be substituted.
      # one of the reasons might be that uuid contains non-hex digits
      raise InternalServerError if dashed_uuid == uuid

      dashed_uuid
    end

    def uuid_to_locktoken uuid
      "opaquelocktoken:#{dashify_uuid uuid}"
    end

    def uuid_to_urn uuid
      "urn:uuid:#{dashify_uuid uuid}"
    end

    DASHED_UUID_CHECK =
      "([[:xdigit:]]{8})-([[:xdigit:]]{4})-([[:xdigit:]]{4})-([[:xdigit:]]{4})-([[:xdigit:]]{12})" unless defined?(DASHED_UUID_CHECK)
    
    def locktoken_to_uuid locktoken
      regexp = Regexp.new("^(opaquelocktoken|urn:uuid):#{DASHED_UUID_CHECK}$")
      uuid = locktoken.sub(regexp, '\2\3\4\5\6')

      # - Our server does not recognize such a formatted locktoken.
      # - Not raising NotFoundError as many methods may call this
      #   function for different purposes.
      return nil if(uuid == locktoken)

      uuid
    end

    alias_method :urn_to_uuid, :locktoken_to_uuid
    
    def locktokens_to_uuids locktoken_array
      locktoken_array.map do |locktoken|
        locktoken_to_uuid locktoken
      end
    end


    XML_FORMATTER = REXML::Formatters::Default.new unless defined? XML_FORMATTER
    
    # node: REXML node
    def xml_print node
      output = ''
      XML_FORMATTER.write node, output
      return output
    end
    
  end

end
