require 'thread'

module ActiveRecord
  module Transactions # :nodoc:
    class TransactionError < ActiveRecordError # :nodoc:
    end

    def self.included(base)
      base.extend(ClassMethods)

      base.class_eval do
        [:destroy, :save, :save!].each do |method|
          alias_method_chain method, :transactions
        end
      end
    end

    # Transactions are protective blocks where SQL statements are only permanent if they can all succeed as one atomic action. 
    # The classic example is a transfer between two accounts where you can only have a deposit if the withdrawal succeeded and
    # vice versa. Transactions enforce the integrity of the database and guard the data against program errors or database break-downs.
    # So basically you should use transaction blocks whenever you have a number of statements that must be executed together or
    # not at all. Example:
    #
    #   transaction do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # This example will only take money from David and give to Mary if neither +withdrawal+ nor +deposit+ raises an exception.
    # Exceptions will force a ROLLBACK that returns the database to the state before the transaction was begun. Be aware, though,
    # that the objects by default will _not_ have their instance data returned to their pre-transactional state.
    #
    # == Rolling back a transaction manually
    #
    # Instead of relying on exceptions to rollback your transactions, you can also do so manually from within the scope
    # of the transaction by accepting a yield parameter and calling rollback! on it. Example:
    #
    #   transaction do |transaction|
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #     transaction.rollback! # rolls back the transaction that was otherwise going to be successful
    #   end
    #
    # == Transactions are not distributed across database connections
    #
    # A transaction acts on a single database connection.  If you have
    # multiple class-specific databases, the transaction will not protect
    # interaction among them.  One workaround is to begin a transaction
    # on each class whose models you alter:
    #
    #   Student.transaction do
    #     Course.transaction do
    #       course.enroll(student)
    #       student.units += course.units
    #     end
    #   end
    #
    # This is a poor solution, but full distributed transactions are beyond
    # the scope of Active Record.
    #
    # == Save and destroy are automatically wrapped in a transaction
    #
    # Both Base#save and Base#destroy come wrapped in a transaction that ensures that whatever you do in validations or callbacks
    # will happen under the protected cover of a transaction. So you can use validations to check for values that the transaction
    # depend on or you can raise exceptions in the callbacks to rollback.
    #
    # == Exception handling
    #
    # Also have in mind that exceptions thrown within a transaction block will be propagated (after triggering the ROLLBACK), so you
    # should be ready to catch those in your application code.
    module ClassMethods
      def transaction(options={}, &block)
        previous_handler = trap('TERM') { raise TransactionError, "Transaction aborted" }
        increment_open_transactions

        begin
#          connection.transaction((options[:force] == true) || Thread.current['start_db_transaction'], Thread.current['open_transactions'], &block)
          connection.transaction(true, Thread.current['open_transactions'], &block)
        ensure
          decrement_open_transactions
          trap('TERM', previous_handler)
        end
      end

      # Sets the options for implicit transactions. For different
      # action types.
      #
      # The action types are:
      # * <tt>:save</tt> - transaction type for creating or updating a record.
      # * <tt>:destroy</tt> - transaction type for deleting a record.
      #
      # The transaction types are:
      # * <tt>:none</tt> - no transaction is created.
      # * <tt>:flat</tt> - transaction is only created if non exist. This is the default.
      # * <tt>:nested</tt> - transaction is created even if one exists. This only works if the database supports nested transactions, if it does not then the behaviour is the same as for :flat.
      #
      # Option examples:
      #   set_transaction_types :save => :flat
      #   set_transaction_types :save => :none, :destroy => :nested
      #   set_transaction_types :nested
      def set_transaction_types(options)
        case options
        when Symbol
          options = { :save => options, :destroy => options }
        when Hash
          options[:save] ||= :flat
          options[:destroy] ||= :flat
        else
          raise(ArgumentError, "Invalid transaction type(s): %s", options.inspect)
        end

        options.assert_valid_keys(:save, :destroy)

        write_inheritable_attribute("transaction_types", options)
      end

      def get_transaction_type(action_type)
        get_transaction_types[action_type] || :flat
      end

      def get_transaction_types
        (read_inheritable_attribute("transaction_types") or write_inheritable_attribute("transaction_types", {}))
      end

      private
        def increment_open_transactions #:nodoc:
          open = Thread.current['open_transactions'] ||= 0
          Thread.current['start_db_transaction'] = open.zero?
          Thread.current['open_transactions'] = open + 1
        end

        def decrement_open_transactions #:nodoc:
          Thread.current['open_transactions'] -= 1
        end
    end

    def transaction(options={}, &block)
      self.class.transaction(options, &block)
    end

    def destroy_with_transactions #:nodoc:
      transaction_type = self.class.get_transaction_type(:destroy)
      if transaction_type == :none
        destroy_without_transactions
      else
        options = { :force => (transaction_type == :nested) }
        transaction(options) { destroy_without_transactions }
      end
    end

    def save_with_transactions(perform_validation = true) #:nodoc:
      rollback_active_record_state! do
        transaction_type = self.class.get_transaction_type(:save)
        if transaction_type == :none
          save_without_transactions
        else
          options = { :force => (transaction_type == :nested) }
          transaction(options) { save_without_transactions(perform_validation) }
        end
      end
    end

    def save_with_transactions! #:nodoc:
      rollback_active_record_state! do
        transaction_type = self.class.get_transaction_type(:save)
        if transaction_type == :none
          save_without_transactions!
        else
          options = { :force => (transaction_type == :nested) }
          transaction(options) { save_without_transactions! }
        end
      end
    end

    # Reset id and @new_record if the transaction rolls back.
    def rollback_active_record_state!
      id_present = has_attribute?(self.class.primary_key)
      previous_id = id
      previous_new_record = @new_record
      yield
    rescue Exception
      @new_record = previous_new_record
      if id_present
        self.id = previous_id
      else
        @attributes.delete(self.class.primary_key)
        @attributes_cache.delete(self.class.primary_key)
      end  
      raise
    end
  end
end
