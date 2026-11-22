--[[ DreamScore: what lies in your bank and guild bank. The windows have to be open to read them, so what was seen on
     the last visit is remembered (only gear you can wear, as links, so gems and enchants count). The upgrade hint
     looks at these as well as your bags. ]]
local DS = DreamSuite
local DSC = DS.DreamScore
local M = DS.byId.DreamScore
local S = {}
DSC.Stash = S

local function Store()
    local db = DSC.db()
    db.stash = db.stash or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    db.stash.chars = db.stash.chars or {}
    db.stash.guilds = db.stash.guilds or {}
    return db.stash, key
end

local function Wearable(link)
    local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)
    return loc and DSC.SLOTS[loc] and true or false
end

-- the bank: the main bank slots (-1) and the bank bags
function S:ScanBank()
    local st, key = Store()
    local list = {}
    local bags = { -1 }
    for b = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7) do bags[#bags + 1] = b end
    for _, bag in ipairs(bags) do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link and Wearable(link) then list[#list + 1] = link end
        end
    end
    st.chars[key] = { bank = list, seen = time() }
end

-- the guild bank tab that is showing (tabs load one at a time, so each visited tab is remembered on its own)
function S:ScanGuildTab()
    if not (GetGuildInfo and GetCurrentGuildBankTab and GetGuildBankItemLink) then return end
    local guild = GetGuildInfo("player")
    if not guild then return end
    local tab = GetCurrentGuildBankTab()
    if not tab then return end
    local list = {}
    for slot = 1, (MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
        local link = GetGuildBankItemLink(tab, slot)
        if link and Wearable(link) then list[#list + 1] = link end
    end
    local st = Store()
    st.guilds[guild] = st.guilds[guild] or {}
    st.guilds[guild][tab] = { items = list, seen = time() }
end

-- everything remembered that could be an upgrade: { link, where = "bank" | "guild", label }
function S:Items()
    local out = {}
    local st, key = Store()
    local rec = st.chars[key]
    if rec then for _, l in ipairs(rec.bank or {}) do out[#out + 1] = { link = l, where = "bank", label = "your bank" } end end
    local guild = GetGuildInfo and GetGuildInfo("player")
    local g = guild and st.guilds[guild]
    if g then
        for tab, t in pairs(g) do
            for _, l in ipairs(t.items or {}) do out[#out + 1] = { link = l, where = "guild", label = "the guild bank, tab " .. tab } end
        end
    end
    return out
end

function S:Forget()
    local db = DSC.db()
    db.stash = nil
end

local frame = CreateFrame("Frame")
S.frame = frame
-- the contents can only be read while the window is open
frame:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then S.bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then S.bankOpen = false; return
    elseif event == "GUILDBANKFRAME_OPENED" then S.guildOpen = true
    elseif event == "GUILDBANKFRAME_CLOSED" then S.guildOpen = false; return end
    if not M.active then return end
    local ok, err = pcall(function()
        if event == "GUILDBANKBAGSLOTS_CHANGED" or event == "GUILDBANKFRAME_OPENED" then
            if S.guildOpen then S:ScanGuildTab() end
        elseif S.bankOpen then S:ScanBank() end
        if DSC.Hint then DSC.Hint:Kick() end
    end)
    if not ok and not S.err then S.err = true; DS.Print("DreamScore bank scan error: " .. tostring(err)) end
end)
for _, e in ipairs({ "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "GUILDBANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED", "BANKFRAME_CLOSED", "GUILDBANKFRAME_CLOSED" }) do
    pcall(frame.RegisterEvent, frame, e)
end
