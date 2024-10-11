class TDS::Driver < DB::Driver
  class ConnectionBuilder < DB::ConnectionBuilder
    def initialize(@options : DB::Connection::Options, @tds_options : TDS::Connection::Options)
    end

    def build : DB::Connection
      TDS::Connection.new(@options, @tds_options)
    end
  end

  def connection_builder(uri : URI) : DB::ConnectionBuilder
    params = HTTP::Params.parse(uri.query || "")
    TDS::Driver::ConnectionBuilder.new(connection_options(params), TDS::Connection::Options.from_uri(uri))
  end
end

DB.register_driver "tds", TDS::Driver
