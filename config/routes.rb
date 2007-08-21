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

ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  map.connect("#{BASE_WEBDAV_PATH}/users/:name",
              :controller => "principal",
              :action => "put_user", :conditions => {:method => :put})
              
  
  map.connect("#{BASE_WEBDAV_PATH}/groups/:name",
              :controller => "principal",
              :action => "put_group", :conditions => {:method => :put})

  {
    "http"   => %w( head get put options delete ),
    "webdav" => %w( propfind proppatch mkcol copy move ),
    "lock"  => %w( lock unlock ),
    "bind"   => %w( bind unbind rebind ),
    "deltav" => %w( version-control checkin checkout ),
    "acl"    => %w( acl )
  }.each do |controller, methods|
    methods.each do |method|
      action = method.gsub(/-/, '_')
      map.connect("#{BASE_WEBDAV_PATH}/*path",
                  :controller => controller,
                  :action => action,
                  :conditions => { :method => method })
    end
  end

  map.connect("#{BASE_WEBDAV_PATH}/*path",
              :controller => "http",
              :action => "method_not_implemented")
  
end
