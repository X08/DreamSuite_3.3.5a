--[[ InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
     Options window: Tabs / Organize / Warehouse pages. ]]

local DS = DreamSuite
local BT = DS.InventoryPlusCore
local M = BT.module
local O = {}
BT.Options = O

local frame, pages, tabs         -- frame = the settings view inside the DreamSuite window
local selBag = 0
local pendingPage, pendingArg

-- ============================================================ widget helpers
local Button = DS.UI.Button          -- shared look (UI/Widgets.lua)

local nameN = 0
local function Check(parent, x, y, label, get, set)
    nameN = nameN + 1
    local n = "InventoryPlusOptCheck" .. nameN
    local cb = CreateFrame("CheckButton", n, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[n .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb.Refresh = function() cb:SetChecked(get()) end
    return cb
end

-- click to cycle (left = next, right = previous): avoids the version-dependent Blizzard dropdown API
local function Cycle(parent, x, y, width, label, values, get, set)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y); fs:SetText(label)
    local b = Button(parent, "", width, 22)
    b:SetPoint("TOPLEFT", x, y - 16)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function show()
        local cur = get()
        for _, v in ipairs(values()) do if v.key == cur then b:SetText(v.label); return end end
        b:SetText(tostring(cur))
    end
    b:SetScript("OnClick", function(_, button)
        local vals, idx = values(), 1
        local cur = get()
        for i, v in ipairs(vals) do if v.key == cur then idx = i end end
        idx = idx + (button == "RightButton" and -1 or 1)
        if idx > #vals then idx = 1 elseif idx < 1 then idx = #vals end
        set(vals[idx].key)
        show()
    end)
    b.Refresh = show
    return b, fs
end

StaticPopupDialogs["INVENTORYPLUS_SUGGESTED"] = {
    text = "Replace the tabs on your five bags with the suggested setup?\n\nThe Hearthstone is kept in slot 1 of bag 1. Bank bags are left alone.",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function() BT:ApplySuggested() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

StaticPopupDialogs["INVENTORYPLUS_CLEARALL"] = {
    text = "Remove ALL bag rules (tabs) of this character, on every bag including the bank bags?\n\nItems stay where they are. This cannot be undone.",
    button1 = "Clear all", button2 = CANCEL,
    OnAccept = function() BT:ClearAllRules() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
}

-- ============================================================ page: Tabs
local function BuildTabsPage(page)
    page.bagBtns = {}
    local list = {}
    for _, b in ipairs(BT.INV_BAGS) do list[#list + 1] = b end
    for _, b in ipairs(BT.BANK_BAGS) do list[#list + 1] = b end
    local y = 0
    for _, bag in ipairs(list) do
        local b = Button(page, "", 130, 20)
        b:SetPoint("TOPLEFT", 0, y)
        b:SetScript("OnClick", function() selBag = bag; O:Refresh() end)
        b.bag = bag
        page.bagBtns[#page.bagBtns + 1] = b
        y = y - 22
        if bag == 4 then y = y - 10 end
    end

    local sug = Button(page, "Suggested setup", 130, 22)
    sug:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 4)
    sug:SetScript("OnClick", function() StaticPopup_Show("INVENTORYPLUS_SUGGESTED") end)
    sug:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Suggested setup", 1, 0.82, 0)
        GameTooltip:AddLine("Bag 1: Quest + Reagents (Hearthstone kept in slot 1)", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Bag 2: Gear + Weapons + Miscellaneous", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Bag 3: Crafting", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Bag 4: Consumables + Conjured", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Bag 5: Raw Food + Junk", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("One tab per bag, holding all of the above. Replaces the tabs on your five bags. Bank bags are left alone.", 1, 0.6, 0.3, true)
        GameTooltip:Show()
    end)
    sug:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local clr = Button(page, "Clear All Rules", 130, 22)
    clr:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 4)
    clr:SetScript("OnClick", function() StaticPopup_Show("INVENTORYPLUS_CLEARALL") end)
    clr:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Clear All Rules", 1, 0.82, 0)
        GameTooltip:AddLine("Removes every tab of this character, on all bags including the bank bags. Asks first.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    clr:SetScript("OnLeave", function() GameTooltip:Hide() end)

    page.header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.header:SetPoint("TOPLEFT", 142, 0)
    page.hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.hint:SetPoint("TOPLEFT", 142, -24); page.hint:SetWidth(580); page.hint:SetJustifyH("LEFT")
    page.hint:SetText("Each tab is a set of item types that belongs in this bag. New loot of that type is moved here automatically. Tabs also appear on the bag itself.")

    page.rows = {}
    for i = 1, BT.MAX_TABS do
        local r = CreateFrame("Frame", nil, page)
        r:SetWidth(580); r:SetHeight(32)
        r:SetPoint("TOPLEFT", 142, -62 - (i - 1) * 34)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if not self.def then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(BT:TabName(self.def), 1, 0.82, 0)
            GameTooltip:AddLine("Holds: " .. BT:CatList(self.def.cats), 0.8, 0.8, 0.8, true)
            if self.def.exclusive then GameTooltip:AddLine("Exclusive bag", 1, 0.6, 0.3) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetWidth(26); r.icon:SetHeight(26); r.icon:SetPoint("LEFT", 0, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1); r.name:SetWidth(330); r.name:SetHeight(12); r.name:SetJustifyH("LEFT")
        r.cats = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.cats:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1); r.cats:SetWidth(330); r.cats:SetHeight(12); r.cats:SetJustifyH("LEFT")
        r.remove = Button(r, "X", 24, 22); r.remove:SetPoint("RIGHT", 0, 0)
        r.down = Button(r, "Dn", 30, 22); r.down:SetPoint("RIGHT", r.remove, "LEFT", -2, 0)
        r.up = Button(r, "Up", 30, 22); r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
        r.edit = Button(r, "Edit", 44, 22); r.edit:SetPoint("RIGHT", r.up, "LEFT", -2, 0)
        r.edit:SetScript("OnClick", function() O:Pick(selBag, r.def) end)
        r.up:SetScript("OnClick", function()
            local t = BT:GetTabs(selBag)
            if r.idx > 1 then t[r.idx], t[r.idx - 1] = t[r.idx - 1], t[r.idx]; BT:OnTabsChanged() end
        end)
        r.down:SetScript("OnClick", function()
            local t = BT:GetTabs(selBag)
            if r.idx < #t then t[r.idx], t[r.idx + 1] = t[r.idx + 1], t[r.idx]; BT:OnTabsChanged() end
        end)
        r.remove:SetScript("OnClick", function()
            local t = BT:GetTabs(selBag)
            tremove(t, r.idx)
            if #t == 0 then BT.chardb.bags[selBag] = nil end
            BT:OnTabsChanged()
        end)
        page.rows[i] = r
    end

    page.add = Button(page, "Add tab", 90, 22)
    page.add:SetScript("OnClick", function() O:Pick(selBag, nil) end)
    page.clear = Button(page, "Clear bag", 90, 22)
    page.clear:SetScript("OnClick", function()
        BT.chardb.bags[selBag] = nil; BT:OnTabsChanged()
    end)
    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.empty:SetPoint("TOPLEFT", 142, -66)
    page.empty:SetText("No tabs on this bag yet.")

    function page:Refresh()
        for _, b in ipairs(self.bagBtns) do
            b:SetText(BT:BagLabel(b.bag))
            if b.bag == selBag then b:LockHighlight() else b:UnlockHighlight() end
            if b.bag >= 5 then
                if (GetContainerNumSlots(b.bag) or 0) > 0 or BT:GetTabs(b.bag) then b:Enable() else b:Disable() end
            end
        end
        self.header:SetText(BT:BagLabel(selBag))
        local tabs = BT:GetTabs(selBag) or {}
        for i, r in ipairs(self.rows) do
            local def = tabs[i]
            if def then
                r.def, r.idx = def, i
                local icon, color = BT:TabIcon(def)
                r.icon:SetTexture(icon)
                r.name:SetText(BT:TabName(def) .. (def.exclusive and "  |cffff9933(exclusive)|r" or "")); r.name:SetTextColor(color[1], color[2], color[3])
                local full = BT:CatList(def.cats)
                r.cats:SetText(#full > 58 and (full:sub(1, 56) .. "...") or full)      -- everything is in the tooltip
                r:Show()
            else
                r:Hide()
            end
        end
        if #tabs == 0 then self.empty:Show() else self.empty:Hide() end
        self.add:ClearAllPoints()
        self.add:SetPoint("TOPLEFT", 142, -62 - math.max(#tabs, 1) * 34 - 4)
        self.clear:ClearAllPoints()
        self.clear:SetPoint("LEFT", self.add, "RIGHT", 6, 0)
        if #tabs >= BT.MAX_TABS then self.add:Disable() else self.add:Enable() end
        if #tabs == 0 then self.clear:Disable() else self.clear:Enable() end
    end
end

-- ============================================================ page: Organize
local function BuildOrganizePage(page)
    local db = BT.db
    local widgets = {}
    local function add(w) widgets[#widgets + 1] = w; return w end

    add(Check(page, 300, 0, "Merge loose stacks automatically",
        function() return db.autoMerge end, function(v) db.autoMerge = v end))
    add(Check(page, 0, 0, "Route new items into their tab's bag",
        function() return db.routing end, function(v) db.routing = v end))
    add(Check(page, 0, -24, "Re-sort a bag after items moved in",
        function() return db.sortAfter end, function(v) db.sortAfter = v end))
    add(Check(page, 0, -48, "Show the + tab on every bag",
        function() return db.showPlus end, function(v) db.showPlus = v; BT:RefreshTabs() end))
    add(Check(page, 0, -72, "Fade tabs in when a bag opens",
        function() return db.anim end, function(v) db.anim = v end))
    add(Check(page, 300, -24, "Warehouse info in item tooltips",
        function() return db.tooltip end, function(v) db.tooltip = v end))
    add(Check(page, 300, -48, "Print routing decisions in chat",
        function() return db.debug end, function(v) db.debug = v end))
    add(Check(page, 0, -96, "Show an item's category in its tooltip",
        function() return db.catTooltip end, function(v) db.catTooltip = v end))
    add(Check(page, 300, -96, "\"Sort All\" button on the backpack",
        function() return db.sortButton end, function(v) db.sortButton = v; for i = 1, (NUM_CONTAINER_FRAMES or 13) do local f = _G["ContainerFrame" .. i]; if f and f:GetID() == 0 then BT:UpdateSortButton(f) end end end))
    add(Check(page, 0, -120, "Upgrade hint (!) on the character window",
        function() return db.upgradeHint end, function(v) db.upgradeHint = v; if BT.Upgrades then BT.Upgrades:Kick() end end))
    add(Check(page, 300, -72, "Mark ignored items in your bags",
        function() return db.ignoreMark end, function(v) db.ignoreMark = v; BT:RefreshTabs() end))

    add(Cycle(page, 0, -152, 190, "Sort bags by (after item type)",
        function() return BT.SORTMODES end, function() return db.sortMode end, function(k) db.sortMode = k end))
    add(Cycle(page, 205, -152, 100, "Tab side",
        function() return { { key = "LEFT", label = "Left" }, { key = "RIGHT", label = "Right" } } end,
        function() return db.side end,
        function(k) db.side = k; if updateContainerFrameAnchors then updateContainerFrameAnchors() end; BT:RefreshTabs() end))
    add(Cycle(page, 320, -152, 150, "Shift-click on the + tab opens",
        function() return { { key = "last", label = "Last used page" }, { key = "warehouse", label = "Warehouse" } } end,
        function() return db.optOpen end, function(k) db.optOpen = k end))

    local sl = CreateFrame("Slider", "InventoryPlusDimSlider", page, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", 8, -216); sl:SetWidth(210)
    sl:SetMinMaxValues(0.05, 0.6); sl:SetValueStep(0.05)
    _G["InventoryPlusDimSliderLow"]:SetText("dark"); _G["InventoryPlusDimSliderHigh"]:SetText("faint")
    _G["InventoryPlusDimSliderText"]:SetText("Dimmed item opacity on hover")
    sl:SetScript("OnValueChanged", function(self, v) db.dimAlpha = math.floor(v * 100 + 0.5) / 100 end)
    sl.Refresh = function() sl:SetValue(db.dimAlpha) end
    add(sl)

    -- sorting speed: the pause between two moves (the server needs a moment per move; faster can stumble on lag)
    local sp = CreateFrame("Slider", "InventoryPlusSpeedSlider", page, "OptionsSliderTemplate")
    sp:SetPoint("TOPLEFT", 238, -216); sp:SetWidth(210)
    sp:SetMinMaxValues(0.05, 0.8); sp:SetValueStep(0.05)
    _G["InventoryPlusSpeedSliderLow"]:SetText("fast"); _G["InventoryPlusSpeedSliderHigh"]:SetText("slow")
    local function speedText(v)
        local t = db.opAuto and "Sorting speed: set by the server" or string.format("Sorting speed: pause %.2f s per move", v)
        _G["InventoryPlusSpeedSliderText"]:SetText(t)
        sp:SetAlpha(db.opAuto and 0.4 or 1)
        if db.opAuto then sp:Disable() else sp:Enable() end
    end
    sp:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v * 20 + 0.5) / 20
        db.opDelay = v
        speedText(v)
    end)
    sp.Refresh = function() sp:SetValue(db.opDelay or 0.3); speedText(db.opDelay or 0.3) end
    add(sp)
    add(Check(page, 230, -240, "Follow the server's speed",
        function() return db.opAuto end, function(v) db.opAuto = v; speedText(db.opDelay or 0.3) end))

    local b2 = Button(page, "Sort tabbed bags", 120, 24)
    b2:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 4)
    local b1 = Button(page, "Organize all now", 130, 24)
    b1:SetPoint("RIGHT", b2, "LEFT", -6, 0)
    b1:SetScript("OnClick", function() BT:OrganizeAll() end)
    b2:SetScript("OnClick", function()
        BT:After(function() BT:SortTabbed("inv") end)
        if BT.bankOpen then BT:After(function() BT:SortTabbed("bank") end) end
        BT:Kick()
    end)

    local rt = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rt:SetPoint("TOPLEFT", 0, -256); rt:SetText("Where each item type goes")
    page.routeL = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.routeL:SetPoint("TOPLEFT", 0, -276); page.routeL:SetWidth(350)
    page.routeL:SetJustifyH("LEFT"); page.routeL:SetJustifyV("TOP")
    page.routeR = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.routeR:SetPoint("TOPLEFT", 370, -276); page.routeR:SetWidth(350)
    page.routeR:SetJustifyH("LEFT"); page.routeR:SetJustifyV("TOP")

    function page:Refresh()
        for _, w in ipairs(widgets) do if w.Refresh then w.Refresh(w) end end
        local lines = {}
        for _, c in ipairs(BT.CATS) do
            local owners = BT:Owners(c.key, "inv", true)
            if #owners > 0 then
                local names = {}
                for _, b in ipairs(owners) do names[#names + 1] = BT:BagLabel(b) .. (BT:IsExclusive(b) and "*" or "") end
                lines[#lines + 1] = c.full .. "  >  " .. table.concat(names, ", ")
            end
        end
        if #lines == 0 then
            self.routeL:SetText("No tabs set up yet. Open the Tabs page, or click the + on a bag.")
            self.routeR:SetText("")
        else
            lines[#lines + 1] = "|cff999999* exclusive bag|r"
            local half = math.ceil(#lines / 2)
            local l, r = {}, {}
            for i, line in ipairs(lines) do if i <= half then l[#l + 1] = line else r[#r + 1] = line end end
            self.routeL:SetText(table.concat(l, "\n"))
            self.routeR:SetText(table.concat(r, "\n"))
        end
    end
end

-- ============================================================ page: Advanced
local function BuildAdvancedPage(page)
    local db = BT.db
    local widgets = {}
    local function add(w) widgets[#widgets + 1] = w; return w end
    local function ReAnchor() if updateContainerFrameAnchors then pcall(updateContainerFrameAnchors) end end

    local h = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 0, 0); h:SetText("Bag layout")
    local info = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 0, -20); info:SetWidth(640); info:SetJustifyH("LEFT")
    info:SetText("Blizzard places the open bags in columns. Switch the manual layout on to take over the horizontal spacing "
        .. "between those columns, for instance so the side tabs don't sit on the next bag. Only columns are moved; "
        .. "the first column and the vertical positions stay as Blizzard has them.")

    local sliders = {}
    local function Dim()
        for _, w in ipairs(sliders) do
            w:SetAlpha(db.manualLayout and 1 or 0.4)
            if db.manualLayout then w:Enable() else w:Disable() end
        end
        if page.anchorBtn then
            if db.manualLayout then page.anchorBtn:Enable() else page.anchorBtn:Disable() end
        end
    end

    add(Check(page, 0, -66, "Manual bag layout (overrides Blizzard's column spacing)",
        function() return db.manualLayout end,
        function(v) db.manualLayout = v; Dim(); ReAnchor() end))

    local anchorBtn, anchorLbl = Cycle(page, 0, -104, 230, "Anchor",
        function() return { { key = "blizzard", label = "Blizzard's own" }, { key = "BOTTOMRIGHT", label = "Bottom right of the screen" } } end,
        function() return db.colAnchor end,
        function(k) db.colAnchor = k; ReAnchor() end)
    page.anchorBtn = anchorBtn
    add(anchorBtn)

    local gs = CreateFrame("Slider", "InventoryPlusGapSlider", page, "OptionsSliderTemplate")
    gs:SetPoint("TOPLEFT", 8, -178); gs:SetWidth(260)
    gs:SetMinMaxValues(0, 80); gs:SetValueStep(2)
    _G["InventoryPlusGapSliderLow"]:SetText("0"); _G["InventoryPlusGapSliderHigh"]:SetText("80")
    local function gapText(v) _G["InventoryPlusGapSliderText"]:SetText(string.format("Extra space per bag column: %d px", v)) end
    gs:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 2 + 0.5) * 2
        db.colGap = v; gapText(v)
        if self.ready then ReAnchor() end
    end)
    gs.Refresh = function() gs.ready = false; gs:SetValue(db.colGap or 0); gapText(db.colGap or 0); gs.ready = true end
    add(gs); sliders[#sliders + 1] = gs

    local ws = CreateFrame("Slider", "InventoryPlusColWidthSlider", page, "OptionsSliderTemplate")
    ws:SetPoint("TOPLEFT", 8, -232); ws:SetWidth(260)
    ws:SetMinMaxValues(0, 400); ws:SetValueStep(5)
    _G["InventoryPlusColWidthSliderLow"]:SetText("auto"); _G["InventoryPlusColWidthSliderHigh"]:SetText("400")
    local function widthText(v)
        _G["InventoryPlusColWidthSliderText"]:SetText(v < 150 and "Column width: Blizzard's" or string.format("Column width: %d px (fixed)", v))
    end
    ws:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 5 + 0.5) * 5
        if v > 0 and v < 150 then v = (v < 75) and 0 or 150 end    -- below 150 px bags would overlap: snap
        db.colWidth = v; widthText(v)
        if self.ready then ReAnchor() end
    end)
    ws.Refresh = function() ws.ready = false; ws:SetValue(db.colWidth or 0); widthText(db.colWidth or 0); ws.ready = true end
    add(ws); sliders[#sliders + 1] = ws

    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 0, -270); note:SetWidth(640); note:SetJustifyH("LEFT")
    note:SetText("A fixed column width wins over the extra space. \"Bottom right\" re-anchors every open bag to the bottom right corner of the screen, "
        .. "at the spot Blizzard gave it.")

    function page:Refresh()
        for _, w in ipairs(widgets) do if w.Refresh then w.Refresh(w) end end
        Dim()
    end
end

-- ============================================================ page: Junk
local function BuildJunkPage(page)
    local db = BT.db
    local widgets = {}
    local function add(w) widgets[#widgets + 1] = w; return w end

    local warn = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warn:SetPoint("TOPLEFT", 0, 0); warn:SetWidth(580); warn:SetJustifyH("LEFT")
    warn:SetText("Cheap grey items are destroyed the moment you loot them. This cannot be undone.")

    add(Check(page, 0, -28, "Delete looted grey (poor quality) items worth less than the limit below",
        function() return db.junkDelete end, function(v) db.junkDelete = v end))
    add(Check(page, 0, -52, "Say in chat what was deleted",
        function() return db.junkReport end, function(v) db.junkReport = v end))

    local lbl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 4, -92); lbl:SetText("Limit")
    local eb = CreateFrame("EditBox", "InventoryPlusJunkLimit", page, "InputBoxTemplate")
    eb:SetWidth(110); eb:SetHeight(20); eb:SetAutoFocus(false)
    eb:SetPoint("LEFT", lbl, "RIGHT", 14, 0)
    eb.Refresh = function() eb:SetText(BT:Money(db.junkMax, "")) end
    local function apply()
        local v = BT:ParseMoney(eb:GetText())
        if v and v <= 100000000 then db.junkMax = v else BT:Print("could not read that amount, use e.g. 10g34s10c") end
        eb.Refresh()
    end
    eb:SetScript("OnEnterPressed", function(s) apply(); s:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", apply)
    eb:SetScript("OnEscapePressed", function(s) eb.Refresh(); s:ClearFocus() end)
    add(eb)
    add(Cycle(page, 270, -78, 130, "Compare the limit against",
        function() return { { key = "item", label = "Each item" }, { key = "stack", label = "Whole stack" } } end,
        function() return db.junkMode end, function(k) db.junkMode = k end))
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 4, -124); hint:SetWidth(580); hint:SetJustifyH("LEFT")
    hint:SetText("Amount syntax: 10g34s10c (gold, silver, copper; any part can be left out, e.g. 1s or 50c; a bare number counts as copper). Only fresh loot is touched: items taken from the bank, mail or a vendor are never deleted, and neither are quest items.")

    add(Check(page, 0, -170, "Warlock: destroy Soul Shards above the limit below",
        function() return db.shardDelete end, function(v) db.shardDelete = v end))
    local kl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    kl:SetPoint("TOPLEFT", 28, -202); kl:SetText("Keep at most")
    local sb = CreateFrame("EditBox", "InventoryPlusShardLimit", page, "InputBoxTemplate")
    sb:SetWidth(44); sb:SetHeight(20); sb:SetAutoFocus(false)
    sb:SetPoint("LEFT", kl, "RIGHT", 12, 0)
    sb.Refresh = function() sb:SetText(tostring(db.shardMax)) end
    local function applyShards()
        local v = tonumber(sb:GetText())
        if v and v >= 0 and v <= 500 then db.shardMax = math.floor(v) end
        sb.Refresh()
    end
    sb:SetScript("OnEnterPressed", function(s) applyShards(); s:ClearFocus() end)
    sb:SetScript("OnEditFocusLost", applyShards)
    sb:SetScript("OnEscapePressed", function(s) sb.Refresh(); s:ClearFocus() end)
    add(sb)
    local kn = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    kn:SetPoint("LEFT", sb, "RIGHT", 10, 0); kn:SetWidth(420); kn:SetJustifyH("LEFT")
    kn:SetText("Soul Shards in your bags. The surplus is destroyed from the last slots. Only on a Warlock; ignored shards are kept.")

    local lt = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lt:SetPoint("TOPLEFT", 0, -232); lt:SetText("Recently deleted")
    page.log = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.log:SetPoint("TOPLEFT", 0, -252); page.log:SetWidth(580)
    page.log:SetJustifyH("LEFT"); page.log:SetJustifyV("TOP")

    function page:Refresh()
        for _, w in ipairs(widgets) do if w.Refresh then w.Refresh(w) end end
        local out = {}
        for i, e in ipairs(db.junkLog) do
            if i > 8 then break end
            out[#out + 1] = tostring(e.link) .. ((e.count or 1) > 1 and (" x" .. e.count) or "") ..
                "   " .. (e.reason == "excess" and "excess" or BT:Money(e.value))
        end
        self.log:SetText(#out > 0 and table.concat(out, "\n") or "Nothing deleted yet.")
    end
end

-- ============================================================ page: Ignore
local IGN_COLS, IGN_ROWS, IGN_SIZE = 12, 4, 40

local function ItemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size); b:SetHeight(size)
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    return b
end

local function BuildIgnorePage(page)
    local info = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 0, 0); info:SetWidth(580); info:SetJustifyH("LEFT")
    info:SetText("Items on this list are never moved, sorted around, routed or deleted. They keep their slot (a Hearthstone, your totems...) and everything else is arranged around them.")

    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOPLEFT", 0, -50)
    hint:SetText("Alt-click an item in your bags to add or remove it, or drop an item on the box.")

    local drop = CreateFrame("Button", nil, page)
    drop:SetWidth(120); drop:SetHeight(44); drop:SetPoint("TOPLEFT", 0, -76)
    drop:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                       tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    drop:SetBackdropColor(0.1, 0.1, 0.12, 0.9); drop:SetBackdropBorderColor(0.7, 0.6, 0.2, 1)
    local dt = drop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dt:SetPoint("CENTER"); dt:SetText("Drop an item here")
    drop:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function take()
        local kind, id = GetCursorInfo()
        if kind == "item" and id then
            BT:SetIgnored(id, true)
            ClearCursor()
        end
    end
    drop:SetScript("OnClick", take)
    drop:SetScript("OnReceiveDrag", take)

    local clear = Button(page, "Clear list", 90, 22)
    clear:SetPoint("LEFT", drop, "RIGHT", 10, 0)
    clear:SetScript("OnClick", function() wipe(BT.db.ignore); BT:OnIgnoreChanged() end)

    local lt = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lt:SetPoint("TOPLEFT", 0, -134); lt:SetText("Ignored items  (right-click to remove)")

    page.btns = {}
    for i = 1, IGN_COLS * IGN_ROWS do
        local b = ItemButton(page, IGN_SIZE)
        local col, row = (i - 1) % IGN_COLS, math.floor((i - 1) / IGN_COLS)
        b:SetPoint("TOPLEFT", col * (IGN_SIZE + 6), -156 - row * (IGN_SIZE + 6))
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then BT:SetIgnored(self.id, false) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            BT.WH.suppress = true
            GameTooltip:SetHyperlink("item:" .. self.id)
            BT.WH.suppress = false
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Right-click: stop ignoring", 0.5, 0.8, 0.5)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page.btns[i] = b
    end
    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.empty:SetPoint("TOPLEFT", 0, -160); page.empty:SetText("Nothing ignored yet.")

    function page:Refresh()
        local ids = {}
        for id in pairs(BT.db.ignore) do ids[#ids + 1] = id end
        table.sort(ids)
        for i, b in ipairs(self.btns) do
            local id = ids[i]
            if id then
                local name, _, q, _, _, _, _, _, _, icon = GetItemInfo(id)
                local known = BT.db.items[id]
                b.id = id
                b.icon:SetTexture(icon or (known and known.i) or "Interface\\Icons\\INV_Misc_QuestionMark")
                local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or (known and known.q) or 1]
                if qc then b:SetBackdropBorderColor(qc.r, qc.g, qc.b, 1) end
                b:Show()
            else
                b:Hide()
            end
        end
        if #ids == 0 then self.empty:Show() else self.empty:Hide() end
    end
end

-- ============================================================ page: Warehouse (one section per character)
local GRID_COLS, GRID_ROWS, CELL, GAP = 15, 9, 32, 4      -- uses the full width of the DreamSuite window
local LINE_H = CELL + GAP
local TREE_ROWS, TREE_H = 21, 16
local whText, whClass, whSub = "", nil, nil
local treeOffset = 0

-- hover info for an icon: the item, this character's share, and who else has it
local function ShowCellTip(cell)
    local e, sec = cell.entry, cell.sec
    if not e then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    BT.WH.suppress = true
    GameTooltip:SetHyperlink("item:" .. e.id)
    BT.WH.suppress = false
    GameTooltip:AddLine(" ")
    BT.WH:AddHolderLines(GameTooltip, { { key = sec.key, rec = sec.rec, b = e.b, k = e.k, e = e.e } })
    local others = BT.WH:Holders(e.id, sec.key)
    if #others > 0 then
        GameTooltip:AddLine("Also on", 0.55, 0.8, 1)
        BT.WH:AddHolderLines(GameTooltip, others)
    end
    GameTooltip:Show()
end

local function BuildWarehousePage(page)
    local lbl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 0, -4); lbl:SetText("Search")
    page.search = CreateFrame("EditBox", "InventoryPlusWHSearch", page, "InputBoxTemplate")
    page.search:SetWidth(300); page.search:SetHeight(20); page.search:SetAutoFocus(false)
    page.search:SetPoint("TOPLEFT", 56, 0)
    page.search:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    page.search:SetScript("OnTextChanged", function(s) whText = s:GetText() or ""; page:Update() end)

    -- left: auction-house style category tree
    local tree = CreateFrame("Frame", nil, page)
    tree:SetWidth(150); tree:SetHeight(TREE_ROWS * TREE_H); tree:SetPoint("TOPLEFT", 0, -30)
    tree:EnableMouseWheel(true)
    tree:SetScript("OnMouseWheel", function(_, delta)
        treeOffset = math.max(0, treeOffset - delta * 3); page:Update()
    end)
    page.treeRows = {}
    for i = 1, TREE_ROWS do
        local r = CreateFrame("Button", nil, tree)
        r:SetWidth(150); r:SetHeight(TREE_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * TREE_H)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 4, 0); r.text:SetWidth(142); r.text:SetJustifyH("LEFT")
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r:SetScript("OnClick", function(self)
            local class, sub = self.class, self.sub
            if class == whClass and sub == whSub then return end
            page:Crossfade(function() whClass, whSub = class, sub; page:Update() end)
        end)
        r:SetScript("OnEnter", function(self)
            if self.class then page.hoverClass, page.hoverSub = self.class, self.sub else page.hoverClass, page.hoverSub = nil, nil end
            page:ApplyHover()
        end)
        r:SetScript("OnLeave", function()
            page.hoverClass, page.hoverSub = nil, nil
            page:ApplyHover()
        end)
        page.treeRows[i] = r
    end

    -- right: scrolling list of lines; a line is either a character header or a row of item icons
    local sf = CreateFrame("ScrollFrame", "InventoryPlusWHScroll", page, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 162, -30); sf:SetWidth(GRID_COLS * LINE_H); sf:SetHeight(GRID_ROWS * LINE_H)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LINE_H, function() page:Update() end)
    end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local sb = _G["InventoryPlusWHScrollScrollBar"]
        sb:SetValue(sb:GetValue() - delta * LINE_H * 2)
    end)
    page.scroll = sf

    page.lines = {}
    for i = 1, GRID_ROWS do
        local ln = CreateFrame("Frame", nil, page)
        ln:SetWidth(GRID_COLS * LINE_H); ln:SetHeight(LINE_H)
        ln:SetPoint("TOPLEFT", 162, -30 - (i - 1) * LINE_H)

        local hd = CreateFrame("Button", nil, ln)
        hd:SetAllPoints(ln)
        hd:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        hd.arrow = hd:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        hd.arrow:SetPoint("LEFT", 4, 0); hd.arrow:SetWidth(14)
        hd.text = hd:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hd.text:SetPoint("LEFT", 24, 0); hd.text:SetWidth(GRID_COLS * LINE_H - 30); hd.text:SetJustifyH("LEFT")
        hd.rule = hd:CreateTexture(nil, "ARTWORK")
        hd.rule:SetHeight(1)
        hd.rule:SetPoint("BOTTOMLEFT", 0, 3); hd.rule:SetPoint("BOTTOMRIGHT", 0, 3)
        hd.rule:SetTexture(1, 1, 1, 0.15)
        hd:SetScript("OnClick", function(self)
            BT.db.whCollapsed[self.key] = (not BT.db.whCollapsed[self.key]) or nil
            page:Update()
        end)
        ln.head = hd

        ln.cells = {}
        for c = 1, GRID_COLS do
            local cell = ItemButton(ln, CELL)
            cell:SetPoint("TOPLEFT", (c - 1) * LINE_H, -2)
            cell:SetScript("OnEnter", ShowCellTip)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cell:SetScript("OnClick", function(self)
                if self.entry and IsShiftKeyDown() and ChatEdit_InsertLink then
                    local _, link = GetItemInfo(self.entry.id)
                    if link then ChatEdit_InsertLink(link) end
                end
            end)
            ln.cells[c] = cell
        end
        page.lines[i] = ln
    end

    page.info = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.info:SetPoint("BOTTOMLEFT", 0, 0)
    page.info:SetWidth(720); page.info:SetHeight(12); page.info:SetJustifyH("LEFT")

    -- hovering a category (or sub-category) in the tree: its items stay bright, the rest dims
    function page:ApplyHover()
        local hc, hs = self.hoverClass, self.hoverSub
        for _, ln in ipairs(self.lines) do
            for _, cell in ipairs(ln.cells) do
                local e = cell.entry
                local a = 1
                if hc and e then
                    if not (e.t == hc and (not hs or e.s == hs)) then a = 0.18 end
                end
                cell:SetAlpha(a)
            end
        end
    end

    -- picking a category: the list fades out, switches, and fades back in
    local fx = CreateFrame("Frame", nil, page)
    local function SetGridAlpha(a) for _, ln in ipairs(page.lines) do ln:SetAlpha(a) end end
    page:SetScript("OnShow", function() fx:SetScript("OnUpdate", nil); SetGridAlpha(1) end)
    function page:Crossfade(change)
        if not self:IsShown() then change(); return end
        local t, switched = 0, false
        fx:SetScript("OnUpdate", function(f, e)
            t = t + e
            if not switched then
                SetGridAlpha(math.max(0, 1 - t / 0.09))
                if t >= 0.09 then switched = true; t = 0; change() end
            else
                local a = math.min(1, t / 0.14)
                SetGridAlpha(a)
                if a >= 1 then f:SetScript("OnUpdate", nil) end
            end
        end)
    end

    function page:Update()
        -- category tree: "All items", then classes; the selected class opens into its subclasses
        local rows = { { text = "All items", on = (whClass == nil) } }
        for _, c in ipairs(BT.WH:Tree()) do
            rows[#rows + 1] = { text = c.name .. "  |cff888888" .. c.count .. "|r", class = c.name, on = (whClass == c.name and not whSub) }
            if whClass == c.name then
                for _, s in ipairs(c.subs) do
                    rows[#rows + 1] = { text = "    " .. s.name .. "  |cff888888" .. s.count .. "|r", class = c.name, sub = s.name,
                                        on = (whSub == s.name) }
                end
            end
        end
        treeOffset = math.min(treeOffset, math.max(0, #rows - TREE_ROWS))
        for i, r in ipairs(self.treeRows) do
            local d = rows[i + treeOffset]
            if d then
                r.class, r.sub = d.class, d.sub
                r.text:SetText(d.text)
                if d.on then r.text:SetTextColor(1, 0.82, 0) else r.text:SetTextColor(1, 1, 1) end
                r:Show()
            else
                r:Hide()
            end
        end

        -- lines: a header per character, followed by that character's icon rows unless it is minimised
        local sections = BT.WH:Sections(whText, whClass, whSub)
        local list = {}
        for _, sec in ipairs(sections) do
            list[#list + 1] = { head = sec }
            if not BT.db.whCollapsed[sec.key] then
                for from = 1, #sec.items, GRID_COLS do list[#list + 1] = { sec = sec, from = from } end
            end
        end
        FauxScrollFrame_Update(self.scroll, #list, GRID_ROWS, LINE_H)
        local off = FauxScrollFrame_GetOffset(self.scroll)
        local filtered = whClass ~= nil
        for i, ln in ipairs(self.lines) do
            local d = list[i + off]
            if not d then
                ln:Hide()
            elseif d.head then
                local sec = d.head
                local hd = ln.head
                hd.key = sec.key
                hd:Show()
                hd.arrow:SetText(BT.db.whCollapsed[sec.key] and "+" or "-")
                local r, g, b = BT.WH.ClassColor(sec.rec.class)
                hd.text:SetTextColor(r, g, b)
                -- with a category picked, the number says how many of its items this character has
                hd.empty = BT.WH:Summary(sec.rec) == 0
                hd.text:SetText(BT.WH:CharName(sec.rec, sec.key) ..
                    ((filtered and #sec.items > 0) and ("  |cffffd100(" .. #sec.items .. ")|r") or "") ..
                    (hd.empty and "  |cff999999(nothing recorded yet - log in on this character once)|r" or ""))
                hd:SetAlpha((filtered and #sec.items == 0) and 0.45 or 1)
                for _, cell in ipairs(ln.cells) do cell.entry = nil; cell:Hide() end
                ln:Show()
            else
                ln.head:Hide()
                for c, cell in ipairs(ln.cells) do
                    local e = d.sec.items[d.from + c - 1]
                    if e then
                        cell.entry, cell.sec = e, d.sec
                        cell.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                        local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.q]
                        if qc then cell:SetBackdropBorderColor(qc.r, qc.g, qc.b, 1) end
                        cell.count:SetText(e.total > 1 and e.total or "")
                        cell:Show()
                    else
                        cell.entry = nil
                        cell:Hide()
                    end
                end
                ln:Show()
            end
        end
        self:ApplyHover()
        self.info:SetText(#sections == 0 and "No characters scanned yet." or
            (#sections .. " character(s). Click a name to minimise it. Bank contents refresh when you visit the bank."))
    end

    function page:Refresh() BT.WH:Scan(); self:Update() end
end

-- ============================================================ settings view (inside the DreamSuite window)
local forceInstant
local function SelectPage(key, instant)
    if not pages[key] then key = "tabs" end
    if tabs.current ~= key then                 -- the tab strip calls back in here with its own state set
        forceInstant = instant
        tabs:Select(key)
        forceInstant = nil
        return
    end
    local old = frame.current and pages[frame.current]
    frame.current = key
    DS.UI.Switch(pages, old, pages[key], instant or forceInstant)
    if pages[key].Refresh then pages[key]:Refresh() end
end

local function Build(body)
    frame = CreateFrame("Frame", "InventoryPlusView", body)
    frame:SetAllPoints(body)

    pages = {}
    O.pages = pages
    local defs = {
        { "tabs", "Tabs", BuildTabsPage },
        { "organize", "Organize", BuildOrganizePage },
        { "junk", "Auto-delete", BuildJunkPage },
        { "ignore", "Ignore", BuildIgnorePage },
        { "warehouse", "Warehouse", BuildWarehousePage },
        { "advanced", "Advanced", BuildAdvancedPage },
    }
    local tabDefs = {}
    for i, d in ipairs(defs) do tabDefs[i] = { d[1], d[2] } end
    tabs = DS.UI.Tabs(frame, tabDefs, function(key) SelectPage(key) end)
    tabs.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    tabs.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    for _, d in ipairs(defs) do
        local p = CreateFrame("Frame", nil, frame)
        p:SetPoint("TOPLEFT", 4, -36); p:SetPoint("BOTTOMRIGHT", -4, 0)
        d[3](p)
        p:Hide()
        pages[d[1]] = p
    end
end

-- the tab picker as a screen of its own inside the window: the page buttons and pages step aside
function O:Pick(bag, def)
    if not (frame and frame:IsShown()) then BT:ShowPicker(bag, def); return end
    tabs.frame:Hide()
    for _, p in pairs(pages) do DS.UI.HideNow(p) end
    BT:ShowPicker(bag, def, nil, frame)
end

function O:EndPick()
    if not (frame and tabs and pages) then return end
    tabs.frame:Show()
    local pg = pages[frame.current or "tabs"]
    if pg and frame:IsVisible() then
        pg:SetAlpha(1); pg:Show()
        if pg.Refresh then pg:Refresh() end
    end
end

-- the hub calls this each time the module's settings open
function M.embed(body)
    if not frame then Build(body) end
    frame:SetParent(body)
    frame:ClearAllPoints()
    frame:SetAllPoints(body)
    frame:Show()
    SelectPage(pendingPage or frame.current or "tabs", true)
    if pendingPage == "warehouse" and pendingArg then pages.warehouse.search:SetText(pendingArg) end
    pendingPage, pendingArg = nil, nil
    return frame
end

function M.release(f)
    if f then f:Hide() end
    if BT.HidePicker then BT:HidePicker() end
end

function O:Refresh()
    if frame and frame:IsShown() and pages[frame.current] and pages[frame.current].Refresh then
        pages[frame.current]:Refresh()
    end
end

-- page / arg / bag are optional: open the settings on a page (and search the warehouse, or pick a bag)
function O:Show(page, arg, bag)
    if bag then selBag = bag end
    if frame and frame:IsShown() then
        SelectPage(page or frame.current or "tabs")
        if page == "warehouse" and arg then pages.warehouse.search:SetText(arg) end
        return
    end
    pendingPage, pendingArg = page, arg
    DS.OpenSettings(M)
end

function O:Toggle() DS.OpenSettings(M) end

function BT:OnIgnoreChanged()
    if self.Options then self.Options:Refresh() end
    self:RefreshTabs()
end
