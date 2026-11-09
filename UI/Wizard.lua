------------------------------------------------------------
-- DreamSuite - Install Wizard
--
-- Runs once on a fresh install (every module starts switched off), and again whenever you type
-- /ds wizard. One page per module: what it does, a small live showcase, and an Enable / No thanks choice.
-- A choice is applied at once (DS.SetEnabled), so the wizard can be left at any moment.
--
--   DS.ShowWizard()   open it (marks the first run as done)
--   DS.WizardDemos    [moduleId] = function(box) ... end   builds the showcase inside `box` (520 x 150)
------------------------------------------------------------
local DS = DreamSuite
local UI = DS.UI

local W, H = 580, 440
local BOX_W, BOX_H = 520, 150
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local PIE = "Interface\\AddOns\\DreamSuite\\Modules\\GCDDot\\media\\piewheel.tga"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICON = "Interface\\Icons\\"

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- what each module page says besides the module's own one-line description
local INFO = {
    URLify = {
        "Web addresses in chat become links you can click.",
        "Clicking one opens a small box with the address selected, ready to copy.",
        "Only the display changes; the message itself is never touched.",
    },
    BulkBag = {
        "Select several items and move them to another bag in one go.",
        "Works in your bags, the bank and the guild bank.",
        "A BB button on the backpack switches it on, so Ctrl+click can keep previewing items.",
    },
    CraftLinker = {
        "Someone whispers \"craft\" and gets your profession links back.",
        "Whisper an item or recipe you can make and it answers with the materials, what you carry, and what your other characters hold.",
        "Learns your recipes whenever you open a profession window.",
    },
    GCDDot = {
        "A small dot that fills while your global cooldown runs and glows when you are free to act.",
        "A thin ring around it follows your melee swing timer.",
        "Movable and resizable; it stays out of the way out of combat.",
    },
    FadeOut = {
        "Fades chosen parts of your interface out when you are not in combat.",
        "They come back when you fight, target something, or hover them.",
        "Also drives the dimming of GCDDot and OrbMeter.",
    },
    OrbMeter = {
        "A small orb with your damage or healing per second.",
        "A ring around it shows your threat.",
        "Follows what you cast, and can post the top damage and healing of your group.",
    },
    RarityBorders = {
        "Item borders in the colour of their quality, in bags, bank and character frame.",
        "Optional sparkles, comet trails and a shimmer for the best items.",
        "Items you cannot use get a red tint.",
    },
    InventoryPlus = {
        "Tabs on the side of your bags hold one kind of item each. Drag a tab onto another to merge them.",
        "New loot is sent to the right bag, bags sort themselves, loose stacks are merged.",
        "A Warehouse shows what all your characters carry.",
        "A small (!) on your character window hints at an upgrade waiting in your bags.",
    },
}

------------------------------------------------------------
-- small drawing helpers for the showcases
------------------------------------------------------------
local function Text(parent, text, x, y, w, size, r, g, b, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", size or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if w then fs:SetWidth(w) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text or "")
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function Solid(parent, x, y, w, h, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    t:SetWidth(w); t:SetHeight(h)
    t:SetTexture(r, g, b, a or 1)
    return t
end

-- a 2 px frame in a colour, around a w x h area at x, y
local function Border(parent, x, y, w, h, r, g, b, a)
    local e = {}
    e[1] = Solid(parent, x, y, w, 2, r, g, b, a, "OVERLAY")
    e[2] = Solid(parent, x, y + h - 2, w, 2, r, g, b, a, "OVERLAY")
    e[3] = Solid(parent, x, y, 2, h, r, g, b, a, "OVERLAY")
    e[4] = Solid(parent, x + w - 2, y, 2, h, r, g, b, a, "OVERLAY")
    return e
end

local function Icon(parent, name, x, y, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    t:SetWidth(size); t:SetHeight(size)
    t:SetTexture(ICON .. name)
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return t
end

local function Panel(parent, x, y, w, h, a)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetWidth(w); f:SetHeight(h)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, a or 0.55)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    return f
end

local function PieFraction(tex, frac)
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    local idx = math.floor(frac * 63 + 0.5)
    local col, row = idx % 8, math.floor(idx / 8)
    tex:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
end

local QUALITY = {
    { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 },
}
local ITEMS = { "INV_Sword_04", "INV_Shield_04", "INV_Potion_54", "INV_Misc_Gem_01", "INV_Helmet_01",
                "INV_Chest_Cloth_17", "INV_Jewelry_Ring_03", "INV_Misc_Herb_07" }

------------------------------------------------------------
-- showcases
------------------------------------------------------------
local D = {}
DS.WizardDemos = D

D.URLify = function(box)
    Text(box, "Without", 10, 8, 120, "GameFontNormalSmall")
    local a = Panel(box, 10, 26, 245, 112)
    Text(a, "|cffaaaaaa[Guild]|r Bob: have you seen\nwww.wowhead.com/item=2318 ?", 8, 10, 230)
    Text(a, "(you have to type it out manually)", 8, 70, 230, "GameFontDisableSmall")
    Text(box, "With URLify", 265, 8, 120, "GameFontNormalSmall")
    local b = Panel(box, 265, 26, 245, 112)
    Text(b, "|cffaaaaaa[Guild]|r Bob: have you seen\n|cff4da6ff[www.wowhead.com/item=2318]|r ?", 8, 10, 230)
    local pop = Panel(b, 14, 52, 215, 50, 0.9)
    Text(pop, "Copy this link (Ctrl+C):", 8, 8, 200, "GameFontDisableSmall")
    Solid(pop, 8, 24, 197, 18, 0.1, 0.1, 0.1, 1)
    Text(pop, "www.wowhead.com/item=2318", 12, 28, 190, "GameFontHighlightSmall", 1, 1, 0.6)
end

D.BulkBag = function(box)
    local function Grid(x, n)
        local slots = {}
        for i = 1, n do
            local sx, sy = x + ((i - 1) % 4) * 38, 22 + math.floor((i - 1) / 4) * 38
            Solid(box, sx, sy, 34, 34, 0.05, 0.05, 0.05, 0.9)
            slots[i] = { x = sx, y = sy }
        end
        return slots
    end
    local from = Grid(20, 8)
    for i = 1, 8 do
        if i ~= 4 and i ~= 7 then
            Icon(box, ITEMS[i], from[i].x + 1, from[i].y + 1, 32)
            if i == 1 or i == 2 or i == 6 then
                Solid(box, from[i].x, from[i].y, 34, 34, 0.2, 0.6, 1, 0.45, "OVERLAY")
                Border(box, from[i].x, from[i].y, 34, 34, 0.3, 0.7, 1, 1)
            end
        end
    end
    Text(box, "Ctrl+click or drag selects", 20, 106, 160, "GameFontDisableSmall")
    Text(box, ">>", 190, 52, 40, "GameFontNormalLarge", 1, 0.82, 0)
    Text(box, "click an empty slot", 170, 106, 120, "GameFontDisableSmall")
    local to = Grid(250, 8)
    for i = 1, 3 do Icon(box, ITEMS[({ 1, 2, 6 })[i]], to[i].x + 1, to[i].y + 1, 32) end
    -- the BB button, glowing the way it does in the game
    local btn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    btn:SetWidth(34); btn:SetHeight(18)
    btn:SetPoint("TOPLEFT", box, "TOPLEFT", 430, -40)
    btn:SetText("BB")
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT", 3, -3); glow:SetPoint("BOTTOMRIGHT", -3, 3)
    glow:SetTexture(1, 0.62, 0.05, 1)
    glow:SetBlendMode("ADD")
    local t = 0
    box:SetScript("OnUpdate", function(_, e)
        t = t + e
        glow:SetAlpha(0.8 * 0.5 * (1 - math.cos(t * 3.2)))
    end)
    Text(box, "The BB button\nturns it on", 410, 66, 90, "GameFontDisableSmall", nil, nil, nil, "CENTER")
end

D.CraftLinker = function(box)
    local p = Panel(box, 10, 6, 500, 138, 0.6)
    local w = { 1, 0.5, 1 }
    local lines = {
        "|cffff80ffBob whispers:|r craft",
        "|cffff80ffTo Bob:|r [CraftLinker] My crafting professions:",
        "|cffff80ffTo Bob:|r |cffffd000[Alchemy]|r   |cffffd000[Tailoring]|r",
        "|cffff80ffBob whispers:|r |cff1eff00[Flask of Pure Mojo]|r",
        "|cffff80ffTo Bob:|r [CraftLinker] 3x |cffffffff[Icethorn]|r - have 7;  1x |cffffffff[Crystal Vial]|r - have 0 (alts: Tim 12)",
    }
    for i, l in ipairs(lines) do Text(p, l, 8, 8 + (i - 1) * 24, 484) end
end

D.GCDDot = function(box)
    -- built the way the real dot is: a dim soft circle, a pie that fills over it, a glow above it, and
    -- for the swing timer a bigger pie on a lower frame level so only its outer rim shows around the dot
    local function Dot(cx, size, withRing)
        local frame = CreateFrame("Frame", nil, box)
        local ringSize = size * 1.55
        frame:SetWidth(ringSize); frame:SetHeight(ringSize)
        frame:SetPoint("CENTER", box, "TOPLEFT", cx, -62)
        local lvl = frame:GetFrameLevel()
        local d = {}
        if withRing then
            local ringLayer = CreateFrame("Frame", nil, frame)
            ringLayer:SetAllPoints(frame); ringLayer:SetFrameLevel(lvl + 1)
            local base = ringLayer:CreateTexture(nil, "ARTWORK")
            base:SetPoint("CENTER", frame, "CENTER"); base:SetWidth(ringSize); base:SetHeight(ringSize)
            base:SetTexture(ROUND); base:SetVertexColor(1, 1, 1, 0.3)
            d.ring = ringLayer:CreateTexture(nil, "OVERLAY")
            d.ring:SetPoint("CENTER", frame, "CENTER"); d.ring:SetWidth(ringSize); d.ring:SetHeight(ringSize)
            d.ring:SetTexture(PIE); d.ring:SetVertexColor(1, 1, 1, 0.9)
            PieFraction(d.ring, 0)
        end
        local dotLayer = CreateFrame("Frame", nil, frame)
        dotLayer:SetAllPoints(frame); dotLayer:SetFrameLevel(lvl + 3)
        local core = dotLayer:CreateTexture(nil, "ARTWORK")
        core:SetPoint("CENTER", frame, "CENTER"); core:SetWidth(size); core:SetHeight(size)
        core:SetTexture(ROUND); core:SetVertexColor(1, 0.82, 0.2, 0.35)
        d.pie = dotLayer:CreateTexture(nil, "OVERLAY")
        d.pie:SetPoint("CENTER", frame, "CENTER"); d.pie:SetWidth(size); d.pie:SetHeight(size)
        d.pie:SetTexture(PIE); d.pie:SetVertexColor(1, 0.82, 0.2, 0.95)
        PieFraction(d.pie, 0)
        d.glow = dotLayer:CreateTexture(nil, "OVERLAY")
        d.glow:SetPoint("CENTER", frame, "CENTER"); d.glow:SetWidth(size * 2.6); d.glow:SetHeight(size * 2.6)
        d.glow:SetTexture(ROUND); d.glow:SetVertexColor(1, 0.82, 0.2, 1); d.glow:SetBlendMode("ADD"); d.glow:SetAlpha(0)
        return d
    end
    local a = Dot(90, 52, false)
    Text(box, "The global cooldown fills the dot,\nthen it glows: you can act again", 10, 110, 190, "GameFontDisableSmall", nil, nil, nil, "CENTER")
    local b = Dot(330, 52, true)
    Text(box, "The thin ring around it is your\nmelee swing timer", 235, 110, 190, "GameFontDisableSmall", nil, nil, nil, "CENTER")
    Text(box, "Movable, resizable,\nhidden out of combat", 410, 50, 100, "GameFontDisableSmall", nil, nil, nil, "CENTER")
    local t = 0
    box:SetScript("OnUpdate", function(_, e)
        t = (t + e) % 3
        PieFraction(a.pie, math.min(t / 1.5, 1))
        PieFraction(b.pie, math.min(t / 1.5, 1))
        a.glow:SetAlpha(t > 1.5 and math.max(0, 0.8 - (t - 1.5) * 1.6) or 0)     -- only the left one flashes
        PieFraction(b.ring, t / 3)
    end)
end

D.FadeOut = function(box)
    local bars = {}
    local function Bar(x, y)
        local f = CreateFrame("Frame", nil, box)
        f:SetPoint("TOPLEFT", box, "TOPLEFT", x, -y)
        f:SetWidth(240); f:SetHeight(44)
        for i = 1, 6 do
            Solid(f, 4 + (i - 1) * 39, 4, 36, 36, 0.05, 0.05, 0.05, 0.9)
            Icon(f, ITEMS[i], 5 + (i - 1) * 39, 5, 34)
        end
        return f
    end
    local actionBar = Bar(10, 34)
    local label = Text(box, "In combat", 10, 10, 240, "GameFontNormal")
    local static = Bar(270, 34)
    Text(box, "Not managed: always visible", 270, 10, 240, "GameFontDisableSmall")
    local note = Text(box, "", 10, 90, 500, "GameFontDisableSmall")
    local t = 0
    box:SetScript("OnUpdate", function(_, e)
        t = (t + e) % 6
        local a
        if t < 2.5 then a = 1; label:SetText("In combat")
        elseif t < 3 then a = 1 - (t - 2.5) / 0.5 * 0.8; label:SetText("Combat ends...")
        elseif t < 5.5 then a = 0.2; label:SetText("Out of combat: faded")
        else a = 0.2 + (t - 5.5) / 0.5 * 0.8; label:SetText("Back in combat") end
        actionBar:SetAlpha(a)
    end)
    note:SetText("You choose which elements fade and how far; hovering or a target brings them back.")
end

D.OrbMeter = function(box)
    local base = box:CreateTexture(nil, "BACKGROUND")
    base:SetPoint("TOPLEFT", box, "TOPLEFT", 40, -20); base:SetWidth(110); base:SetHeight(110)
    base:SetTexture(ROUND); base:SetVertexColor(0, 0, 0, 0.6)
    local ring = box:CreateTexture(nil, "ARTWORK")
    ring:SetPoint("TOPLEFT", box, "TOPLEFT", 40, -20); ring:SetWidth(110); ring:SetHeight(110)
    ring:SetTexture(PIE); ring:SetVertexColor(1, 0.3, 0.2, 0.95)
    local mask = box:CreateTexture(nil, "OVERLAY")
    mask:SetPoint("TOPLEFT", box, "TOPLEFT", 50, -30); mask:SetWidth(90); mask:SetHeight(90)
    mask:SetTexture(ROUND); mask:SetVertexColor(0.1, 0.35, 0.6, 1)
    local num = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    num:SetPoint("CENTER", mask, "CENTER", 0, 0)
    local lab = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    lab:SetPoint("TOP", mask, "BOTTOM", 0, -12); lab:SetText("damage per second")
    Text(box, "The orb shows damage or healing per second.", 190, 26, 320, "GameFontHighlightSmall")
    Text(box, "The ring around it fills with your threat: full means you are about to pull the target.", 190, 52, 320, "GameFontHighlightSmall")
    Text(box, "Cast three healing spells in a row and it switches to healing by itself.", 190, 92, 320, "GameFontHighlightSmall")
    local t = 0
    box:SetScript("OnUpdate", function(_, e)
        t = t + e
        local dps = 9000 + 3200 * math.sin(t * 1.3) + 900 * math.sin(t * 4.1)
        num:SetText(string.format("%.1fk", dps / 1000))
        PieFraction(ring, 0.5 + 0.4 * math.sin(t * 0.7))
    end)
end

D.RarityBorders = function(box)
    local STAR = "Interface\\Cooldown\\star4"
    local sparks = {}
    local function Grid(x, withBorders)
        for i = 1, 8 do
            local gx, gy = x + ((i - 1) % 4) * 56, 30 + math.floor((i - 1) / 4) * 56
            Solid(box, gx, gy, 50, 50, 0.04, 0.04, 0.04, 0.95)
            local ic = Icon(box, ITEMS[i], gx + 2, gy + 2, 46)
            if withBorders then
                local qi = ({ 2, 3, 4, 5, 6, 1, 3, 5 })[i]
                local q = QUALITY[qi]
                Border(box, gx, gy, 50, 50, q[1], q[2], q[3], 1)
                if i == 6 then Solid(box, gx + 2, gy + 2, 46, 46, 1, 0.1, 0.1, 0.4, "OVERLAY") end
                if qi >= 3 and i ~= 6 then               -- the better items twinkle
                    local tex = box:CreateTexture(nil, "OVERLAY")
                    tex:SetTexture(STAR); tex:SetBlendMode("ADD")
                    tex:SetVertexColor(q[1] + (1 - q[1]) * 0.4, q[2] + (1 - q[2]) * 0.4, q[3] + (1 - q[3]) * 0.4)
                    tex:SetAlpha(0)
                    sparks[#sparks + 1] = { tex = tex, cx = gx + 25, cy = gy + 25, t = -math.random() * 2, dur = 1.4, angle = math.random() * 6.28 }
                end
            end
        end
    end
    Text(box, "Without", 14, 8, 200, "GameFontNormalSmall")
    Grid(14, false)
    Text(box, "With RarityBorders", 272, 8, 200, "GameFontNormalSmall")
    Grid(272, true)
    Text(box, "red tint: you cannot use this item", 272, 136, 245, "GameFontDisableSmall", 1, 0.4, 0.4)
    local function Place(sp)
        sp.size = 22 + math.random() * 14
        sp.tex:ClearAllPoints()
        sp.tex:SetPoint("CENTER", box, "TOPLEFT", sp.cx + (math.random() - 0.5) * 26, -(sp.cy + (math.random() - 0.5) * 26))
        sp.tex:SetWidth(sp.size); sp.tex:SetHeight(sp.size)
        sp.dur = 1.2 + math.random() * 0.9
    end
    for _, sp in ipairs(sparks) do Place(sp) end
    box:SetScript("OnUpdate", function(_, e)
        for _, sp in ipairs(sparks) do
            sp.t = sp.t + e
            if sp.t >= sp.dur then sp.t = -(0.3 + math.random() * 1.6); Place(sp); sp.tex:SetAlpha(0)
            elseif sp.t > 0 then
                local f = sp.t / sp.dur
                sp.tex:SetAlpha(math.sin(f * math.pi) * 0.95)
                local ang = sp.angle + f * 0.8
                local c, sn = math.cos(ang) * 0.7071, math.sin(ang) * 0.7071
                sp.tex:SetTexCoord(0.5 - c + sn, 0.5 - sn - c, 0.5 - c - sn, 0.5 - sn + c, 0.5 + c + sn, 0.5 + sn - c, 0.5 + c - sn, 0.5 + sn + c)
            end
        end
    end)
end

D.InventoryPlus = function(box)
    local TABS = {
        { "Gear", { 0.64, 0.21, 0.93 }, { 1, 5, 7 } },
        { "Consumables", { 0, 0.44, 0.87 }, { 3, 8, 3 } },
        { "Crafting", { 1, 0.5, 0 }, { 6, 4, 2 } },
    }
    for n, tab in ipairs(TABS) do
        local bx = 14 + (n - 1) * 172
        Panel(box, bx + 22, 22, 128, 92, 0.7)
        Solid(box, bx, 30, 20, 28, tab[2][1], tab[2][2], tab[2][3], 1)
        Border(box, bx, 30, 20, 28, 1, 1, 1, 0.8)
        Solid(box, bx, 62, 20, 28, 0.3, 0.3, 0.3, 0.8)
        for i, id in ipairs(tab[3]) do
            local gx = bx + 30 + (i - 1) * 38
            Solid(box, gx, 30, 34, 34, 0.04, 0.04, 0.04, 0.95)
            Icon(box, ITEMS[id], gx + 1, 31, 32)
            Border(box, gx, 30, 34, 34, tab[2][1], tab[2][2], tab[2][3], 1)
        end
        Text(box, tab[1] .. " bag", bx + 22, 122, 128, "GameFontNormalSmall", tab[2][1], tab[2][2], tab[2][3], "CENTER")
    end
    Text(box, "Each tab holds one kind of item. Loot lands in its bag, sorting keeps each bag in order.", 14, 4, 500, "GameFontDisableSmall")
end

------------------------------------------------------------
-- the window
------------------------------------------------------------
local wiz
local pages, order = {}, {}

local function Apply(m, on)
    DS.SetEnabled(m, on)
end

local function StateText(m)
    if DS.IsEnabled(m) then return "|cff33ff33Enabled|r" end
    return "|cff999999Disabled|r"
end

local function GoTo(i, instant)
    local old = wiz.pageIndex and pages[wiz.pageIndex]
    wiz.pageIndex = i
    local pg = pages[i]
    if pg.Refresh then pg.Refresh() end
    UI.Switch(order, old, pg, instant)
    wiz.progress:SetText(i .. " / " .. #pages)
    -- buttons
    if i > 1 then wiz.back:Show() else wiz.back:Hide() end
    wiz.no:Hide(); wiz.yes:Hide(); wiz.next:Hide()
    if i == 1 then
        wiz.no:SetText("Skip Setup"); wiz.no:Show()
        wiz.next:SetText("Start"); wiz.next:Show()
        wiz.no.action = function() DS.HideWizard() end
    elseif i == #pages then
        wiz.next:SetText("Finish"); wiz.next:Show()
    else
        wiz.no:SetText("No thanks"); wiz.no:Show()
        wiz.yes:SetText("Enable"); wiz.yes:Show()
        local m = pg.module
        wiz.no.action = function() Apply(m, false); GoTo(i + 1) end
        wiz.yes.action = function() Apply(m, true); GoTo(i + 1) end
    end
end

local function BuildPage(parent)
    local pg = CreateFrame("Frame", nil, parent)
    pg:SetAllPoints(parent)
    pg:Hide()
    return pg
end

local function Build()
    wiz = CreateFrame("Frame", "DreamSuiteWizard", UIParent)
    wiz:SetWidth(W); wiz:SetHeight(H)
    wiz:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    wiz:SetFrameStrata("DIALOG")
    wiz:SetBackdrop(BACKDROP)
    wiz:EnableMouse(true); wiz:SetMovable(true)
    wiz:RegisterForDrag("LeftButton")
    wiz:SetScript("OnDragStart", function(self) self:StartMoving() end)
    wiz:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    wiz:SetClampedToScreen(true)
    wiz:Hide()
    tinsert(UISpecialFrames, "DreamSuiteWizard")

    local logo = wiz:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPLEFT", 22, -18); logo:SetWidth(28); logo:SetHeight(28)
    logo:SetTexture(DS.ICONS .. "Hub.tga")
    local title = wiz:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("DreamSuite Setup")
    wiz.progress = wiz:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    wiz.progress:SetPoint("TOPRIGHT", -26, -28)
    UI.Divider(wiz, 56, 20)
    UI.Divider(wiz, 56, 20, true)

    local body = CreateFrame("Frame", nil, wiz)
    body:SetPoint("TOPLEFT", 20, -64)
    body:SetPoint("BOTTOMRIGHT", -20, 62)
    wiz.body = body

    -- the buttons
    wiz.back = UI.Button(wiz, "Back", 80, 24)
    wiz.back:SetPoint("BOTTOMLEFT", 24, 22)
    wiz.back:SetScript("OnClick", function() GoTo(wiz.pageIndex - 1) end)
    wiz.next = UI.Button(wiz, "Next", 100, 24)
    wiz.next:SetPoint("BOTTOMRIGHT", -26, 22)
    wiz.next:SetScript("OnClick", function()
        if wiz.pageIndex == #pages then DS.HideWizard() else GoTo(wiz.pageIndex + 1) end
    end)
    wiz.yes = UI.Button(wiz, "Enable", 100, 24)
    wiz.yes:SetPoint("BOTTOMRIGHT", -26, 22)
    wiz.yes:SetScript("OnClick", function() if wiz.yes.action then wiz.yes.action() end end)
    wiz.no = UI.Button(wiz, "No thanks", 100, 24)
    wiz.no:SetScript("OnClick", function() if wiz.no.action then wiz.no.action() end end)
    wiz.no:SetPoint("BOTTOMRIGHT", wiz.yes, "BOTTOMLEFT", -8, 0)

    -- page 1: welcome
    local pg = BuildPage(body)
    Text(pg, "Welcome", 0, 6, 520, "GameFontNormalLarge")
    Text(pg, "DreamSuite holds all the X08 addons in one place. Nothing is switched on yet: the next pages go through them one by one, show what each does, and you choose which ones you want.", 0, 44, 520, "GameFontHighlight")
    Text(pg, "You can change every choice later:", 0, 130, 520, "GameFontNormal")
    Text(pg, "|cffffd000/ds|r opens the hub: left-click a module for its settings, right-click to enable or disable it.\n|cffffd000/ds wizard|r runs this setup again.", 0, 156, 520, "GameFontHighlight")
    Text(pg, "The wizard applies a choice the moment you make it, so you can close it whenever you like.", 0, 230, 520, "GameFontDisableSmall")
    pages[1] = pg

    -- one page per module
    for _, m in ipairs(DS.modules) do
        local p = BuildPage(body)
        p.module = m
        local ic = p:CreateTexture(nil, "ARTWORK")
        ic:SetPoint("TOPLEFT", 0, -2); ic:SetWidth(40); ic:SetHeight(40)
        ic:SetTexture(DS.IconPath(m))
        Text(p, m.title, 52, 0, 300, "GameFontNormalLarge")
        p.state = Text(p, "", 52, 24, 200, "GameFontHighlightSmall")
        Text(p, m.desc or "", 220, 4, 300, "GameFontDisableSmall", nil, nil, nil, "LEFT")
        local box = CreateFrame("Frame", nil, p)
        box:SetPoint("TOPLEFT", 0, -52)
        box:SetWidth(BOX_W); box:SetHeight(BOX_H)
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0.02, 0.02, 0.02, 0.5)
        box:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        local inner = CreateFrame("Frame", nil, box)
        inner:SetPoint("TOPLEFT", 2, -2); inner:SetPoint("BOTTOMRIGHT", -2, 2)
        if D[m.id] then D[m.id](inner) end
        local info = INFO[m.id] or {}
        for i, line in ipairs(info) do
            Text(p, "|cffffc800-|r  " .. line, 0, 212 + (i - 1) * 30, 520, "GameFontHighlightSmall")
        end
        p.Refresh = function() p.state:SetText(StateText(m)) end
        pages[#pages + 1] = p
    end

    -- last page: summary
    local last = BuildPage(body)
    Text(last, "All set", 0, 6, 520, "GameFontNormalLarge")
    last.list = Text(last, "", 0, 46, 520, "GameFontHighlight")
    Text(last, "|cffffd000/ds|r opens the hub, |cffffd000/ds wizard|r runs this setup again.", 0, 250, 520, "GameFontDisableSmall")
    last.Refresh = function()
        local lines = {}
        for _, m in ipairs(DS.modules) do
            lines[#lines + 1] = m.title .. "  -  " .. StateText(m)
        end
        last.list:SetText(table.concat(lines, "\n"))
    end
    pages[#pages + 1] = last

    for i, p in ipairs(pages) do order[i] = p end
end

function DS.ShowWizard()
    if not wiz then Build() end
    if DreamSuiteDB then DreamSuiteDB.wizardDone = true end
    wiz.pageIndex = nil
    GoTo(1, true)
    UI.Fade(wiz, 0, 1, 0.25)
end

function DS.HideWizard()
    if not wiz or not wiz:IsShown() then return end
    UI.Fade(wiz, wiz:GetAlpha(), 0, 0.3, function() wiz:Hide(); wiz:SetAlpha(1) end)
end
