require "./spec_helper"

describe TDS do
  it "connects" do
    DB.open "tds://sa:asdkwnqwfjasi-asn123@localhost:1433" do |db|
    end
  end
  it "raises DB::ConnectionRefused" do
    expect_raises(DB::ConnectionRefused) do
      DB.open "tds://sa:wrong-password@localhost:1433" do |db|
      end
    end
  end
  it "raises DB::ConnectionRefused" do
    expect_raises(DB::ConnectionRefused) do
      DB.open "tds://localhost:5555" do |db|
      end
    end
  end
  it "executes query", focus: true do
    DB.open "tds://sa:asdkwnqwfjasi-asn123@localhost:1433" do |db|
      rows = 0
      db.query "SELECT @@MAX_PRECISION, @@LANGUAGE, @@VERSION, @@LOCK_TIMEOUT, @@MAX_CONNECTIONS, @@NESTLEVEL, @@OPTIONS, @@REMSERVER, @@SERVERNAME, @@SERVICENAME, @@SPID, @@TEXTSIZE, @@VERSION, CURRENT_TIMESTAMP , CAST(12345.67 as DECIMAL(10,2))" do |rs|
        rs.each do
          rs.read(Int8).should eq 38_i8
          rs.read(String).empty?.should be_false
          rows += 1
        end
      end
      rows.should eq 1
    end
  end
end
