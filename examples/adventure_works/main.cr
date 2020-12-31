require "uuid"
require "../../src/tds"

DB.open("tds://sa:My-Secret-Pass@localhost:1433/AdventureWorks") do |db|
  db.query "SELECT AddressID, AddressLine1, AddressLine2, City, StateProvinceID, PostalCode, SpatialLocation, rowguid, ModifiedDate FROM [Person].[Address]" do |rs|
    rs.each do
      puts "#{rs.read(Int32)} #{rs.read(String?)}  #{rs.read(String?)} #{rs.read(String?)} #{rs.read(Int32?)} #{rs.read(String?)} #{rs.read(Bytes)} #{rs.read(UUID)} #{rs.read(Time)}"
    end
  end
end
