require "./utf16_io"
require "./type_info"

class TDS::PreparedStatement < DB::Statement
  @proc_id : Parameter? = nil
  @type_infos = [] of TypeInfo

  def initialize(connection, command)
    super(connection, command)
  end

  private def expanded_command(e : Enumerable)
    index = -1
    args = e.to_a
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

  private def ensure_prepared(e : Enumerable)
    return unless @proc_id.nil?
    index = -1
    args = e.to_a
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
    # Workaround for https://github.com/crystal-lang/crystal/issues/11786
    a = [] of Value
    args.each { |x| a.push(x) }
    parameters = a.zip(@type_infos).map do |x|
      Parameter.new(x[0], type_info: x[1])
    end
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
    ensure_prepared(args)
    begin
      parameters = args.zip(@type_infos).map do |x|
        begin
          Parameter.new(x[0], type_info: x[1])
        rescue exc : IndexError
          raise DB::Error.new("#{x} : #{exc}")
        end
      end
    rescue exc : IndexError
      raise DB::Error.new("#{args} #{@type_infos} #{command}: #{exc}")
    end
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
