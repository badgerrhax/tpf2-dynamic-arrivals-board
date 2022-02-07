local log = require("bh_dynamic_arrivals_board/bh_log")

local persistent_state = {}

local function migrateV1(state)
  -- I changed the save state structure to allow each sign to hold multiple attached stations, so
  -- need to move any existing sign station into this new structure

  log.message("Performing save state upgrade to v1")
  log.object("old state", state)

  local newSigns = {}
  for signEntity, signData in pairs(state.placed_signs) do
    if signData.stationTerminal then
      signData.stationTerminal.displaying = true
      newSigns[signEntity] = { signData.stationTerminal }
    end
  end
  state.placed_signs = newSigns
  state.state_version = 1

  log.object("new state", state)
  return state
end

local function ensureState(loaded)
  if not loaded then
    -- something called ensureState without having loaded a state, so this is a blank initialisation
    -- and has no need for migrations
    persistent_state.state_version = 1
  end

  if persistent_state.world_time == nil then
    persistent_state.world_time = 0
  end

  if persistent_state.placed_signs == nil then
    persistent_state.placed_signs = {}
  end

  if persistent_state.state_version == nil then
    persistent_state = migrateV1(persistent_state)
  end
end

local function loadState(state)
  if state then
    persistent_state = state
  end

  ensureState(state ~= nil)

  return persistent_state
end

local function getState()
  return persistent_state
end

return {
  loadState = loadState,
  getState = getState,
  ensureState = ensureState
}