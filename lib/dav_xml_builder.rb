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

require 'builder'

module Builder

  class XmlBase

    def tag_with_unescaped_text!(sym, *args)
      text = nil
      attrs = nil
      sym = "#{sym}:#{args.shift}" if args.first.kind_of?(Symbol)
      args.each do |arg|
        case arg
        when Hash
          attrs ||= {}
          attrs.merge!(arg)
        else
          text ||= ''
          text << arg.to_s
        end
      end

      _indent
      _start_tag(sym, attrs)
      _text(text)
      _end_tag(sym)
      _newline
    end

    def dav_ns_declared!
      @dav_ns_declared
    end

    def tag_dav_ns!(sym, *args, &block)
      @dav_ns_declared = true
      args.push 'xmlns:D' => 'DAV:'
      tag!(sym, *args, &block)
    ensure
      @dav_ns_declared = false
    end
    
    def D(*args, &block)
      if dav_ns_declared!
        method_missing('D', *args, &block)
      else
        args.push 'xmlns:D' => 'DAV:'
        begin
          @dav_ns_declared = true
          method_missing('D', *args, &block)
        ensure
          @dav_ns_declared = false
        end
      end
    end

  end
  
end
