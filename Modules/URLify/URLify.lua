-- URLify (DreamSuite module)
-- Hooks AddMessage on chat frames to linkify URLs at display time only.
-- The server message is never touched, so relay bots see the original text.
local DS = DreamSuite

local M = DS.RegisterModule({
    id      = "URLify",
    title   = "URLify",
    desc    = "Turns chat URLs into clickable links with a copy box",
    legacy  = { folder = "URLify" },
})

local enabled = false        -- the hooks stay in place when switched off, but do nothing
local hooked  = false

local registry = {}
local count    = 0

local function register(url)
    for i, u in ipairs(registry) do
        if u == url then return i end
    end
    count = count + 1
    registry[count] = url
    return count
end

-- Popup (created once, reused)
local popup

local function initPopup()
    if popup then return end
    popup = CreateFrame("Frame", "DreamSuiteURLifyPopup", UIParent)
    popup:SetWidth(440)
    popup:SetHeight(80)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    popup:SetBackdropColor(0, 0, 0, 0.9)

    local x = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 1, 1)
    x:SetScript("OnClick", function() popup:Hide() end)

    local label = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -14)
    label:SetText("Ctrl+C to copy:")
    label:SetTextColor(0.9, 0.9, 0.9)

    local eb = CreateFrame("EditBox", nil, popup)
    eb:SetPoint("TOPLEFT",     popup, "TOPLEFT",     14, -30)
    eb:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -14,  12)
    eb:SetFrameLevel(popup:GetFrameLevel() + 5)
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextColor(1, 1, 1)
    eb:SetAutoFocus(false)
    eb:SetMultiLine(false)
    eb:EnableMouse(true)
    eb:SetMaxLetters(2048)
    eb:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    eb:SetBackdropColor(0.06, 0.06, 0.06, 1)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() popup:Hide() end)
    eb:SetScript("OnEnterPressed",  function(self) self:ClearFocus() popup:Hide() end)
    popup.eb = eb

    popup:SetScript("OnShow", function(self)
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.eb:SetFocus()
        self.eb:HighlightText()
    end)
    popup:Hide()
end

local function showPopup(url)
    initPopup()
    popup.eb:SetText(url)
    popup:Show()
    popup.eb:SetFocus()
    popup.eb:HighlightText()
end

local PAT = "(https?://[%w%-%.%_%~%:%/%?%#%[%]%@%!%$%&%'%(%)%*%+%,%;%=%^]+)"

local function makeLink(url)
    return "|cFF99BBFF|Hitem:" .. tostring(9000000 + register(url)) .. ":0:0:0:0:0:0:0:0|h[" .. url .. "]|h|r"
end

local function process(msg)
    if not msg or not msg:find("https?://") then return msg end
    return (msg:gsub(PAT, makeLink))
end

-- links already in the chat history stay clickable after switching off
local function onClick(self, link)
    local idStr = link and link:match("^item:(%d+):")
    if not idStr then return false end
    local id = tonumber(idStr)
    if not id or id < 9000001 then return false end
    local url = registry[id - 9000000]
    if url then showPopup(url) end
    return true
end

local function hookFrame(f)
    if not f or f._dsUrlify then return end
    f._dsUrlify = true
    f:SetHyperlinksEnabled(true)

    -- Hook AddMessage to rewrite URLs at display time only (server message untouched)
    local origAdd = f.AddMessage
    f.AddMessage = function(self, msg, r, g, b, id, ...)
        if enabled then msg = process(msg) end
        return origAdd(self, msg, r, g, b, id, ...)
    end

    local orig = f:GetScript("OnHyperlinkClick")
    f:SetScript("OnHyperlinkClick", function(self, link, text, button)
        if not onClick(self, link) then
            if orig then orig(self, link, text, button) end
        end
    end)
end

local function hookAll()
    for i = 1, NUM_CHAT_WINDOWS do
        hookFrame(_G["ChatFrame" .. i])
    end
end

function M.OnEnable()
    enabled = true
    hookAll()
    if not hooked then
        hooked = true
        hooksecurefunc("FCF_OpenNewWindow", function()
            if enabled then hookAll() end
        end)
    end
end

function M.OnDisable()
    enabled = false
    if popup then popup:Hide() end
end
