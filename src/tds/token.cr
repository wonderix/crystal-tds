require "./utf16_io.cr"
require "./errno.cr"

module TDS::Token

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


  def self.each_from_io(io : IO, &block)
    metadata = ColumnsMetaData.new()
    while true
      type = Type.new(Int32.new(io.read_byte().not_nil!))
      case type
      when Type::DONE, Type::DONEINPROC, Type::DONEPROC
        done = Done.from_io(io)
        return
      when Type::ERROR
        token = InfoOrError.from_io(io)
        case token.number
        when EPERM
          raise DB::ConnectionRefused.new(token.message)
        else
          raise ::Exception.new("Error #{token.number}: #{token.message}")
        end
      when Type::INFO
        yield InfoOrError.from_io(io)
      when Type::RESULT_V7
        metadata = ColumnsMetaData.from_io(io)
        yield metadata
      when Type::ENVCHANGE
        yield EnvChange.from_io(io)
      when Type::LOGINACK
        yield LogInAck.from_io(io)
      when Type::ROW
        yield Row.from_io(io, metadata)
      else
        raise ::Exception.new("Invalid token #{"0x%02x" % type}")
      end
    end
  end

  struct EnvChange
    def self.from_io(io : IO)
      len = UInt16.from_io(io,ENCODING)
      io.seek(len,IO::Seek::Current)
    end
  end

  struct LogInAck
    def self.from_io(io : IO)
      len = UInt16.from_io(io,ENCODING)
      io.seek(len,IO::Seek::Current)
    end
  end

  struct Done
    def self.from_io(io : IO)
      io.seek(7,IO::Seek::Current)
    end
  end

  struct InfoOrError

    getter message
    getter number

    def initialize(@message : String, @number : Int32)
    end

    def self.from_io(io : IO)
      len = UInt16.from_io(io,ENCODING)
      start = io.pos
      number = Int32.from_io(io,ENCODING)
      state = UInt8.from_io(io,ENCODING)
      severity = UInt8.from_io(io,ENCODING)
      message_len = UInt16.from_io(io,ENCODING)
      message = UTF16_IO.read(io,message_len,ENCODING)
      io.seek(len - (io.pos - start),IO::Seek::Current)
      return InfoOrError.new(message: message, number: number)
    end
  end

  struct ColumnMetaData
    enum Type 
      CHAR                = 0x2F
      VARCHAR             = 0x27
      INTN                = 0x26
      INT1                = 0x30
      DATE                = 0x31
      TIME                = 0x33
      INT2                = 0x34
      INT4                = 0x38
      INT8                = 0x7F
      FLT8                = 0x3E
      DATETIME            = 0x3D
      BIT                 = 0x32
      TEXT                = 0x23
      NTEXT               = 0x63
      IMAGE               = 0x22
      MONEY4              = 0x7A
      MONEY               = 0x3C
      DATETIME4           = 0x3A
      REAL                = 0x3B
      BINARY              = 0x2D
      VOID                = 0x1F
      VARBINARY           = 0x25
      NVARCHAR            = 0x67
      BITN                = 0x68
      NUMERIC             = 0x6C
      DECIMAL             = 0x6A
      FLTN                = 0x6D
      MONEYN              = 0x6E
      DATETIMN            = 0x6F
      DATEN               = 0x7B
      TIMEN               = 0x93
      XCHAR               = 0xAF
      XVARCHAR            = 0xA7
      XNVARCHAR           = 0xE7
      XNCHAR              = 0xEF
      XVARBINARY          = 0xA5
      XBINARY             = 0xAD
      UNITEXT             = 0xAE
      LONGBINARY          = 0xE1
      SINT1               = 0x40
      UINT2               = 0x41
      UINT4               = 0x42
      UINT8               = 0x43
      UINTN               = 0x44
      UNIQUE              = 0x24
      VARIANT             = 0x62
      SINT8               = 0xBF
    end

    getter type, name
    
    def initialize(@user_type : UInt16, @flags : UInt16, @type : Type, @name : String)
    end
  end

  struct ColumnsMetaData

    getter columns

    def initialize(@columns = [] of ColumnMetaData)
    end

    def self.from_io(io : IO)
      len = UInt16.from_io(io,ENCODING)
      columns = Array(ColumnMetaData).new(len)
      len.times do | i |
        user_type = UInt16.from_io(io,ENCODING)
        flags = UInt16.from_io(io,ENCODING)
        type = ColumnMetaData::Type.new(Int32.new(io.read_byte.not_nil!))
        len = UInt16.new(io.read_byte.not_nil!)
        name = UTF16_IO.read(io,len,ENCODING)
        columns << ColumnMetaData.new(user_type,flags,type,name)
      end
      return ColumnsMetaData.new(columns)
    end
  end

  struct Row
    def initialize(@metadata : ColumnsMetaData, @columns : Array(Bytes))
    end
    def self.from_io(io : IO, metadata : ColumnsMetaData)
      columns = Array(Bytes).new(metadata.columns.size)
      metadata.columns.each do | col |
        case col.type
        when ColumnMetaData::Type::INT1
          c = Bytes.new(1)
          io.read(c)
          columns << c
        else
          raise ::Exception.new("Invalid database type #{col.type}")
        end
      end
      return Row.new(metadata, columns)
    end
  end

end
    
