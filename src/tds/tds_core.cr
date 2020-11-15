

ENCODING = IO::ByteFormat::BigEndian


class PacketIO < IO
  MIN_SIZE = 512
  HDR_LEN = 8_u16
  @buffer = Bytes.new(MIN_SIZE)
  @pos = HDR_LEN


  def initialize(@io : IO, @type : UInt8, @version = Version::V9_0)
  end

  def read(slice : Bytes)
    raise Exception.new("Not implemented")
  end

  def write(slice : Bytes): Nil

    count = slice.size
    offset = 0

    while count > 0
      available = @buffer.size - @pos
      
      if available == 0
        send(false)
      else
        len = (available > count) ? count : available
        slice[offset,len].copy_to @buffer[@pos,len]
        offset += len
        count -= len
        @pos += len
      end
    end
  end

  def flush()
    send(true)
  end

  private def send(last : Bool)
    @buffer[0] = @type
    @buffer[1] = last ? 1_u8 : 0_u8
    ENCODING.encode(@pos, @buffer[2,2])
    @buffer[4] = 0
    @buffer[5] = 0
    @buffer[6] = 0
    @buffer[7] = 0
    @io.write(@buffer[0,@pos])
    @pos = HDR_LEN
  end

end

class InfoIO
  NETLIB9 = Bytes[9, 0, 0, 0, 0, 0 ]
  @buffer = IO::Memory.new()
  @sizes = Array(UInt16).new()

  def initialize(@io : IO)
  end

  def write(data : Bytes)
    @sizes << UInt16.new(data.size)
    @buffer.write(data)
  end

  def write(data : String)
    @sizes << UInt16.new(data.size + 1)
    @buffer.write(data.to_slice)
    ENCODING.encode(0_u8, @buffer)
  end

  def write(data : Bool)
    @sizes << 1_u16
    ENCODING.encode(data ? 1_u8 : 0_u8, @buffer)
  end

  def write(data : UInt32)
    @sizes << 4_u16
    ENCODING.encode(data, @buffer)
  end

  def flush()
    header = IO::Memory.new(@sizes.size * 5 + 1)
    offset = UInt16.new(@sizes.size * 5 + 1)
    index = 0_u8
    @sizes.each do | size |
      ENCODING.encode(index, header)
      ENCODING.encode(offset, header)
      ENCODING.encode(size, header)
      offset += size
      index += 1_u8
    end
    header.write(Bytes[0xff])
    @io.write(header.to_slice)
    @io.write(@buffer.to_slice)
  end

  def read(type : String.class) : String
    read_sizes()
    size = @sizes.shift()
    buffer = Bytes.new(size)
    @io.read(buffer)
    String.new(buffer[0,size-1])
  end

  def read(type : Bool.class) 
    read_sizes()
    size = @sizes.shift()
    UInt8.from_io(@io, ENCODING) != 0
  end

  def read(data : Bytes) 
    read_sizes()
    size = @sizes.shift()
    @io.read(data[0,size])
  end

  private def read_sizes()
    return if @sizes.size != 0
    while true
      index = UInt8.from_io(@io,ENCODING)
      break if index == 0xff
      offset = UInt16.from_io(@io,ENCODING)
      size = UInt16.from_io(@io,ENCODING)
      @sizes << size
    end
  end

end

class PreLoginInfo
  NETLIB9 = Bytes[9, 0, 0, 0, 0, 0 ]

  getter force_encryption
  getter instance

  def initialize(@instance : String, @force_encryption : Bool, @process_id : UInt32 , @netlib : Bytes = NETLIB9, @mars_enabled = false)
  end

  def write(io : IO)
    info_io = InfoIO.new(io)
    info_io.write(@netlib)
    info_io.write(@force_encryption)
    info_io.write(@instance)
    info_io.write(@process_id)
    info_io.write(@mars_enabled)
    info_io.flush()
  end

  def self.from_io(io : IO)
    info_io = InfoIO.new(io)
    netlib = Bytes.new(6)
    info_io.read(netlib)
    force_encryption = info_io.read(Bool)
    instance = info_io.read(String)
    return PreLoginInfo.new(instance,force_encryption,0,netlib)
  end

end


module Tds::Core



  enum Version
    V4_2     = 1
    V5_0     = 2
    V7_0     = 3
    V8_0     = 4
    V8_1     = 5
    V9_0     = 6
  end

  ESEOF = 20017	# Unexpected EOF from SQL Server.
  ESMSG = 20018	# General SQL Server error: Check messages from the SQL Server.
  EICONVI = 2403	# Some character(s) could not be converted into client's character set.  Unconverted bytes were changed to question marks ('?').
  EICONVO = 2402	# Error converting characters into server's character set. Some character(s) could not be converted.
  ETIME = 20003	# SQL Server connection timed out.
  EWRIT = 20006	# Write to SQL Server failed.
  EVERDOWN = 100 # indicating the connection can only be v7.1
  ECONN  = 20009	# Unable to connect socket -- SQL Server is unavailable or does not exist.

  def send_pre_login(io : IO, process_id = UInt32.new(Process.pid) , instance = "MSSQLServer", force_encryption : Bool = false)
    io = PacketIO.new(io,18)
    PreLoginInfo.new( instance , force_encryption, process_id).write(io)
    io.flush()
  end


end

 