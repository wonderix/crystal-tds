
require "./version"




struct TDS::LoginRequest

  property username, password, hostname, appname, servername, extension, library_name, language, database_name, db_filename, new_password, packet_size

  def initialize(@username : String, @password : String, @hostname = "localhost", @appname = "", @servername = "", @extension = "", @library_name = "", @language = "", @database_name = "", @db_filename = "", @new_password : String? = nil, @packet_size = 0)
  end

  def write(io : IO, version = Version::V7_1)
    info_io = Serializer.new(io, version: version)
    info_io.write(self)
  end


  class Serializer

    enum Field
      HOST_NAME
      USER_NAME
      PASSWORD
      APP_NAME
      SERVER_NAME
      EXTENSION
      LIBRARY_NAME
      LANGUAGE
      DATABASE_NAME
      DB_FILENAME
      NEW_PASSWORD
    end

    enum Warning
      WARN_ON_USE = 0x20
      SUCCEED_INIT_DB = 0x40
      WARN_ON_LANG = 0x80
    end

    enum Auth
      ODBC = 0x03
      NTLM = 0x80
    end

    ENCODING = IO::ByteFormat::LittleEndian
    PROGRAMM_VERSION = 7_i32
    CONNECTION_ID = 0_i32
  
    @fields = Array(Tuple(UInt16,UInt16)).new(Field.values.size,{0_u16,0_u16})
    @buffer = IO::Memory.new()
  
    def initialize(@io : IO, @version = Version::V7_1)
    end
  
    private def write(field : Field, data : String)
      io = IO::Memory.new(data.size * 2)
      data.to_utf16.each { |i | ENCODING.encode(i,io) }
      write(field, io.to_slice)
    end
  
    private def write(field : Field, data : Bytes)
      pos = @buffer.pos
      @buffer.write(data)
      @fields[field.value] = {UInt16.new(pos + Field.values.size * 4),UInt16.new(@buffer.pos - pos)}
    end
  
    def write_password(field : Field, data : String)
      source = data.to_slice
      dest = Bytes.new(source.size)
      source.size.times.each do | i |
        dest[i] = ((source[i] << 4) | (source[i] >> 4)) ^ 0xA5
      end
      write(field, dest)
    end
  
    def write(req : LoginRequest)
      write(Field::HOST_NAME,req.hostname)
      write(Field::USER_NAME,req.username)
      write_password(Field::PASSWORD,req.password)
      write(Field::SERVER_NAME,req.servername)
      write(Field::EXTENSION, req.extension)
      write(Field::LIBRARY_NAME,req.library_name)
      write(Field::LANGUAGE,req.language)
      write(Field::DATABASE_NAME,req.database_name)
      write(Field::DB_FILENAME,req.db_filename)
      req.new_password.try { |s| write_password(Field::NEW_PASSWORD,s)}
      packet_size = Field.values.size * 4 + @buffer.pos
      ENCODING.encode(packet_size,@io)
      ENCODING.encode(@version.as_uint32,@io)
      ENCODING.encode(req.packet_size,@io)
      ENCODING.encode(PROGRAMM_VERSION,@io)
      ENCODING.encode(UInt32.new(Process.pid),@io)
      ENCODING.encode(CONNECTION_ID,@io)
      ENCODING.encode(UInt8.new(Warning.flags(WARN_ON_USE, SUCCEED_INIT_DB, WARN_ON_LANG).value),@io)
      ENCODING.encode(Auth.flags(ODBC).value,@io)
    end
  end
end