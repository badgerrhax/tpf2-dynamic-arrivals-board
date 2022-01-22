local vec3 = require "vec3"

local persistent_state = {
  world_time = 0,
  placed_signs = {}
}

local function transformVec(vec, matrix)
  return {
    x = vec.x * matrix[1] + vec.y * matrix[5] + vec.z * matrix[9] + matrix[13],
    y = vec.x * matrix[2] + vec.y * matrix[6] + vec.z * matrix[10] + matrix[14],
    z = vec.x * matrix[3] + vec.y * matrix[7] + vec.z * matrix[11] + matrix[15]
}
end

local function getClosestStation(transform)
  local componentType = api.type.ComponentType.STATION
  local position = transformVec(vec3.new(0, 0, 0), transform)
  local radius = 100

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

  return results
end

function data()
return {

------------------ Engine state

save = function()
  return persistent_state
end,

load = function(loadedstate)
  persistent_state = loadedstate or persistent_state
  if persistent_state.placed_signs == nil then
    persistent_state.placed_signs = {}
  end
end,

update = function()
  local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
  if time then
      time = math.floor(time / 1000)
      if time ~= persistent_state.world_time then
        persistent_state.world_time = time
        local clockString = string.format("%02d:%02d:%02d", (time / 60 / 60) % 24, (time / 60) % 60, time % 60)
        print(clockString)

        for k, _ in pairs(persistent_state.placed_signs) do
          local sign = api.engine.getComponent(k, api.type.ComponentType.CONSTRUCTION)
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
            api.cmd.sendCommand(
              api.cmd.make.buildProposal(proposal, api.type.Context:new(), true)--[[,
              function(result, success)
                debugPrint({ buildProposal = {result = result, success = success }})
              end]]
            )
          end
        end
      end
  else
      print("cannot get time!")
  end
end,

handleEvent = function(src, id, name, param)
  --[[if src ~= "guidesystem.lua" then
    debugPrint({ handleEvent = { src, id, name, param }})
  end]]
  if name == "add_display_construction" then
    -- when we add the sign we should look for a nearby station
    -- and add data about that so we can use it to display something during the update
    xpcall(function()
      local sign = api.engine.getComponent(param, api.type.ComponentType.CONSTRUCTION)
      if sign then
        local nearbyStations = getClosestStation(sign.transf)
        debugPrint(nearbyStations)
      end
    end, function(err) print(err) end)

    persistent_state.placed_signs[param] = true
    print("Player created sign ID " .. tostring(param) .. ". Now managing the following signs:")
    debugPrint(persistent_state.placed_signs)
  elseif name == "remove_display_construction" then
    persistent_state.placed_signs[param] = nil
    print("Player removed sign ID " .. tostring(param) .. ". Now managing the following signs:")
    debugPrint(persistent_state.placed_signs)
  end
end,



-------------- GUI state

guiUpdate = function()
end,

guiHandleEvent = function(id, name, param)
  if name == 'builder.apply' or name == 'select' then
    debugPrint({ guiHandleEvent = { id, name, param }})

    if name == 'builder.apply' then
      if param and param.proposal then
        local toAdd = param.proposal.toAdd
        if toAdd and toAdd[1] and toAdd[1].fileName == "asset/bh_dynamic_arrivals_board/bh_digital_display.con" then
          if param.result and param.result[1] then
            api.cmd.sendCommand(api.cmd.make.sendScriptEvent("bh_arrivals_manager.lua", id, "add_display_construction", param.result[1]))
          end
        end
        local toRemove = param.proposal.toRemove
        if toRemove and toRemove[1] and persistent_state.placed_signs[toRemove[1]] then
          api.cmd.sendCommand(api.cmd.make.sendScriptEvent("bh_arrivals_manager.lua", id, "remove_display_construction", toRemove[1]))
        end
      end
    end
  end
end,




}
end