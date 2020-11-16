

require "./byte_format"
require "./packet_io"
require "./pre_login_request"
require "./version"
require "./errno"


module Tds::Core


  def send_pre_login(io : IO, process_id = UInt32.new(Process.pid) , instance = "MSSQLServer", force_encryption : Bool = false)
    io = Tds::PacketIO.new(io,18)
    Tds::PreLoginRequest.new( instance , force_encryption, process_id).write(io)
    io.flush()
  end


end

 