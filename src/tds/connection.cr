require "./pre_login_request"
require "socket"

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
    begin
      socket = TCPSocket.new(host, port)
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

  def build_prepared_statement(query) : Statement
    Statement.new(self, query)
  end

  def build_unprepared_statement(query) : Statement
    raise DB::Error.new("TDS driver does not support unprepared statements")
  end

  def do_close
    super
  end

  # :nodoc:
  def perform_begin_transaction
    self.prepared.exec "BEGIN"
  end

  # :nodoc:
  def perform_commit_transaction
    self.prepared.exec "COMMIT"
  end

  # :nodoc:
  def perform_rollback_transaction
    self.prepared.exec "ROLLBACK"
  end

  # :nodoc:
  def perform_create_savepoint(name)
    self.prepared.exec "SAVEPOINT #{name}"
  end

  # :nodoc:
  def perform_release_savepoint(name)
    self.prepared.exec "RELEASE SAVEPOINT #{name}"
  end

  # :nodoc:
  def perform_rollback_savepoint(name)
    self.prepared.exec "ROLLBACK TO #{name}"
  end
end
