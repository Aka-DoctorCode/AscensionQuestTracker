-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: AutoQuestProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local autoQuestData = {}
addonTable.dataEngine:registerModule("AutoQuestData", autoQuestData)

autoQuestData.pendingPopups = {}
autoQuestData.activePopups  = {}

function autoQuestData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:SetScript("OnEvent", function(_, event) self:onEvent(event) end)
end

function autoQuestData:onEvent(event)
    if event == "QUEST_LOG_UPDATE" then
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:processPending()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end
end

function autoQuestData:update()
    wipe(self.activePopups)

    local numPopups = GetNumAutoQuestPopUps()
    for i = 1, numPopups do
        local questID, popupType = GetAutoQuestPopUp(i)
        if questID then
            if InCombatLockdown() then
                table.insert(self.pendingPopups, { id = questID, popupType = popupType })
            else
                table.insert(self.activePopups, { id = questID, popupType = popupType })
            end
        end
    end
end

function autoQuestData:processPending()
    for _, popup in ipairs(self.pendingPopups) do
        table.insert(self.activePopups, popup)
    end
    wipe(self.pendingPopups)
end
