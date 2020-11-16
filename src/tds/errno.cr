

require "./byte_format"
require "./packet_io"
require "./pre_login_request"


module Tds
  
  ESEOF = 20017	# Unexpected EOF from SQL Server.
  ESMSG = 20018	# General SQL Server error: Check messages from the SQL Server.
  EICONVI = 2403	# Some character(s) could not be converted into client's character set.  Unconverted bytes were changed to question marks ('?').
  EICONVO = 2402	# Error converting characters into server's character set. Some character(s) could not be converted.
  ETIME = 20003	# SQL Server connection timed out.
  EWRIT = 20006	# Write to SQL Server failed.
  EVERDOWN = 100 # indicating the connection can only be v7.1
  ECONN  = 20009	# Unable to connect socket -- SQL Server is unavailable or does not exist.

end

 