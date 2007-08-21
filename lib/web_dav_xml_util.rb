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

require "rexml_fixes"
require "constants"

module WebDavXmlUtil
  include REXML

  # User creation.
  def parse_put_user(target, reqxml)
    return_arr = Array.new
    document = Document.new reqxml
    root = document.root
    raise BadRequestError unless (root.name == Limeberry::USER_ELEM)
    #raise BadRequestError unless (root.namespace == Limeberry::DAV_NS and root.name == Limeberry::USER_ELEM)
    ret_hash = Hash.new
    # Cannot use Hash.from_xml because it does not validate namespace information.

    root.each_element {|e|
      # check for "displayname"
      if e.name == Limeberry::DISPLAYNAME_ELEM
        raise BadRequestError unless ret_hash[e.name].nil?
        ret_hash[e.name] = e.text

        # check for "name"
      elsif e.name == Limeberry::NAME_ELEM
        raise BadRequestError unless ret_hash[e.name].nil? and e.text == target
        ret_hash[e.name] = e.text

        # check for "password"
      elsif e.name == Limeberry::PASSWORD_ELEM
        raise BadRequestError unless ret_hash[e.name].nil?
        ret_hash[e.name] = e.text
      end
    }

    # If name field is empty fill it up.
    ret_hash[Limeberry::NAME_ELEM]=target if ret_hash[Limeberry::NAME_ELEM].nil?

    # Displayname is not a required field.
    
    raise BadRequestError unless (ret_hash.has_key?(Limeberry::NAME_ELEM) && ret_hash.has_key?(Limeberry::PASSWORD_ELEM))
    # Turn the string keys into symbols
    ret_hash.each{|key,val|
      ret_hash.delete(key)
      ret_hash[key.to_sym]=val
    }

    ret_hash
  rescue ParseException
    raise BadRequestError
  end
  
  # Group creation. 
  def parse_put_group(target, reqxml, authenticated_user)
    return_arr = Array.new
    document = Document.new reqxml
    root = document.root
    raise BadRequestError unless (root.name == Limeberry::GROUP_ELEM)
    ret_hash = Hash.new
    # Cannot use Hash.from_xml because it does not validate namespace information.   

    root.each_element {|e|
      # check for "displayname"
      if e.name == Limeberry::DISPLAYNAME_ELEM
        raise BadRequestError unless ret_hash[e.name].nil?
        ret_hash[e.name] = e.text
        
        # check for "name"
      elsif e.name == Limeberry::NAME_ELEM
        raise BadRequestError unless ret_hash[e.name].nil? and e.text == target
        ret_hash[e.name] = e.text
        
        # check for "creator"
      elsif e.name == Limeberry::CREATOR_ELEM
        raise BadRequestError unless ret_hash[e.name].nil?
        ret_hash[e.name] = e.text
        
        # check for "owner"
      elsif e.name == Limeberry::OWNER_ELEM
        raise BadRequestError unless ret_hash[e.name].nil?
        ret_hash[e.name] = e.text
      end
    }
    
    # If name,owner,creator field is empty fill them up.
    ret_hash[Limeberry::NAME_ELEM]=target if ret_hash[Limeberry::NAME_ELEM].nil?
    ret_hash[Limeberry::OWNER_ELEM]=authenticated_user if ret_hash[Limeberry::OWNER_ELEM].nil?
    ret_hash[Limeberry::CREATOR_ELEM]=authenticated_user if ret_hash[Limeberry::CREATOR_ELEM].nil?
    
    # Displayname is not a required field.   
    raise BadRequestError unless (ret_hash.has_key?(Limeberry::NAME_ELEM) && ret_hash.has_key?(Limeberry::CREATOR_ELEM))
    # Turn the string keys into symbols
    ret_hash.each{|key,val| 
      ret_hash.delete(key)
      ret_hash[key.to_sym]=val
    }  
    
    ret_hash
  rescue ParseException
    raise BadRequestError
  end


end
