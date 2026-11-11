local addonName, ns = ...

local WINDOW_WIDTH = 720
local PADDING = 24
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 26
local TITLE_HEIGHT = 52
local BUTTON_AREA_HEIGHT = 58
local APP_CHECK_DELAY = 10

local MESSAGES = {
	tips = table.concat({
		"Your game stays on your main monitor. Your other monitors are free space for panels.",
		"",
		"- Drag a panel by its title bar or any empty spot. It stays where you drop it.",
		"- Drag bags by the bottom edge. The header opens the sorting menu.",
		"- Apps on a side monitor, like a browser or Discord, stay above the game. They cover any panel underneath, so give them their own space.",
		"- The Farsight button on the minimap can stretch the game world across every monitor or move the game to another monitor.",
		"- /fsmreset clears your saved panel positions.",
		"- /fsm shows this window again.",
	}, "\n"),
	oneMonitor = table.concat({
		"Farsight only found one monitor, so there's nowhere to move panels to.",
		"",
		"Plug in another monitor and restart WoW. Farsight sets itself up.",
	}, "\n"),
	noApp = table.concat({
		"Farsight needs its small companion app to use your other monitors, and it isn't running.",
		"",
		"Addons can't move or resize the game window, so the app does that part.",
		"",
		"1. Close WoW.",
		"2. Get the Farsight app from the link on the addon's CurseForge page and run it once.",
		"3. Start WoW as usual. The app starts by itself from then on.",
	}, "\n"),
}

local NO_APP_NOTICE = "|cffffd100Farsight:|r the companion app isn't running, so your game is staying on one monitor. Type /fsm for help."

local function appIsActive()
	return ns.isSpanned and ns.isSpanned()
end

local function currentMessage()
	if not appIsActive() then
		return MESSAGES.noApp
	end
	if #ns.layout.monitors == 1 then
		return MESSAGES.oneMonitor
	end
	return MESSAGES.tips
end

local window, body

local function createWindow()
	window = CreateFrame("Frame", "FarsightMultiMonitorWelcomeFrame", UIParent, "BackdropTemplate")
	window:SetWidth(WINDOW_WIDTH)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:EnableMouse(true)
	window:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	tinsert(UISpecialFrames, window:GetName())

	local title = window:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -PADDING)
	title:SetText("Farsight Multi-Monitor")

	body = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	body:SetPoint("TOPLEFT", PADDING, -TITLE_HEIGHT)
	body:SetWidth(WINDOW_WIDTH - PADDING * 2)
	body:SetJustifyH("LEFT")

	local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	close:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	close:SetPoint("BOTTOM", 0, PADDING)
	close:SetText("Got it")
	close:SetScript("OnClick", function()
		window:Hide()
	end)
end

local function showWindow()
	if not window then
		createWindow()
	end
	body:SetText(currentMessage())
	window:SetHeight(TITLE_HEIGHT + body:GetStringHeight() + BUTTON_AREA_HEIGHT)
	window:Show()
end

local function greet()
	if not appIsActive() then
		print(NO_APP_NOTICE)
	end
	if not FarsightMultiMonitorDB.welcomed then
		FarsightMultiMonitorDB.welcomed = true
		showWindow()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name == addonName then
			FarsightMultiMonitorDB = FarsightMultiMonitorDB or {}
			self:UnregisterEvent(event)
		end
		return
	end
	self:UnregisterEvent(event)
	C_Timer.After(APP_CHECK_DELAY, greet)
end)

SLASH_FSM1 = "/fsm"
SlashCmdList.FSM = showWindow
