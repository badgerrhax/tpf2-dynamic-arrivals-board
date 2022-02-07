-- State is pretty much read-only here
local stateManager = require("bh_dynamic_arrivals_board/bh_state_manager")
local construction = require("bh_dynamic_arrivals_board/bh_construction_hooks")
local guiWindows = require("bh_dynamic_arrivals_board/bh_gui_windows")
local spatialUtils = require("bh_dynamic_arrivals_board/bh_spatial_utils")
local utils = require("bh_dynamic_arrivals_board/bh_utils")

local editingSign

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

local function getConfigForEntity(entityId)
  if not utils.validEntity(entityId) then return nil end

  local sign = api.engine.getComponent(entityId, api.type.ComponentType.CONSTRUCTION)
  if not sign then return nil end

  return construction.getRegisteredConstructions()[sign.fileName]
end

local placedConstruction
local function presentConfigGui(entityId, nearbyStations)
  local latestData = { nearbyStations = nearbyStations }

  local callbacks = {
    onRescan = function()
      queueAction(function()
        placedConstruction(entityId, true)
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

  editingSign = entityId
  guiWindows.ConfigureSign(entityId, nearbyStations, callbacks)
end

placedConstruction = function(entityId, forceGui)
  local constructionConfig = getConfigForEntity(entityId) or { singleTerminal = true }
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
    if getConfigForEntity(param) then
      local signData = state.placed_signs[param]
      if signData then
        presentConfigGui(param, signData)
      end
    end
  end

  if name == "builder.apply" then
    if param and param.proposal then
      local toAdd = param.proposal.toAdd
      if toAdd and toAdd[1] and construction.isRegistered(toAdd[1].fileName) then
        if param.result and param.result[1] then
          placedConstruction(param.result[1], false)
        end
      end
      local toRemove = param.proposal.toRemove
      if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
        if editingSign == toRemove[1] then
          guiWindows.hideConfigureSign()
        end
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
