require "./lib_freetds"
include FreeTDS

class UserData
  property closed = false
  property timing_out = false
  property dbsql_sent = false
  property dbsqlok_sent = false
  property dbsqlok_retcode = SUCCEED
  property dbcancel_sent = false
  property nonblocking = false
  property nonblocking_error : TDS::Exception?

  def reset()
    @timing_out = false
    @dbsql_sent = false
    @dbsqlok_sent = false
    @dbcancel_sent = false
    @nonblocking = false
    @nonblocking_error = nil
  end
end


class TDS::Connection < DB::Connection

  @@exception : TDS::Exception? = nil

  property process = Pointer(DBPROCESS).null
  property userdata = UserData.new()

  def initialize(database)
    super
    init()
    errorhandler = ->(dbproc : DBPROCESS*, severity : Int32, dberr  : Int32, oserr  : Int32, dberrstr  : UInt8*, oserrstr: UInt8*) do
      Connection.on_error(dbproc,TDS::Exception.new(severity,dberr,oserr,dberrstr,oserrstr))
    end
    msghandler = ->(dbproc : DBPROCESS*, msgno: Int32, msgstate: Int32, severity: Int32, msgtext: UInt8*, srvname: UInt8*, procname: UInt8*, line: Int32) do 
      Connection.on_message(dbproc,TDS::Exception.new(severity,msgno,msgstate,msgtext,Pointer(UInt8).null))
    end
    errhandle(errorhandler)
    login = login()
    database.uri.user.try{ | s | setluser(login, s) }
    database.uri.password.try{ | s | setlpwd(login, s) }
    host = database.uri.host || "localhost"
    port = database.uri.port || 1433 
    setlapp(login, "CrystalTds")
    setlversion(login, Version::V7_3)
    setlogintime(60)
    setlutf16(login, false)
    setlhost(login, host)

    @process = open(login,"#{host}:#{port}")
    raise @@exception || Exception.new() if @process.null?
    setuserdata(@process, pointerof(@userdata).as(BYTE*))

  rescue exc : Exception
    raise DB::ConnectionRefused.new if exc.dberr == ECONN
    raise exc
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