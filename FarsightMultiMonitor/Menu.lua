local addonName, ns = ...

local layout = ns.layout
if not layout then
	return
end

local ROOT = "Interface\\AddOns\\FarsightMultiMonitor\\"
local TEX = ROOT .. "Textures\\"
local ICONS = "Interface\\Icons\\"
local MINIMAP_ART = "Interface\\Minimap\\"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT = {
	title = ROOT .. "Fonts\\Cinzel-Bold.ttf",
	body = ROOT .. "Fonts\\Figtree-Regular.ttf",
	strong = ROOT .. "Fonts\\Figtree-SemiBold.ttf",
}

local WIDTH = 280
local HEADER = 44
local PAD = 14
local GAP = 14
local SHEET_PAD = 12
local GROUP_TITLE = 14
local GROUP_GAP = 12
local OPTION_GAP = 6
local LIST = { columns = 1, height = 40, icon = 30 }
local LINK_HEIGHT = 16
local CORNER = 34
local DOCK_X, DOCK_Y = -30, 34
local MINIMAP_RING_OFFSET = 5
local MINIMAP_ANGLE = 240
local DEFAULT_SCALE = 0.9
local SLICE = { [8] = 12, [6] = 10, [4] = 6 }
local WIDESCREEN_ICON = ICONS .. "Ability_Hunter_EagleEye"
local MONITOR_ICON = ICONS .. "INV_Misc_Spyglass_02"

local C = {
	bgTop = { 0.090, 0.086, 0.102 },
	bgBottom = { 0.055, 0.051, 0.063 },
	halo = { 0.078, 0.075, 0.086 },
	plate = { 0.106, 0.098, 0.114 },
	gold = { 0.784, 0.639, 0.353 },
	pale = { 0.914, 0.835, 0.631 },
	cream = { 1, 0.96, 0.88 },
	text = { 0.937, 0.910, 0.855 },
	text2 = { 0.690, 0.663, 0.600 },
	text3 = { 0.443, 0.424, 0.388 },
	black = { 0, 0, 0 },
}
local FACTION = { Horde = { 0.753, 0.224, 0.169 }, Alliance = { 0.231, 0.471, 0.769 } }

local home = FACTION[UnitFactionGroup("player")] or C.gold
local faction = { home[1], home[2], home[3] }

local window
local options = {}

local fontWarmup = CreateFrame("Frame")
fontWarmup:Hide()
for _, path in pairs(FONT) do
	fontWarmup:CreateFontString():SetFont(path, 12, "")
end

local function tracked(str)
	return (str:upper():gsub(" ", "  "):gsub("(%S)", "%1 "):gsub(" $", ""))
end

local function color(t, c, a)
	t:SetVertexColor(c[1], c[2], c[3], a or 1)
	return t
end

local function rgba(c, a)
	return CreateColor(c[1], c[2], c[3], a)
end

local function tex(parent, name, layer, sublevel)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	t:SetTexture(TEX .. name)
	return t
end

local function solid(parent, c, a, layer, sublevel)
	local t = parent:CreateTexture(nil, layer or "BORDER", nil, sublevel)
	t:SetColorTexture(1, 1, 1, 1)
	return color(t, c, a)
end

local function rounded(parent, radius, part, c, a, inset, layer, sublevel)
	local t = tex(parent, "round" .. radius .. "_" .. part, layer or "BORDER", sublevel)
	local m = SLICE[radius]
	t:SetTextureSliceMargins(m, m, m, m)
	t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	t:SetPoint("TOPLEFT", inset or 0, -(inset or 0))
	t:SetPoint("BOTTOMRIGHT", -(inset or 0), inset or 0)
	return color(t, c, a)
end

local function text(parent, font, size, str, c, shadow)
	local s = parent:CreateFontString(nil, "OVERLAY")
	s:SetFont(FONT[font], size, "")
	s:SetText(str)
	s:SetTextColor(c[1], c[2], c[3], 1)
	if shadow then
		s:SetShadowColor(0, 0, 0, 1)
		s:SetShadowOffset(0, -1)
	end
	return s
end

local function setTextColor(s, c)
	s:SetTextColor(c[1], c[2], c[3], 1)
end

local function diamond(parent, size, c, a, layer)
	local t = color(tex(parent, "diamond", layer or "OVERLAY"), c, a)
	t:SetSize(size, size)
	return t
end

local function masked(parent, size, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetSize(size, size)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(t)
	t:AddMaskTexture(mask)
	return t
end

local function option(parent, item, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(size.height)
	b.item = item
	b.fill = rounded(b, 6, "fill", C.cream, 1, 0, "BACKGROUND")
	b.line = rounded(b, 6, "line", C.cream, 0.08)
	b.icon = masked(b, size.icon)
	b.icon:SetPoint("LEFT", 6, 0)
	b.icon:SetTexture(item.picture)
	local ring = color(tex(b, "ring_thin", "OVERLAY"), C.gold, 0.45)
	ring:SetPoint("CENTER", b.icon)
	ring:SetSize(size.icon + 2, size.icon + 2)
	b.label = text(b, "body", size.columns > 1 and 12 or 13, item.name, C.text)
	b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
	b.label:SetPoint("RIGHT", -6, 0)
	b.label:SetJustifyH("LEFT")
	function b.Refresh(self)
		self.selected = item.isSelected()
		self.disabled = item.isDisabled and item.isDisabled()
		self.icon:SetDesaturated(self.disabled)
		self.icon:SetAlpha(self.disabled and 0.45 or 1)
		setTextColor(self.label, self.disabled and C.text3 or C.text)
		if self.disabled then
			self.fill:SetGradient("VERTICAL", rgba(C.cream, 0.01), rgba(C.cream, 0.01))
			color(self.line, C.cream, 0.04)
		elseif self.selected then
			self.fill:SetGradient("VERTICAL", rgba(faction, 0.18), rgba(faction, 0.18))
			color(self.line, faction, 1)
		elseif self:IsMouseOver() then
			self.fill:SetGradient("VERTICAL", rgba(C.gold, 0.16), rgba(C.gold, 0.16))
			color(self.line, C.gold, 1)
		else
			self.fill:SetGradient("VERTICAL", rgba(C.cream, 0.01), rgba(C.cream, 0.04))
			color(self.line, C.cream, 0.08)
		end
	end
	b:SetScript("OnEnter", function(self)
		self:Refresh()
		if self.disabled then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(item.reason, 1, 0.82, 0)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self:Refresh()
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function(self)
		if not self.disabled then
			item.onClick()
			for _, o in ipairs(options) do
				o:Refresh()
			end
		end
	end)
	options[#options + 1] = b
	return b
end

local function link(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(LINK_HEIGHT)
	local s = text(b, "strong", 11, label, C.gold)
	s:SetPoint("LEFT")
	b:SetWidth(s:GetStringWidth())
	b:SetScript("OnEnter", function() setTextColor(s, C.pale) end)
	b:SetScript("OnLeave", function() setTextColor(s, C.gold) end)
	b:SetScript("OnClick", onClick)
	return b
end

local function plate(parent)
	local f = CreateFrame("Frame", nil, parent)
	rounded(f, 6, "fill", C.plate, 0.98, 0, "BACKGROUND")
	local sheen = solid(f, C.cream, 1, "BACKGROUND", 1)
	sheen:SetPoint("TOPLEFT", 1, -1)
	sheen:SetPoint("TOPRIGHT", -1, -1)
	sheen:SetHeight(48)
	sheen:SetGradient("VERTICAL", rgba(C.cream, 0), rgba(C.cream, 0.03))
	rounded(f, 6, "line", C.gold, 0.45)
	return f
end

local function groupTitle(parent, label, c, top)
	local title = text(parent, "strong", 10, tracked(label), c or C.text3)
	title:SetPoint("TOPLEFT", SHEET_PAD, -top)
	local line = solid(parent, C.gold, 1, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("LEFT", title, "RIGHT", 10, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", -SHEET_PAD, 0)
	line:SetGradient("HORIZONTAL", rgba(C.gold, 0.45), rgba(C.gold, 0))
	diamond(parent, 6, C.gold, 1):SetPoint("CENTER", line, "LEFT", 3, 0)
	return top + GROUP_TITLE + 8
end

local function buildHeader(f)
	local sheen = solid(f, C.cream, 1, "BACKGROUND", -3)
	sheen:SetPoint("TOPLEFT", 1, -1)
	sheen:SetPoint("TOPRIGHT", -1, -1)
	sheen:SetHeight(HEADER - 1)
	sheen:SetGradient("VERTICAL", rgba(C.cream, 0), rgba(C.cream, 0.03))

	local rule = solid(f, C.gold, 0.45, "BORDER", 3)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", 1, -HEADER)
	rule:SetPoint("TOPRIGHT", -1, -HEADER)
	diamond(f, 9, C.halo, 1, "OVERLAY"):SetPoint("CENTER", rule)
	local hollow = color(tex(f, "diamond_line", "OVERLAY", 1), C.gold, 0.45)
	hollow:SetSize(9, 9)
	hollow:SetPoint("CENTER", rule)

	local title = text(f, "title", 14, tracked("Far") .. "   |cffc8a35a" .. tracked("Sight") .. "|r", C.text, true)
	title:SetPoint("CENTER", f, "TOP", 0, -HEADER / 2)
	for _, side in ipairs({ -1, 1 }) do
		diamond(f, 6, C.gold, 1):SetPoint("CENTER", title, side < 0 and "LEFT" or "RIGHT", side * 12, 0)
	end

	local close = CreateFrame("Button", nil, f)
	close:SetSize(26, 26)
	close:SetPoint("RIGHT", f, "TOPRIGHT", -12, -HEADER / 2)
	close:SetFrameLevel(f:GetFrameLevel() + 5)
	rounded(close, 4, "fill", C.black, 0.35, 0, "BACKGROUND")
	local closeLine = rounded(close, 4, "line", C.gold, 0.45)
	local cross = text(close, "body", 15, "×", C.text2)
	cross:SetPoint("CENTER", 0, 1)
	close:SetScript("OnEnter", function()
		setTextColor(cross, C.gold)
		color(closeLine, C.gold, 1)
	end)
	close:SetScript("OnLeave", function()
		setTextColor(cross, C.text2)
		color(closeLine, C.gold, 0.45)
	end)
	close:SetScript("OnClick", function() f:Hide() end)
end

local function buildWindow()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(WIDTH, 400)
	f:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", DOCK_X, DOCK_Y)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)

	rounded(f, 8, "fill", C.halo, 0.9, -6, "BACKGROUND", -7)
	rounded(f, 8, "line", C.gold, 0.18, -6, "BACKGROUND", -6)
	rounded(f, 8, "line", C.black, 1, -1, "BACKGROUND", -5)
	local fill = rounded(f, 8, "fill", C.cream, 1, 0, "BACKGROUND", -4)
	fill:SetGradient("VERTICAL", rgba(C.bgBottom, 1), rgba(C.bgTop, 1))
	rounded(f, 8, "line", C.gold, 0.45, 0, "BORDER", 1)
	rounded(f, 8, "line", C.gold, 0.12, 5, "BORDER", 1)

	for _, half in ipairs({ -1, 1 }) do
		local accent = solid(f, C.cream, 1, "OVERLAY", 2)
		accent:SetSize(WIDTH * 0.3, 2)
		accent:SetPoint(half < 0 and "RIGHT" or "LEFT", f, "TOP", 0, 0)
		if half < 0 then
			accent:SetGradient("HORIZONTAL", rgba(faction, 0), rgba(faction, 1))
		else
			accent:SetGradient("HORIZONTAL", rgba(faction, 1), rgba(faction, 0))
		end
	end

	for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
		local t = color(tex(f, "corner", "OVERLAY"), C.gold, 1)
		t:SetSize(CORNER, CORNER)
		local right, bottom = point:find("RIGHT") ~= nil, point:find("BOTTOM") ~= nil
		t:SetPoint(point, right and -6 or 6, bottom and 6 or -6)
		t:SetTexCoord(right and 1 or 0, right and 0 or 1, bottom and 1 or 0, bottom and 0 or 1)
	end

	buildHeader(f)
	f:SetScale(DEFAULT_SCALE)

	f:Hide()
	local escape = CreateFrame("Frame", "FarsightMultiMonitorEscape", UIParent)
	escape:Hide()
	tinsert(UISpecialFrames, escape:GetName())
	escape:SetScript("OnHide", function() f:Hide() end)
	f:SetScript("OnShow", function() escape:Show() end)
	f:SetScript("OnHide", function() escape:Hide() end)
	return f
end

local function addOptions(sheet, items, top)
	for index, item in ipairs(items) do
		local o = option(sheet, item, LIST)
		o:SetPoint("TOPLEFT", SHEET_PAD, -(top + (index - 1) * (LIST.height + OPTION_GAP)))
		o:SetPoint("TOPRIGHT", -SHEET_PAD, -(top + (index - 1) * (LIST.height + OPTION_GAP)))
	end
	return top + #items * LIST.height + (#items - 1) * OPTION_GAP + GROUP_GAP
end

local function buildBody(f)
	local sheet = plate(f)
	sheet:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
	sheet:SetPoint("TOPRIGHT", -PAD, -(HEADER + PAD))

	local top = groupTitle(sheet, "View", nil, SHEET_PAD)
	top = addOptions(sheet, {
		{
			name = "Widescreen",
			picture = WIDESCREEN_ICON,
			isSelected = ns.isWidescreen,
			isDisabled = function() return not ns.canWiden() end,
			reason = "Widescreen works when the game is on your Windows main display.",
			onClick = ns.toggleWidescreen,
		},
	}, top)

	if #layout.monitors > 1 and not layout.split then
		top = groupTitle(sheet, "Game monitor", nil, top)
		local monitors = {}
		for index, monitor in ipairs(layout.monitors) do
			local name = string.format("%d.  %d x %d", index, monitor.width, monitor.height)
			if index == layout.main then
				name = name .. "  " .. rgba(C.text3, 1):WrapTextInColorCode("Windows main")
			end
			monitors[index] = {
				name = name,
				picture = MONITOR_ICON,
				isSelected = function() return ns.gameMonitor() == index end,
				onClick = function() ns.setGameMonitor(index) end,
			}
		end
		top = addOptions(sheet, monitors, top)
	end

	local sheetHeight = top - GROUP_GAP + SHEET_PAD
	sheet:SetHeight(sheetHeight)

	local help = link(f, "Help", SlashCmdList.FSM)
	help:SetPoint("TOPLEFT", sheet, "BOTTOMLEFT", 2, -GAP)

	f:SetHeight(HEADER + PAD + sheetHeight + GAP + LINK_HEIGHT + PAD)
end

local function toggleWindow()
	if not window then
		window = buildWindow()
		buildBody(window)
	end
	window:SetShown(not window:IsShown())
	for _, o in ipairs(options) do
		o:Refresh()
	end
end

local function buildMinimapButton()
	local b = CreateFrame("Button", "FarsightMultiMonitorMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	local background = b:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(MINIMAP_ART .. "UI-Minimap-Background")
	background:SetSize(24, 24)
	background:SetPoint("CENTER", 0, 1)
	local icon = masked(b, 20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture(C_AddOns.GetAddOnMetadata(addonName, "IconTexture"))
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture(MINIMAP_ART .. "MiniMap-TrackingBorder")
	border:SetSize(50, 50)
	border:SetPoint("TOPLEFT")
	b:SetHighlightTexture(MINIMAP_ART .. "UI-Minimap-ZoomButton-Highlight")
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")

	local function place()
		local angle = math.rad(FarsightMultiMonitorDB.minimapAngle or MINIMAP_ANGLE)
		local radius = Minimap:GetWidth() / 2 + MINIMAP_RING_OFFSET
		b:ClearAllPoints()
		b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
	end
	local function follow()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		FarsightMultiMonitorDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
		place()
	end
	b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", follow) end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnClick", toggleWindow)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Farsight Multi-Monitor", 1, 1, 1)
		GameTooltip:AddLine("Click to open. Drag to move around the ring.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Minimap:HookScript("OnSizeChanged", place)
	place()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", buildMinimapButton)
