require "./spec_helper"

describe TDS::Statement do
  it "handles ints" do
    DATABASE.query_one "SELECT CAST(? as INT)", 1 { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles strings" do
    DATABASE.query_one "SELECT ?", "'CREATE TABLE" { |rs| rs.read(String) }.should eq "'CREATE TABLE"
  end
end
