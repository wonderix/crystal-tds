require "./utf16_io"
require "./errno"
require "./trace"
require "big"
require "./decoder"
require "./charset"
require "./version"

module TDS::Token
  include Trace

  ENCODING = IO::ByteFormat::LittleEndian

  enum Type
    PARAMFMT2         = 0x20
    LANG              = 0x21
    TDS5_WIDE_RESULT  = 0x61
    CLOSE             = 0x71
    OFFSETS           = 0x78
    RETURNSTATUS      = 0x79
    TDS_PROCID        = 0x7C
    RESULT_V7         = 0x81
    ALTMETADATA_TOKEN = 0x88
    COLNAME           = 0xA0
    COLFMT            = 0xA1
    TABNAME           = 0xA4
    COLINFO           = 0xA5
    ALT_NAMES         = 0xA7
    ALT_RESULT        = 0xA8
    ORDER             = 0xA9
    ERROR             = 0xAA
    INFO              = 0xAB
    PARAM             = 0xAC
    LOGINACK          = 0xAD
    CONTROL           = 0xAE
    ROW               = 0xD1
    TDS_ALTROW        = 0xD3
    PARAMS            = 0xD7
    CAP               = 0xE2
    ENVCHANGE         = 0xE3
    MSG50             = 0xE5
    DBRPC             = 0xE6
    DYNAMIC           = 0xE7
    PARAMFMT          = 0xEC
    AUTH              = 0xED
    RESULT            = 0xEE
    DONE              = 0xFD
    DONEPROC          = 0xFE
    DONEINPROC        = 0xFF
  end

  struct EnvChange
    getter type, old_value, new_value

    def initialize(@type : UInt8, @old_value : String, @new_value : String)
    end

    def self.from_io(io : IO)
      len = UInt16.from_io(io, ENCODING)
      start = io.pos
      type = UInt8.from_io(io, ENCODING)
      if type == 4_u8
        old_len = UInt8.from_io(io, ENCODING)
        old_value = UTF16_IO.read(io, UInt16.new(old_len), ENCODING)
        new_len = UInt8.from_io(io, ENCODING)
        new_value = UTF16_IO.read(io, UInt16.new(new_len), ENCODING)
        EnvChange.new(type, old_value, new_value)
      else
        io.seek(len - (io.pos - start), IO::Seek::Current)
        EnvChange.new(type, "", "")
      end
    end
  end

  struct LogInAck
    def self.from_io(io : IO)
      len = UInt16.from_io(io, ENCODING)
      io.seek(len, IO::Seek::Current)
      LogInAck.new
    end
  end

  struct Done
    def self.from_io(io : IO)
      io.seek(7, IO::Seek::Current)
      Done.new
    end
  end

  struct InfoOrError
    getter message
    getter number

    def initialize(@message : String, @number : Int32)
    end

    def self.from_io(io : IO)
      len = UInt16.from_io(io, ENCODING)
      start = io.pos
      number = Int32.from_io(io, ENCODING)
      state = UInt8.from_io(io, ENCODING)
      severity = UInt8.from_io(io, ENCODING)
      message_len = UInt16.from_io(io, ENCODING)
      message = UTF16_IO.read(io, message_len, ENCODING)
      io.seek(len - (io.pos - start), IO::Seek::Current)
      InfoOrError.new(message: message, number: number)
    end
  end

  struct ColumnMetaData
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

    getter name

    def initialize(@user_type : UInt16, @flags : UInt16, @decoder : IO -> Value, @name : String)
    end

    def self.read_encoding(io : IO)
      lcid = UInt16.from_io(io, ENCODING)
      flags = UInt16.from_io(io, ENCODING)
      charset_id = UInt8.from_io(io, ENCODING)
      Charset.encoding(lcid, flags, charset_id, Version::V7_1)
    end

    def self.skip_numeric_info(io : IO)
      large_type_size = Int16.from_io(io, ENCODING)
      codepage = Int16.from_io(io, ENCODING)
      flags = Int16.from_io(io, ENCODING)
      charset = Int8.from_io(io, ENCODING)
    end

    def self.from_io(io : IO)
      user_type = UInt16.from_io(io, ENCODING)
      flags = UInt16.from_io(io, ENCODING)
      type = Type.new(Int32.new(io.read_byte.not_nil!))
      trace(type)
      trace_push()
      trace(flags)
      trace(user_type)
      decoder =
        case type
        when Type::INT1
          Decoders.int1
        when Type::INT2
          Decoders.int2
        when Type::INT4
          Decoders.int4
        when Type::INT8
          Decoders.int8
        when Type::INTN
          len = UInt8.from_io(io, ENCODING)
          trace(len)
          Decoders.intn(len)
        when Type::SINT1
          Decoders.sint1
        when Type::UINT2
          Decoders.uint2
        when Type::UINT4
          Decoders.uint4
        when Type::UINT8
          Decoders.uint8
        when Type::UINTN
          len = UInt8.from_io(io, ENCODING)
          trace(len)
          Decoders.uintn(len)
        when Type::FLT8
          Decoders.flt8
        when Type::FLTN
          len = UInt8.from_io(io, ENCODING)
          trace(len)
          Decoders.fltn(len)
        when Type::DATETIME
          Decoders.datetime
        when Type::DATETIME4
          Decoders.datetime4
        when Type::DATETIMN
          len = UInt8.from_io(io, ENCODING)
          trace(len)
          Decoders.datetimn(len)
        when Type::NUMERIC, Type::DECIMAL
          type_size = UInt8.from_io(io, ENCODING)
          precision = UInt8.from_io(io, ENCODING)
          trace(precision)
          scale = UInt8.from_io(io, ENCODING)
          trace(scale)
          Decoders.decimal(precision, scale)
        when Type::XNVARCHAR, Type::XNCHAR
          large_type_size = Int16.from_io(io, ENCODING)
          read_encoding(io)
          Decoders.xnvarchar
        when Type::XVARCHAR, Type::XCHAR
          large_type_size = Int16.from_io(io, ENCODING)
          Decoders.xvarchar(read_encoding(io))
        when Type::TEXT
          large_type_size = UInt32.from_io(io, ENCODING)
          trace(large_type_size)
          encoding = read_encoding(io)
          trace(encoding)
          table_len = UInt16.from_io(io, ENCODING)
          trace(table_len)
          table_name = UTF16_IO.read(io, UInt16.new(table_len), ENCODING)
          trace(table_name)
          Decoders.text(encoding)
        when Type::NTEXT
          large_type_size = UInt32.from_io(io, ENCODING)
          trace(large_type_size)
          encoding = read_encoding(io)
          trace(encoding)
          table_len = UInt16.from_io(io, ENCODING)
          trace(table_len)
          table_name = UTF16_IO.read(io, UInt16.new(table_len), ENCODING)
          trace(table_name)
          Decoders.ntext
        else
          raise ProtocolError.new("Unsupported column type #{type} at position #{"0x%04x" % io.pos}")
        end
      len = UInt8.from_io(io, ENCODING)
      name = UTF16_IO.read(io, UInt16.new(len), ENCODING)
      trace_pop()
      ColumnMetaData.new(user_type, flags, decoder, name)
    end

    def read(io) : Value
      trace(@name)
      trace_push()
      result = @decoder.call(io)
      trace(result)
      trace_pop()
      result
    end
  end

  struct ColumnsMetaData
    include Trace
    getter columns

    def initialize(@columns = [] of ColumnMetaData)
    end

    def self.from_io(io : IO)
      len = UInt16.from_io(io, ENCODING)
      trace(len)
      columns = Array(ColumnMetaData).new(len)
      len.times do |i|
        columns << ColumnMetaData.from_io(io)
      end
      ColumnsMetaData.new(columns)
    end
  end

  struct Row
    include Trace
    getter columns
    getter metadata

    def initialize(@metadata : ColumnsMetaData, @columns : Array(Value))
    end

    def self.from_io(io : IO, metadata : ColumnsMetaData)
      columns = Array(Value).new(metadata.columns.size)
      metadata.columns.each do |col|
        columns << col.read(io)
      end
      Row.new(metadata, columns)
    end
  end

  alias Token = InfoOrError | ColumnsMetaData | LogInAck | Row | Done | EnvChange

  private class Iterator
    include Trace
    include ::Iterator(Token)

    @metadata = ColumnsMetaData.new

    def initialize(@io : IO)
    end

    def next : Token | ::Iterator::Stop
      type = Type.new(Int32.new(UInt8.from_io(@io, ENCODING)))
      trace(type)
      trace_push()
      result =
        case type
        when Type::DONE, Type::DONEINPROC, Type::DONEPROC
          done = Done.from_io(@io)
          stop
        when Type::ERROR
          token = InfoOrError.from_io(@io)
          case token.number
          when EPERM
            raise DB::ConnectionRefused.new(token.message)
          when 102
            raise SyntaxError.new("Syntax error: #{token.message}")
          else
            raise ProtocolError.new("Error #{token.number}: #{token.message}")
          end
        when Type::INFO
          InfoOrError.from_io(@io)
        when Type::RESULT_V7
          @metadata = ColumnsMetaData.from_io(@io)
          @metadata
        when Type::ENVCHANGE
          EnvChange.from_io(@io)
        when Type::LOGINACK
          LogInAck.from_io(@io)
        when Type::ROW
          Row.from_io(@io, @metadata)
        else
          raise ProtocolError.new("Invalid token #{"0x%02x" % type} at position #{"0x%04x" % @io.pos}")
          Done.new
        end
      trace_pop()
      result
    end
  end

  def self.each(io : IO)
    Iterator.new(io)
  end

  def self.each(io : IO, &block : Token ->)
    Iterator.new(io).each(&block)
  end
end
