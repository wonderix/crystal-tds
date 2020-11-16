require "./pre_login_request"



class TDS::Connection < DB::Connection



  def initialize(database)
    super
    user = database.uri.user
    password = database.uri.password
    host = database.uri.host || "localhost"
    port = database.uri.port || 1433 
    @version = Version::V7_3
    @app_name = "crystal-tds"
    @socket = TCPSocket.new(host, port)
    case @version
    when V4_2,  V5_0, V7_0 , V8_0, V8_1
      raise ::Exception.new("Unsupported version")
    when V9_0
      PacketIO.send(@socket,18) do | io |
        PreLoginRequest.new().write(io)
      end
    end
  

 
  rescue exc : Exception
    raise DB::ConnectionRefused.new if exc.dberr == ECONN
    raise exc
  end


  def send_login_pkt()
    send_pre_login(@socket,"instance")
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

  def self.on_error(dbproc : DBPROCESS*, exception : Exception) : Int32 
    ptr = getuserdata(dbproc)
    if ptr.null?
      @@exception = exception
      return INT_CANCEL
    end
    userdata =ptr.as(UserData*).value
    result = INT_CANCEL
    do_cancel = false
    case exception.dberr
    when EVERDOWN, ESEOF, ESMSG, EICONVI
      return result
    when EICONVO
      freebuf(dbproc)
      return result
    when ETIME
      result = INT_TIMEOUT
      do_cancel = true
    when EWRIT
      return result if userdata.dbsqlok_sent || userdata.dbcancel_sent
      do_cancel = true
    end
  
    if userdata.nonblocking
      if do_cancel && dead(dbproc) && !userdata.closed
        cancel(dbproc)
        userdata.dbcancel_sent = true
      end
      userdata.nonblocking_error = exception if userdata.nonblocking_error.nil?
    end

    return result
  
  end

  def self.on_message(dbproc : DBPROCESS*, exception : Exception) : Int32
    ptr = getuserdata(dbproc)
    return 0 if ptr.null?
    userdata =ptr.as(UserData*).value
    is_message_an_error = exception.severity > 10 

    if userdata.nonblocking
      userdata.nonblocking_error = exception if userdata.nonblocking_error.nil?
      if is_message_an_error && !dead(dbproc) && !userdata.closed
        cancel(dbproc);
        userdata.dbcancel_sent = true
      end
    end
    return 0
  end
end