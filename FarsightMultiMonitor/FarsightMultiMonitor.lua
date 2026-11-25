local addonName, ns = ...

local layout = ns.layout
if not layout then
	return
end

local SIDE_TEXTURE = "Interface\\FrameGeneral\\UI-Background-Marble"
local DROP_MARGIN = 40
local PARKED_FRAMES = { "CompactRaidFrameManager" }
local UI_HEIGHT = 768
local MIN_AUTO_SCALE = 0.64
local SCALED_CVARS = {
	WorldTextScale_v2 = function(world)
		return math.max(layout.width / world.width, layout.height / world.height)
	end,
	CursorFreelookStartDelta = function(_, mainMonitor)
		return layout.width / mainMonitor.width
	end,
}
local MOVABLE_TYPES = { "Frame", "Button" }
local MAP_MIN_SCALE = 0.5
local SCALE_GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber"
local SCALE_GRIP_SIZE = 16
local SCALE_GRIP_INSET = 4

local screenFrame = CreateFrame("Frame")
screenFrame:SetAllPoints()
screenFrame:SetScale(GetScreenHeight() * UIParent:GetEffectiveScale() / layout.height)

local clipFrame = CreateFrame("Frame", nil, UIParent)
clipFrame:SetAllPoints()
clipFrame:SetClipsChildren(true)

local sideFrame = CreateFrame("Frame", nil, screenFrame)
sideFrame:SetAllPoints()
sideFrame:SetFrameStrata("BACKGROUND")

local monitorKeys = {}
local monitorFrames = {}
local backgrounds = {}
local unionLeft, unionTop, unionRight, unionBottom = math.huge, math.huge, -math.huge, -math.huge
for index, monitor in ipairs(layout.monitors) do
	monitorKeys[index] = string.format("%dx%d", monitor.width, monitor.height)
	local monitorFrame = CreateFrame("Frame", nil, screenFrame)
	monitorFrame:SetPoint("TOPLEFT", monitor.x, -monitor.y)
	monitorFrame:SetSize(monitor.width, monitor.height)
	monitorFrames[index] = monitorFrame
	local background = sideFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(monitorFrame)
	background:SetTexture(SIDE_TEXTURE, "REPEAT", "REPEAT")
	background:SetHorizTile(true)
	background:SetVertTile(true)
	backgrounds[index] = background
	unionLeft, unionTop = math.min(unionLeft, monitor.x), math.min(unionTop, monitor.y)
	unionRight, unionBottom = math.max(unionRight, monitor.x + monitor.width), math.max(unionBottom, monitor.y + monitor.height)
end
local layoutKey = table.concat(monitorKeys, " ")
local worldArea = CreateFrame("Frame", nil, screenFrame)

local mainIndex = layout.main
local spanned = false
local fullWidth = false
local positions
local adopted = {}
local restore
local fitting = false
local windowScales = {}
local dragged
local moveStarts = {}
local appliedCVars = {}

function ns.isSpanned()
	return spanned
end

local function mainMonitorScale(mainMonitor)
	if GetCVarBool("useUiScale") then
		return tonumber(GetCVar("uiScale"))
	end
	return math.min(1, math.max(MIN_AUTO_SCALE, UI_HEIGHT / mainMonitor.height))
end

local function readPlayerCVar(name)
	local saved = FarsightMultiMonitorDB.playerCVars
	local current = GetCVar(name)
	if not saved[name] or appliedCVars[name] and current ~= appliedCVars[name] then
		saved[name] = current
	end
end

local function applyScaledCVars(world, mainMonitor)
	if not FarsightMultiMonitorDB then
		return
	end
	for name, ratio in pairs(SCALED_CVARS) do
		readPlayerCVar(name)
		SetCVar(name, tonumber(FarsightMultiMonitorDB.playerCVars[name]) / (spanned and ratio(world, mainMonitor) or 1))
		appliedCVars[name] = GetCVar(name)
	end
end

local function canWiden()
	return mainIndex == layout.main
end

local function widened()
	return fullWidth and canWiden()
end

local function worldRect(monitor)
	if not widened() then
		return monitor
	end
	local centerX, centerY = monitor.x + monitor.width / 2, monitor.y + monitor.height / 2
	local halfWidth = math.max(centerX - unionLeft, unionRight - centerX)
	local halfHeight = math.max(centerY - unionTop, unionBottom - centerY)
	return { x = centerX - halfWidth, y = centerY - halfHeight, width = halfWidth * 2, height = halfHeight * 2 }
end

local function applyViewport()
	local width, height = GetPhysicalScreenSize()
	spanned = width == layout.width and height == layout.height
	sideFrame:SetShown(spanned and not widened())
	for index, background in ipairs(backgrounds) do
		background:SetShown(index ~= mainIndex)
	end
	if InCombatLockdown() then
		return
	end
	local mainMonitor = layout.monitors[mainIndex]
	local world = worldRect(mainMonitor)
	WorldFrame:ClearAllPoints()
	UIParent:ClearAllPoints()
	worldArea:ClearAllPoints()
	worldArea:SetPoint("TOPLEFT", world.x, -world.y)
	worldArea:SetSize(world.width, world.height)
	if spanned then
		WorldFrame:SetAllPoints(worldArea)
		UIParent:SetAllPoints(monitorFrames[mainIndex])
		UIParent:SetScale(mainMonitorScale(mainMonitor) * mainMonitor.height / layout.height)
	else
		WorldFrame:SetAllPoints(screenFrame)
		UIParent:SetAllPoints(screenFrame)
	end
	applyScaledCVars(world, mainMonitor)
	for _, name in ipairs(PARKED_FRAMES) do
		local parked = _G[name]
		if parked then
			parked:SetParent(clipFrame)
		end
	end
	for frame in pairs(adopted) do
		restore(frame)
	end
end

local function isLocked(frame)
	return InCombatLockdown() and frame:IsProtected()
end

local function isMaximized(frame)
	return frame.IsMaximized and frame:IsMaximized()
end

local function pointIn(frame, region, point)
	local left, bottom, width, height = region:GetRect()
	local x = point:find("LEFT") and left or point:find("RIGHT") and left + width or left + width / 2
	local y = point:find("TOP") and bottom + height or point:find("BOTTOM") and bottom or bottom + height / 2
	local toFrame = region:GetEffectiveScale() / frame:GetEffectiveScale()
	return x * toFrame, y * toFrame
end

local function homeMonitor(frame)
	local position = positions[frame:GetName()]
	return monitorFrames[position and position.monitor or mainIndex]
end

local function fitScale(frame, monitorFrame)
	local scale = monitorFrame:GetEffectiveScale() / frame:GetParent():GetEffectiveScale()
	local width, height = frame:GetSize()
	return math.min(monitorFrame:GetWidth() * scale / width, monitorFrame:GetHeight() * scale / height)
end

local function shiftRoom(frame, monitorFrame)
	return math.max(0, (monitorFrame:GetWidth() * monitorFrame:GetEffectiveScale() / frame:GetEffectiveScale() - frame:GetWidth()) / 2)
end

function restore(frame)
	local position = positions[frame:GetName()]
	local maximized = isMaximized(frame)
	if not spanned or not (position or maximized) or moveStarts[frame] or isLocked(frame) then
		return
	end
	local methods = getmetatable(frame).__index
	methods.ClearAllPoints(frame)
	if maximized then
		local monitorFrame = homeMonitor(frame)
		methods.SetPoint(frame, "CENTER", monitorFrame, FarsightMultiMonitorDB.mapShift * shiftRoom(frame, monitorFrame), 0)
	else
		local monitorLeft, monitorTop = pointIn(UIParent, monitorFrames[position.monitor], "TOPLEFT")
		local toFrame = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
		methods.SetPoint(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", (monitorLeft + position.left - UIParent:GetLeft()) * toFrame, (monitorTop + position.top - UIParent:GetBottom()) * toFrame)
	end
end

local function fitMonitor(frame)
	if not spanned or fitting or isLocked(frame) then
		return
	end
	fitting = true
	windowScales[frame] = windowScales[frame] or frame:GetScale()
	frame:SetScale(fitScale(frame, homeMonitor(frame)))
	fitting = false
	restore(frame)
end

local function keepPlace(frame)
	if isMaximized(frame) then
		fitMonitor(frame)
	else
		restore(frame)
	end
end

local function clearFit(frame)
	local scale = windowScales[frame]
	if not scale or isLocked(frame) then
		return
	end
	windowScales[frame] = nil
	frame:SetScale(scale)
end

local function onSideMonitor(frame)
	local position = positions[frame:GetName()]
	return spanned and position and position.monitor ~= mainIndex
end

local function keepMainMonitorVisible(frame)
	frame.BlackoutFrame:HookScript("OnShow", function(blackout)
		if onSideMonitor(frame) then
			blackout:Hide()
		end
	end)
end

local function keepOpaque(frame, alpha)
	if alpha < 1 and onSideMonitor(frame) then
		frame:SetAlpha(1)
	end
end

local function adopt(frame)
	if adopted[frame] then
		return
	end
	adopted[frame] = true
	frame:SetMovable(true)
	hooksecurefunc(frame, "SetPoint", restore)
	hooksecurefunc(frame, "SetScale", keepPlace)
	if frame.UpdateMaximizedSize then
		hooksecurefunc(frame, "UpdateMaximizedSize", fitMonitor)
		frame:HookScript("OnSizeChanged", keepPlace)
		hooksecurefunc(frame, "Minimize", clearFit)
		hooksecurefunc(frame, "SetAlpha", keepOpaque)
		keepMainMonitorVisible(frame)
	end
end

local function adoptSaved()
	for name in pairs(positions) do
		local frame = _G[name]
		if frame then
			adopt(frame)
			restore(frame)
		end
	end
end

local function takesClicks(frame)
	return frame:GetObjectType() ~= "Frame" or frame:GetScript("OnMouseDown") or frame:GetScript("OnMouseUp")
end

local function fillsUI(frame)
	return frame:GetWidth() == UIParent:GetWidth() and frame:GetHeight() == UIParent:GetHeight()
end

local function windowOf(frame)
	local parent = frame:GetParent()
	while parent and not fillsUI(parent) do
		frame = parent
		parent = frame:GetParent()
	end
	return frame
end

local function handlesDrag(focus, window)
	while focus do
		if focus:GetScript("OnDragStart") then
			return true
		end
		if focus == window then
			return false
		end
		focus = focus:GetParent()
	end
	return false
end

local function nearestMonitor(x, y)
	local nearestIndex, shiftX, shiftY, nearest
	for index, monitor in ipairs(layout.monitors) do
		local deltaX = math.min(math.max(x, monitor.x), monitor.x + monitor.width) - x
		local deltaY = math.min(math.max(y, monitor.y), monitor.y + monitor.height - DROP_MARGIN) - y
		local distance = deltaX * deltaX + deltaY * deltaY
		if not nearest or distance < nearest then
			nearestIndex, shiftX, shiftY, nearest = index, deltaX, deltaY, distance
		end
	end
	return nearestIndex, shiftX, shiftY
end

local function canMove(frame)
	local name = frame:GetName()
	local _, explicitlyProtected = frame:IsProtected()
	return name and not (explicitlyProtected and issecurevariable(name)) and not frame.system and not isLocked(frame) and not isMaximized(frame)
end

local function savePosition(frame)
	local left, top = frame:GetLeft(), frame:GetTop()
	local scale = frame:GetEffectiveScale() / screenFrame:GetEffectiveScale()
	local monitor, shiftX, shiftY = nearestMonitor((left + frame:GetWidth() / 2) * scale, layout.height - top * scale)
	local toUI = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local monitorLeft, monitorTop = pointIn(UIParent, monitorFrames[monitor], "TOPLEFT")
	positions[frame:GetName()] = { left = (left + shiftX / scale) * toUI - monitorLeft, top = (top - shiftY / scale) * toUI - monitorTop, monitor = monitor }
	frame:SetUserPlaced(false)
	adopt(frame)
	restore(frame)
end

for _, widgetType in ipairs(MOVABLE_TYPES) do
	local methods = getmetatable(CreateFrame(widgetType)).__index
	hooksecurefunc(methods, "StartMoving", function(frame)
		if not frame:IsForbidden() then
			moveStarts[frame] = { GetCursorPosition() }
		end
	end)
	hooksecurefunc(methods, "StopMovingOrSizing", function(frame)
		local start = moveStarts[frame]
		moveStarts[frame] = nil
		if not start or not spanned then
			return
		end
		local x, y = GetCursorPosition()
		if (x ~= start[1] or y ~= start[2]) and canMove(frame) then
			savePosition(frame)
			return
		end
		local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
		if relativeTo or not point or isLocked(frame) then
			return
		end
		local screenX, screenY = pointIn(frame, screenFrame, relativePoint)
		local uiX, uiY = pointIn(frame, UIParent, relativePoint)
		methods.SetPoint(frame, point, UIParent, relativePoint, offsetX + screenX - uiX, offsetY + screenY - uiY)
	end)
end

local mapSlider = CreateFrame("Frame")

local function startSlide(frame)
	local room = shiftRoom(frame, homeMonitor(frame))
	if room == 0 or isLocked(frame) then
		return
	end
	local startX = GetCursorPosition()
	local startShift = FarsightMultiMonitorDB.mapShift
	mapSlider:SetScript("OnUpdate", function()
		local x = GetCursorPosition()
		FarsightMultiMonitorDB.mapShift = Clamp(startShift + (x - startX) / frame:GetEffectiveScale() / room, -1, 1)
		restore(frame)
	end)
end

local function startScaling(map, grip)
	if not spanned or isLocked(map) then
		return
	end
	if not positions[map:GetName()] then
		savePosition(map)
	end
	local startX, startY = GetCursorPosition()
	local startScale = map:GetScale()
	local width = map:GetWidth() * map:GetEffectiveScale()
	local height = map:GetHeight() * map:GetEffectiveScale()
	grip:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		local growth = ((width + x - startX) * width + (height + startY - y) * height) / (width * width + height * height)
		map:SetScale(Clamp(startScale * growth, MAP_MIN_SCALE, fitScale(map, homeMonitor(map))))
		FarsightMultiMonitorDB.mapScale = map:GetScale()
	end)
end

local function setupMap()
	local map = WorldMapFrame
	adopt(map)
	windowScales[map] = spanned and FarsightMultiMonitorDB.mapScale or 1
	if not isMaximized(map) then
		clearFit(map)
	end
	local grip = CreateFrame("Button", nil, map.BorderFrame)
	grip:SetSize(SCALE_GRIP_SIZE, SCALE_GRIP_SIZE)
	grip:SetPoint("BOTTOMRIGHT", -SCALE_GRIP_INSET, SCALE_GRIP_INSET)
	grip:SetNormalTexture(SCALE_GRIP_TEXTURE .. "-Up")
	grip:SetPushedTexture(SCALE_GRIP_TEXTURE .. "-Down")
	grip:SetHighlightTexture(SCALE_GRIP_TEXTURE .. "-Highlight")
	grip:SetShown(spanned and not isMaximized(map))
	grip:SetScript("OnMouseDown", function()
		startScaling(map, grip)
	end)
	grip:SetScript("OnMouseUp", function()
		if grip:GetScript("OnUpdate") then
			grip:SetScript("OnUpdate", nil)
			savePosition(map)
		end
	end)
	hooksecurefunc(map, "SynchronizeDisplayState", function()
		grip:SetShown(spanned and not isMaximized(map))
	end)
end

local handlers = {}

function handlers.ADDON_LOADED(name)
	if name == addonName then
		FarsightMultiMonitorDB = FarsightMultiMonitorDB or {}
		FarsightMultiMonitorDB[layoutKey] = FarsightMultiMonitorDB[layoutKey] or {}
		positions = FarsightMultiMonitorDB[layoutKey]
		FarsightMultiMonitorDB.mapScale = FarsightMultiMonitorDB.mapScale or 1
		FarsightMultiMonitorDB.mapShift = FarsightMultiMonitorDB.mapShift or 0
		FarsightMultiMonitorDB.gameMonitors = FarsightMultiMonitorDB.gameMonitors or {}
		FarsightMultiMonitorDB.playerCVars = FarsightMultiMonitorDB.playerCVars or {}
		mainIndex = FarsightMultiMonitorDB.gameMonitors[layoutKey] or layout.main
		fullWidth = FarsightMultiMonitorDB.fullWidth or false
		applyViewport()
		EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", setupMap)
	end
	adoptSaved()
end

function handlers.DISPLAY_SIZE_CHANGED()
	applyViewport()
	adoptSaved()
end

handlers.PLAYER_REGEN_ENABLED = applyViewport
handlers.UI_SCALE_CHANGED = applyViewport

function handlers.PLAYER_LOGOUT()
	for name in pairs(SCALED_CVARS) do
		readPlayerCVar(name)
		SetCVar(name, FarsightMultiMonitorDB.playerCVars[name])
	end
end

function handlers.GLOBAL_MOUSE_DOWN(button)
	if not spanned or button ~= "LeftButton" then
		return
	end
	local focus = GetMouseFoci()[1]
	if not focus or focus:IsForbidden() or takesClicks(focus) then
		return
	end
	local frame = windowOf(focus)
	if frame == UIParent then
		return
	end
	if isMaximized(frame) then
		if adopted[frame] then
			startSlide(frame)
		end
		return
	end
	if handlesDrag(focus, frame) or not canMove(frame) then
		return
	end
	adopt(frame)
	dragged = frame
	frame:StartMoving()
end

function handlers.GLOBAL_MOUSE_UP()
	mapSlider:SetScript("OnUpdate", nil)
	if not dragged then
		return
	end
	local frame = dragged
	dragged = nil
	frame:StopMovingOrSizing()
	frame:SetUserPlaced(false)
	restore(frame)
end

local eventFrame = CreateFrame("Frame")
for event in pairs(handlers) do
	eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)

applyViewport()
hooksecurefunc(UIParent, "SetPoint", applyViewport)
CinematicFrame:HookScript("OnHide", applyViewport)

EventUtil.ContinueOnAddOnLoaded("Blizzard_BarbershopUI", function()
	BarberShopFrame:SetAllPoints(UIParent)
end)

hooksecurefunc(InputUtil, "AnchorRegionToCursor", function(region, point)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	region:ClearAllPoints()
	region:SetPoint(point, UIParent, "BOTTOMLEFT", x / scale - UIParent:GetLeft(), y / scale - UIParent:GetBottom())
end)

hooksecurefunc(getmetatable(GameTooltip).__index, "SetOwner", function(tooltip)
	if not spanned or tooltip:IsForbidden() or tooltip:IsMovable() then
		return
	end
	local screenScale = screenFrame:GetEffectiveScale()
	local x, y = GetCursorPosition()
	local monitor = layout.monitors[nearestMonitor(x / screenScale, layout.height - y / screenScale)]
	local scale = screenScale / tooltip:GetEffectiveScale()
	tooltip:SetClampRectInsets(
		-monitor.x * scale,
		(layout.width - monitor.x - monitor.width) * scale,
		monitor.y * scale,
		(monitor.y + monitor.height - layout.height) * scale
	)
end)

hooksecurefunc("ContainerFrameItemButton_CalculateItemTooltipAnchors", function(button, tooltip)
	if not spanned then
		return
	end
	local scale = button:GetEffectiveScale() / screenFrame:GetEffectiveScale()
	local right = button:GetRight() * scale
	local _, centerY = button:GetCenter()
	local monitor = layout.monitors[nearestMonitor(right, layout.height - centerY * scale)]
	tooltip:ClearAllPoints()
	if right < monitor.x + monitor.width / 2 then
		tooltip:SetAnchorType("ANCHOR_RIGHT", 0, 0)
		tooltip:SetPoint("BOTTOMLEFT", button, "TOPRIGHT")
	else
		tooltip:SetAnchorType("ANCHOR_LEFT", 0, 0)
		tooltip:SetPoint("BOTTOMRIGHT", button, "TOPLEFT")
	end
end)

SLASH_FSMRESET1 = "/fsmreset"
SlashCmdList.FSMRESET = function()
	wipe(positions)
	FarsightMultiMonitorDB.mapScale = nil
	FarsightMultiMonitorDB.mapShift = nil
	ReloadUI()
end

function ns.isWidescreen()
	return widened()
end

ns.canWiden = canWiden

function ns.toggleWidescreen()
	fullWidth = not fullWidth
	FarsightMultiMonitorDB.fullWidth = fullWidth
	applyViewport()
end

function ns.gameMonitor()
	return mainIndex
end

function ns.setGameMonitor(index)
	mainIndex = index
	FarsightMultiMonitorDB.gameMonitors[layoutKey] = index
	applyViewport()
end

SLASH_FSMWIDE1 = "/fsmwide"
SlashCmdList.FSMWIDE = ns.toggleWidescreen
