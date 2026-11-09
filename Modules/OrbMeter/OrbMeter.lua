--[[
    OrbMeter: visual layer
    Made by X08 | Dreamwind (ChromieCraft-EU).  WoW 3.3.5a, Lua 5.1.

    Two independent visual layers sharing one orb, mirroring GCDDot's
    own dot+ring layering:

    - The core orb (inner circle + number) shows dps or healing,
      whichever mode is currently selected. Mode auto-selects by
      talent-tree majority + stance/form override (see
      RecalculateAutoMode/DetectRole in OrbMeter_core.lua), with
      left-click cycling dps <-> healing manually. Color ramp: blue
      (low relative to group top) -> red for dps, or -> green for
      healing, so red never means "healing a lot," only ever dps or
      threat. Solo play is forced to neutral - see ComputeMeterDisplay
      below for why.

    - The outer ring is an always-on threat gauge, independent of the
      inner orb's mode entirely - shown for anyone with a valid
      target/threat table, not just tanks. It fills clockwise (blue ->
      red) as the player's own threat climbs toward whoever currently
      holds top threat, reaching a full red ring exactly at the point
      of actually pulling aggro - see PollThreatTarget below.

    Hovering the orb shows your top abilities in whichever mode the orb is in
    (damage or healing): the fight in progress, flagged (Current); otherwise
    the last completed fight (Last), or the total since reset (Total) if you
    chose that. The mode follows what you cast: three damage (or three healing)
    spells in a row switch it (/om adaptive turns that off); a left-click pins
    it by hand. Spec and form only set the starting mode, and only out of combat.

    Raid Lead view (off by default, /om raidlead): a second panel that stays
    beside the orb and shows the top 3 and bottom 3 of the group by damage,
    then by healing, switching every 5 seconds, with a "~" row for the players
    in between. Hovering the orb swaps it for the personal overview above.

    Right-click opens a menu: Personal Stats > Damage / Healing prints the
    full breakdown locally (current fight while one is going, then the last
    fight, then total), Report To posts a top-5 Damage Done or Effective
    Healing list (with each member's share of the group) to Say / Party / Raid
    / Guild, Options opens the settings window, and Reset Logs wipes the data.

    Reuses GCDDot's piewheel.tga atlas for its clean anti-aliased
    circular shape (the core orb's fill is held static at 100%, just
    for the shape; the ring's fill is the real dynamic pie-wipe) and
    GCDDot's soft-texture/color pattern for the dim backing circles.
    The atlas ships in this addon's own media folder.

    FadeOut integration (optional): when the FadeOut addon is installed, the
    orb registers with it as "Orb Meter". FadeOut then owns the orb's alpha
    (idle opacity out of combat, full on combat/mouseover, its own
    post-combat delay) and the built-in dim-out-of-combat below stands down.
    Untick it in /fadeout to go back to the built-in behavior. Without
    FadeOut nothing changes.

    Slash commands (/orbmeter or /om) - all of these settings are also in the
    options window (right-click menu > Options, or /om options):
      /om options         open the options window
      /om adaptive [on|off]  the orb follows what you cast (damage <-> healing)
      /om hover last|total   what the hover overview shows
      /om raidlead [on|off]  always-shown top 3 / bottom 3 of the group
      /om unlock          show the border and let you drag the orb
      /om lock            lock it again
      /om size <28-96>    orb size (28 is the default and the minimum)
      /om reset           reset the recorded logs (same as the menu's Reset Logs)
      /om combat          toggle the built-in dimming out of combat
      /om alpha <0-100>   opacity (%) the orb dims to out of combat
      /om maxalpha <10-100>  opacity (%) in combat - the brightest the orb gets
      /om debug           print the tracking core's raw numbers
    combat and alpha only apply while FadeOut is NOT managing the orb.
--]]

--------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------

local DS = DreamSuite
local OM = DS.OrbMeterCore
local M = DS.RegisterModule({
	id      = "OrbMeter",
	title   = "OrbMeter",
	desc    = "A small orb with your damage or healing per second and a threat ring",
	slash   = { "/orbmeter", "/om" },
	legacy  = { folder = "OrbMeter", db = "OrbMeterDB" },
})
local PIE_TEXTURE = "Interface\\AddOns\\DreamSuite\\Modules\\OrbMeter\\media\\piewheel.tga"
local PIE_FRAMES = 64
local PIE_GRID = 8
local SOFT_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local defaults = {
	point = "CENTER",
	relPoint = "CENTER",
	x = 0,
	y = -200,
	size = 28,
	locked = true,
	hideOutOfCombat = true,  -- see UpdateVisibility: this *dims*, it never Hide()s -
	                         -- the right-click menu has to stay reachable out of combat
	outOfCombatAlpha = 0.25,
	maxAlpha = 1.0,          -- opacity in combat (and whenever the orb is not dimmed)
	adaptive = true,         -- orb follows what you cast (damage <-> healing); a left-click pins the mode
	hoverScope = "last",     -- hover overview shows the "last" fight or the "total" since reset
	raidLead = false,        -- Raid Lead view: an always-shown top 3 / bottom 3 of the group
}

local db

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff40d9ffOrbMeter|r: " .. msg)
end

local function SetPieFraction(tex, frac)
	if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
	local idx = math.floor(frac * (PIE_FRAMES - 1) + 0.5)
	local col = idx % PIE_GRID
	local row = math.floor(idx / PIE_GRID)
	local u0, u1 = col / PIE_GRID, (col + 1) / PIE_GRID
	local v0, v1 = row / PIE_GRID, (row + 1) / PIE_GRID
	tex:SetTexCoord(u0, u1, v0, v1)
end

--------------------------------------------------------------------------
-- Frame / visuals
--------------------------------------------------------------------------
-- Button, not Frame: needed for RegisterForClicks/OnClick (left-click mode
-- cycle, right-click menu). Drag-to-move still works the same way on a
-- Button as it does on GCDDot's plain Frame.

-- RING_SCALE mirrors GCDDot's own swing-ring sizing (it used 1.55) -
-- the ring's diameter relative to the core orb's. The clickable frame
-- itself is sized to the ring's extent (not just the core orb), same
-- as GCDDot's frame being sized to its ring, so dragging/clicking
-- works anywhere across the full visual footprint, ring included.
local RING_SCALE = 1.6

local frame = CreateFrame("Button", "OrbMeterFrame", UIParent)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true) -- always on, so clicks register even while locked
frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Threat ring - BACKGROUND layer, so it draws behind the core
-- orb/fill (ARTWORK/OVERLAY below) without needing a separate child
-- frame the way GCDDot used distinct frame levels for its ring vs dot
-- (not needed here since nothing about the ring is independently
-- clickable). ringBase is a faint always-dim backdrop so the ring's
-- position is visible even near 0 fill; ringFill is the actual
-- dynamic pie-wipe, driven every tick by the player's threat ratio.
-- Both stay hidden whenever there's no target/threat table to read.
local ringBase = frame:CreateTexture(nil, "BACKGROUND")
ringBase:SetTexture(SOFT_TEXTURE)
ringBase:SetPoint("CENTER", frame, "CENTER")

local ringFill = frame:CreateTexture(nil, "BACKGROUND", nil, 1) -- sublevel 1: above ringBase, still behind ARTWORK
ringFill:SetTexture(PIE_TEXTURE)
ringFill:SetPoint("CENTER", frame, "CENTER")

-- Hidden until the first OnUpdate tick actually finds a target/threat
-- table to show - avoids a flash of a full/empty ring before that.
ringBase:Hide()
ringFill:Hide()

local core = frame:CreateTexture(nil, "ARTWORK")
core:SetTexture(SOFT_TEXTURE)
core:SetPoint("CENTER", frame, "CENTER")

local fill = frame:CreateTexture(nil, "OVERLAY")
fill:SetTexture(PIE_TEXTURE)
fill:SetPoint("CENTER", frame, "CENTER")
SetPieFraction(fill, 1) -- always a full circle - just reusing the atlas's clean shape

local number = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
number:SetPoint("CENTER", frame, "CENTER")
number:SetJustifyH("CENTER")
number:SetJustifyV("MIDDLE")
number:SetText("")

-- unlocked-mode helper visuals (border + label), hidden while locked
local border = CreateFrame("Frame", nil, frame)
border:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
border:SetBackdrop({
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 8,
})
border:SetBackdropBorderColor(1, 1, 1, 0.6)
border:Hide()

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOM", frame, "TOP", 0, 6)
label:SetText("Orb Meter (drag me)")
label:Hide()

-- Color (cold -> hot lerp, ratio 0..1)
-- The cold/low anchor (GCDDot's base blue) is shared by every mode.
-- The hot/high end differs by mode: red is reserved for dps and
-- threat, so it unambiguously always means "dps/aggro is high" -
-- healing uses green at its hot end instead, so a glance at the color
-- alone (not just the number) tells you which mode you're looking at,
-- and red never means "healing a lot."

local COLOR_LOW = { 0.4, 0.85, 1.0 }   -- GCDDot's base blue - shared cold end
local COLOR_HOT_RED = { 1.0, 0.15, 0.15 }    -- dps / threat hot end
local COLOR_HOT_GREEN = { 0.25, 0.95, 0.35 } -- healing hot end

local function LerpColor(ratio, hotColor)
	hotColor = hotColor or COLOR_HOT_RED
	if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
	local r = COLOR_LOW[1] + (hotColor[1] - COLOR_LOW[1]) * ratio
	local g = COLOR_LOW[2] + (hotColor[2] - COLOR_LOW[2]) * ratio
	local b = COLOR_LOW[3] + (hotColor[3] - COLOR_LOW[3]) * ratio
	return r, g, b
end

local function ApplyRatioColor(ratio, hotColor)
	local r, g, b = LerpColor(ratio, hotColor)
	core:SetVertexColor(r, g, b, 0.35)
	fill:SetVertexColor(r, g, b, 0.95)
end

-- The ring's hot end is always red (threat/aggro, never dps/healing),
-- regardless of whatever mode the inner orb happens to be showing.
local function ApplyRingColor(ratio)
	local r, g, b = LerpColor(ratio, COLOR_HOT_RED)
	ringBase:SetVertexColor(r, g, b, 0.3)
	ringFill:SetVertexColor(r, g, b, 0.9)
end

-- Sizing / position / lock state

-- defaults.size (28) doubles as the floor: the orb can't be sized
-- smaller than its own default, so the text never shrinks past
-- legibility.
local MIN_SIZE = defaults.size
local MAX_SIZE = 96

-- Font path/flags/size are read from the font string's own template
-- (GameFontNormalSmall) once, before any resizing happens, so this is
-- whatever that template actually resolves to (around 10pt) rather
-- than an arbitrary hardcoded number or ratio. baseFontSize anchors
-- the scale: at MIN_SIZE (the default orb size), the font stays
-- exactly what the template gave it originally - it only grows
-- proportionally larger as the orb is sized up beyond that.
local baseFontPath, baseFontSize, baseFontFlags = number:GetFont()
baseFontSize = baseFontSize or 10

local function ApplySize(size)
	size = math.max(MIN_SIZE, math.min(MAX_SIZE, size))
	db.size = size

	-- The clickable frame is sized to the RING's extent (matching
	-- GCDDot's own frame-sized-to-its-ring approach), so the core
	-- orb/fill/number stay at "size" while the frame itself - and the
	-- ring textures - are larger, at size * RING_SCALE.
	local ringSize = size * RING_SCALE
	frame:SetSize(ringSize, ringSize)
	ringBase:SetSize(ringSize, ringSize)
	ringFill:SetSize(ringSize, ringSize)
	core:SetSize(size, size)
	fill:SetSize(size, size)

	local fontSize = math.max(6, math.floor(baseFontSize * (size / MIN_SIZE) + 0.5))
	number:SetFont(baseFontPath or "Fonts\\FRIZQT__.TTF", fontSize, baseFontFlags)
	-- the digit sits a little left of the middle of the font's text box; nudge it right by whole pixels
	-- (anchored on the core, which is the visual centre of the orb), scaled with the font size
	number:ClearAllPoints()
	number:SetPoint("CENTER", core, "CENTER", math.floor(fontSize * 0.1 + 0.5), 0)
end

local function ApplyPosition()
	frame:ClearAllPoints()
	frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

local function ApplyLockState()
	if db.locked then
		frame:RegisterForDrag() -- no drag buttons while locked
		border:Hide()
		label:Hide()
	else
		frame:RegisterForDrag("LeftButton")
		border:Show()
		label:Show()
	end
end

--------------------------------------------------------------------------
-- Logic
--------------------------------------------------------------------------

-- ---- Out-of-combat visibility ----
-- Deliberately NOT a GCDDot-style hard Hide() out of combat: GCDDot is
-- pure display, so vanishing is free. OrbMeter has a right-click
-- report menu you specifically want out of combat (that's when you
-- check what the last pull did) - a Hide()'d frame can't receive
-- clicks at all, so hiding it would make the menu unreachable exactly
-- when you want it most. The frame therefore stays Shown always (which
-- also lets FadeOut animate it).
--
-- Built-in behavior: dim to db.outOfCombatAlpha (still fully clickable -
-- alpha doesn't affect hit-testing in this client) and brighten back to
-- full on mouseover, so it's unobtrusive at rest but easy to find and
-- right-click without ever actually disappearing. Unlocked and in-combat
-- are always full alpha, same as GCDDot's own unlocked/combat behavior.
--
-- FadeOut integration. If the FadeOut addon is loaded, OrbMeter registers
-- its frame with it (it appears as "Orb Meter" in /fadeout) and FadeOut owns
-- the alpha: idle opacity out of combat, full on combat or mouseover, with
-- FadeOut's own post-combat delay. While FadeOut manages the orb, the
-- built-in dim / mouseover / grace logic below stands down. Untick "Orb
-- Meter" in /fadeout, or run without FadeOut, and the built-in behavior
-- takes over again. Same mechanism GCDDot uses.
local FADEOUT_KEY = "orbmeter"
local FADEOUT_LABEL = "Orb Meter"

local function FadeOutApi()
	local fo = DS.byId.FadeOut
	return fo and fo.api
end

local function IsFadeOutManaged()
	local api = FadeOutApi()
	return api and api.IsManaged(FADEOUT_KEY) and true or false
end

local isMouseOver = false

-- Grace period: stays at full alpha for this long after combat ends
-- before it starts dimming, instead of dimming the instant combat
-- drops - gives you a few unobtrusive seconds to glance at what the
-- pull just did before it fades back. Separate from (and shorter than)
-- LAST_FIGHT_LINGER_SECONDS in OrbMeter_core.lua, which controls when
-- the number itself resets to 0 - this only affects visibility.
local OUT_OF_COMBAT_GRACE_SECONDS = 5
local combatEndTime = nil

local function UpdateVisibility()
	frame:Show() -- OrbMeter never Hide()s itself - see note above

	if not db.locked then
		frame:SetAlpha(1) -- always full while unlocked (FadeOut stands down too)
		return
	end

	if IsFadeOutManaged() then
		return -- alpha belongs to FadeOut; never touch it here
	end

	if isMouseOver then
		frame:SetAlpha(1)
		return
	end

	local inCombat = OM.InCombat and OM.InCombat() or false
	local inGrace = (not inCombat) and combatEndTime
		and (GetTime() - combatEndTime) < OUT_OF_COMBAT_GRACE_SECONDS

	if not db.hideOutOfCombat or inCombat or inGrace then
		frame:SetAlpha(db.maxAlpha)
	else
		frame:SetAlpha(math.min(db.outOfCombatAlpha, db.maxAlpha)) -- never brighter than in combat
	end
end

-- ---- Right-click menu ----
-- Personal Stats > Damage | Healing prints your own breakdown locally: the
-- fight in progress (only while one is), then the last completed fight, then
-- the total (totals, share of the group, per-ability numbers).
-- Report To > <channel> > <list> posts a top-5 to chat, ranked by total
-- damage done or effective healing, with each member's share of the group.

local menuFrame = CreateFrame("Frame", "OrbMeterMenuFrame", UIParent, "UIDropDownMenuTemplate")

-- SAY is always valid; PARTY/RAID/GUILD just silently no-op via the
-- client's own chat system if you're not in the relevant group - same as
-- typing /p, /ra, /g yourself with nothing to send it to.
local REPORT_DESTINATIONS = {
	{ text = "Say", channel = "SAY" },
	{ text = "Party", channel = "PARTY" },
	{ text = "Raid", channel = "RAID" },
	{ text = "Guild", channel = "GUILD" },
}

local function ToggleOptions() DS.OpenSettings(M) end -- settings live in the hub

local CURRENT_LISTS = { -- only offered while a fight is going on
	{ text = "Current Fight - Top 5 Damage Done", scope = "current", mode = "damage" },
	{ text = "Current Fight - Top 5 Effective Healing", scope = "current", mode = "healing" },
}

local REPORT_LISTS = {
	{ text = "Last Fight - Top 5 Damage Done", scope = "last", mode = "damage" },
	{ text = "Last Fight - Top 5 Effective Healing", scope = "last", mode = "healing" },
	{ text = "Total - Top 5 Damage Done", scope = "total", mode = "damage" },
	{ text = "Total - Top 5 Effective Healing", scope = "total", mode = "healing" },
}

-- Your own breakdown, printed locally: the last fight first, then the total.
local function PrintPersonalStats(kind)
	local function stats(scope) return OM.GetStatsLines and OM.GetStatsLines(scope, kind) end
	local inFight = OM.InCombat and OM.InCombat()
	local current = inFight and stats("current") or nil
	local last, total = stats("last"), stats("total")
	if not current and not last and not total then
		Print("nothing to report yet.")
		return
	end
	for _, lines in ipairs({ current or false, last or false, total or false }) do
		if lines then
			for i, line in ipairs(lines) do
				-- the first line of each block (Last Fight / Total) is yellow, for structure
				Print(i == 1 and ("|cffffd100" .. line .. "|r") or line)
			end
		end
	end
end

local function PostTopReport(channel, scope, mode)
	local lines = OM.GetTopReportLines and OM.GetTopReportLines(scope, mode, 5)

	if not lines then
		Print("nothing to report yet.")
		return
	end

	for _, line in ipairs(lines) do
		SendChatMessage(line, channel)
	end
end

local function IsReportChannel(value)
	for _, dest in ipairs(REPORT_DESTINATIONS) do
		if dest.channel == value then return true end
	end
	return false
end

-- Shown when hovering the menu's version header.
local COMMAND_HELP = table.concat({
	"/om options - settings window",
	"/om lock | unlock - move the orb",
	"/om size <28-96> - orb size",
	"/om adaptive [on|off] - follow your casts",
	"/om raidlead [on|off] - top 3 / bottom 3 of the group",
	"/om hover last|total - what the hover shows",
	"/om combat - dim out of combat",
	"/om alpha <0-100> - opacity when dimmed out of combat",
	"/om maxalpha <10-100> - opacity in combat (the maximum)",
	"/om reset - reset the logs",
	"/om debug - raw tracking numbers",
}, "\n")

local function OrbMeterMenu_Initialize(self, level)
	level = level or 1

	if level == 1 then
		-- Greyed header with the version; hovering it lists the commands.
		local info = UIDropDownMenu_CreateInfo()
		info.notCheckable = true
		info.text = "|cff888888OrbMeter|r"
		info.func = function() end
		info.keepShownOnClick = true -- it is a label: clicking it does nothing
		info.tooltipTitle = "OrbMeter Commands"
		info.tooltipText = COMMAND_HELP
		info.tooltipOnButton = true
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.notCheckable = true

		info.text = "Personal Stats"
		info.hasArrow = true
		info.value = "PERSONAL_STATS"
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.notCheckable = true
		info.text = "Report To"
		info.hasArrow = true
		info.value = "REPORT_TO"
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.notCheckable = true
		info.text = "Options"
		info.func = function() if ToggleOptions then ToggleOptions() end end
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.notCheckable = true
		info.text = "Reset Logs"
		info.func = function()
			if OM.ResetLogs then OM.ResetLogs() end
			Print("logs reset.")
		end
		UIDropDownMenu_AddButton(info, level)

	elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "PERSONAL_STATS" then
		for _, m in ipairs({ { "Damage", "damage" }, { "Healing", "healing" } }) do
			local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.text = m[1]
			info.func = function() PrintPersonalStats(m[2]) end
			UIDropDownMenu_AddButton(info, level)
		end

	elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "REPORT_TO" then
		for _, dest in ipairs(REPORT_DESTINATIONS) do
			local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.text = dest.text
			info.hasArrow = true
			info.value = dest.channel
			UIDropDownMenu_AddButton(info, level)
		end

	elseif level == 3 and IsReportChannel(UIDROPDOWNMENU_MENU_VALUE) then
		-- The channel is resolved here, when the submenu opens, and the
		-- report itself is built at click time (see PostTopReport).
		local channel = UIDROPDOWNMENU_MENU_VALUE
		local lists = REPORT_LISTS
		if OM.InCombat and OM.InCombat() then
			-- the fight in progress is its own entry, so "Last Fight" never means it
			lists = {}
			for _, l in ipairs(CURRENT_LISTS) do table.insert(lists, l) end
			for _, l in ipairs(REPORT_LISTS) do table.insert(lists, l) end
		end
		for _, list in ipairs(lists) do
			local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.text = list.text
			info.func = function()
				PostTopReport(channel, list.scope, list.mode)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end
end

UIDropDownMenu_Initialize(menuFrame, OrbMeterMenu_Initialize, "MENU")

-- ---- Number display (polls the tracking core) ----

-- Once the linger window expires (LAST_FIGHT_LINGER_SECONDS in
-- OrbMeter_core.lua), the number/color don't snap to 0/neutral - they
-- decay there over DECAY_DURATION, eased to start slow and accelerate
-- (quadratic ease-in), so it reads as settling rather than vanishing.
-- Tracked per mode (dps/healing both decay independently) since only
-- one is on screen at a time but either could be mid-decay if you
-- cycle modes right as it happens.
local DECAY_DURATION = 2

local decayState = {
	dps = { active = false, fromValue = 0, fromRatio = 0, startTime = 0, lastValue = 0, lastRatio = 0 },
	healing = { active = false, fromValue = 0, fromRatio = 0, startTime = 0, lastValue = 0, lastRatio = 0 },
}

local function EaseIn(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return t * t
end

-- Color ratio against the group's top value. Solo (no roster tracked) is
-- forced to 0 explicitly - without this guard a solo player is trivially
-- their own top performer and would always read ratio=1 (full red), which
-- is wrong per the agreed solo behavior (plain neutral, no gradient).
local function GroupRatio(value, top)
	if OM.GetRosterCount and OM.GetRosterCount() > 0 and top > 0 then
		return value / top
	end
	return 0
end

-- Shared by dps and healing mode, which are computed identically (live
-- in combat, last-fight snapshot out of combat, decaying to 0/neutral
-- once the linger window passes, color ratio against the group's top
-- value) and only differ in which accessor functions they poll.
local function ComputeMeterDisplay(mode, getCurrentFn, getTopFn, getLastFn, getLastTopFn)
	local state = decayState[mode]
	local value, ratio

	if OM.InCombat and OM.InCombat() then
		state.active = false -- a new fight started - cancel any decay in progress
		local v = getCurrentFn and getCurrentFn() or 0
		local top = getTopFn and getTopFn() or 0
		value = v
		ratio = GroupRatio(v, top)

	elseif OM.IsLastFightExpired and OM.IsLastFightExpired() then
		if not state.active then
			-- Just expired this tick - start the decay from whatever
			-- was actually last on screen (the held last-fight number),
			-- not from some arbitrary value.
			state.active = true
			state.fromValue = state.lastValue or 0
			state.fromRatio = state.lastRatio or 0
			state.startTime = GetTime()
		end

		local t = (DECAY_DURATION > 0) and ((GetTime() - state.startTime) / DECAY_DURATION) or 1
		local eased = EaseIn(t)
		value = state.fromValue * (1 - eased)
		ratio = state.fromRatio * (1 - eased)

		if t >= 1 then
			state.active = false
			value, ratio = 0, 0
		end

	else
		state.active = false
		local v = getLastFn and getLastFn() or 0
		local top = getLastTopFn and getLastTopFn() or 0
		value = v
		ratio = GroupRatio(v, top)
	end

	state.lastValue, state.lastRatio = value, ratio

	local text
	if OM.FormatNumber then
		text = OM.FormatNumber(value)
	else
		text = tostring(math.floor(value))
	end

	return text, ratio
end

-- ---- Threat ring ----
-- Independent of the inner orb's mode entirely - always
-- driven by the player's own threat ratio whenever there's a valid
-- target/threat table to read, hidden otherwise (mirrors GCDDot's
-- swing ring staying hidden until there's something to show).
-- scaledPercent/100 is already clamped to 0..1 inside GetThreatDisplay,
-- so "full ring" lines up exactly with actually holding top threat -
-- there's no further escalation past that; it just holds full red.
--
-- The fill doesn't snap straight to the new value - it eases there
-- (slow-fast-slow, via smoothstep) over THREAT_ANIM_DURATION, so a
-- threat swing reads as a sweep rather than an instant jump. The poll
-- for the real ratio still only happens every UPDATE_INTERVAL (no
-- need to ask the combat log math every frame); the eased render runs
-- every OnUpdate frame underneath that, independent of the throttle.
local THREAT_ANIM_DURATION = 0.35

local threatRingVisible = false  -- true once the ring has shown at least once since last hidden
local threatAnimFrom, threatAnimTo, threatAnimStart = 0, 0, 0

local function SmoothStep(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return t * t * (3 - 2 * t)
end

-- Polled every UPDATE_INTERVAL: reads the real ratio and sets the
-- animation's target, or hides the ring if there's nothing to show.
local function PollThreatTarget()
	-- NOT "X and X()" here - and/or always truncate their operand to a
	-- single value, even when that operand is a function call that
	-- would otherwise return multiple values, so the second return
	-- (ratio) would silently come back nil every time. This was the
	-- actual bug behind the ring never appearing.
	local ratio
	if OM.GetThreatDisplay then
		local _, r = OM.GetThreatDisplay()
		ratio = r
	end

	if not ratio then
		threatRingVisible = false
		ringBase:Hide()
		ringFill:Hide()
		return
	end

	if not threatRingVisible then
		-- First appearance (or returning after being hidden) - snap
		-- straight to it instead of sweeping up from 0, which would
		-- misleadingly read as "threat building from nothing."
		threatAnimFrom, threatAnimTo, threatAnimStart = ratio, ratio, GetTime()
		threatRingVisible = true
		ringBase:Show()
		ringFill:Show()
		return
	end

	local now = GetTime()
	local t = (THREAT_ANIM_DURATION > 0) and ((now - threatAnimStart) / THREAT_ANIM_DURATION) or 1
	local current = threatAnimFrom + (threatAnimTo - threatAnimFrom) * SmoothStep(t)
	threatAnimFrom, threatAnimTo, threatAnimStart = current, ratio, now
end

-- Runs every frame: renders the eased value between threatAnimFrom and
-- threatAnimTo, regardless of the data-poll throttle above.
local function RenderThreatRing()
	if not threatRingVisible then return end

	local t = (THREAT_ANIM_DURATION > 0) and ((GetTime() - threatAnimStart) / THREAT_ANIM_DURATION) or 1
	local displayRatio = threatAnimFrom + (threatAnimTo - threatAnimFrom) * SmoothStep(t)

	SetPieFraction(ringFill, displayRatio)
	ApplyRingColor(displayRatio)
end

--------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------

frame:SetScript("OnDragStart", function(self)
	if not db.locked then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end)

--------------------------------------------------------------------------
-- Hover panel: your top abilities for the last (or current) fight
--------------------------------------------------------------------------
-- Follows the orb's mode (damage or healing). One row per ability: icon,
-- name, a bar showing its share of your output, and "value  share%". Kept to
-- the last fight on purpose - the full breakdown is in the menu.
local PANEL_ROWS = 8
local PANEL_MIN_W = 150  -- the panel is as wide as its content needs, within these limits
local PANEL_MAX_W = 300
local MAX_NAME_W = 150
local ROW_H = 16
local PANEL_PAD = 6
local ICON = 14
local BAR_COLOR = { 0.20, 0.45, 0.90, 0.70 } -- blue: last fight

-- A panel is a dark box with a heading (label + info) and a pool of bar rows.
-- The hover overview and the Raid Lead view are two of these. Rows without an
-- icon (noIcon) start at the left edge.
local function BuildPanel(frameName, rowPrefix, strata, noIcon)
	local p = CreateFrame("Frame", frameName, UIParent)
	p:SetFrameStrata(strata)
	p:SetClampedToScreen(true)
	p:SetWidth(PANEL_MIN_W)
	p:Hide()
	p.iconW = noIcon and 0 or ICON
	p.gap = noIcon and 3 or 5 -- from the icon column to the name

	local bg = p:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(p)
	bg:SetTexture(0, 0, 0, 0.75)

	-- Heading ("Damage Done" / "Effective Healing") in plain outline, same as
	-- the scope and numbers beside it.
	local title = p:CreateFontString(nil, "OVERLAY")
	title:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
	title:SetPoint("TOPLEFT", p, "TOPLEFT", PANEL_PAD, -PANEL_PAD + 1)
	title:SetJustifyH("LEFT")
	local info = p:CreateFontString(nil, "OVERLAY")
	info:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
	info:SetPoint("LEFT", title, "RIGHT", 6, 0)
	info:SetJustifyH("LEFT")
	p.titleLabel = title
	p.titleInfo = info

	p.rows = {}
	for i = 1, PANEL_ROWS do
		local row = CreateFrame("Frame", rowPrefix .. i, p)
		row:SetWidth(PANEL_MIN_W - 2 * PANEL_PAD)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", p, "TOPLEFT", PANEL_PAD, -(PANEL_PAD + 17 + (i - 1) * ROW_H))

		row.bar = row:CreateTexture(nil, "BACKGROUND")
		row.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
		row.bar:SetVertexColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], BAR_COLOR[4])
		row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", noIcon and 0 or ICON + 2, 0)
		row.bar:SetHeight(ROW_H - 2)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(ICON)
		row.icon:SetHeight(ICON)
		row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		if noIcon then row.icon:Hide() end

		row.nameText = row:CreateFontString(nil, "OVERLAY")
		row.nameText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		row.nameText:SetPoint("LEFT", row, "LEFT", p.iconW + p.gap, 0)
		row.nameText:SetJustifyH("LEFT")
		row.nameText:SetHeight(12)

		row.valueText = row:CreateFontString(nil, "OVERLAY")
		row.valueText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		row.valueText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.valueText:SetJustifyH("RIGHT")

		row:Hide()
		p.rows[i] = row
	end
	return p
end

local panel = BuildPanel("OrbMeterPanel", "OrbMeterPanelRow", "TOOLTIP")

-- Opens the panel above the orb when the orb is low on screen, below it otherwise.
local function PlacePanel(p)
	p:ClearAllPoints()
	local _, cy = frame:GetCenter()
	local screenH = UIParent:GetHeight()
	if cy and screenH and cy < screenH / 2 then
		p:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	else
		p:SetPoint("TOP", frame, "BOTTOM", 0, -4)
	end
end

-- Sizes the panel to its content: widest of the title and the rows
-- (icon + name + gap + value), clamped to the limits above. Bars are scaled
-- to whatever width results. Returns the room for a full-length bar.
local function FitPanel(p, shownRows)
	local need = p.titleLabel:GetStringWidth() + 6 + p.titleInfo:GetStringWidth()
	for i = 1, shownRows do
		local row = p.rows[i]
		row.nameText:SetWidth(0) -- unconstrained, so it reports its real width
		local nameW = math.min(row.nameText:GetStringWidth(), MAX_NAME_W)
		row.nameText:SetWidth(nameW)
		need = math.max(need, p.iconW + p.gap + nameW + 14 + row.valueText:GetStringWidth() + 2)
	end
	local w = math.max(PANEL_MIN_W, math.min(PANEL_MAX_W, math.ceil(need) + 2 * PANEL_PAD))
	p:SetWidth(w)
	for i = 1, PANEL_ROWS do p.rows[i]:SetWidth(w - 2 * PANEL_PAD) end
	return w - 2 * PANEL_PAD - p.iconW - (p.iconW > 0 and 2 or 0)
end

-- Which fight the hover overview and the Raid Lead view show: the one in
-- progress (flagged Current) while there is one, else the last completed fight;
-- the Total setting overrides both.
local function ViewScope()
	if db and db.hoverScope == "total" then return "total" end
	if OM.InCombat and OM.InCombat() then return "current" end
	return "last"
end

local SCOPE_TAG = { total = "(Total)", current = "(Current)", last = "(Last)" }

-- Hover overview: your own top abilities in the orb's current mode.
local function RefreshPanel()
	local mode = OM.GetCurrentMode and OM.GetCurrentMode() or "dps"
	local kind = (mode == "healing") and "healing" or "damage"
	local scope = ViewScope()
	local rows, own, duration
	if OM.GetAbilityRows then rows, own, duration = OM.GetAbilityRows(kind, PANEL_ROWS, scope) end

	local scopeName = SCOPE_TAG[scope]
	panel.titleLabel:SetText((kind == "healing") and "Effective Healing" or "Damage Done")
	if not rows then
		panel.titleInfo:SetText(scopeName .. " no data yet")
		for i = 1, PANEL_ROWS do panel.rows[i]:Hide() end
		FitPanel(panel, 0)
		panel:SetHeight(PANEL_PAD * 2 + 17)
		return
	end

	local fmt = OM.FormatNumber or tostring
	panel.titleInfo:SetText(string.format("%s %s - %s %s", scopeName, fmt(own), fmt(own / duration), (kind == "healing") and "HPS" or "DPS"))

	for i = 1, PANEL_ROWS do
		local row, r = panel.rows[i], rows[i]
		if r then
			row.nameText:SetText(r.name)
			row.valueText:SetText(string.format("%s  %.0f%%", fmt(r.value), r.share))
			row.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		end
	end
	local barMax = FitPanel(panel, #rows)
	for i = 1, PANEL_ROWS do
		local row, r = panel.rows[i], rows[i]
		if r then
			row.bar:SetWidth(math.max(1, barMax * r.share / 100))
			row:Show()
		else
			row:Hide()
		end
	end
	panel:SetHeight(PANEL_PAD * 2 + 17 + #rows * ROW_H)
end

local function ShowPanel()
	PlacePanel(panel)
	RefreshPanel()
	panel:Show()
end

--------------------------------------------------------------------------
-- Raid Lead view
--------------------------------------------------------------------------
-- An always-shown panel beside the orb: the top 3 and bottom 3 of the group
-- by damage, then by healing, switching every LEAD_CYCLE seconds. A "~" row
-- stands for the players in between. Hovering the orb swaps it for the usual
-- personal overview until the mouse leaves. Only people who contributed are
-- ranked, so a healer's 0 damage doesn't clutter the bottom of the damage list.

local LEAD_CYCLE = 5   -- seconds per list
local LEAD_EDGE = 3    -- how many to show from each end
local LEAD_SELF_COLOR = { 1, 0.82, 0 }
local LEAD_BAR_SELF = { 0.85, 0.6, 0.1, 0.7 }

local leadPanel = BuildPanel("OrbMeterLeadPanel", "OrbMeterLeadRow", "HIGH", true)
local leadKind = "damage"  -- the list on show; flips every LEAD_CYCLE seconds
local leadTimer = 0

-- The rows to draw for a ranked list: all of it when short, otherwise the
-- top and bottom LEAD_EDGE around a { between = n } marker.
local function LeadSelection(list)
	local out = {}
	if #list <= 2 * LEAD_EDGE then
		for i = 1, #list do out[#out + 1] = list[i] end
		return out
	end
	for i = 1, LEAD_EDGE do out[#out + 1] = list[i] end
	out[#out + 1] = { between = #list - 2 * LEAD_EDGE }
	for i = #list - LEAD_EDGE + 1, #list do out[#out + 1] = list[i] end
	return out
end

local LEAD_OTHER_LIST = 0.5   -- a player also appears in their weaker list from this share of its top
local LEAD_SETTLE = 5          -- seconds a current fight must run before it decides who is a healer

-- Splits the group into the two lists. A player's role is the list where they
-- are relatively stronger (their value as a share of that list's top); they
-- also appear in the other list when they reach LEAD_OTHER_LIST of its top
-- (a real hybrid). Both lists are re-ranked afterwards.
local function SplitByRole(dmg, heal)
	local topD = dmg[1] and dmg[1].value or 0
	local topH = heal[1] and heal[1].value or 0
	local dShare, hShare = {}, {}
	for _, e in ipairs(dmg) do dShare[e.name] = e.value / topD end
	for _, e in ipairs(heal) do hShare[e.name] = e.value / topH end
	local function keep(list, mine, other)
		local out = {}
		for _, e in ipairs(list) do
			local m, o = mine[e.name] or 0, other[e.name] or 0
			if m >= o or m >= LEAD_OTHER_LIST then
				local c = {}
				for k, v in pairs(e) do c[k] = v end
				c.rank = #out + 1
				out[#out + 1] = c
			end
		end
		return out
	end
	return keep(dmg, dShare, hShare), keep(heal, hShare, dShare)
end

local function RefreshLead()
	local scope = ViewScope()
	local lists = {}
	for _, kind in ipairs({ "damage", "healing" }) do
		lists[kind] = OM.GetRanking and OM.GetRanking(scope, kind) or {}
	end
	-- who is a healer is judged on the last fight while the current one is still young
	local roleD, roleH = lists.damage, lists.healing
	if scope == "current" and OM.GetRanking then
		local _, dur = OM.GetRanking("current", "damage")
		if dur < LEAD_SETTLE then
			local ld, lh = OM.GetRanking("last", "damage"), OM.GetRanking("last", "healing")
			if #ld > 0 or #lh > 0 then roleD, roleH = ld, lh end
		end
	end
	local sd, sh = SplitByRole(roleD, roleH)
	local inD, inH = {}, {}
	for _, e in ipairs(sd) do inD[e.name] = true end
	for _, e in ipairs(sh) do inH[e.name] = true end
	for kind, member in pairs({ damage = inD, healing = inH }) do
		local out = {}
		for _, e in ipairs(lists[kind]) do
			-- people unknown to the role split (new this fight) default to being listed
			local known = (roleD ~= lists.damage) and (inD[e.name] ~= nil or inH[e.name] ~= nil) or (roleD == lists.damage)
			if member[e.name] or not known then e.rank = #out + 1; out[#out + 1] = e end
		end
		lists[kind] = out
	end
	-- show the list that is due; fall back to the other when it has nobody
	local kind = leadKind
	if #lists[kind] == 0 then kind = (kind == "damage") and "healing" or "damage" end
	local list = lists[kind]
	local isHealing = (kind == "healing")
	local rate = isHealing and "HPS" or "DPS"

	leadPanel.titleLabel:SetText(isHealing and "Effective Healing" or "Damage Done")
	if #list == 0 then
		leadPanel.titleInfo:SetText(SCOPE_TAG[scope] .. " no data yet")
		for i = 1, PANEL_ROWS do leadPanel.rows[i]:Hide() end
		FitPanel(leadPanel, 0)
		leadPanel:SetHeight(PANEL_PAD * 2 + 17)
		return
	end
	leadPanel.titleInfo:SetText(SCOPE_TAG[scope] .. " Raid")

	local fmt = OM.FormatNumber or tostring
	local sel = LeadSelection(list)
	local top = list[1].value
	for i = 1, PANEL_ROWS do
		local row, r = leadPanel.rows[i], sel[i]
		if r and r.between then
			row.nameText:SetText(string.format("~ ~ ~  %d more  ~ ~ ~", r.between))
			row.nameText:SetTextColor(0.6, 0.6, 0.6)
			row.valueText:SetText("")
		elseif r then
			row.nameText:SetText(string.format("%d. %s", r.rank, r.name))
			local c = r.self and LEAD_SELF_COLOR or { 1, 1, 1 }
			row.nameText:SetTextColor(c[1], c[2], c[3])
			row.valueText:SetText(string.format("%s  %s %s", fmt(r.value), fmt(r.rate), rate))
		end
	end
	local barMax = FitPanel(leadPanel, #sel)
	for i = 1, PANEL_ROWS do
		local row, r = leadPanel.rows[i], sel[i]
		if r and r.between then
			row.bar:Hide()
			row:Show()
		elseif r then
			local bc = r.self and LEAD_BAR_SELF or BAR_COLOR
			row.bar:SetVertexColor(bc[1], bc[2], bc[3], bc[4])
			row.bar:SetWidth(math.max(1, barMax * r.value / top))
			row.bar:Show()
			row:Show()
		else
			row:Hide()
		end
	end
	leadPanel:SetHeight(PANEL_PAD * 2 + 17 + #sel * ROW_H)
end

-- Shows, refreshes or hides the Raid Lead panel: shown only when the setting
-- is on, you are in a group, and the mouse is not on the orb.
local function UpdateLead()
	local grouped = ((GetNumRaidMembers and GetNumRaidMembers() or 0) + (GetNumPartyMembers and GetNumPartyMembers() or 0)) > 0
	if db and db.raidLead and grouped and not isMouseOver then
		PlacePanel(leadPanel)
		RefreshLead()
		leadPanel:Show()
	else
		leadPanel:Hide()
	end
end

frame:SetScript("OnEnter", function(self)
	isMouseOver = true
	UpdateVisibility()
	UpdateLead() -- the Raid Lead view steps aside for the personal overview
	ShowPanel()
end)
frame:SetScript("OnLeave", function(self)
	isMouseOver = false
	UpdateVisibility()
	panel:Hide()
	UpdateLead()
end)

frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		combatEndTime = nil
		UpdateVisibility()
	elseif event == "PLAYER_REGEN_ENABLED" then
		combatEndTime = GetTime()
		UpdateVisibility()
	end
end)

-- Left: mode cycle (dps <-> healing) for the inner orb only - the
-- threat ring isn't part of this cycle, it's always-on
-- Right: the menu above
frame:SetScript("OnClick", function(self, button)
	if button == "LeftButton" then
		if OM.CycleMode then
			local newMode = OM.CycleMode()
			Print("mode: " .. newMode .. " (pinned - /om adaptive makes it follow your casts again)")
		end
	elseif button == "RightButton" then
		ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
	end
end)

local updateAccum = 0
local UPDATE_INTERVAL = 0.2

local function OnUpdateFn(self, elapsed)
	leadTimer = leadTimer + elapsed
	if leadTimer >= LEAD_CYCLE then
		leadTimer = 0
		leadKind = (leadKind == "damage") and "healing" or "damage"
	end
	updateAccum = updateAccum + elapsed
	if updateAccum >= UPDATE_INTERVAL then
		updateAccum = 0

		-- Re-evaluated here (not just on the regen events) so the
		-- OUT_OF_COMBAT_GRACE_SECONDS window actually expires and dims
		-- the orb on its own, without needing a further combat event.
		UpdateVisibility()

		PollThreatTarget()

		if panel:IsShown() then RefreshPanel() end
		UpdateLead()

		local mode = OM.GetCurrentMode and OM.GetCurrentMode() or "dps"

		if mode == "healing" then
			local text, ratio = ComputeMeterDisplay(
				"healing",
				OM.GetCurrentFightHPS, OM.GetTopFightHPS,
				OM.GetLastFightHPS, OM.GetLastFightTopHPS
			)
			number:SetText(text)
			ApplyRatioColor(ratio, COLOR_HOT_GREEN)
		else -- dps
			local text, ratio = ComputeMeterDisplay(
				"dps",
				OM.GetCurrentFightDPS, OM.GetTopFightDPS,
				OM.GetLastFightDPS, OM.GetLastFightTopDPS
			)
			number:SetText(text)
			ApplyRatioColor(ratio)
		end
	end

	RenderThreatRing()
end

--------------------------------------------------------------------------
-- Settings (shared by the slash commands and the options window)
--------------------------------------------------------------------------

local function RefreshOptions()
	if DS.RefreshOptions then DS.RefreshOptions() end
end

local function SetLocked(on)
	db.locked = on and true or false
	ApplyLockState()
	UpdateVisibility()
	RefreshOptions()
end

local function SetDimOutOfCombat(on)
	db.hideOutOfCombat = on and true or false
	UpdateVisibility()
	RefreshOptions()
end

local function SetOutOfCombatAlpha(pct)
	db.outOfCombatAlpha = pct / 100
	UpdateVisibility()
	RefreshOptions()
end

local function SetMaxAlpha(pct)
	db.maxAlpha = pct / 100
	UpdateVisibility()
	RefreshOptions()
end

local function SetOrbSize(n)
	ApplySize(n)
	RefreshOptions()
end

local function SetAdaptiveOption(on)
	db.adaptive = on and true or false
	if OM.SetAdaptive then OM.SetAdaptive(db.adaptive) end
	RefreshOptions()
end

local function SetHoverScope(scope)
	db.hoverScope = (scope == "total") and "total" or "last"
	if panel:IsShown() then RefreshPanel() end
	UpdateLead()
	RefreshOptions()
end

local function SetRaidLead(on)
	db.raidLead = on and true or false
	leadTimer = 0
	UpdateLead()
	RefreshOptions()
end

--------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------

local function SlashHandler(msg)
	msg = msg or ""
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "unlock" then
		SetLocked(false)
		Print("unlocked - drag to move. Type /om lock when done.")
	elseif cmd == "lock" then
		SetLocked(true)
		Print("locked.")
	elseif cmd == "size" then
		local n = tonumber(rest)
		if n then
			SetOrbSize(n)
			Print("size set to " .. db.size .. ".")
		else
			Print("usage: /om size <" .. MIN_SIZE .. "-" .. MAX_SIZE .. ">")
		end
	elseif cmd == "reset" then
		if OM.ResetLogs then OM.ResetLogs() end
		Print("logs reset.")
	elseif cmd == "debug" then
		if OM.DebugString then
			Print(OM.DebugString())
		else
			Print("debug info unavailable - core not loaded?")
		end
	elseif cmd == "combat" then
		SetDimOutOfCombat(not db.hideOutOfCombat)
		Print("dim out of combat: " .. (db.hideOutOfCombat and "ON" or "OFF"))
		if IsFadeOutManaged() then
			Print("FadeOut currently controls the orb's visibility - untick \"" .. FADEOUT_LABEL .. "\" in /fadeout for this setting to apply.")
		end
	elseif cmd == "adaptive" then
		local want
		if rest == "on" then want = true elseif rest == "off" then want = false else want = not db.adaptive end
		SetAdaptiveOption(want)
		Print("adaptive mode: " .. (want and "ON - the orb follows what you cast (a left-click pins it)" or "OFF - mode comes from your spec/form, or your last left-click"))
	elseif cmd == "raidlead" then
		local want
		if rest == "on" then want = true elseif rest == "off" then want = false else want = not db.raidLead end
		SetRaidLead(want)
		Print("Raid Lead view: " .. (want and "ON - top 3 / bottom 3 of the group, damage then healing every 5s (needs a group)" or "OFF"))
	elseif cmd == "hover" then
		if rest == "last" or rest == "total" then
			SetHoverScope(rest)
			Print("hover overview now shows the " .. (rest == "total" and "total since reset" or "last fight") .. ".")
		else
			Print("usage: /om hover last|total  (current: " .. db.hoverScope .. ")")
		end
	elseif cmd == "options" or cmd == "config" then
		ToggleOptions()
	elseif cmd == "maxalpha" then
		local n = tonumber(rest)
		if n and n >= 10 and n <= 100 then
			SetMaxAlpha(n)
			Print("in-combat opacity set to " .. n .. "%.")
			if IsFadeOutManaged() then
				Print("FadeOut currently controls the orb's visibility - untick \"" .. FADEOUT_LABEL .. "\" in /fadeout for this setting to apply.")
			end
		else
			Print("usage: /om maxalpha <10-100>  (current: " .. math.floor(db.maxAlpha * 100 + 0.5) .. "%)")
		end
	elseif cmd == "alpha" then
		local n = tonumber(rest)
		if n and n >= 0 and n <= 100 then
			SetOutOfCombatAlpha(n)
			Print("out-of-combat alpha set to " .. n .. "%.")
			if IsFadeOutManaged() then
				Print("FadeOut currently controls the orb's visibility - use its Idle Opacity slider (/fadeout), or untick \"" .. FADEOUT_LABEL .. "\" there for this setting to apply.")
			end
		else
			Print("usage: /om alpha <0-100>  (current: " .. math.floor(db.outOfCombatAlpha * 100 + 0.5) .. "%)")
		end
	else
		Print("commands: options, unlock, lock, size <n>, reset, debug, combat, adaptive [on|off], raidlead [on|off], hover last|total, alpha <0-100>, maxalpha <10-100>")
	end
end


function M.OnSlash(msg) SlashHandler(msg) end

--------------------------------------------------------------------------
-- Settings view in the hub
--------------------------------------------------------------------------

local function FadeNote()
	local api = FadeOutApi()
	if not (api and DS.byId.FadeOut.active) then return "" end
	if IsFadeOutManaged() then
		return "FadeOut is managing the orb - the dimming settings below are ignored."
	end
	return "FadeOut is on, but Orb Meter is unticked there - the dimming settings below apply."
end

M.options = function()
	local function pct(v) return v .. "%" end
	local function dimOff() return IsFadeOutManaged() end
	return {
		{ type = "bool", key = "locked", label = "Lock position",
		  desc = "Untick to show a border and drag the orb where you want it.",
		  get = function() return db and db.locked end,
		  set = function(v) SetLocked(v) end },
		{ type = "bool", key = "adaptive", label = "Adaptive Tracking (Damage/Healing)",
		  desc = "Three damage spells (or three healing spells) in a row and the orb follows what you cast. Spec and form only set the starting mode.",
		  get = function() return db and db.adaptive end,
		  set = function(v) SetAdaptiveOption(v) end },
		{ type = "bool", key = "raidLead", label = "Raid Lead view (always shown)",
		  desc = "A panel beside the orb with the top 3 and bottom 3 of your group, damage then healing every 5 seconds. Needs a group. Hover the orb for your own abilities.",
		  get = function() return db and db.raidLead end,
		  set = function(v) SetRaidLead(v) end },
		{ type = "choice", key = "hoverScope", label = "Hover overview shows",
		  values = { "last", "total" }, valueLabels = { last = "Last Fight", total = "Total" },
		  get = function() return db and db.hoverScope or "last" end,
		  set = function(v) SetHoverScope(v) end },
		{ type = "slider", key = "size", label = "Orb size", live = true,
		  min = MIN_SIZE, max = MAX_SIZE, step = 1,
		  get = function() return db and db.size or MIN_SIZE end,
		  set = function(v) SetOrbSize(v) end },
		{ type = "tab", label = "Dimming" },
		{ type = "text", text = FadeNote },
		{ type = "bool", key = "hideOutOfCombat", label = "Dim out of combat",
		  get = function() return db and db.hideOutOfCombat end,
		  set = function(v) SetDimOutOfCombat(v) end, disabled = dimOff },
		{ type = "slider", key = "maxAlpha", label = "Opacity in combat", live = true,
		  min = 10, max = 100, step = 5, fmt = pct,
		  get = function() return db and math.floor(db.maxAlpha * 100 + 0.5) or 100 end,
		  set = function(v) SetMaxAlpha(v) end, disabled = dimOff },
		{ type = "slider", key = "outOfCombatAlpha", label = "Opacity out of combat", live = true,
		  min = 0, max = 100, step = 5, fmt = pct,
		  get = function() return db and math.floor(db.outOfCombatAlpha * 100 + 0.5) or 25 end,
		  set = function(v) SetOutOfCombatAlpha(v) end, disabled = dimOff },
		{ type = "tab", label = "Data" },
		{ type = "action", key = "reset", label = "Reset Logs", confirm = true,
		  set = function() OM.ResetLogs(); Print("logs reset.") end },
	}
end

--------------------------------------------------------------------------
-- Enable / disable
--------------------------------------------------------------------------

frame:Hide() -- inert until the module is switched on

function M.OnEnable()
	local firstRun = DreamSuiteDB.data == nil or DreamSuiteDB.data.OrbMeter == nil
	db = DS.GetDB("OrbMeter", defaults)
	if firstRun then
		-- Start unlocked, so the border shows and the orb is easy to find.
		db.locked = false
	end

	OM.SetAdaptive(db.adaptive)
	ApplyPosition()
	ApplySize(db.size)
	ApplyRatioColor(0)
	ApplyLockState()
	combatEndTime, isMouseOver = nil, false
	threatRingVisible = false
	for _, s in pairs(decayState) do s.active = false end

	-- FadeOut link: registered before the first visibility pass so it already
	-- knows whether FadeOut owns the alpha. The suspend callback keeps FadeOut
	-- off the orb while it is unlocked for dragging.
	local api = FadeOutApi()
	if api then
		api.Register(FADEOUT_KEY, FADEOUT_LABEL, frame, function() return not db.locked end)
	end

	OM.Start()
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnUpdate", OnUpdateFn)
	UpdateVisibility()

	if firstRun then
		Print("first start: the orb is unlocked so you can find it (just below the centre of the screen). Drag it where you want it, then lock it in the settings (/om options).")
	end
end

function M.OnDisable()
	frame:UnregisterAllEvents()
	frame:SetScript("OnUpdate", nil)
	OM.Stop()
	local api = FadeOutApi()
	if api then api.Unregister(FADEOUT_KEY) end
	panel:Hide()
	leadPanel:Hide()
	frame:StopMovingOrSizing()
	frame:Hide()
	CloseDropDownMenus()
	isMouseOver = false
end
