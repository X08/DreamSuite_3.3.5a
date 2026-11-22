--[[ DreamScore: the weights window. Every class and spec with the stat weights DreamScore uses for it, and where
     they come from. Opened from the DreamScore settings or with /dscore specs. ]]
local DS = DreamSuite
local M = DS.byId and DS.byId.DreamScore
local DSC = DS.DreamScore or (M and M.api)
if not DSC then return end

local W = {}
DSC.Weights = W

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local FALLBACK_NAME = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }

local ROWS, ROW_H = 13, 13
local classIdx = 1
local window

local function ClassName(c)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or FALLBACK_NAME[c] or c
end

local function ClassColor(c)
    local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    if col then return col.r, col.g, col.b end
    return 1, 0.82, 0
end

-- the specs of a class as columns: the three trees, the bear variant of Feral next to its cat
local function Columns(class)
    local S = DSC.SPECS[class]
    local cols = {}
    if not S then return cols end
    for tab = 1, 3 do
        if S[tab] then cols[#cols + 1] = S[tab] end
        if class == "DRUID" and tab == 2 and DSC.SPECS.DRUID_BEAR then cols[#cols + 1] = DSC.SPECS.DRUID_BEAR end
    end
    return cols
end

-- every distinct source of a class, with the specs it covers
local function Sources(cols)
    local order, bySrc = {}, {}
    for _, e in ipairs(cols) do
        local s = e.source or "unknown"
        if not bySrc[s] then bySrc[s] = {}; order[#order + 1] = s end
        table.insert(bySrc[s], e.name)
    end
    local lines = {}
    for _, s in ipairs(order) do lines[#lines + 1] = table.concat(bySrc[s], ", ") .. ": " .. s end
    return lines
end

-- the weights view: class picker, one column per spec, and the sources under it. Used inside the settings (a tab)
-- and in its own window (/dscore specs).
function W:NewView(parent, width)
    local v = CreateFrame("Frame", nil, parent)
    v:SetWidth(width); v:SetHeight(372)

    local function Arrow(label, dx, step)
        local b = CreateFrame("Button", nil, v, "UIPanelButtonTemplate")
        b:SetWidth(26); b:SetHeight(22); b:SetText(label)
        b:SetPoint("TOP", v, "TOP", dx, 0)
        b:SetScript("OnClick", function() classIdx = ((classIdx - 1 + step) % #CLASSES) + 1; v:Refresh() end)
        return b
    end
    Arrow("<", -110, -1); Arrow(">", 110, 1)
    v.className = v:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    v.className:SetPoint("TOP", v, "TOP", 0, -3)

    v.info = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    v.info:SetPoint("TOPLEFT", 4, -30); v.info:SetWidth(width - 8); v.info:SetJustifyH("LEFT")

    v.cols = {}
    for c = 1, 4 do
        local col = { head = v:CreateFontString(nil, "OVERLAY", "GameFontNormal"), rows = {} }
        for r = 1, ROWS do
            col.rows[r] = {
                name = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
                val = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            }
            col.rows[r].val:SetJustifyH("RIGHT"); col.rows[r].name:SetJustifyH("LEFT")
        end
        v.cols[c] = col
    end

    local srcTop = 52 + 18 + ROWS * ROW_H + 8
    v.srcTitle = v:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    v.srcTitle:SetPoint("TOPLEFT", 4, -srcTop); v.srcTitle:SetText("Sources")
    v.src = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    v.src:SetPoint("TOPLEFT", v.srcTitle, "BOTTOMLEFT", 0, -3)
    v.src:SetWidth(width - 8); v.src:SetJustifyH("LEFT")
    v.note = v:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    v.note:SetPoint("TOPLEFT", v.src, "BOTTOMLEFT", 0, -6); v.note:SetWidth(width - 8); v.note:SetJustifyH("LEFT")
    v.note:SetText("The stat priorities come from the guides above; turning a priority list into numbers is a judgment call. 1.00 is worth one point of the main stat. Weights are relative within a spec, so scores are not comparable between classes.")

    function v:Refresh()
        local class = CLASSES[classIdx]
        v.className:SetText(ClassName(class))
        v.className:SetTextColor(ClassColor(class))
        local cols = Columns(class)
        local n = #cols
        local colW = (width - 8) / math.max(n, 1)
        local mine = DSC:Spec()
        local _, myClass = UnitClass("player")
        local info
        if mine and myClass == class then
            info = "You: " .. mine.name .. " (what DreamScore currently uses for you). The columns show each spec at 100%."
        else
            info = "The columns show each spec at 100%. With few talent points your own weights are an average of them."
        end
        if DSC.db().hardcore then info = info .. " Hardcore is on: stamina counts double." end
        v.info:SetText(info)
        for c = 1, 4 do
            local col, e = v.cols[c], cols[c]
            if not e then
                col.head:Hide()
                for _, row in ipairs(col.rows) do row.name:Hide(); row.val:Hide() end
            else
                local x = 4 + (c - 1) * colW
                col.head:ClearAllPoints(); col.head:SetPoint("TOPLEFT", x, -52); col.head:SetText(e.name); col.head:Show()
                local keys = {}
                for k in pairs(e.w) do keys[#keys + 1] = k end
                table.sort(keys, function(a, b) return e.w[a] > e.w[b] or (e.w[a] == e.w[b] and a < b) end)
                for r = 1, ROWS do
                    local row, k = col.rows[r], keys[r]
                    if k then
                        local y = -(52 + 18 + (r - 1) * ROW_H)
                        row.name:ClearAllPoints(); row.name:SetPoint("TOPLEFT", x, y)
                        row.name:SetWidth(colW - 56); row.name:SetText(DSC.StatName(k)); row.name:Show()
                        row.val:ClearAllPoints(); row.val:SetPoint("TOPRIGHT", v, "TOPLEFT", x + colW - 12, y)
                        row.val:SetText(string.format("%.2f", e.w[k])); row.val:Show()
                    else
                        row.name:Hide(); row.val:Hide()
                    end
                end
            end
        end
        v.src:SetText(table.concat(Sources(cols), "\n"))
    end
    v:Refresh()
    return v
end

-- the same view in a window of its own (/dscore specs)
function W:Show(class)
    if not window then
        window = CreateFrame("Frame", "DreamScoreWeightsFrame", UIParent)
        window:SetWidth(660); window:SetHeight(440)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        window:SetBackdropColor(0.04, 0.04, 0.06, 0.97)
        window:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        window:SetMovable(true); window:EnableMouse(true); window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window:Hide()
        if UISpecialFrames then table.insert(UISpecialFrames, "DreamScoreWeightsFrame") end
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 16, -14); title:SetText("DreamScore weights")
        local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        window.view = self:NewView(window, 628)
        window.view:SetPoint("TOPLEFT", 16, -40)
    end
    if class then
        for i, c in ipairs(CLASSES) do if c == class then classIdx = i end end
    else
        local _, mine = UnitClass("player")
        for i, c in ipairs(CLASSES) do if c == mine then classIdx = i end end
    end
    window.view:Refresh()
    window:Show()
end

function W:Hide() if window then window:Hide() end end
