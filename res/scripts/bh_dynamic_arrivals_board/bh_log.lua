local debugMode = true
local timingMode = true

return {
  object = function(name, object)
    if debugMode then
      print("BH ------- " .. name .. " START -------")
      debugPrint(object)
      print("BH ------- " .. name .. " END -------")
    end
  end,
  message = function(msg)
    if debugMode then
      print("BH ------ " .. msg)
    end
  end,
  timed = function(label, func)
    local ret
    if timingMode then
      local start = os.clock()
      ret = {func()}
      local elapsed = math.ceil((os.clock() - start) * 1000)
      print("BH PROFILE ---- " .. tostring(label) .. " executed in " .. elapsed .. "ms")
    else
      ret = {func()}
    end
    return table.unpack(ret)
  end
}