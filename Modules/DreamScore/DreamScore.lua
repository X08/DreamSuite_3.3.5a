-- DreamScore (DreamSuite module)
-- Rates an item for YOUR class and spec: every stat is valued by that spec's stat priority, the values are
-- added up, and the tooltip says how it compares with what you wear in that slot.
-- Replaces the "sum of item levels" idea of GearScore with "how much does this item help this spec".
--
-- Every class and spec has weights (Specs.lua). With few talent points the specs are averaged; at 31 points in one tree it is fully that spec.
-- Effects such as procs and Use: abilities cannot be valued; an item that has one is marked "effect not counted".
local DS = DreamSuite

local M = DS.RegisterModule({
    id      = "DreamScore",
    title   = "DreamScore",
    desc    = "Rates items for your class and spec, and compares them with what you wear",
    slash   = { "/dreamscore", "/dscore" },
})

local DSC = {}
DS.DreamScore = DSC
M.api = DSC

-- ============================================================ spec data
-- weights are relative to 1 point of spell power; keys are GetItemStats keys. The data lives in Specs.lua
-- (DS.DreamScoreSpecs[CLASS][talent tree number] = { name, source, w = { [stat] = weight } }).
DSC.SPECS = DS.DreamScoreSpecs or {}
DSC.FULL_POINTS = 31          -- talent points in one tree that count as fully committed to that spec

local STAT_NAME = {
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_SPELL_POWER_SHORT = "spell power",
    ITEM_MOD_HEALING_POWER_SHORT = "healing power", ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_INTELLECT_SHORT = "intellect", ITEM_MOD_SPIRIT_SHORT = "spirit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit",
}
setmetatable(STAT_NAME, { __index = function(_, k) return (k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower()) end })

-- equip location -> the character slots it competes for (the lowest-scoring one is compared)
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16, 17, both = true },
    INVTYPE_SHIELD = { 17 }, INVTYPE_RELIC = { 18 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
}
DSC.SLOTS = SLOTS
local SCORED_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local FALLBACK_LOC = { INVTYPE_TRINKET = true, INVTYPE_RELIC = true }   -- effects and relics cannot be valued by stats

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }

-- ============================================================ settings
local defaults = { tooltip = true, compare = true, socketValue = 18, upgradeHint = true, itemLevelFallback = false, charTotal = true }
local db
local function DB()
    if not db then db = DS.GetDB("DreamScore", defaults) end
    return db
end
DSC.db = DB

-- ============================================================ spec detection
local spec          -- { name, source, w } for this player: the blend of the class's specs (nil without weights)

-- Weights follow the talents: with no points the three specs of the class are averaged; every point spent in the
-- main tree moves the weights towards that spec, until FULL_POINTS (31) points make it 100% that spec.
local function Blend(entries, best, commit)
    local avg, n = {}, 0
    for tab = 1, 3 do
        local e = entries[tab]
        if e then
            n = n + 1
            for k, w in pairs(e.w) do avg[k] = (avg[k] or 0) + w end
        end
    end
    if n == 0 then return nil end
    for k in pairs(avg) do avg[k] = avg[k] / n end
    local main = best and entries[best]
    if not main or commit <= 0 then return avg, n end
    local out = {}
    for k, w in pairs(avg) do out[k] = w * (1 - commit) end
    for k, w in pairs(main.w) do out[k] = (out[k] or 0) + w * commit end
    return out, n
end

-- Feral Druids: the weights of a cat and of a bear differ a lot. Talents that only make sense for one of the two
-- decide which one the build is (more ranks in the bear ones than in the cat ones = bear).
local BEAR_TALENTS = { ["protector of the pack"] = true, ["natural reaction"] = true, ["primal gore"] = true, ["thick hide"] = true }
local CAT_TALENTS  = { ["shredding attacks"] = true, ["predatory strikes"] = true, ["predatory instincts"] = true, ["savage fury"] = true }
function DSC:FeralBuild(tab, group)
    if not (GetNumTalents and GetTalentInfo) then return "cat" end
    local bear, cat = 0, 0
    for i = 1, (GetNumTalents(tab) or 0) do
        local name, _, _, _, rank = GetTalentInfo(tab, i, false, false, group)
        name = name and strlower(name)
        if name and rank and rank > 0 then
            if BEAR_TALENTS[name] then bear = bear + rank elseif CAT_TALENTS[name] then cat = cat + rank end
        end
    end
    return bear > cat and "bear" or "cat"
end

function DSC:Detect()
    self:ClearCache()
    spec = nil
    self.specName, self.treeName, self.commit = nil, nil, 0
    local _, class = UnitClass("player")
    local best, bestPoints = nil, 0
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    for tab = 1, (GetNumTalentTabs and GetNumTalentTabs() or 3) do
        local name, _, points = GetTalentTabInfo(tab, false, false, group)
        if name and points and points > bestPoints then best, bestPoints = tab, points end
        if name and best == tab then self.treeName = name end
    end
    self.class, self.tree = class, best
    local entries = class and DSC.SPECS[class]
    if not entries then return nil end
    self.feral = nil
    if class == "DRUID" and DSC.SPECS.DRUID_BEAR and (best == 2 or not best) then
        self.feral = self:FeralBuild(2, group)
        if self.feral == "bear" then            -- the bear weights take the place of the cat ones
            local copy = {}
            for k, v in pairs(entries) do copy[k] = v end
            copy[2] = DSC.SPECS.DRUID_BEAR
            entries = copy
        end
    end
    local commit = math.min(1, bestPoints / DSC.FULL_POINTS)
    if not (best and entries[best]) then best, commit = nil, 0 end
    local w = Blend(entries, best, commit)
    if not w then return nil end
    self.commit = commit
    local name, source
    if not best or commit <= 0 then
        name, source = "all specs", "average of the three " .. class:lower() .. " specs (no talent points yet)"
    elseif commit >= 1 then
        name, source = entries[best].name, entries[best].source
    else
        name = string.format("%s %d%%", entries[best].name, math.floor(commit * 100 + 0.5))
        source = string.format("%d%% %s, the rest the average of all three specs (%d of %d points)",
            math.floor(commit * 100 + 0.5), entries[best].name, bestPoints, DSC.FULL_POINTS)
    end
    spec = { name = name, source = source, w = w }
    self.specName = name
    return spec
end

function DSC:Spec() return spec end

-- ============================================================ gem effects
-- Effects that cannot be read from a tooltip, worked out into stats by hand and added when the gem is socketed.
-- Insightful Earthsiege Diamond: 600 mana per proc, 15 s internal cooldown; measured at about 60 mp5
-- (Engadget, "Making an Insightful meta choice"; the theoretical maximum is 200 mp5).
DSC.GEM_EFFECTS = {
    ["Insightful Earthsiege Diamond"] = { ITEM_MOD_MANA_REGENERATION_SHORT = 60 },
}

-- ============================================================ scoring
-- Gems and enchants: their stats are not item stats (the game stores them as enchantments), so they are read from
-- the item's tooltip: the lines that appear with the gems and the enchant but not on the bare item. The item's own
-- stats come from GetItemStats on the bare link. Empty sockets are credited with a typical gem, and an active
-- socket bonus is read from the tooltip (English clients).
local cache, cacheCount = {}, 0
function DSC:ClearCache() cache, cacheCount = {}, 0 end

-- names as they appear in "+N <name>" tooltip lines (gems, enchants, socket bonuses) -> stat keys.
-- English names are listed; the game's own localized stat names are added below, so other languages work too.
local ALL_STATS = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
                    "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT" }
local NAME_KEY = {
    intellect = { "ITEM_MOD_INTELLECT_SHORT" }, spirit = { "ITEM_MOD_SPIRIT_SHORT" },
    strength = { "ITEM_MOD_STRENGTH_SHORT" }, agility = { "ITEM_MOD_AGILITY_SHORT" }, stamina = { "ITEM_MOD_STAMINA_SHORT" },
    ["spell power"] = { "ITEM_MOD_SPELL_POWER_SHORT" }, ["haste rating"] = { "ITEM_MOD_HASTE_RATING_SHORT" },
    ["critical strike rating"] = { "ITEM_MOD_CRIT_RATING_SHORT" }, ["crit rating"] = { "ITEM_MOD_CRIT_RATING_SHORT" },
    ["hit rating"] = { "ITEM_MOD_HIT_RATING_SHORT" }, ["expertise rating"] = { "ITEM_MOD_EXPERTISE_RATING_SHORT" },
    ["armor penetration rating"] = { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
    ["attack power"] = { "ITEM_MOD_ATTACK_POWER_SHORT" }, ["ranged attack power"] = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    ["defense rating"] = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" }, ["dodge rating"] = { "ITEM_MOD_DODGE_RATING_SHORT" },
    ["parry rating"] = { "ITEM_MOD_PARRY_RATING_SHORT" }, ["block rating"] = { "ITEM_MOD_BLOCK_RATING_SHORT" },
    ["block value"] = { "ITEM_MOD_BLOCK_VALUE_SHORT" }, armor = { "RESISTANCE0_NAME" },
    ["mana per 5 sec"] = { "ITEM_MOD_MANA_REGENERATION_SHORT" },
    ["all stats"] = ALL_STATS,
}
for _, key in ipairs({ "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT",
        "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_EXPERTISE_RATING_SHORT", "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
        "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT",
        "ITEM_MOD_BLOCK_VALUE_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT" }) do
    local name = _G[key]
    if type(name) == "string" and name ~= "" then
        name = strlower(name):gsub("[%.%s]+$", "")
        if not NAME_KEY[name] then NAME_KEY[name] = { key } end
    end
end
if type(_G.RESISTANCE0_NAME) == "string" and not NAME_KEY[strlower(_G.RESISTANCE0_NAME)] then
    NAME_KEY[strlower(_G.RESISTANCE0_NAME)] = { "RESISTANCE0_NAME" }
end

local BONUS_KEY = {
    intellect = "ITEM_MOD_INTELLECT_SHORT", spirit = "ITEM_MOD_SPIRIT_SHORT",
    ["spell power"] = "ITEM_MOD_SPELL_POWER_SHORT", ["haste rating"] = "ITEM_MOD_HASTE_RATING_SHORT",
    ["critical strike rating"] = "ITEM_MOD_CRIT_RATING_SHORT", ["mana per 5 sec"] = "ITEM_MOD_MANA_REGENERATION_SHORT",
    ["mana per 5 sec."] = "ITEM_MOD_MANA_REGENERATION_SHORT",
}

local scanTip
-- the active socket bonus of an item, as stat key and amount (English clients; nil when inactive or unknown)
function DSC:SocketBonus(link)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "DreamScoreScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    for i = 2, (scanTip:NumLines() or 0) do
        local fs = _G["DreamScoreScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text:find("^Socket Bonus:") then
            local r, g = fs:GetTextColor()
            if g and g > 0.8 and (r or 1) < 0.3 then          -- green: the sockets match, the bonus is active
                local n, what = text:match("%+(%d+) ([%a%s%.%d]+)")
                what = what and strlower(what):gsub("%s+$", "")
                local keys = what and (BONUS_KEY[what] and { BONUS_KEY[what] } or NAME_KEY[what])
                if keys == ALL_STATS then keys = nil end
                return keys and keys[1], tonumber(n)
            end
            return nil
        end
    end
end

local function AddStats(into, from)
    for k, v in pairs(from) do
        if type(k) == "string" and not k:find("^EMPTY_SOCKET_") and type(v) == "number" then into[k] = (into[k] or 0) + v end
    end
end


-- the "+N Stat" lines of an item's tooltip as a stat table (gem lines like "+9 Spell Power and +8 Spirit" included)
function DSC:TooltipStats(link)
    if not scanTip and self.scanTip then scanTip = self.scanTip end          -- (a test can supply its own)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "DreamScoreScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    local out, lines = {}, scanTip:NumLines() or 0
    for i = 2, lines do
        local fs = _G["DreamScoreScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if text:find("^%+%d") then
                for seg in (text:gsub(" and ", "|")):gmatch("[^|]+") do
                    local n, what = seg:match("^%s*%+(%d+) (.-)[%.%s]*$")
                    local keys = what and NAME_KEY[strlower(what)]
                    if keys then for _, k in ipairs(keys) do out[k] = (out[k] or 0) + tonumber(n) end end
                end
            end
        end
    end
    return out, lines > 0
end

-- what the gems and the enchant add: the tooltip of the item as it is, minus the tooltip of the bare item
function DSC:GemEnchantStats(link, bare)
    local full, ok1 = self:TooltipStats(link)
    local plain, ok2 = self:TooltipStats(bare)
    local extra = {}
    for k, v in pairs(full) do
        local d = v - (plain[k] or 0)
        if d > 0 then extra[k] = d end
    end
    return extra, ok1 and ok2
end

-- stats of an item including gems and enchant; also the number of empty (non-meta) sockets and the socket bonus
function DSC:ItemStats(link)
    local id, ench, g1, g2, g3, g4 = link:match("item:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
    local bare = link
    if id then bare = (link:gsub("item:(%-?%d+):%-?%d+:%-?%d+:%-?%d+:%-?%d+:%-?%d+", "item:%1:0:0:0:0:0", 1)) end
    local base = GetItemStats and GetItemStats(bare)
    if not base then return nil end
    local stats, sockets, metaSockets = {}, 0, 0
    for k, v in pairs(base) do
        if type(k) == "string" and k:find("^EMPTY_SOCKET_") then
            sockets = sockets + v
            if k == "EMPTY_SOCKET_META" then metaSockets = metaSockets + v end
        end
    end
    AddStats(stats, base)
    local filled, metaFilled, complete = 0, 0, true
    for _, g in ipairs({ g1 or "0", g2 or "0", g3 or "0", g4 or "0" }) do
        local gid = tonumber(g)
        if gid and gid > 0 then
            filled = filled + 1
            local gname, _, _, _, _, _, gsub = GetItemInfo(gid)
            if gsub == "Meta" then metaFilled = metaFilled + 1 end
            if not gname then complete = false
            elseif DSC.GEM_EFFECTS[gname] then AddStats(stats, DSC.GEM_EFFECTS[gname]) end
        end
    end
    if filled > 0 or (tonumber(ench) or 0) > 0 then
        local extra, ok = self:GemEnchantStats(link, bare)
        AddStats(stats, extra)
        if not ok then complete = false end
    end
    local empty = sockets - filled
    if metaSockets > metaFilled then empty = empty - (metaSockets - metaFilled) end     -- an empty meta socket is not credited
    if empty < 0 then empty = 0 end
    local bonusKey, bonusVal
    if filled > 0 and filled >= sockets then bonusKey, bonusVal = self:SocketBonus(link) end
    return stats, empty, bonusKey, bonusVal, complete
end

-- returns score  (nil when the item data is not available yet)
function DSC:Score(link, tip)
    if not spec or not link then return nil end
    local hit = cache[link]
    if hit then return hit end
    if DB().itemLevelFallback then
        local _, _, _, ilvl, _, _, _, _, loc = GetItemInfo(link)
        if loc and FALLBACK_LOC[loc] then
            if not ilvl then return nil end
            cache[link] = ilvl; cacheCount = cacheCount + 1
            return ilvl
        end
    end
    local stats, empty, bonusKey, bonusVal, complete = self:ItemStats(link)
    if not stats then return nil end
    local total = 0
    for key, w in pairs(spec.w) do
        local v = stats[key]
        if v then total = total + v * w end
    end
    if bonusKey and spec.w[bonusKey] then total = total + bonusVal * spec.w[bonusKey] end
    total = total + empty * (DB().socketValue or 0)
    if complete then                                     -- a gem that is not cached yet must not freeze a low score
        if cacheCount > 400 then self:ClearCache() end
        cache[link] = total
        cacheCount = cacheCount + 1
    end
    return total
end

local function IsEffectLine(text)
    if text:find("^Use:") or text:find("Chance on") or text:find("chance to") then return true end
    if text:find("^Equip:") then
        -- plain stat grants: "... rating by 40", "... power by 90", "Restores 12 mana per 5 sec"
        if text:find("rating by") or text:find("power by") or text:find("per 5 sec") or text:find("penetration by") then
            return text:find("when") ~= nil
        end
        return true
    end
    return false
end

local function TooltipHasEffect(tip)
    local name = tip:GetName()
    if not name then return false end
    for i = 2, (tip:NumLines() or 0) do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if t and IsEffectLine(t) then return true end
    end
    return false
end

-- what the player wears in the slots an item of that type would replace
function DSC:Equipped(loc)
    local slots = SLOTS[loc]
    if not slots then return nil end
    if slots.both then      -- two-hander: it replaces main hand and off hand
        local a = self:Score(GetInventoryItemLink("player", 16)) or 0
        local b = self:Score(GetInventoryItemLink("player", 17)) or 0
        return a + b
    end
    local lowest
    for _, id in ipairs(slots) do
        local link = GetInventoryItemLink("player", id)
        local s = link and self:Score(link) or 0
        if not lowest or s < lowest then lowest = s end
    end
    return lowest
end

function DSC:Total()
    local sum = 0
    for _, id in ipairs(SCORED_SLOTS) do
        local link = GetInventoryItemLink("player", id)
        if link then sum = sum + (self:Score(link) or 0) end
    end
    return sum
end

-- ============================================================ tooltip
local function Fmt(n) return string.format("%d", math.floor(n + 0.5)) end

local function AddScore(tip)
    if not M.active or not DB().tooltip or not spec then return end
    if tip.dscoreDone then return end
    local name, link = tip:GetItem()
    if not link then return end
    local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)
    if not loc or not SLOTS[loc] then return end
    local usesIlvl = DB().itemLevelFallback and FALLBACK_LOC[loc]
    if loc == "INVTYPE_RELIC" and not usesIlvl then return end      -- relics have no stats to value
    local score = DSC:Score(link, tip)
    if not score then return end
    tip.dscoreDone = true
    local effect = not usesIlvl and TooltipHasEffect(tip)
    local line = "|cffffc800DreamScore:|r |cffaaaaaa(" .. (usesIlvl and "item level" or spec.name) .. ")|r " .. Fmt(score)
    local isCompareTip = (tip ~= GameTooltip and tip ~= ItemRefTooltip)    -- the side-by-side tooltip of what you wear
    local isWorn = false                                     -- hovering the very item you wear: nothing to compare
    for _, id in ipairs(SLOTS[loc]) do
        if GetInventoryItemLink("player", id) == link then isWorn = true end
    end
    if DB().compare and not isCompareTip and not isWorn then
        local worn = DSC:Equipped(loc)
        if worn and worn > 0 then
            local pct = (score - worn) / worn * 100
            local r, g, b = "ff4040", "ff4040", "ff4040"
            local col = pct > 0.5 and "40ff40" or (pct < -0.5 and "ff4040" or "aaaaaa")
            line = line .. string.format("  |cff%s%+.0f%%|r |cffaaaaaavs worn (%s)|r", col, pct, Fmt(worn))
        end
    end
    tip:AddLine(line)
    if effect then tip:AddLine("|cff888888DreamScore: this item has an effect that is not counted|r") end
    tip:Show()
end

local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    for _, n in ipairs(TOOLTIPS) do
        local tip = _G[n]
        if tip and tip.HookScript then
            tip:HookScript("OnTooltipSetItem", AddScore)
            tip:HookScript("OnTooltipCleared", function(t) t.dscoreDone = nil end)
        end
    end
end

-- ============================================================ events, slash, options
local frame = CreateFrame("Frame")
-- Talent and item data can arrive late after logging in or a loading screen, so every trigger also starts a
-- 10 second settling period in which the spec is looked at again every second.
local SETTLE = 10
local settleLeft, settleTick = 0, 0
local function Refresh()
    DSC:Detect()
    if DSC.Hint then DSC.Hint:Kick(); DSC.Hint:UpdateTotal() end
end
frame:SetScript("OnEvent", function()
    if not M.active then return end
    settleLeft, settleTick = SETTLE, 0
    Refresh()
end)
frame:SetScript("OnUpdate", function(_, dt)
    if settleLeft <= 0 or not M.active then return end
    settleLeft = settleLeft - dt
    settleTick = settleTick + dt
    if settleTick >= 1 then settleTick = 0; Refresh() end
end)

function M.OnEnable()
    M.active = true
    settleLeft, settleTick = SETTLE, 0
    DSC:Detect()
    Hook()
    for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN" }) do
        frame:RegisterEvent(e)
    end
    if DSC.Hint then DSC.Hint:On() end
end

function M.OnDisable()
    M.active = false
    frame:UnregisterAllEvents()
    if DSC.Hint then DSC.Hint:Off() end
end

function M.OnSlash(msg)
    msg = strlower(strtrim(msg or ""))
    DSC:Detect()
    if not spec then
        DS.Print("DreamScore: no weights for your class.")
        return
    end
    if msg == "upgrades" then
        if DSC.Hint then DSC.Hint:Kick(); DSC.Hint:Report() end
    elseif msg == "weights" then
        DS.Print("DreamScore weights, " .. spec.name .. " (" .. spec.source .. "):")
        local keys = {}
        for k in pairs(spec.w) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return spec.w[a] > spec.w[b] or (spec.w[a] == spec.w[b] and a < b) end)
        for _, k in ipairs(keys) do DS.Print(string.format("  %s  %.2f", STAT_NAME[k] or k, spec.w[k])) end
    else
        DS.Print(string.format("DreamScore, %s: your equipped gear scores %s.  (/dscore weights shows the values)", spec.name, Fmt(DSC:Total())))
    end
end

M.options = function()
    return {
        { type = "bool", key = "tooltip", label = "Show the score on item tooltips",
          get = function() return DB().tooltip end, set = function(v) DB().tooltip = v and true or false end },
        { type = "bool", key = "compare", label = "Compare with the item you wear",
          desc = "Adds how much better or worse the item is than what you wear in that slot (rings and trinkets: the weaker one).",
          disabled = function() return not DB().tooltip end,
          get = function() return DB().compare end, set = function(v) DB().compare = v and true or false end },
        { type = "bool", key = "upgradeHint", label = "Upgrade hint (!) on the character window",
          desc = "A small (!) on a character-window slot when your bags hold a better piece for your spec. Hover shows it, click swaps it in. Armor, jewelry and trinkets; no weapons yet.",
          get = function() return DB().upgradeHint end,
          set = function(v) DB().upgradeHint = v and true or false; if DSC.Hint then DSC.Hint:Kick() end end },
        { type = "bool", key = "itemLevelFallback", label = "Use item level for trinkets and relics",
          desc = "Trinkets and relics/idols work through effects that stats cannot value. With this on they are scored by their item level instead (the tooltip says so).",
          get = function() return DB().itemLevelFallback end,
          set = function(v) DB().itemLevelFallback = v and true or false; DSC:ClearCache(); if DSC.Hint then DSC.Hint:Kick() end end },
        { type = "bool", key = "charTotal", label = "Show your total on the character window",
          desc = "Your total DreamScore, under the trinkets next to the weapon slots.",
          get = function() return DB().charTotal end,
          set = function(v) DB().charTotal = v and true or false; if DSC.Hint then DSC.Hint:UpdateTotal(true) end end },
        { type = "slider", key = "socketValue", label = "Worth of an empty socket", min = 0, max = 30, step = 1,
          desc = "An item with empty sockets is credited with this many points per socket, so it is not unfairly compared with a gemmed one you wear.",
          get = function() return DB().socketValue end, set = function(v) DB().socketValue = v; DSC:ClearCache() end },
    }
end
