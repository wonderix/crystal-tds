require "./spec_helper"

describe TDS do
  it "connects" do
    DB.open "tds://sa:My-Secret-Pass@localhost:1433" do |db|
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
  describe "decoders" do
    it "TINYINT" do
      DATABASE.query "SELECT @@MAX_PRECISION, @@MAX_PRECISION" { |rs| rs.each.map { |rs| rs.read(Int8); rs.read(Int8) }.first }.should eq 38
    end

    it "TINYINT" do
      DATABASE.query "SELECT CAST(1 as TINYINT), CAST(1 as TINYINT)" { |rs| rs.each.map { |rs| rs.read(Int8) }.first }.should eq 1
    end

    it "SMALLINT" do
      DATABASE.query "SELECT CAST(1 as SMALLINT)" { |rs| rs.each.map { |rs| rs.read(Int16) }.first }.should eq 1
    end

    it "INT" do
      DATABASE.query "SELECT CAST(1 as INT)" { |rs| rs.each.map { |rs| rs.read(Int32) }.first }.should eq 1
    end

    it "BIGINT" do
      DATABASE.query "SELECT CAST(1 as BIGINT)" { |rs| rs.each.map { |rs| rs.read(Int64) }.first }.should eq 1
    end
  end
end
