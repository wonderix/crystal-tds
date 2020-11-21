class TDS::Driver < DB::Driver
  def build_connection(context : DB::ConnectionContext) : TDS::Connection
    TDS::Connection.new(context)
  end
end

DB.register_driver "tds", TDS::Driver
