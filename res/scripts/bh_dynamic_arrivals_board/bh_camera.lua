local function getCameraController()
  local ui = api.gui.util.getGameUI()
  if not ui then return nil end

  local renderer = api.gui.comp.GameUI.getMainRendererComponent(ui)
  if not renderer then return nil end

  return api.gui.comp.RendererComponent.getCameraController(renderer)
end

local function flyToEntity(entity)
  local camera = getCameraController()
  if camera and camera:getFollowEntity() ~= entity then
    camera:follow(entity, true)
  end
end

return {
  flyToEntity = flyToEntity
}