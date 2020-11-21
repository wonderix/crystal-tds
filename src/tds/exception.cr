class TDS::Exception < ::Exception
  getter dberrstr : String?
  getter oserrstr : String?
  getter dberr : Int32
  getter severity : Int32

  def initialize(severity = 0, dberr = 0, oserr = 0, dberrstr = Pointer(UInt8).null, oserrstr = Pointer(UInt8).null)
    @severity = severity
    @dberr = dberr
    @dberrstr = String.new(dberrstr) unless dberrstr.null?
    @oserrstr = String.new(oserrstr) unless oserrstr.null?
    super(@dberrstr)
  end
end
