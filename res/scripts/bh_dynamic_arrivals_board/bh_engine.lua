local vec3 = require "vec3"

local bhm = require "bh_dynamic_arrivals_board/bh_maths"
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"

local function getClosestTerminal(transform)
  print("getClosestTerminal")
  local componentType = api.type.ComponentType.STATION
  local position = bhm.transformVec(vec3.new(0, 0, 0), transform)
  local radius = 10
  debugPrint({ position = position })

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

  for _, entity in ipairs(results) do
    local station = api.engine.getComponent(entity, componentType)
      if station then
        local name = api.engine.getComponent(entity, api.type.ComponentType.NAME)
        debugPrint(name)
        --debugPrint(station)
        --print("-- end of station data --")

        for k, v in pairs(station.terminals) do
          print(v.vehicleNodeId.entity)
          local nodeData = api.engine.getComponent(v.vehicleNodeId.entity, api.type.ComponentType.BASE_NODE)
          --debugPrint(nodeData)

          if nodeData then
            local distance = vec3.distance(position, nodeData.position)
            if distance < shortestDistance then
              shortestDistance = distance
              closestEntity = entity
              closestTerminal = k
            end
            print("Terminal " .. tostring(k) .. " is " .. tostring(distance) .. "m away")
          end
        end

        --[[local s2c = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
          local stationConId = s2c[entity]
          local stationCon = api.engine.getComponent(stationConId, api.type.ComponentType.CONSTRUCTION)
          debugPrint(stationCon)]]

          --local lineStops = api.engine.system.lineSystem.getLineStopsForStation(entity)
          --debugPrint(lineStops)
    end
  end

  if closestEntity then
    return { station = closestEntity, terminal = closestTerminal }
  else
    return nil
  end
end

    --[[
      -- when we add the sign we should flag its next update to look for nearby stations
    -- and add data about that so we can use it to display something during the update
    local sign = api.engine.getComponent(param, api.type.ComponentType.CONSTRUCTION)
    if sign then
      local nearbyStations = getClosestStation(sign.transf)
      debugPrint(nearbyStations)
    end
]]

local function update()
  local state = stateManager.loadState()
  local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
  if time then
      time = math.floor(time / 1000)
      if time ~= state.world_time then
        state.world_time = time
        local clockString = string.format("%02d:%02d:%02d", (time / 60 / 60) % 24, (time / 60) % 60, time % 60)
        print(clockString)

        for k, v in pairs(state.placed_signs) do
          local sign = api.engine.getComponent(k, api.type.ComponentType.CONSTRUCTION)
          if not v.linked then
            local stationTerminal = getClosestTerminal(sign.transf)
            if stationTerminal then
              debugPrint({ ClosestTerminal = stationTerminal })

              local lineStops = api.engine.system.lineSystem.getLineStopsForTerminal(stationTerminal.station, stationTerminal.terminal - 1)
              if lineStops then
                print("The following lines stop at this terminal:")
                for _, line in pairs(lineStops) do
                  local lineName = api.engine.getComponent(line, api.type.ComponentType.NAME)
                  if lineName then
                    print(lineName.name)
                  end
                  print("Line data:")
                  local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
                  debugPrint(lineData)
                  print("Vehicles on line:")
                  local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
                  debugPrint(vehicles)
                  if vehicles then
                    for _, veh in ipairs(vehicles) do
                      local vehicle = api.engine.getComponent(veh, api.type.ComponentType.TRANSPORT_VEHICLE)
                      debugPrint(vehicle)
                    end
                  end
                end
              else
                print("No lines stop at this terminal - will only display the clock")
              end
              --debugPrint(lineStops)
            else
              print("Sign placed too far from a station - will only display the clock.")
            end
            v.linked = true
          end

          if sign then
            local newCon = api.type.SimpleProposal.ConstructionEntity.new()

            --debugPrint(sign)

            local newParams = {}
            for oldKey, oldVal in pairs(sign.params) do
              newParams[oldKey] = oldVal
            end

            newParams.bh_digital_display_time_string = clockString
            newParams.bh_digital_display_line1_dest = "test"
            newParams.bh_digital_display_line1_time = "5min"
            newParams.bh_digital_display_line2_dest = "test 2"
            newParams.bh_digital_display_line2_time = "10min"
            newParams.seed = sign.params.seed + 1

            newCon.fileName = sign.fileName
            newCon.params = newParams
            newCon.transf = sign.transf
            newCon.playerEntity = api.engine.util.getPlayer()

            --debugPrint(newCon)

            -- possible optimisation: build the proposal of multiple construction updates and send a single command after the loop
            local proposal = api.type.SimpleProposal.new()
            proposal.constructionsToAdd[1] = newCon
            proposal.constructionsToRemove = { k }

            -- simply changing params on a construction doesn't seem to change the entity id, yay!
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