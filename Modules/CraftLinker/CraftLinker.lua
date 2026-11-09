-- CraftLinker (DreamSuite module)
-- Whisper "craft" to the player running this addon and it will whisper back
-- real trade-skill links for their known crafting professions -- the kind
-- that let the recipient browse the recipe list and request a craft.
--
-- How the link is obtained: WoW only exposes a profession's trade-skill
-- link (GetTradeSkillListLink) while that profession's window is open, and
-- opening a profession window programmatically is a protected action that
-- the game blocks unless a real click/keypress triggered it. So instead of
-- forcing windows open, this addon passively caches the link every time
-- you open one of your crafting professions during normal play, and
-- replies with those cached links (one whisper per profession, after a
-- short intro line) when someone whispers the trigger word.
--
-- First-time setup: open each of your crafting profession windows once
-- (just like you normally would to craft something) so it gets cached.
-- After that it's remembered per character between sessions.
--
-- DreamSuite port: the data is kept per character (as before). Switching the
-- module off stops both the caching and the replies; `/craftlink on|off` still
-- only switches the replies, like the standalone addon did.
local DS = DreamSuite

local M = DS.RegisterModule({
    id      = "CraftLinker",
    title   = "CraftLinker",
    desc    = "Answers \"craft\" whispers with clickable trade-skill links",
    slash   = { "/craftlink" },
    legacy  = { folder = "CraftLinker", db = "CraftLinkerDB", perChar = true },
})

local DEFAULTS = {
    enabled = true,
    trigger = "craft",   -- the word(s) that fire the reply: exact match, case-insensitive; several separated by commas
    cooldown = 30,        -- seconds before the same whisperer can trigger it again
    noneMessage = "I haven't cached my crafting links yet -- ask me to open my profession windows once.",
    report = true,        -- one chat line when a crafting window closes and something was recorded
    stats = {},           -- [professionName] = { rank, recipes } as of the last window close
    links = {},            -- [professionName] = tradeSkillLink, filled in as windows are opened
    materials = true,     -- answer a craftable item / recipe link with its materials and what you have
    recipes = {},         -- [professionName][recipeSpellId] = { n = name, it = itemId, r = { {itemId, count, name}, ... } }
}

local db
local frame

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CraftLinker|r " .. msg)
end

-- Only these have an actual trade-skill/crafting window that can be linked
-- for someone else to browse. Fishing, First Aid, and the gathering skills
-- don't, so they're left out on purpose.
local CRAFTING_PROFESSIONS = {
    ["Alchemy"]        = true,
    ["Blacksmithing"]  = true,
    ["Enchanting"]     = true,
    ["Engineering"]    = true,
    ["Inscription"]    = true,
    ["Jewelcrafting"]  = true,
    ["Leatherworking"] = true,
    ["Tailoring"]      = true,
    ["Cooking"]        = true,
}

local lastReply = {}
local lastMat = {}           -- sender -> time of the last materials answer
local window                 -- the crafting window that is open right now: { name, rank, recipes, linkChanged }

-- Distinguishes your own open profession window from one you're viewing
-- because someone else whispered/linked you theirs -- so a stranger's link
-- never overwrites your own cached one.
local function IsViewingOwnTradeSkill()
    if IsTradeSkillLinked then
        local ok, linked = pcall(IsTradeSkillLinked)
        if ok then
            return not linked
        end
    end

    -- Fallback for clients without IsTradeSkillLinked: the displayed rank
    -- should match your own known rank for that skill if it's really yours.
    local name, currentRank = GetTradeSkillLine()
    if not name then return false end

    local numSkills = GetNumSkillLines()
    for i = 1, numSkills do
        local skillName, isHeader, _, skillRank = GetSkillLineInfo(i)
        if not isHeader and skillName == name then
            return skillRank == currentRank
        end
    end

    return false
end

-- "craft, crafting" -> { "craft", "crafting" }   (lower-case, trimmed, no empties)
local function SplitTriggers(str)
    local list = {}
    for part in tostring(str or ""):gmatch("[^,]+") do
        part = strtrim(part):lower()
        if part ~= "" then list[#list + 1] = part end
    end
    return list
end

-- the cleaned-up text to store, or nil if nothing usable was typed
local function NormalizeTriggers(str)
    local list = SplitTriggers(str)
    if #list == 0 then return nil end
    return table.concat(list, ", ")
end

local function IsTrigger(text)
    for _, t in ipairs(SplitTriggers(db.trigger)) do
        if t == text then return true end
    end
    return false
end

-- the item id out of an item or enchant link
local function LinkId(link, kind)
    return link and tonumber(link:match("|H" .. kind .. ":(%d+)"))
end

-- remember what every visible recipe makes and needs (a filter only hides some: what was seen stays)
local function CacheRecipes(prof)
    db.recipes = db.recipes or {}
    local list = db.recipes[prof]
    if not list then list = {}; db.recipes[prof] = list end
    for i = 1, (GetNumTradeSkills and GetNumTradeSkills() or 0) do
        local rname, kind = GetTradeSkillInfo(i)
        if rname and kind ~= "header" then
            local spell = LinkId(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i), "enchant")
            if spell then
                local rec = list[spell]
                if not rec or rec.n ~= rname or rec.v ~= 2 then
                    local ilink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
                    rec = { v = 2, n = rname, it = LinkId(ilink, "item"), l = ilink, r = {} }
                    for j = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
                        local reagent, _, count = GetTradeSkillReagentInfo(i, j)
                        local rlink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j)
                        if reagent then rec.r[#rec.r + 1] = { LinkId(rlink, "item"), count or 1, reagent, rlink } end
                    end
                    list[spell] = rec
                end
            end
        end
    end
end

-- find a cached recipe by the item it makes or by its own (enchant) link
local function FindRecipe(kind, id)
    for prof, list in pairs(db.recipes or {}) do
        for spell, rec in pairs(list) do
            if (kind == "enchant" and spell == id) or (kind == "item" and rec.it == id) then
                return prof, rec, spell
            end
        end
    end
end

local function HaveCount(id, name)
    if id then return GetItemCount(id) or 0, GetItemCount(id, true) or 0 end
    return 0, 0
end

-- other characters of yours that hold the item, from InventoryPlus' Warehouse when it has data
local function AltsText(id)
    local ip = rawget(_G, "InventoryPlus")
    if not (id and ip and ip.db and ip.db.chars and ip.WH and ip.WH.Holders) then return "" end
    local ok, holders = pcall(ip.WH.Holders, ip.WH, id, ip.WH:Key())
    if not ok or not holders or #holders == 0 then return "" end
    local parts = {}
    for i, h in ipairs(holders) do
        if i > 3 then parts[#parts + 1] = "..."; break end
        parts[#parts + 1] = (h.rec.name or h.key) .. " " .. (h.b + h.k + h.e)
    end
    return " (alts: " .. table.concat(parts, ", ") .. ")"
end

-- always a real hyperlink: the stored one, else one built from the id (the game resolves it by itself)
local function ItemLink(id, stored, name)
    if stored and stored:find("|H") then return stored end
    if id and GetItemInfo then
        local _, l = GetItemInfo(id)
        if type(l) == "string" and l:find("|H") then return l end
    end
    if id then return "|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:0:0:0|h[" .. name .. "]|h|r" end
    return name
end

-- whisper lines (each short enough for chat) telling what a recipe needs and how much of it you carry.
-- A whisper holds at most three item links (many links in one message look like spam to some servers,
-- and the chat limit is 255 characters).
local MAX_LINKS = 3
local function MaterialLines(prof, rec, spell)
    local parts, canMake = {}, nil
    for _, rg in ipairs(rec.r) do
        local id, need, name = rg[1], rg[2], rg[3]
        local have, withBank = HaveCount(id, name)
        local t = need .. "x " .. ItemLink(id, rg[4], name) .. " - have " .. have
        if withBank > have then t = t .. " (+" .. (withBank - have) .. " in bank)" end
        t = t .. AltsText(id)
        parts[#parts + 1] = t
        local k = math.floor(have / math.max(need, 1))
        if not canMake or k < canMake then canMake = k end
    end
    local PRE = "[CraftLinker] "
    local made = rec.it and ItemLink(rec.it, rec.l, rec.n)
        or (spell and ("|cffffd000|Henchant:" .. spell .. "|h[" .. rec.n .. "]|h|r")) or rec.n
    local lines = { PRE .. made .. " (" .. prof .. ") needs:" }
    local cur, links = PRE, 0
    for i, t in ipairs(parts) do
        local piece = t .. (i < #parts and "; " or "")
        if cur ~= PRE and (#cur + #piece > 240 or links >= MAX_LINKS) then
            lines[#lines + 1] = cur; cur, links = PRE, 0
        end
        cur = cur .. piece
        links = links + 1
    end
    if #parts == 0 then cur = cur .. "no materials listed" end
    if cur ~= PRE then lines[#lines + 1] = cur end
    if canMake then
        lines[#lines + 1] = canMake > 0 and (PRE .. "Enough for " .. canMake .. " right now.") or (PRE .. "Can't make it right now.")
    end
    return lines
end

local function CacheCurrentTradeSkill()
    local name = GetTradeSkillLine and GetTradeSkillLine()
    if not (name and CRAFTING_PROFESSIONS[name] and IsViewingOwnTradeSkill()) then
        return
    end

    local link = GetTradeSkillListLink()
    if not link then return end

    -- Nothing is announced here: TRADE_SKILL_SHOW and TRADE_SKILL_UPDATE can both fire, sometimes more
    -- than once, for a single window. What changed is collected and reported when the window closes.
    local cur = window
    if not cur or cur.name ~= name then
        cur = { name = name, rank = 0, recipes = 0 }
        window = cur
    end
    if db.links[name] ~= link then
        db.links[name] = link
        cur.linkChanged = true
    end
    local _, rank = GetTradeSkillLine()
    rank = tonumber(rank) or 0
    if rank > cur.rank then cur.rank = rank end
    local n = 0
    for i = 1, (GetNumTradeSkills and GetNumTradeSkills() or 0) do
        local _, kind = GetTradeSkillInfo(i)
        if kind and kind ~= "header" then n = n + 1 end
    end
    if n > cur.recipes then cur.recipes = n end            -- a filter can hide recipes: keep the largest count seen
    CacheRecipes(name)
end

-- the crafting window closed: say what was recorded or changed, once
local function ReportWindow()
    local cur = window
    window = nil
    if not cur then return end
    local old = db.stats[cur.name]
    db.stats[cur.name] = { rank = cur.rank, recipes = math.max(cur.recipes, old and old.recipes or 0) }
    if not db.report then return end
    local parts = {}
    if not old then
        parts[#parts + 1] = "recorded " .. cur.name .. " (skill " .. cur.rank .. ", " .. cur.recipes .. " recipes)"
    else
        local dr, dn = cur.rank - old.rank, cur.recipes - old.recipes
        if dr > 0 then parts[#parts + 1] = "skill +" .. dr .. " (now " .. cur.rank .. ")" end
        if dn > 0 then parts[#parts + 1] = dn .. (dn == 1 and " recipe" or " recipes") .. " added" end
        if #parts > 0 then parts[1] = cur.name .. ": " .. parts[1] end
        if #parts == 0 and cur.linkChanged then parts[1] = cur.name .. ": link updated" end
    end
    if #parts > 0 then Print(table.concat(parts, ", ") .. ".") end
end

local function OnEvent(self, event, ...)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        CacheCurrentTradeSkill()
        return
    end
    if event == "TRADE_SKILL_CLOSE" then
        ReportWindow()
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        if not db.enabled then return end

        local message, sender = ...
        -- an item or recipe link: say what it takes to make it, if it is one of ours
        if db.materials and message:find("|H") then
            local found
            for kind, id in message:gmatch("|H(%a+):(%d+)") do
                if kind == "item" or kind == "enchant" then
                    local prof, rec, spell = FindRecipe(kind, tonumber(id))
                    if rec then found = { prof, rec, spell }; break end
                end
            end
            if found then
                local now = GetTime()
                if not (lastMat[sender] and now - lastMat[sender] < 3) then
                    lastMat[sender] = now
                    for _, line in ipairs(MaterialLines(found[1], found[2], found[3])) do
                        SendChatMessage(line, "WHISPER", nil, sender)
                    end
                end
                return
            end
        end
        local trimmed = message:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if not IsTrigger(trimmed) then return end

        local now = GetTime()
        if lastReply[sender] and (now - lastReply[sender]) < db.cooldown then
            return
        end
        lastReply[sender] = now

        -- Trust the cache directly -- no re-scanning the skill list here.
        -- Sent as separate whispers, one profession per message: combining
        -- multiple hyperlinks into a single message either overruns the
        -- chat length limit or trips servers' anti-spam filtering for
        -- multi-link messages (a common gold-seller pattern) -- either way
        -- everything past the first link tends to get silently dropped.
        local any = false
        for _, link in pairs(db.links) do
            if not any then
                SendChatMessage("[CraftLinker] My crafting professions:", "WHISPER", nil, sender)
                any = true
            end
            SendChatMessage(link, "WHISPER", nil, sender)
        end

        if not any then
            SendChatMessage(db.noneMessage, "WHISPER", nil, sender)
        end
    end
end

-- /craftlink on|off, /craftlink trigger <word>, /craftlink cooldown <seconds>,
-- /craftlink status, /craftlink clear <ProfessionName>, /craftlink clearall
function M.OnSlash(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    if args[1] == "on" then
        db.enabled = true
        Print("enabled.")
    elseif args[1] == "off" then
        db.enabled = false
        Print("disabled.")
    elseif args[1] == "trigger" and args[2] then
        local v = NormalizeTriggers(msg:match("^%s*%S+%s+(.-)%s*$"))
        if v then
            db.trigger = v
            Print("trigger words set to: " .. v)
        end
    elseif args[1] == "cooldown" and tonumber(args[2]) then
        db.cooldown = tonumber(args[2])
        Print("cooldown set to " .. args[2] .. "s.")
    elseif args[1] == "status" then
        Print("cached professions:")
        local any = false
        for name in pairs(db.links) do
            Print("  - " .. name)
            any = true
        end
        if not any then
            Print("  (none yet -- open a profession window to cache it)")
        end
    elseif args[1] == "clear" and args[2] then
        local target = args[2]
        local removed = false
        for profName in pairs(db.links) do
            if profName:lower() == target then
                db.links[profName] = nil
                removed = true
                break
            end
        end
        if removed then
            Print("cleared cached link for that profession.")
        else
            Print("no cached link found matching that name.")
        end
    elseif args[1] == "clearall" then
        db.links = {}; db.stats = {}; db.recipes = {}
        Print("cleared all cached links.")
    else
        Print("commands:")
        Print("  /craftlink on|off  (replies only)")
        Print("  /craftlink trigger <word, word ...>  (current: " .. db.trigger .. ")")
        Print("  /craftlink cooldown <seconds>  (current: " .. db.cooldown .. ")")
        Print("  /craftlink status  (show which professions are cached)")
        Print("  /craftlink clear <ProfessionName>  (remove one cached entry)")
        Print("  /craftlink clearall  (wipe all cached entries)")
    end
end

-- settings (the hub builds the view). The data lives per character, like the cache itself.
local function CachedList()
    local names = {}
    for name in pairs(db.links) do names[#names + 1] = name end
    table.sort(names)
    if #names == 0 then return "Nothing cached yet - open each crafting profession window once." end
    return "Cached: " .. table.concat(names, ", ")
end

M.options = function()
    return {
        { type = "tab", label = "General" },
        { type = "bool", key = "enabled", label = "Reply to whispers",
          desc = "Off: the links stay cached, but nobody gets an answer.",
          get = function() return db.enabled end,
          set = function(v) db.enabled = v end },
        { type = "edit", key = "trigger", label = "Trigger words", width = 300, maxLetters = 100,
          desc = "The whispers that set it off. Separate several with commas, for example: craft, crafting. Not case sensitive.",
          get = function() return db.trigger end,
          set = function(v)
              v = NormalizeTriggers(v)
              if v then db.trigger = v end
          end },
        { type = "bool", key = "report", label = "Report changes when a crafting window closes",
          desc = "One chat line saying what was recorded: skill points gained and recipes added. Off: silent.",
          get = function() return db.report end,
          set = function(v) db.report = v end },
        { type = "slider", key = "cooldown", label = "Cooldown per player", min = 0, max = 300, step = 5,
          fmt = function(v) return v .. " s" end, lowText = "0 s", highText = "300 s",
          desc = "How long before the same player can set it off again.",
          get = function() return db.cooldown end,
          set = function(v) db.cooldown = v end },
        { type = "tab", label = "Messages" },
        { type = "bool", key = "materials", label = "Answer item and recipe links with materials",
          desc = "When someone whispers an item you can craft, or its recipe, you answer with the materials it needs and how many of each you carry. Recipes are remembered when you open a profession window.",
          get = function() return db.materials end,
          set = function(v) db.materials = v end },
        { type = "edit", key = "noneMessage", label = "When nothing is cached", multiline = true, height = 70, maxLetters = 200,
          desc = "Sent instead of links if you have not opened a profession window yet.",
          get = function() return db.noneMessage end,
          set = function(v) if v ~= "" then db.noneMessage = v end end },
        { type = "tab", label = "Cache" },
        { type = "text", text = "A link is cached each time you open one of your crafting professions. Links from other players' windows are never stored." },
        { type = "action", key = "clearall", label = "Clear all cached links", confirm = true,
          desc = "They are cached again as you open the windows.",
          set = function() db.links = {}; db.stats = {}; db.recipes = {} end },
        { type = "text", text = function() return CachedList() end },
    }
end

function M.OnEnable()
    db = DS.GetCharDB("CraftLinker", DEFAULTS)
    db.stats = db.stats or {}
    db.recipes = db.recipes or {}
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    frame:RegisterEvent("CHAT_MSG_WHISPER")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_UPDATE")
    frame:RegisterEvent("TRADE_SKILL_CLOSE")
    window = nil
end

function M.OnDisable()
    if frame then frame:UnregisterAllEvents() end
end
