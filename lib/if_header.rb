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

require 'errors'

module IfHeaderParser

  class << self
    def parse_if_header header
      s = String.new header
      goto_char(s, [ "<", "(" ], true)
      if s[0,1] == "<" #resource tags exist
        return parse_tagged_list(s)
      else 
        return parse_no_tag_list(s)
      end
    end

    private
    
    def parse_tagged_list s
      final_result = TaggedLists.new
      loop do
        return final_result if (s.strip).empty? #return if only whitespace is left
        s.slice!(0,1) #removes '<'
        tag = goto_char(s, [ ">" ], false)
        s.slice!(0,1) #removes '>'
        lists = parse_lists s, false
        final_result << TaggedList.new(tag, lists)
      end
      raise BadRequestError if final_result.empty?
      final_result
    end
    
    def parse_no_tag_list s
      parse_lists s, true
    end
    
    def parse_lists s, flag #flag to check if list or taglist. true for notag
      lists = Lists.new
      loop do
        r = goto_char(s, [ "(", "<" ], true, false)
        return lists if r.nil?
        raise BadRequestError if s[0,1] == "<" && flag
        return lists if s[0,1] == "<"
        s.slice!(0,1) #remove '('
        list = parse_list s
        raise BadRequestError if list.empty?
        lists << list
      end
    end
    
    def parse_list s
      list = List.new
      loop do
        cond = parse_cond s
        return list if cond.nil? #No more conditions
        list << cond
      end
    end
    
    def parse_cond s
      goto_char(s, [ ")", "<", "[", "n", "N" ], true)
      first = s.slice!(0,1)
      return nil if first == ")"

      cond = nil
      
      if first == "["
        val = goto_char(s, [ "]" ], false)
        cond = Cond.new(:entity_tag, val)
        s.slice!(0,1) #removes ']' from beginning of s
      elsif first == "<"
        val = goto_char(s, [ ">" ], false)
        cond = Cond.new(:state_token, val)
        s.slice!(0,1) #removes '>' from beginning of s
      else #first = 'n'/'N'
        raise BadRequestError unless (s.slice!(0, 2)).upcase == "OT" #'N' has already been checked
        cond = parse_cond(s)
        cond.negated = true
      end
      cond
    end
    
    
    #finds the first positions of one of the required characters,
    #removes the part of the string from the beginning to that char.
    #returns the removed string
    #check_ws is true if all preceeding characters must be whitespace
    #error_if_no_found is true if an error must be raised if none of the chars is found
    def goto_char(s, chars, check_ws, error_if_not_found = true)
      regexstr = ""
      regexstr << "["
      chars.each { |c| 
        c = "\\" + c if ["(", ")", "[", "]"].include? c #escape character required in regex for (,),[ and ]
        regexstr << c 
      }
      regexstr << "]"
      i = s.index(Regexp.new(regexstr))
      if i.nil?
        raise BadRequestError if error_if_not_found
        return nil
      end
      
      result = s.slice!(0, i)
      raise BadRequestError if check_ws and !result.match(/^\s*$/)
      result
    end

  end



  #Evaluation is done according to the latest draft(17) of the RFC2518
  #According to the RFC itself:
  #        1. For a no-tag list, the condition has to be evaluated for all the requests affected by the method
  #        2. For a tag-list, tags that are not affected by the method are ignored in evaluation

  
  class Cond
    attr_reader :value
    attr_accessor :negated

    def initialize(type, value, negated = false)
      @type = type #:state_token or :entity_tag
      @value = value
      @negated = negated
    end

    def lock_token?() @type == :state_token; end

    def evaluate(resource)
      result = case @type
               when :state_token
                 uuid = Utility.locktoken_to_uuid(value)
                 resource.locked_with?(uuid)
               when :entity_tag
                 etag = value.sub(/^(W\/)?"(.*)"$/,'\2')
                 etag == resource.etag
               else
                 raise(InternalServerError,
                       "evaluating a Cond that is not a :state_token nor :entity_tag")
               end

      negated ? !result : result
    end

  end
  
  class List < Array
    
    def <<(cond)
      raise BadRequestError if cond.value.nil?
      super
    end
    
    def lock_tokens
      find_all{ |c| c.lock_token? }.map{ |c| c.value }
    end

    def evaluate(resource)
      all? { |cond| cond.evaluate resource }
    end
    
  end

  # untagged lists
  class Lists < Array

    def <<(list)
      raise BadRequestError if list.empty?
      super
    end
    
    def evaluate(resource, principal)
      Privilege.priv_read.assert_granted(resource, principal)
      any? { |l| l.evaluate resource }
    end

    def lock_tokens
      map{ |l| l.lock_tokens }.flatten.uniq
    end
    
  end
  
  class TaggedList < Array

    attr_reader :tag
    
    def initialize tag, lists
      raise BadRequestError if lists.empty?
      @lists = lists
      super lists
      uri = URI.parse(tag)
      raise MethodNotAllowedError unless /^#{BASE_WEBDAV_PATH}/.match(uri.path)
      @tag = uri.path.sub(/#{BASE_WEBDAV_PATH}/,"")
    end
    
    def lock_tokens
      @lists.lock_tokens
    end

    def each
      @lists.each { |list| yield(list) }
    end

    def evaluate(principal)
      @lists.evaluate(Bind.locate(@tag), principal)
    end
    
  end

  class TaggedLists
    include Enumerable
    
    def initialize
      @tagged_lists = []
    end
    
    def <<(tagged_list)
      @tagged_lists << tagged_list
    end
    
    def each
      @tagged_lists.each {|tagged_list| yield(tagged_list) }
    end

    # resource is ignored
    def evaluate(resource, principal)
      any? { |tl| tl.evaluate principal }
    end

    def lock_tokens
      @tagged_lists.map{ |tl| tl.lock_tokens }.flatten.uniq
    end

  end
  
end
#End of module IfHeaderParser

