-- State is pretty much read-only here
local stateManager = require("bh_dynamic_arrivals_board/bh_state_manager")
local construction = require("bh_dynamic_arrivals_board/bh_construction_hooks")
local guiWindows = require("bh_dynamic_arrivals_board/bh_gui_windows")
local spatialUtils = require("bh_dynamic_arrivals_board.bh_spatial_utils")

local queuedActions = {}
local function queueAction(func)
  queuedActions[#queuedActions+1] = func
end

local function sendScriptEvent(id, name, param)
  api.cmd.sendCommand(api.cmd.make.sendScriptEvent("bh_gui_engine.lua", id, name, param))
end

local function sendConfigureSign(entityId, signData)
  local params = {
    signEntity = entityId,
    signData = signData
  }
  sendScriptEvent("signConfig", "configure_display_construction", params)
end

local placedConstruction
local function presentConfigGui(entityId, nearbyStations, constructionConfig)
  local latestData = { nearbyStations = nearbyStations }

  local callbacks = {
    onRescan = function()
      queueAction(function()
        placedConstruction(entityId, true, constructionConfig)
      end)
    end,

    stationToggle = function(toggled, stationGroup)
      print("Check " .. tostring(stationGroup) .. " " .. tostring(toggled) .. " for sign " .. tostring(entityId))
      for _, station in ipairs(latestData.nearbyStations) do
        if station.stationGroup == stationGroup then
          station.displaying = toggled
          sendConfigureSign(entityId, latestData.nearbyStations)
          break
        end
      end
    end
  }

  guiWindows.ConfigureSign(entityId, nearbyStations, callbacks)
end

placedConstruction = function(entityId, forceGui, constructionConfig)
  local nearbyStations = spatialUtils.getClosestStationGroupsAndTerminal(entityId, not constructionConfig.singleTerminal)

  if #nearbyStations > 0 then
    nearbyStations[1].displaying = true
  end

  sendConfigureSign(entityId, nearbyStations)

  if #nearbyStations > 1 or forceGui then
    presentConfigGui(entityId, nearbyStations)
  end
end

local function handleEvent(id, name, param)
  if name ~= "builder.apply" and name ~= "select" then
    return
  end

  local state = stateManager.getState()

  if name == "select" then
    sendScriptEvent(id, "select_object", param)

    -- if we select a sign, show a gui to change stuff that can't be done in the construction params
    local sign = api.engine.getComponent(param, api.type.ComponentType.CONSTRUCTION)
    if sign and construction.isRegistered(sign.fileName) then
      local signData = state.placed_signs[param]
      if signData then
        local config = construction.getRegisteredConstructions()[sign.fileName]
        presentConfigGui(param, signData, config)
      end
    end
  end

  if name == "builder.apply" then
    if param and param.proposal then
      local toAdd = param.proposal.toAdd
      if toAdd and toAdd[1] and construction.isRegistered(toAdd[1].fileName) then
        if param.result and param.result[1] then
          local config = construction.getRegisteredConstructions()[toAdd[1].fileName]
          placedConstruction(param.result[1], false, config)
        end
      end
      local toRemove = param.proposal.toRemove
      if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
        sendScriptEvent(id, "remove_display_construction", toRemove[1])
      end
    end
  end
end

local function update()
  if #queuedActions > 0 then
    for _, action in ipairs(queuedActions) do
     action()
    end
    queuedActions = {}
  end
end

return {
  handleEvent = handleEvent,
  update = update,
}
