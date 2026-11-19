-- DreamScore: upgrade hint
-- A small yellow "(!)" in the top-left of a character-window slot when the bags hold a better piece for your
-- spec, by DreamScore. Hover shows the item, click swaps it in.
-- Rules: the required level is reached, the armor type is one you can wear, and the DreamScore is higher.
-- Weapons, shields and relics are left out for now.
local DS = DreamSuite
local DSC = DS.DreamScore
local M = DS.byId.DreamScore
local U = {}
DSC.Hint = U

local SLOT_NAME = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
                    [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger0", [12] = "Finger1",
                    [13] = "Trinket0", [14] = "Trinket1", [15] = "Back" }
local ARMOR_RANK = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4 }
local CLASS_ARMOR = { DRUID = 2, ROGUE = 2, HUNTER = 3, SHAMAN = 3, WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
                      PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local HINT_COLOR = { 1, 0.82, 0 }
local MIN_GAIN = 1.01           -- at least 1% better

local hints, best = {}, {}
local dirtyAt
U.hints, U.best = hints, best

local function Active()
    if not M.active or not DSC.db().upgradeHint then return false end
    if not DSC:Spec() then DSC:Detect() end          -- talents can be unavailable for a moment after logging in
    return DSC:Spec() ~= nil
end

local function Wearable(loc, sub)
    local rank = ARMOR_RANK[sub]
    if not rank or loc == "INVTYPE_CLOAK" then return true end       -- jewelry, cloaks and the like
    local _, class = UnitClass("player")
    return rank <= (CLASS_ARMOR[class] or 1)
end

-- explain: a list that receives one line per equippable bag item saying why it did or did not count
function U:Scan(explain)
    wipe(best)
    if not Active() then return end
    local level = UnitLevel("player") or 1
    local function Why(link, text) if explain then explain[#explain + 1] = link .. ": " .. text end end
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, _, _, minLevel, _, sub, _, loc = GetItemInfo(link)
                local slots = loc and DSC.SLOTS[loc]
                if not slots then
                    -- not something you wear
                elseif slots.both or loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND" or loc == "INVTYPE_SHIELD"
                   or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_HOLDABLE" then
                    Why(link, "weapons and shields are not hinted yet")
                elseif (minLevel or 0) > level then
                    Why(link, "needs level " .. minLevel)
                elseif not Wearable(loc, sub) then
                    Why(link, "armor type " .. tostring(sub) .. " is not one you wear")
                else
                    local score = DSC:Score(link)
                    if not score then
                        Why(link, "stats not readable yet (item not cached)")
                    elseif score <= 0 then
                        Why(link, "scores 0 for your spec")
                    else
                        for _, id in ipairs(slots) do
                            local name = SLOT_NAME[id]
                            local worn = GetInventoryItemLink("player", id)
                            local ws = worn and DSC:Score(worn) or 0
                            if name and (ws == 0 or score >= ws * MIN_GAIN) then
                                Why(link, string.format("%s: %.0f vs worn %.0f - counts", name, score, ws))
                                if not best[name] or score > best[name].score then
                                    best[name] = { bag = bag, slot = slot, link = link, score = score, worn = ws, id = id }
                                end
                            elseif name then
                                Why(link, string.format("%s: %.0f vs worn %.0f - not better", name, score, ws))
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
    local gain = b.worn > 0 and string.format("  (+%.0f%% DreamScore)", (b.score - b.worn) / b.worn * 100) or ""
    GameTooltip:AddLine("Upgrade from your bags" .. gain .. " - click to swap it in", HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
    GameTooltip:Show()
end

local function Click(btn)
    local b = best[btn.slotName]
    if not b or InCombatLockdown() or CursorHasItem() then return end
    if GetContainerItemLink(b.bag, b.slot) ~= b.link then dirtyAt = 0; return end
    PickupContainerItem(b.bag, b.slot)
    PickupInventoryItem(b.id)
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
    fs:SetText("(!)")
    fs:SetTextColor(HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
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
    for _, name in pairs(SLOT_NAME) do
        local h = hints[name] or MakeHint(name)
        if h then if best[name] then h:Show() else h:Hide() end end
    end
end

-- total DreamScore on the character window: below the trinkets, beside the weapon slots
local totalFs
function U:UpdateTotal(force)
    if not totalFs then
        if not CharacterFrame or not CharacterTrinket1Slot then return end
        -- a frame of its own on the paper doll, above its artwork (a font string on CharacterFrame would sit underneath it)
        local holder = CreateFrame("Frame", nil, PaperDollFrame or CharacterFrame)
        holder:SetAllPoints(PaperDollFrame or CharacterFrame)
        holder:SetFrameLevel((PaperDollFrame or CharacterFrame):GetFrameLevel() + 12)
        totalFs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if CharacterRangedSlot then
            -- centred in the free space: from the last weapon slot to the right edge of the slot column, level with the weapons
            totalFs:SetPoint("LEFT", CharacterRangedSlot, "RIGHT", 4, 0)
            totalFs:SetPoint("RIGHT", CharacterTrinket1Slot, "RIGHT", 4, 0)
            totalFs:SetPoint("TOP", CharacterRangedSlot, "TOP", 0, -12)
            totalFs:SetPoint("BOTTOM", CharacterRangedSlot, "BOTTOM", 0, -12)
            totalFs:SetJustifyV("MIDDLE")
        else
            totalFs:SetPoint("TOP", CharacterTrinket1Slot, "BOTTOM", -4, 9)
        end
        totalFs:SetJustifyH("CENTER")
    end
    local on = M.active and DSC.db().charTotal and DSC:Spec() ~= nil
    if not on then totalFs:SetText(""); totalFs:Hide(); return end
    if not force and not CharacterFrame:IsShown() then return end
    totalFs:SetText("|cffffc800DreamScore|r\n|cffffffff" .. string.format("%d", math.floor(DSC:Total() + 0.5)) .. "|r")
    totalFs:Show()
end

local frame = CreateFrame("Frame")
U.frame = frame
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    if M.active then dirtyAt = GetTime() + 0.4 end
end)    -- debounce bursts
local sinceCheck = 0
frame:SetScript("OnUpdate", function(_, dt)
    sinceCheck = sinceCheck + dt
    if sinceCheck < 0.25 then return end
    sinceCheck = 0
    U.sinceTotal = (U.sinceTotal or 0) + 0.25
    if U.sinceTotal >= 1 then U.sinceTotal = 0; local ok, err = pcall(U.UpdateTotal, U); if not ok and not U.totErr then U.totErr = true; DS.Print("DreamScore total error: " .. tostring(err)) end end
    if not Active() then
        if next(best) or U.shown then
            wipe(best)
            for _, h in pairs(hints) do h:Hide() end
            U.shown = false
        end
        return
    end
    -- item data can arrive late after logging in: look again every few seconds while the window is open
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
            DS.Print("DreamScore upgrade hint error: " .. tostring(err))
        end
    end
end)

function U:On()
    for _, e in ipairs({ "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        frame:RegisterEvent(e)
    end
    dirtyAt = 0
end

function U:Off()
    frame:UnregisterAllEvents()
    if totalFs then totalFs:Hide() end
    dirtyAt = nil
    wipe(best)
    for _, h in pairs(hints) do h:Hide() end
    U.shown = false
end

function U:Kick() dirtyAt = 0 end

-- /dscore upgrades: why a bag item has (or has no) hint
function U:Report()
    if not DSC:Spec() then DSC:Detect() end
    DS.Print("DreamScore upgrade hint " .. (Active() and "is on" or "is off (or no weights for your spec)")
        .. ", spec " .. tostring(DSC.specName) .. ", tree " .. tostring(DSC.tree))
    local why = {}
    self:Scan(why)
    if #why == 0 then DS.Print("no equippable items in your bags") end
    for _, l in ipairs(why) do DS.Print(l) end
end
