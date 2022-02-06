local vec3 = require("vec3")
local utils = require("bh_dynamic_arrivals_board/bh_utils")
local maths = require("bh_dynamic_arrivals_board/bh_maths")
local log = require("bh_dynamic_arrivals_board/bh_log")
local tpnetUtils = require("bh_dynamic_arrivals_board/bh_tpnet_utils")

local function getClosestTerminalData(stationId, toPosition)
  local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
  if not station then
    return nil
  end

  local terminalData = {
    station = stationId,
    distance = 9999,
  }

  for terminalIdx, terminal in pairs(station.terminals) do
    for _, personEdge in ipairs(terminal.personEdges) do
      local distance = tpnetUtils.distanceFromEdge(toPosition, personEdge)
      if distance and distance < terminalData.distance then
        terminalData.distance = distance
        terminalData.terminal = terminalIdx - 1
      end
    end

    if #terminal.personEdges == 0 then -- bus stops don't have personEdges so use the vehicle node
      local distance = tpnetUtils.distanceFromNode(toPosition, terminal.vehicleNodeId)
      if distance and distance < terminalData.distance then
        terminalData.distance = distance
        terminalData.terminal = terminalIdx - 1
      end
    end
  end

  return terminalData
end

local function getNearbyStationGroups(position)
  local radius = 50
  local height = 10

  local box = api.type.Box3.new(
    api.type.Vec3f.new(position.x - radius, position.y - radius, position.z - height),
    api.type.Vec3f.new(position.x + radius, position.y + radius, position.z + height)
  )

  local stationGroups = {}

  local gatherStations = utils.safeCall(function(entity)
    if not entity then
      return
    end

    if api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE_TRACK) then
      local ownerConstructionId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(entity)
      if not utils.validEntity(ownerConstructionId) then
        return
      end

      local ownerConstruction = api.engine.getComponent(ownerConstructionId, api.type.ComponentType.CONSTRUCTION)
      if not ownerConstruction or not ownerConstruction.stations then
        return
      end

      for _, stationId in pairs(ownerConstruction.stations) do
        local stationGroup = api.engine.system.stationGroupSystem.getStationGroup(stationId)
        if stationGroup then
          stationGroups[stationGroup] = true
        end
      end
    elseif api.engine.getComponent(entity, api.type.ComponentType.STATION) then
      -- fall back for non-rail stations - i.e. bus stops.
      local stationGroup = api.engine.system.stationGroupSystem.getStationGroup(entity)
      stationGroups[stationGroup] = true
    end
  end)

  api.engine.system.octreeSystem.findIntersectingEntities(box, gatherStations)

  return stationGroups
end

local function getClosestStationGroupsAndTerminal(constructionId, stripTerminalInfo)
  return log.timed("getClosestStationGroupsAndTerminal", function()
    local construction = api.engine.getComponent(constructionId, api.type.ComponentType.CONSTRUCTION)
    if not construction then
      return
    end

    local position = maths.transformVec(vec3.new(0, 0, 0), construction.transf)
    local stationGroups = getNearbyStationGroups(position)

    local nearbyStationGroupData = {}

    for stationGroupId, _ in pairs(stationGroups) do
      local stationGroupComponent = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
      if stationGroupComponent then
        local stationGroupData

        if #stationGroupComponent.stations > 1 then
          -- this is likely a bus stop or something where each "station" has one terminal and the game uses the station group for multiple terminals.
          -- for this case we need to do the distance calc for each station but only insert one nearbyStationData entry.
          -- lines stopping at these types of stops use a station field instead of a terminal field to identify terminal.
          for stationIdx, stationId in ipairs(stationGroupComponent.stations) do
            local terminalData = getClosestTerminalData(stationId, position)
            if not stationGroupData or stationGroupData.distance > terminalData.distance then
              stationGroupData = terminalData
              stationGroupData.stationIdx = stationIdx
            end
          end
        elseif #stationGroupComponent.stations == 1 then -- might we ever get an empty station group? maybe after station bulldoze? just to be safe...
          stationGroupData = getClosestTerminalData(stationGroupComponent.stations[1], position)
        end

        stationGroupData.stationGroup = stationGroupId

        -- We used the terminals to identify distance to the station, but the caller doesn't want the terminals in the result itself
        if stripTerminalInfo then
          stationGroupData.terminal = nil
          stationGroupData.stationIdx = nil
        end

        nearbyStationGroupData[#nearbyStationGroupData + 1] = stationGroupData
      end
    end

    table.sort(nearbyStationGroupData, function(a, b) return a.distance < b.distance end)

    return nearbyStationGroupData
  end)
end

return {
  getClosestStationGroupsAndTerminal = getClosestStationGroupsAndTerminal,
}
