local function makeOffsetParams(params, configKeyFunc)
	local offsetMajorValues = {}
	local offsetMinorValues = {}
	for i = -10, 10 do
		offsetMajorValues[#offsetMajorValues+1] = tostring(i)
	end
	for i = -0.95, 1, 0.05 do
		offsetMinorValues[#offsetMinorValues+1] = tostring(i)
	end
	offsetMinorValues[math.ceil(#offsetMinorValues/2)] = "0"

	params[#params+1] = {
		key = configKeyFunc("x_offset_major"),
		name = _("X Offset"),
		values = offsetMajorValues,
		uiType = "SLIDER",
		defaultIndex = #offsetMajorValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("x_offset_minor"),
		name = _("X Offset (fine)"),
		values = offsetMinorValues,
		uiType = "SLIDER",
		defaultIndex = #offsetMinorValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("y_offset_major"),
		name = _("Y Offset"),
		values = offsetMajorValues,
		uiType = "SLIDER",
		defaultIndex = #offsetMajorValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("y_offset_minor"),
		name = _("Y Offset (fine)"),
		values = offsetMinorValues,
		uiType = "SLIDER",
		defaultIndex = #offsetMinorValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("z_offset_major"),
		name = _("Z Offset"),
		values = offsetMajorValues,
		uiType = "SLIDER",
		defaultIndex = #offsetMajorValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("z_offset_minor"),
		name = _("Z Offset (fine)"),
		values = offsetMinorValues,
		uiType = "SLIDER",
		defaultIndex = #offsetMinorValues / 2
	}

	return params
end

local function readOffsetParams(params, configKeyFunc)
	local offsetMajorValues = {}
	local offsetMinorValues = {}
	for i = -10, 10 do
		offsetMajorValues[#offsetMajorValues+1] = i
	end
	for i = -0.95, 1, 0.05 do
		offsetMinorValues[#offsetMinorValues+1] = i
	end
	offsetMinorValues[math.ceil(#offsetMinorValues/2)] = 0

	local xMin = offsetMinorValues[params[configKeyFunc("x_offset_minor")]+1]
	local xMaj = offsetMajorValues[params[configKeyFunc("x_offset_major")]+1]
	local yMin = offsetMinorValues[params[configKeyFunc("y_offset_minor")]+1]
	local yMaj = offsetMajorValues[params[configKeyFunc("y_offset_major")]+1]
	local zMin = offsetMinorValues[params[configKeyFunc("z_offset_minor")]+1]
	local zMaj = offsetMajorValues[params[configKeyFunc("z_offset_major")]+1]

	return { x = xMaj + xMin, y = yMaj + yMin, z = zMaj + zMin }
end

local function makeScaleParams(params, configKeyFunc)
	local scaleValues = {}
	for i = 10, 200, 5 do
		scaleValues[#scaleValues+1] = tostring(i) .. "%"
	end

	params[#params+1] = {
		key = configKeyFunc("x_scale"),
		name = _("X Scale"),
		values = scaleValues,
		uiType = "SLIDER",
		defaultIndex = #scaleValues / 2 - 1
	}
	params[#params+1] = {
		key = configKeyFunc("y_scale"),
		name = _("Y Scale"),
		values = scaleValues,
		uiType = "SLIDER",
		defaultIndex = #scaleValues / 2 - 1
	}
	params[#params+1] = {
		key = configKeyFunc("z_scale"),
		name = _("Z Scale"),
		values = scaleValues,
		uiType = "SLIDER",
		defaultIndex = #scaleValues / 2 - 1
	}

	return params
end

local function readScaleParams(params, configKeyFunc)
	local scaleValues = {}
	for i = 10, 200, 5 do
		scaleValues[#scaleValues+1] = i / 100
	end

	return {
		x = scaleValues[params[configKeyFunc("x_scale")]+1],
		y = scaleValues[params[configKeyFunc("y_scale")]+1],
		z = scaleValues[params[configKeyFunc("z_scale")]+1]
	}
end

local function makeRotateParams(params, configKeyFunc)
	local fineRotateValues = {}
	for i = -11, 11, 0.25 do
		fineRotateValues[#fineRotateValues+1] = tostring(i)
	end

	local bigRotateValues = {}
	for i = 0, 348.75, 11.25 do
		bigRotateValues[#bigRotateValues+1] = tostring(i)
	end

	params[#params+1] = {
		key = configKeyFunc("x_rotate"),
		name = _("X Rotate"),
		values = bigRotateValues,
		uiType = "SLIDER",
		defaultIndex = 0
	}

	params[#params+1] = {
		key = configKeyFunc("x_rotate_fine"),
		name = _("X Rotate (fine)"),
		values = fineRotateValues,
		uiType = "SLIDER",
		defaultIndex = #fineRotateValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("y_rotate_fine"),
		name = _("Y Rotate (fine)"),
		values = fineRotateValues,
		uiType = "SLIDER",
		defaultIndex = #fineRotateValues / 2
	}
	params[#params+1] = {
		key = configKeyFunc("z_rotate_fine"),
		name = _("Z Rotate (fine)"),
		values = fineRotateValues,
		uiType = "SLIDER",
		defaultIndex = #fineRotateValues / 2
	}

	return params
end

local function readRotateParams(params, configKeyFunc)
	local fineRotateValues = {}
	for i = -11, 11, 0.25 do
		fineRotateValues[#fineRotateValues+1] = math.rad(i)
	end

	local bigRotateValues = {}
	for i = 0, 348.75, 11.25 do
		bigRotateValues[#bigRotateValues+1] = math.rad(i)
	end

	local xBig = bigRotateValues[params[configKeyFunc("x_rotate")]+1]
	local xFine = fineRotateValues[params[configKeyFunc("x_rotate_fine")]+1]
	local yFine = fineRotateValues[params[configKeyFunc("y_rotate_fine")]+1]
	local zFine = fineRotateValues[params[configKeyFunc("z_rotate_fine")]+1]

	return { x = xBig + xFine, y = yFine, z = zFine }
end

local function parameterIcons(m)
	local icons = {}
	for i, v in ipairs(m) do
		icons[#icons+1] = "ui/parameters/bh_metrolink_station/bh_" .. v .. ".tga"
	end
	return icons
end

return {
  makeOffsetParams = makeOffsetParams,
  readOffsetParams = readOffsetParams,
	makeScaleParams = makeScaleParams,
	readScaleParams = readScaleParams,
	makeRotateParams = makeRotateParams,
	readRotateParams = readRotateParams,
	parameterIcons = parameterIcons,
}