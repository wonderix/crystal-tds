require "spec"
require "../src/tds"

class DB::ResultSet
  class Iterator
    include ::Iterator(DB::ResultSet)

    def initialize(@rs : DB::ResultSet)
    end

    def next
      if @rs.move_next
        @rs
      else
        stop
      end
    end
  end

  def each
    Iterator.new(self)
  end
end

def connect(hostname)
  timeout = Time::Span.new(seconds: 60)
  expiry = Time.local + timeout
  url = "tds://sa:My-Secret-Pass@#{hostname}:1433?connect_timeout=#{(timeout/5).seconds}"
  database = nil
  while true
    begin
      return DB.open(url)
    rescue exc : DB::ConnectionRefused
      raise exc if Time.local > expiry
      sleep(5)
    end
  end
end

HOSTNAME = ENV["MSSQL_HOST"]? || "localhost"
DATABASE = connect(HOSTNAME)
# DATABASE.exec("DROP TABLE IF EXISTS TEST")
# DATABASE.exec("CREATE TABLE TEST (c1 TINYINT)")
# DATABASE.exec("INSERT INTO TEST (c1) VALUES (1)")
