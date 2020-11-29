require "./utf16_io"
require "./errno"
require "./trace"
require "big"
require "./type_info"
require "./charset"
require "./version"

module TDS::Token
  include Trace

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
      io.seek(8, IO::Seek::Current)
      self.new
    end
  end

  struct DoneInProc
    def self.from_io(io : IO)
      io.seek(8, IO::Seek::Current)
      self.new
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
      self.new(message: message, number: number)
    end
  end

  struct MetaData
    getter columns

    def initialize(@columns = [] of NamedType)
    end

    def self.from_io(io : IO)
      len = UInt16.from_io(io, ENCODING)
      trace(len)
      columns = Array(NamedType).new(len)
      len.times do |i|
        columns << NamedType.from_io(io)
      end
      self.new(columns)
    end
  end

  struct Row
    getter columns
    getter metadata

    def initialize(@metadata : MetaData, @columns : Array(Value))
    end

    def self.from_io(io : IO, metadata : MetaData)
      columns = Array(Value).new(metadata.columns.size)
      metadata.columns.each do |col|
        columns << col.decode(io)
      end
      self.new(metadata, columns)
    end
  end

  struct ReturnStatus
    getter status

    def initialize(@status : UInt32)
    end

    def self.from_io(io : IO)
      self.new(UInt32.from_io(io, ENCODING))
    end
  end

  struct Param
    enum ReturnType
      NORMAL   = 1
      FUNCTION = 2
    end
    getter name
    getter return_type
    getter value

    def initialize(@name : String, @return_type : ReturnType, @value : Value)
    end

    def self.from_io(io : IO)
      len = ENCODING.decode(UInt16, io)
      name = UTF16_IO.read(io, ENCODING.decode(UInt8, io), ENCODING)
      return_type = ReturnType.new(Int32.new(ENCODING.decode(UInt8, io)))
      io.seek(4, IO::Seek::Current)
      type_info = TypeInfo.from_io(io)
      value = type_info.decode(io)
      self.new(name, return_type, value)
    end
  end

  alias Token = InfoOrError | MetaData | LogInAck | Row | Done | DoneInProc | EnvChange | ReturnStatus | Param

  private class Iterator
    include ::Iterator(Token)

    @metadata = MetaData.new

    def initialize(@io : IO)
    end

    def next : Token | ::Iterator::Stop
      type = Type.new(Int32.new(UInt8.from_io(@io, ENCODING)))
      trace(type)
      trace_push()
      result =
        case type
        when Type::DONE, Type::DONEPROC
          done = Done.from_io(@io)
          stop
        when Type::DONEINPROC
          DoneInProc.from_io(@io)
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
          @metadata = MetaData.from_io(@io)
          @metadata
        when Type::ENVCHANGE
          EnvChange.from_io(@io)
        when Type::LOGINACK
          LogInAck.from_io(@io)
        when Type::ROW
          Row.from_io(@io, @metadata)
        when Type::RETURNSTATUS
          ReturnStatus.from_io(@io)
        when Type::PARAM
          Param.from_io(@io)
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
