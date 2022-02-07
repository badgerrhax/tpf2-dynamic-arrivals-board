local lineUtils = require "bh_dynamic_arrivals_board/bh_line_utils"

local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"
local spatialUtils = require "bh_dynamic_arrivals_board/bh_spatial_utils"
local log = require "bh_dynamic_arrivals_board/bh_log"
local utils = require "bh_dynamic_arrivals_board/bh_utils"

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
local function getNextArrivals(stationTerminal, time, arrivals) -- output to arrivals
  -- despite how many we want to return, we actually need to look at every vehicle on every line stopping here before we can sort and trim
  if not stationTerminal then return end

  local lineStops = api.engine.system.lineSystem.getLineStops(stationTerminal.stationGroup)
  if not lineStops then return end

  local uniqueLines = {}
  for _, line in pairs(lineStops) do
    uniqueLines[line] = line
  end

  for _, line in pairs(uniqueLines) do
    local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
    if lineData then
      local lineTermini = lineUtils.calculateLineStopTermini(lineData) -- this will eventually be done in a slower engine loop to save performance
      local terminalStopIndex = lineUtils.findTerminalIndices(lineData, stationTerminal)
      local nStops = #lineData.stops

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

              local timeUntilArrival = lineUtils.calculateTimeUntilStop(vehicle, stopIdx, stopsAway, nStops, averageSectionTime, time)
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

local function gatherNextArrivals(signData, numArrivals, time)
  local arrivals = {}

  for _, stationTerminal in ipairs(signData) do
    if stationTerminal.displaying then
      getNextArrivals(stationTerminal, time, arrivals)
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
    for _, arrival in ipairs(arrivals) do
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

  return ret
end

local function refreshAndResyncStations(entityId, oldData)
  local newData = spatialUtils.getClosestStationGroupsAndTerminal(entityId, false)
  local displayMap = {}
  for _, oldST in ipairs(oldData) do
    displayMap[oldST.stationGroup] = oldST.displaying
  end
  for _, newST in ipairs(newData) do
    newST.displaying = displayMap[newST.stationGroup]
  end
  return newData
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
          for signEntity, _ in pairs(state.placed_signs) do
            if not utils.validEntity(signEntity) then
              log.message("Sign " .. signEntity .. " no longer exists. Removing data.")
              state.placed_signs[signEntity] = nil
            end
          end

          for signEntity, signData in pairs(state.placed_signs) do
            local sign = api.engine.getComponent(signEntity, api.type.ComponentType.CONSTRUCTION)
            if sign then
              local config = construction.getRegisteredConstructions()[sign.fileName]
              if not config then config = {} end
              if not config.labelParamPrefix then config.labelParamPrefix = "" end
              local function param(name) return config.labelParamPrefix .. name end

              -- TODO: i don't like this the way it is.
              -- update the linked terminal as it might have been changed by the player in the construction params
              local terminalOverride = sign.params[param("terminal_override")] or 0
              if #signData > 0 then
                if signData[1].auto == false and terminalOverride == 0 then
                  -- player may have changed the construction from a specific terminal to auto, so we need to recalculate the closest one
                  signData = refreshAndResyncStations(signEntity, signData)
                  state.placed_signs[signEntity] = signData
                elseif terminalOverride > 0 then
                  for _, stationTerminal in ipairs(signData) do
                    stationTerminal.terminal = terminalOverride - 1
                    stationTerminal.auto = false
                  end
                end
              end

              local arrivals = {}

              if #signData > 0 and config.maxArrivals > 0 then
                local nextArrivals = gatherNextArrivals(signData, config.maxArrivals, time)

                if selectedObject == signEntity then
                  log.object("Time", time)
                  log.object("signData", signData)
                  log.object("nextArrivals", nextArrivals)
                end

                arrivals = formatArrivals(nextArrivals, time)
              end

              local newCon = api.type.SimpleProposal.ConstructionEntity.new()

              local newParams = {}
              local arrivalParamPrefix = param("arrival_")
              for oldKey, oldVal in pairs(sign.params) do
                -- don't copy auto-arrival params as they may have been removed during this update
                if string.sub(oldKey, 1, #arrivalParamPrefix) ~= arrivalParamPrefix then
                  newParams[oldKey] = oldVal
                end
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
              oldConstructions[#oldConstructions+1] = signEntity
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
    if name == "remove_display_construction" then
      local state = stateManager.getState()
      state.placed_signs[param] = nil
      log.message("Removed display construction id " .. tostring(param))
    elseif name == "select_object" then
      debugPrint({ selectedObject = param })
      selectedObject = param
    elseif name == "configure_display_construction" then
      debugPrint({ configure_display_construction = param })
      local state = stateManager.getState()
      state.placed_signs[param.signEntity] = param.signData
    end
  end
end

return {
  update = update,
  handleEvent = handleEvent
}