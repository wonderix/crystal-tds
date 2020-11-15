
class TDS::Statement < DB::Statement
  def initialize(connection, command)
    super(connection, command)
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
  end

  protected def perform_exec(args : Enumerable) : DB::ExecResult
    rows_affected : Int64 = 0
    last_id : Int64 = 0
    DB::ExecResult.new rows_affected, last_id
  end

  protected def do_close
    super
  end

  private def bind_arg(index, value : Nil)
  end

  private def bind_arg(index, value : Bool)
  end

  private def bind_arg(index, value : Int32)
  end

  private def bind_arg(index, value : Int64)
  end

  private def bind_arg(index, value : Float32)
  end

  private def bind_arg(index, value : Float64)
  end

  private def bind_arg(index, value : String)
  end

  private def bind_arg(index, value : Bytes)
  end

  private def bind_arg(index, value : Time)
  end

  private def bind_arg(index, value)
    raise "#{self.class} does not support #{value.class} params"
  end

  def to_unsafe
    @stmt
  end
end

