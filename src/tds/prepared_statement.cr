require "./utf16_io"
require "./type_info"

class TDS::PreparedStatement < DB::Statement
  @handles = Hash(String, Parameter).new

  def initialize(connection, command)
    super(connection, command)
  end

  private def ensure_prepared(args : Enumerable) : Array(Parameter)
    arguments = parameterize args
    key = arguments.map(&.type_info.type).join(",")
    handle = @handles.fetch(key) {
      index = -1
      params = Array(String).new
      cmd = command.gsub(/\?/) do |s|
        begin
          index += 1
          param = "@P#{index}"
          params << "#{param} #{arguments[index].type_info.type}"
          param
        rescue ex : ::IndexError
          raise DB::Error.new("Too few arguments specified for statement: #{command}", ex)
        end
      end
      raise DB::Error.new("Too many arguments specified for statement: #{command}") if index != arguments.size - 1
      Parameter.new(conn.sp_prepare(params.join(","), cmd))
    }
    [handle] + arguments
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    parameters = ensure_prepared(args)
    conn.send(PacketIO::Type::RPC) do |io|
      RpcRequest.new(id: RpcRequest::Type::EXECUTE, parameters: parameters).write(io)
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
    parameters = ensure_prepared(args)
    conn.send(PacketIO::Type::RPC) do |io|
      RpcRequest.new(id: RpcRequest::Type::EXECUTE, parameters: parameters).write(io)
    end
    conn.recv(PacketIO::Type::REPLY) do |io|
      Token.each(io) { |t| }
    end
    DB::ExecResult.new 0, 0
  rescue ex : IO::Error
    raise DB::ConnectionLost.new(conn, ex)
  rescue ex
    raise DB::Error.new("#{ex.to_s} in \"#{command}\"", ex)
  end

  protected def parameterize(args : Enumerable) : Array(Parameter)
    args.to_a.map { |arg| Parameter.new(arg).as(Parameter) }
  end

  protected def do_close
    super
    @handles.each_value do |handle|
      begin
        conn.sp_unprepare handle.value.as(Int32)
      rescue ex : DB::Error
        # ignore errors when unpreparing to not affect the connection being closed
      end
    end
    @handles.clear
  end

  protected def conn
    @connection.as(Connection)
  end
end
