local vec3 = require "vec3"
local bhm = require "bh_dynamic_arrivals_board/bh_maths"

local function getTpnEdges(entity)
  local tpn

  local network = api.engine.getComponent(entity, api.type.ComponentType.TRANSPORT_NETWORK)
  if network then
    tpn = network.edges
  else
    tpn = {}
  end

  return tpn
end

-- version 35024 changed the structure of geometry.params so pos and tangent are arrays of 2 vectors.
-- this function performs a one-off version check to allow us to account for this across current release and beta.
-- this check can be removed after beta is released but for now workshop mod needs to maintain compatibility for both versions.
local geometryParamsAreArray
local function expectGeometryParamArray()
  -- first time version check / string parse, because this function is called a lot and otherwise expensive
  if geometryParamsAreArray == nil then
    local gameVersion = api.util.getBuildVersion()
    -- return type of getBuildVersion also changed from number to string
    if type(gameVersion) == "string" then
      gameVersion = tonumber(gameVersion)
    end

    geometryParamsAreArray = gameVersion >= 35024
  end

  return geometryParamsAreArray
end

local function getPosParam(geometry)
  if expectGeometryParamArray() then
    return geometry.params.pos[1]
  else
    return geometry.params.pos
  end
end

local function getTanParam(geometry)
  if expectGeometryParamArray() then
    if geometry.params.tangent then
      return geometry.params.tangent[1]
    else
      return { x = 0, y = 0 }
    end
  else
    return geometry.params.tangent or { x = 0, y = 0 }
  end
end

-- calculates the start or end point of an edge using its origin position and tangent
local function edgeNodePos(geometry, index) -- <= 1 for start point, > 1 for end point
  local pos = getPosParam(geometry)
  local tan = getTanParam(geometry)
  local offset = geometry.params.offset or 0
  local perpendicularOffset = offset * vec3.normalize(vec3.new(-tan.y, tan.x, 0))
  return (index > 1 and
    vec3.new(pos.x + tan.x, pos.y + tan.y, geometry.height.y) or
    vec3.new(pos.x, pos.y, geometry.height.x)) + perpendicularOffset
end

-- calculates the distance from position to the closest point on edge
local function distanceFromEdge(position, edgeId)
  local tpn = getTpnEdges(edgeId.entity)
  if tpn then
    local edge = tpn[edgeId.index]
    if edge and edge.geometry then
      return bhm.distanceToLine(position, edgeNodePos(edge.geometry, 1), edgeNodePos(edge.geometry, 2))
    end
  end

  return nil
end

-- get the distance from a node in the transport network by finding its entity/id combo
-- in a set of edge connections and calculating its position using the edge geometry.
-- there are usually 2 instances of this node in a set of edges but we only need the first
-- because the tangent calcs result in the same value regardless (because the edge ends at the same node)
local function distanceFromNode(position, nodeId)
  local tpn = getTpnEdges(nodeId.entity)
  if tpn then
    for _, edge in ipairs(tpn) do
      if edge.conns and edge.geometry then
        for idx, conn in ipairs(edge.conns) do
          if conn.entity == nodeId.entity and conn.index == nodeId.index then
            return vec3.distance(position, edgeNodePos(edge.geometry, idx))
          end
        end
      end
    end
  end

  return nil
end

return {
  distanceFromEdge = distanceFromEdge,
  distanceFromNode = distanceFromNode,
}