require "./spec_helper"
require "db/spec"

DB::DriverSpecs(DB::Any).run do
  connection_string DATABASE_URI

  before do
  end

  after do
    # ...
  end

  # Unsupported By DB::DriverSpecs::ValueDef
  # sample_value BigDecimal.new(1,0), "DECIMAL(19,2)", "1"
  # sample_value , "NUMERIC(10,5)", "1"
  # sample_value 1_i8, "TINYINT", "1"
  # sample_value 1_i16 , "SMALLINT", "1"

  sample_value "hello", "VARCHAR(25)", "'hello'"
  sample_value 1_i32, "INT", "1"
  sample_value 1_i64, "BIGINT", "1"
  sample_value 1.0_f64, "FLOAT", "1.0"
  sample_value 1.0_f32, "REAL", "1.0"
  sample_value "hello", "NVARCHAR(25)", "'hello'"
  sample_value Time.utc(2016, 2, 15, 10, 20, 30), "DATETIME", "'2016-02-15 10:20:30.000'", type_safe_value: false
  sample_value Time.utc(2016, 2, 15, 10, 20, 30), "DATETIME2", "'2016-02-15 10:20:30.000000'", type_safe_value: false
  sample_value Time.utc(2016, 2, 15, 10, 21, 0), "SMALLDATETIME", "'2016-02-15 10:21:00'", type_safe_value: false
  sample_value Time.utc(2016, 2, 15), "DATE", "'2016-02-15'", type_safe_value: false
  sample_value "hello", "TEXT", "'hello'"
  sample_value "hello", "NTEXT", "'hello'"

  binding_syntax do |index|
    "?"
  end

  create_table_1column_syntax do |table_name, col1|
    "create table #{table_name} (#{col1.name} #{col1.sql_type} #{col1.null ? "NULL" : "NOT NULL"})"
  end

  create_table_2columns_syntax do |table_name, col1, col2|
    "create table #{table_name} (#{col1.name} #{col1.sql_type} #{col1.null ? "NULL" : "NOT NULL"}, #{col2.name} #{col2.sql_type} #{col2.null ? "NULL" : "NOT NULL"})"
  end

  select_1column_syntax do |table_name, col1|
    "select #{col1.name} from #{table_name}"
  end

  select_2columns_syntax do |table_name, col1, col2|
    "select #{col1.name}, #{col2.name} from #{table_name}"
  end

  select_count_syntax do |table_name|
    "select count(*) from #{table_name}"
  end

  select_scalar_syntax do |expression, sql_type|
    "select #{expression}"
  end

  insert_1column_syntax do |table_name, col, expression|
    "insert into #{table_name} (#{col.name}) values (#{expression})"
  end

  insert_2columns_syntax do |table_name, col1, expr1, col2, expr2|
    "insert into #{table_name} (#{col1.name}, #{col2.name}) values (#{expr1}, #{expr2})"
  end

  drop_table_if_exists_syntax do |table_name|
    "drop table if exists #{table_name}"
  end
end
