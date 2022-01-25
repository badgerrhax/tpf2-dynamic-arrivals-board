local targetConstructions = {}

local function getRegisteredConstructions()
  return targetConstructions
end

local function registerConstruction(conPath, params)
  targetConstructions[conPath] = params
end

return {
  registerConstruction = registerConstruction,
  getRegisteredConstructions = getRegisteredConstructions
}