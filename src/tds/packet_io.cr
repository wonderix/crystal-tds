
require "./version"

enum TDS::PacketType
  UNKNOWN   = 0x00
  LOGIN     = 0x10
  PRE_LOGIN = 0x12
end

class TDS::PacketIO < IO
  ENCODING = IO::ByteFormat::BigEndian

  MIN_SIZE = 512
  HDR_LEN = 8_u16
  @buffer = Bytes.new(MIN_SIZE)
  @write_pos = HDR_LEN
  @read_pos = HDR_LEN


  def initialize(@io : IO, @type : PacketType)
  end

  def read(slice : Bytes)
    
    if @read_pos == @write_pos
      @write_pos = 0
      while @write_pos < HDR_LEN
        count = @io.read(@buffer[@write_pos..HDR_LEN])
        @write_pos += count
      end
      last_pos = ENCODING.decode(UInt16,@buffer[2,2])
      while @write_pos < last_pos
        count = @io.read(@buffer[@write_pos..last_pos])
        @write_pos += count
      end
    end
    count = Math.min(slice.size, @write_pos - @read_pos )
    slice.copy_from(@buffer[@read_pos, count])
    @read_pos += count
    count
  
  end

  def write(slice : Bytes): Nil

    count = slice.size
    offset = 0

    while count > 0
      available = @buffer.size - @write_pos
      
      if available == 0
        send(false)
      else
        len = (available > count) ? count : available
        slice[offset,len].copy_to @buffer[@write_pos,len]
        offset += len
        count -= len
        @write_pos += len
      end
    end
  end

  def flush()
    send(true)
  end

  private def send(last : Bool)
    @buffer[0] = UInt8.new(@type.value)
    @buffer[1] = last ? 1_u8 : 0_u8
    ENCODING.encode(@write_pos, @buffer[2,2])
    @buffer[4] = 0
    @buffer[5] = 0
    @buffer[6] = 0
    @buffer[7] = 0
    @io.write(@buffer[0,@write_pos])
    @write_pos = HDR_LEN
  end


  def self.send(io : IO, type : PacketType, &block : IO -> Nil)
    packet_io =  PacketIO.new(io,type)
    yield packet_io
    packet_io.flush()
  end

  def self.recv(io : IO, &block : IO -> Nil)
    packet_io =  PacketIO.new(io,PacketType::UNKNOWN)
    yield packet_io
  end

end

