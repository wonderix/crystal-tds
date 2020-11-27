require "./token"
require "./type_info"

struct TDS::Parameter
  def initialize(@name : String, @type_info : TypeInfo, @value : Value, @status : UInt8)
  end

  def write(io : IO)
    ENCODING.encode(UInt8.new(@name.size), io)
    UTF16_IO.write(io, @name, ENCODING)
    ENCODING.encode(@status, io)
    @type_info.write(io)
    @type_info.encode(@value, io)
  end
end

struct TDS::RemoteProcedureCall
  PROCEDURE_NAME_LENGTH = 0xffff_u32

  def initialize(@id : UInt16, @parameters = Array(Parameter), @options = 0_u32)
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
