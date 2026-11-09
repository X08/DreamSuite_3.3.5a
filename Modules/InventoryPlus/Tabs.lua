--[[ InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
     Tabs: magnet tabs on the side of the default bag frames, "+" tab, category picker, hover highlight. ]]

local DS = DreamSuite
local BT = DS.InventoryPlusCore
local TAB_W, TAB_H, PLUS_W, GAP = 30, 30, 22, 3
local PAD, OVERLAP = 6, 3

-- every default bag frame (shown or not)
local function EachBagFrame(fn)
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f then fn(f) end
    end
end

-- fn(button, bag, slot) for every item button of a bag frame
local function EachItemButton(frame, fn)
    local bag, name = frame:GetID(), frame:GetName()
    for i = 1, (GetContainerNumSlots(bag) or 0) do
        local b = _G[name .. "Item" .. i]
        if b then fn(b, bag, b:GetID()) end
    end
end
local FADE_TIME = 0.25

-- ============================================================ geometry
-- offsets (frame-local units) of the item grid relative to the bag frame, measured live so it
-- works whatever the frame's real width/art offsets are.
local function Geometry(frame)
    local name = frame:GetName()
    local fl, ft, fr = frame:GetLeft(), frame:GetTop(), frame:GetRight()
    if not (fl and ft and fr) then return end
    local minL, maxR, maxT
    for i = 1, (GetContainerNumSlots(frame:GetID()) or 0) do
        local b = _G[name .. "Item" .. i]
        if b and b:IsShown() then
            local l, r, t = b:GetLeft(), b:GetRight(), b:GetTop()
            if l and r and t then
                minL = minL and math.min(minL, l) or l
                maxR = maxR and math.max(maxR, r) or r
                maxT = maxT and math.max(maxT, t) or t
            end
        end
    end
    if not minL then return end
    return minL - fl, maxR - fr, maxT - ft
end

-- ============================================================ tab buttons
local function CreateTabButton(holder)
    local b = CreateFrame("Button", nil, holder)
    b:SetWidth(TAB_W); b:SetHeight(TAB_H)
    b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER", 0, 0)
    b.icon:SetWidth(TAB_W - 10); b.icon:SetHeight(TAB_H - 10)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b:SetScript("OnEnter", function(self)
        if self.def then BT:SetHover(self.def.cats) end
        if self.isPlus and self.SetPlusColor then self:SetPlusColor(1, 0.95, 0.45) end
        GameTooltip:SetOwner(self, BT.db.side == "LEFT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        if self.isPlus then
            GameTooltip:AddLine("Add a tab", 1, 1, 1)
            GameTooltip:AddLine("Pick which item types belong in this bag.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Shift-click: open " .. (BT.db.optOpen == "warehouse" and "the Warehouse" or "the options"), 0.5, 0.8, 0.5)
        else
            GameTooltip:AddLine(BT:TabName(self.def), 1, 0.82, 0)
            GameTooltip:AddLine("Holds: " .. BT:CatList(self.def.cats), 0.8, 0.8, 0.8, true)
            if self.def.exclusive then
                GameTooltip:AddLine("Exclusive: other items are moved out of this bag", 1, 0.6, 0.3, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Left-click: gather items here and sort", 0.5, 0.8, 0.5)
            GameTooltip:AddLine("Shift-click: sort this bag only", 0.5, 0.8, 0.5)
            GameTooltip:AddLine("Right-click: edit tab", 0.5, 0.8, 0.5)
            GameTooltip:AddLine("Drag onto another bag: move the tab and its items", 0.5, 0.8, 0.5)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        BT:SetHover(nil)
        if self.isPlus and self.SetPlusColor then self:SetPlusColor(1, 0.82, 0) end
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self, button)
        if self.isPlus then
            if IsShiftKeyDown() then
                if BT.Options then
                    BT.Options:Show(BT.db.optOpen == "warehouse" and "warehouse" or nil, nil, self.bag)
                end
            else
                BT:ShowPicker(self.bag, nil, self)
            end
        elseif button == "RightButton" then
            BT:ShowPicker(self.bag, self.def, self)
        elseif IsShiftKeyDown() then
            BT:After(function() BT:SortBag(self.bag) end); BT:Kick()
        else
            BT:GatherTab(self.bag, self.def, true)
        end
    end)
    -- dragging a tab onto another bag moves it (the items follow)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.isPlus or not self.def then return end
        GameTooltip:Hide()
        BT:StartTabDrag(self)
    end)
    b:SetScript("OnDragStop", function(self) BT:StopTabDrag() end)
    return b
end

local function PlaceTab(b)
    b:ClearAllPoints()
    if BT.db.side == "LEFT" then
        b:SetPoint("TOPRIGHT", b.holderFrame, "TOPLEFT", b.baseX, b.baseY)
    else
        b:SetPoint("TOPLEFT", b.holderFrame, "TOPRIGHT", b.baseX, b.baseY)
    end
end

-- tabs fade in when a bag opens (or when a tab has just been moved onto a bag)
local function StartFade(h)
    h.animT = 0
    h:SetAlpha(0)
    h:SetScript("OnUpdate", h.OnAnim)
end

local function GetHolder(frame)
    if frame.btHolder then return frame.btHolder end
    local h = CreateFrame("Frame", nil, frame)
    h:SetAllPoints(frame)
    h:SetFrameLevel(frame:GetFrameLevel() + 6)
    h.tabs = {}
    h.animT = FADE_TIME
    h.OnAnim = function(self, elapsed)
        self.animT = self.animT + elapsed
        local p = math.min(1, self.animT / FADE_TIME)
        self:SetAlpha(p)
        if p >= 1 then self:SetScript("OnUpdate", nil) end
    end
    h:SetScript("OnShow", function(self)
        if BT.db and BT.db.anim then StartFade(self) else self:SetAlpha(1) end
    end)
    frame.btHolder = h
    return h
end

function BT:LayoutFrame(frame)
    if not frame or not self.db or not self.enabled then return end
    local bag = frame:GetID()
    local h = GetHolder(frame)
    if bag < 0 or bag > 11 or not self:IsUsableBag(bag) or not frame:IsShown() then h:Hide(); return end
    local xl, xr, yt = Geometry(frame)
    if not xl then h:Hide(); return end
    h:Show()
    local db = self.db
    local x = (db.side == "LEFT") and (xl - PAD + OVERLAP) or (xr + PAD - OVERLAP)
    x = x + db.offsetX
    local y = yt - 2 + db.offsetY
    local tabs = self:GetTabs(bag) or {}
    for i, def in ipairs(tabs) do
        local b = h.tabs[i]
        if not b then b = CreateTabButton(h); h.tabs[i] = b end
        b.holderFrame, b.bag, b.def, b.isPlus = frame, bag, def, false
        b:SetAlpha(1)
        local icon, color = self:TabIcon(def)
        b.icon:SetTexture(icon)
        b:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        b.count:SetText(self:CountInBag(bag, def.cats))
        b:SetWidth(TAB_W); b:SetHeight(TAB_H)
        b.baseX, b.baseY = x, y - (i - 1) * (TAB_H + GAP)
        PlaceTab(b)
        b:Show()
    end
    for i = #tabs + 1, #h.tabs do h.tabs[i]:Hide() end

    if db.showPlus and #tabs < BT.MAX_TABS then
        local pb = h.plus
        if not pb then pb = CreateTabButton(h); h.plus = pb end
        pb.holderFrame, pb.bag, pb.def, pb.isPlus = frame, bag, nil, true
        pb.icon:SetTexture(nil); pb.count:SetText("")
        if not pb.barH then      -- a thick golden plus, drawn from two bars (no texture file to go missing)
            pb.barH = pb:CreateTexture(nil, "ARTWORK")
            pb.barH:SetWidth(12); pb.barH:SetHeight(4); pb.barH:SetPoint("CENTER", 0, 0)
            pb.barV = pb:CreateTexture(nil, "ARTWORK")
            pb.barV:SetWidth(4); pb.barV:SetHeight(12); pb.barV:SetPoint("CENTER", 0, 0)
            pb.SetPlusColor = function(self, r, g, b)
                self.barH:SetTexture(r, g, b, 1); self.barV:SetTexture(r, g, b, 1)
            end
            pb:SetPlusColor(1, 0.82, 0)
        end
        pb:SetWidth(PLUS_W); pb:SetHeight(PLUS_W)
        pb:SetBackdropBorderColor(0.6, 0.5, 0.15, 1)
        pb.baseX = x + (db.side == "LEFT" and 2 or -2)
        pb.baseY = y - #tabs * (TAB_H + GAP)
        PlaceTab(pb)
        pb:Show()
    elseif h.plus then
        h.plus:Hide()
    end
end

function BT:RefreshTabs()
    if not self.enabled then return end
    EachBagFrame(function(f)
        if f:IsShown() then self:LayoutFrame(f); self:MarkFrame(f) end
    end)
    self:ApplyHighlight()
end

-- ============================================================ hover highlight / dim
BT.hoverCats = nil

local function GlowFor(btn)
    if btn.btGlow then return btn.btGlow end
    local g = btn:CreateTexture(nil, "OVERLAY")
    g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER", btn, "CENTER", 0, 0)
    g:SetWidth(btn:GetWidth() * 1.85); g:SetHeight(btn:GetHeight() * 1.85)
    g:Hide()
    btn.btGlow = g
    return g
end

local function ApplyButton(btn, bag, slot)
    local cats = BT.hoverCats
    if not cats then
        btn:SetAlpha(1)
        if btn.btGlow then btn.btGlow:Hide() end
        return
    end
    local link = GetContainerItemLink(bag, slot)
    local cat = link and BT:Classify(link, bag, slot)
    if cat and BT:Matches(cats, cat) then
        btn:SetAlpha(1)
        local g = GlowFor(btn)
        local c = BT.CAT[cat].color
        g:SetVertexColor(c[1], c[2], c[3], 0.9)
        g:Show()
    else
        btn:SetAlpha(BT.db.dimAlpha)
        if btn.btGlow then btn.btGlow:Hide() end
    end
end

-- tiny gold pin on ignored items
local function MarkButton(btn, bag, slot)
    local link = BT.db.ignoreMark and GetContainerItemLink(bag, slot)
    if link and BT:IsIgnored(link) then
        if not btn.ipMark then
            local m = btn:CreateTexture(nil, "OVERLAY")
            m:SetWidth(7); m:SetHeight(7); m:SetPoint("TOPLEFT", 3, -3)
            m:SetTexture(1, 0.82, 0, 0.95)
            btn.ipMark = m
        end
        btn.ipMark:Show()
    elseif btn.ipMark then
        btn.ipMark:Hide()
    end
end

function BT:MarkFrame(frame) EachItemButton(frame, MarkButton) end

local function ApplyFrame(frame) EachItemButton(frame, ApplyButton) end

function BT:ApplyHighlight()
    EachBagFrame(function(f) if f:IsShown() then ApplyFrame(f) end end)
    if BankFrame and BankFrame:IsShown() then
        for i = 1, (NUM_BANKGENERIC_SLOTS or 28) do
            local b = _G["BankFrameItem" .. i]
            if b then ApplyButton(b, -1, b:GetID()) end
        end
    end
end

function BT:SetHover(cats)
    self.hoverCats = cats
    self:ApplyHighlight()
end

-- ============================================================ category picker (add / edit a tab)
local picker
local PW, ROWS, COLS, ROWH, COLW = 404, 8, 2, 20, 186
local PTOP = -80

local TOPCATS = {}
for _, c in ipairs(BT.CATS) do if not c.parent then TOPCATS[#TOPCATS + 1] = c end end

-- the tab's categories live in p.cats: a ticked parent means "everything below it"; single sub-categories
-- can stand alone. These helpers keep that tidy so any mix can be ticked and unticked.
local function SubState(p, parent)
    local n = 0
    for _, sk in ipairs(BT.SUBS[parent]) do if p.cats[sk] then n = n + 1 end end
    return n, #BT.SUBS[parent]
end

local function FullyIn(p, key)
    if p.cats[key] then return true end
    if BT.SUBS[key] then
        local n, t = SubState(p, key)
        return n == t
    end
    return false
end

local function ToggleTop(p, key)
    local subs = BT.SUBS[key]
    if not subs then p.cats[key] = (not p.cats[key]) or nil; return end
    local was = FullyIn(p, key)
    for _, sk in ipairs(subs) do p.cats[sk] = nil end
    p.cats[key] = (not was) or nil
end

local function ToggleSub(p, sk)
    local parent = BT.PARENT[sk]
    if p.cats[parent] then                         -- the whole group was in: take just this one out
        p.cats[parent] = nil
        for _, k in ipairs(BT.SUBS[parent]) do p.cats[k] = (k ~= sk) or nil end
    else
        p.cats[sk] = (not p.cats[sk]) or nil
        local n, t = SubState(p, parent)
        if n == t then                             -- every sub-category ticked again = the whole group
            for _, k in ipairs(BT.SUBS[parent]) do p.cats[k] = nil end
            p.cats[parent] = true
        end
    end
end

local function SetRow(r, c, checked, count)
    r.catKey = c.key
    r.check:SetChecked(checked and true or false)
    r.label:SetText(c.label)
    r.label:SetTextColor(c.color[1], c.color[2], c.color[3])
    r.count:SetText(count or "")
    r:Show()
end

local function UpdatePicker(p)
    for i, r in ipairs(p.rows) do
        local c = TOPCATS[i]
        if c then
            local count
            if BT.SUBS[c.key] then
                local n, t = SubState(p, c.key)
                if not p.cats[c.key] and n > 0 and n < t then count = n .. "/" .. t end
                r.exp:Show()
            else
                r.exp:Hide()
            end
            SetRow(r, c, FullyIn(p, c.key), count)
        else
            r:Hide()
        end
    end
    local parent = p.subOf and BT.CAT[p.subOf]
    if parent then
        p.subTitle:SetText(parent.label)
        p.subTitle:SetTextColor(parent.color[1], parent.color[2], parent.color[3])
        local list = { { key = parent.key, label = "All " .. parent.label, color = parent.color, all = true } }
        for _, sk in ipairs(BT.SUBS[parent.key]) do list[#list + 1] = BT.CAT[sk] end
        for i, r in ipairs(p.subRows) do
            local c = list[i]
            if c then
                SetRow(r, c, c.all and FullyIn(p, c.key) or (not c.all and (p.cats[c.key] or p.cats[parent.key])))
                r.isAll = c.all
            else
                r:Hide()
            end
        end
    end
end

local PICKER_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}

local function Tip(cb, def, all)
    GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
    GameTooltip:AddLine(all and ("All " .. def.label) or def.full, def.color[1], def.color[2], def.color[3])
    if def.prof then GameTooltip:AddLine("Professions: " .. def.prof, 0.7, 0.7, 0.7, true) end
    GameTooltip:AddLine(def.hint or "", 0.9, 0.9, 0.9, true)
    if BT.SUBS[def.key] and not all then
        GameTooltip:AddLine("Ticking this includes all of its sub-categories. Click > to pick single ones.", 0.5, 0.8, 0.5, true)
    end
    GameTooltip:Show()
end

local function BuildRow(p, parentFrame, name, i, col, line, yTop)
    local r = CreateFrame("Frame", nil, parentFrame)
    r:SetWidth(COLW - 4); r:SetHeight(ROWH)
    r:SetPoint("TOPLEFT", col * COLW, yTop - line * ROWH)
    local cb = CreateFrame("CheckButton", name .. i, r, "UICheckButtonTemplate")
    cb:SetWidth(20); cb:SetHeight(20); cb:SetPoint("LEFT", 0, 0)
    cb:SetHitRectInsets(0, -110, 0, 0)          -- the label counts as part of the button
    cb.row = r
    r.check = cb
    r.label = _G[name .. i .. "Text"]
    r.label:SetFontObject(GameFontHighlightSmall)
    r.label:SetWidth(112)
    r.count = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.count:SetPoint("RIGHT", r, "RIGHT", -24, 0)
    cb:SetScript("OnEnter", function(self) local d = BT.CAT[self.row.catKey]; if d then Tip(self, d, self.row.isAll) end end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function BuildPicker()
    local p = CreateFrame("Frame", "InventoryPlusPicker", UIParent)
    p:SetWidth(PW); p:SetFrameStrata("DIALOG"); p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetBackdrop(PICKER_BACKDROP)
    p:Hide()
    -- inside the DreamSuite window the picker is a screen of its own: when it closes the pages come back
    p:SetScript("OnHide", function(self)
        if self.embedded then
            self.embedded = nil
            BT.pickClosedAt = GetTime()
            if BT.Options and BT.Options.EndPick then BT.Options:EndPick() end
        end
    end)
    tinsert(UISpecialFrames, "InventoryPlusPicker")
    p.cats = {}

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOP", 0, -14)

    local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 20, -36); lbl:SetText("Name (optional)")
    p.name = CreateFrame("EditBox", "InventoryPlusPickerName", p, "InputBoxTemplate")
    p.name:SetWidth(PW - 56); p.name:SetHeight(20); p.name:SetAutoFocus(false)
    p.name:SetPoint("TOPLEFT", 26, -50)
    p.name:SetMaxLetters(24)
    p.name:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    -- two views that crossfade: the categories, and the sub-categories of one of them
    local VW, VH = COLS * COLW, ROWS * ROWH
    p.main = CreateFrame("Frame", nil, p)
    p.main:SetWidth(VW); p.main:SetHeight(VH); p.main:SetPoint("TOPLEFT", 16, PTOP)
    p.sub = CreateFrame("Frame", nil, p)
    p.sub:SetWidth(VW); p.sub:SetHeight(VH); p.sub:SetPoint("TOPLEFT", 16, PTOP)
    p.sub:Hide()
    p.views = { p.main, p.sub }

    p.rows = {}
    for i = 1, #TOPCATS do
        local col, line = math.floor((i - 1) / ROWS), (i - 1) % ROWS        -- fills the left column first
        local r = BuildRow(p, p.main, "InventoryPlusPickerRow", i, col, line, 0)
        r.exp = CreateFrame("Button", nil, r)
        r.exp:SetWidth(22); r.exp:SetHeight(ROWH); r.exp:SetPoint("RIGHT", 0, 0)
        r.exp.text = r.exp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.exp.text:SetPoint("CENTER", 0, 0); r.exp.text:SetText(">")
        r.exp.row = r
        r.exp:SetScript("OnClick", function(self)
            p.subOf = self.row.catKey
            UpdatePicker(p)
            DS.UI.Switch(p.views, p.main, p.sub)
        end)
        r.exp:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Pick single sub-categories", 1, 0.82, 0); GameTooltip:Show()
        end)
        r.exp:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.check:SetScript("OnClick", function(self)
            ToggleTop(p, self.row.catKey)
            UpdatePicker(p)
        end)
        p.rows[i] = r
    end

    local back = CreateFrame("Button", nil, p.sub, "UIPanelButtonTemplate")
    back:SetWidth(64); back:SetHeight(20); back:SetPoint("TOPLEFT", 0, 0); back:SetText("Back")
    back:SetScript("OnClick", function()
        UpdatePicker(p)
        DS.UI.Switch(p.views, p.sub, p.main)
    end)
    p.subTitle = p.sub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    p.subTitle:SetPoint("LEFT", back, "RIGHT", 12, 0)
    local subHint = p.sub:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subHint:SetPoint("TOPLEFT", 0, -26); subHint:SetText("Untick one to leave it out; tick all again for the whole group.")
    p.subRows = {}
    local maxSubs = 0
    for _, subs in pairs(BT.SUBS) do maxSubs = math.max(maxSubs, #subs) end
    for i = 1, maxSubs + 1 do
        local col, line = math.floor((i - 1) / (ROWS - 3)), (i - 1) % (ROWS - 3)
        local r = BuildRow(p, p.sub, "InventoryPlusPickerSub", i, col, line, -44)
        r.check:SetScript("OnClick", function(self)
            if self.row.isAll then ToggleTop(p, self.row.catKey) else ToggleSub(p, self.row.catKey) end
            UpdatePicker(p)
        end)
        p.subRows[i] = r
    end

    local y = PTOP - VH - 6
    local function Opt(name, x, text, tipTitle, tipText)
        local cb = CreateFrame("CheckButton", name, p, "UICheckButtonTemplate")
        cb:SetWidth(22); cb:SetHeight(22); cb:SetPoint("TOPLEFT", x, y)
        cb:SetHitRectInsets(0, -140, 0, 0)
        local t = _G[name .. "Text"]
        t:SetText(text); t:SetFontObject(GameFontNormalSmall)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tipTitle, 1, 0.82, 0)
            GameTooltip:AddLine(tipText, 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return cb
    end
    p.excl = Opt("InventoryPlusPickerExclusive", 14, "Exclusive bag", "Exclusive bag",
        "Only the item types on this bag's tabs may live here. Everything else is moved to your other bags, which are filled first. Strangers only stay here when no other slot is free.")
    p.rev = Opt("InventoryPlusPickerReverse", 200, "Fill from the bottom", "Fill from the bottom",
        "Items of this tab are stored and sorted from the last slot of the bag upwards instead of from the first. Another tab on the same bag can fill from the top.")
    y = y - 28

    p.save = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.save:SetWidth(84); p.save:SetHeight(22); p.save:SetPoint("TOPLEFT", 16, y)
    p.remove = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.remove:SetWidth(84); p.remove:SetHeight(22); p.remove:SetPoint("LEFT", p.save, "RIGHT", 6, 0)
    p.remove:SetText("Remove")
    p.cancel = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.cancel:SetWidth(84); p.cancel:SetHeight(22); p.cancel:SetPoint("LEFT", p.remove, "RIGHT", 6, 0)
    p.cancel:SetText("Cancel")
    p:SetHeight(-y + 22 + 16)

    p.cancel:SetScript("OnClick", function() p:Hide() end)
    p.save:SetScript("OnClick", function()
        if not next(p.cats) then BT:Print("pick at least one item type"); return end
        local name = strtrim(p.name:GetText() or "")
        if name == "" then name = nil end
        local copy = {}
        for k in pairs(p.cats) do copy[k] = true end
        for k in pairs(copy) do                      -- a ticked parent already covers its sub-categories
            local par = BT.PARENT[k]
            if par and copy[par] then copy[k] = nil end
        end
        local excl = p.excl:GetChecked() and true or nil
        local rev = p.rev:GetChecked() and true or nil
        local resort = rev
        if p.def then
            resort = resort or p.def.reverse
            p.def.cats, p.def.name, p.def.exclusive, p.def.reverse = copy, name, excl, rev
        else
            local tabs = BT:GetTabs(p.bag, true)
            if #tabs >= BT.MAX_TABS then BT:Print("a bag can hold " .. BT.MAX_TABS .. " tabs"); return end
            tinsert(tabs, { cats = copy, name = name, exclusive = excl, reverse = rev })
        end
        p:Hide()
        BT:OnTabsChanged()
        if excl then BT:After(function() BT:CleanBag(p.bag) end) end
        if resort then BT:After(function() BT:SortBag(p.bag) end) end
        if excl or resort then BT:Kick() end
    end)
    p.remove:SetScript("OnClick", function()
        if p.def then
            local tabs = BT:GetTabs(p.bag)
            for i, d in ipairs(tabs) do if d == p.def then tremove(tabs, i); break end end
            if #tabs == 0 then BT.chardb.bags[p.bag] = nil end
        end
        p:Hide()
        BT:OnTabsChanged()
    end)
    return p
end

function BT:HidePicker() if picker then picker:Hide() end end

-- true while the picker is open as a screen inside the DreamSuite window, or in the instant after it
-- closed (Esc must close only the picker, not the window around it)
function BT:PickerSwallowsEsc()
    return (picker and picker.embedded and picker:IsShown()) or (BT.pickClosedAt and BT.pickClosedAt == GetTime())
end

-- embedIn: a frame of the DreamSuite window to show the picker in (instead of a popup next to the bag)
function BT:ShowPicker(bag, def, anchor, embedIn)
    picker = picker or BuildPicker()
    if picker:IsShown() and picker.embedded then picker.embedded = nil end      -- re-opened: no "closed" callback
    picker:SetParent(embedIn or UIParent)
    picker:SetFrameStrata(embedIn and embedIn:GetFrameStrata() or "DIALOG")
    picker:SetBackdrop(embedIn and nil or PICKER_BACKDROP)
    picker.embedded = embedIn and true or nil
    picker.bag, picker.def, picker.cats, picker.subOf = bag, def, {}, nil
    if def then
        for k in pairs(def.cats) do picker.cats[k] = true end
    end
    picker.excl:SetChecked(def and def.exclusive and true or false)
    picker.rev:SetChecked(def and def.reverse and true or false)
    picker.name:SetText(def and def.name or "")
    picker.title:SetText((def and "Edit tab" or "New tab") .. " - " .. self:BagLabel(bag))
    picker.save:SetText(def and "Save" or "Add")
    if def then picker.remove:Show() else picker.remove:Hide() end
    DS.UI.Switch(picker.views, picker.sub, picker.main, true)
    UpdatePicker(picker)
    picker:ClearAllPoints()
    if embedIn then
        picker:SetPoint("TOP", embedIn, "TOP", 0, -4)
    elseif anchor then
        if self.db.side == "LEFT" then picker:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
        else picker:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0) end
    else
        picker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    picker:Show()
end

-- ============================================================ dragging a tab to another bag
local ghost

local function ValidTarget(f)
    local d = BT.dragging
    if not d or not f or not f:IsShown() then return false end
    local bag = f:GetID()
    return bag ~= d.bag and BT:Domain(bag) == BT:Domain(d.bag) and BT:IsUsableBag(bag)
end

local function DropOverlay(f)
    local h = f.btHolder
    if not h then return end
    if not h.drop then
        h.drop = h:CreateTexture(nil, "OVERLAY")
        h.drop:SetAllPoints(f)
        h.drop:SetTexture(1, 0.82, 0, 0.18)
        h.drop:Hide()
    end
    return h.drop
end

local function TargetUnderMouse()
    local found
    EachBagFrame(function(f)
        if not found and ValidTarget(f) and MouseIsOver(f) then found = f end
    end)
    return found
end

-- another tab (same kind of bag) under the mouse: dropping on it offers to merge the two
local function TabUnderMouse()
    local d = BT.dragging
    if not d then return end
    local found
    EachBagFrame(function(f)
        local h = f.btHolder
        if found or not h or not f:IsShown() or not h:IsShown() then return end
        if BT:Domain(f:GetID()) ~= BT:Domain(d.bag) then return end
        for _, b in ipairs(h.tabs) do
            if b:IsShown() and b.def and not b.isPlus and b.def ~= d.def and MouseIsOver(b) then found = b; return end
        end
    end)
    return found
end

StaticPopupDialogs["INVENTORYPLUS_MERGE"] = {
    text = "Merge these two tabs into one new tab?\n%s\n\nName for the new tab (optional):",
    button1 = "Merge", button2 = CANCEL or "Cancel",
    hasEditBox = 1, maxLetters = 24,
    OnShow = function(self)
        local m = BT.mergeAsk
        self.editBox:SetText(m and m.suggest or "")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local m = BT.mergeAsk
        BT.mergeAsk = nil
        if m then BT:MergeTabs(m.a, m.abag, m.b, m.bbag, self.editBox:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local m = BT.mergeAsk
        BT.mergeAsk = nil
        if m then BT:MergeTabs(m.a, m.abag, m.b, m.bbag, self:GetText()) end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    OnCancel = function() BT.mergeAsk = nil end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function BT:AskMerge(a, abag, b, bbag)
    self.mergeAsk = { a = a, abag = abag, b = b, bbag = bbag, suggest = b.name or a.name }
    StaticPopup_Show("INVENTORYPLUS_MERGE", self:TabName(a) .. "  +  " .. self:TabName(b))
end

function BT:StartTabDrag(tab)
    if self.dragging then return end
    self.dragging = { def = tab.def, bag = tab.bag }
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP"); ghost:SetWidth(TAB_W); ghost:SetHeight(TAB_H)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
        ghost.icon:SetAllPoints(ghost); ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        ghost:SetScript("OnUpdate", function(self)
            local x, y = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
            local hot = TabUnderMouse()
            if hot ~= self.hot then
                if self.hot then self.hot:SetBackdropBorderColor(unpack(self.hotColor or { 1, 1, 1, 1 })) end
                self.hot = hot
                if hot then self.hotColor = { hot:GetBackdropBorderColor() }; hot:SetBackdropBorderColor(1, 1, 1, 1) end
            end
            local over = (not hot) and TargetUnderMouse() or nil
            EachBagFrame(function(f)
                local o = DropOverlay(f)
                if o then if f == over then o:Show() else o:Hide() end end
            end)
        end)
    end
    ghost.icon:SetTexture((BT:TabIcon(tab.def)))
    ghost:Show()
    tab:SetAlpha(0.35)
end

function BT:StopTabDrag()
    local d = self.dragging
    if not d then return end
    local hotTab = TabUnderMouse()
    local target = (not hotTab) and TargetUnderMouse() or nil
    if ghost and ghost.hot then ghost.hot:SetBackdropBorderColor(unpack(ghost.hotColor or { 1, 1, 1, 1 })); ghost.hot = nil end
    self.dragging = nil
    if ghost then ghost:Hide() end
    EachBagFrame(function(f)
        local o = f.btHolder and f.btHolder.drop
        if o then o:Hide() end
    end)
    if hotTab then
        self:AskMerge(d.def, d.bag, hotTab.def, hotTab.bag)
    elseif target and self:MoveTab(d.def, d.bag, target:GetID()) then
        for _, f in ipairs({ target }) do          -- let the tab snap onto its new bag
            if f.btHolder and self.db.anim then
                StartFade(f.btHolder)
            end
        end
    end
    self:RefreshTabs()
end

function BT:OnTabsChanged()
    self:RefreshTabs()
    if self.Options and self.Options.Refresh then self.Options:Refresh() end
end

-- switching off: no tab, glow, dim or mark is left on any bag or bank button
function BT:Teardown()
    self.hoverCats = nil
    self.dragging = nil
    if picker then picker:Hide() end
    if ghost then ghost:Hide() end
    EachBagFrame(function(f)
        if f.btSortAll then f.btSortAll:Hide(); if DS.BulkBagPlace then DS.BulkBagPlace(f) end end
        local h = f.btHolder
        if h then
            h:Hide()
            if h.drop then h.drop:Hide() end
        end
        EachItemButton(f, function(btn)
            btn:SetAlpha(1)
            if btn.btGlow then btn.btGlow:Hide() end
            if btn.ipMark then btn.ipMark:Hide() end
        end)
    end)
    for i = 1, (NUM_BANKGENERIC_SLOTS or 28) do
        local b = _G["BankFrameItem" .. i]
        if b then
            b:SetAlpha(1)
            if b.btGlow then b.btGlow:Hide() end
        end
    end
end


-- ============================================================ "Sort All" button on the backpack
-- sits in the small gap between the title and the first row of items
local function UpdateSortButton(frame)
    local self = BT
    if not frame or frame:GetID() ~= 0 then return end
    local btn = frame.btSortAll
    if not (self.enabled and self.db and self.db.sortButton and frame:IsShown()) then
        if btn then btn:Hide() end
        return
    end
    local name = frame:GetName()
    local top, topBtn
    for i = 1, (GetContainerNumSlots(0) or 0) do
        local b = _G[name .. "Item" .. i]
        if b and b:IsShown() then
            local t, r = b:GetTop(), b:GetRight()
            if t and r and (not top or t > top + 1 or (math.abs(t - top) <= 1 and r > topBtn:GetRight())) then
                top, topBtn = t, b
            end
        end
    end
    if not topBtn then if btn then btn:Hide() end return end
    if not btn then
        btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetWidth(58); btn:SetHeight(16)
        btn:SetText("Sort All")
        local fs = btn:GetFontString()
        if fs and fs.SetFontObject then fs:SetFontObject(GameFontNormalSmall) end
        btn:SetScript("OnClick", function() BT:OrganizeAll() end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Sort All")
            GameTooltip:AddLine("Routes items to their bags and sorts every tabbed bag", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.btSortAll = btn
    end
    btn:SetFrameLevel(frame:GetFrameLevel() + 6)
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMRIGHT", topBtn, "TOPRIGHT", 0, 3)
    btn:Show()
end


function BT:UpdateSortButton(frame)
    UpdateSortButton(frame)
    if DS.BulkBagPlace and frame and frame:GetID() == 0 then DS.BulkBagPlace(frame) end   -- BB sits next to it
end

-- ============================================================ hooks
BT:OnInit(function()
    hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
        if not BT.enabled then return end
        BT:LayoutFrame(frame)
        BT:UpdateSortButton(frame)
        if BT.hoverCats then ApplyFrame(frame) end
    end)
    hooksecurefunc("ContainerFrame_Update", function(frame)
        if not BT.enabled then return end
        if frame:IsShown() then BT:MarkFrame(frame) end
        if frame.btHolder and frame:IsShown() then BT:LayoutFrame(frame) end
        BT:UpdateSortButton(frame)
        if BT.hoverCats then ApplyFrame(frame) end
    end)

    -- Alt-click an item in a bag: add it to / remove it from the ignore list
    local lastToggle = 0
    local function AltClick(self, button)
        if not BT.enabled then return end
        if button ~= "LeftButton" or not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
        if GetTime() - lastToggle < 0.2 then return end      -- both Blizzard handlers may fire for one click
        local bag, slot = self:GetParent():GetID(), self:GetID()
        local link = GetContainerItemLink(bag, slot)
        local id = BT.ItemID(link)
        if not id then return end
        lastToggle = GetTime()
        local on = not BT.db.ignore[id]
        BT:SetIgnored(id, on)
        BT:Print((on and "ignoring " or "no longer ignoring ") .. link .. (on and " (never moved, sorted or deleted)" or ""))
    end
    if ContainerFrameItemButton_OnModifiedClick then hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", AltClick) end
    if ContainerFrameItemButton_OnClick then hooksecurefunc("ContainerFrameItemButton_OnClick", AltClick) end

    -- make room between bag columns so side tabs do not sit on top of the neighbouring bag.
    -- Blizzard re-anchors every open bag each time one opens or closes; we shift the head of each column
    -- by a fixed amount on top of what Blizzard just set. The pass is idempotent (it remembers the base it
    -- started from) and repeated one frame later, so a bag that was shown late still lands in place.
    local function IsContainer(rel)
        local n = rel and rel.GetName and rel:GetName()
        return n and n:match("^ContainerFrame%d+$") ~= nil
    end
    local function PushColumns()
        if not BT.enabled or not BT.db.manualLayout then return end
        local gap, width = BT.db.colGap or 0, BT.db.colWidth or 0
        local list = ContainerFrame1 and ContainerFrame1.bags
        if not list then return end
        -- 1. Blizzard's own position of every bag anchored to the screen (our earlier shift undone)
        local heads = {}
        for _, fname in ipairs(list) do
            local f = _G[fname]
            if f and f:IsShown() then
                local point, rel, relPoint, x, y = f:GetPoint(1)
                if point and not IsContainer(rel) then
                    local last = f.btPush
                    if last and last.point == point and last.rel == rel and last.x == x and last.y == y then
                        x, y = last.base, last.baseY            -- our own anchor: start from Blizzard's spot again
                    elseif BT.db.colAnchor == "BOTTOMRIGHT" and point ~= "BOTTOMRIGHT" and rel == UIParent then
                        -- same place on screen, expressed from the bottom right corner
                        local fs, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
                        local r, b = f:GetRight(), f:GetBottom()
                        if r and b and fs and fs > 0 then
                            x = (r * fs - UIParent:GetRight() * us) / fs
                            y = (b * fs - UIParent:GetBottom() * us) / fs
                            point, relPoint = "BOTTOMRIGHT", "BOTTOMRIGHT"
                        end
                    end
                    heads[#heads + 1] = { f = f, point = point, rel = rel, relPoint = relPoint, x = x, y = y, d = math.abs(x) }
                end
            end
        end
        -- 2. columns = bags at (nearly) the same distance from the screen edge; column 0 is the one nearest the edge
        local ds = {}
        for _, h in ipairs(heads) do ds[#ds + 1] = h.d end
        table.sort(ds)
        local starts = {}                                   -- distance of the first bag of each column
        for _, d in ipairs(ds) do
            if #starts == 0 or d - starts[#starts] > 4 then starts[#starts + 1] = d end
        end
        for _, h in ipairs(heads) do
            local col = 0
            for i, d in ipairs(starts) do if h.d >= d - 0.5 then col = i - 1 end end
            local dir = h.point:find("LEFT") and 1 or -1     -- away from the screen edge
            local nx
            if width > 0 then
                nx = (dir * starts[1]) + dir * col * width    -- manual: fixed column pitch from the first column
                if (h.x < 0) ~= (dir < 0) then nx = h.x end
            else
                nx = h.x + dir * col * gap                    -- only columns after the first are moved
            end
            h.f:ClearAllPoints()
            h.f:SetPoint(h.point, h.rel, h.relPoint, nx, h.y)
            h.f.btPush = { point = h.point, rel = h.rel, x = nx, y = h.y, base = h.x, baseY = h.y }
        end
    end
    BT.PushColumns = PushColumns
    local pusher = CreateFrame("Frame")
    pusher:Hide()
    pusher:SetScript("OnUpdate", function(self) self:Hide(); PushColumns() end)
    if updateContainerFrameAnchors then
        hooksecurefunc("updateContainerFrameAnchors", function()
            PushColumns()
            pusher:Show()
        end)
    end
end)
