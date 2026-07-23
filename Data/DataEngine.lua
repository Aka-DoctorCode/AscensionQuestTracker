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
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "SCENARIO_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "SCENARIO_BONUS_VISIBILITY_CHANGED",
        "UPDATE_UI_WIDGET",
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
        "BAG_UPDATE_DELAYED",
        "SUPER_TRACKING_CHANGED"
    }

    for _, eventName in ipairs(eventsToRegister) do
        self.masterFrame:RegisterEvent(eventName)
    end

    self.masterFrame:SetScript("OnEvent", function(_, eventName, ...)
        self:handleEvent(eventName, ...)
    end)
end

function dataEngine:handleEvent(eventName, ...)
    if eventName == "PLAYER_ENTERING_WORLD" then
        self:updateAll()
    else
        self:queueUpdate()
    end
end

-- C_Timer debounce replaces OnUpdate polling for optimal CPU usage
function dataEngine:queueUpdate()
    if not self.isUpdateQueued then
        self.isUpdateQueued = true
        C_Timer.After(0.05, function()
            self:updateAll()
            self.isUpdateQueued = false
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
    for _, moduleInstance in pairs(self.modules) do
        if moduleInstance and moduleInstance.update then
            pcall(moduleInstance.update, moduleInstance)
        end
    end

    if addonTable.uiEngine and addonTable.uiEngine.render then
        pcall(addonTable.uiEngine.render, addonTable.uiEngine)
    end
end
