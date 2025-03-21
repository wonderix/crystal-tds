require "./spec_helper"

describe TDS::UnpreparedStatement do
  it "handles parameters" do
    DATABASE.using_connection do |connection|
      statement = TDS::UnpreparedStatement.new(connection, "SELECT CAST(c1 as INT) FROM TEST WHERE c1 = ?")
      statement.query(1) do |rs|
        rs.each do
          rs.read(Int32).should eq 1
        end
      end
    end
  end
end

describe TDS::PreparedStatement do
  it "handles ints" do
    DATABASE.query_one "SELECT CAST(? as INT)", 1 { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles strings" do
    DATABASE.query_one "SELECT ?", "'CREATE TABLE" { |rs| rs.read(String) }.should eq "'CREATE TABLE"
  end
  it "handles SELECT" do
    DATABASE.query_one "SELECT CAST(c1 as INT) FROM TEST WHERE c1 = ?", 1 { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles ORDER BY" do
    DATABASE.query_one "SELECT CAST(c1 as INT) FROM TEST WHERE c1 = ? ORDER BY 1", 1 { |rs| rs.read(Int32) }.should eq 1
  end
  it "should not raise exception when prepared on first execution with nil argument then later executed with non-nil argument" do
    DATABASE.using_connection do |connection|
      statement = TDS::PreparedStatement.new(connection, "SELECT CAST(c1 as INT) FROM TEST WHERE c1 = ?")
      statement.query nil
      statement.query 1
    end
  end
  it "handles query with question mark parameter and quoted string including a question mark" do
    DATABASE.query_one "SELECT 1 WHERE ? LIKE '%?'", "Wherefore art thou?" { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles query with quoted values and comments that contain parameter like tokens" do
    statement = <<-SQL
    -- comment with ? and @p1 and @test
    DECLARE @namedparam INT = 1
    SELECT CAST(c1 as INT) -- another comment with ? and @p1 and @test
    FROM TEST
    WHERE c1 = ?
    /* multi-line (1/2) comment with ? and @p1 and @test
       multi-line (2/2) comment with ? and @p1 and @test
    */
    OR c1 LIKE '%?'
    OR @namedparam = ?
    OR c1 = '' /* another comment with ? and @p1 and @test */
    SQL

    DATABASE.query_one statement, 1, 1 { |rs| rs.read(Int32) }.should eq 1
  end

  it "handles query with $1 parameter" do
    DATABASE.query_one "SELECT 1 WHERE $1 LIKE '$%'", "$1,000.00" { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles query with multiple $-prefixed parameters" do
    DATABASE.query_one "SELECT CAST(c1 as INT) FROM TEST WHERE c1 = $1 OR c1 = $2", 1, 2 { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles query with reused $-prefixed parameters" do
    DATABASE.query_one "SELECT $2 FROM TEST WHERE c1 = $1 OR c1 = $2", 1, 2 { |rs| rs.read(Int32) }.should eq 2
  end
  it "raises when query mixes use of ? and $-prefixed parameters" do
    expect_raises(DB::Error, "Mixed use of parameter placeholders") do
      DATABASE.query_one "SELECT $2 FROM TEST WHERE c1 = $1 OR c1 = $2 OR $2 = ?", 1, 2, 3 { |rs| rs.read(Int32) }.should eq 2
    end
  end
  it "handles query with escaped single quote in single-quoted literal" do
    DATABASE.query_one "SELECT 1 WHERE $1 LIKE '''a%'", "'abc'" { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles query with escaped double quote in double-quoted literal" do
    DATABASE.query_one "SET QUOTED_IDENTIFIER OFF; SELECT 1 WHERE $1 LIKE \"\"\"a%\"", "\"abc" { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles query with double-quoted identifier" do
    DATABASE.query_one "SET QUOTED_IDENTIFIER ON; SELECT 1 FROM \"TEST\"" { |rs| rs.read(Int32) }.should eq 1
  end
  it "handles query with escaped right bracket in bracket-quoted identifier" do
    DATABASE.query_one "SELECT CAST([TEST[]]].c1 AS INT) FROM TEST AS [TEST[]]] WHERE c1 = $1", 1 { |rs| rs.read(Int32) }.should eq 1
  end
end
