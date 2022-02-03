require "db"

module TDS
  abstract struct TypeInfo
  end

  struct Int_n < TypeInfo
  end

  class PreparedStatement < DB::Statement
    @type_infos = [] of TypeInfo

    def initialize(connection, command)
      super(connection, command)
    end

    protected def perform_query(args : Enumerable) : DB::ResultSet
      raise "not implemented"
    end

    def perform_exec(args : Enumerable) : DB::ExecResult
      parameters = args.zip(@type_infos).map do |x|
        test(x[0].as(Int32), type_info: x[1].as(TypeInfo))
      end
      raise "not implemented"
    end

    def test(@value : Int32, type_info : TypeInfo? = nil, @name = "") 
    end
  end
end

DB.open("/test").exec("CREATE DATABASE test")
