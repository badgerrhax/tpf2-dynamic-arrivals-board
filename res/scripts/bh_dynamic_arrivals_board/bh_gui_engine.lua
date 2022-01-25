-- State is pretty much read-only here
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

local function sendScriptEvent(id, msg, param)
  api.cmd.sendCommand(api.cmd.make.sendScriptEvent("bh_gui_engine.lua", id, msg, param))
end

local function handleEvent(id, name, param)
  if name == 'builder.apply' or name == 'select' then
    --debugPrint({ guiHandleEvent = { id, name, param }})
    local state = stateManager.getState()
    debugPrint({ guiConstructions = construction.getRegisteredConstructions() })

    if name == 'builder.apply' then
      if param and param.proposal then
        local toAdd = param.proposal.toAdd
        if toAdd and toAdd[1] and toAdd[1].fileName == "asset/bh_dynamic_arrivals_board/bh_digital_display.con" then
          if param.result and param.result[1] then
            sendScriptEvent(id, "add_display_construction", param.result[1])
          end
        end
        local toRemove = param.proposal.toRemove
        if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
          sendScriptEvent(id, "remove_display_construction", toRemove[1])
        end
      end
    end
  end
end

return {
  handleEvent = handleEvent
}