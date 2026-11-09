-- FadeOut (DreamSuite module)
-- Fades chosen UI elements out of combat, back in on combat or mouseover.
--
-- DreamSuite port: the settings window now lives in the hub (/fadeout opens it).
-- While the module is on, its API is published as the global `FadeOut`, exactly
-- like the standalone addon did, so other modules (OrbMeter) can find it.
-- Switching the module off stops the poller, cancels running fades and puts
-- every faded frame back to full opacity.
local DS = DreamSuite

local M = DS.RegisterModule({
    id      = "FadeOut",
    title   = "FadeOut",
    desc    = "Fades chosen UI elements out of combat, back in on demand",
    slash   = { "/fadeout" },
    legacy  = { folder = "FadeOut", db = "FadeOutDB" },
})

local addon = {}
M.api = addon

-- ===================== Tunables =====================

addon.DEFAULT_FADE_ALPHA = 0.25   -- default idle opacity (0-1)
addon.DEFAULT_EXIT_DELAY = 1.0    -- default seconds to wait after combat ends
addon.MAX_EXIT_DELAY     = 20     -- upper bound offered on the delay slider
addon.FADE_OUT_TIME      = 3      -- seconds, out-of-combat fade
addon.FADE_IN_TIME       = 0.2    -- seconds, combat/mouseover fade
addon.REFRESH_FADE_TIME  = 0.15   -- seconds, quick re-fade when a slider is dragged
local POLL_INTERVAL      = 0.15   -- how often to check mouseover, in seconds

-- ===================== Trackable frames =====================
-- key       : internal id, used for saved settings
-- label     : shown in the settings
-- frameName : global frame name to fade

addon.trackable = {
    { key = "mainbar",        label = "Main Action Bar",   frameName = "MainMenuBar" },
    { key = "bottomleftbar",  label = "Bottom Left Bar",   frameName = "MultiBarBottomLeft" },
    { key = "bottomrightbar", label = "Bottom Right Bar",  frameName = "MultiBarBottomRight" },
    { key = "rightbar",       label = "Right Bar",         frameName = "MultiBarRight" },
    { key = "rightbar2",      label = "Right Bar 2",       frameName = "MultiBarLeft" },
    { key = "petbar",         label = "Pet Action Bar",    frameName = "PetActionBarFrame" },
    { key = "stancebar",      label = "Stance Bar",        frameName = "StanceBarFrame" },
    { key = "bags",           label = "Backpack Button",   frameName = "MainMenuBarBackpackButton" },
    { key = "minimap",        label = "Minimap",           frameName = "Minimap" },
    { key = "chat",           label = "Chat Frame",        frameName = "ChatFrame1" },
    { key = "playerframe",    label = "Player Frame",      frameName = "PlayerFrame" },
    { key = "targetframe",    label = "Target Frame",      frameName = "TargetFrame" },
    { key = "partyframe",     label = "Party Frame",       frameName = "PartyMemberFrame1" },
    { key = "buffs",          label = "Buffs",             frameName = "BuffFrame" },
    { key = "durability",     label = "Durability Frame",  frameName = "DurabilityFrame" },
    { key = "watchframe",     label = "Quest Tracker",     frameName = "WatchFrame" },
}

-- runtime[key] = { frame = <frame ref>, state = "in" | "out" | nil }
addon.runtime = {}

local inCombat = false
local combatExitTimer = nil -- countdown in seconds, nil == not counting down
local mainFrame
local db

-- ===================== Saved variables =====================

local defaults = {
    fadeAlpha = addon.DEFAULT_FADE_ALPHA,
    exitDelay = addon.DEFAULT_EXIT_DELAY,
    enabled = {},          -- [key] = false when a frame is switched off (absent = on)
}

local function GetDB()
    if not db then db = DS.GetDB("FadeOut", defaults) end
    return db
end

local function IsEnabled(key)
    local d = GetDB()
    if d.enabled[key] == nil then
        return true -- default: on
    end
    return d.enabled[key]
end

local function SetEnabled(key, val)
    GetDB().enabled[key] = val
end

-- ===================== Mouseover detection =====================

-- Walks up from whatever is directly under the cursor to see if it is
-- (or is nested inside) the given frame. This is what lets hovering over
-- a button on an action bar correctly count as hovering the bar itself.
local function IsMouseOverFrame(frame)
    local focus = GetMouseFocus()
    while focus do
        if focus == frame then
            return true
        end
        local ok, parent = pcall(focus.GetParent, focus)
        if not ok or not parent then break end
        focus = parent
    end
    return false
end

-- ===================== Fade application =====================

local function ApplyState(entry, desiredIn)
    local frame = entry.frame
    if not frame then return end

    if desiredIn then
        if entry.state ~= "in" then
            entry.state = "in"
            UIFrameFadeIn(frame, addon.FADE_IN_TIME, frame:GetAlpha(), 1)
        end
    else
        if entry.state ~= "out" then
            entry.state = "out"
            UIFrameFadeOut(frame, addon.FADE_OUT_TIME, frame:GetAlpha(), GetDB().fadeAlpha)
        end
    end
end

-- Forces a frame back to fully visible, e.g. right after it's switched off
-- in the settings so it doesn't get stuck half-faded.
local function ResetFrame(key)
    local rt = addon.runtime[key]
    if rt and rt.frame and rt.frame:IsShown() then
        UIFrameFadeIn(rt.frame, addon.FADE_IN_TIME, rt.frame:GetAlpha(), 1)
        rt.state = "in"
    end
end

-- When the idle opacity slider changes, snap any currently-faded frames
-- to the new target quickly instead of waiting for the next state change.
local function RefreshFadedFrames()
    local d = GetDB()
    for _, rt in pairs(addon.runtime) do
        if rt.state == "out" and rt.frame and rt.frame:IsShown() then
            UIFrameFadeOut(rt.frame, addon.REFRESH_FADE_TIME, rt.frame:GetAlpha(), d.fadeAlpha)
        end
    end
end

-- ===================== Main loop =====================

local elapsedSince = 0
local function OnUpdate(self, elapsed)
    -- post-combat delay countdown, ticks every frame for accurate timing
    if combatExitTimer then
        combatExitTimer = combatExitTimer - elapsed
        if combatExitTimer <= 0 then
            combatExitTimer = nil
            inCombat = false
        end
    end

    elapsedSince = elapsedSince + elapsed
    if elapsedSince < POLL_INTERVAL then return end
    elapsedSince = 0

    for _, entry in ipairs(addon.trackable) do
        local rt = addon.runtime[entry.key]
        if rt and rt.frame and IsEnabled(entry.key) then
            -- Respect the game's own visibility choice: if Blizzard (or the
            -- player's bar settings) has this frame hidden, leave it alone.
            -- Fading it in would force it to Show(), overriding that choice.
            if entry.suspend and entry.suspend() then
                rt.state = nil -- the owner (e.g. an unlocked orb) is handling its own alpha
            elseif rt.frame:IsShown() then
                local hovered = IsMouseOverFrame(rt.frame)
                local desiredIn = inCombat or hovered
                ApplyState(rt, desiredIn)
            else
                rt.state = nil -- so it re-initializes cleanly if it reappears
            end
        end
    end
end

-- ===================== Setup =====================

local function InitRuntime()
    local d = GetDB()
    wipe(addon.runtime)
    for _, entry in ipairs(addon.trackable) do
        local frame = entry.frame or _G[entry.frameName]
        if frame then
            addon.runtime[entry.key] = { frame = frame, state = nil }
            if IsEnabled(entry.key) and frame:IsShown() then
                if inCombat then
                    frame:SetAlpha(1)
                    addon.runtime[entry.key].state = "in"
                else
                    frame:SetAlpha(d.fadeAlpha)
                    addon.runtime[entry.key].state = "out"
                end
            end
        end
    end
end

local function OnEvent(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        combatExitTimer = nil -- cancel any pending fade-out
    elseif event == "PLAYER_REGEN_ENABLED" then
        local d = GetDB()
        if d.exitDelay and d.exitDelay > 0 then
            combatExitTimer = d.exitDelay
        else
            inCombat = false
        end
    end
end

-- ===================== Public API (the global `FadeOut` while the module is on) =====================

addon.GetDB = GetDB
addon.IsEnabled = IsEnabled
addon.SetEnabled = SetEnabled
addon.ResetFrame = ResetFrame
addon.RefreshFadedFrames = RefreshFadedFrames

-- Other DreamSuite modules can hand FadeOut a frame of their own (OrbMeter does).
-- Registration is remembered while FadeOut is off and picked up when it switches on.
-- suspend() -> true makes FadeOut leave the frame alone for now.
function addon.Register(key, label, frame, suspend)
    if type(key) ~= "string" or not frame then return end
    addon.Unregister(key)
    tinsert(addon.trackable, { key = key, label = label or key, frame = frame, suspend = suspend, external = true })
    DS.InvalidateOptions(M)
    if M.active then
        local d = GetDB()
        local rt = { frame = frame, state = nil }
        addon.runtime[key] = rt
        if IsEnabled(key) and frame:IsShown() and not (suspend and suspend()) then
            frame:SetAlpha(inCombat and 1 or d.fadeAlpha)
            rt.state = inCombat and "in" or "out"
        end
    end
end

function addon.Unregister(key)
    for i, t in ipairs(addon.trackable) do
        if t.key == key and t.external then
            tremove(addon.trackable, i)
            DS.InvalidateOptions(M)
            break
        end
    end
    addon.runtime[key] = nil
end

-- true while FadeOut owns this frame's opacity
function addon.IsManaged(key)
    return (M.active and addon.runtime[key] and IsEnabled(key)) and true or false
end

-- ===================== Settings view in the hub =====================

M.options = function()
    local list = {
        { type = "tab", label = "General" },
        { type = "text", text = "Checked items fade out of combat." },
        { type = "slider", key = "fadeAlpha", label = "Idle opacity", live = true,
          min = 0, max = 100, step = 1,
          fmt = function(v) return v .. "%" end,
          get = function() return math.floor(GetDB().fadeAlpha * 100 + 0.5) end,
          set = function(v) GetDB().fadeAlpha = v / 100; RefreshFadedFrames() end },
        { type = "slider", key = "exitDelay", label = "Post-combat delay", live = true,
          min = 0, max = addon.MAX_EXIT_DELAY, step = 0.5,
          fmt = function(v) return string.format("%.1fs", v) end,
          lowText = "0s", highText = addon.MAX_EXIT_DELAY .. "s",
          get = function() return GetDB().exitDelay end,
          set = function(v) GetDB().exitDelay = v end },
        { type = "tab", label = "Interface" },
        { type = "header", label = "Fade these elements" },
    }
    local function Entry(t)
        return { type = "bool", key = "fo_" .. t.key, label = t.label,
            get = function() return IsEnabled(t.key) end,
            set = function(v)
                SetEnabled(t.key, v)
                if not v then ResetFrame(t.key) end
            end }
    end
    local ext = {}
    for _, t in ipairs(addon.trackable) do
        if t.external then tinsert(ext, t) else tinsert(list, Entry(t)) end
    end
    -- DreamSuite's own addons live under their own tab
    tinsert(list, { type = "tab", label = "DreamSuite addons" })
    if #ext == 0 then
        tinsert(list, { type = "text", text = "No DreamSuite module has handed FadeOut a frame right now. OrbMeter does once it is switched on." })
    else
        tinsert(list, { type = "header", label = "Fade these DreamSuite addons" })
        for _, t in ipairs(ext) do tinsert(list, Entry(t)) end
    end
    return list
end

-- /fadeout opens the settings in the hub (a second /fadeout closes it again)
function M.OnSlash()
    DS.OpenSettings(M)
end

-- ===================== Enable / disable =====================

function M.OnEnable()
    db = DS.GetDB("FadeOut", defaults)
    if not mainFrame then
        mainFrame = CreateFrame("Frame", "DreamSuiteFadeOutFrame")
        mainFrame:SetScript("OnEvent", OnEvent)
    end
    inCombat = UnitAffectingCombat("player") and true or false
    combatExitTimer = nil
    elapsedSince = 0
    InitRuntime()

    _G.FadeOut = addon
    mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    mainFrame:SetScript("OnUpdate", OnUpdate)
end

function M.OnDisable()
    if mainFrame then
        mainFrame:SetScript("OnUpdate", nil)
        mainFrame:UnregisterAllEvents()
    end
    -- cancel running fades and give everything back at full opacity
    for _, rt in pairs(addon.runtime) do
        if rt.frame then
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(rt.frame) end
            rt.frame:SetAlpha(1)
        end
    end
    wipe(addon.runtime)
    combatExitTimer = nil
    if _G.FadeOut == addon then _G.FadeOut = nil end
end
