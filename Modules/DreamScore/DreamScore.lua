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
DSC.HARDCORE_MIN = 0.2        -- Hardcore: the least a point of stamina is worth, for specs that hardly value it
DSC.FULL_POINTS = 31          -- talent points in one tree that count as fully committed to that spec

local STAT_NAME = {
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_SPELL_POWER_SHORT = "spell power",
    ITEM_MOD_HEALING_POWER_SHORT = "healing power", ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_INTELLECT_SHORT = "intellect", ITEM_MOD_SPIRIT_SHORT = "spirit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", RESISTANCE0_NAME = "armor",
    ITEM_MOD_ATTACK_POWER_SHORT = "attack power", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "ranged attack power",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feral attack power", ITEM_MOD_STRENGTH_SHORT = "strength",
    ITEM_MOD_AGILITY_SHORT = "agility", ITEM_MOD_STAMINA_SHORT = "stamina",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "armor penetration", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense",
    ITEM_MOD_DODGE_RATING_SHORT = "dodge", ITEM_MOD_PARRY_RATING_SHORT = "parry",
    ITEM_MOD_BLOCK_RATING_SHORT = "block rating", ITEM_MOD_BLOCK_VALUE_SHORT = "block value",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "weapon DPS",
}
setmetatable(STAT_NAME, { __index = function(_, k) return (k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower()) end })

function DSC.StatName(k)
    local n = STAT_NAME[k] or k
    return (n:gsub("^%l", string.upper))
end

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
local defaults = { tooltip = true, compare = true, socketValue = 18, upgradeHint = true, itemLevelFallback = false, charTotal = true, hardcore = false, hardcoreMult = 2, effects = true, includeBank = true, capMode = "boss", capFloor = 10 }
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
    if DB().hardcore then       -- hardcore: it is not all about damage, so stamina counts more (default double, and never nothing)
        local copy = {}
        for k2, v2 in pairs(w) do copy[k2] = v2 end
        copy.ITEM_MOD_STAMINA_SHORT = math.max((w.ITEM_MOD_STAMINA_SHORT or 0) * (DB().hardcoreMult or 2), DSC.HARDCORE_MIN)
        w = copy
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
function DSC:ClearCache() cache, cacheCount = {}, 0; if DSC.capVals then for k in pairs(DSC.capVals) do DSC.capVals[k] = nil end end end

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
    if self.scanTip then scanTip = self.scanTip end
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

DSC.NAME_KEY = NAME_KEY
local function AddStats(into, from)
    for k, v in pairs(from) do
        if type(k) == "string" and not k:find("^EMPTY_SOCKET_") and type(v) == "number" then into[k] = (into[k] or 0) + v end
    end
end


-- ============================================================ set bonuses
-- "(2) Set: Increases your spell power by 150." -> stats, when the bonus is a plain stat grant. Bonuses with
-- conditions ("when", "chance", "each time", durations) are effects and are not counted.
local SET_STATS = {
    { "ranged attack power by (%d+)", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    { "attack power by (%d+)", "ITEM_MOD_ATTACK_POWER_SHORT", skipIf = "ranged attack power by" },
    { "spell power by (%d+)", "ITEM_MOD_SPELL_POWER_SHORT" },
    { "critical strike rating by (%d+)", "ITEM_MOD_CRIT_RATING_SHORT" },
    { "crit rating by (%d+)", "ITEM_MOD_CRIT_RATING_SHORT" },
    { "haste rating by (%d+)", "ITEM_MOD_HASTE_RATING_SHORT" },
    { "hit rating by (%d+)", "ITEM_MOD_HIT_RATING_SHORT" },
    { "expertise rating by (%d+)", "ITEM_MOD_EXPERTISE_RATING_SHORT" },
    { "armor penetration rating by (%d+)", "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
    { "defense rating by (%d+)", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
    { "dodge rating by (%d+)", "ITEM_MOD_DODGE_RATING_SHORT" },
    { "parry rating by (%d+)", "ITEM_MOD_PARRY_RATING_SHORT" },
    { "block rating by (%d+)", "ITEM_MOD_BLOCK_RATING_SHORT" },
    { "block value of your shield by (%d+)", "ITEM_MOD_BLOCK_VALUE_SHORT" },
    { "restores (%d+) mana per 5 sec", "ITEM_MOD_MANA_REGENERATION_SHORT" },
    { "mana per 5 seconds? by (%d+)", "ITEM_MOD_MANA_REGENERATION_SHORT" },
    { "your intellect by (%d+)", "ITEM_MOD_INTELLECT_SHORT" },
    { "your spirit by (%d+)", "ITEM_MOD_SPIRIT_SHORT" },
    { "your strength by (%d+)", "ITEM_MOD_STRENGTH_SHORT" },
    { "your agility by (%d+)", "ITEM_MOD_AGILITY_SHORT" },
    { "your stamina by (%d+)", "ITEM_MOD_STAMINA_SHORT" },
    { "your armor by (%d+)", "RESISTANCE0_NAME" },
}
local SET_CONDITION = { "when", "chance", "each time", "for %d+ sec", "on hit", "after", "whenever", "if you" }

-- the stats of the effect text, or nil when it is not a plain stat grant
local function ParseSetEffect(text)
    local t = strlower(text or "")
    for _, c in ipairs(SET_CONDITION) do if t:find(c) then return nil end end
    local out
    for _, d in ipairs(SET_STATS) do
        local n = t:match(d[1])
        if n and not (d.skipIf and t:find(d.skipIf)) then
            out = out or {}
            out[d[2]] = (out[d[2]] or 0) + tonumber(n)
        end
    end
    return out
end
DSC.ParseSetEffect = ParseSetEffect

-- the plain stat bonuses of the set an item belongs to, split over the pieces it takes: a 2-piece bonus counts half
-- for each of its two pieces, a 3-piece bonus a third, and so on, so what is worn and what is looked at share it
function DSC:SetBonusStats(link)
    local lines = self:TooltipLines(link)
    local out, parsed = {}, 0
    for _, text in ipairs(lines) do
        local n, effect = text:match("^%((%d+)%) Set: (.+)$")
        if n then
            local stats = ParseSetEffect(effect)
            if stats then
                parsed = parsed + 1
                local pieces = math.max(1, tonumber(n))
                for k, v in pairs(stats) do out[k] = (out[k] or 0) + v / pieces end
            end
        end
    end
    return out, parsed
end

-- the "+N Stat" lines of an item's tooltip as a stat table (gem lines like "+9 Spell Power and +8 Spirit" included)
function DSC:TooltipLines(link, withRight)
    if self.scanTip then scanTip = self.scanTip end                           -- (a test can supply its own)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "DreamScoreScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    local out, n = {}, scanTip:NumLines() or 0
    for i = 2, n do
        local fs = _G["DreamScoreScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and withRight then      -- the cooldown of a Use: effect can sit on the right
            local rs = _G["DreamScoreScanTipTextRight" .. i]
            local right = rs and rs:GetText()
            if right and right ~= "" and right:lower():find("cooldown") then text = text .. " (" .. right .. ")" end
        end
        if text then out[#out + 1] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    end
    return out, n > 0
end

function DSC:TooltipStats(link)
    local lines, ok = self:TooltipLines(link)
    local out = {}
    for _, text in ipairs(lines) do
        if text:find("^%+%d") then
            for seg in (text:gsub(" and ", "|")):gmatch("[^|]+") do
                local n, what = seg:match("^%s*%+(%d+) (.-)[%.%s]*$")
                local keys = what and NAME_KEY[strlower(what)]
                if keys then for _, k in ipairs(keys) do out[k] = (out[k] or 0) + tonumber(n) end end
            end
        end
    end
    return out, ok
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
    AddStats(stats, (self:SetBonusStats(link)))
    if DB().effects and DSC.Effects then AddStats(stats, (DSC.Effects:Stats(link))) end
    local empty = sockets - filled
    if metaSockets > metaFilled then empty = empty - (metaSockets - metaFilled) end     -- an empty meta socket is not credited
    if empty < 0 then empty = 0 end
    local bonusKey, bonusVal
    if filled > 0 and filled >= sockets then bonusKey, bonusVal = self:SocketBonus(link) end
    return stats, empty, bonusKey, bonusVal, complete
end

-- ============================================================ hit and defense caps
-- Past a cap a stat is worth much less. The totals come from the game (gear, gems, buffs, talents), so the room an
-- item has left depends on everything else you have, not on the item that is being replaced.
local HIT, DEF = "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"
local HIT_CAPS = {              -- percent: { same level mobs, boss level mobs }
    melee = { 5, 8 }, ranged = { 5, 8 }, spell = { 4, 17 },
}
local WHITE_CAP_DW = 27         -- boss level, dual wielding: white attacks miss 8% + 19%
local DEF_CAP = 540             -- defense skill that makes you uncrittable by bosses
local CAP_MODES = { off = true, same = true, boss = true, white = true }
DSC.CAP_MODES = CAP_MODES

local function SpecKind()
    if not spec then return "melee" end
    local _, class = UnitClass("player")
    if class == "HUNTER" then return "ranged" end
    local w = spec.w
    if (w.ITEM_MOD_SPELL_POWER_SHORT or 0) > (w.ITEM_MOD_ATTACK_POWER_SHORT or 0) then return "spell" end
    return "melee"
end

local function DualWielding()
    local link = GetInventoryItemLink("player", 17)
    if not link then return false end
    local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)
    return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_WEAPONMAINHAND"
end

local function WornRating(statKey)          -- the stat summed over the worn items (fallback when the game's totals are unavailable)
    local sum = 0
    for _, id in ipairs(SCORED_SLOTS) do
        local link = GetInventoryItemLink("player", id)
        local vals = link and DSC.capVals[link]
        if vals then sum = sum + (vals[statKey] or 0) end
    end
    return sum
end

-- { have = the amount you have now (in %, or skill points), per = rating per % (skill point), cap = the cap }
function DSC:CapInfo(statKey)
    local mode = DB().capMode or "boss"
    if mode == "off" or not spec then return nil end
    if statKey == HIT then
        local kind = SpecKind()
        local crType = (kind == "spell" and CR_HIT_SPELL) or (kind == "ranged" and CR_HIT_RANGED) or CR_HIT_MELEE
        local per = kind == "spell" and 26.23 or 32.79
        local have
        if GetCombatRating and GetCombatRatingBonus and crType then
            local rating, bonus = GetCombatRating(crType), GetCombatRatingBonus(crType)
            if rating and bonus and rating > 0 and bonus > 0 then per = rating / bonus end
            local mod = (kind == "spell" and GetSpellHitModifier and GetSpellHitModifier()) or (kind ~= "spell" and GetHitModifier and GetHitModifier()) or 0
            have = (bonus or 0) + (mod or 0)
        else
            have = WornRating(HIT) / per
        end
        local caps = HIT_CAPS[kind]
        local cap = mode == "same" and caps[1] or caps[2]
        if mode == "white" and kind ~= "spell" and DualWielding() then cap = WHITE_CAP_DW end
        local info = { have = have, per = per, cap = cap }
        -- Enhancement casts too: past the melee cap hit rating is still worth half until about 14% spell hit
        -- (spell hit takes 26.23 rating per 1%, melee 32.79, so the same rating gives more spell hit than melee hit)
        if kind == "melee" and spec.name and strfind(spec.name, "^Enhancement") and mode ~= "same" then
            info.cap2 = 14 * 26.23 / per
        end
        return info
    elseif statKey == DEF then
        if not (spec.w[DEF] and spec.w[DEF] > 0) then return nil end
        local per, have = 4.9185, nil
        if UnitDefense then
            local base, mod = UnitDefense("player")
            if base then have = base + (mod or 0) end
        end
        if CR_DEFENSE_SKILL and GetCombatRating and GetCombatRatingBonus then
            local rating, bonus = GetCombatRating(CR_DEFENSE_SKILL), GetCombatRatingBonus(CR_DEFENSE_SKILL)
            if rating and bonus and rating > 0 and bonus > 0 then per = rating / bonus end
        end
        if not have then have = 400 + WornRating(DEF) / per end
        return { have = have, per = per, cap = DEF_CAP }
    end
end

-- the part of an item's stat that counts: all of it while there is room under the cap, the rest at a reduced value
function DSC:Counted(v, replaced, info)
    local others = info.have - (replaced or 0) / info.per
    local room = math.max(0, (info.cap - others) * info.per)
    local floor = (DB().capFloor or 10) / 100
    local mid = 0
    if info.cap2 and info.cap2 > info.cap then
        mid = math.min(math.max(0, v - room), math.max(0, (info.cap2 - others) * info.per - room))
    end
    return math.min(v, room) + mid * 0.5 + math.max(0, v - room - mid) * floor
end

DSC.capVals = {}
local capVals = DSC.capVals

-- the worn items among the links given (an item that is worn replaces itself)
local function WornSelf(link)
    for _, id in ipairs(SCORED_SLOTS) do
        if GetInventoryItemLink("player", id) == link then return true end
    end
    return false
end

-- returns the score without the caps  (nil when the item data is not available yet)
function DSC:BaseScore(link)
    local hit = cache[link]
    if hit then return hit end
    if DB().itemLevelFallback then
        local _, _, _, ilvl, _, _, _, _, loc = GetItemInfo(link)
        if loc and FALLBACK_LOC[loc] then
            if not ilvl then return nil end
            cache[link] = ilvl; cacheCount = cacheCount + 1
            capVals[link] = nil
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
    capVals[link] = { [HIT] = stats[HIT] or 0, [DEF] = stats[DEF] or 0 }
    return total
end

-- replacing: the worn links this item would take the place of (worn items replace themselves)
function DSC:Score(link, replacing)
    if not spec or not link then return nil end
    local total = self:BaseScore(link)
    if not total then return nil end
    local vals = capVals[link]
    if not vals then return total end
    if not replacing and WornSelf(link) then replacing = { link } end
    for _, statKey in ipairs({ HIT, DEF }) do
        local v, w = vals[statKey], spec.w[statKey]
        if v and v > 0 and w and w > 0 then
            local info = self:CapInfo(statKey)
            if info then
                local replaced = 0
                for _, r in ipairs(replacing or {}) do
                    local rv = capVals[r] or (self:BaseScore(r) and capVals[r])
                    replaced = replaced + (rv and rv[statKey] or 0)
                end
                total = total - w * (v - self:Counted(v, replaced, info))
            end
        end
    end
    return total
end

local function IsEffectLine(text)
    local setEffect = text:match("^%(%d+%) Set: (.+)$")
    if setEffect then return DSC.ParseSetEffect(setEffect) == nil end         -- a plain stat set bonus is counted
    if DB().effects and DSC.Effects and DSC.Effects.Parse(text) then return false end      -- an effect that was turned into stats
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
        if t then
            local rs = _G[name .. "TextRight" .. i]
            local right = rs and rs:GetText()
            if right and right ~= "" and right:lower():find("cooldown") then t = t .. " (" .. right .. ")" end   -- Use: cooldown on the right
            t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if IsEffectLine(t) then return true end
        end
    end
    return false
end

-- what the player wears in the slots an item of that type would replace
function DSC:Equipped(loc)
    local slots = SLOTS[loc]
    if not slots then return nil end
    if slots.both then      -- two-hander: it replaces main hand and off hand
        local l1, l2 = GetInventoryItemLink("player", 16), GetInventoryItemLink("player", 17)
        local a = l1 and self:Score(l1) or 0
        local b = l2 and self:Score(l2) or 0
        local repl = {}
        if l1 then repl[#repl + 1] = l1 end
        if l2 then repl[#repl + 1] = l2 end
        return a + b, repl
    end
    local lowest, lowLink
    for _, id in ipairs(slots) do
        local link = GetInventoryItemLink("player", id)
        local s = link and self:Score(link) or 0
        if not lowest or s < lowest then lowest, lowLink = s, link end
    end
    return lowest, lowLink and { lowLink } or {}
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
    local worn, replacing = DSC:Equipped(loc)
    local score = DSC:Score(link, replacing)
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

-- /dscore audit: what DreamScore reads on every piece you wear, and what it leaves out
local SLOT_LABEL = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
    [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
    [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }
local function Short(link) return (link:match("%[(.-)%]")) or link end

function DSC:AuditItem(link)
    local stats, empty, bonusKey, bonusVal, complete = self:ItemStats(link)
    if not stats then return nil end
    local counted, unweighted = {}, {}
    for k, v in pairs(stats) do
        local w = spec and spec.w[k]
        local txt = string.format("%s %s", math.floor(v * 10 + 0.5) / 10, DSC.StatName(k))
        if w and w > 0 then counted[#counted + 1] = txt else unweighted[#unweighted + 1] = txt end
    end
    table.sort(counted); table.sort(unweighted)
    local unread = {}
    for _, text in ipairs(self:TooltipLines(link, true)) do
        if text:find("^%+%d") then
            for seg in (text:gsub(" and ", "|")):gmatch("[^|]+") do
                local what = seg:match("^%s*%+%d+ (.-)[%.%s]*$")
                if what and not NAME_KEY[strlower(what)] then unread[#unread + 1] = seg end
            end
        elseif IsEffectLine(text) then
            unread[#unread + 1] = text:sub(1, 60)
        end
    end
    return { counted = counted, unweighted = unweighted, unread = unread, empty = empty, bonusKey = bonusKey,
             bonusVal = bonusVal, complete = complete, score = self:Score(link) }
end

function DSC:Audit()
    if not spec then DS.Print("DreamScore audit: no weights for your class."); return end
    DS.Print("DreamScore audit, " .. spec.name .. ": what is read on each worn item")
    for _, id in ipairs(SCORED_SLOTS) do
        local link = GetInventoryItemLink("player", id)
        if link then
            local a = self:AuditItem(link)
            if a then
                DS.Print(string.format("%s: %s = %s%s", SLOT_LABEL[id] or id, Short(link), Fmt(a.score or 0),
                    a.complete and "" or "  (gem or enchant data still loading)"))
                if #a.counted > 0 then DS.Print("   counted: " .. table.concat(a.counted, ", ")) end
                if a.bonusKey then DS.Print(string.format("   socket bonus: +%d %s", a.bonusVal or 0, DSC.StatName(a.bonusKey))) end
                if a.empty > 0 then DS.Print(string.format("   %d empty socket(s) credited", a.empty)) end
                if #a.unweighted > 0 then DS.Print("   read but not valued by this spec: " .. table.concat(a.unweighted, ", ")) end
                if #a.unread > 0 then DS.Print("   |cffff8040not read|r: " .. table.concat(a.unread, " | ")) end
            end
        end
    end
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

-- ============================================================ hardcore detection
-- ChromieCraft documents no buff for its Hardcore challenge, so this matches any buff with "hardcore" in its name.
-- It asks once per character; /dscore hardcore asks again.
local function HardcoreAura()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then return nil end
        if strfind(strlower(name), "hardcore", 1, true) then return name end
    end
end
DSC.HardcoreAura = HardcoreAura

local hcFrame
function DSC:AskHardcore(auraName)
    if not hcFrame then
        local f = CreateFrame("Frame", "DreamScoreHardcoreFrame", UIParent)
        f:SetSize(330, 170); f:SetPoint("CENTER", 0, 120); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("TOP", 0, -16)
        f.title:SetText("DreamScore: Hardcore")
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("TOP", 0, -38); f.text:SetWidth(290); f.text:SetJustifyH("CENTER")
        local sl = CreateFrame("Slider", "DreamScoreHardcoreSlider", f, "OptionsSliderTemplate")
        sl:SetPoint("TOP", 0, -92); sl:SetWidth(240); sl:SetMinMaxValues(1, 4); sl:SetValueStep(0.5)
        _G[sl:GetName() .. "Low"]:SetText("1x"); _G[sl:GetName() .. "High"]:SetText("4x")
        sl:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v * 2 + 0.5) / 2
            _G[self:GetName() .. "Text"]:SetText("Stamina counts " .. v .. "x")
            self.value = v
        end)
        f.slider = sl
        local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ok:SetSize(120, 22); ok:SetPoint("BOTTOMLEFT", 24, 18); ok:SetText("Use Hardcore")
        ok:SetScript("OnClick", function()
            DB().hardcore = true; DB().hardcoreMult = f.slider.value or 2
            f:Hide(); DSC:Detect(); DSC:ClearCache()
            if DSC.Hint then DSC.Hint:Kick(); DSC.Hint:UpdateTotal() end
        end)
        local no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        no:SetSize(120, 22); no:SetPoint("BOTTOMRIGHT", -24, 18); no:SetText("Not now")
        no:SetScript("OnClick", function() f:Hide() end)
        tinsert(UISpecialFrames, "DreamScoreHardcoreFrame")
        hcFrame = f
    end
    hcFrame.text:SetText(auraName and ("You have the buff \"" .. auraName .. "\". Count stamina higher in scores? (Surviving matters on a Hardcore run.)")
        or "Count stamina higher in your scores? (Surviving matters on a Hardcore run.)")
    hcFrame.slider:SetValue(DB().hardcoreMult or 2)
    hcFrame:Show()
end

-- once per character, when the buff is seen and Hardcore scoring is still off
function DSC:CheckHardcore()
    if DB().hardcore or InCombatLockdown() then return end
    local d = DB()
    d.hcAsked = d.hcAsked or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    if d.hcAsked[key] then return end
    local aura = HardcoreAura()
    if aura then
        d.hcAsked[key] = true
        self:AskHardcore(aura)
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
    DSC:CheckHardcore()
    if DSC.Hint then DSC.Hint:Kick(); DSC.Hint:UpdateTotal() end
end
frame:SetScript("OnEvent", function(_, event, unit)
    if not M.active then return end
    if event == "UNIT_AURA" then
        if unit == "player" then DSC:CheckHardcore() end
        return
    end
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
    for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN", "UNIT_AURA" }) do
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
    if msg == "audit" then
        DSC:Audit()
    elseif msg == "specs" or msg == "spec" then
        if DSC.Weights then DSC.Weights:Show() end
    elseif msg == "hardcore" then
        DSC:AskHardcore(HardcoreAura())
    elseif msg == "upgrades" then
        if DSC.Hint then DSC.Hint:Kick(); DSC.Hint:Report() end
    elseif msg == "weights" then
        DS.Print("DreamScore weights, " .. spec.name .. " (" .. spec.source .. "):")
        local keys = {}
        for k in pairs(spec.w) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return spec.w[a] > spec.w[b] or (spec.w[a] == spec.w[b] and a < b) end)
        for _, k in ipairs(keys) do DS.Print(string.format("  %s  %.2f", STAT_NAME[k] or k, spec.w[k])) end
    else
        DS.Print(string.format("DreamScore, %s: your equipped gear scores %s.  (/dscore weights, /dscore specs, /dscore audit, /dscore upgrades, /dscore hardcore)", spec.name, Fmt(DSC:Total())))
    end
end

M.options = function()
    local function Kick() if DSC.Hint then DSC.Hint:Kick() end end
    return {
        { type = "tab", label = "General" },
        { type = "bool", key = "tooltip", label = "Show the score on item tooltips",
          get = function() return DB().tooltip end, set = function(v) DB().tooltip = v and true or false end },
        { type = "bool", key = "compare", label = "Compare with the item you wear",
          desc = "Adds how much better or worse the item is than what you wear in that slot (rings and trinkets: the weaker one).",
          disabled = function() return not DB().tooltip end,
          get = function() return DB().compare end, set = function(v) DB().compare = v and true or false end },
        { type = "bool", key = "charTotal", label = "Show your total on the character window",
          desc = "Your total DreamScore, under the trinkets next to the weapon slots.",
          get = function() return DB().charTotal end,
          set = function(v) DB().charTotal = v and true or false; if DSC.Hint then DSC.Hint:UpdateTotal(true) end end },
        { type = "bool", key = "upgradeHint", label = "Upgrade hint (!) on the character window",
          desc = "A small (!) on a character-window slot when your bags hold a better piece for your spec. Hover shows it, click swaps it in. Armor, jewelry and trinkets; no weapons yet.",
          get = function() return DB().upgradeHint end,
          set = function(v) DB().upgradeHint = v and true or false; Kick() end },
        { type = "bool", key = "includeBank", label = "Count bank and guild bank items too",
          desc = "The (!) hint also looks at gear in your bank and guild bank, as it was when you last had those windows open (a guild bank tab counts once you have looked at it). Click does not swap those: take them out first.",
          disabled = function() return not DB().upgradeHint end,
          get = function() return DB().includeBank end,
          set = function(v) DB().includeBank = v and true or false; Kick() end },

        { type = "tab", label = "Scoring" },
        { type = "bool", key = "hardcore", label = "Hardcore: stamina counts more",
          desc = "Surviving matters as well as damage. With this on, stamina is worth the chosen multiple of what the spec gives it (at least 0.20 where a spec hardly values it).",
          get = function() return DB().hardcore end,
          set = function(v) DB().hardcore = v and true or false; DSC:Detect(); DSC:ClearCache(); Kick() end },
        { type = "slider", key = "hardcoreMult", label = "Hardcore stamina multiplier", min = 1, max = 4, step = 0.5,
          desc = "How many times the spec's stamina weight counts while Hardcore is on. 2 = double.",
          disabled = function() return not DB().hardcore end,
          get = function() return DB().hardcoreMult or 2 end,
          set = function(v) DB().hardcoreMult = v; DSC:Detect(); DSC:ClearCache(); Kick() end },
        { type = "bool", key = "itemLevelFallback", label = "Use item level for trinkets and relics",
          desc = "Trinkets and relics/idols work through effects that stats cannot value. With this on they are scored by their item level instead (the tooltip says so).",
          get = function() return DB().itemLevelFallback end,
          set = function(v) DB().itemLevelFallback = v and true or false; DSC:ClearCache(); Kick() end },
        { type = "bool", key = "effects", label = "Count Use: and proc effects",
          desc = "Trinkets and weapons that grant a stat for a while: the amount is averaged over how often it can happen (amount x seconds it lasts / seconds between uses or procs) and weighed like a normal stat. Procs are read when the tooltip gives their chance and cooldown or procs per minute. Healing and damage effects cannot be counted.",
          get = function() return DB().effects end,
          set = function(v) DB().effects = v and true or false; DSC:ClearCache(); Kick() end },
        { type = "slider", key = "socketValue", label = "Worth of an empty socket", min = 0, max = 30, step = 1,
          desc = "An item with empty sockets is credited with this many points per socket, so it is not unfairly compared with a gemmed one you wear.",
          get = function() return DB().socketValue end, set = function(v) DB().socketValue = v; DSC:ClearCache() end },
        { type = "choice", key = "capMode", label = "Hit and defense caps",
          desc = "Hit rating (and defense for tanks) is worth much less once you are past what you need. Your hit from gear, gems, buffs and talents is read from the game. Same level / Boss: the cap against such mobs. White hit: the cap for dual wielders' normal attacks (27%). Casters use their spell hit cap.",
          values = { "off", "same", "boss", "white" },
          valueLabels = { off = "Off", same = "Same lvl", boss = "Boss", white = "White hit" },
          get = function() return DB().capMode end,
          set = function(v) DB().capMode = v; DSC:ClearCache(); Kick() end },
        { type = "slider", key = "capFloor", label = "Value past the cap (%)", min = 0, max = 50, step = 5,
          desc = "How much of its normal weight a point of hit or defense keeps once the cap is reached.",
          disabled = function() return (DB().capMode or "boss") == "off" end,
          get = function() return DB().capFloor end, set = function(v) DB().capFloor = v; DSC:ClearCache(); Kick() end },

        { type = "tab", label = "Specs" },
        { type = "frame", wide = true, height = 372, build = function(parent) return DSC.Weights:NewView(parent, 716) end },
    }
end
