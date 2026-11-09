------------------------------------------------------------
-- DreamSuite - Minimap button (draggable around the minimap)
------------------------------------------------------------
local DS = DreamSuite
local C = DS.C
local button

local function Place()
    local a = math.rad(DreamSuiteDB.minimap.angle)
    local x, y = math.cos(a), math.sin(a)
    local r = Minimap:GetWidth() / 2 + 10
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        x = math.max(-1, math.min(1, x * 1.414))
        y = math.max(-1, math.min(1, y * 1.414))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    px, py = px / s, py / s
    DreamSuiteDB.minimap.angle = math.deg(math.atan2(py - my, px - mx))
    Place()
end

function DS.UpdateMinimapVisibility()
    if not button then return end
    if DreamSuiteDB.minimap.hide then button:Hide() else button:Show() end
end

-- orange dot on the button while a newer DreamSuite is known, red while old addons conflict
function DS.UpdateMinimap()
    if not button then return end
    if #DS.legacyFound > 0 then
        button.badge:SetVertexColor(1, 0.25, 0.25); button.badge:Show()
    elseif DS.UpdateAvailable() then
        button.badge:SetVertexColor(1, 0.5, 0.04); button.badge:Show()
    else
        button.badge:Hide()
    end
end

-- right-click: shortcuts to the modules that are on, plus the go-to extras modules list in `quick`
local menuFrame
local function ShowMenu()
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "DreamSuiteMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = {
        { text = "DreamSuite", isTitle = true, notCheckable = true },
        { text = "Open DreamSuite", notCheckable = true, func = function() DS.Show() end },
    }
    for _, m in ipairs(DS.modules) do
        if m.active and DS.HasSettings(m) then
            tinsert(menu, { text = m.title .. " settings", notCheckable = true,
                            func = function() DS.OpenSettings(m) end })
            for _, q in ipairs(m.quick or {}) do
                tinsert(menu, { text = m.title .. ": " .. q.text, notCheckable = true,
                                func = function() q.func() end })
            end
        end
    end
    tinsert(menu, { text = "Setup wizard", notCheckable = true, func = function() DS.ShowWizard() end })
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
end

function DS.CreateMinimapButton()
    if button then return end
    button = CreateFrame("Button", "DreamSuiteMinimapButton", Minimap)
    button:SetWidth(31); button:SetHeight(31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetWidth(20); bg:SetHeight(20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 5, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetTexture(DS.ICONS .. "Hub.tga")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 5, -5)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53); border:SetHeight(53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    button.badge = button:CreateTexture(nil, "OVERLAY")
    button.badge:SetTexture(DS.ICONS .. "dot.tga")
    button.badge:SetWidth(12); button.badge:SetHeight(12)
    button.badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.badge:Hide()

    button:SetScript("OnClick", function(self, btn)
        GameTooltip:Hide()
        if btn == "RightButton" then ShowMenu() else DS.Toggle() end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:LockHighlight()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("DreamSuite", 1, 0.82, 0)
        local n = 0
        for _, m in ipairs(DS.modules) do
            if m.active then n = n + 1 end
        end
        GameTooltip:AddLine(n .. " of " .. #DS.modules .. " modules enabled", 0.8, 0.8, 0.8)
        if #DS.legacyFound > 0 then
            GameTooltip:AddLine("Old standalone addons found - type /ds legacy", 1, 0.4, 0.4)
        elseif DS.UpdateAvailable() then
            GameTooltip:AddLine("A newer DreamSuite exists", 1, 0.5, 0.04)
        end
        GameTooltip:AddLine("Click to open - right-click for shortcuts - drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Place()
    DS.UpdateMinimapVisibility()
    DS.UpdateMinimap()
end
