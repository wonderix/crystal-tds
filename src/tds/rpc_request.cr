require "./token"
require "./type_info"

module TDS
  struct Parameter
    enum Status
      BY_REFERENCE  = 0x01
      DEFAULT_VALUE = 0x02
    end
    @type_info : TypeInfo

    def initialize(@value : Value, type_info : TypeInfo? = nil, @name = "", @status = Status.new(0))
      @type_info = type_info ||
                   case @value
                   when String
                     NVarchar.new
                   when Int32
                     Int_n.new(4)
                   when Int16
                     Int_n.new(2)
                   else
                     raise NotImplemented.new
                   end
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

    def initialize(@id : UInt16, @parameters : Array(Parameter), @options = 0_u16)
    end

    def write(io : IO)
      ENCODING.encode(PROCEDURE_NAME_LENGTH, io)
      ENCODING.encode(@id, io)
      ENCODING.encode(@options, io)
      @parameters.each do |parameter|
        parameter.write(io)
      end
    end
  end
end
