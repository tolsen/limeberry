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


module REXML
  class Element
    
    # EMPTY_NAMESPACE_PREFIX_DECLARATION_FIX
    
    # If an XML document includes an empty
    # namespace prefix declaration (xmlns:ns1=""), then a
    # ParseException should be raised.
    # http://www.w3.org/TR/REC-xml-names#dt-prefix
    
    alias_method :add_element_orig, :add_element
    private :add_element_orig
    def add_element element,attrs=nil
      if attrs.kind_of? Hash
        attrs.each do |key,value|
          raise ParseException.new("Empty Namespace Prefix Declaration") if ((key =~ /^xmlns:/) and (value == ""))
        end
      end
      add_element_orig element,attrs
    end
    # END EMPTY_NAMESPACE_PREFIX_DECLARATION_FIX
    
    #CONTENTS OF AN ELEMENT ALONG WITH APPROPRIATE CONTEXT INFORMATION
    #This is basically to define the contents function, which 
    #returns the contents of any element as a string. Since there may 
    #be prefixes on the contents, the context information must first be
    #taken care of by adding prefix definitions to contents.
#     def each_prefix_with_value
#       prefixes = {}
#       prefixes = parent.each_prefix_with_value if parent
#       attributes.prefixes.each {|prefix|
#         prefixes[prefix] = attributes[prefix]
#       }
#       return prefixes
#     end
#     def add_relevant_prefixes
#       relevant_prefixes = each_prefix_with_value
#       self.each_element {|elem|
#         relevant_prefixes.each {|key,val|
#           #elem.add_namespace key,val
#           elem.attributes[key] ||= val
#         }
#       }
#     end
    def innerXML
#      add_relevant_prefixes
      map.join
    end
    #END: CONTENTS OF AN ELEMENT WITH CONTEXT INFORMATION
    #Set contents of an element from the source string 
    def innerXML= source
      Parsers::TreeParser.new(source,self).parse
    end

    def propkey
      PropKey.get namespace, name
    end
    
    def <=>(other)
      result = name <=> other.name
      return result unless result.zero?

      result = elements.to_a <=> other.elements.to_a
      return result unless result.zero?

      result = texts <=> other.texts
      return result unless result.zero?

      return attributes.old_to_a <=> other.attributes.old_to_a
    end

    def sort_r
      result = clone_shallow
      result.add_text texts.map{ |t| t.value }.join

      elements.map{ |e| e.sort_r }.sort.each do |e|
        result.add_element e
      end

      result
    end

    private
    
    def clone_shallow
      clone
    end
  end

  class Document

    private

    def clone_shallow
      self.class.new
    end
  end

  class Attributes

    def old_to_a
      map{ |k, v| [k, v] }
    end
  end

  if (VERSION.split('.') <=> "3.1.7.1".split('.')) >= 0

    module Node

      def to_s indent=nil
        unless indent.nil?
#          Kernel.warn( "#{self.class.name}.to_s(indent) parameter is deprecated" )
          f = REXML::Formatters::Pretty.new( indent )
        else
          f = REXML::Formatters::Default.new
        end
        f.write( self, rv = "" )
        return rv
      end
    end
  end

  
end

