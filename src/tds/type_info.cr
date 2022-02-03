require "uuid"
require "./trace"
require "./errno"

module TDS
  alias Value = Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Float64 | Float32 | String | Time | BigDecimal | Nil | Bytes | UUID | Bool
  alias Decoder = Proc(IO, Value)
  ENCODING = IO::ByteFormat::LittleEndian
end

module TDS
  abstract struct TypeInfo
    enum Type
      INTN       = 0x26
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
      raise ProtocolError.new("Unsupported column type at position #{"0x%04x" % io.pos}")
    end

    def self.from_value(value : Value) : TypeInfo
      raise NotImplemented.new("Invalid type #{value.inspect}")
    end
  end


  struct Int_n < TypeInfo
    def initialize(@expected_len : UInt8)
    end

    def self.from_io(io : IO)
       self.new(1)
    end

    def type : String
        raise NotImplemented.new
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(TypeInfo::Type::INTN.value), io)
      ENCODING.encode(@expected_len, io)
    end

    def encode(value : Value, io : IO)
        raise ProtocolError.new("Unsupported value #{value}")
    end

    def decode(io : IO) : Value
        raise ProtocolError.new
    end
  end


  struct NamedType
    include Trace

    getter name

    def initialize(@name : String, @type_info : TypeInfo)
    end

    def self.from_io(io : IO)
      NamedType.new(name, Int_n.new(1))
    end

    def decode(io) : Value
      nil
    end
  end
end
