require "./statement_methods"

class TDS::PreparedStatement < DB::Statement
  include StatementMethods

  @handles = Hash(String, Parameter).new

  def initialize(connection, command)
    super(connection, command)
  end

  protected def requestType : RpcRequest::Type
    RpcRequest::Type::EXECUTE
  end

  protected def parameterize(args : Enumerable) : {String, Array(Parameter)}
    arguments = args.to_a.map { |arg| Parameter.new(arg).as(Parameter) }
    key = arguments.map(&.type_info.type).join(",")
    statement, parameters, arguments = parameterize(command, arguments)
    handle = @handles.fetch(key) {
      Parameter.new(conn.sp_prepare(parameters.join(","), statement))
    }
    {statement, [handle] + arguments}
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
end
