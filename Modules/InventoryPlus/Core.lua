--[[ InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
     Core: categories, tab data, routing, sorting, move queue.  WoW 3.3.5a / Lua 5.1 ]]

-- DreamSuite module. The global `InventoryPlus` (the API other addons may use) is published while the
-- module is on. Switching off hides every tab, stops routing / sorting / deleting, and puts every item
-- button back (alpha, glow, ignore marks). Toggling waits for the end of combat (secure = true).
local DS = DreamSuite
local BT = {}
DS.InventoryPlusCore = BT      -- Tabs / Warehouse / Options share the module through this table
local M = DS.RegisterModule({
    id      = "InventoryPlus",
    title   = "InventoryPlus",
    desc    = "Category tabs on your bags: highlight a type, route loot to the right bag, sort, auto-delete junk, and a cross-character Warehouse",
    slash   = { "/inventoryplus", "/invplus", "/ip" },
    secure  = true,
    legacy  = { folder = "InventoryPlus", db = "InventoryPlusDB", charDb = "InventoryPlusCharDB" },
    profileSkip = { chars = true, items = true },      -- the warehouse is collected data, not a setting
    quick   = { { text = "Warehouse", func = function() if BT.Options then BT.Options:Show("warehouse") end end } },   -- minimap right-click
})
BT.module = M
BT.enabled = false

local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local GetTime = GetTime

BT.INV_BAGS  = { 0, 1, 2, 3, 4 }
BT.BANK_BAGS = { 5, 6, 7, 8, 9, 10, 11 }
BT.MAX_TABS  = 8

-- ============================================================ categories
local I = "Interface\\Icons\\"
BT.CATS = {
    { key = "Quest", hint = "Items flagged as quest items: quest objectives and items that start a quest.",       label = "Quest",         icon = I.."INV_Misc_Note_01",       color = { 1.00, 0.82, 0.00 } },
    { key = "Junk", hint = "Grey (poor quality) items that are not quest items. Usually only good for the vendor.",        label = "Junk",          icon = I.."INV_Misc_Coin_01",       color = { 0.62, 0.62, 0.62 } },
    { key = "Gear", hint = "Everything you wear: armor of every type (cloth, leather, mail, plate), cloaks, rings, necklaces, trinkets, shirts, tabards, relics. Shields are under Weapons.",        label = "Gear",          icon = I.."INV_Chest_Plate06",      color = { 0.80, 0.82, 1.00 } },
    { key = "Gear:Common", parent = "Gear", label = "White (Common)", hint = "Gear of white (common) quality.", icon = I.."INV_Chest_Plate06", color = { 1, 1, 1 } },
    { key = "Gear:Uncommon", parent = "Gear", label = "Green (Uncommon)", hint = "Gear of green (uncommon) quality.", icon = I.."INV_Chest_Plate06", color = { 0.12, 1, 0.2 } },
    { key = "Gear:Rare", parent = "Gear", label = "Blue (Rare)", hint = "Gear of blue (rare) quality.", icon = I.."INV_Chest_Plate06", color = { 0.2, 0.5, 1 } },
    { key = "Gear:Epic", parent = "Gear", label = "Epic or better", hint = "Gear of epic (purple) quality or better.", icon = I.."INV_Chest_Plate06", color = { 0.7, 0.3, 1 } },
    { key = "Weapons", hint = "Weapons of every kind (melee, bows, guns, wands, thrown) and shields.",     label = "Weapons",       icon = I.."INV_Sword_04",           color = { 1.00, 0.40, 0.30 } },
    { key = "Weapons:Common", parent = "Weapons", label = "White (Common)", hint = "Weapons and shields of white (common) quality.", icon = I.."INV_Sword_04", color = { 1, 1, 1 } },
    { key = "Weapons:Uncommon", parent = "Weapons", label = "Green (Uncommon)", hint = "Weapons and shields of green (uncommon) quality.", icon = I.."INV_Sword_04", color = { 0.12, 1, 0.2 } },
    { key = "Weapons:Rare", parent = "Weapons", label = "Blue (Rare)", hint = "Weapons and shields of blue (rare) quality.", icon = I.."INV_Sword_04", color = { 0.2, 0.5, 1 } },
    { key = "Weapons:Epic", parent = "Weapons", label = "Epic or better", hint = "Weapons and shields of epic (purple) quality or better.", icon = I.."INV_Sword_04", color = { 0.7, 0.3, 1 } },
    { key = "Consumables", hint = "Potions, elixirs, flasks, food and drink, bandages, scrolls and item enhancements. Conjured food and water are under Conjured.", label = "Consumables",   icon = I.."INV_Potion_54",          color = { 0.40, 0.90, 0.50 } },
    { key = "Conjured", hint = "Items created by spells: mage food and water, mana gems, healthstones and soulstones.",    label = "Conjured",      icon = I.."Spell_Shadow_SoulGem",   color = { 0.70, 0.50, 1.00 } },
    { key = "RawFood", hint = "Uncooked food: raw meat and fish, fruit and other ingredients you eat or cook with. Cooked and crafted food is under Consumables.", label = "Raw Food", icon = I.."INV_Misc_Food_15", color = { 0.90, 0.45, 0.45 } },
    { key = "Crafting", hint = "Profession materials. Tick the whole category, or pick sub-categories (cloth, leather, ore, herbs, enchanting...). Gems, raw food and spell reagents have their own categories.",    label = "Crafting",      icon = I.."INV_Misc_Gear_01",       color = { 0.95, 0.85, 0.40 } },
    { key = "Crafting:Cloth", parent = "Crafting", label = "Cloth", hint = "Linen, Wool, Silk, Mageweave, Runecloth, Netherweave, Frostweave and other cloth.", icon = I.."INV_Fabric_Linen_01", color = { 0.8, 0.7, 1 }, prof = "Tailoring", sortGroup = true },
    { key = "Crafting:Leather", parent = "Crafting", label = "Leather", hint = "Leather, hides, scales and other skinning drops.", icon = I.."INV_Misc_LeatherScrap_02", color = { 0.8, 0.55, 0.3 }, prof = "Skinning, Leatherworking", sortGroup = true },
    { key = "Crafting:Ore", parent = "Crafting", label = "Ore & Stone", hint = "Ore, bars and stone.", icon = I.."INV_Ore_Copper_01", color = { 0.75, 0.75, 0.8 }, prof = "Mining, Blacksmithing", sortGroup = true },
    { key = "Crafting:Herbs", parent = "Crafting", label = "Herbs", hint = "Herbs and flowers.", icon = I.."INV_Misc_Herb_07", color = { 0.4, 0.9, 0.4 }, prof = "Herbalism, Alchemy", sortGroup = true },
    { key = "Crafting:Enchanting", parent = "Crafting", label = "Enchanting", hint = "Dusts, essences, shards and other enchanting materials.", icon = I.."INV_Enchant_DustArcane", color = { 0.7, 0.5, 1 }, prof = "Enchanting", sortGroup = true },
    { key = "Crafting:Jewelcrafting", parent = "Crafting", label = "Jewelcrafting", hint = "Jewelcrafting materials. Cut and uncut gems are under Gems.", icon = I.."INV_Misc_Gem_01", color = { 0.4, 0.9, 0.9 }, prof = "Jewelcrafting", sortGroup = true },
    { key = "Crafting:Engineering", parent = "Crafting", label = "Engineering", hint = "Parts, devices and explosives.", icon = I.."INV_Misc_Gear_01", color = { 0.95, 0.85, 0.4 }, prof = "Engineering", sortGroup = true },
    { key = "Crafting:Elemental", parent = "Crafting", label = "Elemental", hint = "Elemental materials such as motes, primals and eternals.", icon = I.."INV_Misc_Gear_01", color = { 0.95, 0.6, 0.3 }, prof = "Various", sortGroup = true },
    { key = "Crafting:Inscription", parent = "Crafting", label = "Inscription", hint = "Pigments, inks and parchment (recognised by name).", icon = I.."INV_Inscription_Tradeskill01", color = { 0.9, 0.75, 0.55 }, prof = "Inscription", sortGroup = true },
    { key = "Crafting:Other", parent = "Crafting", label = "Other materials", hint = "Any crafting material the game does not file under a profession.", icon = I.."INV_Misc_Gear_01", color = { 0.8, 0.8, 0.8 }, sortGroup = true },
    { key = "Reagents", hint = "Spell reagents that get used up when casting: Rune of Teleportation, Symbol of Kings, Ankh, Arcane Powder and the like.",    label = "Reagents",      icon = I.."INV_Misc_Candle_01",     color = { 0.95, 0.60, 0.30 } },
    { key = "Gems", hint = "Cut and uncut gems.",        label = "Gems",          icon = I.."INV_Misc_Gem_01",        color = { 0.40, 0.90, 0.90 } },
    { key = "Recipes", hint = "Profession recipes, patterns, plans, formulae and schematics.",     label = "Recipes",       icon = I.."INV_Scroll_03",          color = { 0.90, 0.75, 0.55 } },
    { key = "Containers", hint = "Bags, quivers and ammo pouches.",  label = "Containers",    icon = I.."INV_Misc_Bag_08",        color = { 0.75, 0.60, 0.40 } },
    { key = "Ammo", hint = "Arrows and bullets.",        label = "Ammo",          icon = I.."INV_Ammo_Arrow_02",      color = { 0.80, 0.80, 0.50 } },
    { key = "Glyphs", hint = "Inscription glyphs.",      label = "Glyphs",        icon = I.."INV_Misc_Book_09",       color = { 0.60, 0.60, 1.00 } },
    { key = "Misc", hint = "Everything else: mounts, pets, keys, tokens and other odds and ends.",        label = "Miscellaneous", icon = I.."INV_Misc_QuestionMark",  color = { 0.75, 0.75, 0.75 } },
}
-- categories that existed in 0.1 -> where saved tabs get migrated to
local MIGRATE = { Cloth = "Gear", Leather = "Gear", Mail = "Gear", Plate = "Gear", Accessories = "Gear",
                  Shields = "Weapons", TradeGoods = "Crafting" }
BT.CAT = {}      -- key -> def
BT.CATIDX = {}   -- key -> order index
BT.PARENT = {}   -- sub-category key -> parent key
BT.SUBS = {}     -- parent key -> list of sub-category keys
for i, c in ipairs(BT.CATS) do BT.CAT[c.key] = c; BT.CATIDX[c.key] = i end
for _, c in ipairs(BT.CATS) do
    if c.parent then
        BT.PARENT[c.key] = c.parent
        BT.SUBS[c.parent] = BT.SUBS[c.parent] or {}
        tinsert(BT.SUBS[c.parent], c.key)
        c.full = BT.CAT[c.parent].label .. ": " .. c.label
    else
        c.full = c.label
    end
end

-- does a tab's category set cover an item of category `cat`? (a tab holding "Gear" also covers "Gear:Rare")
function BT:Matches(cats, cat)
    while cat do
        if cats[cat] then return cat end
        cat = BT.PARENT[cat]
    end
end

BT.SORTMODES = {
    { key = "quality", label = "Quality (best first)" },
    { key = "name",    label = "Name (A-Z)" },
    { key = "ilevel",  label = "Item level (high first)" },
    { key = "count",   label = "Stack size (large first)" },
}

local DEFAULTS = {
    routing = true, sortAfter = false, sortMode = "quality", dimAlpha = 0.22,
    side = "LEFT", showPlus = true, anim = true, manualLayout = true, colAnchor = "blizzard", colGap = 36, colWidth = 0, tooltip = true,
    offsetX = 0, offsetY = 0,
    junkDelete = false, junkMax = 100, junkMode = "item", optOpen = "last", junkReport = true, junkLog = {}, debug = false,
    ignore = {}, catTooltip = false, ignoreMark = true, whCollapsed = {},
    shardDelete = false, shardMax = 20,
    opDelay = 0.3,                 -- pause between two moves while sorting / routing (seconds), used when opAuto is off
    autoMerge = true,              -- merge loose partial stacks of the same item inside a bag when things go quiet
    upgradeHint = true,            -- tiny "!" on character slots when the bags hold an upgrade
    sortButton = true,             -- "Sort All" button above the first row of the backpack
    opAuto = true,                 -- follow what the server allows: pause = measured round trip, backing off on trouble
    chars = {}, items = {},
}

-- ============================================================ suggested setup
-- bag 1 = backpack ... bag 5 = the last bag slot. The Hearthstone is put on the ignore list (ignored items
-- keep their slot) and moved to slot 1 of bag 1.
local HEARTHSTONE = 6948
BT.SUGGESTED = {
    [0] = { { "Quest" }, { "Reagents" } },
    [1] = { { "Gear", "Weapons" }, { "Misc" } },
    [2] = { { "Crafting" } },
    [3] = { { "Consumables" }, { "Conjured" } },
    [4] = { { "RawFood" }, { "Junk" } },
}

function BT:ApplySuggested()
    for bag, defs in pairs(BT.SUGGESTED) do
        local tabs = {}
        for _, cats in ipairs(defs) do
            local set = {}
            for _, k in ipairs(cats) do set[k] = true end
            tabs[#tabs + 1] = { cats = set }
        end
        self.chardb.bags[bag] = tabs
    end
    self.db.ignore[HEARTHSTONE] = true
    for _, bag in ipairs(BT.INV_BAGS) do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link and BT.ItemID(link) == HEARTHSTONE and not (bag == 0 and slot == 1) then
                self:QueueExchange(bag, slot, 0, 1)
                self:Kick()
            end
        end
    end
    self:OnTabsChanged()
end

-- ============================================================ helpers
function BT:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00InventoryPlus|r: " .. tostring(msg))
end

local function ItemID(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
end
BT.ItemID = ItemID

function BT:IsIgnored(link)
    local id = ItemID(link)
    return (id and self.db.ignore[id]) and true or false
end

function BT:SetIgnored(id, on)
    self.db.ignore[id] = on and true or nil
    if self.OnIgnoreChanged then self:OnIgnoreChanged() end
end

function BT:Domain(bag)
    if bag >= 5 and bag <= 11 then return "bank" end
    return "inv"
end
function BT:DomainBags(domain)
    return domain == "bank" and BT.BANK_BAGS or BT.INV_BAGS
end

function BT:BagLabel(bag)
    if bag == 0 then return BACKPACK_TOOLTIP or "Backpack" end
    local n = GetBagName(bag)
    if n and n ~= "" then return n end
    if bag >= 5 then return "Bank bag " .. (bag - 4) end
    return "Bag " .. bag
end

-- normal (non-quiver/herb/soul) bag that exists
function BT:IsUsableBag(bag)
    local n = GetContainerNumSlots(bag)
    if not n or n == 0 then return false end
    if bag == 0 then return true end
    local _, btype = GetContainerNumFreeSlots(bag)
    return btype == nil or btype == 0
end

-- ============================================================ tab data
function BT:GetTabs(bag, create)
    local t = self.chardb.bags[bag]
    if not t and create then t = {}; self.chardb.bags[bag] = t end
    return t
end

function BT:TabName(def)
    if def.name and def.name ~= "" then return def.name end
    local parts = {}
    for _, c in ipairs(BT.CATS) do
        if def.cats[c.key] then parts[#parts + 1] = c.full end
    end
    if #parts == 0 then return "Empty" end
    if #parts <= 2 then return table.concat(parts, " + ") end
    return parts[1] .. " +" .. (#parts - 1)
end

function BT:TabIcon(def)
    for _, c in ipairs(BT.CATS) do
        if def.cats[c.key] then return c.icon, c.color end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark", { 0.7, 0.7, 0.7 }
end

function BT:CatList(cats)
    local parts = {}
    for _, c in ipairs(BT.CATS) do
        if cats[c.key] then parts[#parts + 1] = c.full end
    end
    return table.concat(parts, ", ")
end

-- bags (in domain) that should hold items of `cat`, ascending bag id. The most specific tab wins: when
-- one bag has a "Gear: Rare" tab and another a plain "Gear" tab, rare gear belongs to the first.
-- exact = only tabs naming this very category (used for display)
function BT:Owners(cat, domain, exact)
    local key = cat
    while key do
        local list = {}
        for _, bag in ipairs(self:DomainBags(domain)) do
            local tabs = self.chardb.bags[bag]
            if tabs then
                for _, t in ipairs(tabs) do
                    if t.cats[key] then list[#list + 1] = bag; break end
                end
            end
        end
        if #list > 0 or exact then return list, key end
        key = BT.PARENT[key]
    end
    return {}
end

function BT:IsHome(cat, bag)
    for _, b in ipairs(self:Owners(cat, self:Domain(bag))) do
        if b == bag then return true end
    end
    return false
end

-- categories a bag's tabs hold
function BT:BagWants(bag, cat)
    local tabs = self.chardb.bags[bag]
    if not tabs then return false end
    for _, t in ipairs(tabs) do if self:Matches(t.cats, cat) then return true end end
    return false
end

-- exclusive bag: only the types on its tabs may live there (foreign items get moved out when room exists)
function BT:IsExclusive(bag)
    local tabs = self.chardb.bags[bag]
    if not tabs then return false end
    for _, t in ipairs(tabs) do if t.exclusive then return true end end
    return false
end

function BT:BagAccepts(bag, cat)
    return (not self:IsExclusive(bag)) or self:BagWants(bag, cat)
end

-- rank of each category inside a bag: its own tabs first (in tab order), then the rest.
-- sub-categories share their parent's rank unless a tab names them directly
function BT:CatRank(bag)
    local rank, n = {}, 0
    local tabs = self.chardb.bags[bag]
    if tabs then
        for _, t in ipairs(tabs) do
            for _, c in ipairs(BT.CATS) do
                if t.cats[c.key] and not rank[c.key] then n = n + 1; rank[c.key] = n end
            end
        end
    end
    local out = {}
    for _, c in ipairs(BT.CATS) do
        local k, r = c.key, nil
        while k do
            r = rank[k]
            if r then break end
            k = BT.PARENT[k]
        end
        out[c.key] = r or (n + BT.CATIDX[c.key])
    end
    return out
end

-- ============================================================ classification
local catCache, conjuredCache = {}, {}
local CONJURED_LINE = ITEM_CONJURED or "Conjured Item"
local MANA_GEMS = { ["Mana Agate"] = true, ["Mana Jade"] = true, ["Mana Citrine"] = true,
                    ["Mana Ruby"] = true, ["Mana Emerald"] = true }
local scanTip

-- conjured = the "Conjured Item" tooltip line (mage food/water, healthstones, mana gems, soulstones...)
-- returns isConjured, ready (ready=false when the tooltip had no data yet: do not cache)
function BT:IsConjured(link, id, name)
    if id and conjuredCache[id] ~= nil then return conjuredCache[id], true end
    local found = false
    if name and (name:find("^Conjured ") or name:find("Healthstone") or name:find("Soulstone") or MANA_GEMS[name]) then
        found = true
    else
        if not scanTip then scanTip = CreateFrame("GameTooltip", "InventoryPlusScanTip", nil, "GameTooltipTemplate") end
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetHyperlink(link)
        local n = scanTip:NumLines()
        if not n or n == 0 then return false, false end
        for i = 2, math.min(n, 8) do
            local fs = _G["InventoryPlusScanTipTextLeft" .. i]
            local txt = fs and fs:GetText()
            if txt and txt:find(CONJURED_LINE, 1, true) then found = true; break end
        end
    end
    if id then conjuredCache[id] = found end
    return found, true
end

-- raw food = Trade Goods "Meat" (raw meat and fish), "Raw ..." items, and raw fruit by name.
-- Anything cooked or crafted stays a Consumable. (English names; edible fruit has no other tell.)
local FRUIT = { "Apple", "Banana", "Melon", "Watermelon", "Pear", "Mango", "Pineapple", "Papaya", "Coconut",
                "Berries", "Berry", "Orange", "Lemon", "Grape", "Grapes", "Plum", "Kiwi", "Pomegranate", "Cherries" }
local COOKED = { "Pie", "Tart", "Cake", "Pudding", "Juice", "Cider", "Strudel", "Bread", "Stew", "Soup",
                 "Dumpling", "Salad", "Jam", "Pastry", "Muffin", "Cookie", "Wine", "Ale", "Roll" }
function BT:IsRawFood(itype, subtype, name)
    if itype == "Trade Goods" and subtype == "Meat" then return true end
    if (itype == "Consumable" or itype == "Trade Goods") and name:find("^Raw ") then return true end
    if itype == "Consumable" and subtype == "Food & Drink" then
        for _, w in ipairs(COOKED) do if name:find("%f[%a]" .. w .. "%f[%A]") then return false end end
        for _, w in ipairs(FRUIT) do if name:find("%f[%a]" .. w .. "%f[%A]") then return true end end
    end
    return false
end

-- by item id, whatever the game files them under
BT.SOUL_SHARD = 6265
local SPECIAL = { [6265] = "Reagents" }

local QSUB = { [1] = "Common", [2] = "Uncommon", [3] = "Rare" }
local function QualityKey(base, q)
    q = q or 1
    return base .. ":" .. (q >= 4 and "Epic" or QSUB[q] or "Common")
end

-- Trade Goods subclass (as GetItemInfo names it) -> crafting sub-category
local CRAFT = {
    Cloth = "Crafting:Cloth", Leather = "Crafting:Leather", ["Metal & Stone"] = "Crafting:Ore", Herb = "Crafting:Herbs",
    Enchanting = "Crafting:Enchanting", Jewelcrafting = "Crafting:Jewelcrafting", Elemental = "Crafting:Elemental",
    Parts = "Crafting:Engineering", Devices = "Crafting:Engineering", Explosives = "Crafting:Engineering",
}
function BT:CraftKey(subtype, name)
    if name:find("Pigment") or name:find("^Ink ") or name:find(" Ink$") or name:find("^Ink of") or name:find("Parchment") then
        return "Crafting:Inscription"
    end
    return CRAFT[subtype] or "Crafting:Other"
end

function BT:Classify(link, bag, slot)
    if not link then return nil end
    if bag and slot and GetContainerItemQuestInfo then
        local isQuest, questId = GetContainerItemQuestInfo(bag, slot)
        if isQuest or questId then return "Quest" end
    end
    local id = ItemID(link)
    if id and catCache[id] then return catCache[id] end
    local name, _, quality, _, _, itype, subtype, _, equipLoc = GetItemInfo(link)
    if not name then return "Misc" end   -- not cached yet: do not remember
    local cat, remember = nil, true
    if id and SPECIAL[id] then
        cat = SPECIAL[id]
    elseif itype == "Quest" then
        cat = "Quest"
    elseif quality == 0 then
        cat = "Junk"
    elseif itype == "Armor" then
        -- all wearable gear is one category (split by quality); shields count as weapons
        if equipLoc == "INVTYPE_SHIELD" or subtype == "Shields" then
            cat = QualityKey("Weapons", quality)
        else
            cat = QualityKey("Gear", quality)
        end
    elseif itype == "Weapon" then cat = QualityKey("Weapons", quality)
    elseif itype == "Gem" then cat = "Gems"
    elseif itype == "Recipe" then cat = "Recipes"
    elseif itype == "Container" or itype == "Quiver" then cat = "Containers"
    elseif itype == "Projectile" then cat = "Ammo"
    elseif itype == "Glyph" then cat = "Glyphs"
    else
        local conj, ready = false, true
        if itype == "Consumable" or itype == "Miscellaneous" or itype == "Trade Goods" or itype == "Reagent" then
            conj, ready = self:IsConjured(link, id, name)
            if not ready then remember = false end
        end
        if conj then cat = "Conjured"
        elseif self:IsRawFood(itype, subtype, name) then cat = "RawFood"
        elseif itype == "Consumable" then cat = "Consumables"
        elseif itype == "Trade Goods" then cat = self:CraftKey(subtype, name)
        elseif itype == "Reagent" then cat = "Reagents"
        else cat = "Misc" end
    end
    if id and remember then catCache[id] = cat end
    return cat
end

-- ============================================================ bag scanning helpers
-- the tab of `bag` that holds items of category `cat` (nil when no tab does)
function BT:TabFor(bag, cat)
    local tabs = self.chardb and self.chardb.bags[bag]
    if tabs and cat then
        for _, t in ipairs(tabs) do
            if self:Matches(t.cats, cat) then return t end
        end
    end
end

-- first free slot; for an item whose tab fills in reverse the search starts at the last slot
function BT:FreeSlot(bag, cat)
    local n = GetContainerNumSlots(bag) or 0
    local tab = cat and self:TabFor(bag, cat)
    local from, to, step = 1, n, 1
    if tab and tab.reverse then from, to, step = n, 1, -1 end
    for s = from, to, step do
        if not GetContainerItemLink(bag, s) and not self.reserved[bag .. ":" .. s] then return s end
    end
end

-- destination for an item that should live in another bag
function BT:PlanRoute(srcBag, cat)
    for _, owner in ipairs(self:Owners(cat, self:Domain(srcBag))) do
        if owner ~= srcBag and self:IsUsableBag(owner) then
            local s = self:FreeSlot(owner, cat)
            if s then return owner, s end
        end
    end
end

-- somewhere else for an item that must leave an exclusive bag (other bags are filled first)
function BT:PlanEvict(bag, cat)
    for _, b in ipairs(self:DomainBags(self:Domain(bag))) do
        if b ~= bag and self:IsUsableBag(b) and self:BagAccepts(b, cat) then
            local s = self:FreeSlot(b)
            if s then return b, s end
        end
    end
end

-- where should this item go? (nil = leave it)
function BT:PlanFor(bag, cat)
    local domain = self:Domain(bag)
    if #self:Owners(cat, domain) > 0 and not self:IsHome(cat, bag) then
        local b, s = self:PlanRoute(bag, cat)
        if b then return b, s end
    end
    if not self:BagAccepts(bag, cat) then return self:PlanEvict(bag, cat) end
end

function BT:CountInBag(bag, cats)
    local n = 0
    for s = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, s)
        if link and self:Matches(cats, self:Classify(link, bag, s)) then n = n + 1 end
    end
    return n
end

-- ============================================================ move queue
BT.queue, BT.reserved, BT.pending = {}, {}, {}

local function Locked(bag, slot)
    local _, _, locked = GetContainerItemInfo(bag, slot)
    return locked
end

function BT:QueueMove(sb, ss, db, ds)
    self.reserved[db .. ":" .. ds] = true
    tinsert(self.queue, { kind = "move", sb = sb, ss = ss, db = db, ds = ds, link = GetContainerItemLink(sb, ss) })
end

function BT:QueueDelete(bag, slot, value, count, split, reason)
    tinsert(self.queue, { kind = "delete", sb = bag, ss = slot, link = GetContainerItemLink(bag, slot),
                          value = value, count = count, split = split, reason = reason or "junk" })
end

-- copper -> "1g 2s 3c"; sep = "" gives "1g2s3c" (the form the limit fields take)
function BT:Money(c, sep)
    c = math.floor(c or 0)
    local g, s, cc = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if cc > 0 or #parts == 0 then parts[#parts + 1] = cc .. "c" end
    return table.concat(parts, sep or " ")
end

-- "10g34s10c" (any subset, any order of use once each); a bare number counts as copper
function BT:ParseMoney(str)
    str = strlower(strtrim(str or ""))
    str = str:gsub("%s+", "")
    if str == "" then return nil end
    if str:match("^%d+$") then return tonumber(str) end
    local total, rest, seen = 0, str, {}
    while rest ~= "" do
        local n, u, tail = rest:match("^(%d+)([gsc])(.*)$")
        if not n or seen[u] then return nil end
        seen[u] = true
        total = total + tonumber(n) * ((u == "g" and 10000) or (u == "s" and 100) or 1)
        rest = tail
    end
    return total
end


function BT:LogDelete(op)
    local log = self.db.junkLog
    tinsert(log, 1, { link = op.link, count = op.count or 1, value = op.value or 0, t = time(), reason = op.reason })
    while #log > 30 do tremove(log) end
    if self.db.junkReport then
        local what = (op.reason == "excess") and "excess " or "junk "
        self:Print("deleted " .. what .. tostring(op.link) .. ((op.count or 1) > 1 and (" x" .. op.count) or "")
            .. ((op.value or 0) > 0 and (" (worth " .. self:Money(op.value) .. ")") or ""))
    end
    if self.Options and self.Options.Refresh then self.Options:Refresh() end
end

function BT:JunkLimit()    -- copper; later this can scale with player level
    return self.db.junkMax or 0
end

function BT:Debug(...)
    if self.db and self.db.debug then self:Print("|cff999999" .. string.format(...) .. "|r") end
end

function BT:QueueExchange(ba, a, bb, b)
    tinsert(self.queue, { kind = "swap", ba = ba, a = a, bb = bb, b = b })
end
function BT:QueueSwap(bag, a, b) self:QueueExchange(bag, a, bag, b) end

-- run fn when the queue is idle (immediately if it already is)
function BT:After(fn)
    tinsert(self.pending, fn)
end

function BT:Kick()
    if #self.queue == 0 then self:OnQueueDone() end
    if #self.queue > 0 then
        if not self.driver:IsShown() then self.lastProgress = GetTime() end
        self.driver:Show()
    end
end

function BT:OnQueueDone()
    wipe(self.reserved)
    while #self.queue == 0 and #self.pending > 0 do
        local fn = tremove(self.pending, 1)
        fn()
    end
    if #self.queue == 0 then
        -- no re-baseline here: arrivals are judged by item totals, so our own moves never look like loot,
        -- and loot that landed while the queue was busy is still picked up afterwards
        self.driver:Hide()
        if self.RefreshTabs then self:RefreshTabs() end
    end
end

-- returns true when the op is finished (or dropped)
-- Pick-up / drop / delete is done in one frame, then judged one wait later: the server may keep the
-- item on the cursor for a moment, so the cursor is only cleared when it is STILL full afterwards.
function BT:StepOp(op)
    op.tries = (op.tries or 0) + 1
    if op.tries > 30 then
        if op.stage and CursorHasItem() then ClearCursor() end
        return true
    end
    if op.kind == "move" or op.kind == "delete" then
        if not op.stage then
            if GetContainerItemLink(op.sb, op.ss) ~= op.link then return true end
            if op.kind == "move" and GetContainerItemLink(op.db, op.ds) then return true end
            if Locked(op.sb, op.ss) or (op.kind == "move" and Locked(op.db, op.ds)) then self:Penalize(0.05); return false end
            if op.kind == "delete" and op.split then
                SplitContainerItem(op.sb, op.ss, op.split)       -- only part of the stack goes
            else
                PickupContainerItem(op.sb, op.ss)
            end
            if op.kind == "move" then
                PickupContainerItem(op.db, op.ds)
            elseif CursorHasItem() then
                DeleteCursorItem()
                self:LogDelete(op)
            end
            op.stage = 2
            return false
        end
        if CursorHasItem() then          -- placement did not happen (or a merge overflowed): put the rest back
            ClearCursor()
            if not op.merge then self:Penalize() end
        end
        return true
    else -- swap / exchange between two slots (same or different bag)
        if not op.stage then
            local la, lb = GetContainerItemLink(op.ba, op.a), GetContainerItemLink(op.bb, op.b)
            if not la and not lb then return true end
            if Locked(op.ba, op.a) or Locked(op.bb, op.b) then self:Penalize(0.05); return false end
            if la then
                PickupContainerItem(op.ba, op.a)
                PickupContainerItem(op.bb, op.b)
            else
                PickupContainerItem(op.bb, op.b)
                PickupContainerItem(op.ba, op.a)
            end
            op.stage = 2
            return false
        else
            if CursorHasItem() then
                self:Penalize()
                if Locked(op.ba, op.a) then return false end
                PickupContainerItem(op.ba, op.a)
                if CursorHasItem() then PickupContainerItem(op.bb, op.b) end
                if CursorHasItem() then ClearCursor() end
            end
            return true
        end
    end
end

-- How long to wait after a move. Automatic mode follows the server: the measured time between sending a
-- move and the server answering (item lock / bag update), plus a margin, plus a penalty that grows
-- whenever the server refused or dropped something and fades away again while everything goes well.
local STALL = 10          -- seconds without any progress before the queue is abandoned
function BT:OpPause()
    if not self.db.opAuto then return self.db.opDelay or 0.3 end
    local _, _, world = (GetNetStats and GetNetStats())
    local lat = (world or 0) / 1000
    local ack = self.ackAvg or 0.12
    local pause = math.max(ack * 1.3, lat * 1.5) + 0.04 + (self.slow or 0)
    return math.min(1.5, math.max(0.08, pause))
end

function BT:Penalize(n) self.slow = math.min(1, (self.slow or 0) + (n or 0.15)) end

-- the server answered the last move: learn how long that took
function BT:Acked()
    self.eventSeen = true
    if self.opSentAt then
        local ack = GetTime() - self.opSentAt
        self.opSentAt = nil
        self.ackAvg = self.ackAvg and (self.ackAvg * 0.7 + ack * 0.3) or ack
    end
end

-- give up on a queue that is not getting anywhere (locked slot that never frees, item stuck on the cursor ...)
function BT:Abort(why)
    local op = self.queue[1]
    if op and op.stage and CursorHasItem() then ClearCursor() end    -- only what we picked up ourselves
    wipe(self.queue); wipe(self.reserved); wipe(self.pending)
    self.opSentAt, self.waitLeft = nil, 0
    self:Penalize(0.3)
    self:Print("sorting stopped: " .. why)
    self.driver:Hide()
    if self.RefreshTabs then self:RefreshTabs() end
end

function BT:Tick(elapsed)
    local now = GetTime()
    if #self.queue > 0 and now - (self.lastProgress or now) > STALL then
        self:Abort(CursorHasItem() and "something is on your cursor" or "the server did not respond in time")
        return
    end
    if self.waitLeft > 0 then
        self.waitLeft = self.waitLeft - elapsed
        if self.eventSeen and self.db.opAuto then self.waitLeft = math.min(self.waitLeft, 0.05 + (self.slow or 0)) end
        if self.waitLeft > 0 then return end
    end
    local op = self.queue[1]
    if not op then self:OnQueueDone(); return end
    if CursorHasItem() and not op.stage then return end   -- the user is holding something: never clobber it
    local hadStage, tries = op.stage, op.tries or 0
    if self:StepOp(op) then
        tremove(self.queue, 1)
        self.lastProgress = now
        if (op.tries or 0) <= 2 then self.slow = (self.slow or 0) * 0.85 end   -- went smoothly: speed up again
    elseif op.stage and not hadStage then
        self.lastProgress = now                            -- picked up / dropped: waiting for the server's answer
        self.opSentAt = now
    end
    self.waitLeft, self.eventSeen = self:OpPause(), false
    if #self.queue == 0 then self:OnQueueDone() end
end

-- ============================================================ sorting
local function Cmp(mode)
    return function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.ci ~= b.ci then return a.ci < b.ci end
        if mode == "name" then
            if a.name ~= b.name then return a.name < b.name end
        elseif mode == "ilevel" then
            if a.il ~= b.il then return a.il > b.il end
            if a.name ~= b.name then return a.name < b.name end
        elseif mode == "count" then
            if a.count ~= b.count then return a.count > b.count end
            if a.name ~= b.name then return a.name < b.name end
        else
            if a.q ~= b.q then return a.q > b.q end
            if a.name ~= b.name then return a.name < b.name end
        end
        if a.id ~= b.id then return a.id < b.id end
        return a.slot < b.slot     -- stable: identical items never trade places (no accidental stack merges)
    end
end

-- returns list of {i, j} swaps that sort the bag; ignored items keep their slot and are sorted around
function BT:PlanSort(bag)
    local n = GetContainerNumSlots(bag) or 0
    local rank = self:CatRank(bag)
    local items, cur, slots = {}, {}, {}
    for s = 1, n do
        local link = GetContainerItemLink(bag, s)
        if not (link and self:IsIgnored(link)) then
            slots[#slots + 1] = s
            if link then
                local _, count = GetContainerItemInfo(bag, s)
                local name, _, q, il = GetItemInfo(link)
                local cat = self:Classify(link, bag, s)
                local cd = BT.CAT[cat]
                local tab = self:TabFor(bag, cat)
                items[#items + 1] = {
                    slot = s, id = ItemID(link) or 0, name = name or "", q = q or 0, il = il or 0,
                    count = count or 1, rank = rank[cat] or 99,
                    ci = (cd and cd.sortGroup) and BT.CATIDX[cat] or 0,     -- crafting sub-categories stay grouped
                    rev = tab and tab.reverse and true or false,
                }
                cur[s] = s
            end
        end
    end
    tsort(items, Cmp(self.db.sortMode))
    -- target[k] = the item that belongs in slots[k]: ordinary tabs fill from the first slot, reverse tabs from the last
    local target, nSlots, fwd, rev = {}, #slots, 0, 0
    for _, it in ipairs(items) do
        if it.rev then rev = rev + 1; target[nSlots - rev + 1] = it
        else fwd = fwd + 1; target[fwd] = it end
    end
    local swaps = {}
    for k = 1, nSlots do
        local it = target[k]
        if it then
            local i, want = slots[k], it.slot
            if cur[i] ~= want then
                local j
                for m = 1, nSlots do if m ~= k and cur[slots[m]] == want then j = slots[m]; break end end
                if j then
                    cur[i], cur[j] = cur[j], cur[i]
                    swaps[#swaps + 1] = { i, j }
                end
            end
        end
    end
    return swaps
end

-- merges that would leave one stack per item in `bag` (partial stacks only; full stacks stay as they are)
-- returns { {src, dst}, ... } with slots; the largest partial stack collects, the smallest is emptied first
function BT:PlanStacks(bag)
    local byItem = {}
    for s = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, s)
        if link and not self.reserved[bag .. ":" .. s] and not self:IsIgnored(link) then
            local id = ItemID(link)
            local max = select(8, GetItemInfo(link)) or 1
            local _, count = GetContainerItemInfo(bag, s)
            count = count or 1
            if id and max > 1 and count < max then
                local g = byItem[id]
                if not g then g = { max = max, list = {} }; byItem[id] = g end
                g.list[#g.list + 1] = { slot = s, n = count }
            end
        end
    end
    local moves = {}
    for _, g in pairs(byItem) do
        local l = g.list
        if #l > 1 then
            tsort(l, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.slot < b.slot end)
            local d, e = 1, #l
            while d < e do
                local dst, src = l[d], l[e]
                moves[#moves + 1] = { src.slot, dst.slot }
                local total = dst.n + src.n
                if total <= g.max then dst.n = total; e = e - 1
                else src.n = total - g.max; dst.n = g.max; d = d + 1 end
            end
        end
    end
    tsort(moves, function(a, b) return a[1] < b[1] end)
    return moves
end

function BT:QueueStacks(bag)
    local moves = self:PlanStacks(bag)
    for _, m in ipairs(moves) do
        self:QueueMove(bag, m[1], bag, m[2])
        self.queue[#self.queue].merge = true
    end
    return #moves
end

-- the quiet check: loose partial stacks anywhere in the bags are merged, once things have settled.
-- Returns true when done for now, false when it should look again a little later.
function BT:CheckStacks()
    if not self.db.autoMerge then return true end
    if self.baselineAt or #self.queue > 0 or CursorHasItem() or InCombatLockdown() then return false end
    if GetTime() - (self.lastCursor or 0) < 1.5 then return false end        -- the player is moving things around
    local sig, n = {}, 0
    for _, bag in ipairs(self.INV_BAGS) do
        for _, m in ipairs(self:PlanStacks(bag)) do
            sig[#sig + 1] = bag .. ":" .. m[1] .. ">" .. m[2]
            n = n + 1
        end
    end
    if n == 0 then self.lastStackSig = nil; return true end
    sig = table.concat(sig, ",")
    if sig == self.lastStackSig and GetTime() - (self.lastStackAt or 0) < 60 then return true end   -- tried that already
    self.lastStackSig, self.lastStackAt = sig, GetTime()
    for _, bag in ipairs(self.INV_BAGS) do self:QueueStacks(bag) end
    self:Kick()
    return true
end

function BT:SortBag(bag, pass)
    pass = pass or 1
    if not self:IsUsableBag(bag) then return end
    -- partial stacks first: sorting leaves one stack per item, then the order is planned on what is left
    if self:QueueStacks(bag) > 0 then
        self:After(function() self:SortBag(bag, pass) end)
        return
    end
    local swaps = self:PlanSort(bag)
    if #swaps == 0 then return end
    for _, s in ipairs(swaps) do self:QueueSwap(bag, s[1], s[2]) end
    if pass < 3 then
        self:After(function() self:SortBag(bag, pass + 1) end)   -- verify; stack merges can change the picture
    end
end

-- ============================================================ gather / organize
-- a slot in `bag` whose item does not belong there and could live in srcBag instead
function BT:FindForeignSlot(bag, srcBag)
    for s = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, s)
        if link and not self.reserved[bag .. ":" .. s] and not self:IsIgnored(link) then
            local cat = self:Classify(link, bag, s)
            if not self:BagWants(bag, cat) and self:BagAccepts(srcBag, cat) then return s end
        end
    end
end

-- pull the tab's item types into `bag`; when the bag is full, exchange with items that do not belong
function BT:PlanGather(bag, def)
    local domain = self:Domain(bag)
    for _, sb in ipairs(self:DomainBags(domain)) do
        if sb ~= bag and (GetContainerNumSlots(sb) or 0) > 0 then
            for ss = 1, GetContainerNumSlots(sb) do
                local link = GetContainerItemLink(sb, ss)
                if link and not self.reserved[sb .. ":" .. ss] and not self:IsIgnored(link) then
                    local cat = self:Classify(link, sb, ss)
                    if self:Matches(def.cats, cat) and self:IsHome(cat, bag) and not self:IsHome(cat, sb) then
                        local ds = self:FreeSlot(bag, cat)
                        if ds then
                            self:QueueMove(sb, ss, bag, ds)
                        else
                            local fs = self:FindForeignSlot(bag, sb)
                            if not fs then return end
                            self.reserved[bag .. ":" .. fs] = true
                            self.reserved[sb .. ":" .. ss] = true
                            self:QueueExchange(sb, ss, bag, fs)
                        end
                    end
                end
            end
        end
    end
end

-- send away what does not belong in this bag (to its own bag, or - exclusive bags - anywhere with room)
function BT:CleanBag(bag)
    if not self:IsUsableBag(bag) then return end
    for ss = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, ss)
        if link and not self.reserved[bag .. ":" .. ss] and not self:IsIgnored(link) then
            local cat = self:Classify(link, bag, ss)
            if not self:BagWants(bag, cat) then
                local db, ds
                if #self:Owners(cat, self:Domain(bag)) > 0 then db, ds = self:PlanRoute(bag, cat) end
                if not db and self:IsExclusive(bag) then db, ds = self:PlanEvict(bag, cat) end
                if db then self:QueueMove(bag, ss, db, ds) end
            end
        end
    end
end

function BT:GatherTab(bag, def, sortToo)
    if not def or not self:IsUsableBag(bag) then return end
    local domain = self:Domain(bag)
    if domain == "bank" and not self.bankOpen then return end
    self:After(function() self:PlanGather(bag, def) end)
    if self:IsExclusive(bag) then self:After(function() self:CleanBag(bag) end) end
    if sortToo then self:After(function() self:SortBag(bag) end) end
    self:Kick()
end

-- drag a tab onto another bag: the tab moves, its items follow, strangers are swapped out
function BT:MoveTab(def, from, to)
    if from == to or self:Domain(from) ~= self:Domain(to) or not self:IsUsableBag(to) then return false end
    local dst = self:GetTabs(to, true)
    if #dst >= BT.MAX_TABS then self:Print("that bag already has " .. BT.MAX_TABS .. " tabs"); return false end
    local src = self:GetTabs(from)
    if not src then return false end
    for i, d in ipairs(src) do if d == def then tremove(src, i); break end end
    if #src == 0 then self.chardb.bags[from] = nil end
    tinsert(dst, def)
    if self.OnTabsChanged then self:OnTabsChanged() end
    if self:Domain(to) == "bank" and not self.bankOpen then return true end
    self:After(function() self:PlanGather(to, def) end)
    self:After(function() self:CleanBag(to) end)
    self:After(function() self:SortBag(to) end)
    self:Kick()
    return true
end

-- merge tab `a` (in bag `abag`) into tab `b` (in bag `bbag`): one new tab takes b's place holding both item sets
function BT:MergeTabs(a, abag, b, bbag, name)
    if a == b or self:Domain(abag) ~= self:Domain(bbag) then return false end
    local dst, src = self:GetTabs(bbag), self:GetTabs(abag)
    if not dst or not src then return false end
    local cats = {}
    for k in pairs(a.cats) do cats[k] = true end
    for k in pairs(b.cats) do cats[k] = true end
    for k in pairs(cats) do                          -- a parent already covers its sub-categories
        local par = BT.PARENT[k]
        if par and cats[par] then cats[k] = nil end
    end
    name = name and strtrim(name) or nil
    if name == "" then name = nil end
    local merged = { cats = cats, name = name, exclusive = (a.exclusive or b.exclusive) and true or nil,
                     reverse = b.reverse and true or nil }
    for i, d in ipairs(src) do if d == a then tremove(src, i); break end end
    if #src == 0 and src ~= dst then self.chardb.bags[abag] = nil end
    for i, d in ipairs(dst) do if d == b then dst[i] = merged; break end end
    if self.OnTabsChanged then self:OnTabsChanged() end
    if not (self:Domain(bbag) == "bank" and not self.bankOpen) then
        self:After(function() self:PlanGather(bbag, merged) end)
        self:After(function() self:CleanBag(bbag) end)
        self:After(function() self:SortBag(bbag) end)
        self:Kick()
    end
    return merged
end

-- remove every tab of this character
function BT:ClearAllRules()
    wipe(self.chardb.bags)
    if self.OnTabsChanged then self:OnTabsChanged() end
    self:Print("all bag rules cleared.")
end

function BT:RouteAll(domain)
    for _, sb in ipairs(self:DomainBags(domain)) do
        for ss = 1, (GetContainerNumSlots(sb) or 0) do
            local link = GetContainerItemLink(sb, ss)
            if link and not self.reserved[sb .. ":" .. ss] and not self:IsIgnored(link) then
                local db, ds = self:PlanFor(sb, self:Classify(link, sb, ss))
                if db then self.reserved[sb .. ":" .. ss] = true; self:QueueMove(sb, ss, db, ds) end
            end
        end
    end
end

function BT:SortTabbed(domain)
    for _, bag in ipairs(self:DomainBags(domain)) do
        local tabs = self.chardb.bags[bag]
        if tabs and #tabs > 0 then self:SortBag(bag) end
    end
end

function BT:OrganizeAll()
    local domains = { "inv" }
    if self.bankOpen then domains[2] = "bank" end
    for _, d in ipairs(domains) do
        self:After(function() self:RouteAll(d) end)
        self:After(function() self:RouteAll(d) end)     -- second pass uses the room the first one freed
        self:After(function() self:SortTabbed(d) end)
    end
    self:Kick()
end

-- ============================================================ auto-route new items
-- An "arrival" = a slot that now holds an item that was not there before AND the character's total of
-- that item went up (so moving things around by hand never counts).
BT.arrivals = {}

function BT:Snapshot()
    local snap, totals = {}, {}
    for _, bag in ipairs(BT.INV_BAGS) do
        snap[bag] = {}
        for s = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, s)
            if link then
                local id = ItemID(link)
                if id then
                    local _, c = GetContainerItemInfo(bag, s)
                    snap[bag][s] = { id = id, n = c or 1 }
                    totals[id] = (totals[id] or 0) + (c or 1)
                end
            end
        end
    end
    return snap, totals
end

function BT:CheckArrivals()
    if CursorHasItem() then return false end         -- user is mid-drag: look again later
    if #self.queue > 0 then return false end
    if self.baselineAt then return true end           -- just logged in / zoned: bags not trustworthy yet
    local snap, totals = self:Snapshot()
    local old, oldTotals = self.snap, self.totals
    self.snap, self.totals = snap, totals
    if not old then return true end
    local manual = GetTime() - (self.lastCursor or 0) < 0.8
    for bag, slots in pairs(snap) do
        for s, e in pairs(slots) do
            local o = old[bag] and old[bag][s]
            if (not o or o.id ~= e.id) and (totals[e.id] or 0) > (oldTotals[e.id] or 0) then
                if manual then
                    self:Debug("bag %d slot %d: new item ignored (placed by hand)", bag, s)
                else
                    tinsert(self.arrivals, { bag = bag, slot = s, id = e.id, t = GetTime() })
                end
            end
        end
    end
    return true
end

-- decides what to do with each arrival: delete cheap loot junk, route to a tab bag, or leave alone
function BT:ProcessArrivals()
    if #self.arrivals == 0 or #self.queue > 0 or CursorHasItem() then return end
    local keep, queued = {}, false
    local db = self.db
    for _, a in ipairs(self.arrivals) do
        local link = GetContainerItemLink(a.bag, a.slot)
        if not link or ItemID(link) ~= a.id then
            self:Debug("arrival gone from bag %d slot %d", a.bag, a.slot)
        elseif self:IsIgnored(link) then
            self:Debug("%s is on the ignore list - left alone", link)
        elseif not GetItemInfo(link) and GetTime() - a.t < 6 then
            keep[#keep + 1] = a                       -- item data not loaded yet: retry
        else
            local cat = self:Classify(link, a.bag, a.slot)
            local handled = false
            if cat == "Junk" and db.junkDelete then
                local del, value, count = self:ShouldDelete(link, a)
                if del then
                    self:QueueDelete(a.bag, a.slot, value, count)
                    queued, handled = true, true
                end
            end
            if not handled then
                local dbag, dslot = self:PlanFor(a.bag, cat)
                if dbag then
                    self:Debug("%s -> %s: bag %d to bag %d", link, cat, a.bag, dbag)
                    self:QueueMove(a.bag, a.slot, dbag, dslot)
                    self.touchedBags = self.touchedBags or {}
                    self.touchedBags[dbag] = true
                    queued = true
                else
                    self:Debug("%s -> %s: staying in bag %d (no tab for it, already home, or target full)", link, cat, a.bag)
                end
            end
        end
    end
    self.arrivals = keep
    if queued then
        if db.sortAfter and self.touchedBags then
            self:After(function()
                for b in pairs(self.touchedBags or {}) do self:SortBag(b) end
                self.touchedBags = nil
            end)
        end
        self:Kick()
    end
end

-- Warlocks: destroy Soul Shards above the limit (last slots first). Returns true when nothing is left to retry.
function BT:CheckExcess()
    local db = self.db
    if not db.shardDelete then return true end
    local _, class = UnitClass("player")
    if class ~= "WARLOCK" then return true end                 -- never touches shards on other classes
    if db.ignore[self.SOUL_SHARD] then return true end
    if self.baselineAt or #self.queue > 0 or CursorHasItem() then return false end
    local have, slots = 0, {}
    for _, bag in ipairs(self.INV_BAGS) do
        for s = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, s)
            if link and ItemID(link) == self.SOUL_SHARD then
                local _, c = GetContainerItemInfo(bag, s)
                c = c or 1
                have = have + c
                slots[#slots + 1] = { bag = bag, slot = s, n = c }
            end
        end
    end
    local excess = have - (db.shardMax or 0)
    if excess <= 0 then return true end
    for i = #slots, 1, -1 do
        if excess <= 0 then break end
        local sl = slots[i]
        local take = math.min(sl.n, excess)
        self:QueueDelete(sl.bag, sl.slot, 0, take, take < sl.n and take or nil, "excess")
        excess = excess - take
    end
    self:Kick()
    return true
end

-- looted junk only: must be worth less than the limit, and the loot window must have just been used
function BT:ShouldDelete(link, a)
    if self:IsIgnored(link) then return false end
    if GetTime() - (self.lootTime or 0) > 4 then
        self:Debug("%s: junk, but not looted just now - kept", link); return false
    end
    local _, _, _, _, _, itype, _, _, _, _, price = GetItemInfo(link)
    if itype == "Quest" then return false end
    if GetContainerItemQuestInfo and (GetContainerItemQuestInfo(a.bag, a.slot)) then return false end
    if not price then self:Debug("%s: no vendor price known - kept", link); return false end
    local _, count = GetContainerItemInfo(a.bag, a.slot)
    count = count or 1
    local value = (self.db.junkMode == "stack") and (price * count) or price     -- per item unless set to per stack
    if value < self:JunkLimit() then return true, price * count, count end
    self:Debug("%s: worth %s, limit %s - kept", link, self:Money(value), self:Money(self:JunkLimit()))
    return false
end

-- ============================================================ init + events
BT.initHooks = {}
function BT:OnInit(fn) tinsert(self.initHooks, fn) end

local frame = CreateFrame("Frame")
BT.frame = frame
BT.driver = CreateFrame("Frame")
BT.driver:Hide()
BT.waitLeft, BT.eventSeen = 0, false
BT.driver:SetScript("OnUpdate", function(_, elapsed) BT:Tick(elapsed) end)

local EVENTS = { "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "CURSOR_UPDATE", "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_SLOT_CLEARED", "CHAT_MSG_LOOT" }

frame:SetScript("OnEvent", function(_, event, ...)
    if BT[event] then BT[event](BT, ...) end
end)

local dirtyAt, acc = 0, 0
local function OnUpdate(_, elapsed)
    if CursorHasItem() then BT.lastCursor = GetTime() end
    acc = acc + elapsed
    if acc < 0.2 then return end
    local dt = acc
    acc = 0
    local now = GetTime()
    if BT.baselineAt and now >= BT.baselineAt then
        BT.baselineAt = nil
        BT.snap, BT.totals = BT:Snapshot()
    end
    if BT.dirty and now - dirtyAt >= 0.25 then
        if BT:CheckArrivals() then BT.dirty = false end
    end
    BT:ProcessArrivals()
    if BT.stackDirty and now - (BT.stackAt or 0) >= 1.5 then
        if BT:CheckStacks() then BT.stackDirty = false end
    end
    if BT.excessDirty and now - (BT.excessAt or 0) >= 0.5 then
        if BT:CheckExcess() then BT.excessDirty = false end
    end
    if BT.WH and BT.WH.Tick then BT.WH:Tick(dt) end
end

-- first switch-on: stores, migration of 0.1 tabs, hooks on the stock UI (hooks cannot be removed; they
-- check BT.enabled)
function BT:Init()
    self.db = DS.GetDB("InventoryPlus", DEFAULTS)
    self.chardb = DS.GetCharDB("InventoryPlus", { bags = {} })
    self.db.ignore = self.db.ignore or {}
    if self.db.pushColumns == false then self.db.colGap = 0 end     -- the old on/off became the gap slider
    self.db.pushColumns = nil
    for _, tabs in pairs(self.chardb.bags) do      -- repair + migrate 0.1 categories
        for _, t in ipairs(tabs) do
            t.cats = t.cats or {}
            for old, new in pairs(MIGRATE) do
                if t.cats[old] then t.cats[old] = nil; t.cats[new] = true end
            end
            for k in pairs(t.cats) do if not BT.CAT[k] then t.cats[k] = nil end end
        end
    end
    if not self.hooksDone then
        self.hooksDone = true
        for _, fn in ipairs(self.initHooks) do fn() end
    end
end

function BT:PLAYER_ENTERING_WORLD()
    self.snap, self.totals = nil, nil
    self.baselineAt = GetTime() + 2        -- let the bags finish loading before trusting them
    wipe(self.arrivals)
    if self.RefreshTabs then self:RefreshTabs() end
end

function BT:BAG_UPDATE(bag)
    if bag and bag >= 0 and bag <= 4 then
        self.dirty, dirtyAt = true, GetTime()
        self.excessDirty, self.excessAt = true, GetTime()
        self.stackDirty, self.stackAt = true, GetTime()
    end
    self:Acked()
    if self.WH then self.WH:MarkDirty() end
end
function BT:ITEM_LOCK_CHANGED() self:Acked() end
function BT:CURSOR_UPDATE()
    if CursorHasItem() then self.lastCursor = GetTime() end
    self.eventSeen = true
end
function BT:LOOT_OPENED() self.lootTime = GetTime() end
BT.LOOT_CLOSED, BT.LOOT_SLOT_CLEARED, BT.CHAT_MSG_LOOT = BT.LOOT_OPENED, BT.LOOT_OPENED, BT.LOOT_OPENED
function BT:BANKFRAME_OPENED()
    self.bankOpen = true
    if self.WH then self.WH:MarkDirty() end
    if self.RefreshTabs then self:RefreshTabs() end
end
function BT:BANKFRAME_CLOSED()
    self.bankOpen = false
    if self.WH then self.WH:Scan() end
end
function BT:PLAYERBANKSLOTS_CHANGED() if self.WH then self.WH:MarkDirty() end end

-- ============================================================ public API (for BulkBag etc.)
function BT:GetItemCategory(link, bag, slot) return self:Classify(link, bag, slot) end
function BT:GetHomeBag(cat) return self:Owners(cat, "inv")[1] end

-- ============================================================ slash
function M.OnSlash(msg)
    msg = strlower(strtrim(msg or ""))
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    if cmd == "organize" then BT:OrganizeAll()
    elseif cmd == "sort" then
        for _, d in ipairs({ "inv", "bank" }) do
            if d == "inv" or BT.bankOpen then BT:After(function() BT:SortTabbed(d) end) end
        end
        BT:Kick()
    elseif cmd == "offset" then
        local x, y = rest:match("^(-?%d+)%s+(-?%d+)$")
        if x then
            BT.db.offsetX, BT.db.offsetY = tonumber(x), tonumber(y)
            if BT.RefreshTabs then BT:RefreshTabs() end
            BT:Print("tab offset " .. x .. ", " .. y)
        else
            BT:Print("usage: /inventoryplus offset <x> <y>   (currently " .. BT.db.offsetX .. ", " .. BT.db.offsetY .. ")")
        end
    elseif cmd == "wh" or cmd == "warehouse" then
        if BT.Options then BT.Options:Show("warehouse", rest) end
    elseif cmd == "upgrades" then
        if BT.Upgrades then BT.Upgrades:Kick(); BT.Upgrades:Scan(); BT.Upgrades:Report() end
    elseif cmd == "debug" then
        BT.db.debug = not BT.db.debug
        BT:Print("debug " .. (BT.db.debug and "on: routing decisions are printed" or "off"))
    elseif cmd == "help" then
        BT:Print("/inventoryplus  options  |  organize  |  sort  |  wh <item>  |  offset <x> <y>  |  debug")
    else
        if BT.Options then BT.Options:Toggle() end
    end
end

-- ============================================================ enable / disable
function M.OnEnable()
    BT:Init()
    BT.enabled = true
    _G.InventoryPlus = BT
    wipe(BT.queue); wipe(BT.reserved); wipe(BT.pending); wipe(BT.arrivals)
    BT.hoverCats, BT.dragging, BT.dirty, BT.excessDirty, BT.stackDirty = nil, nil, false, false, false
    BT.waitLeft, BT.eventSeen = 0, false
    BT.bankOpen = (BankFrame and BankFrame:IsShown()) and true or false
    BT.driver:Hide()
    frame:SetScript("OnEvent", function(_, event, ...)
        if BT[event] then BT[event](BT, ...) end
    end)
    for _, e in ipairs(EVENTS) do frame:RegisterEvent(e) end
    frame:SetScript("OnUpdate", OnUpdate)
    if BT.Upgrades then BT.Upgrades:Kick() end
    BT:PLAYER_ENTERING_WORLD()        -- fresh baseline: what is in the bags now is not "loot"
    if BT.WH then BT.WH:MarkDirty() end
end

function M.OnDisable()
    BT.enabled = false
    frame:UnregisterAllEvents()
    frame:SetScript("OnUpdate", nil)
    BT.driver:Hide()
    wipe(BT.queue); wipe(BT.reserved); wipe(BT.pending); wipe(BT.arrivals)
    BT.touchedBags = nil
    if BT.Teardown then BT:Teardown() end
    if _G.InventoryPlus == BT then _G.InventoryPlus = nil end
    if updateContainerFrameAnchors then pcall(updateContainerFrameAnchors) end   -- bag columns back where Blizzard puts them
end

-- Esc inside the DreamSuite window closes the tab picker first, not the window
tinsert(DS.escHooks, function() return BT.enabled and BT:PickerSwallowsEsc() end)
