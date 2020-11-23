require "./trace"
require "./errno"

module TDS
  alias Value = Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float64 | Float32 | String | Time | BigDecimal | Nil
  alias Decoder = Proc(IO, Value)
end

module TDS::Decoders
  include Trace
  ENCODING = IO::ByteFormat::LittleEndian

  def self.int1
    Decoder.new() { |io| Int8.from_io(io, ENCODING) }
  end

  def self.int2
    Decoder.new() { |io| Int16.from_io(io, ENCODING) }
  end

  def self.int4
    Decoder.new() { |io| Int32.from_io(io, ENCODING) }
  end

  def self.int8
    Decoder.new() { |io| Int64.from_io(io, ENCODING) }
  end

  def self.intn(expected_len : UInt8)
    Decoder.new() do |io|
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 1
        raise ProtocolError.new if len != expected_len
        Int8.from_io(io, ENCODING)
      when 2
        raise ProtocolError.new if len != expected_len
        Int16.from_io(io, ENCODING)
      when 4
        raise ProtocolError.new if len != expected_len
        Int32.from_io(io, ENCODING)
      when 8
        raise ProtocolError.new if len != expected_len
        Int64.from_io(io, ENCODING)
      else
        raise ProtocolError.new
      end
    end
  end

  def self.sint1
    Decoder.new() { |io| Int8.from_io(io, ENCODING) }
  end

  def self.uint2
    Decoder.new() { |io| UInt16.from_io(io, ENCODING) }
  end

  def self.uint4
    Decoder.new() { |io| UInt32.from_io(io, ENCODING) }
  end

  def self.uint8
    Decoder.new() { |io| UInt64.from_io(io, ENCODING) }
  end

  def self.uintn(expected_len : UInt8)
    Decoder.new() do |io|
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 1
        raise ProtocolError.new if len != expected_len
        UInt8.from_io(io, ENCODING)
      when 2
        raise ProtocolError.new if len != expected_len
        UInt16.from_io(io, ENCODING)
      when 4
        raise ProtocolError.new if len != expected_len
        UInt32.from_io(io, ENCODING)
      when 8
        raise ProtocolError.new if len != expected_len
        UInt64.from_io(io, ENCODING)
      else
        raise ProtocolError.new
      end
    end
  end

  def self.flt8
    Decoder.new { |io| Float64.from_io(io, ENCODING) }
  end

  def self.fltn(expected_len : UInt8)
    Decoder.new() do |io|
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 4
        raise ProtocolError.new if len != expected_len
        Float32.from_io(io, ENCODING)
      when 8
        raise ProtocolError.new if len != expected_len
        Float64.from_io(io, ENCODING)
      else
        raise ProtocolError.new
      end
    end
  end

  def self.datetime
    Decoder.new { |io| read_datetime_8(io) }
  end

  def self.datetime4
    Decoder.new { |io| read_datetime_4(io) }
  end

  def self.datetimn(expected_len)
    Decoder.new do |io|
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 4
        raise ProtocolError.new if len != expected_len
        read_datetime_4(io)
      when 8
        raise ProtocolError.new if len != expected_len
        read_datetime_8(io)
      else
        raise ProtocolError.new
      end
    end
  end

  def self.decimal(precision : UInt8, scale : UInt8)
    Decoder.new { |io| read_decimal(precision, scale, io) }
  end

  def self.xnvarchar
    Decoder.new do |io|
      len = UInt16.from_io(io, ENCODING)
      trace(len)
      if len == 0xFFFF_u16
        nil
      else
        UTF16_IO.read(io, len >> 1, ENCODING)
      end
    end
  end

  def self.xvarchar(encoding)
    Decoder.new do |io|
      len = UInt16.from_io(io, ENCODING)
      trace(len)
      if len == 0xFFFF_u16
        nil
      else
        buffer = Bytes.new(len)
        io.read(buffer)
        encoded_io = IO::Memory.new(buffer)
        encoded_io.set_encoding(encoding, nil)
        encoded_io.gets_to_end
      end
    end
  end

  def self.text(encoding)
    Decoder.new do |io|
      textptr_len = UInt8.from_io(io, ENCODING)
      trace(textptr_len)
      if textptr_len == 0
        nil
      else
        io.seek(textptr_len + 8, IO::Seek::Current)
        len = UInt32.from_io(io, ENCODING)
        trace(len)
        buffer = Bytes.new(len)
        io.read(buffer)
        encoded_io = IO::Memory.new(buffer)
        encoded_io.set_encoding(encoding, nil)
        encoded_io.gets_to_end
      end
    end
  end

  def self.ntext
    Decoder.new do |io|
      textptr_len = UInt8.from_io(io, ENCODING)
      trace(textptr_len)
      if textptr_len == 0
        nil
      else
        io.seek(textptr_len + 8, IO::Seek::Current)
        len = UInt32.from_io(io, ENCODING)
        trace(len)
        UTF16_IO.read(io, len >> 1, ENCODING)
      end
    end
  end

  private def self.read_datetime_8(io : IO)
    days = Int32.from_io(io, ENCODING) - 25567
    seconds = Int32.from_io(io, ENCODING)//300
    Time.unix(days*24*60*60 + seconds)
  end

  private def self.read_datetime_4(io : IO)
    days = UInt32.new(UInt16.from_io(io, ENCODING)) - 25567_i32
    trace(days)
    seconds = UInt32.new(UInt16.from_io(io, ENCODING)) * 60_i32
    trace(seconds)
    Time.unix(days*24*60*60 + seconds)
  end

  private def self.read_decimal(precision : UInt8, scale : UInt8, io : IO) : Value
    len = UInt8.from_io(io, ENCODING)
    return nil if len == 0
    sign = UInt8.from_io(io, ENCODING)
    trace(len)
    trace(sign)
    x = BigInt.new(0)
    y = BigInt.new(1)
    (len - 1).times do
      f = UInt8.from_io(io, ENCODING)
      trace(f)
      x += f * y
      y = y << 8
    end
    if sign == 1_u8
      BigDecimal.new(x, UInt64.new(scale))
    else
      BigDecimal.new(-x, UInt64.new(scale))
    end
  end
end
