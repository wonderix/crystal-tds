require "./utf16_io"
require "./type_info"

class TDS::UnpreparedStatement < DB::Statement
  def initialize(connection, command)
    super(connection, command)
  end

  private def expanded_command(e : Enumerable)
    args = e.to_a
    index = -1
    cmd = command.gsub(/\?/) do |s|
      begin
        index += 1
        UnpreparedStatement.encode(args[index])
      rescue ::IndexError
        raise DB::Error.new("Too few arguments for statement #{command}")
      end
    end
    raise DB::Error.new("Too many arguments for statement #{command}") if index != args.size - 1
    cmd
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    conn.send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, expanded_command(args), ENCODING)
    end
    result = nil
    conn.recv(PacketIO::Type::REPLY) do |io|
      result = ResultSet.new(self, Token.each(io))
    end
    result.not_nil!
  rescue ex : IO::Error
    raise DB::ConnectionLost.new(conn, ex)
  end

  protected def perform_exec(args : Enumerable) : DB::ExecResult
    statement = expanded_command(args)
    conn.send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, statement, ENCODING)
    end
    conn.recv(PacketIO::Type::REPLY) do |io|
      Token.each(io) { |t| }
    end
    DB::ExecResult.new 0, 0
  rescue ex : IO::Error
    raise DB::ConnectionLost.new(conn, ex)
  rescue ex
    raise StatementError.new(ex, statement.to_s)
  end

  protected def do_close
    super
  end

  protected def self.encode(value : Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float64 | Float32 | BigDecimal)
    value.to_s
  end

  protected def self.encode(value : String)
    "'#{value.gsub(/'/, "''")}'"
  end

  protected def self.encode(value : Time)
    "'#{Time::Format::RFC_3339.format(value)}'"
  end

  protected def self.encode(value : Nil)
    "NULL"
  end

  protected def conn
    @connection.as(Connection)
  end
end
