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
local WORLD_TEXT_CVAR = "WorldTextScale_v2"

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

function ns.isSpanned()
	return spanned
end

local function mainMonitorScale()
	if GetCVarBool("useUiScale") then
		return tonumber(GetCVar("uiScale"))
	end
	return math.min(1, math.max(MIN_AUTO_SCALE, UI_HEIGHT / mainMonitor.height))
end

local function applyWorldTextScale(onMain)
	local saved = FarsightMultiMonitorDB
	if not saved then
		return
	end
	local current = GetCVar(WORLD_TEXT_CVAR)
	if current ~= saved.appliedWorldText and current ~= saved.playerWorldText then
		saved.playerWorldText = current
	end
	local windowRatio = onMain and math.max(layout.width / mainMonitor.width, layout.height / mainMonitor.height) or 1
	SetCVar(WORLD_TEXT_CVAR, tonumber(saved.playerWorldText) / windowRatio)
	saved.appliedWorldText = GetCVar(WORLD_TEXT_CVAR)
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
	if onMain then
		UIParent:SetScale(mainMonitorScale() * mainMonitor.height / layout.height)
	end
	applyWorldTextScale(onMain)
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
	if not spanned or not position or isLocked(frame) then
		return
	end
	local monitorFrame = monitorFrames[position.monitor]
	local scale = monitorFrame:GetEffectiveScale() / frame:GetParent():GetEffectiveScale()
	local width, height = frame:GetSize()
	frame:SetScale(math.min(monitorFrame:GetWidth() * scale / width, monitorFrame:GetHeight() * scale / height))
	restore(frame)
end

local function clearFit(frame)
	if isLocked(frame) then
		return
	end
	frame:SetScale(1)
	restore(frame)
end

local function onSideMonitor(frame)
	local position = positions[frame:GetName()]
	return spanned and position and position.monitor ~= layout.main
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
	if frame.UpdateMaximizedSize then
		hooksecurefunc(frame, "UpdateMaximizedSize", fitMonitor)
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

function handlers.PLAYER_LOGOUT()
	SetCVar(WORLD_TEXT_CVAR, FarsightMultiMonitorDB.playerWorldText)
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
	if frame == UIParent or not frame:GetName() then
		return
	end
	local _, explicitlyProtected = frame:IsProtected()
	if explicitlyProtected or frame.system or isLocked(frame) or isMaximized(frame) then
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

hooksecurefunc(InputUtil, "AnchorRegionToCursor", function(region, point)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	region:ClearAllPoints()
	region:SetPoint(point, UIParent, "BOTTOMLEFT", x / scale - UIParent:GetLeft(), y / scale - UIParent:GetBottom())
end)

hooksecurefunc(getmetatable(GameTooltip).__index, "SetOwner", function(tooltip)
	if not spanned or fullWidth or tooltip:IsForbidden() or tooltip:IsMovable() then
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
