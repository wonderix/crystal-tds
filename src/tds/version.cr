enum TDS::Version
  V4_2 = 1
  V5_0 = 2
  V7_0 = 3
  V7_1 = 4
  V8_1 = 5
  V9_0 = 6

  def as_uint32 : UInt32
    case self
    when V9_0
      return 0x74000004_u32
    when V7_1
      return 0x71000001_u32
    else
      raise "Unsupported version"
    end
  end
end
