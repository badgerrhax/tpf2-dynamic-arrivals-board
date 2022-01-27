local debugMode = true

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
}