require "./spec_helper"
require "big"

describe TDS::Connection do
  it "connects" do
    DB.open URL do |db|
    end
  end
  it "raises DB::ConnectionRefused" do
    expect_raises(DB::ConnectionRefused) do
      DB.open "tds://sa:wrong-password@#{HOSTNAME}:1433" do |db|
      end
    end
  end
  it "raises DB::ConnectionRefused" do
    expect_raises(DB::ConnectionRefused) do
      DB.open "tds://#{HOSTNAME}:5555" do |db|
      end
    end
  end
  it "prepare statement" do
    connection = DB.connect(URL).as(TDS::Connection)
    connection.sp_prepare("@P0 int", "SELECT c1 FROM TEST WHERE c1 =  @P0 ").should eq 1
    connection.close
  end
end
