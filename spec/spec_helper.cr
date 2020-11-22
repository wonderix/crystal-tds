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

HOSTNAME = ENV["MSSQL_HOST"]? || "localhost"
DATABASE = DB.open("tds://sa:My-Secret-Pass@#{HOSTNAME}:1433")
# DATABASE.exec("DROP TABLE IF EXISTS TEST")
# DATABASE.exec("CREATE TABLE TEST (c1 TINYINT)")
# DATABASE.exec("INSERT INTO TEST (c1) VALUES (1)")
