module TDS
  ESEOF     =  20017 # Unexpected EOF from SQL Server.
  ESMSG     =  20018 # General SQL Server error: Check messages from the SQL Server.
  EICONVI   =   2403 # Some character(s) could not be converted into client's character set.  Unconverted bytes were changed to question marks ('?').
  EICONVO   =   2402 # Error converting characters into server's character set. Some character(s) could not be converted.
  ETIME     =  20003 # SQL Server connection timed out.
  EWRIT     =  20006 # Write to SQL Server failed.
  EVERDOWN  =    100 # indicating the connection can only be v7.1
  ECONN     =  20009 # Unable to connect socket -- SQL Server is unavailable or does not exist.
  EPERM     = 0x4818
  EROLLBACK =   3903 # The ROLLBACK TRANSACTION request has no corresponding BEGIN TRANSACTION

  class ProtocolError < DB::Error
    def initialize(msg = "")
      super(msg)
    end
  end

  class ServerError < DB::Error
    getter number : Int32

    def initialize(@number, message)
      super("Error #{@number}: #{message}")
    end
  end

  class StatementError < DB::Error
    getter statement : String

    def initialize(cause, @statement)
      super("#{cause.to_s} in \"#{@statement}\"", cause: cause)
    end
  end

  class NotImplemented < DB::Error
    def initialize(msg = "")
      super(msg)
    end
  end

  class SyntaxError < DB::Error
  end
end
