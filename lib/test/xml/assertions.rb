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

require 'generator'
require 'rexml/document'

module Test::XML::Assertions

  TEST_XML_REXML_DOC_CTX = {
    :compress_whitespace => :all,
    :ignore_whitespace_nodes => :all
  } unless defined? TEST_XML_REXML_DOC_CTX

  class XmlMatchAssertion
    
    def initialize doc, testcase
      doc = REXML::Document.new(doc, TEST_XML_REXML_DOC_CTX) if doc.instance_of? String
      @children = [ doc.root ]
      @namespaces = self.class.empty_ns
      @seen = []
      @tc = testcase
      @num_matched = 0
    end

    def method_missing sym, *args, &block
      ns, name = if args[0].instance_of? Symbol
                   raise "prefix #{sym} not defined" unless @namespaces.include? sym
                   [ @namespaces[sym], args.shift.to_s ]
                 else
                   [ @namespaces[:@default], sym.to_s ]
                 end

      if @ordered
        assert_current_element ns, name, *args, &block
      else
        assert_any_element ns, name, *args, &block
      end

      @num_matched += 1
    end

    def ordered!() @ordered = true; end
    def unordered!() @ordered = false; end

    def xmlns! arg
      case arg
      when String then @namespaces[:@default] = arg
      when Hash then @namespaces.merge! arg
      else raise "arg must be String or Hash"
      end
    end

    private
    
    def assert_any_element ns, name, text = nil, &block
      children_left.each do |child|
        begin
          assert_element child, ns, name, text, &block
          return
        rescue Test::Unit::AssertionFailedError
        end
      end

      @tc.flunk "could not find element named #{name}"
    end

    def assert_current_element ns, name, text = nil, &block
      left = children_left
      @tc.assert ! left.empty?
      assert_element left[0], ns, name, text, &block
    end

    def assert_element element, ns, name, text = nil, &block
      @tc.assert_equal ns, element.namespace unless ns.empty?
      @tc.assert_equal name, element.name
      @tc.assert_equal text, element.text unless text.nil?
      if block_given?
        with_state_safe do
          @children = element.children
          @seen = []
          @num_matched = 0
          yield
          @tc.assert_equal @children.size, @num_matched
        end
      end

      @seen << element
    end

    def children_left() @children - @seen; end

    def with_state_safe
      orig_ordered = @ordered
      orig_namespaces = @namespaces.clone
      orig_children = @children.clone
      orig_seen = @seen.clone
      orig_num_matched = @num_matched
      yield
    ensure
      @num_matched = orig_num_matched
      @seen = orig_seen
      @children = orig_children
      @namespaces = orig_namespaces
      @ordered = orig_ordered
    end
    
    def self.empty_ns() { :@default => '' }; end
    
  end
end

    
    
