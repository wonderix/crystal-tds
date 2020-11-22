require "./trace.cr"

module TDS
  alias Value = Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float64 | String | Time | BigDecimal | Nil
  alias Decoder = Proc(IO, Value)
end

module TDS::Decoders
  include Trace
  ENCODING = IO::ByteFormat::LittleEndian

  class ProtocolError < DB::Error
  end

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

  def self.intn(len : UInt8)
    case len
    when 1
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; Int8.from_io(io, ENCODING) }
    when 2
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; Int16.from_io(io, ENCODING) }
    when 4
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; Int32.from_io(io, ENCODING) }
    when 8
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; Int64.from_io(io, ENCODING) }
    else
      raise ProtocolError.new
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

  def self.uintn(len : UInt8)
    case len
    when 1
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; UInt8.from_io(io, ENCODING) }
    when 2
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; UInt16.from_io(io, ENCODING) }
    when 4
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; UInt32.from_io(io, ENCODING) }
    when 8
      Decoder.new() { |io| raise ProtocolError.new if UInt8.from_io(io, ENCODING) != len; UInt64.from_io(io, ENCODING) }
    else
      raise ProtocolError.new
    end
  end

  def self.flt8
    Decoder.new { |io| Float64.from_io(io, ENCODING) }
  end

  def self.datetime
    Decoder.new { |io| read_datetime_8(io) }
  end

  def self.datetime4
    Decoder.new { |io| read_datetime_4(io) }
  end

  def self.datetimn
    Decoder.new { |io| read_datetime_n(io) }
  end

  def self.decimal(precision : UInt8, scale : UInt8)
    Decoder.new { |io| read_decimal(precision, scale, io) }
  end

  def self.xnvarchar
    Decoder.new { |io| read_string(io) }
  end

  private def self.read_datetime_8(io : IO) : Value
    days = Int32.from_io(io, ENCODING) - 25567
    seconds = Int32.from_io(io, ENCODING)//300
    Time.unix(days*24*60*60 + seconds)
  end

  private def self.read_datetime_4(io : IO) : Value
    days = UInt16.from_io(io, ENCODING) - 25567_i32
    seconds = UInt16.from_io(io, ENCODING) * 60_i32
    Time.unix(days*24*60*60 + seconds)
  end

  private def self.read_datetime_n(io : IO) : Value
    len = UInt8.from_io(io, ENCODING)
    case len
    when 0
      nil
    when 4
      read_datetime_4(io)
    when 8
      read_datetime_8(io)
    else
      raise ProtocolError.new
    end
  end

  private def self.read_string(io : IO) : Value
    len = UInt16.from_io(io, ENCODING)
    trace(len)
    if len == 0xFFFF_u16
      nil
    else
      UTF16_IO.read(io, len >> 1, ENCODING)
    end
  end

  private def self.read_decimal(precision : UInt8, scale : UInt8, io : IO) : Value
    len = UInt8.from_io(io, ENCODING) - 1
    sign = UInt8.from_io(io, ENCODING)
    trace(len)
    trace(sign)
    x = BigInt.new(0)
    y = BigInt.new(1)
    len.times do
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
