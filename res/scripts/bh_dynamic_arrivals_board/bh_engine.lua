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

-- first pass at performing arrival calculations separately from sign updates.
-- not final, but a way to get started so that there is cached data available for incremental sign update
local stationTerminalArrivalCache = {}

local function isArrivalCacheEmpty()
  -- only way to check if a dictionary table is empty is to iterate on at least one k/v pair
  for _, __ in pairs(stationTerminalArrivalCache) do
    return false
  end

  return true
end

local function stationTerminalCacheIndex(stationTerminal)
  local terminalInc = 0
  if stationTerminal.terminal ~= nil then
    terminalInc = stationTerminal.terminal + 1
  elseif stationTerminal.stationIdx ~= nil then
    terminalInc = stationTerminal.stationIdx + 1
  end
  -- stationgroup + station + terminal is what makes each stationTerminal object unique
  return stationTerminal.stationGroup * 1000000 + stationTerminal.station * 1000 + terminalInc
end

local function cacheArrivals(signData, time)
  for _, stationTerminal in ipairs(signData) do
    if stationTerminal.displaying then
      local arrivals = {}
      getNextArrivals(stationTerminal, time, arrivals)
      stationTerminalArrivalCache[stationTerminalCacheIndex(stationTerminal)] = arrivals
    end
  end
end

local function coPerformArrivalCalculations(time)
  -- todo could maybe optimise this by gathering unique stationTerminals and caching those
  local state = stateManager.getState()
  for _, signData in pairs(state.placed_signs) do
    cacheArrivals(signData, time)
    time = coroutine.yield()
  end
end

local function gatherNextArrivals(signData, numArrivals)
  local arrivals = {}

  for _, stationTerminal in ipairs(signData) do
    if stationTerminal.displaying then
      local cachedArrivals = stationTerminalArrivalCache[stationTerminalCacheIndex(stationTerminal)]
      if cachedArrivals then
        arrivals = utils.joinTables(arrivals, cachedArrivals)
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

local function getGameSpeed()
  local speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup
  if not speed then
    speed = 1
  end
  return speed
end

-- todo clean up these parameters later
local function prepareUpdatedConstruction(sign, config, param, arrivals, clockString, clock_time)
  local newParams = {}
  local arrivalParamPrefix = param("arrival_")
  for oldKey, oldVal in pairs(sign.params) do
    -- don't copy auto-arrival params as they may have been removed during this update
    if string.sub(oldKey, 1, #arrivalParamPrefix) ~= arrivalParamPrefix then
      newParams[oldKey] = oldVal
    end
  end

  local maxDiff = getGameSpeed() -- use the speed to decide how many seconds difference we allow before updating
  if (sign.params[param("game_time")] or 0) > clock_time - maxDiff then
    -- skip rebuilding this time as the time hasn't changed enough
    return nil
  end

  newParams[param("time_string")] = clockString
  newParams[param("game_time")] = clock_time

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

  local newCon = api.type.SimpleProposal.ConstructionEntity.new()
  newCon.fileName = sign.fileName
  newCon.params = newParams
  newCon.transf = sign.transf
  newCon.playerEntity = api.engine.util.getPlayer()

  return newCon
end

local function coReplaceSigns(time)
  local state = stateManager.getState()
  for signEntity, signData in pairs(state.placed_signs) do
    local sign = api.engine.getComponent(signEntity, api.type.ComponentType.CONSTRUCTION)
    if sign then
      local startTime = os.clock()
      local config = construction.getRegisteredConstructions()[sign.fileName]
      if not config then config = {} end
      if not config.labelParamPrefix then config.labelParamPrefix = "" end
      local function param(name) return config.labelParamPrefix .. name end

      local clock_time = math.floor(time / 1000)
      local clockString = formatClockString(clock_time)

      local arrivals = {}

      if #signData > 0 and config.maxArrivals > 0 then
        local nextArrivals = gatherNextArrivals(signData, config.maxArrivals)
        arrivals = formatArrivals(nextArrivals, time)
      end

      local newCon = prepareUpdatedConstruction(sign, config, param, arrivals, clockString, clock_time)
      -- newCon may be nil if the clock time (seconds) has not changed since the sign was last built.
      if newCon ~= nil then
        local proposal = api.type.SimpleProposal.new()
        proposal.constructionsToAdd[1] = newCon
        proposal.constructionsToRemove = { signEntity }

        -- changing params on a construction doesn't seem to change the entity id which indicates it doesn't completely "replace" it but i don't know how expensive this command actually is...
        api.cmd.sendCommand(api.cmd.make.buildProposal(proposal, api.type.Context:new(), true))
      end

      local elapsedTime = math.ceil((os.clock() - startTime) * 1000)
      -- update time provided by next resume
      time = coroutine.yield(elapsedTime, newCon ~= nil)
    end
  end
end

local function cleanupDeadSigns()
  -- clean up dead signs
  local state = stateManager.getState()
  for signEntity, _ in pairs(state.placed_signs) do
    if not utils.validEntity(signEntity) then
      log.message("Sign " .. signEntity .. " no longer exists. Removing data.")
      state.placed_signs[signEntity] = nil
    end
  end
end

-- populated with running coroutines for sign placement and arrival calcs
local coroutines = {}
-- records average timings of sign updates and how many signs placed in a placementSampleWindow
local metrics = {
  placementTimeSamples = {},
  placementSampleWindow = 10000, --ms
  lastPlacementAverageTime = 0,
  averageProposalDuration = nil,
  signsReplaced = 0
}

local function processCoroutines(time)
  local speed = getGameSpeed()

  if coroutines.arrivalCalcCoroutine == nil or coroutine.status(coroutines.arrivalCalcCoroutine) == "dead" then
    coroutines.arrivalCalcCoroutine = coroutine.create(coPerformArrivalCalculations)
  end

  -- this runs at least once even if game is paused, so in that case populate the whole line cache initially
  -- so our first sign update doesn't fill signs with blank entries
  if isArrivalCacheEmpty() then
    repeat
      local success, err = coroutine.resume(coroutines.arrivalCalcCoroutine, time)
      if not success then
        log.message("arrivalCalcCoroutine failed " .. tostring(err))
      end
    until not success or coroutine.status(coroutines.arrivalCalcCoroutine) == "dead"
  else
    -- do one step of arrival calc updates
    coroutine.resume(coroutines.arrivalCalcCoroutine, time)
  end

  -- time each sign replacement, and for each update replaces as many as can approximately fit in a fixed time budget.
  -- this could be a config value for the mod so the target can be scaled as needed by player (lower at expense of update speed, ofc)
  -- signs are only replaced if the clock is at least one second different, otherwise they are skipped
  local targetSignProposalTimeBudget = 20 / speed -- milliseconds to spend per engine update performing sign replacements, scaled by game speed (faster update = less time budget per update)
  local updateBuildTime = 0
  repeat
    if coroutines.replacementCoroutine == nil or coroutine.status(coroutines.replacementCoroutine) == "dead" then
      coroutines.replacementCoroutine = coroutine.create(coReplaceSigns)
    end

    local success, execTime, placedCon = coroutine.resume(coroutines.replacementCoroutine, time)
    if not success then
      log.message("replacementCoroutine failed " .. tostring(execTime)) --execTime contains err
      break
    elseif execTime ~= nil then
      if placedCon then
        metrics.signsReplaced = metrics.signsReplaced + 1
        metrics.placementTimeSamples[#metrics.placementTimeSamples+1] = execTime
      end

      updateBuildTime = updateBuildTime + execTime

      if metrics.averageProposalDuration == nil then
        metrics.averageProposalDuration = execTime
      end
    else
      break
    end
    -- stop one sign short of exceeding the time budget for this update
  until updateBuildTime + metrics.averageProposalDuration > targetSignProposalTimeBudget

  if time > metrics.lastPlacementAverageTime + metrics.placementSampleWindow then
    metrics.lastPlacementAverageTime = time
    if #metrics.placementTimeSamples > 0 then
      local sum = 0
      for _, sample in ipairs(metrics.placementTimeSamples) do
        sum = sum + sample
      end
      metrics.averageProposalDuration = sum / #metrics.placementTimeSamples
      metrics.placementTimeSamples = {}
      log.message(string.format("Averages -- Single sign update: %.1fms -- Total signs per second: %.1f",
        metrics.averageProposalDuration, (metrics.signsReplaced / ((metrics.placementSampleWindow / 1000) / speed))))
    end
    metrics.signsReplaced = 0
  end
end

local function updateState(time)
  local state = stateManager.getState()
  local clock_time = math.floor(time / 1000)
  if clock_time ~= state.world_time then
    state.world_time = clock_time

    for signEntity, signData in pairs(state.placed_signs) do
      local sign = api.engine.getComponent(signEntity, api.type.ComponentType.CONSTRUCTION)
      if sign then
        local config = construction.getRegisteredConstructions()[sign.fileName]
        if not config then
          config = {}
        end
        if not config.labelParamPrefix then
          config.labelParamPrefix = ""
        end
        local function param(name)
          return config.labelParamPrefix .. name
        end

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
      end
    end
  end
end

local lastTime = 0
local function update()
  local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
  if not time then
    log.message("cannot get time!")
    return
  end

  if time > lastTime then
    lastTime = time

    cleanupDeadSigns()
    processCoroutines(time)

    updateState(time)
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