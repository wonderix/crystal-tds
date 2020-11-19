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
  # it "executes statements" do 
  #   DB.open "tds://sa:asdkwnqwfjasi-asn123@localhost:1433" do |db|
  #     db.exec "create table contacts (name text, age integer)"
  #   end
  # end
end
