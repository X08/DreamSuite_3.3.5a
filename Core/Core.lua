------------------------------------------------------------
-- DreamSuite - Core
-- module registry, enable/disable, saved variables, versions,
-- peer version gossip, legacy-addon detection, slash commands
------------------------------------------------------------
DreamSuite = DreamSuite or {}
local DS = DreamSuite

DS.VERSION  = "0.10.27.25"
DS.PREFIX   = "DREAMSUITE"
DS.ICONS    = "Interface\\AddOns\\DreamSuite\\Icons\\"
DS.REPO     = "https://github.com/X08/DreamSuite_3.3.5a"
DS.DOWNLOAD = DS.REPO .. "/archive/refs/heads/main.zip"
DS.WARPERIA = "https://warperia.com/search/all/x08/"

DS.modules = {}      -- in registration (= TOC) order, which is also the order of the hub grid
DS.byId    = {}
DS.pending = {}      -- id -> wanted state, for secure modules toggled during combat
DS.legacyFound = {}  -- folder names of old standalone addons that are still loaded

DS.C = {
    yellow = "|cffffc800", orange = "|cffff7d0a", grey = "|cff888888",
    green  = "|cff33ff66", red    = "|cffff5555", white = "|cffffffff", r = "|r",
}
local C = DS.C

local DEFAULTS = {
    minimap  = { hide = false, angle = 215 },
    enabled  = {},     -- id -> false when the user switched a module off (absent = on)
    data     = {},     -- id -> that module's own settings
    seen     = {},     -- id -> newest version heard from other players
    migrated = {},
    profiles = {},     -- profile name (a character: "Name-Realm") -> saved copy of the settings
    -- live      name of the profile the settings above currently belong to
}

-- per-character data (a module that keeps things per character, like CraftLinker's cached links)
local CHAR_DEFAULTS = { data = {} }   -- plus `profile`: which profile this character uses

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

function DS.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(C.yellow .. "DreamSuite" .. C.r .. ": " .. tostring(msg))
end

------------------------------------------------------------
-- Tiny timer (no C_Timer in 3.3.5a)
------------------------------------------------------------
local timers = {}
local tf = CreateFrame("Frame")
tf:Hide()
tf:SetScript("OnUpdate", function(self, el)
    for i = #timers, 1, -1 do
        local t = timers[i]
        t.left = t.left - el
        if t.left <= 0 then
            table.remove(timers, i)
            t.fn()
        end
    end
    if #timers == 0 then self:Hide() end
end)
function DS.After(delay, fn)
    tinsert(timers, { left = delay, fn = fn })
    tf:Show()
end

------------------------------------------------------------
-- Version: a.b.c.d for the whole package
--   a  0 = unreleased, 1 = released
--   b  major update      c  minor update / small addition
--   d  fix (every fix bumps it; numbers never roll over)
-- Every change is logged in CHANGELOG.md.
------------------------------------------------------------
local function ParseVersion(v)
    if not v then return nil end
    local a, b, c, d = tostring(v):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(c), tonumber(d)
end

-- 1 if a > b, -1 if a < b, 0 if equal, nil if either is unparseable
function DS.CompareVersions(a, b)
    local x, y = { ParseVersion(a) }, { ParseVersion(b) }
    if #x < 4 or #y < 4 then return nil end
    for i = 1, 4 do
        if x[i] ~= y[i] then return x[i] > y[i] and 1 or -1 end
    end
    return 0
end

------------------------------------------------------------
-- Module registry
--
--   DreamSuite.RegisterModule({
--       id       = "GCDDot",              unique, letters/digits/underscore (also the icon name)
--       title    = "GCDDot",
--       desc     = "one line for the tooltip",
--       slash    = { "/gcd", "/gcddot" }, optional; DreamSuite registers them
--       OnSlash  = function(msg) end,
--       OnEnable = function(m) end,       build / register events / show
--       OnDisable= function(m) end,       unregister / hide - must leave the module inert
--       options  = function() return { ... } end,   settings view (see Options.lua)
--       embed    = function(parent, view) return frame end,   alternative: build own settings
--       release  = function(frame) end,   optional, pairs with embed
--       secure   = true,                  toggling is postponed while in combat
--       profileSkip = { chars = true },   keys of the module's account data that are NOT part of a profile
--                                         (collected data such as a cache; everything else is a setting)
--       legacy   = { folder = "GCDDot", db = "GCDDotDB", perChar = false },  old standalone addon
--   })
------------------------------------------------------------
function DS.RegisterModule(m)
    assert(type(m) == "table" and type(m.id) == "string", "DreamSuite.RegisterModule: id is required")
    assert(not DS.byId[m.id], "DreamSuite.RegisterModule: duplicate id " .. m.id)
    m.title   = m.title or m.id
    tinsert(DS.modules, m)
    DS.byId[m.id] = m
    return m
end

function DS.IconPath(m)
    return m.icon or (DS.ICONS .. m.id .. ".tga")
end

function DS.GetDB(id, defaults)
    local d = DreamSuiteDB.data
    d[id] = d[id] or {}
    if defaults then CopyDefaults(defaults, d[id]) end
    return d[id]
end

-- same, but stored per character (DreamSuiteCharDB)
function DS.GetCharDB(id, defaults)
    local d = DreamSuiteCharDB.data
    d[id] = d[id] or {}
    if defaults then CopyDefaults(defaults, d[id]) end
    return d[id]
end

------------------------------------------------------------
-- Profiles
--
-- The settings live in DreamSuiteDB (module data + which modules are enabled). A profile is a saved
-- copy of them, kept in DreamSuiteDB.profiles under a name; every character starts with a profile
-- of its own, named "Name-Realm". A character *uses* one profile (DreamSuiteCharDB.profile), and
-- DreamSuiteDB.live says which profile the live settings belong to. Edits go to the profile in use:
-- they are written back when the profile is left and at logout. Using another profile reloads the UI.
------------------------------------------------------------
local function CharKey() return UnitName("player") .. "-" .. GetRealmName() end
DS.CharKey = CharKey

local function Snapshot()
    local snap = { enabled = DeepCopy(DreamSuiteDB.enabled), data = {} }
    for id, tbl in pairs(DreamSuiteDB.data) do
        local skip = DS.byId[id] and DS.byId[id].profileSkip or {}
        local copy = {}
        for k, v in pairs(tbl) do
            if not skip[k] then copy[k] = DeepCopy(v) end
        end
        snap.data[id] = copy
    end
    return snap
end

-- loads a snapshot into the live tables in place (modules keep their references to them)
local function ApplySnapshot(snap)
    local function Fill(dst, src, skip)
        for k in pairs(dst) do
            if not (skip and skip[k]) then dst[k] = nil end
        end
        for k, v in pairs(src or {}) do
            if not (skip and skip[k]) then dst[k] = DeepCopy(v) end
        end
    end
    Fill(DreamSuiteDB.enabled, snap.enabled)
    local ids = {}
    for id in pairs(DreamSuiteDB.data) do ids[id] = true end
    for id in pairs(snap.data or {}) do ids[id] = true end
    for id in pairs(ids) do
        DreamSuiteDB.data[id] = DreamSuiteDB.data[id] or {}
        Fill(DreamSuiteDB.data[id], (snap.data or {})[id], DS.byId[id] and DS.byId[id].profileSkip)
    end
end

-- write the live settings back into the profile they belong to
function DS.SaveLive()
    if not (DreamSuiteDB and DreamSuiteDB.live) then return end
    DreamSuiteDB.profiles[DreamSuiteDB.live] = Snapshot()
end

-- at login, before the modules start: make the live settings match this character's profile
function DS.SyncProfile()
    local want = DreamSuiteCharDB.profile
    if not want then want = CharKey(); DreamSuiteCharDB.profile = want end
    if not DreamSuiteDB.live then DreamSuiteDB.live = want end          -- first run: today's settings become this profile
    if DreamSuiteDB.live ~= want then
        DS.SaveLive()
        local snap = DreamSuiteDB.profiles[want]
        if snap then ApplySnapshot(snap) else DreamSuiteDB.profiles[want] = Snapshot() end   -- a new character starts from what is live
        DreamSuiteDB.live = want
    end
    if not DreamSuiteDB.profiles[want] then DreamSuiteDB.profiles[want] = Snapshot() end
end

-- name, isOwn
function DS.CurrentProfile()
    local name = DreamSuiteCharDB.profile or CharKey()
    return name, name == CharKey()
end

-- "Name" (the realm only when it is another one)
function DS.ProfileDisplay(name)
    local n, realm = name:match("^(.-)%-(.+)$")
    if not n then return name end
    return realm == GetRealmName() and n or (n .. " (" .. realm .. ")")
end

-- every profile, this character's first, then by name
function DS.ProfileNames()
    local me, cur = CharKey(), DS.CurrentProfile()
    local seen, out = {}, {}
    local function add(n) if n and not seen[n] then seen[n] = true; out[#out + 1] = n end end
    for n in pairs(DreamSuiteDB.profiles) do add(n) end
    add(me); add(cur)
    table.sort(out, function(a, b)
        if (a == me) ~= (b == me) then return a == me end
        return a < b
    end)
    return out
end

-- use another profile (the one in use keeps the current settings); reloads the UI
function DS.UseProfile(name)
    if not name or name == (DS.CurrentProfile()) then return end
    local snap = DreamSuiteDB.profiles[name]
    if not snap then return end
    DS.SaveLive()
    ApplySnapshot(snap)
    DreamSuiteDB.live = name
    DreamSuiteCharDB.profile = name
    DS.Print("now using " .. DS.ProfileDisplay(name) .. "'s profile - reloading.")
    ReloadUI()
end

-- save the current settings as this character's own profile and use that from now on
-- (the profile that was in use before is left as it was last saved)
function DS.SaveProfileHere()
    local me = CharKey()
    DreamSuiteDB.profiles[me] = Snapshot()
    DreamSuiteDB.live = me
    DreamSuiteCharDB.profile = me
    DS.Print("saved the current settings to " .. DS.ProfileDisplay(me) .. "'s profile and now using it.")
end

function DS.HasSettings(m)
    return (m.options ~= nil) or (m.embed ~= nil)
end

------------------------------------------------------------
-- Enable / disable
------------------------------------------------------------
function DS.IsEnabled(m)
    return not (DreamSuiteDB and DreamSuiteDB.enabled[m.id] == false)
end

-- "on" | "off" | "pending" | "conflict" | "error"
function DS.Status(m)
    if m.conflict then return "conflict" end
    if m.error then return "error" end
    if DS.pending[m.id] ~= nil then return "pending" end
    return m.active and "on" or "off"
end

local function Activate(m)
    if m.active or m.conflict then return end
    m.error = nil
    local ok, err = pcall(m.OnEnable or function() end, m)
    if ok then
        m.active = true
    else
        m.error = tostring(err)
        m.active = false
        geterrorhandler()("DreamSuite: " .. m.id .. " failed to start: " .. tostring(err))
    end
end

local function Deactivate(m)
    if not m.active then return end
    local ok, err = pcall(m.OnDisable or function() end, m)
    m.active = false
    if not ok then geterrorhandler()("DreamSuite: " .. m.id .. " did not stop cleanly: " .. tostring(err)) end
end

function DS.SetEnabled(m, on)
    on = on and true or false
    if m.conflict then
        DS.Print(m.title .. ": the old standalone addon is still installed. Type /ds legacy, then /reload.")
        return
    end
    if on then DreamSuiteDB.enabled[m.id] = nil else DreamSuiteDB.enabled[m.id] = false end
    if m.secure and InCombatLockdown() then
        DS.pending[m.id] = on
        DS.Print(m.title .. " will be " .. (on and "enabled" or "disabled") .. " when combat ends.")
    else
        DS.pending[m.id] = nil
        if on then Activate(m) else Deactivate(m) end
    end
    if DS.RefreshAll then DS.RefreshAll() end
end

function DS.Toggle1(m)
    DS.SetEnabled(m, not DS.IsEnabled(m))
end

------------------------------------------------------------
-- Update info: learned from other players (see gossip).
------------------------------------------------------------
function DS.UpdateAvailable()
    local s = DreamSuiteDB and DreamSuiteDB.seen.DreamSuite
    if s and DS.CompareVersions(s, DS.VERSION) == 1 then return true, s end
    return false
end

function DS.GetLinks()
    return {
        { "Direct download", DS.DOWNLOAD },
        { "Warperia", DS.WARPERIA },
        { "GitHub", DS.REPO },
    }
end

------------------------------------------------------------
-- Peer version gossip: players running DreamSuite tell each other their
-- version, so "update available" works without any web access.
------------------------------------------------------------
local lastBroadcast = -60
function DS.Broadcast()
    if GetTime() - lastBroadcast < 60 then return end
    local msg = "V2;" .. DS.VERSION
    lastBroadcast = GetTime()
    if IsInGuild() then SendAddonMessage(DS.PREFIX, msg, "GUILD") end
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(DS.PREFIX, msg, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(DS.PREFIX, msg, "PARTY")
    end
end

local function OnGossip(msg)
    local ver = msg:match("^V2;([%d%.]+)$")
    if not ver or #ver > 24 then return end
    local x = { ParseVersion(ver) }
    if #x < 4 then return end
    for i = 1, 4 do if x[i] > 100000 then return end end
    local seen = DreamSuiteDB.seen.DreamSuite
    if DS.CompareVersions(ver, DS.VERSION) == 1 and (not seen or DS.CompareVersions(ver, seen) == 1) then
        DreamSuiteDB.seen.DreamSuite = ver
        if DS.RefreshAll then DS.RefreshAll() end
    end
end

------------------------------------------------------------
-- Old standalone addons: detect, import their settings once, offer to disable
------------------------------------------------------------
local function DetectLegacy()
    wipe(DS.legacyFound)
    for _, m in ipairs(DS.modules) do
        local lg = m.legacy
        if lg and IsAddOnLoaded(lg.folder) then
            m.conflict = true
            tinsert(DS.legacyFound, lg.folder)
        end
        -- carry the old settings over (only possible while the old addon is still loaded)
        if lg and lg.charDb and type(_G[lg.charDb]) == "table" and DreamSuiteCharDB.data[m.id] == nil then
            DreamSuiteCharDB.data[m.id] = DeepCopy(_G[lg.charDb])      -- a second, per-character variable (InventoryPlus)
        end
        if lg and lg.db and type(_G[lg.db]) == "table" then
            local store = lg.perChar and DreamSuiteCharDB.data or DreamSuiteDB.data
            if store[m.id] == nil then
                store[m.id] = DeepCopy(_G[lg.db])
                DS.Print("imported your " .. m.title .. " settings.")
            end
        end
    end
    if IsAddOnLoaded("X08Hub") then
        DS.hubConflict = true
        tinsert(DS.legacyFound, "X08Hub")
        if not DreamSuiteDB.migrated.hub and type(_G.X08HubDB) == "table" and type(_G.X08HubDB.minimap) == "table" then
            DreamSuiteDB.migrated.hub = true
            DreamSuiteDB.minimap.angle = _G.X08HubDB.minimap.angle or DreamSuiteDB.minimap.angle
            DreamSuiteDB.minimap.hide  = _G.X08HubDB.minimap.hide or false
        end
    end
    if #DS.legacyFound > 0 then
        DS.Print(C.red .. "old standalone addons are still installed: " .. table.concat(DS.legacyFound, ", ") .. C.r ..
                 ". DreamSuite already contains them. Type " .. C.yellow .. "/ds legacy" .. C.r ..
                 " to switch them off, then /reload.")
    end
end

function DS.DisableLegacy()
    if #DS.legacyFound == 0 then
        DS.Print("no old standalone addons found.")
        return
    end
    for _, folder in ipairs(DS.legacyFound) do DisableAddOn(folder) end
    DS.Print("switched off " .. table.concat(DS.legacyFound, ", ") .. ". Type /reload to apply. " ..
             "You can delete those folders from Interface\\AddOns afterwards.")
end

------------------------------------------------------------
-- Slash commands of the modules (registered here so a switched-off module
-- answers politely instead of doing nothing)
------------------------------------------------------------
local function RegisterModuleSlashes()
    for _, m in ipairs(DS.modules) do
        if m.slash and not m.conflict then
            local key = "DREAMSUITE_" .. strupper(m.id)
            for i, s in ipairs(m.slash) do _G["SLASH_" .. key .. i] = s end
            SlashCmdList[key] = function(msg)
                if not m.active then
                    DS.Print(m.title .. " is disabled. Right-click its icon in /ds to enable it.")
                elseif m.OnSlash then
                    m.OnSlash(msg or "")
                end
            end
        end
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
ev:RegisterEvent("RAID_ROSTER_UPDATE")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
    if event == "ADDON_LOADED" then
        if a1 ~= "DreamSuite" then return end
        local fresh = (DreamSuiteDB == nil)
        DreamSuiteDB = DreamSuiteDB or {}
        CopyDefaults(DEFAULTS, DreamSuiteDB)
        if fresh then
            -- a fresh install starts with every module off; the Install Wizard asks for each one
            DS.fresh = true
            for _, m in ipairs(DS.modules) do DreamSuiteDB.enabled[m.id] = false end
        elseif DreamSuiteDB.wizardDone == nil then
            DreamSuiteDB.wizardDone = true                 -- installed before the wizard existed: nothing to ask
        end
        DreamSuiteCharDB = DreamSuiteCharDB or {}
        CopyDefaults(CHAR_DEFAULTS, DreamSuiteCharDB)
    elseif event == "PLAYER_LOGOUT" then
        DS.SaveLive()
    elseif event == "PLAYER_LOGIN" then
        DetectLegacy()
        DS.SyncProfile()
        for _, m in ipairs(DS.modules) do
            if DS.IsEnabled(m) then Activate(m) end
        end
        RegisterModuleSlashes()
        -- /x08 keeps working, unless the old hub is still loaded and owns it
        if not DS.hubConflict then
            SLASH_DREAMSUITEX081 = "/x08"
            SlashCmdList["DREAMSUITEX08"] = SlashCmdList["DREAMSUITE"]
        end
        DS.CreateMinimapButton()
        if DS.RefreshAll then DS.RefreshAll() end
        if DS.fresh and not DreamSuiteDB.wizardDone and DS.ShowWizard then DS.After(3, DS.ShowWizard) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        for id, want in pairs(DS.pending) do
            local m = DS.byId[id]
            DS.pending[id] = nil
            if m then
                if want then Activate(m) else Deactivate(m) end
            end
        end
        if DS.RefreshAll then DS.RefreshAll() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DS.After(20, DS.Broadcast)
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        DS.After(5, DS.Broadcast)
    elseif event == "CHAT_MSG_ADDON" then
        if a1 == DS.PREFIX and a4 ~= UnitName("player") then OnGossip(a2 or "") end
    end
end)

------------------------------------------------------------
-- Slash: /ds  (/dreamsuite; /x08 is added at login, see above)
------------------------------------------------------------
SLASH_DREAMSUITE1 = "/ds"
SLASH_DREAMSUITE2 = "/dreamsuite"
SlashCmdList["DREAMSUITE"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "minimap" then
        DreamSuiteDB.minimap.hide = not DreamSuiteDB.minimap.hide
        DS.CreateMinimapButton()
        DS.UpdateMinimapVisibility()
        DS.Print("minimap button " .. (DreamSuiteDB.minimap.hide and "hidden" or "shown"))
    elseif cmd == "legacy" then
        DS.DisableLegacy()
    elseif cmd == "memory" or cmd == "mem" then
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            DS.Print(string.format("DreamSuite uses %.0f KB of memory (Lua total %.0f KB)", GetAddOnMemoryUsage("DreamSuite"), collectgarbage("count")))
        end
    elseif cmd == "wizard" or cmd == "setup" then
        DS.ShowWizard()
    elseif cmd == "list" then
        for _, m in ipairs(DS.modules) do
            local st = DS.Status(m)
            DS.Print(m.id .. " - " .. (st == "on" and "enabled" or st == "off" and "disabled" or st))
        end
    elseif cmd == "on" or cmd == "off" or cmd == "enable" or cmd == "disable" then
        local target
        for _, m in ipairs(DS.modules) do
            if strlower(m.id) == arg then target = m end
        end
        if target then DS.SetEnabled(target, cmd == "on" or cmd == "enable")
        else DS.Print("usage: /ds " .. cmd .. " <module>   (/ds list shows the names)") end
    elseif cmd == "help" then
        DS.Print("DreamSuite " .. DS.VERSION .. "   /ds - open the hub   /ds list   /ds enable|disable <module>   /ds minimap   /ds legacy   /ds wizard")
    else
        DS.Toggle()
    end
end
