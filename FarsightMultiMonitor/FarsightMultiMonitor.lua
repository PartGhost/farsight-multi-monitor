local addonName, ns = ...

local layout = ns.layout
if not layout then
	return
end

local SIDE_TEXTURE = "Interface\\FrameGeneral\\UI-Background-Marble"
local DROP_MARGIN = 40
local PARKED_FRAMES = { "CompactRaidFrameManager" }

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
for index, monitor in ipairs(layout.monitors) do
	monitorKeys[index] = string.format("%dx%d+%d+%d", monitor.width, monitor.height, monitor.x, monitor.y)
	local monitorFrame = CreateFrame("Frame", nil, screenFrame)
	monitorFrame:SetPoint("TOPLEFT", monitor.x, -monitor.y)
	monitorFrame:SetSize(monitor.width, monitor.height)
	monitorFrames[index] = monitorFrame
	if index ~= layout.main then
		local background = sideFrame:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints(monitorFrame)
		background:SetTexture(SIDE_TEXTURE, "REPEAT", "REPEAT")
		background:SetHorizTile(true)
		background:SetVertTile(true)
	end
end
local layoutKey = table.concat(monitorKeys, " ")
local mainMonitor = layout.monitors[layout.main]

local spanned = false
local fullWidth = false
local positions
local adopted = {}
local restoring = false
local dragged, dragX, dragY
local baseScale, appliedScale

function ns.isSpanned()
	return spanned
end

local function applyScale(ratio)
	local current = UIParent:GetScale()
	if current ~= appliedScale then
		baseScale = current
	end
	UIParent:SetScale(baseScale * ratio)
	appliedScale = UIParent:GetScale()
end

local function applyViewport()
	local width, height = GetPhysicalScreenSize()
	spanned = width == layout.width and height == layout.height
	local onMain = spanned and not fullWidth
	sideFrame:SetShown(onMain)
	if InCombatLockdown() then
		return
	end
	local viewport = onMain and monitorFrames[layout.main] or screenFrame
	WorldFrame:ClearAllPoints()
	WorldFrame:SetAllPoints(viewport)
	UIParent:ClearAllPoints()
	UIParent:SetAllPoints(viewport)
	applyScale(onMain and mainMonitor.height / layout.height or 1)
	for _, name in ipairs(PARKED_FRAMES) do
		local parked = _G[name]
		if parked then
			parked:SetParent(clipFrame)
		end
	end
end

local function isLocked(frame)
	return InCombatLockdown() and frame:IsProtected()
end

local function isMaximized(frame)
	return frame.IsMaximized and frame:IsMaximized()
end

local function restore(frame)
	local position = positions[frame:GetName()]
	if not spanned or not position or restoring or isLocked(frame) then
		return
	end
	restoring = true
	frame:ClearAllPoints()
	if isMaximized(frame) then
		frame:SetPoint("CENTER", monitorFrames[position.monitor])
	else
		frame:SetPoint("TOPLEFT", screenFrame, "BOTTOMLEFT", position.left, position.top)
	end
	restoring = false
end

local function fitMonitor(frame)
	local position = positions[frame:GetName()]
	if not spanned or not position or not isMaximized(frame) or isLocked(frame) then
		return
	end
	local monitorFrame = monitorFrames[position.monitor]
	local scale = monitorFrame:GetEffectiveScale() / frame:GetEffectiveScale()
	local width, height = frame:GetSize()
	local fit = math.min(monitorFrame:GetWidth() * scale / width, monitorFrame:GetHeight() * scale / height)
	frame:SetSize(width * fit, height * fit)
	frame:OnFrameSizeChanged()
	frame.BlackoutFrame:SetShown(position.monitor == layout.main)
	restore(frame)
end

local function adopt(frame)
	if adopted[frame] then
		return
	end
	adopted[frame] = true
	frame:SetMovable(true)
	hooksecurefunc(frame, "SetPoint", restore)
	if frame.UpdateMaximizedSize then
		hooksecurefunc(frame, "UpdateMaximizedSize", fitMonitor)
		hooksecurefunc(frame, "Maximize", fitMonitor)
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

local function windowOf(frame)
	local parent = frame:GetParent()
	while parent and parent ~= UIParent do
		frame = parent
		parent = frame:GetParent()
	end
	return frame
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

local handlers = {}

function handlers.ADDON_LOADED(name)
	if name == addonName then
		FarsightMultiMonitorDB = FarsightMultiMonitorDB or {}
		FarsightMultiMonitorDB[layoutKey] = FarsightMultiMonitorDB[layoutKey] or {}
		positions = FarsightMultiMonitorDB[layoutKey]
		fullWidth = layout.split and FarsightMultiMonitorDB.fullWidth or false
		applyViewport()
	end
	adoptSaved()
end

function handlers.DISPLAY_SIZE_CHANGED()
	applyViewport()
	adoptSaved()
end

handlers.PLAYER_ENTERING_WORLD = applyViewport
handlers.PLAYER_REGEN_ENABLED = applyViewport
handlers.UI_SCALE_CHANGED = applyViewport

function handlers.GLOBAL_MOUSE_DOWN(button)
	if not spanned or button ~= "LeftButton" then
		return
	end
	local focus = GetMouseFoci()[1]
	if not focus or takesClicks(focus) then
		return
	end
	local frame = windowOf(focus)
	if frame == UIParent or not frame:GetName() then
		return
	end
	local _, explicitlyProtected = frame:IsProtected()
	if explicitlyProtected or isLocked(frame) or isMaximized(frame) then
		return
	end
	adopt(frame)
	dragged = frame
	dragX, dragY = GetCursorPosition()
	frame:StartMoving()
end

function handlers.GLOBAL_MOUSE_UP()
	if not dragged then
		return
	end
	local frame = dragged
	dragged = nil
	frame:StopMovingOrSizing()
	frame:SetUserPlaced(false)
	local x, y = GetCursorPosition()
	if x ~= dragX or y ~= dragY then
		local left, top = frame:GetLeft(), frame:GetTop()
		local scale = frame:GetEffectiveScale() / screenFrame:GetEffectiveScale()
		local monitor, shiftX, shiftY = nearestMonitor((left + frame:GetWidth() / 2) * scale, layout.height - top * scale)
		positions[frame:GetName()] = { left = left + shiftX / scale, top = top - shiftY / scale, monitor = monitor }
	end
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

SLASH_FSMRESET1 = "/fsmreset"
SlashCmdList.FSMRESET = function()
	wipe(positions)
	ReloadUI()
end

SLASH_FSMSPLIT1 = "/fsmsplit"
SlashCmdList.FSMSPLIT = function()
	if layout.split then
		FarsightMultiMonitorDB.fullWidth = not FarsightMultiMonitorDB.fullWidth
		ReloadUI()
	end
end
