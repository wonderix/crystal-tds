require "./utf16_io"
require "./type_info"

class TDS::PreparedStatement < DB::Statement
  @proc_id : Parameter? = nil
  @type_infos = [] of TypeInfo

  def initialize(connection, command)
    super(connection, command)
  end

  private def expanded_command(args : Enumerable)
    index = -1
    cmd = command.gsub(/\?/) do |s|
      begin
        index += 1
        PreparedStatement.encode(args[index])
      rescue ::IndexError
        raise DB::Error.new("To few arguments for statement #{command}")
      end
    end
    raise DB::Error.new("To much arguments for statement #{command}") if index != args.size - 1
    cmd
  end

  private def ensure_prepared(args : Enumerable)
    return unless @proc_id.nil?
    index = -1
    params = [] of String
    cmd = command.gsub(/\?/) do |s|
      begin
        index += 1
        param = "@P#{index}"
        type_info = TypeInfo.from_value(args[index])
        @type_infos << type_info
        params << "#{param} #{type_info.type}"
        param
      rescue ::IndexError
        raise DB::Error.new("To few arguments for statement #{command}")
      end
    end
    raise DB::Error.new("To much arguments for statement #{command}") if index != args.size - 1
    @proc_id = Parameter.new(connection.sp_prepare(params.join(","), cmd))
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    ensure_prepared(args)
    parameters = args.zip(@type_infos).map { |x| Parameter.new(x[0].as(Value), type_info: x[1].as(TypeInfo)) }
    connection.send(PacketIO::Type::RPC) do |io|
      RpcRequest.new(id: RpcRequest::Type::EXECUTE, parameters: [@proc_id.not_nil!] + parameters).write(io)
    end
    result = nil
    connection.recv(PacketIO::Type::REPLY) do |io|
      result = ResultSet.new(self, Token.each(io))
    end
    result.not_nil!
  end

  protected def perform_exec(args : Enumerable) : DB::ExecResult
    parameters = args.zip(@type_infos).map { |x| Parameter.new(x[0].as(Value), type_info: x[1].as(TypeInfo)) }
    connection.send(PacketIO::Type::RPC) do |io|
      RpcRequest.new(id: RpcRequest::Type::EXECUTE, parameters: [@proc_id.not_nil!] + parameters).write(io)
    end
    connection.recv(PacketIO::Type::REPLY) do |io|
      begin
        Token.each(io) { |t| }
      rescue exc : ::Exception
        raise DB::Error.new("#{exc.to_s} in \"#{command}\"")
      end
    end
    DB::ExecResult.new 0, 0
  end

  protected def do_close
    super
  end
end
