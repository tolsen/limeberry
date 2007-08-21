module SymetrieCom
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      def self.append_features(base)
        super
        base.extend(ClassMethods)
      end

      # better_nested_set ehances the core nested_set tree functionality provided in ruby_on_rails.
      #
      # This acts provides Nested Set functionality. Nested Set is a smart way to implement
      # an _ordered_ tree, with the added feature that you can select the children and all of their
      # descendents with a single query. The drawback is that insertion or move need some complex
      # sql queries. But everything is done here by this module!
      #
      # Nested sets are appropriate each time you want either an orderd tree (menus,
      # commercial categories) or an efficient way of querying big trees (threaded posts).
      #
      # == API
      # Methods names are aligned on Tree's ones as much as possible, to make replacment from one
      # by another easier, except for the creation:
      #
      # in acts_as_tree:
      #   item.children.create(:name => "child1")
      #
      # in acts_as_nested_set:
      #   # adds a new item at the "end" of the tree, i.e. with child.left = max(tree.right)+1
      #   child = MyClass.new(:name => "child1")
      #   child.save
      #   # now move the item to its right place
      #   child.move_to_child_of my_item
      #
      # You can use:
      # * move_to_child_of
      # * move_to_right_of
      # * move_to_left_of
      # and pass them an id or an object.
      #
      # Other methods added by this mixin are:
      # * +root+ - root item of the tree (the one that has a nil parent; should have left_column = 1 too)
      # * +roots+ - root items, in case of multiple roots (the ones that have a nil parent)
      # * +level+ - number indicating the level, a root being level 0
      # * +ancestors+ - array of all parents, with root as first item
      # * +self_and_ancestors+ - array of all parents and self
      # * +siblings+ - array of all siblings, that are the items sharing the same parent and level
      # * +self_and_siblings+ - array of itself and all siblings
      # * +children_count+ - count of all immediate children
      # * +children+ - array of all immediate childrens
      # * +all_children+ - array of all children and nested children
      # * +full_set+ - array of itself and all children and nested children
      #
      # These should not be useful, except if you want to write direct SQL:
      # * +left_col_name+ - name of the left column passed on the declaration line
      # * +right_col_name+ - name of the right column passed on the declaration line
      # * +parent_col_name+ - name of the parent column passed on the declaration line
      #
      # recommandations:
      # Don't name your left and right columns 'left' and 'right': these names are reserved on most of dbs.
      # Usage is to name them 'lft' and 'rgt' for instance.
      #
      module ClassMethods
        # Configuration options are:
        #
        # * +parent_column+ - specifies the column name to use for keeping the position integer (default: parent_id)
        # * +left_column+ - column name for left boundry data, default "lft"
        # * +right_column+ - column name for right boundry data, default "rgt"
        # * +text_column+ - column name for the title field (optional). Used as default in the
        #   {your-class}_options_for_select helper method. If empty, will use the first string field
        #   of your model class.
        # * +scope+ - restricts what is to be considered a list. Given a symbol, it'll attach "_id"
        #   (if that hasn't been already) and use that as the foreign key restriction. It's also possible
        #   to give it an entire string that is interpolated if you need a tighter scope than just a foreign key.
        #   Example: <tt>acts_as_nested_set :scope => 'todo_list_id = #{todo_list_id} AND completed = 0'</tt>
        def acts_as_nested_set(options = {})
          if options[:scope].is_a?(Symbol)
            if options[:scope].to_s !~ /_id$/
              options[:scope] = "#{options[:scope]}_id".intern
            end
            options[:scope] = %(#{options[:scope].to_s}.nil? ? "#{options[:scope].to_s} IS NULL" : "#{options[:scope].to_s} = \#{#{options[:scope].to_s}}")
          end

#            options[:scope] = %("#{options[:scope]}")

          write_inheritable_attribute(:acts_as_nested_set_options,
             { :parent_column  => (options[:parent_column] || 'parent_id'),
               :left_column    => (options[:left_column]   || 'lft'),
               :right_column   => (options[:right_column]  || 'rgt'),
               :scope          => (options[:scope] || '1 = 1'),
               :text_column    => (options[:text_column] || columns.collect{|c| (c.type == :string) ? c.name : nil }.compact.first),
               :class          => self
              } )

          class_inheritable_reader :acts_as_nested_set_options

          # no bulk assignment
          attr_protected  acts_as_nested_set_options[:left_column].intern,
                          acts_as_nested_set_options[:right_column].intern,
                          acts_as_nested_set_options[:parent_column].intern
          # no assignment to structure fields
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{acts_as_nested_set_options[:left_column]}=(x)
              raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{acts_as_nested_set_options[:left_column]}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
            end
            def #{acts_as_nested_set_options[:right_column]}=(x)
              raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{acts_as_nested_set_options[:right_column]}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
            end
            def #{acts_as_nested_set_options[:parent_column]}=(x)
              raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{acts_as_nested_set_options[:parent_column]}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
            end
          end_eval

          include SymetrieCom::Acts::NestedSet::InstanceMethods
          extend SymetrieCom::Acts::NestedSet::ClassMethods

          # adds the helper for the class
#          ActionView::Base.send(:define_method, "#{Inflector.underscore(acts_as_nested_set_options[:class])}_options_for_select") { special=nil
#              "#{acts_as_nested_set_options[:text_column]} || "#{acts_as_nested_set_options[:class]} id #{id}"
#            }

        end

        # Returns the single root
        def root
          self.find(:first, :conditions => "(#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:parent_column]} IS NULL)")
        end

        # Returns roots when multiple roots (or virtual root, which is the same)
        def roots
          self.find(:all, :conditions => "(#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:parent_column]} IS NULL)", :order => "#{acts_as_nested_set_options[:left_column]}")
        end
      end

      module InstanceMethods
        def left_col_name() acts_as_nested_set_options[:left_column] end
        def right_col_name() acts_as_nested_set_options[:right_column] end
        def parent_col_name() acts_as_nested_set_options[:parent_column] end

        # on creation, set automatically lft and rgt to the end of the tree
        def before_create
          maxright = acts_as_nested_set_options[:class].maximum(acts_as_nested_set_options[:right_column], :conditions => acts_as_nested_set_options[:scope]) || 0
          # adds the new node to the right of all existing nodes
          self[acts_as_nested_set_options[:left_column]] = maxright+1
          self[acts_as_nested_set_options[:right_column]] = maxright+2
        end

        # Returns true if this is a root node.
        def root?
          parent_id = self[acts_as_nested_set_options[:parent_column]]
          (parent_id == 0 || parent_id.nil?) && (self[acts_as_nested_set_options[:left_column]] == 1) && (self[acts_as_nested_set_options[:right_column]] > self[acts_as_nested_set_options[:left_column]])
        end

        # Returns true is this is a child node
        def child?
          parent_id = self[acts_as_nested_set_options[:parent_column]]
          !(parent_id == 0 || parent_id.nil?) && (self[acts_as_nested_set_options[:left_column]] > 1) && (self[acts_as_nested_set_options[:right_column]] > self[acts_as_nested_set_options[:left_column]])
        end

        # Returns true if we have no idea what this is
        #
        # Deprecated, will be removed in next versions
        def unknown?
          !root? && !child?
        end

        # order by left column
        def <=>(x)
          self[acts_as_nested_set_options[:left_column]] <=> x[acts_as_nested_set_options[:left_column]]
        end

        # Adds a child to this object in the tree.  If this object hasn't been initialized,
        # it gets set up as a root node.  Otherwise, this method will update all of the
        # other elements in the tree and shift them to the right, keeping everything
        # balanced.
        #
        # Deprecated, will be removed in next versions
        def add_child( child )
          self.reload
          child.reload

          if child.root?
            raise ActiveRecord::ActiveRecordError, "Adding sub-tree isn\'t currently supported"
          else
            if ( (self[acts_as_nested_set_options[:left_column]] == nil) || (self[acts_as_nested_set_options[:right_column]] == nil) )
              # Looks like we're now the root node!  Woo
              self[acts_as_nested_set_options[:left_column]] = 1
              self[acts_as_nested_set_options[:right_column]] = 4

              # What do to do about validation?
              return nil unless self.save

              child[acts_as_nested_set_options[:parent_column]] = self.id
              child[acts_as_nested_set_options[:left_column]] = 2
              child[acts_as_nested_set_options[:right_column]]= 3
              return child.save
            else
              # OK, we need to add and shift everything else to the right
              child[acts_as_nested_set_options[:parent_column]] = self.id
              right_bound = self[acts_as_nested_set_options[:right_column]]
              child[acts_as_nested_set_options[:left_column]] = right_bound
              child[acts_as_nested_set_options[:right_column]] = right_bound + 1
              self[acts_as_nested_set_options[:right_column]] += 2
              acts_as_nested_set_options[:class].transaction {
                acts_as_nested_set_options[:class].update_all( "#{acts_as_nested_set_options[:left_column]} = (#{acts_as_nested_set_options[:left_column]} + 2)",  "#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:left_column]} >= #{right_bound}" )
                acts_as_nested_set_options[:class].update_all( "#{acts_as_nested_set_options[:right_column]} = (#{acts_as_nested_set_options[:right_column]} + 2)",  "#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:right_column]} >= #{right_bound}" )
                self.save
                child.save
              }
            end
          end
        end

        # Returns root
        def root
            acts_as_nested_set_options[:class].find(:first, :conditions => "#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:parent_column]} IS NULL)")
        end

        # Returns roots when multiple roots (or virtual root, which is the same)
        def roots
            acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:parent_column]} IS NULL)", :order => "#{acts_as_nested_set_options[:left_column]}")
        end

        # Returns the parent
        def parent
            acts_as_nested_set_options[:class].find(self[acts_as_nested_set_options[:parent_column]]) if self[acts_as_nested_set_options[:parent_column]]
        end

        # Returns an array of all parents
        # Maybe 'full_outline' would be a better name, but we prefer to mimic the Tree class
        def ancestors
            acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:left_column]} < #{self[acts_as_nested_set_options[:left_column]]} and #{acts_as_nested_set_options[:right_column]} > #{self[acts_as_nested_set_options[:right_column]]})", :order => acts_as_nested_set_options[:left_column] )
        end

        # Returns the array of all parents and self
        def self_and_ancestors
            ancestors + [self]
        end

        # Returns the array of all children of the parent, except self
        def siblings
            self_and_siblings - [self]
        end

        # Returns the array of all children of the parent, included self
        def self_and_siblings
            if self[acts_as_nested_set_options[:parent_column]].nil? || self[acts_as_nested_set_options[:parent_column]].zero?
                [self]
            else
                acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} and #{acts_as_nested_set_options[:parent_column]} = #{self[acts_as_nested_set_options[:parent_column]]}", :order => acts_as_nested_set_options[:left_column])
            end
        end

        # Returns the level of this object in the tree
        # root level is 0
        def level
            return 0 if self[acts_as_nested_set_options[:parent_column]].nil?
            acts_as_nested_set_options[:class].count("#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:left_column]} < #{self[acts_as_nested_set_options[:left_column]]} and #{acts_as_nested_set_options[:right_column]} > #{self[acts_as_nested_set_options[:right_column]]})")
        end

        # Returns the number of nested children of this object.
        def children_count
          return (self[acts_as_nested_set_options[:right_column]] - self[acts_as_nested_set_options[:left_column]] - 1)/2
        end

        # Returns a set of itself and all of its nested children
        # Pass :exclude => item, or id, or [items or id] to exclude some parts of the tree
        def full_set(special=nil)
          return [self] if new_record? or self[acts_as_nested_set_options[:right_column]]-self[acts_as_nested_set_options[:left_column]] == 1
#          acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:left_column]} BETWEEN #{self[acts_as_nested_set_options[:left_column]]} and #{self[acts_as_nested_set_options[:right_column]]})", :order => acts_as_nested_set_options[:left_column])
          [self] + all_children(special)
        end

        # Returns a set of all of its children and nested children
        # Pass :exclude => item, or id, or [items or id] to exclude some parts of the tree
        def all_children(special=nil)
          if special && special[:exclude]
            transaction do
              # exclude some items and all their children
              special[:exclude] = [special[:exclude]] if !special[:exclude].is_a?(Array)
              # get objects for ids
              special[:exclude].collect! {|s| s.is_a?(acts_as_nested_set_options[:class]) ? s : acts_as_nested_set_options[:class].find(s)}
              # get all subtrees and flatten the list
              exclude_list = special[:exclude].map{|e| e.full_set.map{|ee| ee.id}}.flatten.uniq.join(',')
              if exclude_list.blank?
                acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:left_column]} > #{self[acts_as_nested_set_options[:left_column]]}) and (#{acts_as_nested_set_options[:right_column]} < #{self[acts_as_nested_set_options[:right_column]]})", :order => acts_as_nested_set_options[:left_column])
              else
                acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND id NOT IN (#{exclude_list}) AND (#{acts_as_nested_set_options[:left_column]} > #{self[acts_as_nested_set_options[:left_column]]}) and (#{acts_as_nested_set_options[:right_column]} < #{self[acts_as_nested_set_options[:right_column]]})", :order => acts_as_nested_set_options[:left_column])
              end
            end
          else
            acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND (#{acts_as_nested_set_options[:left_column]} > #{self[acts_as_nested_set_options[:left_column]]}) and (#{acts_as_nested_set_options[:right_column]} < #{self[acts_as_nested_set_options[:right_column]]})", :order => acts_as_nested_set_options[:left_column])
          end
        end

        # Returns a set of only this entry's immediate children
        def children
            acts_as_nested_set_options[:class].find(:all, :conditions => "#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:parent_column]} = #{self.id}", :order => acts_as_nested_set_options[:left_column])
        end

        # Prunes a branch off of the tree, shifting all of the elements on the right
        # back to the left so the counts still work.
        def before_destroy
          return if self[acts_as_nested_set_options[:right_column]].nil? || self[acts_as_nested_set_options[:left_column]].nil?
          dif = self[acts_as_nested_set_options[:right_column]] - self[acts_as_nested_set_options[:left_column]] + 1

          acts_as_nested_set_options[:class].transaction {
            acts_as_nested_set_options[:class].delete_all( "#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:left_column]} > #{self[acts_as_nested_set_options[:left_column]]} and #{acts_as_nested_set_options[:right_column]} < #{self[acts_as_nested_set_options[:right_column]]}" )
            acts_as_nested_set_options[:class].update_all( "#{acts_as_nested_set_options[:left_column]} = (#{acts_as_nested_set_options[:left_column]} - #{dif})",  "#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:left_column]} >= #{self[acts_as_nested_set_options[:right_column]]}" )
            acts_as_nested_set_options[:class].update_all( "#{acts_as_nested_set_options[:right_column]} = (#{acts_as_nested_set_options[:right_column]} - #{dif} )",  "#{acts_as_nested_set_options[:scope]} AND #{acts_as_nested_set_options[:right_column]} >= #{self[acts_as_nested_set_options[:right_column]]}" )
          }
        end

        # Move the node to the left of another node (you can pass id only)
        def move_to_left_of(node)
            self.move_to node, :left
        end

        # Move the node to the left of another node (you can pass id only)
        def move_to_right_of(node)
            self.move_to node, :right
        end

        # Move the node to the child of another node (you can pass id only)
        def move_to_child_of(node)
            self.move_to node, :child
        end

        protected
        def move_to(target, position)
          raise ActiveRecord::ActiveRecordError, "You cannot move a new node" if self.id.nil?

          # use shorter names for readability: current left and right
          cur_left, cur_right = self[acts_as_nested_set_options[:left_column]], self[acts_as_nested_set_options[:right_column]]

          # extent is the width of the tree self and children
          extent = cur_right - cur_left + 1

          # load object if node is not an object
          if !(target.kind_of? acts_as_nested_set_options[:class])
            target = acts_as_nested_set_options[:class].find(target)
          end
          target_left, target_right = target[acts_as_nested_set_options[:left_column]], target[acts_as_nested_set_options[:right_column]]

          # detect impossible move
          if ((cur_left <= target_left) && (target_left <= cur_right)) or ((cur_left <= target_right) && (target_right <= cur_right))
            raise ActiveRecord::ActiveRecordError, "Impossible move, target node cannot be inside moved tree."
          end

          # compute new left/right for self
          if position == :child
            if target_left < cur_left
              new_left  = target_left + 1
              new_right = target_left + extent
            else
              new_left  = target_left - extent + 1
              new_right = target_left
            end
          elsif position == :left
            if target_left < cur_left
              new_left  = target_left
              new_right = target_left + extent - 1
            else
              new_left  = target_left - extent
              new_right = target_left - 1
            end
          elsif position == :right
            if target_right < cur_right
              new_left  = target_right + 1
              new_right = target_right + extent
            else
              new_left  = target_right - extent + 1
              new_right = target_right
            end
          else
            raise ActiveRecord::ActiveRecordError, "Position should be either left or right ('#{position}' received)."
          end

          # boundaries of update action
          b_left, b_right = [cur_left, new_left].min, [cur_right, new_right].max

          # Shift value to move self to new position
          shift = new_left - cur_left

          # Shift value to move nodes inside boundaries but not under self_and_children
          updown = (shift > 0) ? -extent : extent

          # change nil to NULL for new parent
          if position == :child
            new_parent = target.id
          else
            new_parent = target[acts_as_nested_set_options[:parent_column]].nil? ? 'NULL' : target[acts_as_nested_set_options[:parent_column]]
          end

          # update and that rules
          acts_as_nested_set_options[:class].update_all( "#{acts_as_nested_set_options[:left_column]} = CASE \
                                      WHEN #{acts_as_nested_set_options[:left_column]} BETWEEN #{cur_left} AND #{cur_right} \
                                        THEN #{acts_as_nested_set_options[:left_column]} + #{shift} \
                                      WHEN #{acts_as_nested_set_options[:left_column]} BETWEEN #{b_left} AND #{b_right} \
                                        THEN #{acts_as_nested_set_options[:left_column]} + #{updown} \
                                      ELSE #{acts_as_nested_set_options[:left_column]} END, \
                                  #{acts_as_nested_set_options[:right_column]} = CASE \
                                      WHEN #{acts_as_nested_set_options[:right_column]} BETWEEN #{cur_left} AND #{cur_right} \
                                        THEN #{acts_as_nested_set_options[:right_column]} + #{shift} \
                                      WHEN #{acts_as_nested_set_options[:right_column]} BETWEEN #{b_left} AND #{b_right} \
                                        THEN #{acts_as_nested_set_options[:right_column]} + #{updown} \
                                      ELSE #{acts_as_nested_set_options[:right_column]} END, \
                                  #{acts_as_nested_set_options[:parent_column]} = CASE \
                                      WHEN #{acts_as_nested_set_options[:class].primary_key} = #{self.id} \
                                        THEN #{new_parent} \
                                      ELSE #{acts_as_nested_set_options[:parent_column]} END",
                                  acts_as_nested_set_options[:scope] )
          self.reload
        end

      end

    end
  end
end
