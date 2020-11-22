module TDS::UTF16_IO
  def self.read(io : IO, len : UInt16 | UInt32, format : IO::ByteFormat) : String
    buffer = Slice(UInt16).new(len)
    len.times { |i| buffer[i] = UInt16.from_io(io, format) }
    String.from_utf16(buffer)
  end

  def self.write(io : IO, str : String, format : IO::ByteFormat)
    str.to_utf16.each { |c| format.encode(c, io) }
    str.size * 2
  end
end
