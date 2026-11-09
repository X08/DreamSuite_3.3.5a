--[[ InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
     Warehouse: remembers what every character carries in bags and bank; shows it in tooltips and as an icon
     overview with one section per character, sorted like the auction house. ]]

local DS = DreamSuite
local BT = DS.InventoryPlusCore
local WH = {}
BT.WH = WH

local INCLUDE_WORN = false      -- equipped items are left out for now (flip to bring them back)
local UNKNOWN = "Other"
local dirty, dirtyAt = false, 0

function WH:Key()
    return UnitName("player") .. "-" .. GetRealmName()
end

function WH:MarkDirty()
    dirty, dirtyAt = true, GetTime()
end

function WH:Tick()
    if dirty and GetTime() - dirtyAt > 1.5 then
        dirty = false
        self:Scan()
    end
end

-- ============================================================ scanning
-- item facts shared by all characters: name, quality, icon, class and subclass (as the auction house names them)
local function Remember(id, link)
    local info = BT.db.items[id]
    if info and info.n and info.t then return end
    local name, _, quality, _, _, itype, subtype, _, _, icon = GetItemInfo(link)
    if name then
        BT.db.items[id] = { n = name, q = quality or 1, i = icon, t = itype, s = subtype }
    elseif not info then
        BT.db.items[id] = { n = link:match("%[(.-)%]"), q = 1 }
    end
end

local function Add(map, link, count)
    local id = BT.ItemID(link)
    if not id then return end
    map[id] = (map[id] or 0) + (count or 1)
    Remember(id, link)
end

local function ScanBags(bags)
    local map = {}
    for _, bag in ipairs(bags) do
        for s = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, s)
            if link then
                local _, count = GetContainerItemInfo(bag, s)
                Add(map, link, count)
            end
        end
    end
    return map
end

function WH:Scan()
    if not BT.db or not BT.enabled then return end
    -- the bag API is not ready (just logged in, loading screen): keep what was recorded earlier
    if (GetContainerNumSlots(0) or 0) == 0 then return end
    local key = self:Key()
    local rec = BT.db.chars[key]
    if not rec then rec = { bag = {}, bank = {} }; BT.db.chars[key] = rec end
    local _, class = UnitClass("player")
    rec.name, rec.realm, rec.class = UnitName("player"), GetRealmName(), class
    rec.level, rec.seen = UnitLevel("player"), time()

    rec.bag = ScanBags(BT.INV_BAGS)

    if INCLUDE_WORN then
        local eq = {}
        for slot = 0, 23 do
            local link = GetInventoryItemLink("player", slot)
            if link then Add(eq, link, (slot == 0) and (GetInventoryItemCount("player", 0) or 1) or 1) end
        end
        rec.eq = eq
    else
        rec.eq = nil
    end

    if BT.bankOpen then
        local bank = ScanBags(BT.BANK_BAGS)
        for s = 1, (NUM_BANKGENERIC_SLOTS or 28) do
            local link = GetContainerItemLink(-1, s)
            if link then
                local _, count = GetContainerItemInfo(-1, s)
                Add(bank, link, count)
            end
        end
        rec.bank = bank
    end
end

-- how many distinct items a record holds (bags + bank)
function WH:Summary(rec)
    local n, seen = 0, {}
    for _, map in ipairs({ rec.bag or {}, rec.bank or {} }) do
        for id in pairs(map) do if not seen[id] then seen[id] = true; n = n + 1 end end
    end
    return n
end

-- ============================================================ counts and holders
-- bags, bank, worn for one character
function WH:Counts(rec, id)
    return (rec.bag or {})[id] or 0, (rec.bank or {})[id] or 0, INCLUDE_WORN and (rec.eq or {})[id] or 0
end

function WH:WhereText(b, k, e)
    local parts = {}
    if b > 0 then parts[#parts + 1] = "bags " .. b end
    if k > 0 then parts[#parts + 1] = "bank " .. k end
    if (e or 0) > 0 then parts[#parts + 1] = "worn " .. e end
    return table.concat(parts, ", ")
end

function WH:CharName(rec, key)
    local nm = rec.name or key
    if rec.realm and rec.realm ~= GetRealmName() then nm = nm .. " (" .. rec.realm .. ")" end
    return nm
end

function WH.ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- every character that holds the item (optionally except one), sorted by name
function WH:Holders(id, exceptKey)
    local out = {}
    for key, rec in pairs(BT.db.chars) do
        if key ~= exceptKey then
            local b, k, e = self:Counts(rec, id)
            if b + k + e > 0 then out[#out + 1] = { key = key, rec = rec, b = b, k = k, e = e } end
        end
    end
    table.sort(out, function(a, b) return (a.rec.name or a.key) < (b.rec.name or b.key) end)
    return out
end

-- ============================================================ overview data
-- auction-house ordering of classes and subclasses (localized names, so it matches GetItemInfo)
local function Orders()
    local classOrder, subOrder = {}, {}
    for i, c in ipairs({ GetAuctionItemClasses() }) do
        classOrder[c] = i
        subOrder[c] = {}
        for j, s in ipairs({ GetAuctionItemSubClasses(i) }) do subOrder[c][s] = j end
    end
    return classOrder, subOrder
end

-- one section per character (the current one first), each with its items in auction-house order.
-- text / class / sub filter the items; a section can end up empty but is still returned.
function WH:Sections(text, class, sub)
    local classOrder, subOrder = Orders()
    local needle = strlower(strtrim(text or ""))
    local function byAuctionOrder(a, b)
        local ca, cb = classOrder[a.t] or 99, classOrder[b.t] or 99
        if ca ~= cb then return ca < cb end
        local sa, sb = (subOrder[a.t] or {})[a.s] or 99, (subOrder[b.t] or {})[b.s] or 99
        if sa ~= sb then return sa < sb end
        if a.q ~= b.q then return a.q > b.q end
        return a.name < b.name
    end

    local sections = {}
    for key, rec in pairs(BT.db.chars) do
        local ids, items = {}, {}
        for _, map in ipairs({ rec.bag or {}, rec.bank or {}, INCLUDE_WORN and rec.eq or {} }) do
            for id in pairs(map) do ids[id] = true end
        end
        for id in pairs(ids) do
            local info = BT.db.items[id] or {}
            local name = info.n or ("item:" .. id)
            local t, s = info.t or UNKNOWN, info.s or UNKNOWN
            if (needle == "" or strfind(strlower(name), needle, 1, true))
                and (not class or class == t) and (not sub or sub == s) then
                local b, k, e = self:Counts(rec, id)
                items[#items + 1] = { id = id, name = name, q = info.q or 1, icon = info.i, t = t, s = s,
                                      b = b, k = k, e = e, total = b + k + e }
            end
        end
        table.sort(items, byAuctionOrder)
        sections[#sections + 1] = { key = key, rec = rec, items = items }
    end

    local me = self:Key()
    table.sort(sections, function(a, b)
        if (a.key == me) ~= (b.key == me) then return a.key == me end
        return (a.rec.name or a.key) < (b.rec.name or b.key)
    end)
    return sections, classOrder, subOrder
end

-- left-hand category tree: classes in auction-house order with the subclasses that hold items
-- (counts are distinct items over all characters)
function WH:Tree()
    local sections, classOrder, subOrder = self:Sections()
    local classes, byName, seen = {}, {}, {}
    for _, sec in ipairs(sections) do
        for _, e in ipairs(sec.items) do
            if not seen[e.id] then
                seen[e.id] = true
                local c = byName[e.t]
                if not c then
                    c = { name = e.t, count = 0, subs = {}, subBy = {} }
                    byName[e.t] = c; classes[#classes + 1] = c
                end
                c.count = c.count + 1
                local s = c.subBy[e.s]
                if not s then s = { name = e.s, count = 0 }; c.subBy[e.s] = s; c.subs[#c.subs + 1] = s end
                s.count = s.count + 1
            end
        end
    end
    table.sort(classes, function(a, b) return (classOrder[a.name] or 99) < (classOrder[b.name] or 99) end)
    for _, c in ipairs(classes) do
        local so = subOrder[c.name] or {}
        table.sort(c.subs, function(a, b) return (so[a.name] or 99) < (so[b.name] or 99) end)
    end
    return classes
end

-- ============================================================ tooltips
-- other characters' holdings under a character line, shared by the item tooltip and the overview
function WH:AddHolderLines(tip, holders)
    for _, h in ipairs(holders) do
        local r, g, b = self.ClassColor(h.rec.class)
        tip:AddDoubleLine(self:CharName(h.rec, h.key), self:WhereText(h.b, h.k, h.e), r, g, b, 0.9, 0.9, 0.9)
    end
end

local function AddLines(tip)
    if WH.suppress or not BT.enabled or not BT.db or not BT.db.tooltip or tip.btDone then return end
    local _, link = tip:GetItem()
    local id = BT.ItemID(link)
    if not id then return end
    local me = WH:Key()
    local holders = {}
    for _, h in ipairs(WH:Holders(id)) do
        if h.key == me then
            h.b, h.e = 0, 0                             -- bags are right in front of you; only the bank is news
            if BT.bankOpen then h.k = 0 end
        end
        if h.b + h.k + h.e > 0 then holders[#holders + 1] = h end
    end
    if #holders == 0 then return end
    tip.btDone = true
    tip:AddLine(" ")
    tip:AddLine("Warehouse", 0.55, 0.8, 1)
    WH:AddHolderLines(tip, holders)
    tip:Show()
end

-- optional: which InventoryPlus category an item belongs to
local function AddCategory(tip)
    if WH.suppress or not BT.enabled or not BT.db or not BT.db.catTooltip or tip.ipCatDone then return end
    local _, link = tip:GetItem()
    if not link then return end
    local bag, slot
    local f = GetMouseFocus and GetMouseFocus()
    local name = f and f.GetName and f:GetName()
    if name and name:match("^ContainerFrame%d+Item%d+$") then bag, slot = f:GetParent():GetID(), f:GetID() end
    local cat = BT:Classify(link, bag, slot)
    local def = cat and BT.CAT[cat]
    if not def then return end
    tip.ipCatDone = true
    local text = def.full .. (BT:IsIgnored(link) and "  (ignored: never moved)" or "")
    tip:AddDoubleLine("InventoryPlus", text, 0.55, 0.8, 1, def.color[1], def.color[2], def.color[3])
    tip:Show()
end

BT:OnInit(function()
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
        tip:HookScript("OnTooltipSetItem", function(self) AddCategory(self); AddLines(self) end)
        tip:HookScript("OnTooltipCleared", function(self) self.btDone = nil; self.ipCatDone = nil end)
    end
    WH:MarkDirty()
end)
