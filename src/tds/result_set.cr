class TDS::ResultSet < DB::ResultSet
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
      rescue exc : ::Exception
        @done = true
        raise DB::Error.new("#{exc.to_s} in \"#{statement.command}\"")
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
