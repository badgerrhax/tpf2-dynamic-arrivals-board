local function getUniqueValidLines(stationGroupId)
  local lineStops = api.engine.system.lineSystem.getLineStops(stationGroupId)
  if not lineStops then return end

  local uniqueLines = {}
  for _, line in pairs(lineStops) do
    local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
    if lineData and #lineData.stops > 1 then -- a line with 1 stop is definitely not valid
      uniqueLines[line] = lineData
    end
  end

  local problemLines = api.engine.system.lineSystem.getProblemLines(api.engine.util.getPlayer())
  for _, problemLine in ipairs(problemLines) do
    uniqueLines[problemLine] = nil -- remove problem lines from calculations
  end

  return uniqueLines
end

local function calculateLineStopTermini(lineData)
  local lineStops = lineData.stops
  local stops = {}
  local visitedStations = {}
  local legStart = 1

  local function setLegTerminus(start, length, terminus)
    for i = start, start + length - 1 do
      stops[i] = terminus
    end
  end

  for stopIndex, stop in ipairs(lineStops) do
    if visitedStations[stop.stationGroup] then
      setLegTerminus(legStart, stopIndex - 2, stopIndex - 1)
      legStart = stopIndex - 1
      visitedStations = {}
    end

    visitedStations[stop.stationGroup] = true
  end

  if legStart == 1 then
    -- route is direct (there are no repeated stops on the way back)
    setLegTerminus(legStart, #lineStops - legStart, #lineStops)
    stops[#lineStops] = 1
  else
    setLegTerminus(legStart, #lineStops - legStart + 1, 1)
  end
  return stops
end

local function calculateTimeUntilStop(vehicle, sectionTimes, stopIdx, stopsAway, nStops, currentTime)
  local idx = (stopIdx - 2) % nStops + 1
  local segTotal = 0
  for _ = 1, stopsAway + 1 do
    local seg = sectionTimes[idx]
    segTotal = segTotal + seg
    idx = (idx - 2) % nStops + 1
  end
  segTotal = segTotal * 1000

  local timeSinceLastDeparture = currentTime - vehicle.lineStopDepartures[idx % nStops + 1]
  return math.ceil(segTotal - timeSinceLastDeparture)
end

local function findTerminalIndices(lineData, stationTerminal)
  local terminalStopIndex = {}
  for stopIdx, stop in ipairs(lineData.stops) do
    if stop.stationGroup == stationTerminal.stationGroup and 
    (stationTerminal.terminal == nil or stationTerminal.terminal == stop.terminal) and
    (stationTerminal.stationIdx == nil or stationTerminal.stationIdx == stop.station) then
      terminalStopIndex[stationTerminal.stationIdx ~= nil and stop.station or stop.terminal] = stopIdx
    end
  end
  return terminalStopIndex
end

local function calculateSectionTimesAndLineDuration(line, nStops)
  local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
  local sectionTimes
  local lineDuration = 0
  local returnSectionTimes

  if vehicles then
    for _, veh in ipairs(vehicles) do
      local vehicle = api.engine.getComponent(veh, api.type.ComponentType.TRANSPORT_VEHICLE)
      if vehicle then
        if not sectionTimes then
          sectionTimes = {}
          for i = 1, #vehicle.sectionTimes do
            sectionTimes[i] = {}
          end
        end

        for i, sectionTime in ipairs(vehicle.sectionTimes) do
          if sectionTime > 0 then
            local si = sectionTimes[i]
            si[#si+1] = sectionTime
          end
        end
      end
    end

    if not sectionTimes then
      return nil, 0 -- there are no vehicles on the line
    end

    returnSectionTimes = {}
    
    -- gather average of each section time across all vehicles on the line to help fill in gaps
    for i, sectionTimeAccum in ipairs(sectionTimes) do
      if #sectionTimeAccum == 0 then
        lineDuration = 0
        break -- early out if we dont have full line duration data. we need to calculate a different (less accurate) way
      end
      local cumulative = 0
      for _, sectionTime in ipairs(sectionTimeAccum) do
        cumulative = cumulative + sectionTime
      end
      cumulative = cumulative / #sectionTimeAccum
      lineDuration = lineDuration + cumulative
      returnSectionTimes[i] = cumulative
    end

    if lineDuration == 0 then
      -- vehicle hasn't run a full route yet, so fall back to less accurate (?) method
      -- calculate line duration by multiplying the number of vehicles by the line frequency.
      -- NOTE this method does not work inside a coroutine! at all!
      local lineEntity = game.interface.getEntity(line)
      lineDuration = (1 / lineEntity.frequency) * #vehicles

      -- and calculate an average section time by dividing by the number of stops
      local averageSectionTime = lineDuration / nStops

      for i = 1, #sectionTimes do
        returnSectionTimes[i] = averageSectionTime
      end
    end
  end

  return returnSectionTimes, lineDuration
end

local function getCallingAtStationGroups(line, afterStop, untilStop)
  if afterStop == untilStop then return {} end
  local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
  local stationGroups = {}
  if lineData then
    local nStops = #lineData.stops
    if afterStop > nStops or untilStop > nStops then return {} end
    local idx = afterStop % nStops + 1
    while idx ~= untilStop do
      stationGroups[#stationGroups+1] = lineData.stops[idx].stationGroup
      idx = idx % nStops + 1
    end
  end
  return stationGroups
end

return {
  getUniqueValidLines = getUniqueValidLines,
  calculateLineStopTermini = calculateLineStopTermini,
  calculateTimeUntilStop = calculateTimeUntilStop,
  findTerminalIndices = findTerminalIndices,
  calculateSectionTimesAndLineDuration = calculateSectionTimesAndLineDuration,
  getCallingAtStationGroups = getCallingAtStationGroups
}