-- State is pretty much read-only here
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"
local guiWindows = require "bh_dynamic_arrivals_board/bh_gui_windows"

local function sendScriptEvent(id, msg, param)
  api.cmd.sendCommand(api.cmd.make.sendScriptEvent("bh_gui_engine.lua", id, msg, param))
end

local function handleEvent(id, name, param)
  if name == 'builder.apply' or name == 'select' then
    local state = stateManager.getState()

    if name == 'select' then
      sendScriptEvent(id, "select_object", param)

      -- if we select a sign, show a gui to change stuff that can't be done in the construction params
      local sign = api.engine.getComponent(param, api.type.ComponentType.CONSTRUCTION)
      if sign and construction.getRegisteredConstructions()[sign.fileName] then
        -- commented out until fully functional
        --guiWindows.ConfigureSign(param)
      end
    end

    if name == 'builder.apply' then
      if param and param.proposal then
        local toAdd = param.proposal.toAdd
        if toAdd and toAdd[1] and construction.getRegisteredConstructions()[toAdd[1].fileName] then
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