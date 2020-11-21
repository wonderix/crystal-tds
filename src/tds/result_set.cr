class TDS::ResultSet < DB::ResultSet
  @row : Token::Row? = nil
  @column_index = 0

  def initialize(statement, @iterator : ::Iterator(Token::Token))
    super(statement)
  end

  protected def do_close
    super
  end

  def move_next : Bool
    while true
      token = @iterator.next
      case token
      when Token::Row
        @row = token
        return true
      when ::Iterator::Stop
        return false
      else
      end
    end
  end

  def read
    value = @row.not_nil!.columns[@column_index]
    @column_index += 1
    value
  end

  def read(t : Int32.class) : Int32
    read(Int64).to_i32
  end

  def read(type : Int32?.class) : Int32?
    read(Int64?).try &.to_i32
  end

  def read(t : Float32.class) : Float32
    read(Float64).to_f32
  end

  def read(type : Float32?.class) : Float32?
    read(Float64?).try &.to_f32
  end

  def read(t : Time.class) : Time
    Time.parse read(String), SQLite3::DATE_FORMAT, location: SQLite3::TIME_ZONE
  end

  def read(t : Time?.class) : Time?
    read(String?).try { |v| Time.parse(v, SQLite3::DATE_FORMAT, location: SQLite3::TIME_ZONE) }
  end

  def read(t : Bool.class) : Bool
    read(Int64) != 0
  end

  def read(t : Bool?.class) : Bool?
    read(Int64?).try &.!=(0)
  end

  def column_count : Int32
    @row.not_nil!.columns.size
  end

  def column_name(index) : String
    @row.metadata.columns[index].name
  end
end
