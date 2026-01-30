--------------------------------------------------------------------------------
-- CONFIGURATION MODULE
--------------------------------------------------------------------------------
local addonName, addonTable = ...

-- 1. Default Settings
local defaults = {
    position = { point = "RIGHT", relativePoint = "RIGHT", x = -50, y = 0 },
    scale = 1.0,
    hideOnBoss = true,
    width = 260,
    locked = false
}

-- 2. Database Handling (SavedVariables)
function addonTable.LoadDatabase()
    -- Create DB if it doesn't exist
    if not AscensionQuestTrackerDB then
        AscensionQuestTrackerDB = {}
    end
    
    -- Populate missing defaults
    for key, value in pairs(defaults) do
        if AscensionQuestTrackerDB[key] == nil then
            AscensionQuestTrackerDB[key] = value
        end
    end
    
    -- Deep copy for position if missing
    if not AscensionQuestTrackerDB.position then
        AscensionQuestTrackerDB.position = defaults.position
    end
end

-- 3. Create Options Panel
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "AscensionQT_OptionsPanel", UIParent)
    panel.name = "Ascension Quest Tracker"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ascension Quest Tracker Settings")
    
    -- CHECKBOX: Hide on Boss
    local cbHide = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbHide:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    cbHide.Text:SetText("Hide Quests during Boss Encounters")
    cbHide:SetChecked(AscensionQuestTrackerDB.hideOnBoss)
    cbHide:SetScript("OnClick", function(self)
        AscensionQuestTrackerDB.hideOnBoss = self:GetChecked()
        -- Trigger update in main addon
        if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
            AscensionQuestTrackerFrame:FullUpdate()
        end
    end)
    
    -- CHECKBOX: Lock Tracker
    local cbLock = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbLock:SetPoint("TOPLEFT", cbHide, "BOTTOMLEFT", 0, -10)
    cbLock.Text:SetText("Lock Position")
    cbLock:SetChecked(AscensionQuestTrackerDB.locked)
    cbLock:SetScript("OnClick", function(self)
        AscensionQuestTrackerDB.locked = self:GetChecked()
        if AscensionQuestTrackerFrame then
            AscensionQuestTrackerFrame:EnableMouse(not AscensionQuestTrackerDB.locked)
        end
    end)

    -- SLIDER: Scale
    local sliderScale = CreateFrame("Slider", "AscensionQT_ScaleSlider", panel, "OptionsSliderTemplate")
    sliderScale:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -30)
    sliderScale:SetMinMaxValues(0.5, 2.0)
    sliderScale:SetValue(AscensionQuestTrackerDB.scale or 1.0)
    sliderScale:SetValueStep(0.1)
    sliderScale:SetObeyStepOnDrag(true)
    
    _G[sliderScale:GetName() .. "Low"]:SetText("0.5")
    _G[sliderScale:GetName() .. "High"]:SetText("2.0")
    _G[sliderScale:GetName() .. "Text"]:SetText("Tracker Scale: " .. (AscensionQuestTrackerDB.scale or 1.0))
    
    sliderScale:SetScript("OnValueChanged", function(self, value)
        -- Round to 1 decimal
        local val = math.floor(value * 10 + 0.5) / 10
        AscensionQuestTrackerDB.scale = val
        _G[self:GetName() .. "Text"]:SetText("Tracker Scale: " .. val)
        
        if AscensionQuestTrackerFrame then
            AscensionQuestTrackerFrame:SetScale(val)
        end
    end)

    -- DESCRIPTION / HELP
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", sliderScale, "BOTTOMLEFT", 0, -20)
    desc:SetText("Note: To move the tracker, ensure 'Lock Position' is unchecked.\nDrag the tracker with Left Click.")
    
    -- Register to WoW Settings (Modern API support)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Ascension QT")
        Settings.RegisterAddOnCategory(category)
    else
        -- Fallback for older clients
        InterfaceOptions_AddCategory(panel)
    end
end

-- Initialize Config on Login
local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("PLAYER_LOGIN")
configLoader:SetScript("OnEvent", function()
    addonTable.LoadDatabase()
    CreateOptionsPanel()
end)