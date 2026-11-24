--[[ DreamScore: effects that come and go. "Use: Increases your attack power by 278 for 20 sec. (2 Min Cooldown)" and
     "Equip: ... a chance to grant 765 spell power for 10 sec (Proc chance: 15%, 45s cooldown)" are turned into the
     average amount of that stat they give, so they can be valued like any other stat:
        average = amount x seconds it lasts / seconds between uses (or procs)
     Only effects whose tooltip gives the numbers are read: Use: trinkets with a cooldown, and procs that show their
     chance and cooldown or their procs per minute. Mana restores become mana per 5 sec. Healing and damage effects
     have no stat to weigh and stay uncounted. English tooltips. ]]
local DS = DreamSuite
local DSC = DS.DreamScore
local E = {}
DSC.Effects = E

local MP5 = "ITEM_MOD_MANA_REGENERATION_SHORT"
E.TRIGGER_SECONDS = 1.5      -- how often a "when your spells/attacks hit" proc gets a chance to happen
E.CRIT_FACTOR = 3            -- an "on critical hit" trigger happens about a third as often

local names
local function StatNames()          -- longest first, so "ranged attack power" is not read as "attack power"
    if names then return names end
    names = {}
    for nm in pairs(DSC.NAME_KEY) do
        if nm ~= "all stats" and nm ~= "mana per 5 sec" and not nm:find("[%d%%]") then names[#names + 1] = nm end
    end
    table.sort(names, function(a, b) return #a > #b or (#a == #b and a < b) end)
    return names
end

local function Esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- "2 Min Cooldown", "1 Min 30 Sec Cooldown", "45s cooldown" -> seconds
local function Cooldown(t)
    local c = t:match("%(([^%)]-cooldown)%)")
    if not c then return nil end
    local total, found = 0, false
    for n, unit in c:gmatch("(%d+)%s*(%a+)") do
        if unit:find("^h") then total = total + n * 3600; found = true
        elseif unit:find("^m") then total = total + n * 60; found = true
        elseif unit:find("^s") then total = total + n; found = true end
    end
    return found and total or nil
end

-- the stats granted for a while: { [statKey] = amount }, duration in seconds
local function Granted(t)
    local dur = t:match("for (%d+) sec")
    if not dur then return nil end
    local out, any = {}, false
    for _, nm in ipairs(StatNames()) do
        local pat = Esc(nm)
        local n = t:match("(%d+) " .. pat) or t:match(pat .. " by (%d+)")
        if n then
            for _, k in ipairs(DSC.NAME_KEY[nm]) do out[k] = (out[k] or 0) + tonumber(n) end
            any = true
            t = t:gsub("%d+ " .. pat, ""):gsub(pat .. " by %d+", "")
        end
    end
    if not any then return nil end
    return out, tonumber(dur)
end

-- seconds between procs of an Equip: effect from what the tooltip says, nil when it does not say
local function ProcInterval(t)
    local ppm = t:match("approximately ([%d%.]+) procs? per minute") or t:match("([%d%.]+) procs? per minute")
    if ppm and tonumber(ppm) > 0 then return 60 / tonumber(ppm) end
    local chance = t:match("proc chance: (%d+)%%")
    if chance and tonumber(chance) > 0 then
        local icd = Cooldown(t) or 0
        local period = E.TRIGGER_SECONDS
        if t:find("critical") or t:find("crit") then period = period * E.CRIT_FACTOR end
        return icd + period / (tonumber(chance) / 100)
    end
    return nil
end

-- the stat average one effect line gives, or nil when it is not one this can read.  Second value: what it was.
function E.Parse(text)
    local t = strlower(text or "")
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local isUse = t:find("^use:") ~= nil
    local isEquip = t:find("^equip:") ~= nil
    if not (isUse or isEquip) then return nil end
    local interval
    if isUse then
        interval = Cooldown(t)
    else
        if not (t:find("chance") or t:find("each time") or t:find("procs")) then return nil end      -- plain stats are read elsewhere
        interval = ProcInterval(t)
    end
    if not interval or interval <= 0 then return nil end

    -- mana restored: mana per 5 sec over time
    local lo, hi = t:match("(%d+) to (%d+) mana")
    local mana = lo and (tonumber(lo) + tonumber(hi)) / 2 or t:match("restores? (%d+) mana") or t:match("(%d+) mana")
    if mana and not t:match("mana per 5") and not Granted(t) then
        return { [MP5] = tonumber(mana) * 5 / interval }, isUse and "use" or "proc"
    end

    local granted, dur = Granted(t)
    if not granted then return nil end
    local uptime = math.min(1, dur / interval)
    local out = {}
    for k, v in pairs(granted) do out[k] = v * uptime end
    return out, isUse and "use" or "proc"
end

-- all the effect lines of an item
function E:Stats(link)
    local out, n = {}, 0
    for _, text in ipairs(DSC:TooltipLines(link, true)) do
        local stats = E.Parse(text)
        if stats then
            n = n + 1
            for k, v in pairs(stats) do out[k] = (out[k] or 0) + v end
        end
    end
    return out, n
end
