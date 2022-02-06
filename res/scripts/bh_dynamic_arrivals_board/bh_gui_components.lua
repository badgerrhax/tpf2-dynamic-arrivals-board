local utils = require "bh_dynamic_arrivals_board/bh_utils"

-- the UG checkbox doesn't seem to work (the docs for new() are wrong and I couldn't guess the params it wanted)
-- so use a toggle button instead (and also wrap the callback in call-safety here to save other instances doing it)
local function createCheckBox(initialState, onToggle)
  local uncheckedImage = "ui/design/components/checkbox_invalid.tga"
  local checkedImage = "ui/design/components/checkbox_valid.tga"

  local checkImg = api.gui.comp.ImageView.new(initialState and checkedImage or uncheckedImage)
  local check = api.gui.comp.ToggleButton.new(checkImg)

  if initialState == nil then
    initialState = false
  end

  check:setSelected(initialState, false)
  check:onToggle(utils.safeCall(function(toggled)
    checkImg:setImage(toggled and checkedImage or uncheckedImage, false)

    if onToggle then
      onToggle(toggled)
    end
  end))

  return check
end

-- returns a table component and a function for adding station groups to it
-- TODO: adding the util to the metatable would be cleaner if possible
local function createStationTable(styleName, onToggle)
  local stationTable = api.gui.comp.Table.new(3, "NONE")
  stationTable:setHeader({
    api.gui.comp.TextView.new(_("StationPickTableCheckHeader")),
    api.gui.comp.TextView.new(_("StationPickTableNameHeader")),
    api.gui.comp.TextView.new(_("StationPickTableDistanceHeader")),})
  stationTable:setColWeight(1, 2)

  local function addStationGroup(stationGroupId, enabled, distance)
    if not utils.validEntity(stationGroupId) then
      return
    end

    local nameString

    local stationGroupName = api.engine.getComponent(stationGroupId, api.type.ComponentType.NAME)
    if stationGroupName then
      nameString = stationGroupName.name
    end

    if not nameString then
      nameString = tostring(stationGroupId)
    end

    local nameView = api.gui.comp.TextView.new(nameString)
    nameView:setName(styleName .. "::Table::Text")

    local checkBox = createCheckBox(enabled, function(toggled) onToggle(toggled, stationGroupId) end)
    checkBox:setGravity(0.5, 0)
    checkBox:setName(styleName .. "::Table::Check")

    if distance == nil then
      distance = 0
    end
    local distanceString = string.format("%.1fm", distance)
    local distanceView = api.gui.comp.TextView.new(distanceString)
    distanceView:setName(styleName .. "::Table::Text")

    stationTable:addRow({ checkBox, nameView, distanceView })
  end

  local object = {
    Component = stationTable,
    addStationGroup = addStationGroup
  }

  return object
end

local function createStationPickerHeader(styleName, onRescan)
  local headerText = api.gui.comp.TextView.new(_("StationPickHeaderText"))
  headerText:setName(styleName .. "::Header::Text")

  local fatten = api.gui.comp.TextView.new("")
  fatten:setGravity(-1, 0)

  local buttonIcon = api.gui.comp.ImageView.new("ui/icons/windows/vehicle_replace.tga")
  buttonIcon:setName(styleName .. "::Header::RescanButton::Icon")

  local stationRescanButton = api.gui.comp.Button.new(buttonIcon, false)
  stationRescanButton:setName(styleName .. "::Header::RescanButton")
  stationRescanButton:setGravity(0, 1)
  stationRescanButton:setTooltip(_("StationPickRefreshTooltipText"))
  stationRescanButton:onClick(utils.safeCall(onRescan))

  local headerRow = api.gui.layout.BoxLayout.new("HORIZONTAL")
  headerRow:addItem(headerText)
  headerRow:addItem(fatten)
  headerRow:addItem(stationRescanButton)

  return headerRow
end

return {
  createCheckBox = createCheckBox,
  createStationTable = createStationTable,
  createStationPickerHeader = createStationPickerHeader
}