require "./spec_helper"

describe Tds do

  it "works" do
    DB.open "tds://sa:asdkwnqwfjasi-asn123@localhost:1433" do |db|
    end
  end
end
