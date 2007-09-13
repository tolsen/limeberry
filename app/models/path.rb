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

require 'set'

class Path < ActiveRecord::Base

  before_validation_on_create(:normalize_url,
                              :locate_bind,
                              :create_parent)

  # indented weird because emacs ruby mode stinks
  validates_format_of(:url, :with =>
                      /^\/([^\/]+(\/[^\/]+)*)?$/)

  belongs_to :bind

  acts_as_tree

  def validate
    unless self.url == '/'
      errors.add_to_base("only / can have no parent") if self.parent.nil?
      errors.add_to_base("only / can have no bind") if self.bind.nil?
    end
  end

  def basename() dir_and_base[1]; end
  def dirname() dir_and_base[0]; end

  def resource
    self.bind.nil? ? Bind.root_collection : bind.child
  end
  
  def descendants
    self.class.find(:all, :conditions => "url LIKE '#{self.url}/%'")
  end

  def create_children
    create_descendants_helper([bind], Set.new, 1.0)
    children
  end

  def create_descendants
    create_descendants_helper
    descendants
  end

  # returns hash mapping descendant urls to paths
  def descendant_urls_and_paths
    create_descendants
    Hash[*(descendants.map{ |p| [p.url, p] }.flatten)]
  end
  
  # Finds set of descendant paths that have same subpaths
  # returns list of path pairs.
  def descendant_intersection(path)
    self.create_descendants
    path.create_descendants

    prefix1_length = self.url.size + 1
    prefix2_length = path.url.size + 1
    
    matching_pairs =
      self.class.find(:all, :select => "p1.id path1, p2.id path2",
                      :joins => "AS p1 INNER JOIN paths AS p2" +
                      " ON SUBSTR(p1.url, #{prefix1_length}) = " +
                      "SUBSTR(p2.url, #{prefix2_length})",
                      :conditions => "p1.url LIKE '#{self.url}/%'" +
                      " AND p2.url LIKE '#{path.url}/%'")

    subpaths1_str = matching_pairs.sql_in_condition{ |p| p.path1 }
    subpaths2_str = matching_pairs.sql_in_condition{ |p| p.path2 }
    
    subpaths1 =
      self.class.find(:all, :conditions => "id IN #{subpaths1_str}")

    subpaths2 =
      self.class.find(:all, :conditions => "id IN #{subpaths2_str}")

    id_to_path1 = Hash[*(subpaths1.map{|p|[p.id, p]}.flatten)]
    id_to_path2 = Hash[*(subpaths2.map{|p|[p.id, p]}.flatten)]

    matching_pairs.map do |pair|
      [id_to_path1[pair.path1], id_to_path2[pair.path2]]
    end
    
  end
  
  
  private

  def normalize_url
    return false if self.url.blank?
    self.url.squeeze!('/')
    url.chomp!('/') unless url == '/'
  end

  def locate_bind
    self.bind = Bind.locate(url).path_binds.last unless self.url == '/'
  end
  
  # TODO: change this to use Bind.locate
  def create_parent
    return true if self.url == '/'
    self.parent = self.class.find_or_create_by_url(dirname)
  end
  
  def create_descendants_helper(binds = [bind],
                                binds_seen = Set.new,
                                depth = 1.0/0)
    return if binds.empty?

    binds_str = binds.sql_in_condition
    
    conditions = "b1.id IN #{binds_str}"
    conditions += " AND b2.id NOT IN #{binds_seen.sql_in_condition}" unless binds_seen.empty?

    transaction do
      new_binds = Bind.find_by_sql( 'SELECT * FROM binds AS b1 INNER JOIN binds AS b2' +
                                    ' ON b1.resource_id = b2.collection_id' +
                                    ' WHERE ' + conditions)

      # maybe have this use ON DUPLICATE instead of IGNORE?
      insert_sql =
        "INSERT IGNORE INTO paths (parent_id, bind_id, url)" +
        " SELECT p.id path_id, b2.id childbind_id, " +
        " CONCAT(p.url, '/', b2.name) child_url" +
        " FROM paths AS p INNER JOIN binds AS b1" +
        " ON p.bind_id = b1.id INNER JOIN binds b2" +
        " ON b1.resource_id = b2.collection_id" +
        " WHERE #{conditions}"

      connection.execute(insert_sql)
      create_descendants_helper(new_binds, binds_seen + binds) if depth.infinite?
    end
    
  end

  def dir_and_base
    self.url.match(/^(.*)\/([^\/]+)$/)
    dir, base = [$1, $2]
    dir = '/' if dir.empty?
    [dir, base]
  end
  

end
