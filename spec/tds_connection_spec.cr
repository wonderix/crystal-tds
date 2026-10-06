require "./spec_helper"
require "big"

describe TDS::Connection do
  it "connects" do
    DB.open DATABASE_URI do |db|
    end
  end
  it "raises DB::Error" do
    expect_raises(DB::Error) do
      DB.open "tds://#{USER}:#{PASSWORD + "XYZ"}@#{HOST}:#{PORT}" do |db|
      end
    end
  end
  it "raises DB::ConnectionRefused" do
    expect_raises(DB::ConnectionRefused) do
      DB.open "tds://#{HOST}:65535" do |db|
      end
    end
  end
  it "prepare statement" do
    connection = DB.connect(DATABASE_URI).as(TDS::Connection)
    connection.sp_prepare("@P0 int", "SELECT c1 FROM TEST WHERE c1 =  @P0 ").should eq 1
    connection.close
  end
  it "reports the driver name" do
    DB.connect DATABASE_URI do |connection|
      connection.driver_name.should eq "tds"
    end
  end
  it "reports the server name" do
    DB.connect DATABASE_URI do |connection|
      connection.server_name.should eq "Microsoft SQL Server"
    end
  end
  it "reports the server version" do
    DB.connect DATABASE_URI do |connection|
      # LOGINACK carries major.minor.build, SERVERPROPERTY also includes the revision
      product_version = connection.scalar("SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128))").as(String)
      product_version.should start_with "#{connection.server_version}."
    end
  end
end
