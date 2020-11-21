require "./version"

class TDS::PacketIO < IO
  enum Type
    QUERY     =  1
    LOGIN     =  2
    RPC       =  3
    REPLY     =  4
    CANCEL    =  6
    MSDTC     = 14
    SYBQUERY  = 15
    MSLOGIN   = 16
    NTLMAUTH  = 17
    PRE_LOGIN = 18
  end

  enum Mode
    READ  = 0
    WRITE = 1
  end

  ENCODING = IO::ByteFormat::BigEndian

  MIN_SIZE =   512
  HDR_LEN  = 8_u16
  @write_pos = HDR_LEN
  @read_pos = HDR_LEN

  def initialize(@io : IO, @type : Type, @mode : Mode, size : Int32)
    @buffer = Bytes.new(size)
  end

  def pos
    if @mode == Mode::READ
      return @read_pos
    else
      return @write_pos
    end
  end

  def seek(offset, whence : Seek = IO::Seek::Set)
    case whence
    when IO::Seek::Current
      if @mode == Mode::READ
        @read_pos += offset
      else
        @write_pos += offset
      end
    else
      raise IO::Error.new "Unable to seek"
    end
  end

  def read(slice : Bytes)
    raise "invalid mode" unless @mode == Mode::READ

    if @read_pos == @write_pos
      @write_pos = 0
      while @write_pos < HDR_LEN
        count = @io.read(@buffer[@write_pos..HDR_LEN])
        @write_pos += count
      end
      raise "expected different type" if Type.new(Int32.new(@buffer[0])) != @type
      last_pos = ENCODING.decode(UInt16, @buffer[2, 2])
      while @write_pos < last_pos
        count = @io.read(@buffer[@write_pos..last_pos])
        @write_pos += count
      end
    end
    count = Math.min(slice.size, @write_pos - @read_pos)
    slice.copy_from(@buffer[@read_pos, count])
    @read_pos += count
    count
  end

  def write(slice : Bytes) : Nil
    raise "invalid mode" unless @mode == Mode::WRITE

    count = slice.size
    offset = 0

    while count > 0
      available = @buffer.size - @write_pos

      if available == 0
        send(false)
      else
        len = (available > count) ? count : available
        slice[offset, len].copy_to @buffer[@write_pos, len]
        offset += len
        count -= len
        @write_pos += len
      end
    end
  end

  def flush
    send(true)
  end

  private def send(last : Bool)
    @buffer[0] = UInt8.new(@type.value)
    @buffer[1] = last ? 1_u8 : 0_u8
    ENCODING.encode(@write_pos, @buffer[2, 2])
    @buffer[4] = 0
    @buffer[5] = 0
    @buffer[6] = 0
    @buffer[7] = 0
    @io.write(@buffer[0, @write_pos])
    @write_pos = HDR_LEN
  end

  def self.send(io : IO, type : Type, size = MIN_SIZE, &block : IO -> Nil)
    packet_io = PacketIO.new(io, type, Mode::WRITE, size)
    yield packet_io
    packet_io.flush
  end

  def self.recv(io : IO, expected_type : Type, size = MIN_SIZE, &block : IO -> Nil)
    packet_io = PacketIO.new(io, expected_type, Mode::READ, size)
    yield packet_io
  end
end
