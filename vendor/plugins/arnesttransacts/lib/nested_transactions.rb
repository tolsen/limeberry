# Author: Laas Toom <laas.toom@eenet.ee>
#
# Plugin that enchances ActiveRecord to make use of savepoints to achieve nested transactions functionality

require 'active_record'
require 'md5'

module EENet #:nodoc:
  module NestedTransactions #:nodoc:

    # Module to overlay ActiveRecord::ConnectionAdapters::DatabaseStatements module
    module DBStatements

      # redefine transactions method to make usage of SAVEPOINTS
      def transaction(start_db_transaction = true)
        transaction_open = false
        savepoint_open = false
        savepoint_name = nil
        begin
          if block_given?
            if start_db_transaction
              begin_db_transaction
              transaction_open = true
            else
              savepoint_name = create_savepoint
              # if savepoint was created, indicate it
              savepoint_open = true if savepoint_name
            end
            yield
          end
        rescue Exception => database_transaction_rollback
          if transaction_open
            transaction_open = false
            rollback_db_transaction
          end
          if savepoint_open
            savepoint_open = false
            rollback_to_savepoint(savepoint_name)
          end
          raise
        end
      ensure
        release_savepoint(savepoint_name) if savepoint_open
        commit_db_transaction if transaction_open
      end  

      # method to generate savepoint name
      def generate_savepoint_name
        # name must start with letters
        "SP#{MD5.md5(rand.to_s)}"
      end

      # abstract create_savepoint method that does nothing
      def create_savepoint
      end

      # abstract rollback_to_savepoint method that does nothing
      def rollback_to_savepoint(sp)
      end

      # abstract release_savepoint method that does nothing
      def release_savepoint(sp)
      end
    end # module DBStatements

    # implement abstract methods for generic syntax used by most DBMS's
    module GenericMethods
      # creates savepoint with some arbitrary name
      def create_savepoint
        begin
          sp = generate_savepoint_name
          execute("SAVEPOINT #{sp}")
          return sp
        rescue Exception
          # savepoints are not supported
        end
      end

      # rolls back to savepoint
      def rollback_to_savepoint(sp)
        begin
          return if sp.nil?
          execute("ROLLBACK TO SAVEPOINT #{sp}")
        rescue Exception
          # savepoints are not supported
        end
      end

      # releases savepoint
      def release_savepoint(sp)
        begin
          return if sp.nil?
          execute("RELEASE SAVEPOINT #{sp}")
        rescue Exception
          # savepoints are not supported
        end
      end
    end # module GenericMethods

    # methods for PostgreSQL
    module PostgresMethods
      # PostgreSQL uses generic syntax
      include GenericMethods
    end

    # methods for MySQL
    module MysqlMethods
      # MySQL uses generic syntax
      include GenericMethods
    end

  end # module NestedTransactions
end # module EENet

# Reopen ActiveRecord to include nested transactions
ActiveRecord::ConnectionAdapters::AbstractAdapter.module_eval{include EENet::NestedTransactions::DBStatements}
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval{include EENet::NestedTransactions::PostgresMethods}
ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval{include EENet::NestedTransactions::MysqlMethods}
