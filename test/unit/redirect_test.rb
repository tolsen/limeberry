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

class RedirectTest < DavTestCase

  #   #make redirect.
  #   #covers all redirect functionality
  #   def test_make_redirect

  #     puts "Testing MAKE_REDIRECT"

  #     #make some directory for links
  #     @dir = Resource.make_directory "/", "top", Principal.limeberry
  #     @dir1 = Resource.make_directory "top", "dir1", Principal.limeberry

  #     #make different types of redirects
  #     assert_nothing_raised(StandardError){#absolute
  #     @redirect1 = Resource.make_redirect "top","redirect_test1","http://www.google.com","T", Principal.limeberry
  #     }
  #     assert_nothing_raised(StandardError){#relative
  #     @redirect2 = Resource.make_redirect "top","redirect_test2","/nitin/dir1","T", Principal.limeberry
  #     }
  #     assert_nothing_raised(StandardError){#relative to current
  #     @redirect3 = Resource.make_redirect "top","redirect_test3","dir1","T", Principal.limeberry
  #     }
  #     assert_nothing_raised(StandardError){#permanent
  #     @redirect4 = Resource.make_redirect "top","redirect_test4","http://www.yahoo.com","P", Principal.limeberry
  #     }

  #     assert_not_nil @redirect1
  #     assert_not_nil @redirect2
  #     assert_not_nil @redirect3
  #     assert_not_nil @redirect4


  #     #check created rediects
  #     assert_equal @redirect1.redirect.get_header, "302 Moved Temporarily"
  #     assert_equal @redirect4.redirect.get_header, "301 Moved Permanently"

  #     #assign a parent URL to see if the concat  is working fine
  #     @redirect3.redirect.parent_url = "http://localhost:3000/view/nitin"
  #     #check the methods within redirect
  #     #redirect3 is relative to current
  #     assert !@redirect3.redirect.absolute_target?
  #     assert !@redirect3.redirect.relative_target?
  #     assert @redirect3.redirect.relative_to_current_target?
  #     assert !@redirect1.redirect.relative_to_current_target?

  #     assert_equal @redirect3.redirect.get_target, "http://localhost:3000/view/nitin/dir1"

  #     #creating a redirect wih the same name as that of a directory
  #     assert_raise(ConflictError){
  #       @redirect5 = Resource.make_redirect "top","dir1", "/test1/test2", "T", Principal.limeberry
  #     }

  #     #create a redirect over an existing redirect,nil target'
  #     assert_nothing_raised(StandardError){
  #     @redirect6 = Resource.make_redirect "top","redirect_test4",nil,"T", Principal.limeberry
  #     }
  #     assert_equal @redirect6.redirect.lifetime,"T"
  #     assert_equal @redirect6.redirect.get_target,"http://www.yahoo.com"

  #     #create a redirect over an existing redirect,nil lifetime'
  #     assert_nothing_raised(StandardError){
  #     @redirect7 = Resource.make_redirect "top","redirect_test4","/home/nitin","P", Principal.limeberry
  #     }

  #     assert_equal @redirect7.redirect.get_target,"/home/nitin"
  #   end



end
