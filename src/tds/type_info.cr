require "uuid"
require "./trace"
require "./errno"

module TDS
  alias Value = Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float64 | Float32 | String | Time | BigDecimal | Nil | Bytes | UUID
  alias Decoder = Proc(IO, Value)
  ENCODING = IO::ByteFormat::LittleEndian
end

module TDS
  abstract struct TypeInfo
    include Trace
    enum Type
      CHAR       = 0x2F
      VARCHAR    = 0x27
      INTN       = 0x26
      INT1       = 0x30
      DATE       = 0x31
      TIME       = 0x33
      INT2       = 0x34
      INT4       = 0x38
      INT8       = 0x7F
      FLT8       = 0x3E
      DATETIME   = 0x3D
      BIT        = 0x32
      TEXT       = 0x23
      NTEXT      = 0x63
      IMAGE      = 0x22
      MONEY4     = 0x7A
      MONEY      = 0x3C
      DATETIME4  = 0x3A
      REAL       = 0x3B
      BINARY     = 0x2D
      VOID       = 0x1F
      VARBINARY  = 0x25
      NVARCHAR   = 0x67
      BITN       = 0x68
      NUMERIC    = 0x6C
      DECIMAL    = 0x6A
      FLTN       = 0x6D
      MONEYN     = 0x6E
      DATETIMN   = 0x6F
      DATEN      = 0x7B
      TIMEN      = 0x93
      XCHAR      = 0xAF
      XVARCHAR   = 0xA7
      XNVARCHAR  = 0xE7
      XNCHAR     = 0xEF
      XVARBINARY = 0xA5
      XBINARY    = 0xAD
      UNITEXT    = 0xAE
      LONGBINARY = 0xE1
      SINT1      = 0x40
      UINT2      = 0x41
      UINT4      = 0x42
      UINT8      = 0x43
      UINTN      = 0x44
      UNIQUE     = 0x24
      VARIANT    = 0x62
      SINT8      = 0xBF
    end

    abstract def decode(io : IO) : Value

    def encode(value : Value, io : IO)
      raise NotImplemented.new
    end

    def type : String
      raise NotImplemented.new
    end

    def write(io : IO)
      raise NotImplemented.new
    end

    def self.from_io(io : IO) : TypeInfo
      type = Type.new(Int32.new(io.read_byte.not_nil!))
      trace(type)
      case type
      when Type::INT1
        Int_1.from_io(io)
      when Type::INT2
        Int_2.from_io(io)
      when Type::INT4
        Int_4.from_io(io)
      when Type::INT8
        Int_8.from_io(io)
      when Type::INTN
        Int_n.from_io(io)
      when Type::SINT1
        SInt_1.from_io(io)
      when Type::UINT2
        UInt_2.from_io(io)
      when Type::UINT4
        UInt_4.from_io(io)
      when Type::UINT8
        UInt_8.from_io(io)
      when Type::UINTN
        UInt_n.from_io(io)
      when Type::FLT8
        Flt_8.from_io(io)
      when Type::FLTN
        Flt_n.from_io(io)
      when Type::DATETIME
        Datetime.from_io(io)
      when Type::DATETIME4
        Datetime_4.from_io(io)
      when Type::DATETIMN
        Datetime_n.from_io(io)
      when Type::NUMERIC, Type::DECIMAL
        Decimal.from_io(io)
      when Type::XNVARCHAR, Type::XNCHAR
        NVarchar.from_io(io)
      when Type::XVARCHAR, Type::XCHAR
        Varchar.from_io(io)
      when Type::TEXT
        Text.from_io(io)
      when Type::NTEXT
        NText.from_io(io)
      when Type::IMAGE
        Image.from_io(io)
      when Type::UNIQUE
        UniqueIdentifier.from_io(io)
      else
        raise ProtocolError.new("Unsupported column type #{type} at position #{"0x%04x" % io.pos}")
      end
    end

    def self.from_value(value : Value) : TypeInfo
      case value
      when String
        NVarchar.new
      when Int8
        Int_n.new(1)
      when Int16
        Int_n.new(2)
      when Int32
        Int_n.new(4)
      when Int64
        Int_n.new(8)
      when Float32
        Flt_n.new(4)
      when Float64
        Flt_n.new(8)
      when Time
        Datetime_n.new(8)
      when BigDecimal
        Decimal.new(18, UInt8.new(value.scale))
      else
        raise NotImplemented.new
      end
    end
  end

  struct Int_1 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Int8.from_io(io, ENCODING)
    end
  end

  struct Int_2 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Int16.from_io(io, ENCODING)
    end
  end

  struct Int_4 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Int32.from_io(io, ENCODING)
    end
  end

  struct Int_8 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Int64.from_io(io, ENCODING)
    end
  end

  struct Int_n < TypeInfo
    def initialize(@expected_len : UInt8)
    end

    def self.from_io(io : IO)
      len = UInt8.from_io(io, ENCODING)
      trace(len)
      self.new(len)
    end

    def type : String
      case @expected_len
      when 1
        "TINYINT"
      when 2
        "SMALLINT"
      when 4
        "INT"
      when 8
        "BIGINT"
      else
        raise NotImplemented.new
      end
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(TypeInfo::Type::INTN.value), io)
      ENCODING.encode(@expected_len, io)
    end

    def encode(value : Value, io : IO)
      case value
      when Nil
        ENCODING.encode(0x0_u8, io)
      when Number
        case @expected_len
        when 1
          ENCODING.encode(0x1_u8, io)
          ENCODING.encode(value.to_i8, io)
        when 2
          ENCODING.encode(0x2_u8, io)
          ENCODING.encode(value.to_i16, io)
        when 4
          ENCODING.encode(0x4_u8, io)
          ENCODING.encode(value.to_i32, io)
        when 8
          ENCODING.encode(0x8_u8, io)
          ENCODING.encode(value.to_i64, io)
        end
      else
        raise ProtocolError.new("Unsupported value #{value}")
      end
    end

    def decode(io : IO) : Value
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 1
        raise ProtocolError.new if len != @expected_len
        Int8.from_io(io, ENCODING)
      when 2
        raise ProtocolError.new if len != @expected_len
        Int16.from_io(io, ENCODING)
      when 4
        raise ProtocolError.new if len != @expected_len
        Int32.from_io(io, ENCODING)
      when 8
        raise ProtocolError.new if len != @expected_len
        Int64.from_io(io, ENCODING)
      else
        raise ProtocolError.new
      end
    end
  end

  struct SInt_1 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Int8.from_io(io, ENCODING)
    end
  end

  struct UInt_2 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      UInt16.from_io(io, ENCODING)
    end
  end

  struct UInt_4 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      UInt32.from_io(io, ENCODING)
    end
  end

  struct UInt_8 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      UInt64.from_io(io, ENCODING)
    end
  end

  struct UInt_n < TypeInfo
    def initialize(@expected_len : UInt8)
    end

    def self.from_io(io : IO)
      len = UInt8.from_io(io, ENCODING)
      trace(len)
      self.new(len)
    end

    def decode(io : IO) : Value
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 1
        raise ProtocolError.new if len != @expected_len
        UInt8.from_io(io, ENCODING)
      when 2
        raise ProtocolError.new if len != @expected_len
        UInt16.from_io(io, ENCODING)
      when 4
        raise ProtocolError.new if len != @expected_len
        UInt32.from_io(io, ENCODING)
      when 8
        raise ProtocolError.new if len != @expected_len
        UInt64.from_io(io, ENCODING)
      else
        raise ProtocolError.new
      end
    end
  end

  struct Flt_8 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Float64.from_io(io, ENCODING)
    end
  end

  struct Flt_n < TypeInfo
    def initialize(@expected_len : UInt8)
    end

    def self.from_io(io : IO)
      len = UInt8.from_io(io, ENCODING)
      trace(len)
      self.new(len)
    end

    def type : String
      case @expected_len
      when 4
        "REAL"
      when 8
        "FLOAT"
      else
        raise NotImplemented.new
      end
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(TypeInfo::Type::FLTN.value), io)
      ENCODING.encode(@expected_len, io)
    end

    def encode(value : Value, io : IO)
      case value
      when Nil
        ENCODING.encode(0x0_u8, io)
      when Number
        case @expected_len
        when 4
          ENCODING.encode(0x4_u8, io)
          ENCODING.encode(value.to_f32, io)
        when 8
          ENCODING.encode(0x8_u8, io)
          ENCODING.encode(value.to_f64, io)
        end
      else
        raise ProtocolError.new("Unsupported value #{value}")
      end
    end

    def decode(io : IO) : Value
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 4
        raise ProtocolError.new if len != @expected_len
        Float32.from_io(io, ENCODING)
      when 8
        raise ProtocolError.new if len != @expected_len
        Float64.from_io(io, ENCODING)
      else
        raise ProtocolError.new
      end
    end
  end

  struct Datetime < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Datetime.read_datetime_8(io)
    end

    protected def self.read_datetime_8(io : IO)
      days = Int32.from_io(io, ENCODING) - 25567
      seconds = Int32.from_io(io, ENCODING)//300
      Time.unix(days*24*60*60 + seconds)
    end

    protected def self.read_datetime_4(io : IO)
      days = UInt32.new(UInt16.from_io(io, ENCODING)) - 25567_i32
      trace(days)
      seconds = UInt32.new(UInt16.from_io(io, ENCODING)) * 60_i32
      trace(seconds)
      Time.unix(days*24*60*60 + seconds)
    end
  end

  struct Datetime_4 < TypeInfo
    def self.from_io(io : IO)
      self.new
    end

    def decode(io : IO) : Value
      Datetime.read_datetime_4(io)
    end
  end

  struct Datetime_n < TypeInfo
    def initialize(@expected_len : UInt8)
    end

    def self.from_io(io : IO)
      len = UInt8.from_io(io, ENCODING)
      trace(len)
      self.new(len)
    end

    def type : String
      case @expected_len
      when 8
        "DATETIME"
      else
        raise NotImplemented.new
      end
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(TypeInfo::Type::DATETIMN.value), io)
      ENCODING.encode(@expected_len, io)
    end

    def encode(value : Value, io : IO)
      case value
      when Nil
        ENCODING.encode(0x0_u8, io)
      when Time
        raise NotImplemented.new if @expected_len != 8
        ENCODING.encode(0x8_u8, io)
        ms = value.to_unix_ms
        days = UInt32.new(ms/(1000*24*60*60) + 25567)
        fraction = UInt32.new((ms % (1000*24*60*60)) * 300//1000)
        ENCODING.encode(days, io)
        ENCODING.encode(fraction, io)
      else
        raise ProtocolError.new("Unsupported value #{value}")
      end
    end

    def decode(io : IO) : Value
      len = UInt8.from_io(io, ENCODING)
      case len
      when 0
        nil
      when 4
        raise ProtocolError.new if len != @expected_len
        Datetime.read_datetime_4(io)
      when 8
        raise ProtocolError.new if len != @expected_len
        Datetime.read_datetime_8(io)
      else
        raise ProtocolError.new
      end
    end
  end

  struct Decimal < TypeInfo
    def initialize(@precision : UInt8, @scale : UInt8)
    end

    def self.from_io(io : IO)
      type_size = UInt8.from_io(io, ENCODING)
      precision = UInt8.from_io(io, ENCODING)
      trace(precision)
      scale = UInt8.from_io(io, ENCODING)
      trace(scale)
      self.new(precision, scale)
    end

    def type : String
      "DECIMAL(#{@precision},#{@scale}"
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(TypeInfo::Type::DECIMAL.value), io)
    end

    def encode(value : Value, io : IO)
      case value
      when Nil
        ENCODING.encode(0x0_u8, io)
      when BigDecimal
        sign = 1_u8
        if value < 0
          sign = 0_u8
          value = -value
        end
        v = (value * (BigInt.new(10) ** @scale)).to_big_i
        trace(v)
        data = IO::Memory.new
        while v != 0
          data.write_byte(UInt8.new(v % 0x100))
          v = v >> 8
        end
        ENCODING.encode(UInt8.new(data.size + 1), io)
        ENCODING.encode(sign, io)
        io.write(data.to_slice)
      else
        raise ProtocolError.new("Unsupported value #{value}")
      end
    end

    def decode(io : IO) : Value
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
        BigDecimal.new(x, UInt64.new(@scale))
      else
        BigDecimal.new(-x, UInt64.new(@scale))
      end
    end
  end

  struct NVarchar < TypeInfo
    def self.from_io(io : IO)
      large_type_size = Int16.from_io(io, ENCODING)
      read_encoding(io)
      self.new
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(TypeInfo::Type::XNVARCHAR.value), io)
      ENCODING.encode(8000_u16, io)
      ENCODING.encode(0x0409_u16, io)
      ENCODING.encode(0x00d0_u16, io)
      ENCODING.encode(52_u8, io)
    end

    def type
      "NVARCHAR(4000)"
    end

    def encode(value : Value, io : IO)
      case value
      when Nil
        ENCODING.encode(0xFFFF_u16, io)
      when String
        ENCODING.encode(UInt16.new(value.size * 2), io)
        UTF16_IO.write(io, value, ENCODING)
      else
        raise ProtocolError.new("Unsupported value #{value}")
      end
    end

    def decode(io : IO) : Value
      len = UInt16.from_io(io, ENCODING)
      trace(len)
      if len == 0xFFFF_u16
        nil
      else
        UTF16_IO.read(io, len >> 1, ENCODING)
      end
    end

    def self.read_encoding(io : IO)
      lcid = UInt16.from_io(io, ENCODING)
      flags = UInt16.from_io(io, ENCODING)
      charset_id = UInt8.from_io(io, ENCODING)
      Charset.encoding(lcid, flags, charset_id, Version::V7_1)
    end
  end

  struct Varchar < TypeInfo
    def initialize(@encoding : String)
    end

    def self.from_io(io : IO)
      large_type_size = Int16.from_io(io, ENCODING)
      self.new(NVarchar.read_encoding(io))
    end

    def decode(io : IO) : Value
      len = UInt16.from_io(io, ENCODING)
      trace(len)
      if len == 0xFFFF_u16
        nil
      else
        buffer = Bytes.new(len)
        io.read(buffer)
        encoded_io = IO::Memory.new(buffer)
        encoded_io.set_encoding(@encoding, nil)
        encoded_io.gets_to_end
      end
    end
  end

  struct Text < TypeInfo
    def initialize(@encoding : String)
    end

    def self.from_io(io : IO)
      large_type_size = UInt32.from_io(io, ENCODING)
      trace(large_type_size)
      encoding = NVarchar.read_encoding(io)
      trace(encoding)
      table_len = UInt16.from_io(io, ENCODING)
      trace(table_len)
      table_name = UTF16_IO.read(io, table_len, ENCODING)
      trace(table_name)
      self.new(encoding)
    end

    def decode(io : IO) : Value
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
        encoded_io.set_encoding(@encoding, nil)
        encoded_io.gets_to_end
      end
    end
  end

  struct NText < TypeInfo
    def initialize(@encoding : String)
    end

    def self.from_io(io : IO)
      large_type_size = UInt32.from_io(io, ENCODING)
      trace(large_type_size)
      encoding = NVarchar.read_encoding(io)
      trace(encoding)
      table_len = UInt16.from_io(io, ENCODING)
      trace(table_len)
      table_name = UTF16_IO.read(io, table_len, ENCODING)
      trace(table_name)
      self.new(encoding)
    end

    def decode(io : IO) : Value
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

  struct Image < TypeInfo
    def initialize
    end

    def self.from_io(io : IO)
      large_type_size = UInt32.from_io(io, ENCODING)
      trace(large_type_size)
      table_len = UInt16.from_io(io, ENCODING)
      trace(table_len)
      table_name = UTF16_IO.read(io, table_len, ENCODING)
      trace(table_name)
      self.new
    end

    def decode(io : IO) : Value
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
        buffer
      end
    end
  end

  struct UniqueIdentifier < TypeInfo
    def initialize
    end

    def self.from_io(io : IO)
      type_size = UInt8.from_io(io, ENCODING)
      trace(type_size)
      self.new
    end

    def self.swap(buffer, index1, index2)
      tmp = buffer[index1]
      buffer[index1] = buffer[index2]
      buffer[index2] = tmp
    end

    def decode(io : IO) : Value
      len = UInt8.from_io(io, ENCODING)
      trace(len)
      if len == 0
        nil
      else
        buffer = Bytes.new(len)
        io.read(buffer)
        UniqueIdentifier.swap(buffer, 3, 0)
        UniqueIdentifier.swap(buffer, 2, 1)
        UniqueIdentifier.swap(buffer, 4, 5)
        UniqueIdentifier.swap(buffer, 6, 7)
        UUID.new(slice: buffer)
      end
    end
  end

  struct NamedType
    include Trace

    def initialize(@name : String, @type_info : TypeInfo)
    end

    def self.from_io(io : IO)
      user_type = UInt16.from_io(io, ENCODING)
      flags = UInt16.from_io(io, ENCODING)
      trace_push()
      trace(flags)
      trace(user_type)
      type_info = TypeInfo.from_io(io)
      len = UInt8.from_io(io, ENCODING)
      name = UTF16_IO.read(io, UInt16.new(len), ENCODING)
      trace_pop()
      NamedType.new(name, type_info)
    end

    def decode(io) : Value
      trace(@name)
      trace_push()
      result = @type_info.decode(io)
      trace(result)
      trace_pop()
      result
    end
  end
end
