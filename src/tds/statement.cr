require "./utf16_io"
require "./decoder"

class TDS::Statement < DB::Statement
  ENCODING = IO::ByteFormat::LittleEndian

  def initialize(connection, command)
    super(connection, command)
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

  private def expanded_command(args : Enumerable)
    index = -1
    cmd = command.gsub(/\?/) do |s|
      begin
        index += 1
        Statement.encode(args[index])
      rescue ::IndexError
        raise DB::Error.new("To few arguments for statement #{command}")
      end
    end
    raise DB::Error.new("To much arguments for statement #{command}") if index != args.size - 1
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
    result = nil
    connection.recv(PacketIO::Type::REPLY) do |io|
      begin
        Token.each(io) { |t| }
      rescue exc: ::Exception
        raise DB::Error.new("#{exc.to_s} in \"#{statement}\"")
      end
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
