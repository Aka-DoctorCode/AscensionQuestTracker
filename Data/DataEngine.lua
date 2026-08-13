-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: DataEngine.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

addonTable.dataEngine = {}
local dataEngine = addonTable.dataEngine

dataEngine.modules = {}
dataEngine.isUpdateQueued = false

function dataEngine:init()
    self:initModules()
    self.masterFrame = CreateFrame("Frame")

    local eventsToRegister = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "QUEST_WATCH_UPDATE",
        "QUEST_WATCH_OBJECTIVES_CHANGED",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
        "QUEST_AUTOCOMPLETE",
        "QUEST_POI_UPDATE",
        "QUEST_DATA_LOAD_RESULT",
        "UNIT_QUEST_LOG_CHANGED",
        "SCENARIO_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "SCENARIO_STEP_UPDATE",
        "SCENARIO_COMPLETED",
        "SCENARIO_BONUS_VISIBILITY_CHANGED",
        "TRACKED_ACHIEVEMENT_UPDATE",
        "TRACKED_ACHIEVEMENT_LIST_CHANGED",
        "ACHIEVEMENT_EARNED",
        "CRITERIA_UPDATE",
        "CRITERIA_EARNED",
        "UPDATE_UI_WIDGET",
        "MAW_ANIMA_POWER_GAINED",
        "MAW_ANIMA_POWER_LIST_TOGGLED",
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
        "BAG_UPDATE_DELAYED",
        "SUPER_TRACKING_CHANGED",
        "ZONE_CHANGED",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED_INDOORS",
        "MINIMAP_ZONE_CHANGED",
        "PERKS_ACTIVITIES_UPDATED",
        "PERKS_ACTIVITIES_TRACKED_UPDATED",
        "PERKS_ACTIVITY_COMPLETED",
        "PERKS_PROGRAM_DATA_REFRESH",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED"
    }

    for _, eventName in ipairs(eventsToRegister) do
        pcall(function() self.masterFrame:RegisterEvent(eventName) end)
    end

    self.masterFrame:SetScript("OnEvent", function(_, eventName, ...)
        self:handleEvent(eventName, ...)
    end)
end

function dataEngine:handleEvent(eventName, ...)
    if eventName == "PLAYER_REGEN_DISABLED" then
        self.inCombat = true
        return
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        self.inCombat = false
        if self.pendingUpdate then
            self.pendingUpdate = false
            self:updateAll()
        end
        return
    end

    if eventName == "PLAYER_ENTERING_WORLD" then
        self:updateAll()
    else
        self:queueUpdate()
        if eventName == "QUEST_TURNED_IN" or eventName == "QUEST_REMOVED" or eventName == "QUEST_AUTOCOMPLETE" or eventName == "SCENARIO_UPDATE" or eventName == "SCENARIO_COMPLETED" or string.match(eventName, "^ZONE_CHANGED") or eventName == "MINIMAP_ZONE_CHANGED" then
            C_Timer.After(0.1, function()
                self:updateAll()
            end)
            C_Timer.After(0.3, function()
                self:updateAll()
            end)
            C_Timer.After(1.0, function()
                self:updateAll()
            end)
        end
    end
end

function dataEngine:queueUpdate()
    if not self.isUpdateQueued then
        self.isUpdateQueued = true
        C_Timer.After(0.05, function()
            self.isUpdateQueued = false
            self:updateAll()
        end)
    end
end

function dataEngine:registerModule(moduleName, moduleInstance)
    self.modules[moduleName] = moduleInstance
end

function dataEngine:initModules()
    for _, moduleInstance in pairs(self.modules) do
        if moduleInstance.init then
            moduleInstance:init()
        end
    end
end

function dataEngine:updateAll()
    if self.inCombat then
        self.pendingUpdate = true
        return
    end

    for _, moduleInstance in pairs(self.modules) do
        if moduleInstance and moduleInstance.update then
            pcall(moduleInstance.update, moduleInstance)
        end
    end

    if addonTable.uiEngine and addonTable.uiEngine.render then
        pcall(addonTable.uiEngine.render, addonTable.uiEngine)
    end
end
