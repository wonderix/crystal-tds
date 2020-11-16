
require "./byte_format"
require "./version"

class Tds::PreLoginSerializer
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

class Tds::PreLoginRequest
  NETLIB9 = Bytes[9, 0, 0, 0, 0, 0 ]

  getter force_encryption
  getter instance

  def initialize(@instance : String, @force_encryption : Bool, @process_id : UInt32 , @netlib : Bytes = NETLIB9, @mars_enabled = false)
  end

  def write(io : IO)
    info_io = Tds::PreLoginSerializer.new(io)
    info_io.write(@netlib)
    info_io.write(@force_encryption)
    info_io.write(@instance)
    info_io.write(@process_id)
    info_io.write(@mars_enabled)
    info_io.flush()
  end

  def self.from_io(io : IO)
    info_io = PreLoginSerializer.new(io)
    netlib = Bytes.new(6)
    info_io.read(netlib)
    force_encryption = info_io.read(Bool)
    instance = info_io.read(String)
    return Tds::PreLoginRequest.new(instance,force_encryption,0,netlib)
  end

end