------------------------------------------------------------
-- DreamSuite - shared widgets
-- one look for every module: dividers, buttons, checkboxes, tab strips.
-- Modules (and the hub itself) build their settings from these so
-- everything stays uniform.
--
--   DS.UI.Divider(parent, y, inset [, fromBottom])   thin full-width line
--   DS.UI.Button(parent, text, w, h)                 standard button
--   DS.UI.Check(parent, name, label, get, set)       checkbox with label, .Refresh()
--   DS.UI.Tabs(parent, defs, onSelect)               tab strip, see below
------------------------------------------------------------
local DS = DreamSuite
local UI = {}
DS.UI = UI

UI.LINE = { 1, 1, 1, 0.10 }
UI.TAB_H = 26

function UI.Divider(parent, y, inset, fromBottom)
    local l = parent:CreateTexture(nil, "ARTWORK")
    l:SetTexture(UI.LINE[1], UI.LINE[2], UI.LINE[3], UI.LINE[4])
    l:SetHeight(1)
    inset = inset or 0
    if fromBottom then
        l:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, y)
        l:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, y)
    else
        l:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -y)
        l:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -y)
    end
    return l
end

function UI.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w or 100); b:SetHeight(h or 22)
    b:SetText(text or "")
    return b
end

-- a small bordered box that shows a state and works like a switch (click it); style it with :SetState
function UI.StateBox(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w or 110); b:SetHeight(h or 24)
    b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER", 0, 0)
    function b:SetState(text, r, g, bl)
        self.text:SetText(text or "")
        self.text:SetTextColor(r, g, bl)
        self:SetBackdropColor(r * 0.22, g * 0.22, bl * 0.22, 0.9)
        self:SetBackdropBorderColor(r, g, bl, 0.75)
    end
    return b
end

local checkN = 0
function UI.Check(parent, label, get, set)
    checkN = checkN + 1
    local n = "DreamSuiteCheck" .. checkN
    local cb = CreateFrame("CheckButton", n, parent, "InterfaceOptionsCheckButtonTemplate")
    local text = _G[n .. "Text"]
    if text then text:SetText(label or "") end
    cb:SetScript("OnClick", function(self) if set then set(self:GetChecked() and true or false) end end)
    function cb.Refresh() if get then cb:SetChecked(get()) end end
    return cb
end

------------------------------------------------------------
-- Tab strip
--   defs     = { { key, "Label" }, ... }
--   onSelect = function(key)           called after a tab is picked
--   returns  = tabs object: tabs.frame (the strip, TAB_H tall, anchor it yourself),
--              tabs:Select(key), tabs.current, tabs:SetBadge(key, bool)
-- Look: flat tabs, the active one in gold with a bar under it.
------------------------------------------------------------
local function Paint(t, on)
    t.text:SetTextColor(on and 1 or 0.65, on and 0.82 or 0.65, on and 0 or 0.65)
    if on then t.bar:Show(); t.bg:Show() else t.bar:Hide(); t.bg:Hide() end
end

function UI.Tabs(parent, defs, onSelect)
    local tabs = { buttons = {}, order = {} }
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(UI.TAB_H)
    tabs.frame = strip

    local rule = strip:CreateTexture(nil, "BORDER")
    rule:SetTexture(UI.LINE[1], UI.LINE[2], UI.LINE[3], UI.LINE[4])
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)

    local x = 0
    for _, d in ipairs(defs) do
        local t = CreateFrame("Button", nil, strip)
        t:SetHeight(UI.TAB_H - 1)
        t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t.text:SetPoint("CENTER", 0, 1)
        t.text:SetText(d[2])
        local w = math.max(70, (t.text:GetStringWidth() or 50) + 28)
        t:SetWidth(w)
        t:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, 1)
        x = x + w + 2

        t.bg = t:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints(); t.bg:SetTexture(1, 0.82, 0, 0.07)
        t.hl = t:CreateTexture(nil, "HIGHLIGHT")
        t.hl:SetAllPoints(); t.hl:SetTexture(1, 1, 1, 0.07)
        t.bar = t:CreateTexture(nil, "ARTWORK")
        t.bar:SetHeight(2)
        t.bar:SetTexture(1, 0.82, 0, 1)
        t.bar:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, -1)
        t.bar:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, -1)
        t.badge = t:CreateTexture(nil, "OVERLAY")
        t.badge:SetTexture(DS.ICONS .. "dot.tga")
        t.badge:SetWidth(10); t.badge:SetHeight(10)
        t.badge:SetPoint("TOPRIGHT", t, "TOPRIGHT", -3, -3)
        t.badge:SetVertexColor(1, 0.5, 0.04)
        t.badge:Hide()

        t.key = d[1]
        t:SetScript("OnClick", function() tabs:Select(d[1]) end)
        Paint(t, false)
        tabs.buttons[d[1]] = t
        tinsert(tabs.order, d[1])
    end

    function tabs:Select(key)
        if not self.buttons[key] then key = self.order[1] end
        for k, t in pairs(self.buttons) do Paint(t, k == key) end
        self.current = key
        if onSelect then onSelect(key) end
    end

    function tabs:SetBadge(key, on)
        local t = self.buttons[key]
        if t then if on then t.badge:Show() else t.badge:Hide() end end
    end

    return tabs
end

------------------------------------------------------------
-- Fading
--   UI.Fade(frame, from, to, dur, done)   alpha tween; hides the frame when it ends at 0
--   UI.HideNow(frame)                     cancel any fade, hide, alpha back to 1
--   UI.Switch(all, old, new, instant)     crossfade between two pages of a set (all = table of pages)
------------------------------------------------------------
UI.FADE = 0.15          -- default tween
UI.FADE_OUT = 0.18      -- page change: old page out ...
UI.FADE_IN  = 0.24      -- ... then the new one in

function UI.Fade(frame, from, to, dur, done)
    dur = dur or UI.FADE
    frame:SetAlpha(from)
    frame:Show()
    local t = 0
    frame.fading = true
    frame:SetScript("OnUpdate", function(self, el)
        t = t + el
        local p = math.min(1, t / dur)
        self:SetAlpha(from + (to - from) * p)
        if p >= 1 then
            self:SetScript("OnUpdate", nil)
            self.fading = nil
            if to == 0 then self:Hide() end
            if done then done() end
        end
    end)
end

function UI.HideNow(frame)
    frame:SetScript("OnUpdate", nil)
    frame.fading = nil
    frame:SetAlpha(1)
    frame:Hide()
end

local switchToken = setmetatable({}, { __mode = "k" })

function UI.Switch(all, old, new, instant)
    switchToken[all] = (switchToken[all] or 0) + 1
    local tok = switchToken[all]
    for _, p in pairs(all) do
        if p ~= old and p ~= new then UI.HideNow(p) end
    end
    if instant or not old or old == new or not old:IsShown() then
        if old and old ~= new then UI.HideNow(old) end
        new:SetScript("OnUpdate", nil)
        new.fading = nil
        new:SetAlpha(1)
        new:Show()
        return
    end
    UI.HideNow(new)                                    -- the new page waits until the old one is gone
    UI.Fade(old, old:GetAlpha(), 0, UI.FADE_OUT, function()
        if switchToken[all] == tok then UI.Fade(new, 0, 1, UI.FADE_IN) end
    end)
end
