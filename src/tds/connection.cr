require "./pre_login_request"
require "./rpc_request"
require "socket"
require "http"

class TDS::Connection < DB::Connection
  @version = Version::V7_1
  @socket : TCPSocket
  @packet_size = PacketIO::MIN_SIZE

  def initialize(database)
    super
    user = database.uri.user || ""
    password = database.uri.password || ""
    host = database.uri.host || "localhost"
    port = database.uri.port || 1433
    connect_timeout = nil
    database.uri.query.try do |query|
      params = HTTP::Params.parse(query)
      ct = params["connect_timeout"]?
      connect_timeout = Time::Span.new(seconds: ct.to_i) if ct
    end
    begin
      socket = TCPSocket.new(host, port, connect_timeout: connect_timeout)
    rescue exc : Socket::ConnectError
      raise DB::ConnectionRefused.new
    end
    @socket = socket
    case @version
    when Version::V9_0
      PacketIO.send(@socket, PacketIO::Type::PRE_LOGIN) do |io|
        PreLoginRequest.new.write(io)
      end
    when Version::V7_1
      PacketIO.send(@socket, PacketIO::Type::MSLOGIN) do |io|
        LoginRequest.new(user, password, appname: "crystal-tds").write(io, @version)
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
      RpcRequest.new(id: 11, parameters: [
        Parameter.new(nil, type_info: Int_n.new(4), status: Parameter::Status::BY_REFERENCE),
        Parameter.new(params),
        Parameter.new(statement),
        Parameter.new(options),
      ]).write(io)
    end
    result : Int32? = nil
    begin
      recv(PacketIO::Type::REPLY) do |io|
        Token.each(io) do |token|
          case token
          when Token::MetaData
          when Token::ReturnStatus
          when Token::DoneInProc
          when Token::Param
            result = token.value.as(Int32)
          else
            raise ProtocolError.new("Unexpected token #{token.inspect}")
          end
        end
      end
    rescue exc : ::Exception
      raise DB::Error.new("#{exc.to_s} while preparing \"#{statement}\"")
    end
    result.not_nil!
  end

  def build_prepared_statement(query) : Statement
    Statement.new(self, query)
  end

  def build_unprepared_statement(query) : Statement
    Statement.new(self, query)
  end

  def do_close
    super
  end

  # :nodoc:
  def perform_begin_transaction
    self.prepared.exec "BEGIN TRANSACTION"
  end

  # :nodoc:
  def perform_commit_transaction
    self.prepared.exec "COMMIT TRANSACTION"
  end

  # :nodoc:
  def perform_rollback_transaction
    self.prepared.exec "ROLLBACK TRANSACTION "
  end

  # :nodoc:
  def perform_create_savepoint(name)
    self.prepared.exec "SAVE TRANSACTION #{name}"
  end

  # :nodoc:
  def perform_release_savepoint(name)
    self.prepared.exec "COMMIT TRANSACTION #{name}"
  end

  # :nodoc:
  def perform_rollback_savepoint(name)
    self.prepared.exec "ROLLBACK TO #{name}"
  end
end
