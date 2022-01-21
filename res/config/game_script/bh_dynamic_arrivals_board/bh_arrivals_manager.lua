local persistent_state = {
  world_time = 0,
  placed_signs = {}
}

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
          local newCon = api.type.SimpleProposal.ConstructionEntity.new()

          debugPrint(sign)

          local newParams = {
            bh_digital_display_line1_dest = 0,
            bh_digital_display_line1_time = 0,
            bh_digital_display_line2_dest = 0,
            bh_digital_display_line2_time = 0,
            bh_digital_display_style = 0,
            bh_digital_display_x_offset_major = 10,
            bh_digital_display_x_offset_minor = 19,
            bh_digital_display_x_rotate = 0,
            bh_digital_display_x_rotate_fine = 44,
            bh_digital_display_y_offset_major = 10,
            bh_digital_display_y_offset_minor = 19,
            bh_digital_display_y_rotate_fine = 44,
            bh_digital_display_z_offset_major = 10,
            bh_digital_display_z_offset_minor = 19,
            bh_digital_display_z_rotate_fine = 44,
            paramX = 0,
            paramY = 0,
            seed = sign.params.seed + 1,
            year = 2030,
            bh_digital_display_time_seconds = (time % 60) + 1,
            bh_digital_display_time_mins = ((time / 60) % 60) + 1,
            bh_digital_display_time_hours = ((time / 60 / 60) % 24) + 1,
          }
 
          newCon.fileName = sign.fileName
          newCon.params = newParams
          newCon.transf = sign.transf
          newCon.playerEntity = api.engine.util.getPlayer()

          debugPrint(newCon)

          local proposal = api.type.SimpleProposal.new()
          proposal.constructionsToAdd[1] = newCon
          proposal.constructionsToRemove = { k }
          --proposal.old2new = { k = 0 }

          -- todo replace with new id
          --persistent_state.placed_signs[k] = nil

          api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, api.type.Context:new(), true),
            function(result, success)
              debugPrint({ buildProposal = {result = result, success = success }})
            end
          )
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