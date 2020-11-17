require "./spec_helper"


include TDS

HELLO_DATA = Bytes[18, 1, 0, 14, 0, 0, 0, 0, 72, 101, 108, 108, 111, 10]

describe PacketIO do

  it "writes correct" do
    io = IO::Memory.new()
    PacketIO.send(io, PacketType::PRE_LOGIN ) do | io |
      io.puts("Hello")
    end
    io.to_slice[0,io.pos].should eq HELLO_DATA
  end

  it "reads pre login correct" do 
    io = IO::Memory.new(HELLO_DATA)
    PacketIO.recv(io) do | io |
      io.gets().should eq "Hello"
    end

  end
end
