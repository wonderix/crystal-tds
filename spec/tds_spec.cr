require "./spec_helper"
require "big"

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
end
