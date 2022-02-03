require "./utf16_io"
require "./type_info"

class TDS::PreparedStatement < DB::Statement
  @proc_id : Int32? = nil
  @type_infos = [] of TypeInfo

  def initialize(connection, command)
    super(connection, command)
  end

  private def expanded_command(e : Enumerable)
    raise "xxx"
  end

  private def ensure_prepared(e : Enumerable)
    return unless @proc_id.nil?
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    raise "xxx"
  end

  def perform_exec(args : Enumerable) : DB::ExecResult
    ensure_prepared(args)
    begin
      parameters = args.zip(@type_infos).map do |x|
        test(x[0].as(Value), type_info: x[1].as(TypeInfo))
      end
    rescue exc : IndexError
      raise DB::Error.new("#{args} #{@type_infos} #{command}: #{exc}")
    end
    raise "xxx"
  end

  def test(@value : Value, type_info : TypeInfo? = nil, @name = "") 

  end

  protected def do_close
    super
  end
end
