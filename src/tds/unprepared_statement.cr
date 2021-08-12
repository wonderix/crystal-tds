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
    raise DB::Error.new("Too much arguments for statement #{command}") if index != args.size - 1
    cmd
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    connection.send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, expanded_command(args), ENCODING)
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
    statement = expanded_command(args)
    connection.send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, statement, ENCODING)
    end
    connection.recv(PacketIO::Type::REPLY) do |io|
      begin
        Token.each(io) { |t| }
      rescue exc : ::Exception
        raise DB::Error.new("#{exc.to_s} in \"#{statement}\"")
      end
    end
    DB::ExecResult.new rows_affected, last_id
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
end
