module COMMON

def self.usage_percent(used, total, _round=nil)
  # Calculate percentage usage of 'used' against 'total'.
  begin
      ret = (used / total.to_f) * 100
  rescue ZeroDivisionError
      ret = 0
  end
  if _round
      return ret.round(_round)
  else
      return ret
  end
end
  
end
