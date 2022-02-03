require "./prepared_statement"
require "socket"
require "http"

class TDS::Connection < DB::Connection

  def initialize(database)
    super
  end

  def sp_prepare(params : String, statement : String, options = 0x0001_i32) : Int32
    0
  end

  protected def perform_exec(statement)
  end

  def build_prepared_statement(query) : DB::Statement
    raise "xxx"
  end

  def build_unprepared_statement(query) : DB::Statement
    raise "xxx"
  end

  def do_close
  end

  # :nodoc:
  def perform_begin_transaction
  end

  # :nodoc:
  def perform_commit_transaction
  end

  # :nodoc:
  def perform_rollback_transaction
  end

  # :nodoc:
  def perform_create_savepoint(name)
  end

  # :nodoc:
  def perform_release_savepoint(name)
  end

  # :nodoc:
  def perform_rollback_savepoint(name)
  end
end
