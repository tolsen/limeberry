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

class AddPrincipalDirectories < ActiveRecord::Migration
  def self.up
    [ Principal::PRINCIPALS_COLLECTION_PATH,
      User::USERS_COLLECTION_PATH,
      Group::GROUPS_COLLECTION_PATH,
      User::HOME_COLLECTION_PATH ].each do |path|
      Collection.mkcol_p(path, Principal.limeberry)
    end


    Principal.principals_collection.bind(Principal.limeberry,
                                         Principal.limeberry.name,
                                         Principal.limeberry)
  end

  def self.down
    [ Principal::PRINCIPALS_COLLECTION_PATH,
      User::USERS_COLLECTION_PATH,
      Group::GROUPS_COLLECTION_PATH,
      User::HOME_COLLECTION_PATH ].each do |path|
      Resource.dav_delete(path, Principal.limeberry)
    end
  end

end
