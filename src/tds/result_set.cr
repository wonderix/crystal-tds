class TDS::ResultSet < DB::ResultSet
  DATETIME_FORMAT = Time::Format.new("%Y-%m-%d %H:%M:%S")
  DATE_FORMAT     = Time::Format.new("%Y-%m-%d")
  @row : Token::Row? = nil
  @metadata : Token::MetaData
  @column_index = 0
  @done = false

  def initialize(statement, @iterator : ::Iterator(Token::Token))
    super(statement)
    metadata : Token::MetaData? = nil
    while true
      token = @iterator.next
      case token
      when Token::MetaData
        metadata = token
        break
      else
      end
    end
    @metadata = metadata.not_nil!
  end

  protected def do_close
    super
    @iterator.each { |token| } unless @done
  end

  def move_next : Bool
    @column_index = 0
    while !@done
      token = begin
        @iterator.next
      rescue ex : IO::Error
        @done = true
        raise DB::ConnectionLost.new(statement.connection, ex)
      rescue ex
        @done = true
        raise DB::Error.new("#{ex.to_s} in \"#{statement.command}\"", ex)
      end
      case token
      when Token::Row
        @row = token
        return true
      when ::Iterator::Stop
        @done = true
        return false
      else
      end
    end
    return false
  end

  def read
    value = @row.not_nil!.columns[@column_index]
    @column_index += 1
    value
  end

  def next_column_index : Int32
    @column_index
  end

  def read(t : Int64.class) : Int64
    case v = read
    when Number
      v.to_i64
    else
      raise "read returned a #{v}. A Number was expected"
    end
  end

  def read(t : Float64.class) : Float64
    case v = read
    when Float64, BigDecimal
      v.to_f64
    else
      raise "read returned a #{v.class}. A Float64|BigDecimal was expected"
    end
  end

  def read(t : Float64?.class) : Float64?
    case v = read
    when Float64, BigDecimal
      v.to_f64
    when Nil
      v
    else
      raise "read returned a #{v.inspect}. A Float64|BigDecimal|Nil was expected"
    end
  end

  def read(t : Float32.class) : Float32
    case v = read
    when Float64, BigDecimal
      v.to_f32
    when Float32
      v
    else
      raise "read returned a #{v.class}. A Float64|Float32|BigDecimal was expected"
    end
  end

  def read(t : Float32?.class) : Float32?
    case v = read
    when Float64, BigDecimal
      v.to_f32
    when Float32, Nil
      v
    else
      raise "read returned a #{v.inspect}. A Float64|Float32|BigDecimal|Nil was expected"
    end
  end

  def read(t : Time.class) : Time
    case v = read
    when Time
      v
    when String
      v.size == 10 ? DATE_FORMAT.parse(v, Time::Location::UTC) : DATETIME_FORMAT.parse(v, Time::Location::UTC)
    else
      raise "read returned a #{v.class}. A Time|String was expected"
    end
  end

  def read(t : Time?.class) : Time?
    case v = read
    when Time, Nil
      v
    when String
      v.size == 10 ? DATE_FORMAT.parse(v, Time::Location::UTC) : DATETIME_FORMAT.parse(v, Time::Location::UTC)
    else
      raise "read returned a #{v.inspect}. A Time|String|Nil was expected"
    end
  end

  def read(t : Bool.class) : Bool
    read(UInt8) != 0
  end

  def read(t : Bool?.class) : Bool?
    read(UInt8?).try &.!=(0)
  end

  def column_count : Int32
    @metadata.columns.size
  end

  def column_name(index) : String
    @metadata.columns[index].name
  end
end
