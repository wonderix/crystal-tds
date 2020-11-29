require "spec"
require "../src/tds"

def connect(url)
  timeout = Time::Span.new(seconds: 60)
  expiry = Time.local + timeout
  url = "#{url}?connect_timeout=#{(timeout/5).seconds}"
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
URL      = "tds://sa:My-Secret-Pass@#{HOSTNAME}:1433"
DATABASE = connect(URL)
DATABASE.exec("DROP TABLE IF EXISTS TEST")
DATABASE.exec("CREATE TABLE TEST (c1 TINYINT)")
DATABASE.exec("INSERT INTO TEST (c1) VALUES (1)")
