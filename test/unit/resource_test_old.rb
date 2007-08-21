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
require 'rexml/document'
require 'stringio'
require File.dirname(__FILE__) + '/../../lib/errors'
require File.dirname(__FILE__) + '/../../lib/if_header'

class ResourceTest < DavTestCase

  # TODO: move to functional tests
  
  #   def test_if_header_evaluate_tag_list
  #     Resource.put("/foo", StringIO.new("arbit"),
  #                       "text/plain", @limeberry)

  #     foo = Bind.locate("/foo")
  #     foo_etag_str = "\"" + foo.etag + "\""
  #     cond1 = Cond.new
  #     cond1.value = foo_etag_str
  #     cond1.type = :entity_tag
  #     cond2 = Cond.new
  #     cond2.value = "random string"
  #     cond2.type = :entity_tag
  #     list1 = List.new
  #     list1.add_cond(cond1)
  #     list1.add_cond(cond2)
  #     lists = Lists.new
  #     lists.add_list list1
  #     tl = TagList.new
  #     tl.add_tag_list_element(TagListElement.new("/limeberry/foo", lists))
  #     assert(!Resource.evaluate_tag_list(tl, @limeberry))
  #     cond2.not = true
  #     assert(Resource.evaluate_tag_list(tl, @limeberry))

  #     cond2.not = false
  #     list1 = List.new
  #     list1.add_cond(cond1)
  #     list2 = List.new
  #     list2.add_cond(cond2)
  #     lists = Lists.new
  #     lists.add_list list1
  #     lists.add_list list2
  #     tl = TagList.new
  #     tl.add_tag_list_element(TagListElement.new("/limeberry/foo", lists))
  #     assert(Resource.evaluate_tag_list(tl, @limeberry))

  #     Resource.put("/foo1", StringIO.new("arbit1"), "text/plain",
  #                       :principal => @limeberry)

  #     foo1 = Bind.locate("/foo1")
  #     foo1_etag_str = "\"" + foo1.etag + "\""

  #     cond1 = Cond.new
  #     cond1.value = foo_etag_str
  #     cond1.type = :entity_tag
  #     cond2 = Cond.new
  #     cond2.value = foo1_etag_str
  #     cond2.type = :entity_tag
  #     list1 = List.new
  #     list1.add_cond(cond1)
  #     list2 = List.new
  #     list2.add_cond(cond2)
  #     lists1 = Lists.new
  #     lists2 = Lists.new
  #     lists1.add_list list1
  #     lists2.add_list list2
  #     tl = TagList.new
  #     tl.add_tag_list_element(TagListElement.new("/limeberry/foo", lists1))
  #     tl.add_tag_list_element(TagListElement.new("/limeberry/foo1", lists2))
  #     assert(Resource.evaluate_tag_list(tl, @limeberry))
  #     cond2.not = true
  #     assert(!Resource.evaluate_tag_list(tl, @limeberry))

  #     Resource.dav_delete("/foo", :principal => @limeberry)
  #     Resource.dav_delete("/foo1", :principal => @limeberry)
  #   end



  # TODO: move to functional tests  
  #   def test_lock_refresh
  #     opts = get_lock_args

  #     AppConfig.default_timeout = 2.hour

  #     dir_info = Bind.locate_detailed("/dir")
  #     dir = dir_info[:resource]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 2.hour + 1) && (approx_given_timeout > 2.hour - 5))

  #     opts[:timeout] = "Second-3600"
  #     opts[:if_locktokens] = [lock.uuid]
  #     response = Resource.lock_refresh("/dir", opts)
  #     assert_equal 200, response.status.code

  #     lock.reload
  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 1.hour + 1) && (approx_given_timeout > 1.hour - 5))
  #   end

  #   def test_lock_refresh_errors
  #     opts = get_lock_args

  #     # refreshing a res not locked.
  #     opts[:if_locktokens] = ["wrongtoken"]
  #     assert_raise(PreconditionFailedError) {
  #       Resource.lock_refresh("/dir", opts)
  #     }

  #     dir_info = Bind.locate_detailed("/dir/")
  #     dir = dir_info[:resource]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     # more than 1 locktokens in if-header
  #     opts[:if_locktokens] = [lock.uuid, "extra_errorraising_token"]
  #     assert_raise(PreconditionFailedError) {
  #       Resource.lock_refresh("/dir", opts)
  #     }

  #     # less than 1 locktoken in if-header
  #     opts[:if_locktokens] = []
  #     assert_raise(PreconditionFailedError) {
  #       Resource.lock_refresh("/dir", opts)
  #     }

  #     Privilege.priv_write.grant(@collection,@user)
  #     opts[:principal] = @user
  #     userlock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     # refreshing lock of someone else
  #     opts[:if_locktokens] = [lock.uuid]
  #     assert_raise(ConflictError) {
  #       Resource.lock_refresh("/dir", opts)
  #     }

  #     # refreshing a lock is a real thing and dosen't always raises an error :)
  #     opts[:if_locktokens] = [userlock.uuid]

  #     response = Resource.lock_refresh("/dir", opts)
  #     assert_equal 200, response.status.code
  #   end

  #   def test_lock_timeout
  #     opts = get_lock_args

  #     # explicitly setting timeout to make tests independent of configuration
  #     AppConfig.max_timeout = 2.hour
  #     AppConfig.default_timeout = 1.hour

  #     dir_info = Bind.locate_detailed("/dir/")
  #     dir = dir_info[:resource]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 1.hour + 1) && (approx_given_timeout > 1.hour - 5))

  #     opts[:timeout] = ["10000"]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 2.hour + 1) && (approx_given_timeout > 2.hour - 5))


  #     opts[:timeout] = ["120"]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 2.minute + 1) && (approx_given_timeout > 2.minute - 5))

  #     opts[:timeout] = ["infinite", "infinite"]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 2.hour + 1) && (approx_given_timeout > 2.hour - 5))

  #     opts[:timeout] = ["infinite", "120", "70", "2400", "infinite"]
  #     lock = dir.lock("/dir", dir_info[:binds], opts)[:lock]

  #     approx_given_timeout = lock.expires_at - Time.now
  #     assert((approx_given_timeout < 2.minute + 1) && (approx_given_timeout > 2.minute - 5))
  #   end

  #   def test_lock_unlock_collection
  #     opts = get_lock_args
  #     Collection.mkcol("/dir/dir1", :principal => @limeberry)
  #     Resource.put("/dir/dir1/src1", StringIO.new("123456"),
  #                       "text/plain", :principal => @limeberry)

  #     Collection.bind("/dir/src", "/dir/dir1", "src", opts)

  #     response = Resource.lock("/dir", opts)
  #     response1 = Resource.lock("/dir", opts)

  #     dir1 = Bind.locate("/dir/dir1")
  #     src1 = Bind.locate("/dir/dir1/src1")

  #     assert_equal 2, @collection.direct_locks.length
  #     assert_equal 2, @collection.locks.length
  #     assert_equal 2, @resource.locks.length
  #     assert_equal 2, dir1.locks.length
  #     assert_equal 2, src1.locks.length
  #     assert_equal 0, @resource.direct_locks.length

  #     opts[:locktoken] = response["Lock-Token"]
  #     Resource.unlock("/dir/", opts)

  #     @collection.reload; @resource.reload; dir1.reload; src1.reload
  #     assert_equal 1, @collection.direct_locks.length
  #     assert_equal 1, @collection.locks.length
  #     assert_equal 1, @resource.locks.length
  #     assert_equal 1, dir1.locks.length
  #     assert_equal 1, src1.locks.length

  #     opts[:locktoken] = response1["Lock-Token"]
  #     Resource.unlock("/dir/", opts)

  #     @collection.reload; @resource.reload; dir1.reload; src1.reload
  #     assert_equal 0, @collection.direct_locks.length
  #     assert_equal 0, @collection.locks.length
  #     assert_equal 0, @resource.locks.length
  #     assert_equal 0, dir1.locks.length
  #     assert_equal 0, src1.locks.length

  #     response = Resource.lock("/dir/dir1/src1", opts)
  #     src1.reload
  #     assert_equal 1, src1.direct_locks.length
  #     assert_equal 1, src1.locks.length

  #     opts[:xmlrequest]["lockscope"] = "exclusive"

  #     response = Resource.lock("/dir", opts)
  #     assert_equal 207, response.status.code

  #     @collection.reload; @resource.reload; dir1.reload; src1.reload
  #     assert_equal 0, @collection.direct_locks.length
  #     assert_equal 0, @collection.locks.length
  #     assert_equal 0, @resource.locks.length
  #     assert_equal 0, dir1.locks.length
  #     assert_equal 1, src1.direct_locks.length
  #     assert_equal 1, src1.locks.length
  #   end

  # move to functional test
  #   def test_move_bad_request
  #     assert_raise(BadRequestError) {
  #       Resource.move(@collectionpath,"/random",
  #                          :depth => "0",
  #                          :principal => @limeberry)
  #     }
  #   end


  #   def test_proppatch
  #     namespace,property,value,options = get_proppatch_args
  #     options[:updates].push(:namespace => namespace,:name => property,:method => "remove")

  #     @resource.proppatch(@resourcepath,options)
  #     assert_raise(NotFoundError) {
  #       @resource.propfind_one(namespace,property)
  #     }

  #   end

  #   def test_proppatch_locked_resource
  #     namespace,property,value,options = get_proppatch_args
  #     lock_params = get_lock_args
  #     lock_uuid = lock_resource_and_get_uuid(@resourcepath,lock_params)
  #     options[:principal] = @limeberry
  #     assert_raise(LockedError) {
  #       Resource.proppatch(@resourcepath,options)
  #     }
  #     options[:if_locktokens] = lock_uuid
  #     assert_nothing_raised() {
  #       @resource.proppatch(@resourcepath,options)
  #     }
  #     Privilege.priv_write.grant(@resource,@user)
  #     options[:principal] = @user
  #     assert_raise(LockedError) {
  #       Resource.proppatch(@resourcepath,options)
  #     }
  #   end

  #   def test_proppatch_permissions
  #     namespace,property,value,options = get_proppatch_args
  #     Privilege.priv_write_properties.deny(@resource,@user)

  #     options[:principal] = @user
  #     assert_raise(ForbiddenError) {
  #       Resource.proppatch(@resourcepath,options)
  #     }
  #   end


  #   def test_unlock_errors
  #     opts = get_lock_args
  #     response = Resource.lock("/dir/src", opts)

  #     Privilege.priv_read.grant(@resource,@user)
  #     assert_raise(ForbiddenError) {
  #       Resource.unlock("/dir/src", :principal => @user,
  #                            :locktoken => response["Lock-Token"])
  #     }

  #     Privilege.priv_write.grant(@resource,@user)
  #     assert_raise(ConflictError) {
  #       Resource.unlock("/dir/src", :principal => @user,
  #                            :locktoken => response["Lock-Token"])
  #     }

  #     Privilege.priv_unlock.grant(@resource,@user)
  #     assert_nothing_raised() {
  #       Resource.unlock("/dir/src", :principal => @user,
  #                            :locktoken => response["Lock-Token"])
  #     }
  #   end

  #   def test_unlock_locktoken_required
  #     lock_args = get_lock_args
  #     response = Resource.lock("/dir/src",lock_args)

  #     assert_raise(ConflictError) {
  #       Resource.unlock("/dir/src",:principal => @limeberry,
  #                            :locktoken => "wronglocktoken")
  #     }
  #     assert_nothing_raised() {
  #       Resource.unlock("/dir/src",:principal => @limeberry,
  #                            :locktoken => response["Lock-Token"])
  #     }
  #     assert(!@resource.locked?)
  #   end

  #   def test_unlock_multiple_locks_present
  #     opts = get_lock_args
  #     Collection.mkcol("/dir1", :principal => @limeberry)
  #     Collection.bind("/dir/src", "/dir1", "src1", opts)

  #     Resource.lock("/dir/src", opts)
  #     response = Resource.lock("/dir/src", opts)
  #     assert_equal 200, response.status.code

  #     response1 = Resource.lock("/dir1/src1", opts)
  #     assert_equal 200, response1.status.code

  #     src = Bind.locate("/dir/src")
  #     assert_equal 3, src.direct_locks.length

  #     opts[:locktoken] = response["Lock-Token"]

  #     assert_nothing_raised() {
  #       Resource.unlock("/dir/src/", opts)
  #     }

  #     src.reload
  #     assert_equal 2, src.direct_locks.length

  #     opts[:locktoken] = response1["Lock-Token"]
  #     assert_nothing_raised() {
  #       Resource.unlock("/dir1/src1", opts)
  #     }

  #     src.reload
  #     assert_equal 1, src.direct_locks.length
  #   end

  #   def test_unlock_resource_not_locked
  #     assert_raise(ConflictError) {
  #       Resource.unlock("/dir/", :principal => @limeberry,
  #                            :locktoken => "empty")
  #     }
  #   end

end

