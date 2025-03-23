require "./pre_login_request"
require "./rpc_request"
require "./prepared_statement"
require "./unprepared_statement"
require "socket"
require "http"

class TDS::Connection < DB::Connection
  @version = Version::V7_1
  @socket : TCPSocket
  @packet_size = PacketIO::MIN_SIZE

  record Options, host : String, port : Int32, user : String, password : String, database_name : String, dns_timeout : Time::Span?, connect_timeout : Time::Span?, read_timeout : Time::Span?, write_timeout : Time::Span?, isolation_level : String? do
    def self.from_uri(uri : URI) : Options
      params = HTTP::Params.parse(uri.query || "")

      host = uri.host || "localhost"
      port = uri.port || 1433
      user = uri.user || ""
      password = uri.password || ""
      database_name = File.basename(uri.path || "/")
      dns_timeout = Time::Span.new(seconds: (params["dns_timeout"]).to_i32) if params.has_key? "dns_timeout"
      connect_timeout = Time::Span.new(seconds: (params["connect_timeout"]).to_i32) if params.has_key? "connect_timeout"
      read_timeout = Time::Span.new(seconds: (params["read_timeout"]).to_i32) if params.has_key? "read_timeout"
      write_timeout = Time::Span.new(seconds: (params["write_timeout"]).to_i32) if params.has_key? "write_timeout"
      isolation_level = params["isolation_level"]?

      Options.new(host: host, port: port, user: user, password: password, database_name: database_name, dns_timeout: dns_timeout, connect_timeout: connect_timeout, read_timeout: read_timeout, write_timeout: write_timeout, isolation_level: isolation_level)
    end
  end

  def initialize(options : DB::Connection::Options, tds_options : TDS::Connection::Options)
    super(options)

    begin
      socket = TCPSocket.new(tds_options.host, tds_options.port, dns_timeout: tds_options.dns_timeout, connect_timeout: tds_options.connect_timeout)
    rescue ex : Socket::ConnectError
      raise DB::ConnectionRefused.new(cause: ex)
    end
    @socket = socket
    @socket.read_timeout = tds_options.read_timeout
    @socket.write_timeout = tds_options.write_timeout
    case @version
    when Version::V9_0
      PacketIO.send(@socket, PacketIO::Type::PRE_LOGIN) do |io|
        PreLoginRequest.new.write(io)
      end
    when Version::V7_1
      PacketIO.send(@socket, PacketIO::Type::MSLOGIN) do |io|
        LoginRequest.new(tds_options.user, tds_options.password, appname: "crystal-tds", database_name: tds_options.database_name).write(io, @version)
      end
      PacketIO.recv(@socket, PacketIO::Type::REPLY) do |io|
        Token.each(io) do |token|
          case token
          when Token::EnvChange
            if token.type == 4_u8
              @packet_size = token.new_value.to_i
            end
          end
        end
      end
    else
      raise ::Exception.new("Unsupported version #{@version}")
    end
    self.perform_exec "SET TRANSACTION ISOLATION LEVEL #{tds_options.isolation_level}" if tds_options.isolation_level
  end

  def send(type : PacketIO::Type, &block : IO ->)
    PacketIO.send(@socket, type, @packet_size) do |io|
      block.call(io)
    end
  end

  def recv(type : PacketIO::Type, &block : IO ->)
    PacketIO.recv(@socket, type, @packet_size) do |io|
      block.call(io)
    end
  end

  def sp_prepare(params : String, statement : String, options = 0x0001_i32) : Int32
    send(PacketIO::Type::RPC) do |io|
      RpcRequest.new(id: RpcRequest::Type::PREPARE, parameters: [
        Parameter.new(nil, type_info: Int_n.new(4), status: Parameter::Status::BY_REFERENCE),
        Parameter.new(params),
        Parameter.new(statement),
        Parameter.new(options),
      ]).write(io)
    end
    result : Int32? = nil
    recv(PacketIO::Type::REPLY) do |io|
      Token.each(io) do |token|
        case token
        when Token::MetaData
        when Token::Order
        when Token::ReturnStatus
        when Token::DoneInProc
        when Token::Param
          result = token.value.as(Int32)
        else
          raise ProtocolError.new("Unexpected token #{token.inspect}")
        end
      end
    end
    result.not_nil!
  rescue ex : IO::Error
    raise DB::ConnectionLost.new(self, ex)
  rescue ex
    raise DB::Error.new("#{ex.to_s} while preparing \"#{statement}\"", ex)
  end

  def sp_unprepare(handle : Int32) : UInt32
    return_status : UInt32? = nil
    send(PacketIO::Type::RPC) do |io|
      RpcRequest.new(id: RpcRequest::Type::UNPREPARE, parameters: [
        Parameter.new(handle),
      ]).write(io)
    end
    recv(PacketIO::Type::REPLY) do |io|
      Token.each(io) do |token|
        case token
        when Token::ReturnStatus
          return_status = token.status
        else
          raise ProtocolError.new("Unexpected token #{token.inspect}")
        end
      end
    end
    return_status.not_nil!
  rescue ex : IO::Error
    raise DB::ConnectionLost.new(self, ex)
  rescue ex
    raise DB::Error.new("#{ex.to_s} while unpreparing \"#{handle}\"", ex)
  end

  protected def perform_exec(statement)
    send(PacketIO::Type::QUERY) do |io|
      UTF16_IO.write(io, statement, ENCODING)
    end
    recv(PacketIO::Type::REPLY) do |io|
      Token.each(io) { |t| }
    end
  rescue ex : IO::Error
    raise DB::ConnectionLost.new(self, ex)
  rescue ex
    raise DB::Error.new("#{ex.to_s} in \"#{statement}\"", ex)
  end

  def build_prepared_statement(query) : DB::Statement
    if query.includes?('?')
      PreparedStatement.new(self, query)
    else
      UnpreparedStatement.new(self, query)
    end
  end

  def build_unprepared_statement(query) : DB::Statement
    UnpreparedStatement.new(self, query)
  end

  def do_close
    super
    @socket.close
  end

  # :nodoc:
  def perform_begin_transaction
    self.perform_exec "BEGIN TRANSACTION"
  end

  # :nodoc:
  def perform_commit_transaction
    self.perform_exec "COMMIT TRANSACTION"
  end

  # :nodoc:
  def perform_rollback_transaction
    self.perform_exec "ROLLBACK TRANSACTION "
  end

  # :nodoc:
  def perform_create_savepoint(name)
    self.perform_exec "SAVE TRANSACTION #{name}"
  end

  # :nodoc:
  def perform_release_savepoint(name)
  end

  # :nodoc:
  def perform_rollback_savepoint(name)
    self.perform_exec "ROLLBACK TRANSACTION #{name}"
  end
end
