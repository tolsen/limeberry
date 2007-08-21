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

class AclNode < ActiveRecord::Base

  set_primary_key "resource_id"
  set_table_name "acl_inheritance"

  belongs_to :resource

  # name it base instead of root so as
  # not to conflict with root method in
  # NestedSet
  #    acts_as_nested_set( :scope => :base_id )

  acts_as_nested_set

  def before_destroy
    super
    @parent = reload.parent
  end

  def after_destroy
    super
    @parent.destroy unless @parent.nil? || @parent.reload.necessary?
  end

  protected

  # overrides BetterNestedSet#move_to
  def move_to(target, position)
    par = parent
    super
    par.destroy unless par.nil? || par.reload.necessary?
    self
  end

  # An acl_node is necessary if it has a parent or has children
  def necessary?
    parent || (children_count > 0)
  end

end
