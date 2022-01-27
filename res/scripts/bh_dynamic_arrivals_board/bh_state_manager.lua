local persistent_state = {}

local function ensureState()
  if persistent_state.world_time == nil then
    persistent_state.world_time = 0
  end

  if persistent_state.placed_signs == nil then
    persistent_state.placed_signs = {}
  end
end

local function loadState(state)
  if state then
    persistent_state = state
  end

  ensureState()

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