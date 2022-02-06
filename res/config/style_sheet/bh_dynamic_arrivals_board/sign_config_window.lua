local ssu = require("stylesheetutil")

local hp = 10
local vp = 5

function data()
  local result = {}

  local a = ssu.makeAdder(result)

  a("DynamicArrivalsStationPick::Header::RescanButton", {
    backgroundColor1 = ssu.makeColor(83, 151, 198, 200),
    backgroundImage1 = {
      fileName = "ui/design/buttons/button_guide.tga",
      horizontal = { 0, 4, 6, 10 },
      vertical = { 10, 14, 16, 20 },
    },
  })
  a("DynamicArrivalsStationPick::Header::RescanButton:hover", {
    backgroundColor1 = ssu.makeColor(106, 192, 251, 200),
  })
  a("DynamicArrivalsStationPick::Header::RescanButton:active", {
    backgroundColor1 = ssu.makeColor(161, 217, 255, 200),
  })
  a("DynamicArrivalsStationPick::Header::RescanButton:disabled", {
    backgroundColor1 = ssu.makeColor(160, 180, 190, 50),
  })
  a("DynamicArrivalsStationPick::Header::Text", {
    padding = { vp, hp, vp, hp },
    fontSize = 13,
  })
  a("DynamicArrivalsStationPick::Table::Check", {
    padding = { vp, hp, vp, hp },
  })
  a("DynamicArrivalsStationPick::Table::Text", {
    padding = { vp, hp, vp, hp },
  })

  return result
end
