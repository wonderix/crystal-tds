
require "./byte_format"
require "./version"


class TDS::PacketIO < IO
  MIN_SIZE = 512
  HDR_LEN = 8_u16
  @buffer = Bytes.new(MIN_SIZE)
  @pos = HDR_LEN


  def initialize(@io : IO, @type : UInt8, @version = TDS::Version::V9_0)
  end

  def read(slice : Bytes)
    raise ::Exception.new("Not implemented")
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

  def self.send(io : IO, type : UInt8, version = TDS::Version::V9_0, &block : IO -> Nil)
    packet_io =  PacketIO.new(io,type,version)
    yield packet_io
    packet_io.flush()
  end

end

