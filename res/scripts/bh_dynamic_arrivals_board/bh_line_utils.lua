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

local function calculateTimeUntilStop(vehicle, stopIdx, stopsAway, nStops, averageSectionTime, currentTime)
  local idx = (stopIdx - 2) % nStops + 1
  local segTotal = 0
  for _ = 1, stopsAway + 1 do
    local seg = vehicle.sectionTimes[idx]
    segTotal = segTotal + (seg or averageSectionTime)
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

return {
  calculateLineStopTermini = calculateLineStopTermini,
  calculateTimeUntilStop = calculateTimeUntilStop,
  findTerminalIndices = findTerminalIndices
}