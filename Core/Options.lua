------------------------------------------------------------
-- DreamSuite - Options
-- generated settings view for a module
--
-- A module's `options` is a list (or a function returning one) of descriptors:
--   { type = "bool",   key, label, desc, get, set, disabled, preview }
--   { type = "slider", key, label, desc, min, max, step, fmt, lowText, highText,
--                      get, set, live, disabled }
--   { type = "choice", key, label, desc, values, valueLabels, get, set }
--   { type = "color",  key, label, desc, get -> r,g,b, set(r,g,b), disabled }
--   { type = "action", key, label, desc, set, confirm }
--   { type = "edit",   key, label, desc, width, maxLetters, multiline, height, get -> string, set(string) }
--                      multiline: a framed box that wraps long text (at most one column wide)
--                      (applied on Enter or when the box loses focus; Escape cancels)
--   { type = "header", label }      { type = "text", text = string | function }
--   { type = "tab", label }         starts a new tab; everything after it belongs to that tab
--                                    (no tab entries = one plain page; items before the first
--                                    tab entry go on a tab called "General")
--
-- get / set are plain functions that talk to the module directly.
-- `disabled` is an optional function returning true to grey the control out.
-- bool `preview` is an optional function(parent) returning a small frame; the
-- hub places it beside the checkbox and calls frame:SetOn(bool) if it has one.
------------------------------------------------------------
local DS = DreamSuite
local C = DS.C

------------------------------------------------------------
-- Option model
------------------------------------------------------------
-- m.options may be a list or a function returning one (evaluated when the
-- module is running, so it can read the module's own tables)
function DS.GetOptions(m)
    if m._opts then return m._opts end
    local o = m.options
    if type(o) == "function" then
        local ok, res = pcall(o)
        if ok and type(res) == "table" and #res > 0 then
            m._opts = res
            return res
        end
        if not ok then geterrorhandler()(res) end
        return {}
    elseif o then
        m._opts = o
        return o
    end
    return {}
end

local function ToBool(v)
    return v == true or v == 1 or v == "on" or v == "1"
end

function DS.GetOptionState(m, o)
    if o.get then
        local ok, v = pcall(o.get)
        if ok and v ~= nil then
            if o.type == "bool" then return ToBool(v) end
            return v
        end
    end
    if o.type == "bool" then return ToBool(o.default) end
    return o.default
end

function DS.SetOption(m, o, val)
    if not o.set then return end
    local ok, err = pcall(o.set, val)
    if not ok then geterrorhandler()(err) end
end

function DS.SetOptionColor(m, o, r, g, b)
    local ok, err = pcall(o.set, r, g, b)
    if not ok then geterrorhandler()(err) end
end

------------------------------------------------------------
-- Generated panel
------------------------------------------------------------
local contents = {}
local CONTENT_W = 350        -- width of one column
local COL_GAP   = 24
local BODY_H    = 420        -- height available to the settings body
local sliderCount = 0

local function Divider(c, y) DS.UI.Divider(c, y, 0) end

local function Reg(c, o, ctl)
    ctl.o = o
    tinsert((c.root or c).controls, ctl)
end

local function AddHeader(c, m, o, y)
    local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 12)
    fs:SetText(o.label)
    Divider(c, y + 28)
    return y + 34
end

local function AddText(c, m, o, y)
    local fs = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 2)
    fs:SetWidth(CONTENT_W - 8)
    fs:SetJustifyH("LEFT")
    if type(o.text) == "function" then
        Reg(c, o, { Refresh = function()
            local ok, t = pcall(o.text)
            fs:SetText(ok and t or "")
        end })
        return y + 18
    end
    fs:SetText(o.text)
    return y + (fs:GetStringHeight() or 14) + 10
end

local function AddBool(c, m, o, y)
    local x = 0
    local tile
    if o.preview then
        local ok, t = pcall(o.preview, c)
        if ok and type(t) == "table" then
            tile = t
            tile:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
            x = (tile:GetWidth() or 48) + 10
        end
    end
    local cb = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
    cb:SetWidth(26); cb:SetHeight(26)
    cb:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y - 2)
    local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(o.label or o.key)
    local h = 28
    if o.desc then
        local d = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, 1)
        d:SetWidth(CONTENT_W - x - 8)
        d:SetJustifyH("LEFT")
        d:SetText(o.desc)
        h = 30 + (d:GetStringHeight() or 12) + 4
    end
    if tile and h < (tile:GetHeight() or 0) then h = tile:GetHeight() end
    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        DS.SetOption(m, o, v)
        if tile and tile.SetOn then tile:SetOn(v) end
    end)
    local ctl = {}
    function ctl.Refresh()
        local v = DS.GetOptionState(m, o) and true or false
        cb:SetChecked(v)
        if tile and tile.SetOn then tile:SetOn(v) end
    end
    function ctl.SetEnabled(on)
        if on then cb:Enable(); lbl:SetTextColor(1, 0.82, 0)
        else cb:Disable(); lbl:SetTextColor(0.5, 0.5, 0.5) end
    end
    Reg(c, o, ctl)
    if tile then Divider(c, y + h - 2) end
    return y + h
end

local function ChoiceColors(buttons, cur)
    for _, ob in ipairs(buttons) do
        local on = ob.value == cur
        ob:GetFontString():SetTextColor(on and 1 or 0.7, on and 0.82 or 0.7, on and 0 or 0.7)
    end
end

local function AddChoice(c, m, o, y)
    local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 4)
    lbl:SetText(o.label or o.key)
    local top = 22
    if o.desc then
        local d = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -1)
        d:SetWidth(CONTENT_W - 8)
        d:SetJustifyH("LEFT")
        d:SetText(o.desc)
        top = 22 + (d:GetStringHeight() or 12) + 4
    end
    local buttons = {}
    for i, v in ipairs(o.values) do
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetWidth(72); b:SetHeight(20)
        b:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + (i - 1) * 76, -y - top - 2)
        b:SetText(o.valueLabels and o.valueLabels[v] or v)
        b.value = v
        b:SetScript("OnClick", function()
            DS.SetOption(m, o, v)
            ChoiceColors(buttons, v)
        end)
        buttons[i] = b
    end
    local ctl = {}
    function ctl.Refresh() ChoiceColors(buttons, DS.GetOptionState(m, o)) end
    Reg(c, o, ctl)
    return y + top + 30
end

local function AddSlider(c, m, o, y)
    sliderCount = sliderCount + 1
    local name = "DreamSuiteSlider" .. sliderCount
    local fmt = o.fmt or function(v) return tostring(v) end
    local step = o.step or 1

    local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 2)
    local top = 20
    if o.desc then
        local d = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -1)
        d:SetWidth(CONTENT_W - 8)
        d:SetJustifyH("LEFT")
        d:SetText(o.desc)
        top = 20 + (d:GetStringHeight() or 12) + 2
    end

    local sl = CreateFrame("Slider", name, c, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -y - top - 12)
    sl:SetWidth(CONTENT_W - 20); sl:SetHeight(16)
    sl:SetMinMaxValues(o.min, o.max)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local low, high, text = _G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"]
    if low then low:SetText(o.lowText or fmt(o.min)) end
    if high then high:SetText(o.highText or fmt(o.max)) end
    if text then text:SetText("") end

    local function ShowValue(v)
        lbl:SetText((o.label or o.key) .. ": " .. C.white .. fmt(v) .. C.r)
    end

    local refreshing = false
    sl:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        ShowValue(value)
        if refreshing then return end
        if o.live then
            DS.SetOption(m, o, value)
        else
            self.pending = value          -- applied on mouse release: no spam while dragging
        end
    end)
    sl:SetScript("OnMouseDown", function(self) self.dragging = true end)
    sl:SetScript("OnMouseUp", function(self)
        self.dragging = false
        if self.pending ~= nil then
            local v = self.pending
            self.pending = nil
            DS.SetOption(m, o, v)
        end
    end)

    local ctl = {}
    function ctl.Refresh()
        if sl.dragging then return end
        local v = DS.GetOptionState(m, o)
        if type(v) ~= "number" then return end
        refreshing = true
        sl:SetValue(v)
        ShowValue(v)
        refreshing = false
    end
    function ctl.SetEnabled(on)
        sl:EnableMouse(on and true or false)
        sl:SetAlpha(on and 1 or 0.45)
        if on then lbl:SetTextColor(1, 0.82, 0) else lbl:SetTextColor(0.5, 0.5, 0.5) end
    end
    Reg(c, o, ctl)
    return y + top + 44
end

local function AddColor(c, m, o, y)
    local sw = CreateFrame("Button", nil, c)
    sw:SetWidth(24); sw:SetHeight(24)
    sw:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 2)
    local edge = sw:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints(); edge:SetTexture(0.8, 0.8, 0.8, 1)
    local fill = sw:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2); fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetTexture(1, 1, 1, 1)
    local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    lbl:SetText(o.label or o.key)
    local h = 32
    if o.desc then
        local d = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", sw, "BOTTOMLEFT", 0, -2)
        d:SetWidth(CONTENT_W - 8)
        d:SetJustifyH("LEFT")
        d:SetText(o.desc)
        h = 32 + (d:GetStringHeight() or 12) + 4
    end

    local function Apply(r, g, b)
        fill:SetVertexColor(r, g, b)
        DS.SetOptionColor(m, o, r, g, b)
    end
    sw:SetScript("OnClick", function(self)
        if not self.enabled then return end
        local r, g, b = o.get()
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = nil
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = function()
            Apply(ColorPickerFrame:GetColorRGB())
        end
        ColorPickerFrame.cancelFunc = function(prev)
            prev = prev or ColorPickerFrame.previousValues
            Apply(prev[1], prev[2], prev[3])
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:Show()
    end)
    sw.enabled = true

    local ctl = {}
    function ctl.Refresh()
        local ok, r, g, b = pcall(o.get)
        if ok and r then fill:SetVertexColor(r, g, b) end
    end
    function ctl.SetEnabled(on)
        sw.enabled = on and true or false
        sw:SetAlpha(on and 1 or 0.4)
        if on then lbl:SetTextColor(1, 0.82, 0) else lbl:SetTextColor(0.5, 0.5, 0.5) end
    end
    Reg(c, o, ctl)
    return y + h
end

local function AddAction(c, m, o, y)
    local b = DS.UI.Button(c, "", 170, 22)
    b:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 4)
    local label = o.label or o.key
    b:SetText(label)
    local token = 0
    b:SetScript("OnClick", function(self)
        if o.confirm and not self.armed then
            self.armed = true
            token = token + 1
            local mine = token
            self:SetText("Click again to confirm")
            DS.After(3, function()
                if token == mine then self.armed = false; self:SetText(label) end
            end)
            return
        end
        if self.armed then
            self.armed = false
            token = token + 1
            self:SetText(label)
        end
        DS.SetOption(m, o)
        if DS.RefreshOptions then DS.RefreshOptions() end
    end)
    local h = 34
    if o.desc then
        local d = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("LEFT", b, "RIGHT", 8, 0)
        d:SetWidth(CONTENT_W - 190)
        d:SetJustifyH("LEFT")
        d:SetText(o.desc)
    end
    return y + h
end

local function AddEdit(c, m, o, y)
    local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y - 4)
    lbl:SetText(o.label or o.key)
    local top = 22
    if o.desc then
        local d = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -1)
        d:SetWidth(CONTENT_W - 8)
        d:SetJustifyH("LEFT")
        d:SetText(o.desc)
        top = 22 + (d:GetStringHeight() or 12) + 4
    end
    local eb, boxH
    if o.multiline then
        -- a framed box that wraps long text over several lines (Enter applies, click outside applies too)
        boxH = o.height or 64
        local w = math.min(o.width or (CONTENT_W - 8), CONTENT_W - 8)
        local box = CreateFrame("Frame", nil, c)
        box:SetWidth(w); box:SetHeight(boxH)
        box:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -y - top)
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        eb = CreateFrame("EditBox", nil, box)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(w - 14); eb:SetHeight(boxH - 12)
        eb:SetPoint("TOPLEFT", box, "TOPLEFT", 7, -6)
        eb:SetAutoFocus(false)
        box:EnableMouse(true)
        box:SetScript("OnMouseDown", function() eb:SetFocus() end)
        eb:SetScript("OnTextChanged", function(self)
            local t = self:GetText() or ""
            if t:find("\n") then self:SetText((t:gsub("\n", ""))); self:ClearFocus() end     -- Enter applies
        end)
        top = top + boxH - 20 + 4
    else
        eb = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        eb:SetWidth(o.width or 200); eb:SetHeight(20)
        eb:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -y - top - 2)
        eb:SetAutoFocus(false)
    end
    if o.maxLetters then eb:SetMaxLetters(o.maxLetters) end
    local function show()
        local v = DS.GetOptionState(m, o)
        eb:SetText(v ~= nil and tostring(v) or "")
        eb:SetCursorPosition(0)
    end
    eb:SetScript("OnEnterPressed", function(self)
        DS.SetOption(m, o, strtrim(self:GetText() or ""))
        show()
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) show(); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function(self)
        DS.SetOption(m, o, strtrim(self:GetText() or ""))
        show()
    end)
    local ctl = {}
    function ctl.Refresh() if not eb:HasFocus() then show() end end
    Reg(c, o, ctl)
    return y + top + 30
end

local BUILDERS = {
    header = AddHeader, text = AddText, bool = AddBool, slider = AddSlider,
    choice = AddChoice, color = AddColor, action = AddAction, edit = AddEdit,
}

-- flows built items into two columns inside `page` (a heading never ends a column on its own)
local function Flow(page, items, height)
    local col, y = 0, 0
    for i, it in ipairs(items) do
        local need = it.h
        if it.header and items[i + 1] then need = need + items[i + 1].h end
        if col == 0 and y > 0 and y + need > height then
            col, y = 1, 0
        end
        it.f:SetPoint("TOPLEFT", page, "TOPLEFT", col * (CONTENT_W + COL_GAP), -y)
        y = y + it.h
    end
end

local function BuildContent(m, body)
    local root = CreateFrame("Frame", nil, body)
    root:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    root:SetWidth(CONTENT_W * 2 + COL_GAP); root:SetHeight(BODY_H)
    root.controls = {}

    local opts = DS.GetOptions(m)
    root.empty = (#opts == 0)
    if root.empty then
        local fs = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", root, "TOPLEFT", 4, 0)
        fs:SetWidth(CONTENT_W)
        fs:SetJustifyH("LEFT")
        fs:SetText("This module has no settings.")
        return root
    end

    -- split into tabs
    local groups, cur = {}, nil
    local hasTabs = false
    for _, o in ipairs(opts) do if o.type == "tab" then hasTabs = true end end
    if hasTabs and opts[1].type ~= "tab" then
        cur = { label = "General", opts = {} }; tinsert(groups, cur)
    end
    if not hasTabs then cur = { label = "", opts = {} }; tinsert(groups, cur) end
    for _, o in ipairs(opts) do
        if o.type == "tab" then
            cur = { label = o.label or "Tab", opts = {} }; tinsert(groups, cur)
        else
            tinsert(cur.opts, o)
        end
    end

    local top, pageH = 0, BODY_H
    local strip
    if hasTabs then
        local defs = {}
        for i, g in ipairs(groups) do defs[i] = { i, g.label } end
        root.tabs = DS.UI.Tabs(root, defs, function(key)
            local pages = {}
            for i, g in ipairs(groups) do pages[i] = g.page end
            local prev = root.tabKey and groups[root.tabKey] and groups[root.tabKey].page
            root.tabKey = key
            DS.UI.Switch(pages, prev, groups[key].page)
        end)
        strip = root.tabs.frame
        strip:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        strip:SetWidth(CONTENT_W * 2 + COL_GAP)
        top = DS.UI.TAB_H + 12
        pageH = BODY_H - top
    end

    for _, g in ipairs(groups) do
        local page = CreateFrame("Frame", nil, root)
        page:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -top)
        page:SetWidth(CONTENT_W * 2 + COL_GAP); page:SetHeight(pageH)
        g.page = page
        local items = {}
        for _, o in ipairs(g.opts) do
            local item = CreateFrame("Frame", nil, page)
            item.root = root
            item:SetWidth(CONTENT_W)
            local build = BUILDERS[o.type or "bool"] or AddBool
            local h = build(item, m, o, 0)
            item:SetHeight(h)
            tinsert(items, { f = item, h = h, header = (o.type == "header") })
        end
        Flow(page, items, pageH)
        if hasTabs then page:Hide() end
    end
    if hasTabs then root.tabs:Select(root.tabKey or 1) end
    return root
end

local function RefreshControls(c)
    for _, ctl in ipairs(c.controls) do
        ctl.Refresh()
        if ctl.SetEnabled and ctl.o.disabled then
            local ok, off = pcall(ctl.o.disabled)
            ctl.SetEnabled(not (ok and off))
        end
    end
end

-- a module whose option list changed (e.g. FadeOut gained an entry) asks for a rebuild
function DS.InvalidateOptions(m)
    m._opts = nil
    local c = contents[m.id]
    if c then
        c:Hide()
        contents[m.id] = nil
        if DS.currentContent == c then DS.currentContent = nil end
    end
end

function DS.HideContents()
    for _, c in pairs(contents) do c:Hide() end
    DS.currentContent = nil
end

-- Shows this module's settings inside `body` (built once, then reused) and
-- hides every other module's.
function DS.ShowContent(m, body)
    for _, c in pairs(contents) do c:Hide() end
    local c = contents[m.id]
    if c and c.empty and #DS.GetOptions(m) > 0 then
        c:Hide()                       -- was built before the module's options were ready
        c = nil
    end
    if not c then
        c = BuildContent(m, body)
        contents[m.id] = c
    end
    c:Show()
    RefreshControls(c)
    DS.currentContent = c
    return c
end

function DS.RefreshOptions()
    local c = DS.currentContent
    if c and c:IsVisible() then RefreshControls(c) end
end
