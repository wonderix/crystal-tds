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
    while true
      type = Type.new(Int32.new(io.read_byte().not_nil!))
      len = UInt16.from_io(io,ENCODING)
      start = io.pos
      case type
      when Type::DONE, Type::DONEINPROC, Type::DONEPROC
        return
      when Type::ERROR
        raise Error.from_io(io)
      when Type::INFO
        yield Error.from_io(io)
      when Type::ENVCHANGE
      when Type::LOGINACK
      else
        raise ::Exception.new("Invalid token #{"0x%02x" % type}")
      end
      io.seek(len - (io.pos - start),IO::Seek::Current)
    end
  end

  class Error < ::Exception

    def initialize(message)
      super(message)
    end

    def self.from_io(io : IO)
      number = Int32.from_io(io,ENCODING)
      state = UInt8.from_io(io,ENCODING)
      severity = UInt8.from_io(io,ENCODING)
      message_len = UInt16.from_io(io,ENCODING)
      message = UTF16_IO.read(io,message_len,ENCODING)
      case number
      when EPERM
        return DB::ConnectionRefused.new(message)
      else
        Error.new(message)
      end
    end
  end
end
    
      