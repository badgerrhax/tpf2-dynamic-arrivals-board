local targetConstructions = {}

local function getRegisteredConstructions()
  return targetConstructions
end

local function registerConstruction(conPath, params)
  targetConstructions[conPath] = params
end

local function isRegistered(conPath)
  return targetConstructions[conPath] ~= nil
end

return {
  registerConstruction = registerConstruction,
  getRegisteredConstructions = getRegisteredConstructions,
  isRegistered = isRegistered
}