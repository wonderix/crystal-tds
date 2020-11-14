
@[Link("sybdb")]
lib LibFreeTDS
  alias RETCODE = Int32
  alias LOGINREC = Void
  alias DBPROCESS = Void
  alias BYTE = UInt8
  alias DBBOOL = UInt8

  alias EHANDLEFUNC = (DBPROCESS*, Int32, Int32, Int32, UInt8*, UInt8*) -> Int32
  alias MHANDLEFUNC = (DBPROCESS*, Int32, Int32, Int32, UInt8*, UInt8*, UInt8*, Int32) -> Int32

  fun init = dbinit() : RETCODE

  fun login = dblogin() : LOGINREC*
  fun setlname = dbsetlname(login : LOGINREC*, value : UInt8*, which : Int32) : RETCODE
  fun setlbool = dbsetlbool(login : LOGINREC*, value : Int32, which: Int32) : RETCODE
  fun setlshort = dbsetlshort(login : LOGINREC*, value : Int32, which : Int32) : RETCODE
  fun setllong = dbsetllong(login : LOGINREC*, value : Int64, which : Int32) : RETCODE
  fun setlversion = dbsetlversion (login : LOGINREC*, version : UInt8) : RETCODE
  fun msghandle =  dbmsghandle(handler: MHANDLEFUNC) : MHANDLEFUNC
  fun errhandle =  dberrhandle(handler: EHANDLEFUNC) : EHANDLEFUNC
  fun setlogintime = dbsetlogintime(seconds : Int32) : RETCODE
  fun open = dbopen(login: LOGINREC* , server : UInt8*) : DBPROCESS *
  fun getuserdata =  dbgetuserdata(dbproc : DBPROCESS* ) : BYTE*
  fun setuserdata = dbsetuserdata(dbproc : DBPROCESS*, ptr : BYTE* );
  fun freebuf = dbfreebuf(dbproc : DBPROCESS* )
  fun cancel = dbcancel(dbproc : DBPROCESS* ) : RETCODE
  fun dead = dbdead(dbproc : DBPROCESS* ): DBBOOL
  fun cmd = dbcmd(dbproc : DBPROCESS* ,cmdstring: UInt8*):  RETCODE 
  fun sqlsend = dbsqlsend(dbproc : DBPROCESS*):  RETCODE 

end

module FreeTDS

  alias RETCODE = LibFreeTDS::RETCODE
  alias LOGINREC = LibFreeTDS::LOGINREC
  alias DBPROCESS = LibFreeTDS::DBPROCESS
  alias BYTE = LibFreeTDS::BYTE
  alias EHANDLEFUNC = LibFreeTDS::EHANDLEFUNC
  alias MHANDLEFUNC = LibFreeTDS::MHANDLEFUNC


  enum Version
    Unknown  = 0
    V4_6     = 1
    V100     = 2
    V4_2     = 3
    V7_0     = 4
    V7_1     = 5
    V7_2     = 6
    V7_3     = 7
  end


  INT_EXIT	= 0
  INT_CONTINUE = 1
  INT_CANCEL = 2
  INT_TIMEOUT = 3

  SUCCEED = 1
  FAIL = 0

  SETHOST = 1
  SETUSER = 2
  SETPWD = 3
  SETHID = 4	
  SETAPP = 5
  SETBCP = 6
  SETNATLANG = 7
  SETNOSHORT = 8
  SETHIER = 9
  SETCHARSET = 10
  SETPACKET = 11
  SETENCRYPT = 12
  SETLABELED = 13
  SETDBNAME = 14
  SETNETWORKAUTH = 101
  SETMUTUALAUTH = 102
  SETSERVERPRINCIPAL = 103
  SETUTF16 = 1001
  SETNTLMV2 = 1002
  SETREADONLY = 1003
  SETDELEGATION = 1004


  macro check(name, *args)
    ret = LibFreeTDS.{{name}}({{*args}})
    raise Exception.new("{{name}}") unless ret == FreeTDS::SUCCEED
  end


  def init() check(init); end
  def login() : LOGINREC* LibFreeTDS.login(); end
  def open(x : LOGINREC* , server : String) : DBPROCESS* LibFreeTDS.open(x, server); end
  def errhandle(handler : EHANDLEFUNC) : EHANDLEFUNC LibFreeTDS.errhandle(handler); end

  def getuserdata(dbproc : DBPROCESS*) : BYTE*  LibFreeTDS.getuserdata(dbproc); end
  def setuserdata(dbproc : DBPROCESS*, ptr : BYTE* )  LibFreeTDS.setuserdata(dbproc, ptr); end
  def freebuf(dbproc : DBPROCESS*)  LibFreeTDS.freebuf(dbproc); end
  def cancel(dbproc : DBPROCESS*) check(cancel,dbproc); end
  def dead(dbproc : DBPROCESS*) : Bool  LibFreeTDS.dead(dbproc) != 0 ; end
  def cmd(dbproc : DBPROCESS* ,cmdstring : String) check(cmd, dbproc, cmdstring) ; end
  def sqlsend(dbproc : DBPROCESS*) check(sqlsend,dbproc); end

  def setlogintime(seconds : Int32) check(setlogintime,seconds); end
  def setlversion(x : LOGINREC*, y : Version) check(setlversion,x, y.value) end
  def setlhost(x : LOGINREC*, y : String) check(setlname,x, y,SETHOST); end
  def setluser(x : LOGINREC*, y : String) check(setlname,x, y, SETUSER); end
  def setlpwd(x : LOGINREC*, y : String) check(setlname,x, y,SETPWD); end
  def setlhid(x : LOGINREC*, y : String) check(setlname,x, y,SETHID); end
  def setlapp(x : LOGINREC*, y : String) check(setlname,x, y,SETAPP); end
  def setlsecure(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETBCP); end
  def setlnatlang(x : LOGINREC*, y : String) check(setlname,x, y,SETNATLANG); end
  def setlnoshort(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETNOSHORT); end
  def setlhier(x : LOGINREC*, y : Int32) check(setlshort,x, y,SETHIER); end
  def setlcharset(x : LOGINREC*, y : String) check(setlname,x, y,SETCHARSET); end
  def setlpacket(x : LOGINREC*, y : Int32) check(setlshort,x, y,SETPACKET); end
  def setlencrypt(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETENCRYPT); end
  def setllabeled(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETLABELED); end
  def setldbname(x : LOGINREC*, y : String) check(setlname,x, y,NAME); end
  def setlnetworkauth(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETNETWORKAUTH); end
  def setlmutualauth(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETMUTUALAUTH); end
  def setlserverprincipal(x : LOGINREC*, y : String) check(setlname,x, y,SETSERVERPRINCIPAL); end
  def setlutf16(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0 ,SETUTF16); end
  def setlntlmv2(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETNTLMV2); end
  def setlreadonly(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETREADONLY); end
  def setldelegation(x : LOGINREC*, y : Bool) check(setlbool,x, y ? 1 : 0,SETDELEGATION); end


  ESEOF = 20017	# Unexpected EOF from SQL Server.
  ESMSG = 20018	# General SQL Server error: Check messages from the SQL Server.
  EICONVI = 2403	# Some character(s) could not be converted into client's character set.  Unconverted bytes were changed to question marks ('?').
  EICONVO = 2402	# Error converting characters into server's character set. Some character(s) could not be converted.
  ETIME = 20003	# SQL Server connection timed out.
  EWRIT = 20006	# Write to SQL Server failed.
  EVERDOWN = 100 # indicating the connection can only be v7.1
  ECONN  = 20009	# Unable to connect socket -- SQL Server is unavailable or does not exist.


end

 