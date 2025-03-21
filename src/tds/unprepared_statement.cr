require "./statement_methods"

class TDS::UnpreparedStatement < DB::Statement
  include StatementMethods

  def initialize(connection, command)
    super(connection, command)
  end

  protected def requestType : RpcRequest::Type
    RpcRequest::Type::EXECUTESQL
  end

  protected def parameterize(args : Enumerable) : {String, Array(Parameter)}
    arguments = args.to_a.map { |arg| Parameter.new(arg).as(Parameter) }
    statement, parameters, arguments = parameterize(command, arguments)
    {statement, [Parameter.new(statement), Parameter.new(parameters.join(","))] + arguments}
  end

  protected def do_close
    super
  end
end
