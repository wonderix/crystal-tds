
@[Link("sybdb")]
lib LibFreeTDS
  type RETCODE = Int32
  type LOGINREC = Void*

  fun login = dblogin() : LOGINREC
  fun setlname = dbsetlname(login : LOGINREC, value : UInt8*, which : Int32) : RETCODE
  fun setlbool = dbsetlbool(login : LOGINREC, value : Int32, which: Int32) : RETCODE
  fun setlshort = dbsetlshort(login : LOGINREC, value : Int32, which : Int32) : RETCODE
  fun setllong = dbsetllong(login : LOGINREC, value : Int64, which : Int32) : RETCODE
  fun setlversion = dbsetlversion (login : LOGINREC, version : UInt8) : RETCODE

end

module FreeTDS
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
  def setlhost(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETHOST); end
  def setluser(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x, y, SETUSER); end
  def setlpwd(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETPWD); end
  def setlhid(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETHID); end
  def setlapp(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETAPP); end
  def setlsecure(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETBCP); end
  def setlnatlang(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETNATLANG); end
  def setlnoshort(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETNOSHORT); end
  def setlhier(x : LOGINREC,y : Int32) : RETCODE  setlshort(x,y,SETHIER); end
  def setlcharset(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETCHARSET); end
  def setlpacket(x : LOGINREC,y : Int32) : RETCODE  setlshort(x,y,SETPACKET); end
  def setlencrypt(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETENCRYPT); end
  def setllabeled(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETLABELED); end
  def setldbname(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,NAME); end
  def setlnetworkauth(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETNETWORKAUTH); end
  def setlmutualauth(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETMUTUALAUTH); end
  def setlserverprincipal(x : LOGINREC,y : UInt8*) : RETCODE  setlname(x,y,SETSERVERPRINCIPAL); end
  def setlutf16(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETUTF16); end
  def setlntlmv2(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETNTLMV2); end
  def setlreadonly(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETREADONLY); end
  def setldelegation(x : LOGINREC,y : Bool) : RETCODE  setlbool(x,y,SETDELEGATION); end
end

 