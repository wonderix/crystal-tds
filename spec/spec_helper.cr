require "spec"
require "../src/tds"

def connect(connection_string)
  timeout = Time::Span.new(seconds: 60)
  expiry = Time.local + timeout

  uri = URI.parse connection_string
  uri.query_params["connect_timeout"] = "#{(timeout/5).seconds}"

  while true
    begin
      return DB.open(uri)
    rescue exc : DB::ConnectionRefused
      raise exc if Time.local > expiry
      sleep(5)
    end
  end
end

Log.setup_from_env

HOST = ENV["MSSQL_HOST"]? || "localhost"
PORT = ENV["MSSQL_PORT"]? || "1433"
USER = ENV["MSSQL_USER"]? || "sa"
PASSWORD = ENV["MSSQL_PASSWORD"]? || "My-Secret-Pass"
DATABASE_NAME = "test"

DATABASE_URI = "tds://#{USER}:#{PASSWORD}@#{HOST}:#{PORT}/#{DATABASE_NAME}?isolation_level=SNAPSHOT"

MASTER = connect(DATABASE_URI.sub("/#{DATABASE_NAME}", ""))
begin
  MASTER.exec("CREATE DATABASE #{DATABASE_NAME}")
rescue exc : DB::Error
end
MASTER.exec("ALTER DATABASE #{DATABASE_NAME} SET ALLOW_SNAPSHOT_ISOLATION ON")
DATABASE = connect(DATABASE_URI)

DATABASE.exec("DROP TABLE IF EXISTS TEST")
DATABASE.exec("CREATE TABLE TEST (c1 TINYINT)")
DATABASE.exec("INSERT INTO TEST (c1) VALUES (1)")
