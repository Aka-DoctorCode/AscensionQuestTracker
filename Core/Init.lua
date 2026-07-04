-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: Init.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

addonTable.ascensionTracker = {}
local ascensionTracker = addonTable.ascensionTracker

function ascensionTracker:init()
    addonTable.config:init()
    if addonTable.config.db.profile.automation.hideNativeTracker then
        self:disableNativeTracker()
    end
    self:createContainer()
    self:setupEditMode()
    addonTable.dataEngine:init()
    if addonTable.uiEngine and addonTable.uiEngine.init then
        addonTable.uiEngine:init()
        addonTable.dataEngine:updateAll()
    end
    self:updateBackground()
end

function ascensionTracker:disableNativeTracker()
    ObjectiveTrackerFrame:UnregisterAllEvents()
    ObjectiveTrackerFrame:Hide()
    ObjectiveTrackerFrame:HookScript("OnShow", function(frame) frame:Hide() end)

    local subTrackers = {
        AchievementObjectiveTracker,
        BonusObjectiveTracker,
        CampaignQuestObjectiveTracker,
        MonthlyActivitiesObjectiveTracker,
        ProfessionsRecipeTracker,
        QuestObjectiveTracker,
        ScenarioObjectiveTracker,
        UIWidgetObjectiveTracker,
        WorldQuestObjectiveTracker
    }

    for _, tracker in ipairs(subTrackers) do
        if tracker then
            tracker:UnregisterAllEvents()
            tracker:Hide()
            tracker:HookScript("OnShow", function(frame) frame:Hide() end)
        end
    end
end

function ascensionTracker:createContainer()
    local dragHandleHeight = 16

    self.masterFrame = CreateFrame("Frame", "AscensionObjectiveTracker", UIParent)
    self.masterFrame:SetFrameStrata("MEDIUM")
    local configMaxWidth = 250
    if AscensionQuestTrackerDB and AscensionQuestTrackerDB.profiles then
        -- fallback to default if AceDB isn't loaded yet
        configMaxWidth = 250
    end
    self.maxHeight = 600
    self.masterFrame:SetSize(configMaxWidth, self.maxHeight)
    self.masterFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -300, -200)
    self.masterFrame:SetClampedToScreen(true)
    self.masterFrame:SetMovable(true)
    self.masterFrame:EnableMouse(true)
    self.masterFrame:RegisterForDrag("LeftButton")
    self.masterFrame:SetScript("OnDragStart", self.masterFrame.StartMoving)
    self.masterFrame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        self:saveAnchorPoint()
    end)
    self.masterFrame:SetScript("OnUpdate", function(f)
        if addonTable.config and addonTable.config.db then
            if not addonTable.config.db.profile.position.showMoveFrame then
                if f:IsMouseOver() then
                    self.dragHandle:SetAlpha(1)
                else
                    self.dragHandle:SetAlpha(0)
                end
            else
                self.dragHandle:SetAlpha(1)
            end
        end
    end)
    self.masterFrame:Show()
    
    self.bgTexture = self.masterFrame:CreateTexture(nil, "BACKGROUND")
    self.bgTexture:SetAllPoints()
    self.bgTexture:SetColorTexture(0, 0, 0, 0)

    -- Drag handle strip at the top — visible to masterFrame mouse handler
    self.dragHandle = self.masterFrame:CreateTexture(nil, "BACKGROUND")
    self.dragHandle:SetPoint("TOPLEFT", self.masterFrame, "TOPLEFT", 0, 0)
    self.dragHandle:SetPoint("TOPRIGHT", self.masterFrame, "TOPRIGHT", 0, 0)
    self.dragHandle:SetHeight(dragHandleHeight)
    self.dragHandle:SetColorTexture(1, 1, 1, 0.08) -- subtle grab area

    -- scrollFrame starts BELOW the drag handle so it does not block mouse events
    self.scrollFrame = CreateFrame("ScrollFrame", "AscensionObjectiveScroll", self.masterFrame)
    self.scrollFrame:SetPoint("TOPLEFT", self.masterFrame, "TOPLEFT", 0, -dragHandleHeight)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self.masterFrame, "BOTTOMRIGHT", 0, 0)
    self.scrollFrame:EnableMouse(false)
    self.scrollFrame:EnableMouseWheel(true)
    self.scrollFrame:SetScript("OnMouseWheel", function(frame, delta)
        local currentScroll = frame:GetVerticalScroll()
        local maxScroll = math.max(0, self.contentFrame:GetHeight() - frame:GetHeight())
        
        local newScroll = currentScroll - (delta * 30)
        if newScroll < 0 then newScroll = 0 end
        if newScroll > maxScroll then newScroll = maxScroll end
        frame:SetVerticalScroll(newScroll)
    end)

    self.contentFrame = CreateFrame("Frame", "AscensionObjectiveContent", self.scrollFrame)
    self.contentFrame:SetSize(250, 10)
    self.scrollFrame:SetScrollChild(self.contentFrame)

    self.editModeOverlay = self.masterFrame:CreateTexture(nil, "OVERLAY")
    self.editModeOverlay:SetAllPoints()
    self.editModeOverlay:SetColorTexture(0, 0.5, 0, 0.5)
    self.editModeOverlay:Hide()

    self.editModeText = self.masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.editModeText:SetPoint("TOP", self.masterFrame, "TOP", 0, -2)
    self.editModeText:SetText("Ascension Tracker")
    self.editModeText:Hide()

    -- Restore saved position if available
    if AscensionQuestTrackerDB and AscensionQuestTrackerDB.anchor then
        local a = AscensionQuestTrackerDB.anchor
        self.masterFrame:ClearAllPoints()
        self.masterFrame:SetPoint(a.point, UIParent, a.relativePoint, a.xOfs, a.yOfs)
    end
end

function ascensionTracker:updateHeight(newHeight)
    local dragHandleHeight = 16
    self.contentFrame:SetHeight(newHeight)
    
    local configMaxHeight = self.maxHeight
    if addonTable.config and addonTable.config.db then
        configMaxHeight = addonTable.config.db.profile.sizing.maxHeight
    end
    
    local desiredMasterHeight = newHeight + dragHandleHeight
    if desiredMasterHeight > configMaxHeight then
        self.masterFrame:SetHeight(configMaxHeight)
    else
        self.masterFrame:SetHeight(desiredMasterHeight)
    end
end

function ascensionTracker:updateWidth(newWidth)
    self.masterFrame:SetWidth(newWidth)
    self.contentFrame:SetWidth(newWidth)
end

function ascensionTracker:updateBackground()
    if addonTable.config and addonTable.config.db then
        local alpha = addonTable.config.db.profile.colors.backgroundAlpha or 0
        self.bgTexture:SetColorTexture(0, 0, 0, alpha)
    end
end

function ascensionTracker:setupEditMode()
    if EditModeManagerFrame and EventRegistry then
        if EditModeManagerFrame.RegisterSystem then
            -- Attempting native edit mode registration
            pcall(function() EditModeManagerFrame:RegisterSystem(self.masterFrame) end)
        end
        EventRegistry:RegisterCallback("EditMode.Enter", self.onEditModeEnter, self)
        EventRegistry:RegisterCallback("EditMode.Exit", self.onEditModeExit, self)
    end
end

function ascensionTracker:onEditModeEnter()
    self.editModeOverlay:Show()
    self.editModeText:Show()
end

function ascensionTracker:onEditModeExit()
    self.editModeOverlay:Hide()
    self.editModeText:Hide()
    self:saveAnchorPoint()
end

function ascensionTracker:saveAnchorPoint()
    local x, y = self.masterFrame:GetCenter()
    if not x or not y then return end

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()

    local point = "CENTER"
    if y > screenHeight / 2 then
        point = "TOP"
    else
        point = "BOTTOM"
    end

    if x > screenWidth / 2 then
        point = point .. "RIGHT"
    else
        point = point .. "LEFT"
    end

    local left = self.masterFrame:GetLeft() or 0
    local right = self.masterFrame:GetRight() or 0
    local top = self.masterFrame:GetTop() or 0
    local bottom = self.masterFrame:GetBottom() or 0

    self.masterFrame:ClearAllPoints()
    if point == "TOPRIGHT" then
        self.masterFrame:SetPoint(point, UIParent, point, right - screenWidth, top - screenHeight)
    elseif point == "TOPLEFT" then
        self.masterFrame:SetPoint(point, UIParent, point, left, top - screenHeight)
    elseif point == "BOTTOMRIGHT" then
        self.masterFrame:SetPoint(point, UIParent, point, right - screenWidth, bottom)
    else
        self.masterFrame:SetPoint(point, UIParent, point, left, bottom)
    end

    if not AscensionQuestTrackerDB then AscensionQuestTrackerDB = {} end
    local pointStr, _, relativePointStr, xOfs, yOfs = self.masterFrame:GetPoint()
    AscensionQuestTrackerDB.anchor = {
        point = pointStr,
        relativePoint = relativePointStr,
        xOfs = xOfs,
        yOfs = yOfs
    }
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ascensionTracker:init()
    end
end)
