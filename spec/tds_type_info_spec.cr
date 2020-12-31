require "big"
require "./spec_helper"

def test_encoding(type_info, value)
  io = IO::Memory.new
  type_info.encode(value, io)
  io.rewind
  type_info.decode(io).should eq value
end

describe TDS::TypeInfo do
  describe TDS::Decimal do
    it "encodes and decodes correct" do
      test_encoding(TDS::Decimal.new(19, 2), BigDecimal.new(10.02))
      test_encoding(TDS::Decimal.new(12, 3), BigDecimal.new(-10.02))
      test_encoding(TDS::Decimal.new(12, 3), nil)
    end
  end
  describe TDS::Datetime_n do
    it "encodes and decodes correct" do
      test_encoding(TDS::Datetime_n.new(8), Time.utc(2016, 2, 15, 10, 20, 30))
      test_encoding(TDS::Datetime_n.new(8), nil)
    end
  end
  describe TDS::Int_n do
    it "encodes and decodes correct" do
      test_encoding(TDS::Int_n.new(1), 12)
      test_encoding(TDS::Int_n.new(2), 1234)
      test_encoding(TDS::Int_n.new(4), 1234)
      test_encoding(TDS::Int_n.new(8), 1234)
      test_encoding(TDS::Int_n.new(8), nil)
    end
  end
  describe TDS::Flt_n do
    it "encodes and decodes correct" do
      test_encoding(TDS::Flt_n.new(4), 1.0)
      test_encoding(TDS::Flt_n.new(8), 1.0)
      test_encoding(TDS::Flt_n.new(8), nil)
    end
  end
  describe TDS::NVarchar do
    it "encodes and decodes correct" do
      test_encoding(TDS::NVarchar.new, "test")
      test_encoding(TDS::NVarchar.new, nil)
    end
  end
end
