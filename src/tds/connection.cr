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
end


class TDS::Connection < DB::Connection

  @@exception : TDS::Exception? = nil

  property process = Pointer(DBPROCESS).null
  property userdata = UserData.new()

  def initialize(database)
    super
    check init()
    errorhandler = ->(dbproc : DBPROCESS*, severity : Int32, dberr  : Int32, oserr  : Int32, dberrstr  : UInt8*, oserrstr: UInt8*) do
      ptr = getuserdata(dbproc)
      exception = TDS::Exception.new(severity,dberr,oserr,dberrstr,oserrstr)
      if ptr.null?
        @@exception = exception
        INT_CANCEL
      else
        Connection.on_error(dbproc,ptr.as(UserData*).value,exception)
      end
    end
    errhandle(errorhandler)
    login = login()
    database.uri.user.try{ | s | check setluser(login, s) }
    database.uri.password.try{ | s | check setlpwd(login, s) }
    host = database.uri.host || "localhost"
    port = database.uri.port || 1433 
    check setlapp(login, "CrystalTds")
    check setlversion(login, Version::V7_3)
    check setlogintime(60)
    check setlutf16(login, false)
    check setlhost(login, host)

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

  private def check(code : Int32 )
    raise Exception.new(code) unless code == FreeTDS::SUCCEED
  end
    
  def self.on_error(dbproc : DBPROCESS*, userdata : UserData, exception : Exception) : Int32 
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

end