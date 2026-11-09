--[[ InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
     Upgrade hint: a tiny yellow "(!)" in the top-left of a character-window slot when the bags hold a
     better piece of armor for it. Hover shows the item, click swaps it in.
     Deliberately simple: same armor type as what you wear, higher item level, required level reached.
     Weapons, shields and ranged are left out (item level says too little about them). ]]

local DS = DreamSuite
local BT = DS.InventoryPlusCore
local U = {}
BT.Upgrades = U

-- equipLoc -> character slot names that can take it
local SLOTS = {
    INVTYPE_HEAD = { "Head" }, INVTYPE_NECK = { "Neck" }, INVTYPE_SHOULDER = { "Shoulder" },
    INVTYPE_CLOAK = { "Back" }, INVTYPE_CHEST = { "Chest" }, INVTYPE_ROBE = { "Chest" },
    INVTYPE_WRIST = { "Wrist" }, INVTYPE_HAND = { "Hands" }, INVTYPE_WAIST = { "Waist" },
    INVTYPE_LEGS = { "Legs" }, INVTYPE_FEET = { "Feet" },
    INVTYPE_FINGER = { "Finger0", "Finger1" }, INVTYPE_TRINKET = { "Trinket0", "Trinket1" },
}
local HINT_COLOR = { 1, 0.82, 0 }          -- yellow

local hints = {}            -- slot name -> hint button
local best = {}             -- slot name -> { bag, slot, link, ilvl }
local dirtyAt
U.hints, U.best = hints, best

local function Active() return BT.enabled and BT.db and BT.db.upgradeHint end

local function SlotId(name)
    local id = GetInventorySlotInfo and GetInventorySlotInfo(name .. "Slot")
    return id
end

-- scan the bags, fill `best`
function U:Scan()
    wipe(best)
    if not Active() then return end
    local level = UnitLevel("player") or 1
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, _, ilvl, minLevel, _, subType, _, loc = GetItemInfo(link)
                local names = loc and SLOTS[loc]
                if names and ilvl and (minLevel or 0) <= level then
                    for _, name in ipairs(names) do
                        local id = SlotId(name)
                        local worn = id and GetInventoryItemLink("player", id)
                        if worn then
                            local _, _, _, wilvl, _, _, wsub = GetItemInfo(worn)
                            local sameType = (wsub == subType)
                            if sameType and wilvl and ilvl > wilvl and (not best[name] or ilvl > best[name].ilvl) then
                                -- two-slot items: the other ring/trinket may already be this very item
                                best[name] = { bag = bag, slot = slot, link = link, ilvl = ilvl, worn = worn }
                            end
                        end
                    end
                end
            end
        end
    end
end

local function ShowTip(btn)
    local b = best[btn.slotName]
    if not b then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(b.link)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Upgrade from your bags (item level " .. b.ilvl .. ") - click to swap it in", HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
    GameTooltip:Show()
end

local function Click(btn)
    local b = best[btn.slotName]
    if not b or InCombatLockdown() or CursorHasItem() then return end
    if GetContainerItemLink(b.bag, b.slot) ~= b.link then dirtyAt = 0; return end
    local id = SlotId(btn.slotName)
    PickupContainerItem(b.bag, b.slot)
    PickupInventoryItem(id)
    dirtyAt = GetTime() + 0.5
end

local function MakeHint(name)
    local parent = _G["Character" .. name .. "Slot"]
    if not parent then return nil end
    local h = CreateFrame("Button", nil, parent)
    h:SetWidth(26); h:SetHeight(14)
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -1)
    h:SetFrameStrata("HIGH")
    h:SetFrameLevel(parent:GetFrameLevel() + 10)
    local fs = h:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "THICKOUTLINE")
    fs:SetPoint("CENTER", 0, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(0, 0)
    fs:SetText("(!)")
    fs:SetTextColor(HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
    h.text = fs
    h.slotName = name
    h:SetScript("OnEnter", ShowTip)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    h:SetScript("OnClick", Click)
    h:Hide()
    hints[name] = h
    return h
end

function U:Refresh()
    self:Scan()
    for _, names in pairs(SLOTS) do
        for _, name in ipairs(names) do
            local h = hints[name] or MakeHint(name)
            if h then
                if best[name] then h:Show() else h:Hide() end
            end
        end
    end
end

local frame = CreateFrame("Frame")
U.frame = frame
for _, e in ipairs({ "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
    frame:RegisterEvent(e)
end
frame:SetScript("OnEvent", function()
    if BT.enabled then dirtyAt = GetTime() + 0.4 end      -- debounce bursts of bag events
end)
local sinceCheck = 0
frame:SetScript("OnUpdate", function(_, dt)
    sinceCheck = sinceCheck + dt
    if sinceCheck < 0.25 then return end
    sinceCheck = 0
    if not Active() then
        if next(best) or U.shown then
            wipe(best)
            for _, h in pairs(hints) do h:Hide() end
            U.shown = false
        end
        return
    end
    -- item data can arrive late after logging in, so look again every few seconds while the window is open
    if CharacterFrame and CharacterFrame:IsShown() and (not U.lastScan or GetTime() - U.lastScan > 3) then
        dirtyAt = dirtyAt or 0
    end
    if dirtyAt and GetTime() >= dirtyAt then
        dirtyAt = nil
        U.shown = true
        U.lastScan = GetTime()
        local ok, err = pcall(U.Refresh, U)
        if not ok and not U.errShown then
            U.errShown = true
            BT:Print("upgrade hint error: " .. tostring(err))
        end
    end
end)

-- /ip upgrades: why a slot has (or has no) hint
function U:Report()
    local level = UnitLevel("player") or 1
    BT:Print("upgrade hint " .. (Active() and "is on" or "is OFF") .. ", level " .. level)
    for _, names in pairs(SLOTS) do
        for _, name in ipairs(names) do
            local id = SlotId(name)
            local worn = id and GetInventoryItemLink("player", id)
            local _, _, _, wilvl, _, _, wsub = GetItemInfo(worn or "")
            BT:Print(name .. ": worn " .. (worn and (tostring(wilvl) .. " " .. tostring(wsub)) or "nothing/uncached")
                .. (best[name] and (" -> upgrade " .. best[name].link .. " (" .. best[name].ilvl .. ")") or ""))
        end
    end
end

-- turned on (module or option): scan soon
function U:Kick() dirtyAt = 0 end
