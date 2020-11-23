require "./utf16_io"

class TDS::Statement < DB::Statement
  ENCODING = IO::ByteFormat::LittleEndian

  def initialize(connection, command)
    super(connection, command)
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    raise NotImplemented.new("prepared statements are not supported yet") unless args.empty?
    connection.send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, command, ENCODING)
    end
    result = nil
    connection.recv(PacketIO::Type::REPLY) do |io|
      result = ResultSet.new(self, Token.each(io))
    end
    result.not_nil!
  end

  protected def perform_exec(args : Enumerable) : DB::ExecResult
    rows_affected : Int64 = 0
    last_id : Int64 = 0
    connection.send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, command, ENCODING)
    end
    result = nil
    connection.recv(PacketIO::Type::REPLY) do |io|
      Token.each(io) { |t| }
    end
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
    raise NotImplemented.new("#{self.class} does not support #{value.class} params")
  end

  def to_unsafe
    @stmt
  end
end
