------------------------------------------------------------
-- DreamSuite - Hub window
-- one window: a list of modules (home) that crossfades into a
-- module's settings (detail) and back.
--   left-click a row   open its settings (a module without any, or a disabled one, blinks red)
--   right-click a row  menu: enable / disable, settings
------------------------------------------------------------
local DS = DreamSuite
local C = DS.C

local WIN_W, WIN_H = 800, 550
local ROW_W, ROW_H = WIN_W - 52, 52
local LIST_TOP = 78
local FADE_TIME = 0.15

local main, home, detail, links, menuFrame, notice
local head, headLogo, headTitle, headCredit, profileBtn, escProxy
local changelog         -- scrollable version history (click the version in the footer)
local thanks            -- the hidden thank-you page (click the logo three times)

-- who gets thanked; edit freely. class: HUNTER, WARLOCK, PALADIN, MAGE, DRUID, PRIEST (anything else = gold)
DS.THANKS = {
    guild = "Stratholme Fire Brigade",
    names = {
        { "Sapphine", "HUNTER" }, { "Soul", "WARLOCK" }, { "Void", "DRUID" }, { "Mack", "PALADIN" },
        { "Luna", "MAGE" }, { "Rachnor", "PALADIN" }, { "Desblade", "PRIEST" },
    },
}
local CLASS_COLOR = {
    HUNTER = { 0.67, 0.83, 0.45 }, WARLOCK = { 0.58, 0.51, 0.79 }, PALADIN = { 0.96, 0.55, 0.73 },
    MAGE = { 0.41, 0.80, 0.94 }, DRUID = { 1, 0.49, 0.04 }, PRIEST = { 1, 1, 1 },
}
local closing = false
DS.escHooks = {}        -- functions: return true when Esc was used up by something inside the window
local cells = {}
local busy = false
local embedded                           -- { m = module, frame = frame } while a module builds its own settings

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

------------------------------------------------------------
-- Crossfade helper
------------------------------------------------------------
local function Fade(frame, from, to, done)
    DS.UI.Fade(frame, from, to, FADE_TIME, done)
end

------------------------------------------------------------
-- Modules that build their own settings view
------------------------------------------------------------
local function ReleaseEmbed()
    local cur = embedded
    embedded = nil
    if notice then notice:Hide() end
    if not cur then return end
    if cur.m.release then
        local ok, err = pcall(cur.m.release, cur.frame)
        if not ok then geterrorhandler()(err) end
    else
        cur.frame:Hide()
    end
end

local function ShowEmbed(m, body)
    ReleaseEmbed()
    local ok, frame = pcall(m.embed, body, detail)
    if ok and type(frame) == "table" then
        frame:Show()
        embedded = { m = m, frame = frame }
        return
    end
    if not notice then
        notice = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        notice:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -4)
        notice:SetWidth(560)
        notice:SetJustifyH("LEFT")
    end
    notice:SetText(m.title .. " could not build its settings" .. (ok and "." or (":\n" .. tostring(frame))))
    notice:Show()
end

local function ShowDetailBody(m, body)
    ReleaseEmbed()
    if m.embed then
        DS.HideContents()
        ShowEmbed(m, body)
    else
        DS.ShowContent(m, body)
    end
end

-- the header shows DreamSuite, or the module whose settings are open
local function SetHeader(m)
    if not head then return end
    if m then
        headLogo:SetTexture(DS.IconPath(m))
        headTitle:SetText(m.title)
        headCredit:SetText(C.grey .. (m.desc or "") .. C.r)
    else
        headLogo:SetTexture(DS.ICONS .. "Hub.tga")
        headTitle:SetText("DreamSuite")
        headCredit:SetText(C.grey .. "by " .. C.r .. C.yellow .. "X08" .. C.r .. C.grey .. " | " .. C.r ..
                           C.orange .. "Dreamwind (Chromiecraft-EU)" .. C.r)
    end
end

local function ResetViews()
    busy = false
    if not home then return end
    head:SetScript("OnUpdate", nil); head.fading = nil
    head:SetAlpha(1); head:Show()
    SetHeader(nil)
    home:SetScript("OnUpdate", nil); detail:SetScript("OnUpdate", nil)
    home.fading, detail.fading = nil, nil
    home:SetAlpha(1); home:Show()
    detail:SetAlpha(0); detail:Hide()
    DS.currentContent = nil
    ReleaseEmbed()
end

------------------------------------------------------------
-- Link popup: WoW cannot open a browser, so links are shown as
-- pre-selected text to copy with Ctrl+C.
------------------------------------------------------------
local function BuildLinks()
    links = CreateFrame("Frame", "DreamSuiteLinks", UIParent)
    links:SetWidth(440); links:SetHeight(60)
    links:SetFrameStrata("FULLSCREEN_DIALOG")
    links:SetBackdrop(BACKDROP)
    links:EnableMouse(true)
    links:SetPoint("CENTER", main, "CENTER", 0, 0)

    links.title = links:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    links.title:SetPoint("TOPLEFT", 22, -20)
    local hint = links:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", links.title, "BOTTOMLEFT", 0, -3)
    hint:SetText("Click a box, press Ctrl+C, then paste it into your browser.")

    local close = CreateFrame("Button", nil, links, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    links.rows = {}
    for i = 1, 3 do
        local lbl = links:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 24, -58 - (i - 1) * 40)
        local eb = CreateFrame("EditBox", nil, links, "InputBoxTemplate")
        eb:SetWidth(390); eb:SetHeight(20)
        eb:SetPoint("TOPLEFT", 28, -72 - (i - 1) * 40)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        eb:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); links:Hide() end)
        eb:SetScript("OnTextChanged", function(self)
            if self.url and self:GetText() ~= self.url then
                self:SetText(self.url)
                self:HighlightText()
            end
        end)
        links.rows[i] = { label = lbl, edit = eb }
    end
end

function DS.ShowLinks()
    if not main then return end
    if not links then BuildLinks() end
    local list = DS.GetLinks()
    links.title:SetText("DreamSuite - where to get the latest version")
    for i, r in ipairs(links.rows) do
        local l = list[i]
        if l then
            r.label:SetText(l[1]); r.label:Show()
            r.edit.url = l[2]
            r.edit:SetText(l[2]); r.edit:SetCursorPosition(0)
            r.edit:Show()
        else
            r.label:Hide(); r.edit:Hide(); r.edit.url = nil
        end
    end
    links:SetHeight(86 + #list * 40)
    links:Show()
end

------------------------------------------------------------
-- Actions
------------------------------------------------------------
-- version history: generated from CHANGELOG.md into Core\\Changelog.lua
-- WoW cannot mix a bold font into one text block, so the tags are bright capitals
local TYPE_TAG = { b = "|cffffd000MAJOR|r", c = "|cff6cb8ffMINOR|r", d = "|cffc8c8c8FIX|r" }
local TAG_PAD = { b = "  ", c = "  ", d = "    " }

local function BuildChangelog()
    changelog = CreateFrame("Frame", nil, main)
    changelog:SetPoint("TOPLEFT", main, "TOPLEFT", 14, -72)
    changelog:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -14, 50)
    changelog:SetFrameLevel(main:GetFrameLevel() + 30)
    changelog:EnableMouse(true)
    changelog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    changelog:SetBackdropColor(0.03, 0.03, 0.05, 1)
    changelog:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
    changelog:Hide()

    local title = changelog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetText("What changed")
    local close = CreateFrame("Button", nil, changelog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() DS.HideChangelog() end)

    local scroll = CreateFrame("ScrollFrame", "DreamSuiteChangelogScroll", changelog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -44)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(690); content:SetHeight(10)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 48)))
    end)

    local prev, total = nil, 0
    for _, rel in ipairs(DS.CHANGELOG or {}) do
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetWidth(680); fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
        if prev then fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14) else fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -2) end
        local lines = { "|cffffc800Version " .. rel.ver .. "|r"
            .. (rel.date and rel.date ~= "" and ("  |cff808080(" .. rel.date .. ")|r") or "")
            .. (rel.ver == DS.VERSION and "  |cff40ff40(installed)|r" or "") }
        for _, it in ipairs(rel.items) do
            lines[#lines + 1] = (TYPE_TAG[it[1]] or "") .. (TAG_PAD[it[1]] or "  ") .. it[2]
        end
        fs:SetText(table.concat(lines, "\n"))
        local h = fs:GetStringHeight()
        if not h or h < 14 then h = 14 * #lines end
        total = total + h + 14
        prev = fs
    end
    content:SetHeight(total + 10)
end

function DS.ShowChangelog()
    if not main then return end
    if not changelog then BuildChangelog() end
    if changelog:IsShown() then return end
    DS.UI.Fade(changelog, 0, 1, 0.2)
end

function DS.HideChangelog()
    if changelog and changelog:IsShown() then DS.UI.Fade(changelog, changelog:GetAlpha(), 0, 0.15) end
end

tinsert(DS.escHooks, function()
    if changelog and changelog:IsShown() then DS.HideChangelog(); return true end
end)

-- the thank-you page: covers the whole window (fully opaque), click anywhere (or Esc) to close it
local STAR, GLOW = "Interface\\Cooldown\\star4", "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function Clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end

local function BuildThanks()
    thanks = CreateFrame("Frame", nil, main)
    thanks:SetAllPoints(main)
    thanks:SetFrameLevel(main:GetFrameLevel() + 40)
    thanks:EnableMouse(true)
    thanks:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    thanks:Hide()
    thanks:SetScript("OnMouseUp", function() DS.HideThanks() end)

    local bg = thanks:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(thanks)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.03, 0.02, 0.07, 1)

    local fx = CreateFrame("Frame", nil, thanks)      -- animation driver (thanks itself is used by the fade)
    fx:SetAllPoints(thanks)

    -- slow colored clouds
    local clouds = {}
    local cloudCol = { { 0.45, 0.2, 0.9 }, { 1, 0.6, 0.1 }, { 0.2, 0.55, 1 } }
    for i = 1, 3 do
        local c = fx:CreateTexture(nil, "BORDER")
        c:SetTexture(GLOW); c:SetBlendMode("ADD")
        c:SetWidth(420); c:SetHeight(300)
        c:SetVertexColor(cloudCol[i][1], cloudCol[i][2], cloudCol[i][3], 0.16)
        clouds[i] = c
    end

    -- twinkling stars drifting upward
    local stars = {}
    for i = 1, 48 do
        local t = fx:CreateTexture(nil, "ARTWORK")
        t:SetTexture(STAR); t:SetBlendMode("ADD")
        local sz = 5 + math.random() * 11
        t:SetWidth(sz); t:SetHeight(sz)
        stars[i] = { tex = t, x = math.random() * 780 + 10, y = math.random() * 540, v = 6 + math.random() * 22,
                     ph = math.random() * 6.28, sp = 1 + math.random() * 3, gold = math.random() < 0.5 }
    end

    -- logo with a pulsing halo
    local halo = fx:CreateTexture(nil, "ARTWORK")
    halo:SetTexture(GLOW); halo:SetBlendMode("ADD")
    halo:SetWidth(170); halo:SetHeight(170)
    halo:SetPoint("TOP", fx, "TOP", 0, 6 - 28 + 4)
    halo:SetVertexColor(1, 0.75, 0.2, 0.5)
    local logo = fx:CreateTexture(nil, "OVERLAY")
    logo:SetWidth(64); logo:SetHeight(64)
    logo:SetPoint("TOP", fx, "TOP", 0, -28)
    logo:SetTexture(DS.ICONS .. "Hub.tga")

    -- "Thank You": one font string per letter, a wave and a sweeping highlight
    local letters, word = {}, "Thank You"
    local total = 0
    for i = 1, #word do
        local fs = fx:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\FRIZQT__.TTF", 38, "OUTLINE")
        fs:SetText(string.sub(word, i, i))
        local w = fs:GetStringWidth() or 0
        if w == 0 then w = 14 end
        letters[i] = { fs = fs, w = w }
        total = total + w + 1
    end
    local titleX = -total / 2
    for i, l in ipairs(letters) do
        l.x = titleX + l.w / 2
        titleX = titleX + l.w + 1
    end

    local sub = fx:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub:SetPoint("TOP", fx, "TOP", 0, -158)
    sub:SetWidth(640)
    sub:SetText("To everyone I've met in WoW all these years. To those that bring joy and laughter into our near daily conversations and who inspire me to tinker away and create without judgement and to those who helped out and tested it for many, many days.")

    local who = fx:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    who:SetPoint("TOP", fx, "TOP", 0, -226)
    who:SetWidth(560)
    who:SetText("The whole |cff40ff40<" .. DS.THANKS.guild .. ">|r crew;")

    -- names in class colors, 4 per row
    local nameFs = {}
    local list = DS.THANKS.names
    local perRow, cellW = 4, 170
    for i, n in ipairs(list) do
        local fs = fx:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
        local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
        local inRow = math.min(perRow, #list - row * perRow)
        local x = (col - (inRow - 1) / 2) * cellW
        local c = CLASS_COLOR[n[2] or ""] or { 1, 0.82, 0 }
        fs:SetText(n[1])
        fs:SetTextColor(c[1], c[2], c[3])
        nameFs[i] = { fs = fs, x = x, y = -262 - row * 36, ph = i * 0.7 }
    end

    local others = fx:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    others:SetPoint("TOP", fx, "TOP", 0, -336)
    others:SetWidth(700)
    others:SetText("and everyone else, including the former |cff6699ff<Blades of Wrynn>|r guild on Turtle WoW (Tel'Abim-PvP)")

    -- the cats
    local catsLine = fx:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catsLine:SetPoint("TOP", fx, "TOP", 0, -378)
    catsLine:SetWidth(560)
    catsLine:SetText("And a little thanks to my two cats")
    local plate = fx:CreateTexture(nil, "ARTWORK")
    plate:SetTexture(GLOW); plate:SetBlendMode("ADD")
    plate:SetWidth(150); plate:SetHeight(60)
    plate:SetVertexColor(0.55, 0.55, 0.6, 0.45)
    plate:SetPoint("TOP", fx, "TOP", 62, -392)
    local lea = fx:CreateFontString(nil, "OVERLAY")
    lea:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    lea:SetPoint("TOP", fx, "TOP", -62, -402)
    lea:SetText("Lea"); lea:SetTextColor(1, 0.5, 0.04)
    local oriL = {}                                   -- tabby: black and white patches
    local oriCol = { { 1, 1, 1 }, { 0.1, 0.1, 0.1 }, { 0.9, 0.9, 0.9 } }
    local ox = 62 - 36
    for i = 1, 3 do
        local fs = fx:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
        fs:SetText(string.sub("Ori", i, i))
        local c = oriCol[i]
        fs:SetTextColor(c[1], c[2], c[3])
        local w = fs:GetStringWidth() or 0
        if w == 0 then w = 18 end
        fs:SetPoint("TOPLEFT", fx, "TOP", ox, -402)
        ox = ox + w
        oriL[i] = fs
    end

    local foryou = fx:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    foryou:SetPoint("TOP", fx, "TOP", 0, -446)
    foryou:SetWidth(640)
    foryou:SetText("And to you for using this addon. Thank you.")

    local credit = fx:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    credit:SetPoint("BOTTOM", fx, "BOTTOM", 0, 34)
    credit:SetText("|cffffc800X08|r || |cffff7d0aDreamwind|r (Chromiecraft-EU)")
    local closeHint = fx:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    closeHint:SetPoint("BOTTOM", fx, "BOTTOM", 0, 16)
    closeHint:SetText("click anywhere to close")

    local t = 0
    fx:SetScript("OnShow", function() t = 0 end)
    fx:SetScript("OnUpdate", function(_, e)
        t = t + e
        thanks:SetBackdropBorderColor(1, 0.78, 0.1, 0.55 + 0.45 * math.sin(t * 2))
        for i, c in ipairs(clouds) do
            c:ClearAllPoints()
            c:SetPoint("CENTER", fx, "CENTER", math.sin(t * 0.25 + i * 2.1) * 170, math.cos(t * 0.2 + i * 1.3) * 110)
            c:SetAlpha(0.7 + 0.3 * math.sin(t * 0.6 + i))
        end
        for _, st in ipairs(stars) do
            st.y = st.y + st.v * e
            if st.y > 550 then st.y = -10; st.x = math.random() * 780 + 10 end
            st.tex:ClearAllPoints()
            st.tex:SetPoint("CENTER", fx, "BOTTOMLEFT", st.x, st.y)
            local a = 0.25 + 0.75 * math.abs(math.sin(t * st.sp + st.ph))
            if st.gold then st.tex:SetVertexColor(1, 0.85, 0.4, a) else st.tex:SetVertexColor(0.8, 0.85, 1, a) end
        end
        halo:SetAlpha(0.55 + 0.45 * math.sin(t * 2.2))
        for i, l in ipairs(letters) do
            local s = math.sin(t * 2.4 - i * 0.55); s = s > 0 and s * s * s * s or 0
            l.fs:ClearAllPoints()
            l.fs:SetPoint("CENTER", fx, "TOP", l.x, -128 + math.sin(t * 3 + i * 0.6) * 4)
            l.fs:SetTextColor(1, 0.82 + 0.18 * s, 0.2 + 0.7 * s)
            l.fs:SetAlpha(Clamp01(t * 3 - i * 0.12))
        end
        sub:SetAlpha(Clamp01(t - 0.8)); who:SetAlpha(Clamp01(t - 1.2)); others:SetAlpha(Clamp01(t - 3.2))
        for i, n in ipairs(nameFs) do
            n.fs:ClearAllPoints()
            n.fs:SetPoint("CENTER", fx, "TOP", n.x, n.y + math.sin(t * 1.6 + n.ph) * 2)
            n.fs:SetAlpha(Clamp01((t - 1.6 - i * 0.22) / 0.5))
        end
        local ca = Clamp01((t - 3.8) / 0.7)
        catsLine:SetAlpha(ca); lea:SetAlpha(ca); plate:SetAlpha(ca * (0.7 + 0.3 * math.sin(t * 1.5)))
        for _, fs in ipairs(oriL) do fs:SetAlpha(ca) end
        foryou:SetAlpha(Clamp01((t - 5) / 0.8)); credit:SetAlpha(Clamp01(t - 4.5)); closeHint:SetAlpha(Clamp01(t - 4.5) * (0.5 + 0.5 * math.sin(t * 2)))
    end)
end

function DS.ShowThanks()
    if not main then return end
    if not thanks then BuildThanks() end
    DS.UI.Fade(thanks, 0, 1, 0.4)
end

function DS.HideThanks()
    if thanks and thanks:IsShown() then DS.UI.Fade(thanks, thanks:GetAlpha(), 0, 0.3) end
end

tinsert(DS.escHooks, function()
    if thanks and thanks:IsShown() then DS.HideThanks(); return true end
end)

function DS.OpenDetail(m)
    if busy or not main or not m.active or not DS.HasSettings(m) then return end
    busy = true
    ShowDetailBody(m, detail.body)
    detail.module = m
    Fade(head, 1, 0, function()
        SetHeader(m)
        Fade(head, 0, 1)
    end)
    Fade(home, 1, 0, function()
        Fade(detail, 0, 1, function() busy = false end)
    end)
end

function DS.CloseDetail()
    if busy or not detail:IsShown() then return end
    busy = true
    Fade(head, 1, 0, function()
        SetHeader(nil)
        Fade(head, 0, 1)
    end)
    Fade(detail, 1, 0, function()
        DS.currentContent = nil
        ReleaseEmbed()
        Fade(home, 0, 1, function() busy = false end)
    end)
end

------------------------------------------------------------
-- Right-click menu
------------------------------------------------------------
local function ShowMenu(m)
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "DreamSuiteContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = { { text = m.title, isTitle = true, notCheckable = true } }
    tinsert(menu, { text = m.error and "Try again" or (DS.IsEnabled(m) and "Disable" or "Enable"), notCheckable = true,
                    disabled = m.conflict and true or false,
                    func = function()
                        if m.error then m.error = nil end
                        DS.Toggle1(m)
                    end })
    tinsert(menu, { text = "Settings", notCheckable = true,
                    disabled = not (m.active and DS.HasSettings(m)),
                    func = function() DS.OpenDetail(m) end })
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
end

------------------------------------------------------------
-- Profiles
------------------------------------------------------------
StaticPopupDialogs["DREAMSUITE_USE_PROFILE"] = {
    text = "Use %s's settings profile?\n\nWhat you have now stays in the profile you are leaving. The interface reloads.",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function(self, data) DS.UseProfile(data) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function DS.ShowProfileMenu()
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "DreamSuiteContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local cur, curOwn = DS.CurrentProfile()
    local me = DS.CharKey()
    local menu = { { text = "Settings profile", isTitle = true, notCheckable = true } }
    for _, name in ipairs(DS.ProfileNames()) do
        local label = DS.ProfileDisplay(name) .. (name == me and "  (this character)" or "")
        tinsert(menu, { text = label, checked = (name == cur),
                        func = function()
                            if name ~= (DS.CurrentProfile()) then
                                StaticPopup_Show("DREAMSUITE_USE_PROFILE", DS.ProfileDisplay(name), nil, name)
                            end
                        end })
    end
    tinsert(menu, { text = "Save current settings to " .. DS.ProfileDisplay(me), notCheckable = true,
                    disabled = curOwn and true or false,
                    func = function() DS.SaveProfileHere(); DS.RefreshAll() end })
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
end

local function UpdateProfileButton()
    if not profileBtn then return end
    local name, own = DS.CurrentProfile()
    profileBtn:SetText("Profile: " .. DS.ProfileDisplay(name) .. (own and "" or " (other)"))
end

------------------------------------------------------------
-- Home grid
------------------------------------------------------------
local function StatusState(m, status)
    if status == "conflict" then return "Old addon installed", 1, 0.3, 0.3
    elseif status == "error" then return "Failed to start", 1, 0.3, 0.3
    elseif status == "pending" then return (DS.pending[m.id] and "Enables" or "Disables") .. " after combat", 1, 0.55, 0.1
    elseif status == "on" then return "Enabled", 0.3, 0.9, 0.3
    end
    return "Disabled", 0.55, 0.55, 0.55
end

local function UpdateCell(cell)
    local m = cell.module
    local status = DS.Status(m)
    local bright = DS.IsEnabled(m) and status ~= "conflict" and status ~= "error"

    if bright then
        cell.icon:SetDesaturated(nil)
        cell.icon:SetVertexColor(1, 1, 1)
        cell.title:SetTextColor(1, 0.82, 0)
        cell.desc:SetTextColor(0.8, 0.8, 0.8)
    else
        cell.icon:SetDesaturated(1)
        cell.icon:SetVertexColor(0.5, 0.5, 0.5)
        cell.title:SetTextColor(0.5, 0.5, 0.5)
        cell.desc:SetTextColor(0.45, 0.45, 0.45)
    end
    cell.switch:SetState(StatusState(m, status))

    -- red badge on the icon = problem
    if status == "conflict" or status == "error" then
        cell.badge:SetVertexColor(1, 0.25, 0.25); cell.badge:Show()
    else
        cell.badge:Hide()
    end
    cell.status_ = status
end

-- the whole row glows a faint red (instead of the blue hover plate): this click does nothing
local BLINK_TIME = 0.55
local function Blink(cell)
    local t = 0
    cell.hl:SetAlpha(0)
    cell:SetScript("OnUpdate", function(self, el)
        t = t + el
        if t >= BLINK_TIME then
            self.red:SetAlpha(0)
            self.hl:SetAlpha(1)
            self:SetScript("OnUpdate", nil)
            return
        end
        self.red:SetAlpha(math.sin(math.pi * t / BLINK_TIME))
    end)
end

local function Tooltip(cell)
    local m = cell.module
    local status = cell.status_ or DS.Status(m)
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:AddLine(m.title, 1, 0.82, 0)
    if m.desc then GameTooltip:AddLine(m.desc, 1, 1, 1, true) end
    if m.slash then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Command", table.concat(m.slash, "  "), 0.6, 0.6, 0.6, 0.9, 0.9, 0.9)
    end
    GameTooltip:AddLine(" ")
    if status == "conflict" then
        GameTooltip:AddLine("The old " .. m.legacy.folder .. " addon is still loaded.", 1, 0.4, 0.4, true)
        GameTooltip:AddLine("Type /ds legacy, then /reload.", 1, 0.4, 0.4, true)
    elseif status == "error" then
        GameTooltip:AddLine(tostring(m.error), 1, 0.4, 0.4, true)
        GameTooltip:AddLine("Right-click: try again", 0.5, 0.8, 1)
    else
        if m.active and DS.HasSettings(m) then GameTooltip:AddLine("Click: settings", 0.5, 0.8, 1) end
        GameTooltip:AddLine("Right-click: " .. (DS.IsEnabled(m) and "disable" or "enable") .. (DS.HasSettings(m) and " / settings" or ""), 0.5, 0.8, 1)
    end
    GameTooltip:Show()
end

local function BuildCell(i, m)
    local cell = CreateFrame("Button", nil, home)
    cell.module = m
    cell:SetWidth(ROW_W); cell:SetHeight(ROW_H)
    cell:SetPoint("TOPLEFT", main, "TOPLEFT", 26, -(LIST_TOP + (i - 1) * ROW_H))
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- hover plate and a thin rule under every row
    local hl = cell:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetTexture(0.45, 0.65, 1, 0.12)
    hl:Hide()
    cell.hl = hl
    local rule = cell:CreateTexture(nil, "BORDER")
    rule:SetHeight(1)
    rule:SetTexture(1, 1, 1, 0.06)
    rule:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 0, 0)

    cell.red = cell:CreateTexture(nil, "BACKGROUND")
    cell.red:SetAllPoints()
    cell.red:SetTexture(1, 0.2, 0.2, 0.22)
    cell.red:SetAlpha(0)

    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetWidth(34); cell.icon:SetHeight(34)
    cell.icon:SetPoint("LEFT", cell, "LEFT", 9, 0)
    cell.icon:SetTexture(DS.IconPath(m))

    cell.badge = cell:CreateTexture(nil, "OVERLAY")
    cell.badge:SetTexture(DS.ICONS .. "dot.tga")
    cell.badge:SetWidth(14); cell.badge:SetHeight(14)
    cell.badge:SetPoint("TOPRIGHT", cell.icon, "TOPRIGHT", 4, 4)
    cell.badge:Hide()

    cell.title = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell.title:SetPoint("TOPLEFT", cell, "TOPLEFT", 56, -8)
    cell.title:SetWidth(240)
    cell.title:SetJustifyH("LEFT")
    cell.title:SetText(m.title)

    cell.desc = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.desc:SetPoint("TOPLEFT", cell.title, "BOTTOMLEFT", 0, -3)
    cell.desc:SetWidth(350); cell.desc:SetHeight(24)
    cell.desc:SetJustifyH("LEFT"); cell.desc:SetJustifyV("TOP")
    cell.desc:SetText(m.desc or "")

    cell.cmd = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    local hasCmd, hasMenu = m.slash and m.slash[1], DS.HasSettings(m)
    cell.cmd:SetPoint("RIGHT", cell, "RIGHT", -150, (not hasMenu and hasCmd) and 7 or 0)
    cell.cmd:SetWidth(190)
    cell.cmd:SetJustifyH("RIGHT")
    -- the command(s): the first and the last of a module's slashes, e.g. "/inventoryplus  /ip"
    local sl = m.slash
    local cmdText = ""
    if sl and sl[1] then
        cmdText = sl[1]
        if #sl > 1 then cmdText = cmdText .. "  " .. sl[#sl] end
    end
    cell.cmd:SetText(cmdText)

    if not hasMenu then
        cell.noMenu = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cell.noMenu:SetPoint("RIGHT", cell, "RIGHT", -150, hasCmd and -7 or 0)
        cell.noMenu:SetWidth(150)
        cell.noMenu:SetJustifyH("RIGHT")
        cell.noMenu:SetTextColor(1, 0.3, 0.3)
        cell.noMenu:SetText("No menu available")
    end

    cell.switch = DS.UI.StateBox(cell, 128, 24)
    cell.switch:SetPoint("RIGHT", cell, "RIGHT", -10, 0)
    cell.status = cell.switch.text
    cell.switch:SetScript("OnEnter", function(self)
        cell.hl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(DS.IsEnabled(m) and "Click to disable" or "Click to enable", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    cell.switch:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if not (MouseIsOver and MouseIsOver(cell)) then cell.hl:Hide() end
    end)
    cell.switch:SetScript("OnClick", function()
        GameTooltip:Hide()
        if busy then return end
        if m.error then m.error = nil end
        DS.Toggle1(m)
    end)

    cell:SetScript("OnEnter", function(self) self.hl:Show(); Tooltip(self) end)
    cell:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    cell:SetScript("OnClick", function(self, button)
        GameTooltip:Hide()
        if busy then return end
        if button == "RightButton" then
            ShowMenu(m)
        elseif m.active and DS.HasSettings(m) then
            DS.OpenDetail(m)
        else
            Blink(self)
        end
    end)

    cells[i] = cell
    return cell
end

function DS.RefreshAll()
    for _, cell in ipairs(cells) do UpdateCell(cell) end
    UpdateProfileButton()
    if main then
        if #DS.legacyFound > 0 then
            main.notice.kind = "legacy"
            main.notice.text:SetText(C.red .. "Old standalone addons found: " .. table.concat(DS.legacyFound, ", ") ..
                                     " - type /ds legacy" .. C.r)
        elseif DS.UpdateAvailable() then
            local _, newer = DS.UpdateAvailable()
            main.notice.kind = "update"
            main.notice.text:SetText(C.orange .. "A newer DreamSuite exists" .. (newer and (" (" .. newer .. ")") or "") .. " - click for links" .. C.r)
        else
            main.notice.kind = nil
            main.notice.text:SetText("")
        end
    end
    if DS.UpdateMinimap then DS.UpdateMinimap() end
end

------------------------------------------------------------
-- Window
------------------------------------------------------------
local function BuildMain()
    main = CreateFrame("Frame", "DreamSuiteFrame", UIParent)
    main:SetWidth(WIN_W); main:SetHeight(WIN_H)
    main:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    main:SetFrameStrata("DIALOG")
    main:SetBackdrop(BACKDROP)
    main:SetMovable(true)
    main:SetClampedToScreen(true)
    main:EnableMouse(true)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", function(self) self:StartMoving() end)
    main:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    -- Esc closes the proxy, which turns into the fade-out of the window
    escProxy = CreateFrame("Frame", "DreamSuiteEscProxy", UIParent)
    escProxy:Hide()
    escProxy:SetScript("OnHide", function()
        if not main:IsShown() or closing then return end
        for _, swallow in ipairs(DS.escHooks) do
            if swallow() then escProxy:Show(); return end      -- a module closed something of its own: the window stays
        end
        DS.Close()
    end)
    tinsert(UISpecialFrames, "DreamSuiteEscProxy")

    -- header (always visible): DreamSuite, or the module that is open
    head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    head:SetWidth(440); head:SetHeight(68)

    headLogo = head:CreateTexture(nil, "ARTWORK")
    headLogo:SetWidth(40); headLogo:SetHeight(40)
    headLogo:SetPoint("TOPLEFT", 24, -16)

    headTitle = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headTitle:SetPoint("TOPLEFT", headLogo, "TOPRIGHT", 10, -3)

    headCredit = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headCredit:SetPoint("TOPLEFT", headTitle, "BOTTOMLEFT", 0, -2)
    headCredit:SetWidth(360); headCredit:SetHeight(12)
    headCredit:SetJustifyH("LEFT")
    SetHeader(nil)
    main.headTitle, main.headLogo, main.headCredit = headTitle, headLogo, headCredit

    -- hidden: click the X08 logo three times (while DreamSuite's own logo is showing)
    local logoBtn = CreateFrame("Button", nil, head)
    logoBtn:SetAllPoints(headLogo)
    logoBtn:RegisterForDrag("LeftButton")
    logoBtn:SetScript("OnDragStart", function() main:StartMoving() end)
    logoBtn:SetScript("OnDragStop", function() main:StopMovingOrSizing() end)
    local clicks, firstClick = 0, 0
    logoBtn:SetScript("OnClick", function()
        if detail and detail:IsShown() then return end
        local now = GetTime()
        if now - firstClick > 2 then clicks, firstClick = 0, now end
        clicks = clicks + 1
        if clicks >= 3 then clicks = 0; DS.ShowThanks() end
    end)
    main.logoBtn = logoBtn

    -- one line for problems / updates; clickable when it points somewhere
    local nb = CreateFrame("Button", nil, main)
    nb:SetWidth(400); nb:SetHeight(14)
    nb:SetPoint("TOPRIGHT", -48, -46)
    nb.text = nb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    nb.text:SetAllPoints()
    nb.text:SetJustifyH("RIGHT")
    nb:SetScript("OnClick", function(self)
        if self.kind == "update" then DS.ShowLinks() end
    end)
    main.notice = nb

    local close = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() DS.Close() end)

    profileBtn = DS.UI.Button(main, "", 230, 22)
    profileBtn:SetPoint("TOPRIGHT", -40, -14)
    main.profileBtn = profileBtn
    profileBtn:SetScript("OnClick", function(self) DS.ShowProfileMenu() end)
    profileBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Settings profile", 1, 0.82, 0)
        local name, own = DS.CurrentProfile()
        GameTooltip:AddLine("Using " .. DS.ProfileDisplay(name) .. "'s profile" .. (own and " (this character)" or ""), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Click to switch or save", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    profileBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- header and footer rules close off the two fixed sections
    DS.UI.Divider(main, 68, 24)
    DS.UI.Divider(main, 44, 24, true)

    -- the version is a button: it opens the change log. 
    local verBtn = CreateFrame("Button", nil, main)
    verBtn:SetPoint("BOTTOMLEFT", 26, 18)
    local verText = verBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("LEFT", verBtn, "LEFT", 0, 0)
    verText:SetText("Version " .. DS.VERSION)
    local vw = verText:GetStringWidth()
    if not vw or vw < 10 then vw = 90 end
    verBtn:SetWidth(vw); verBtn:SetHeight(16)
    local function Tint(r, g, b)
        verText:SetTextColor(r, g, b)
    end
    verBtn:SetScript("OnEnter", function(self)
        Tint(1, 0.82, 0)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to see what changed")
        GameTooltip:Show()
    end)
    verBtn:SetScript("OnLeave", function() Tint(0.55, 0.55, 0.55); GameTooltip:Hide() end)
    verBtn:SetScript("OnClick", function()
        if changelog and changelog:IsShown() then DS.HideChangelog() else DS.ShowChangelog() end
    end)
    main.verBtn = verBtn
    local foot = main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("LEFT", verBtn, "RIGHT", 0, 0)
    foot:SetText("  -  /ds minimap hides the minimap button")

    -- home view
    home = CreateFrame("Frame", nil, main)
    home:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    home:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    for i, m in ipairs(DS.modules) do BuildCell(i, m) end
    local hint = home:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -28, 20)
    hint:SetText("Click: settings   Right-click: enable / disable")

    -- detail view (a module's settings)
    detail = CreateFrame("Frame", nil, main)
    detail:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)

    local back = DS.UI.Button(detail, "Back", 86, 24)
    back:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -26, 16)
    back:SetScript("OnClick", function() DS.CloseDetail() end)

    detail.body = CreateFrame("Frame", nil, detail)
    detail.body:SetPoint("TOPLEFT", detail, "TOPLEFT", 26, -78)
    detail.body:SetWidth(WIN_W - 52); detail.body:SetHeight(420)

    -- keep the controls honest if a setting changes elsewhere (slash command, macro ...)
    local poll, acc = CreateFrame("Frame", nil, detail), 0
    poll:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 0.5 then acc = 0; DS.RefreshOptions() end
    end)

    main:SetScript("OnShow", function()
        ResetViews()
        DS.RefreshAll()
    end)
    main:SetScript("OnHide", function()
        escProxy:Hide()
        ResetViews()
        if links then links:Hide() end
        if DropDownList1 then CloseDropDownMenus() end
    end)
    ResetViews()
    DS.RefreshAll()
    -- new frames are born shown: hide it so the first click opens it instead of closing it
    main:Hide()
end

-- the window fades in and out
local WINDOW_FADE = 0.18

function DS.Show()
    if not main then BuildMain() end
    closing = false
    escProxy:Show()
    DS.UI.Fade(main, main:IsShown() and main:GetAlpha() or 0, 1, WINDOW_FADE)
end

function DS.Close()
    if not main or not main:IsShown() or closing then return end
    closing = true
    escProxy:Hide()
    DS.UI.Fade(main, main:GetAlpha(), 0, WINDOW_FADE, function() closing = false end)
end

function DS.Toggle()
    if not main then BuildMain() end
    if main:IsShown() and not closing then DS.Close() else DS.Show() end
end

-- Opens the hub straight on a module's settings (used by slash commands such as /fadeout);
-- calling it again while those settings are showing closes the hub.
function DS.OpenSettings(m)
    if not (m.active and DS.HasSettings(m)) then return end
    if not main then BuildMain() end
    if main:IsShown() and not closing and detail.module == m and detail:IsShown() then
        DS.Close()
        return
    end
    if not main:IsShown() or closing then DS.Show() end
    DS.OpenDetail(m)
end
