local vec3 = require "vec3"
local transf = require "transf"

local bhm = require "bh_dynamic_arrivals_board/bh_maths"
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

local log = require "bh_dynamic_arrivals_board/bh_log"

local function validEntity(id)
  return type(id) == "number" and id > 0 and api.engine.entityExists(id)
end

local function getClosestTerminal(transform)
  local position = bhm.transformVec(vec3.new(0, 0, 0), transform)
  local radius = 50

  local box = api.type.Box3.new(
    api.type.Vec3f.new(position.x - radius, position.y - radius, position.z - 10),
    api.type.Vec3f.new(position.x + radius, position.y + radius, position.z + 10)
  )

  local stations = {}

  api.engine.system.octreeSystem.findIntersectingEntities(box, function(entity, boundingVolume)
    xpcall(function()
      if entity and api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE_TRACK) then
        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(entity)
        if validEntity(conId) then
          local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
          if con then
            for _, id in pairs(con.stations) do
              stations[id] = true
            end
          end
        end
      end

    end, function(err) print(err) end)
  end)

  debugPrint(stations)

  local shortestDistance = 9999
  local closestEntity
  local closestTerminal
  local closestStationGroup

  local tpData = {}
  local function getTpnEdges(entity)
    local tpn = tpData[entity]
    if not tpn then
      local network = api.engine.getComponent(entity, api.type.ComponentType.TRANSPORT_NETWORK)
      if network then
        tpn = network.edges
      else
        tpn = {}
      end
      tpData[entity] = tpn
    end
    return tpn
  end

  for entity, _ in pairs(stations) do
    local station = api.engine.getComponent(entity, api.type.ComponentType.STATION)
    if station then
      local stationGroup = api.engine.system.stationGroupSystem.getStationGroup(entity)
      for k, v in pairs(station.terminals) do
        -- this is an improvement over vehicle nodes as the terminal detection further away from the station is better.
        -- but there are still sections of platforms where it misses / gets the wrong info for some reason, and near an entrance it always seems to prefer 2nd platform
        -- i guess because some edges cross the terminal and i happen to pick the node on the far end as the position test?
        -- not sure how to solve that other than to find the longest edges and take their tangents as the direction of the platform..
        for _, p in ipairs(v.personEdges) do
          local tpn = getTpnEdges(p.entity)
          if tpn then
            local edge = tpn[p.index]
            if edge and edge.geometry and edge.geometry.params and edge.geometry.params.pos and edge.geometry.height then
              local edgePos = vec3.new(edge.geometry.params.pos.x, edge.geometry.params.pos.y, edge.geometry.height.x)
              local distance = vec3.distance(position, edgePos)
              if distance < shortestDistance then
                shortestDistance = distance
                closestEntity = entity
                closestTerminal = k - 1
                closestStationGroup = stationGroup
              end
            end
          end
        end

        --[[local nodeData = api.engine.getComponent(v.vehicleNodeId.entity, api.type.ComponentType.BASE_NODE)

        -- try getting a node from the edge if there is one
        if not nodeData then
          local edge = api.engine.getComponent(v.vehicleNodeId.entity, api.type.ComponentType.BASE_EDGE)
          --log.object("edge", edge)
          if edge then
            nodeData = api.engine.getComponent(edge.node0, api.type.ComponentType.BASE_NODE)
          end
        end

        -- if we couldn't get this node, need to fall back to station only...
        if not nodeData then
          local s2c = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
          local conId = s2c[entity]
          if conId then
            local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con then
              local distance = vec3.distance(position, vec3.new(con.transf[13], con.transf[14], con.transf[15]))
              if distance < shortestDistance then
                shortestDistance = distance
                closestEntity = entity
                closestTerminal = 1
                closestStationGroup = stationGroup
              end
              log.message("Station " .. tostring(entity) .. " is " .. tostring(distance) .. "m away")
              break
            end
          end
        end

        if nodeData then
          local distance = vec3.distance(position, nodeData.position)
          if distance < shortestDistance then
            shortestDistance = distance
            closestEntity = entity
            closestTerminal = k - 1
            closestStationGroup = stationGroup
          end
          log.message("Terminal " .. tostring(k) .. " is " .. tostring(distance) .. "m away")
        end]]
      end
    end
  end

  if closestEntity then
    log.message("Part of transport network on terminal " .. closestTerminal .. " is closest to sign (" .. tostring(shortestDistance) .. "m)")
    return { station = closestEntity, stationGroup = closestStationGroup, terminal = closestTerminal, auto = true }
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

local selectedObject

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
local function getNextArrivals(stationTerminal, numArrivals, time)
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
      local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
      if lineData then
        local lineTermini = calculateLineStopTermini(lineData) -- this will eventually be done in a slower engine loop to save performance
        local terminalStopIndex = {}
        local nStops = #lineData.stops
        
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
              for _, sectionTime in ipairs(vehicle.sectionTimes) do
                lineDuration = lineDuration + sectionTime
                if sectionTime == 0 then
                  lineDuration = 0
                  break -- early out if we dont have full line duration data. we need to calculate a different (less accurate) way
                end
              end

              --[[if selectedObject == veh then
                debugPrint({ terminals = terminalStopIndex, sectionTimes = vehicle.sectionTimes, stopDepartures = vehicle.lineStopDepartures })
              end]]

              local function blah(str, val)
                if selectedObject == veh then
                  print(str .. " = " .. val)
                end
              end

              if lineDuration == 0 then
                -- vehicle hasn't run a full route yet, so fall back to less accurate (?) method
                -- calculate line duration by multiplying the number of vehicles by the line frequency
                local lineEntity = game.interface.getEntity(line)
                lineDuration = (1 / lineEntity.frequency) * #vehicles
              end

              -- and calculate an average section time by dividing by the number of stops
              local averageSectionTime = lineDuration / nStops

              --log.object("vehicle_" .. veh, vehicle)
              for terminalIdx, stopIdx in pairs(terminalStopIndex) do
                local stopsAway = (stopIdx - vehicle.stopIndex - 1) % nStops

                -- using lineStopDepartures[stopIdx] + lineDuration seems simple but requires at least one full loop and still isn't always correct if there's bunching.
                -- so instead, using stopsAway, add up the sectionTimes of the stops between there and here, and subtract the diff of now - stopsAway departure time.
                -- lastLineStopDeparture seems to be inaccurate.
                --local expectedArrivalTime = vehicle.lineStopDepartures[stopIdx] + math.ceil(lineDuration) * 1000

                local timeUntilArrival = calculateTimeUntilStop(vehicle, stopIdx, stopsAway, nStops, averageSectionTime, time)
                blah("[Stop " .. stopIdx .. "]: timeUntilArrival", timeUntilArrival)
                local expectedArrivalTime = time + timeUntilArrival

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

local function formatClockStringHHMM(clock_time)
  return string.format("%02d:%02d", (clock_time / 60 / 60) % 24, (clock_time / 60) % 60)
end

local function formatArrivals(arrivals, time)
  local ret = {}

  if arrivals then
    for i, arrival in ipairs(arrivals) do
      local entry = { dest = "", etaMinsString = "", arrivalTimeString = "", arrivalTerminal = arrival.terminalId }
      local terminusName = api.engine.getComponent(arrival.destination, api.type.ComponentType.NAME)
      if terminusName then
        entry.dest = terminusName.name
      end

      entry.arrivalTimeString = formatClockStringHHMM(arrival.arrivalTime / 1000)
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

local function configureSignLink(sign, state, config)
  local xform = sign.transf

  local stationTerminal = getClosestTerminal(xform)

  if stationTerminal then
    log.object("Closest Terminal", { ClosestTerminal = stationTerminal })
    if not config.singleTerminal then
      stationTerminal.terminal = nil
    end
    state.stationTerminal = stationTerminal
  end

  state.linked = true
end

local function update()
  local state = stateManager.loadState()
  local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
  local speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup
  -- TODO actually use this to avoid faster speeds updating faster.. it's not necessary...
  if not speed then
    speed = 1
  end

  if time then
      local clock_time = math.floor(time / 1000)
      if clock_time ~= state.world_time then
        state.world_time = clock_time

        -- performance profiling
        local startTick = os.clock()

        local clockString = formatClockString(clock_time)

        -- some optimisation ideas noting here while i think of them.
        -- * (maybe not needed after below) build the proposal of multiple construction updates and send a single command after the loop.
        --    (is this even a bottleneck? - not per call - batching all constructions into single proposal takes about as long as each individual build command.
        --     so it may be more beneficial to make smaller batches and apply over a few updates to avoid a risk of stuttering)
        -- * move station / line info gathering into less frequent coroutine
        -- prevent multiple requests for the same data in this single update. (how slow are engine api calls? )
        -- we do need to request these per update tho because the player might edit the lines / add / remove vehicles
        -- do a pass over signs and sort into ones with and without a clock, and update the non-clock ones less frequently

        local newConstructions = {}
        local oldConstructions = {}

        log.timed("sign processing", function()
          for k, v in pairs(state.placed_signs) do
            local sign = api.engine.getComponent(k, api.type.ComponentType.CONSTRUCTION)
            if sign then
              local config = construction.getRegisteredConstructions()[sign.fileName]
              if not config then config = {} end
              if not config.labelParamPrefix then config.labelParamPrefix = "" end
              local function param(name) return config.labelParamPrefix .. name end

              -- update the linked terminal as it might have been changed by the player in the construction params
              local terminalOverride = sign.params[param("terminal_override")] or 0
              if v.stationTerminal and not v.stationTerminal.auto and terminalOverride == 0 then
                -- player may have changed the construction from a specific terminal to auto, so we need to recalculate the closest one
                v.linked = false
              end

              if not v.linked then
                configureSignLink(sign, v, config)
              end

              if v.stationTerminal and terminalOverride > 0 then
                v.stationTerminal.terminal = terminalOverride - 1
                v.stationTerminal.auto = false
              end

              local arrivals = {}

              if v.stationTerminal and config.maxArrivals > 0 then
                local nextArrivals = getNextArrivals(v.stationTerminal, config.maxArrivals, time)

                if selectedObject == k then
                  log.object("Time", time)
                  log.object("stationTerminal", v.stationTerminal)
                  log.object("nextArrivals", nextArrivals)
                end

                arrivals = formatArrivals(nextArrivals, time)
              end

              local newCon = api.type.SimpleProposal.ConstructionEntity.new()

              local newParams = {}
              for oldKey, oldVal in pairs(sign.params) do
                newParams[oldKey] = oldVal
              end

              if config.clock then
                newParams[param("time_string")] = clockString
                newParams[param("game_time")] = clock_time
              end

              newParams[param("num_arrivals")] = #arrivals

              for i, a in ipairs(arrivals) do
                local paramName = ""
                
                paramName = paramName .. "arrival_" .. i .. "_"
                newParams[param(paramName .. "dest")] = a.dest
                newParams[param(paramName .. "time")] = config.absoluteArrivalTime and a.arrivalTimeString or a.etaMinsString
                if not config.singleTerminal and a.arrivalTerminal then
                  newParams[param(paramName .. "terminal")] = a.arrivalTerminal + 1
                end
              end

              newParams.seed = sign.params.seed + 1

              newCon.fileName = sign.fileName
              newCon.params = newParams
              newCon.transf = sign.transf
              newCon.playerEntity = api.engine.util.getPlayer()

              newConstructions[#newConstructions+1] = newCon
              oldConstructions[#oldConstructions+1] = k
            end
          end
        end)

        if #newConstructions then
          local proposal = api.type.SimpleProposal.new()
          for i = 1, #newConstructions do
            proposal.constructionsToAdd[i] = newConstructions[i]
          end
          proposal.constructionsToRemove = oldConstructions

          log.timed("buildProposal command", function()
            -- changing params on a construction doesn't seem to change the entity id which indicates it doesn't completely "replace" it but i don't know how expensive this command actually is...
            api.cmd.sendCommand(api.cmd.make.buildProposal(proposal, api.type.Context:new(), true))
          end)
        end

        local executionTime = math.ceil((os.clock() - startTick) * 1000)
        print("Full update took " .. executionTime .. "ms")
      end
  else
      log.message("cannot get time!")
  end
end

local function handleEvent(src, id, name, param)
  if src == "bh_gui_engine.lua" then
    if name == "add_display_construction" then
      local state = stateManager.getState()
      state.placed_signs[param] = {}
      log.message("Added display construction id " .. tostring(param))
    elseif name == "remove_display_construction" then
      local state = stateManager.getState()
      state.placed_signs[param] = nil
      log.message("Removed display construction id " .. tostring(param))
    elseif name == "select_object" then
      selectedObject = param
    end
  end
end

return {
  update = update,
  handleEvent = handleEvent
}