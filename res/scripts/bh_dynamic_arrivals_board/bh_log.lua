local debugMode = true

return {
  logObject = function(name, object)
    if debugMode then
      print("BH -------" .. name .. " START -------")
      debugPrint(object)
      print("BH -------" .. name .. " END -------")
    end
  end,
  logCall = function(name)
    if debugMode then
      print("BH -------" .. name .. " CALLED -------")
    end
  end
}