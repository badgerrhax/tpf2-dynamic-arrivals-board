local vec3 = require "vec3"

local bhm = require "bh_dynamic_arrivals_board/bh_maths"
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

local function getClosestTerminal(transform)
  --print("getClosestTerminal")
  local componentType = api.type.ComponentType.STATION
  local position = bhm.transformVec(vec3.new(0, 0, 0), transform)
  local radius = 10
  --debugPrint({ position = position })

  local box = api.type.Box3.new(
    api.type.Vec3f.new(position.x - radius, position.y - radius, -9999),
    api.type.Vec3f.new(position.x + radius, position.y + radius, 9999)
  )
  local results = {}
  api.engine.system.octreeSystem.findIntersectingEntities(box, function(entity, boundingVolume)
    if entity and api.engine.getComponent(entity, componentType) then
      results[#results+1] = entity
    end
  end)

  --debugPrint(results)
  --return results

  local shortestDistance = 9999
  local closestEntity
  local closestTerminal
  local closestStationGroup

  for _, entity in ipairs(results) do
    local station = api.engine.getComponent(entity, componentType)
      if station then
        local stationGroup = api.engine.system.stationGroupSystem.getStationGroup(entity)
        local name = api.engine.getComponent(stationGroup, api.type.ComponentType.NAME)
        debugPrint(name)
        --debugPrint(station)
        --print("-- end of station data --")

        for k, v in pairs(station.terminals) do
          --print(v.vehicleNodeId.entity)
          local nodeData = api.engine.getComponent(v.vehicleNodeId.entity, api.type.ComponentType.BASE_NODE)
          --debugPrint(nodeData)

          if nodeData then
            local distance = vec3.distance(position, nodeData.position)
            if distance < shortestDistance then
              shortestDistance = distance
              closestEntity = entity
              closestTerminal = k - 1
              closestStationGroup = stationGroup
            end
            print("Terminal " .. tostring(k) .. " is " .. tostring(distance) .. "m away")
          end
        end
    end
  end

  if closestEntity then
    return { station = closestEntity, stationGroup = closestStationGroup, terminal = closestTerminal }
  else
    return nil
  end
end

local function calculateLineStopTermini(line)
  local lineStops = line.stops
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

--[[ 
  returns an array of tables that look like this:
  {
    terminalId = n,
    destination = stationGroup,
    arrivalTime = milliseconds,
    stopsAway = n
  }
  sorted in order of arrivalTime (earliest first)
]]
local function getNextArrivals(stationTerminal, numArrivals)
  -- despite how many we want to return, we actually need to look at every vehicle on every line stopping here before we can sort and trim
  local arrivals = {}

  if not stationTerminal then return arrivals end

  local lineStops
  if stationTerminal.terminal ~= nil then
    lineStops = api.engine.system.lineSystem.getLineStopsForTerminal(stationTerminal.station, stationTerminal.terminal)
  else
    lineStops = api.engine.system.lineSystem.getLineStopsForStation(stationTerminal.station)
  end
  
  if lineStops then
    local uniqueLines = {}
    for _, line in pairs(lineStops) do
      uniqueLines[line] = line
    end
    
    for _, line in pairs(uniqueLines) do
      --print("line " .. line)
      local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
      if lineData then
        local lineTermini = calculateLineStopTermini(lineData) -- this will eventually be done in a slower engine loop to save performance
        local terminalStopIndex = {}
        
        for stopIdx, stop in ipairs(lineData.stops) do
          if stop.stationGroup == stationTerminal.stationGroup and (stationTerminal.terminal == nil or stationTerminal.terminal == stop.terminal) then
            terminalStopIndex[stop.terminal] = stopIdx
          end
        end

        local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
        if vehicles then
          for _, veh in ipairs(vehicles) do
            local vehicle = api.engine.getComponent(veh, api.type.ComponentType.TRANSPORT_VEHICLE)
            if vehicle then
              local lineDuration = 0
              --debugPrint({ vehicleId = veh, times = vehicle.sectionTimes, deps = vehicle.lineStopDepartures })
              for _, sectionTime in ipairs(vehicle.sectionTimes) do
                lineDuration = lineDuration + sectionTime
              end
              for terminalIdx, stopIdx in pairs(terminalStopIndex) do
                local stopsAway = (stopIdx - vehicle.stopIndex - 1) % #lineData.stops
                local expectedArrivalTime = vehicle.lineStopDepartures[stopIdx] + math.ceil(lineDuration) * 1000

                arrivals[#arrivals+1] = {
                  terminalId = terminalIdx,
                  destination = lineData.stops[lineTermini[stopIdx]].stationGroup,
                  arrivalTime = expectedArrivalTime,
                  stopsAway = stopsAway
                }

                if #vehicles == 1 and lineDuration > 0 then
                  -- if there's only one vehicle, make a second arrival eta + an entire line duration
                  arrivals[#arrivals+1] = {
                    terminalId = terminalIdx,
                    destination = lineData.stops[lineTermini[stopIdx]].stationGroup,
                    arrivalTime = math.ceil(expectedArrivalTime + lineDuration * 1000),
                    stopsAway = stopsAway
                  }
                end
              end
            end
          end
        end
      end
    end
  end

  table.sort(arrivals, function(a, b) return a.arrivalTime < b.arrivalTime end)

  local ret = {}
  
  for i = 1, numArrivals do
    ret[#ret+1] = arrivals[i]
  end

  return ret
end

local function formatClockString(clock_time)
  return string.format("%02d:%02d:%02d", (clock_time / 60 / 60) % 24, (clock_time / 60) % 60, clock_time % 60)
end

local function formatArrivals(arrivals, time)
  local ret = {}

  if arrivals then
    for i, arrival in ipairs(arrivals) do
      local entry = { dest = "", etaMinsString = "", arrivalTimeString = "" }
      local terminusName = api.engine.getComponent(arrival.destination, api.type.ComponentType.NAME)
      if terminusName then
        entry.dest = terminusName.name
      end

      entry.arrivalTimeString = formatClockString(time / 1000)
      local expectedSecondsFromNow = math.ceil((arrival.arrivalTime - time) / 1000)
      local expectedMins = math.ceil(expectedSecondsFromNow / 60)
      if expectedMins > 0 then
        entry.etaMinsString = expectedMins .. "min"
      end

      ret[#ret+1] = entry
    end
  end
  while #ret < 2 do
    ret[#ret+1] = { dest = "", eta = 0 }
  end

  return ret
end

local function update()
  local state = stateManager.loadState()
  local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
  if time then
      local clock_time = math.floor(time / 1000)
      if clock_time ~= state.world_time then
        state.world_time = clock_time
        local clockString = formatClockString(clock_time)
        print(clockString)
        debugPrint({ engineConstructions = construction.getRegisteredConstructions() })

        -- some optimisation ideas noting here while i think of them.
        -- * add debugging info to count how many times various loops are entered per update so i know how much is too much
        -- * build the proposal of multiple construction updates and send a single command after the loop
        -- * gather placed_signs into a map by station entity, so multiple signs at the same station can do a single station eta update and pass out the info to each sign as needed
        -- prevent multiple requests for the same data in this single update.
        -- we do need to request these per update tho because the player might edit the lines / add / remove vehicles

        for k, v in pairs(state.placed_signs) do
          local sign = api.engine.getComponent(k, api.type.ComponentType.CONSTRUCTION)
          if sign then
            if not v.linked then
              local stationTerminal = getClosestTerminal(sign.transf)
              if stationTerminal then
                debugPrint({ ClosestTerminal = stationTerminal })
                v.stationTerminal = stationTerminal
              else
                print("Sign placed too far from a station - will only display the clock.")
              end

              v.linked = true
            end
            
            local arrivals

            if v.stationTerminal then
              -- i could do this getNextArrivals logic less frequently too, as the only thing that uses the current time is the formatting below
              local nextArrivals = getNextArrivals(v.stationTerminal, 2)
              arrivals = formatArrivals(nextArrivals, time)

              if not nextArrivals or #nextArrivals == 0 then
                print("No arrivals for this terminal - will only display the clock")
              end
            end

            local newCon = api.type.SimpleProposal.ConstructionEntity.new()

            --debugPrint(sign)

            local newParams = {}
            for oldKey, oldVal in pairs(sign.params) do
              newParams[oldKey] = oldVal
            end

            newParams.bh_digital_display_time_string = clockString

            newParams.bh_digital_display_line1_dest = arrivals[1].dest
            newParams.bh_digital_display_line1_time = arrivals[1].etaMinsString
            newParams.bh_digital_display_line2_dest = arrivals[2].dest
            newParams.bh_digital_display_line2_time = arrivals[2].etaMinsString

            newParams.seed = sign.params.seed + 1

            newCon.fileName = sign.fileName
            newCon.params = newParams
            newCon.transf = sign.transf
            newCon.playerEntity = api.engine.util.getPlayer()

            --debugPrint(newCon)
            
            local proposal = api.type.SimpleProposal.new()
            proposal.constructionsToAdd[1] = newCon
            proposal.constructionsToRemove = { k }

            -- changing params on a construction doesn't seem to change the entity id which indicates it doesn't completely "replace" it but i don't know how expensive this command actually is...
            api.cmd.sendCommand(api.cmd.make.buildProposal(proposal, api.type.Context:new(), true))
          end
        end
      end
  else
      print("cannot get time!")
  end
end

local function handleEvent(src, id, name, param)
  if name == "add_display_construction" then
    local state = stateManager.getState()
    state.placed_signs[param] = {}
    print("Player created sign ID " .. tostring(param) .. ". Now managing the following signs:")
    debugPrint(state.placed_signs)
  elseif name == "remove_display_construction" then
    local state = stateManager.getState()
    state.placed_signs[param] = nil
    print("Player removed sign ID " .. tostring(param) .. ". Now managing the following signs:")
    debugPrint(state.placed_signs)
  end
end

return {
  update = update,
  handleEvent = handleEvent
}