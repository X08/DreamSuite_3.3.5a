--[[
    GCDDot (DreamSuite module)
    A tiny, movable, resizable dot whose fill is a genuine circular pie-wipe
    (not the square-bounded Cooldown-widget swipe - see note below) tracking
    your GCD clockwise from 12 o'clock, then pulses a single soft/feathered
    glow the instant you're actually free to act again (see the cast/channel
    note below). A thin outer ring around the dot separately tracks your
    melee swing timer the same way. Hidden automatically out of combat
    (while locked) so it doesn't clutter your screen when it isn't relevant.

    GCD detection: spell ID 61304 is a hidden dummy spell Blizzard uses
    internally that is ALWAYS on cooldown for exactly the GCD's duration
    whenever you trigger the GCD, regardless of class/spec. Polling
    GetSpellCooldown(61304) is the standard, addon-safe way to track the GCD.

    Circular fill: the native Cooldown widget (used for action button
    cooldowns) can't be recolored or reshaped on real 3.3.5 - that
    customization (SetSwipeColor/SetSwipeTexture) wasn't added until
    Cataclysm's 4.0, so its default dark swipe always fills its full SQUARE
    footprint, clashing against a circular design. Instead, media\piewheel.tga
    is a hand-generated 64-frame sprite sheet of genuine anti-aliased
    circular pie-fill frames (0% to 100%, clockwise from 12 o'clock); each
    poll tick we just pick the right frame via SetTexCoord based on
    elapsed-time fraction. No Cooldown widget involved at all for either fill.

    Flash timing vs casting: if the GCD finishes while you're still in the
    middle of a cast-time or channeled spell (e.g. a 3s Fireball on a 1.5s
    GCD), flashing right when the GCD ends would be misleading - you can't
    actually act yet. So the flash is held and fired instead the moment the
    cast/channel completes.

    Swing ring: a larger, dimmer copy of the same soft circle sits BEHIND
    the core dot at a lower frame level, so the core dot visually "punches
    a hole" in its middle - what's left showing around the edge reads as a
    thin ring. Its own pie-wipe fill, timed off UnitAttackSpeed() and reset
    whenever a melee swing (SWING_DAMAGE/SWING_MISSED) lands, fills up
    between one auto-attack swing and the next. NOTE: this only tracks your
    main-hand pace - for dual-wielders an off-hand swing will still reset
    it, which isn't perfectly accurate for the off-hand's own timing, but
    keeps things simple for now.

    Slash commands (either /gcddot or /gcd):
        /gcd unlock          - unlock the dot so you can drag it, shows a
                                border and always stays visible while unlocked
        /gcd lock            - lock it back down
        /gcd size <n>        - set the core dot's diameter in pixels (4-64)
        /gcd color <r g b>   - set the core/GCD color, each 0-1
        /gcd classcolor      - toggle using your class's official color instead
                                (from Blizzard's own RAID_CLASS_COLORS table)
        /gcd swing           - toggle the swing timer ring (on by default)
        /gcd swingcolor <r g b> - set the swing ring's color, each 0-1
        /gcd combat          - toggle hiding the dot outside of combat (on by default)
        /gcd reset           - reset everything to defaults
        /gcd test            - fire a preview flash without needing a GCD

    DreamSuite port: the frames are built the first time the module is switched on.
    Switching off unregisters every event, stops the poller and hides the dot.
--]]
local DS = DreamSuite

local M = DS.RegisterModule({
    id      = "GCDDot",
    title   = "GCDDot",
    desc    = "Movable dot that fills with the GCD, plus a swing timer ring",
    slash   = { "/gcddot", "/gcd" },
    legacy  = { folder = "GCDDot", db = "GCDDotDB" },
})

local GCD_SPELL_ID = 61304
local RING_SCALE = 1.55 -- swing ring's diameter relative to the core dot's size

local PIE_TEXTURE = "Interface\\AddOns\\DreamSuite\\Modules\\GCDDot\\media\\piewheel.tga"
local PIE_FRAMES = 64
local PIE_GRID = 8 -- 8x8 grid of frames in the atlas
local SOFT_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

--------------------------------------------------------------------------
-- Defaults / saved variables
--------------------------------------------------------------------------

local defaults = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -150,
    size = 14,
    r = 0.4,
    g = 0.85,
    b = 1.0,
    locked = true,
    hideOutOfCombat = true,
    showSwing = true,
    swingR = 1,
    swingG = 1,
    swingB = 1,
    useClassColor = false,
}

local db
local running = false   -- true between OnEnable and OnDisable

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40d9ffGCDDot|r: " .. msg)
end

--------------------------------------------------------------------------
-- Pie-fill helper
--------------------------------------------------------------------------
-- Picks the correct cell out of the piewheel.tga atlas for a given
-- progress fraction (0 = empty, 1 = full circle), via plain SetTexCoord.

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
-- Frame + visuals (built once, on first enable)
--------------------------------------------------------------------------
-- Layer stack, back to front:
--   ringLayer  (lower frame level) - swingBase (dim marker) + swingPie (fill)
--   dotLayer   (higher frame level) - core (dim marker) + cdPie (fill) + glow

local frame, ringLayer, swingBase, swingPie
local dotLayer, core, cdPie, glow
local border, label
-- the flash is driven by a timer in the poller (not an animation group), so it can never stay stuck on
local flashT
local FLASH_IN, FLASH_OUT = 0.07, 0.42
local castWatcher, swingWatcher, poller

local gcdActive = false
local lastStart = 0
local castEndTime = nil -- set while a cast/channel is in progress that outlasts the GCD
local pendingFlash = false
local hasSwung = false
local swingStart, swingDuration = nil, nil
local elapsedAccum, combatPollAccum = 0, 0
local POLL_INTERVAL = 0.02          -- 50x/sec is plenty to catch the GCD ending cleanly
local COMBAT_POLL_INTERVAL = 0.25   -- self-healing check in case combat events don't fire on some cores

--------------------------------------------------------------------------
-- Sizing / coloring / visibility
--------------------------------------------------------------------------

local function ApplySize(size)
    size = math.max(4, math.min(64, size))
    db.size = size

    local ringSize = size * RING_SCALE
    frame:SetSize(ringSize, ringSize) -- overall footprint = outer ring's extent
    core:SetSize(size, size)
    cdPie:SetSize(size, size)
    glow:SetSize(size * 2.6, size * 2.6)
    swingBase:SetSize(ringSize, ringSize)
    swingPie:SetSize(ringSize, ringSize)
end

local function ApplyColorRaw(r, g, b)
    core:SetVertexColor(r, g, b, 0.35) -- dim always-visible marker
    cdPie:SetVertexColor(r, g, b, 0.95) -- brighter growing fill
    glow:SetVertexColor(r, g, b, 1)
end

local function ApplyColor(r, g, b)
    db.r, db.g, db.b = r, g, b
    db.useClassColor = false -- an explicit manual color opts back out of class-color mode
    ApplyColorRaw(r, g, b)
end

-- RAID_CLASS_COLORS is a long-standing Blizzard FrameXML global mapping the
-- English class token to its official {r,g,b}.
local function GetClassColor()
    local _, classToken = UnitClass("player")
    local c = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if c then
        return c.r, c.g, c.b
    end
    return nil
end

local function ApplyClassColor()
    local r, g, b = GetClassColor()
    if not r then
        Print("couldn't determine your class color - leaving the current color as-is.")
        return
    end
    db.useClassColor = true
    ApplyColorRaw(r, g, b) -- deliberately does NOT touch db.r/g/b, so your last
                            -- manual color is preserved underneath if you turn
                            -- class-color mode back off later
end

local function SetClassColor(on)
    if on then
        ApplyClassColor()
    else
        db.useClassColor = false
        ApplyColorRaw(db.r, db.g, db.b)
    end
end

local function ApplySwingColor(r, g, b)
    db.swingR, db.swingG, db.swingB = r, g, b
    swingBase:SetVertexColor(r, g, b, 0.3)
    swingPie:SetVertexColor(r, g, b, 0.9)
end

local function ApplyPosition()
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

-- FadeOut link: when the FadeOut module is on and "GCD Dot" is ticked in its list, FadeOut owns the
-- dot's opacity (idle opacity out of combat, full in combat). The dot then stays shown and the
-- "Hide out of combat" switch stands down. Untick it in FadeOut and the built-in hiding applies again.
local FADEOUT_KEY = "gcddot"
local FADEOUT_LABEL = "GCD Dot"

local function FadeOutApi()
    local fo = DS.byId.FadeOut
    return fo and fo.api
end

local function IsFadeOutManaged()
    local api = FadeOutApi()
    return api and api.IsManaged(FADEOUT_KEY) and true or false
end

local function UpdateVisibility()
    if not running then
        frame:Hide()
        return
    end
    if not db.locked then
        -- always visible while unlocked, so you can find/drag/size it
        frame:SetAlpha(1)
        frame:Show()
        return
    end
    if IsFadeOutManaged() then
        frame:Show()      -- the alpha belongs to FadeOut
        return
    end
    frame:SetAlpha(1)
    local inCombat = InCombatLockdown and InCombatLockdown() or UnitAffectingCombat("player")
    if not db.hideOutOfCombat or inCombat then
        frame:Show()
    else
        frame:Hide()
    end
end

local function ApplyLockState()
    if db.locked then
        frame:EnableMouse(false)
        border:Hide()
        label:Hide()
    else
        frame:EnableMouse(true)
        border:Show()
        label:Show()
    end
    UpdateVisibility()
end

local function ApplySwingVisibility()
    if db.showSwing and hasSwung then
        ringLayer:Show()
    else
        ringLayer:Hide()
    end
end

local function ResetSwingRing()
    hasSwung = false
    swingStart, swingDuration = nil, nil
    SetPieFraction(swingPie, 0)
    ApplySwingVisibility()
end

local function StartSwingTimer()
    local mainSpeed = UnitAttackSpeed("player")
    if not mainSpeed or mainSpeed <= 0 then return end
    hasSwung = true
    swingStart, swingDuration = GetTime(), mainSpeed
    SetPieFraction(swingPie, 0)
    ApplySwingVisibility()
end

--------------------------------------------------------------------------
-- Flash animation (single pulse of feathered glow)
--------------------------------------------------------------------------

local function Flash()
    glow:SetAlpha(0)
    flashT = 0
end

local function StepFlash(elapsed)
    if not flashT then return end
    flashT = flashT + elapsed
    if flashT >= FLASH_IN + FLASH_OUT then
        flashT = nil
        glow:SetAlpha(0)
    elseif flashT < FLASH_IN then
        glow:SetAlpha(flashT / FLASH_IN)
    else
        glow:SetAlpha(1 - (flashT - FLASH_IN) / FLASH_OUT)
    end
end

--------------------------------------------------------------------------
-- Cast/channel tracking (delay the flash until you can actually act)
--------------------------------------------------------------------------
-- 3.3.5a note: the no-arg CastingInfo()/ChannelInfo() globals do NOT exist
-- on original WotLK - the era-appropriate calls are UnitCastingInfo("player") /
-- UnitChannelInfo("player"), whose return signature still includes a
-- "nameSubtext" field that shifts startTime/endTime to the 5th/6th values.

local function RefreshCastEnd()
    local name, _, _, _, startTime, endTime = UnitCastingInfo("player")
    if name then
        castEndTime = endTime / 1000
        return
    end
    local cName, _, _, _, cStart, cEndTime = UnitChannelInfo("player")
    if cName then
        castEndTime = cEndTime / 1000
        return
    end
    castEndTime = nil
end

local function OnCastEvent(self, event, unit)
    if unit ~= "player" then return end

    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        RefreshCastEnd()
    else
        -- STOP / FAILED / INTERRUPTED / CHANNEL_STOP: whatever was pending
        -- is over one way or another, so this is the moment you're free to
        -- act again - fire the held-back flash now if one was waiting.
        castEndTime = nil
        if pendingFlash then
            pendingFlash = false
            Flash()
        end
    end
end

--------------------------------------------------------------------------
-- Swing timer (thin outer ring)
--------------------------------------------------------------------------
-- Detected the classic way: watch the combat log for a SWING_DAMAGE or
-- SWING_MISSED event whose source is you, then restart a timer for
-- UnitAttackSpeed("player")'s main-hand speed.
--
-- 3.3.5a note: COMBAT_LOG_EVENT_UNFILTERED's payload has varied across
-- patches/backports depending on whether the "hideCaster" field is present,
-- which shifts sourceGUID from argument 3 to argument 4. We check both.

local function OnSwingEvent(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        ResetSwingRing()
        return
    end

    local subevent = select(2, ...)
    if subevent ~= "SWING_DAMAGE" and subevent ~= "SWING_MISSED" then return end

    local a3, a4 = select(3, ...), select(4, ...)
    local playerGUID = UnitGUID("player")
    if a3 == playerGUID or a4 == playerGUID then
        if db.showSwing then
            StartSwingTimer()
        end
    end
end

--------------------------------------------------------------------------
-- GCD polling
--------------------------------------------------------------------------

local function OnPoll(self, elapsed)
    StepFlash(elapsed)
    combatPollAccum = combatPollAccum + elapsed
    if combatPollAccum >= COMBAT_POLL_INTERVAL then
        combatPollAccum = 0
        UpdateVisibility()
    end

    elapsedAccum = elapsedAccum + elapsed
    if elapsedAccum < POLL_INTERVAL then return end
    elapsedAccum = 0

    -- swing ring fill
    if swingStart then
        local frac = (GetTime() - swingStart) / swingDuration
        SetPieFraction(swingPie, frac)
        if frac >= 1 then
            swingStart, swingDuration = nil, nil -- stays full until the next swing resets it
        end
    end

    local start, duration = GetSpellCooldown(GCD_SPELL_ID)
    local active = start and duration and duration > 0

    if active and start ~= lastStart then
        -- a new GCD just started - kick off the pie fill from scratch
        lastStart = start
    end

    if active then
        SetPieFraction(cdPie, (GetTime() - start) / duration)
    end

    if active and not gcdActive then
        gcdActive = true
    elseif gcdActive and not active then
        gcdActive = false
        SetPieFraction(cdPie, 1) -- make sure it lands on "full" exactly
        if castEndTime then
            -- still mid-cast/channel past the GCD - hold the flash until
            -- that finishes instead of firing while you still can't act
            pendingFlash = true
        else
            Flash()
        end
    end
end

--------------------------------------------------------------------------
-- Build (once)
--------------------------------------------------------------------------

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP",
}

local function Build()
    frame = CreateFrame("Frame", "DreamSuiteGCDDotFrame", UIParent)
    frame:SetFrameStrata("BACKGROUND")      -- behind the Blizzard windows
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    local baseLevel = frame:GetFrameLevel()

    -- ring layer (swing timer) - deliberately BELOW the dot layer
    ringLayer = CreateFrame("Frame", nil, frame)
    ringLayer:SetAllPoints(frame)
    ringLayer:SetFrameLevel(baseLevel + 1)

    swingBase = ringLayer:CreateTexture(nil, "ARTWORK")
    swingBase:SetTexture(SOFT_TEXTURE)
    swingBase:SetPoint("CENTER", frame, "CENTER")

    swingPie = ringLayer:CreateTexture(nil, "OVERLAY")
    swingPie:SetTexture(PIE_TEXTURE)
    swingPie:SetPoint("CENTER", frame, "CENTER")
    SetPieFraction(swingPie, 0)

    -- dot layer (core + GCD fill + flash) - explicitly ABOVE the ring layer
    dotLayer = CreateFrame("Frame", nil, frame)
    dotLayer:SetAllPoints(frame)
    dotLayer:SetFrameLevel(baseLevel + 3)

    core = dotLayer:CreateTexture(nil, "ARTWORK")
    core:SetTexture(SOFT_TEXTURE)
    core:SetPoint("CENTER", frame, "CENTER")

    cdPie = dotLayer:CreateTexture(nil, "OVERLAY", nil, 0)
    cdPie:SetTexture(PIE_TEXTURE)
    cdPie:SetPoint("CENTER", frame, "CENTER")
    SetPieFraction(cdPie, 0)

    glow = dotLayer:CreateTexture(nil, "OVERLAY", nil, 1) -- sublevel 1: always above cdPie
    glow:SetTexture(SOFT_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    glow:SetPoint("CENTER", frame, "CENTER")

    -- unlocked-mode helper visuals (border + label), hidden while locked
    border = CreateFrame("Frame", nil, frame)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    border:SetBackdropBorderColor(1, 1, 1, 0.6)
    border:Hide()

    label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", frame, "TOP", 0, 6)
    label:SetText("GCD Dot (drag me)")
    label:Hide()

    -- dragging
    frame:SetScript("OnDragStart", function(self)
        if not db.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    end)

    -- mouse wheel resize while unlocked, for quick adjustment without typing
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if db.locked then return end
        ApplySize(db.size + delta)
    end)

    -- combat visibility
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            UpdateVisibility()
        end
    end)

    castWatcher = CreateFrame("Frame")
    castWatcher:SetScript("OnEvent", OnCastEvent)

    swingWatcher = CreateFrame("Frame")
    swingWatcher:SetScript("OnEvent", OnSwingEvent)

    poller = CreateFrame("Frame")
end

--------------------------------------------------------------------------
-- Settings actions (shared by the slash commands and the hub's settings view)
--------------------------------------------------------------------------

local function SetLocked(v)
    db.locked = v and true or false
    ApplyLockState()
end

local function SetSwing(on)
    db.showSwing = on and true or false
    ApplySwingVisibility()
end

local function SetHideOutOfCombat(on)
    db.hideOutOfCombat = on and true or false
    UpdateVisibility()
end

local function ResetAll()
    for k, v in pairs(defaults) do db[k] = v end
    ApplyPosition()
    ApplySize(db.size)
    ApplyColor(db.r, db.g, db.b)
    ApplySwingColor(db.swingR, db.swingG, db.swingB)
    ResetSwingRing()
    ApplyLockState()
end

--------------------------------------------------------------------------
-- Slash commands (registered by DreamSuite; only reach here while switched on)
--------------------------------------------------------------------------

function M.OnSlash(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "unlock" then
        SetLocked(false)
        Print("unlocked - drag to move, mouse-wheel to resize. Type /gcd lock when done.")
    elseif cmd == "lock" then
        SetLocked(true)
        Print("locked.")
    elseif cmd == "size" then
        local n = tonumber(rest)
        if n then
            ApplySize(n)
            Print("size set to " .. db.size .. ".")
        else
            Print("usage: /gcd size <4-64>")
        end
    elseif cmd == "color" then
        local r, g, b = rest:match("^([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)$")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if r and g and b then
            ApplyColor(r, g, b)
            Print("color updated.")
        else
            Print("usage: /gcd color <r> <g> <b>  (each 0-1)")
        end
    elseif cmd == "classcolor" then
        SetClassColor(not db.useClassColor)
        Print(db.useClassColor and "using your class color." or "class color off - back to your custom color.")
    elseif cmd == "swing" then
        SetSwing(not db.showSwing)
        Print("swing timer ring: " .. (db.showSwing and "ON" or "OFF"))
    elseif cmd == "swingcolor" then
        local r, g, b = rest:match("^([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)$")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if r and g and b then
            ApplySwingColor(r, g, b)
            Print("swing ring color updated.")
        else
            Print("usage: /gcd swingcolor <r> <g> <b>  (each 0-1)")
        end
    elseif cmd == "combat" then
        SetHideOutOfCombat(not db.hideOutOfCombat)
        Print("hide out of combat: " .. (db.hideOutOfCombat and "ON" or "OFF"))
    elseif cmd == "reset" then
        ResetAll()
        Print("reset to defaults.")
    elseif cmd == "test" then
        Flash()
    else
        Print("commands: unlock, lock, size <n>, color <r g b>, classcolor, swing, swingcolor <r g b>, combat, reset, test")
    end
end

--------------------------------------------------------------------------
-- Settings view in the hub
--------------------------------------------------------------------------

local function FadeNote()
    local fo = DS.byId.FadeOut
    if not (FadeOutApi() and fo.active) then return "" end
    if IsFadeOutManaged() then
        return "FadeOut is managing the dot - \"Hide out of combat\" is ignored. Set its opacity in FadeOut."
    end
    return "FadeOut is on, but GCD Dot is unticked there - \"Hide out of combat\" applies."
end

M.options = function()
    return {
        { type = "bool", key = "lock", label = "Lock position",
          desc = "Untick to drag the dot where you want it; the mouse wheel resizes it.",
          get = function() return db.locked end,
          set = function(v) SetLocked(v) end },
        { type = "slider", key = "size", label = "Dot size", min = 4, max = 64, step = 1, live = true,
          fmt = function(v) return v .. " px" end,
          get = function() return db.size end,
          set = function(v) ApplySize(v) end },
        { type = "text", text = FadeNote },
        { type = "bool", key = "combat", label = "Hide out of combat",
          disabled = function() return IsFadeOutManaged() end,
          get = function() return db.hideOutOfCombat end,
          set = function(v) SetHideOutOfCombat(v) end },
        { type = "tab", label = "Colours" },
        { type = "bool", key = "classcolor", label = "Use my class colour",
          get = function() return db.useClassColor end,
          set = function(v) SetClassColor(v) end },
        { type = "color", key = "color", label = "GCD dot colour",
          disabled = function() return db.useClassColor end,
          get = function() return db.r, db.g, db.b end,
          set = function(r, g, b) ApplyColor(r, g, b) end },
        { type = "tab", label = "Swing timer" },
        { type = "bool", key = "swing", label = "Show swing ring",
          get = function() return db.showSwing end,
          set = function(v) SetSwing(v) end },
        { type = "color", key = "swingcolor", label = "Swing ring colour",
          disabled = function() return not db.showSwing end,
          get = function() return db.swingR, db.swingG, db.swingB end,
          set = function(r, g, b) ApplySwingColor(r, g, b) end },
        { type = "tab", label = "Other" },
        { type = "action", key = "test", label = "Preview flash",
          desc = "Fires the GCD-ready flash.",
          set = function() Flash() end },
        { type = "action", key = "reset", label = "Reset to defaults", confirm = true,
          set = function() ResetAll() end },
    }
end

--------------------------------------------------------------------------
-- Enable / disable
--------------------------------------------------------------------------

function M.OnEnable()
    db = DS.GetDB("GCDDot", defaults)
    if not frame then Build() end

    ApplyPosition()
    ApplySize(db.size)
    if db.useClassColor then
        ApplyClassColor() -- re-derive from THIS character's class, since the
                           -- saved color is account-wide and shared across alts
    else
        ApplyColorRaw(db.r, db.g, db.b)
    end
    ApplySwingColor(db.swingR, db.swingG, db.swingB)
    ApplySwingVisibility() -- ring stays hidden until the first swing lands

    flashT = nil                 -- nothing flashes when the dot starts up
    glow:SetAlpha(0)
    running = true
    local api = FadeOutApi()
    if api then api.Register(FADEOUT_KEY, FADEOUT_LABEL, frame, function() return not db.locked end) end
    ApplyLockState()

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, e in ipairs(CAST_EVENTS) do castWatcher:RegisterEvent(e) end
    swingWatcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    swingWatcher:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat: reset for next time
    elapsedAccum, combatPollAccum = 0, 0
    poller:SetScript("OnUpdate", OnPoll)
end

function M.OnDisable()
    running = false
    local api = FadeOutApi()
    if api then api.Unregister(FADEOUT_KEY) end
    if not frame then return end
    poller:SetScript("OnUpdate", nil)
    frame:UnregisterAllEvents()
    castWatcher:UnregisterAllEvents()
    swingWatcher:UnregisterAllEvents()
    flashT = nil
    glow:SetAlpha(0)
    gcdActive, pendingFlash, castEndTime = false, false, nil
    ResetSwingRing()
    frame:EnableMouse(false)
    frame:Hide()
end
