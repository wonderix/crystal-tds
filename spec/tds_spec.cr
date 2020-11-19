require "./spec_helper"


describe TDS do

  it "connects" do
    DB.open "tds://sa:asdkwnqwfjasi-asn123@localhost:1433" do |db|
    end
  end
  it "raises DB::ConnectionRefused"  do
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
      db.query "SELECT @@MAX_PRECISION\r\nSET TRANSACTION ISOLATION LEVEL READ COMMITTED\r\nSET IMPLICIT_TRANSACTIONS OFF\r\nSET QUOTED_IDENTIFIER ON\r\nSET TEXTSIZE 2147483647" do |rs|
      end
    end
  end
end
