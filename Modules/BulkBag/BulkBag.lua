-- BulkBag: with the BB button on, Ctrl+drag selects items, LMB on an empty slot bulk moves them
-- Supports inventory bags, personal bank, and guild bank
--
-- DreamSuite module. It touches the bag / bank frames, so switching it on or off waits for the end of
-- combat (secure = true). The hooks on the item buttons cannot be removed; while the module is off they
-- do nothing, and switching off clears the selection, drops the move queue and hides every highlight.
local DS = DreamSuite
local M = DS.RegisterModule({
    id      = "BulkBag",
    title   = "BulkBag",
    desc    = "Switch on the BB button on the backpack, then Ctrl+click or drag to select several items and click an empty slot to move them all (bags, bank, guild bank)",
    slash   = { "/bb", "/bulkbag" },
    secure  = true,
})
local enabled = false
local DEFAULTS = {
    legacy     = false,   -- selecting is always on, as in the standalone addon (Ctrl+click also previews)
    hideButton = false,   -- hide the BB button (only used together with legacy)
}
local db
local function DB()
    db = db or DS.GetDB("BulkBag", DEFAULTS)
    return db
end
local function Legacy() return DB().legacy and true or false end
local bbMode  = false     -- the BB button on the backpack: Ctrl-click selects instead of previewing
local buttons = {}        -- every BB button (one per backpack frame)

------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------

local HIGHLIGHT_COLOR = {r=0.2, g=0.6, b=1.0, a=0.5}
local MOVE_INTERVAL   = 0.05  -- seconds between queued moves

local TYPE_CONTAINER = "container"
local TYPE_BANK      = "bank"
local TYPE_GUILDBANK = "guildbank"

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local selected        = {}     -- currently highlighted slots
local reservedSlots   = {}     -- destination slots already queued
local moveQueue       = {}     -- pending moves
local isDragging      = false
local dragMode        = nil    -- "select" or "deselect"
local isMoving        = false
local waitingForUpdate = false
local currentTarget   = nil    -- target bag for active move operation
local frameTick       = 0

------------------------------------------------------------------------
-- Slot utilities
------------------------------------------------------------------------

local function GetSlotKey(slotType, bagID, slotID)
    if slotType == TYPE_BANK      then return "bank_" .. slotID end
    if slotType == TYPE_GUILDBANK then return "guild_" .. bagID .. "_" .. slotID end
    return "bag_" .. bagID .. "_" .. slotID
end

-- Container slots: visual slot 1 = bottom-right, API slot 1 = top-left
local function ToAPISlot(bagID, visualSlot)
    return (GetContainerNumSlots(bagID) + 1) - visualSlot
end

local function GetButton(slotType, bagID, slotID)
    if slotType == TYPE_BANK then
        return _G["BankFrameItem" .. slotID]
    elseif slotType == TYPE_GUILDBANK then
        local col = math.ceil(slotID / 14)
        local row = slotID - (col - 1) * 14
        return _G["GuildBankColumn" .. col .. "Button" .. row]
    else
        return _G["ContainerFrame" .. (bagID + 1) .. "Item" .. slotID]
    end
end

local function IsSlotEmpty(slotType, bagID, slotID)
    if slotType == TYPE_BANK then
        local btn = _G["BankFrameItem" .. slotID]
        return btn and not btn.hasItem
    elseif slotType == TYPE_GUILDBANK then
        return not GetGuildBankItemLink(bagID, slotID)
    else
        return not GetContainerItemLink(bagID, ToAPISlot(bagID, slotID))
    end
end

------------------------------------------------------------------------
-- Highlight
------------------------------------------------------------------------

local function HighlightSlot(button, on)
    if not button._bbOverlay then
        local tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(button)
        tex:SetTexture(1, 1, 1, 1)
        button._bbOverlay = tex
    end
    if on then
        button._bbOverlay:SetVertexColor(HIGHLIGHT_COLOR.r, HIGHLIGHT_COLOR.g, HIGHLIGHT_COLOR.b, HIGHLIGHT_COLOR.a)
        button._bbOverlay:Show()
    else
        button._bbOverlay:Hide()
    end
end

------------------------------------------------------------------------
-- Selection
------------------------------------------------------------------------

local function IsSelected(slotType, bagID, slotID)
    return selected[GetSlotKey(slotType, bagID, slotID)] ~= nil
end

local function SelectSlot(slotType, bagID, slotID, button)
    selected[GetSlotKey(slotType, bagID, slotID)] = { slotType = slotType, bagID = bagID, slotID = slotID }
    HighlightSlot(button, true)
end

local function DeselectSlot(slotType, bagID, slotID, button)
    selected[GetSlotKey(slotType, bagID, slotID)] = nil
    HighlightSlot(button, false)
end

local function ClearSelection()
    for _, data in pairs(selected) do
        local btn = GetButton(data.slotType, data.bagID, data.slotID)
        if btn then HighlightSlot(btn, false) end
    end
    selected = {}
end

------------------------------------------------------------------------
-- Move queue
------------------------------------------------------------------------

local function GetFreeSlots(target)
    local free = {}
    if target.slotType == TYPE_BANK then
        for slotID = 1, 28 do
            local btn = _G["BankFrameItem" .. slotID]
            if btn and not btn.hasItem and not reservedSlots[GetSlotKey(TYPE_BANK, 0, slotID)] then
                table.insert(free, slotID)
            end
        end
    elseif target.slotType == TYPE_GUILDBANK then
        local tabID = target.bagID
        for slotID = 1, 98 do
            if not GetGuildBankItemLink(tabID, slotID) and not reservedSlots[GetSlotKey(TYPE_GUILDBANK, tabID, slotID)] then
                table.insert(free, slotID)
            end
        end
    else
        local bagID = target.bagID
        local numSlots = GetContainerNumSlots(bagID)
        for visualSlot = numSlots, 1, -1 do
            local key = GetSlotKey(TYPE_CONTAINER, bagID, visualSlot)
            if not GetContainerItemLink(bagID, (numSlots + 1) - visualSlot)
                and not IsSelected(TYPE_CONTAINER, bagID, visualSlot)
                and not reservedSlots[key] then
                table.insert(free, visualSlot)
            end
        end
    end
    return free
end

local function BuildQueue(target)
    local freeSlots = GetFreeSlots(target)

    local sortedSelected = {}
    for _, data in pairs(selected) do
        if not (data.slotType == target.slotType and data.bagID == target.bagID) then
            table.insert(sortedSelected, data)
        end
    end
    table.sort(sortedSelected, function(a, b)
        if a.bagID ~= b.bagID then return a.bagID < b.bagID end
        return a.slotID > b.slotID
    end)

    moveQueue = {}
    local freeIndex = 1
    for _, data in ipairs(sortedSelected) do
        if freeIndex > #freeSlots then break end
        local dstSlot = freeSlots[freeIndex]
        reservedSlots[GetSlotKey(target.slotType, target.bagID, dstSlot)] = true
        table.insert(moveQueue, {
            srcType = data.slotType, srcBag = data.bagID, srcSlot = data.slotID,
            dstType = target.slotType, dstBag = target.bagID, dstSlot = dstSlot,
        })
        freeIndex = freeIndex + 1
    end
end

local function ExecuteMove(move)
    -- Pick up source
    if move.srcType == TYPE_BANK then
        local btn = GetButton(TYPE_BANK, 0, move.srcSlot)
        if btn then btn:Click() end
    elseif move.srcType == TYPE_GUILDBANK then
        PickupGuildBankItem(move.srcBag, move.srcSlot)
    else
        PickupContainerItem(move.srcBag, ToAPISlot(move.srcBag, move.srcSlot))
    end
    -- Place at destination
    if move.dstType == TYPE_BANK then
        local btn = GetButton(TYPE_BANK, 0, move.dstSlot)
        if btn then btn:Click() end
    elseif move.dstType == TYPE_GUILDBANK then
        PickupGuildBankItem(move.dstBag, move.dstSlot)
    else
        PickupContainerItem(move.dstBag, ToAPISlot(move.dstBag, move.dstSlot))
    end
end

local function DequeueMove()
    if #moveQueue == 0 then
        isMoving        = false
        waitingForUpdate = false
        currentTarget   = nil
        reservedSlots   = {}
        local remaining = 0
        for _ in pairs(selected) do remaining = remaining + 1 end
        if remaining > 0 then
            print(string.format("BulkBag: %d item(s) could not be moved, target full", remaining))
        end
        return
    end

    local move = table.remove(moveQueue, 1)
    ExecuteMove(move)

    local key = GetSlotKey(move.srcType, move.srcBag, move.srcSlot)
    if selected[key] then
        local btn = GetButton(move.srcType, move.srcBag, move.srcSlot)
        if btn then HighlightSlot(btn, false) end
        selected[key] = nil
    end

    waitingForUpdate = true
end

local function MoveSelectedTo(target)
    currentTarget = target
    reservedSlots = {}
    BuildQueue(target)
    if #moveQueue > 0 then
        isMoving        = true
        waitingForUpdate = false
    else
        print("BulkBag: no free slots in target")
    end
end

------------------------------------------------------------------------
-- BB button on the backpack
------------------------------------------------------------------------

-- on = the button itself glows: a warm yellow/orange (like Blizzard's own messages) fades in and out over
-- its face, so it slowly changes colour between its normal look and orange. The layer is added on top of
-- the red panel texture (additive blending keeps the button's shape and border).
local GLOW_R, GLOW_G, GLOW_B = 1.0, 0.62, 0.05
local GLOW_MAX = 0.8          -- strongest the glow gets
local GLOW_SPEED = 3.2        -- radians per second: one full cycle in about two seconds

local function Tint(b, on)
    b.bbOn = on and true or false
    if b.cover then
        if on then
            b.cover.t = 0
            b.cover.tex:SetAlpha(0)
            b.cover:Show()
        else
            b.cover:Hide()
        end
    end
    if b.label then
        if on then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(1, 0.82, 0) end
    end
end

local function RefreshButtons()
    for _, b in ipairs(buttons) do
        Tint(b, bbMode and enabled)
    end
end

local function SetMode(on)
    on = on and enabled or false
    if bbMode == on then return end
    bbMode = on
    if not on then ClearSelection(); isDragging, dragMode = false, nil end
    RefreshButtons()
end

-- next to the Sort All button of InventoryPlus when that is there, else in the same spot above the first row
local function PlaceButton(frame)
    if not frame or frame:GetID() ~= 0 then return end
    local btn = frame._bbButton
    if not (enabled and frame:IsShown()) or (Legacy() and DB().hideButton) then
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
        btn:SetWidth(28); btn:SetHeight(16)
        btn:SetText("")
        btn.cover = CreateFrame("Frame", nil, btn)
        btn.cover:SetPoint("TOPLEFT", 3, -3); btn.cover:SetPoint("BOTTOMRIGHT", -3, 3)
        btn.cover.tex = btn.cover:CreateTexture(nil, "BACKGROUND")
        btn.cover.tex:SetAllPoints(btn.cover)
        btn.cover.tex:SetTexture(GLOW_R, GLOW_G, GLOW_B, 1)
        btn.cover.tex:SetBlendMode("ADD")
        btn.cover.t = 0
        btn.cover:SetScript("OnUpdate", function(self, elapsed)
            self.t = self.t + elapsed
            self.tex:SetAlpha(GLOW_MAX * 0.5 * (1 - math.cos(self.t * GLOW_SPEED)))     -- 0 -> max -> 0, starting from normal
        end)
        btn.cover:Hide()
        btn.labelFrame = CreateFrame("Frame", nil, btn)
        btn.labelFrame:SetAllPoints(btn)
        btn.label = btn.labelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("CENTER", 0, 0)
        btn.label:SetText("BB")
        btn:SetScript("OnClick", function() if not Legacy() then SetMode(not bbMode) end end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("BulkBag", 1, 0.82, 0)
            GameTooltip:AddLine(Legacy() and "Legacy mode: selecting is always on (Ctrl+click also previews items). Change this in the BulkBag options."
                or bbMode and "On: Ctrl+click or Ctrl+drag selects items, then click an empty slot to move them. Ctrl+click does not preview items."
                or "Off: Ctrl+click previews items as usual. Click to switch BulkBag selecting on.", 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame._bbButton = btn
        buttons[#buttons + 1] = btn
    end
    btn:SetFrameLevel(frame:GetFrameLevel() + 6)
    if btn.cover then
        btn.cover:SetFrameLevel(btn:GetFrameLevel() + 1)
        btn.labelFrame:SetFrameLevel(btn:GetFrameLevel() + 2)
    end
    btn:ClearAllPoints()
    local sort = frame.btSortAll
    if sort and sort:IsShown() then
        btn:SetPoint("BOTTOMRIGHT", sort, "BOTTOMLEFT", -3, 0)
    else
        btn:SetPoint("BOTTOMRIGHT", topBtn, "TOPRIGHT", 0, 3)
    end
    btn:Show()
    RefreshButtons()
end
DS.BulkBagPlace = PlaceButton            -- InventoryPlus calls this after it moves its Sort All button

local hooksDone = false
local function InstallHooks()
    if hooksDone then return end
    hooksDone = true
    hooksecurefunc("ContainerFrame_GenerateFrame", function(frame) if enabled then PlaceButton(frame) end end)
    hooksecurefunc("ContainerFrame_Update", function(frame) if enabled then PlaceButton(frame) end end)
    -- Ctrl+click previews an item in the dressing room; while BB is on that click belongs to BulkBag
    local orig = DressUpItemLink
    if orig then
        DressUpItemLink = function(...)
            if enabled and bbMode and not Legacy() and IsControlKeyDown() then return end
            return orig(...)
        end
    end
end

------------------------------------------------------------------------
-- Hooking
------------------------------------------------------------------------

local function HookButton(btn, slotType, bagID, slotID)
    if not btn or btn._bbHooked then return end
    btn._bbHooked = true

    -- a guild bank button shows whichever tab is open now, so ask for the tab each time
    local function Bag()
        if slotType == TYPE_GUILDBANK and GetCurrentGuildBankTab then
            return GetCurrentGuildBankTab() or bagID
        end
        return bagID
    end

    btn:HookScript("OnMouseDown", function(self, mouseButton)
        if not enabled or not (bbMode or Legacy()) or mouseButton ~= "LeftButton" then return end
        local bagID = Bag()

        if IsControlKeyDown() then
            isDragging = true
            if IsSelected(slotType, bagID, slotID) then
                dragMode = "deselect"
                DeselectSlot(slotType, bagID, slotID, self)
            else
                dragMode = "select"
                SelectSlot(slotType, bagID, slotID, self)
            end
            return
        end

        if next(selected) and IsSlotEmpty(slotType, bagID, slotID) and not IsSelected(slotType, bagID, slotID) then
            MoveSelectedTo({ slotType = slotType, bagID = bagID })
        else
            ClearSelection()
        end
    end)

    btn:HookScript("OnEnter", function(self)
        if not enabled or not isDragging then return end
        local bagID = Bag()
        if dragMode == "select" then
            SelectSlot(slotType, bagID, slotID, self)
        else
            DeselectSlot(slotType, bagID, slotID, self)
        end
    end)
end

local function HookInventoryBags()
    for bagID = 0, 4 do
        for slotID = 1, GetContainerNumSlots(bagID) do
            HookButton(_G["ContainerFrame" .. (bagID + 1) .. "Item" .. slotID], TYPE_CONTAINER, bagID, slotID)
        end
    end
end

local function HookBankSlots()
    for slotID = 1, 28 do
        HookButton(_G["BankFrameItem" .. slotID], TYPE_BANK, 0, slotID)
    end
    for bagID = 5, 10 do
        for slotID = 1, GetContainerNumSlots(bagID) do
            HookButton(_G["ContainerFrame" .. (bagID + 1) .. "Item" .. slotID], TYPE_CONTAINER, bagID, slotID)
        end
    end
end

local function HookGuildBankSlots()
    local tabID = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
    for col = 1, 7 do
        for row = 1, 14 do
            HookButton(_G["GuildBankColumn" .. col .. "Button" .. row], TYPE_GUILDBANK, tabID, (col - 1) * 14 + row)
        end
    end
end

------------------------------------------------------------------------
-- Event and update loop
------------------------------------------------------------------------

local f = CreateFrame("Frame", "DreamSuiteBulkBagFrame")
local EVENTS = { "BAG_UPDATE", "BANKFRAME_OPENED", "GUILDBANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED" }

local function OnEvent(self, event)
    if event == "BAG_UPDATE" then
        HookInventoryBags()
        if isMoving and waitingForUpdate then waitingForUpdate = false end
    elseif event == "BANKFRAME_OPENED" then
        HookBankSlots()
    elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
        HookGuildBankSlots()
        if isMoving and waitingForUpdate then waitingForUpdate = false end
    end
end

local function OnUpdate(self, elapsed)
    if isDragging and not IsMouseButtonDown("LeftButton") then
        isDragging = false
        dragMode   = nil
    end
    if isMoving and not waitingForUpdate then
        frameTick = frameTick + elapsed
        if frameTick >= MOVE_INTERVAL then
            frameTick = 0
            DequeueMove()
        end
    end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

function M.OnSlash(msg)
    if msg == "on" or msg == "off" or msg == "toggle" then
        if Legacy() then
            print("BulkBag: legacy mode, selecting is always on (change it in the BulkBag options)")
        else
            SetMode(msg == "toggle" and not bbMode or msg == "on")
            print("BulkBag: selecting is " .. (bbMode and "on" or "off"))
        end
    elseif msg == "clear" then
        ClearSelection()
        print("BulkBag: selection cleared")
    else
        local count = 0
        for _, data in pairs(selected) do
            print(string.format("  %s bag=%d slot=%d", data.slotType, data.bagID, data.slotID))
            count = count + 1
        end
        print(string.format("BulkBag: %d item(s) selected", count))
    end
end

------------------------------------------------------------------------
-- Options
------------------------------------------------------------------------

-- a setting changed: move or hide the buttons, drop a selection that is no longer allowed
local function ApplySettings()
    if not enabled then return end
    if not Legacy() and not bbMode then ClearSelection(); isDragging, dragMode = false, nil end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:GetID() == 0 then DS.BulkBagPlace(cf) end
    end
end

M.options = function()
    return {
        { type = "bool", key = "legacy", label = "Always on (legacy)",
          desc = "Selecting is always switched on, as in the standalone BulkBag: Ctrl+click and Ctrl+drag select items. Ctrl+click then also previews the item, because both use the same click.",
          get = function() return DB().legacy end,
          set = function(v) DB().legacy = v and true or false; ApplySettings() end },
        { type = "bool", key = "hideButton", label = "Hide the BB button",
          desc = "Only available in legacy mode: with selecting always on, the button has nothing left to switch.",
          disabled = function() return not DB().legacy end,
          get = function() return DB().hideButton end,
          set = function(v) DB().hideButton = v and true or false; ApplySettings() end },
    }
end

------------------------------------------------------------------------
-- Enable / disable
------------------------------------------------------------------------

function M.OnEnable()
    enabled = true
    bbMode = false
    InstallHooks()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsShown() then PlaceButton(cf) end
    end
    isDragging, dragMode, isMoving, waitingForUpdate, currentTarget, frameTick = false, nil, false, false, nil, 0
    moveQueue, reservedSlots, selected = {}, {}, {}
    HookInventoryBags()
    HookBankSlots()
    HookGuildBankSlots()
    f:SetScript("OnEvent", OnEvent)
    for _, e in ipairs(EVENTS) do f:RegisterEvent(e) end
    f:SetScript("OnUpdate", OnUpdate)
end

function M.OnDisable()
    enabled = false
    bbMode = false
    for _, b in ipairs(buttons) do b:Hide(); Tint(b, false) end
    f:UnregisterAllEvents()
    f:SetScript("OnUpdate", nil)
    ClearSelection()
    selected, moveQueue, reservedSlots = {}, {}, {}
    isDragging, dragMode, isMoving, waitingForUpdate, currentTarget = false, nil, false, false, nil
end
