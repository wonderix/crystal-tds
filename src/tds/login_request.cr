
require "./version"
require "io"




struct TDS::LoginRequest

  property username, password, hostname, appname, servername, extension, library_name, language, database_name, db_filename, new_password, packet_size, process_id

  def initialize(@username : String, @password : String, @hostname = System.hostname , @appname = "", @servername = "", @extension = "", @library_name = "", @language = "", @database_name = "", @db_filename = "", @new_password : String? = nil, @packet_size = 0, @process_id = UInt32.new(Process.pid))
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
    TIME_ZONE = 0_u32
    COLLATION = 0_u32
    SQL_TYPE = 0_u8
    RESERVED = 0_u8
  
  
    def initialize(@io : IO, @version = Version::V7_1)
    end
  
    private def write(fields : IO, buffer : IO,  data : Slice(UInt16))
      if data.size == 0
        ENCODING.encode(0_u16, fields)
        ENCODING.encode(0_u16, fields)
      else
        pos = buffer.pos
        data.each { | i| ENCODING.encode(i,buffer) }
        ENCODING.encode(UInt16.new(pos), fields)
        ENCODING.encode(UInt16.new(data.size), fields)
      end
    end

    private def write(fields : IO, buffer : IO, data : String)
      write(fields, buffer, data.to_utf16)
    end
  
  
    def write_password(fields : IO, buffer : IO, data : String)
      pwd = data.to_utf16.map do | i |
        c = i ^ 0x5A5A
        (c >> 4) & 0x0F0F | (c << 4) & 0xF0F0
      end
      write(fields, buffer, pwd)
    end
  
    def write(req : LoginRequest)
      buffer = IO::Memory.new()
      buffer.seek(4, IO::Seek::Current)
      ENCODING.encode(@version.as_uint32, buffer)
      ENCODING.encode(req.packet_size, buffer)
      ENCODING.encode(PROGRAMM_VERSION, buffer)
      ENCODING.encode(UInt32.new(req.process_id), buffer)
      ENCODING.encode(CONNECTION_ID, buffer)
      ENCODING.encode(UInt8.new(Warning.flags(WARN_ON_USE, SUCCEED_INIT_DB, WARN_ON_LANG).value), buffer)
      ENCODING.encode(UInt8.new(Auth.flags(ODBC).value), buffer)
      ENCODING.encode(SQL_TYPE, buffer)
      ENCODING.encode(RESERVED, buffer)
      ENCODING.encode(TIME_ZONE, buffer)
      ENCODING.encode(COLLATION, buffer)
      field_bytes = Bytes.new(Field.values.size * 4+6)
      fields = IO::Memory.new(field_bytes)
      field_pos = buffer.pos
      buffer.write(field_bytes.to_slice)
      # 0x24
      write(fields, buffer, req.hostname)
      write(fields, buffer, req.username)
      write_password(fields, buffer, req.password)
      write(fields, buffer, req.appname)
      write(fields, buffer, req.servername)
      write(fields, buffer, req.extension)
      write(fields, buffer, req.library_name)
      write(fields, buffer, req.language)
      write(fields, buffer, req.database_name)
      write(fields, buffer, req.db_filename)
      req.new_password.try { |s| write_password(fields, buffer, s)}
      size = buffer.pos
      buffer.seek(0, IO::Seek::Set)
      ENCODING.encode(size, buffer)
      buffer.seek(field_pos, IO::Seek::Set)
      buffer.write(fields.to_slice)
      buffer.seek(size, IO::Seek::Set)
      @io.write(buffer.to_slice)
    end
  end
end