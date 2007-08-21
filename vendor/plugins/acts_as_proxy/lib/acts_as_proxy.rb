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

# ActsAsProxy

module Lime
  module Acts
    module Proxy

      def self.included(mod)
        mod.extend(ClassMethods)
      end

      module ClassMethods

        def acts_as_proxy( options = {} )

          unless options.include?( :for )
            raise ArgumentError, "Proxy needs a target.  Supply an options hash with a :for key"
          end

          proxied_class_str = options[:for].to_s
          proxied_class = self.const_get( proxied_class_str.camelize )
          proxy_class_base_str = self.to_s.split(/::/).last.underscore

          attr_hash = {
            :proxied_class_base_str => proxied_class_str,
            :proxied_class => proxied_class,
            :proxy_class_base_str => proxy_class_base_str
          }

          proxied_class_sym = proxied_class_str.to_sym

          has_one_options = { :dependent => :destroy }
          belongs_to_options = { }

           if options.include?( :foreign_key )
#             belongs_to_options[:foreign_key] = has_one_options[:foreign_key] = options[:foreign_key]
             has_one_options[:foreign_key] = options[:foreign_key]
           end

          proxy_attr_hashes = [attr_hash] + (read_inheritable_attribute(:proxy_attr_hashes) || [])

          class_eval do
            has_one proxied_class_sym, has_one_options
            before_update :save_proxied_classes

            include Lime::Acts::Proxy::InstanceMethods
            extend Lime::Acts::Proxy::SingletonMethods


            class_inheritable_reader(:proxy_attr_hashes)

            write_inheritable_attribute(:proxy_attr_hashes, proxy_attr_hashes)

          end

#           proxied_class.class_eval do
#             belongs_to proxy_class_base_str.to_sym, belongs_to_options
#           end
        end

        def proxied_by(proxy_class_str, options)
          class_eval do
            belongs_to proxy_class_str, options
          end
        end
        
      end


      module SingletonMethods

        def method_missing( method_id, *arguments )
          super
        rescue NameError => e
          proxy_attr_hashes.each do |h|
            begin
              result = h[:proxied_class].send(method_id, *arguments)
              if  result.instance_of?(h[:proxied_class])
                return result.send(h[:proxy_class_base_str])
              else
                return result
              end
            rescue NoMethodError
            end
          end
          raise e
        end

      end


      module InstanceMethods

        def save_proxied_classes
          proxy_attr_hashes.each do |h|
            proxied = self.send(h[:proxied_class_base_str])
            proxied.save unless proxied.nil?
          end
        end

        def method_missing( method_id, *arguments )
          super
        rescue NameError => e
          proxy_attr_hashes.each do |h|
            begin
              return self.send( h[:proxied_class_base_str] ).send( method_id, *arguments )
            rescue NoMethodError
            end
          end
          raise e
        end

      end

    end

  end
end


ActiveRecord::Base.class_eval do
  include Lime::Acts::Proxy
end
