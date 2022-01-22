
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local engine = require "bh_dynamic_arrivals_board/bh_engine"
local guiEngine = require "bh_dynamic_arrivals_board/bh_gui_engine"

local function errorHandler(error)
  print(error)
end

function data()
return {

----------------- State exchange

save = function()
  return stateManager.getState()
end,

load = function(loadedstate)
  stateManager.loadState(loadedstate)
end,


------------------ Engine state

update = function()
  xpcall(engine.update, errorHandler)
end,

handleEvent = function(src, id, name, param)
  xpcall(function() engine.handleEvent(src, id, name, param) end, errorHandler)
end,

-------------- GUI state

guiHandleEvent = function(id, name, param)
  xpcall(function() guiEngine.handleEvent(id, name, param) end, errorHandler)
end,

}
end