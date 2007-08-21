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

class AddDefaultPrivileges < ActiveRecord::Migration
  def self.up
    # The hierarchy is:
    #
    #     DAV:all
    #      DAV:read
    #      DAV:read-acl
    #      DAV:read-current-user-privilege-set
    #      DAV:write
    #         DAV:write-properties
    #         DAV:write-content
    #         DAV:bind
    #         DAV:unbind
    #      DAV:write-acl
    #      DAV:unlock

    dav = Namespace.create! :name => "DAV:"

    priv_all = Privilege.create!( :name => "all",
                                  :namespace => dav,
                                  :description => 'Any operation' )

    { 'read' => 'Read content or properties',
      'read-acl' => 'Read access control list',
      'read-current-user-privilege-set' => 'Read privileges granted',
      'write-acl' => 'Write to the access control list',
      'unlock' => 'Unlock regardless of lock ownership' }.each do |name, desc|
      p = Privilege.create!( :name => name,
                             :namespace => dav,
                             :description => desc )
      p.move_to_child_of(priv_all)
    end

    priv_write = Privilege.create!( :name => "write",
                                    :namespace => dav,
                                    :description =>
                                    'Modify the resource (except for its access control list)')
    priv_write.move_to_child_of(priv_all)

    { 'write-properties' => 'Write properties',
      'write-content' => 'Write content',
      'bind' => 'Add resource to collection',
      'unbind' => 'Remove resource from collection' }.each do |name, desc|
      p = Privilege.create!( :name => name,
                             :namespace => dav,
                             :description => desc )
      p.move_to_child_of(priv_write)
    end
  end

  def self.down
    Privilege.destroy_all
    Namespace.destroy_all
  end
end
