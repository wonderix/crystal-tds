require "./token"
require "./type_info"

module TDS
  struct Parameter
    enum Status
      BY_REFERENCE  = 0x01
      DEFAULT_VALUE = 0x02
    end

    getter value : Value, type_info : TypeInfo, name : String, status : Status

    def initialize(@value : Value, type_info : TypeInfo? = nil, @name = "", @status = Status.new(0))
      @type_info = type_info || TypeInfo.from_value(@value)
    end

    def write(io : IO)
      ENCODING.encode(UInt8.new(@name.size), io)
      UTF16_IO.write(io, @name, ENCODING)
      ENCODING.encode(UInt8.new(@status.value), io)
      @type_info.write(io)
      @type_info.encode(@value, io)
    end
  end

  struct RpcRequest
    PROCEDURE_NAME_LENGTH = 0xffff_u16

    enum Type
      EXECUTE   = 12
      PREPARE   = 11
      UNPREPARE = 15
    end

    def initialize(@id : Type, @parameters : Array(Parameter), @options = 0_u16)
    end

    def write(io : IO)
      ENCODING.encode(PROCEDURE_NAME_LENGTH, io)
      ENCODING.encode(UInt16.new(@id.value), io)
      ENCODING.encode(@options, io)
      @parameters.each do |parameter|
        parameter.write(io)
      end
    end
  end
end
