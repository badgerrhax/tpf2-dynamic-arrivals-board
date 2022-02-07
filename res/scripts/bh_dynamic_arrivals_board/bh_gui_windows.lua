local guiComp = require "bh_dynamic_arrivals_board/bh_gui_components"
local camera = require "bh_dynamic_arrivals_board.bh_camera"
local utils = require "bh_dynamic_arrivals_board/bh_utils"

-- There's a function on window called "setLocateButtonVisible" to add a locate button
-- but apparently no associated helper func to set the onClick callback or set the entity for it to locate
-- so this finds the button in the window layout so i can add a callback to it
local function findWindowLocateButton(window)
  local windowLayout = window:getLayout()
  for windowItemIdx = 0, windowLayout:getNumItems() do
    local windowItem = windowLayout:getItem(windowItemIdx)
    if windowItem:getName() == "Window::Title-bar" then
      local titleBarLayout = windowItem:getLayout()
      for titleBarItemIdx = 0, titleBarLayout:getNumItems() do
        local titleBarItem = titleBarLayout:getItem(titleBarItemIdx)
        if titleBarItem:getName() == "Window::Locate" then
          return titleBarItem
        end
      end
      break
    end
  end

  return nil
end

-- We can only set the locate callback once (button:onClick ADDS callbacks, doesn't replace them)
-- so our callback needs to capture this table instead (by ref) so future calls to ConfigureSign
-- can update the target entity without having to recreate the window (which is the thing that owns the locate button)
local lastSelectedEntity = {}

local function hideConfigureSign()
  local window = api.gui.util.getById("DynamicArrivals.SignConfig.Window")
  if window then
    window:setVisible(false, false)
  end
end

local function ConfigureSign(signEntity, nearbyStationGroupData, callbacks)
  local width = 400

  local layout = api.gui.layout.BoxLayout.new("VERTICAL")
  local window = api.gui.util.getById("DynamicArrivals.SignConfig.Window")

  -- need to capture the current entity
  lastSelectedEntity.targetEntity = signEntity

  if window == nil then
    local gameRect = api.gui.util.getGameUI():getContentRect()

    -- size and centre it only on creation to respect player moving it to a preferred location
    local posX = gameRect.w / 2 - width
    local size = api.gui.util.Size.new(width, 200)

    window = api.gui.comp.Window.new("", layout)
    window:setId("DynamicArrivals.SignConfig.Window")
    window:setPosition(posX, 100)
    window:setSize(size)
    window:setLocateButtonVisible(true)
    window:addHideOnCloseHandler()

    -- manually add a callback to handle the locate button press and fly to the sign
    local locateButton = findWindowLocateButton(window)
    if locateButton ~= nil then
      locateButton:onClick(utils.safeCall(function()
        camera.flyToEntity(lastSelectedEntity.targetEntity)
      end))
    end
  else
    window:setContent(layout)
  end

  window:setTitle(_("ConfigureSignWindowTitle") .. " [" .. tostring(signEntity) .. "]")
  window:setVisible(true, false)

  local stationTable = guiComp.createStationTable("DynamicArrivalsStationPick", callbacks.stationToggle)
  local header = guiComp.createStationPickerHeader("DynamicArrivalsStationPick", callbacks.onRescan)

  for _, station in ipairs(nearbyStationGroupData) do
    stationTable.addStationGroup(station.stationGroup, station.displaying, station.distance)
  end

  local scrollArea = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new("Stations"), "DynamicArrivals.SignConfig.Window.ScrollArea")
  scrollArea:setMinimumSize(api.gui.util.Size.new(width, 130))
  scrollArea:setMaximumSize(api.gui.util.Size.new(width, 130))
  scrollArea:setContent(stationTable.Component)

  layout:addItem(header)
  layout:addItem(scrollArea)

  return window
end

return {
  ConfigureSign = ConfigureSign,
  hideConfigureSign = hideConfigureSign
}