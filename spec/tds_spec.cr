require "./spec_helper"

describe Tds do

  it "works" do
    DB.open "tds:./file.db" do |db|
    end
  end
end
