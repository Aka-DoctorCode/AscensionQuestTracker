-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: AchievementProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local achievementData = {}
addonTable.dataEngine:registerModule("AchievementData", achievementData)

achievementData.activeAchievements = {}

function achievementData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
    self.eventFrame:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
    self.eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    self.eventFrame:RegisterEvent("CRITERIA_UPDATE")
    if C_ContentTracking then
        pcall(function() self.eventFrame:RegisterEvent("CONTENT_TRACKING_LIST_CHANGED") end)
        pcall(function() self.eventFrame:RegisterEvent("CONTENT_TRACKING_UPDATE") end)
    end
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function achievementData:update()
    wipe(self.activeAchievements)

    if not C_ContentTracking or not C_ContentTracking.GetTrackedIDs then return end
    if not Enum.ContentTrackingType or not Enum.ContentTrackingType.Achievement then return end

    local trackedIDs = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
    if not trackedIDs then return end

    for _, achievementID in ipairs(trackedIDs) do
        self:parseAchievement(achievementID)
    end
end


function achievementData:parseAchievement(achievementID)
    local _, name, _, completed, _, _, _, description = GetAchievementInfo(achievementID)
    
    local numCriteria = GetAchievementNumCriteria(achievementID)
    local criteriaList = {}

    for i = 1, numCriteria do
        local criteriaString, criteriaType, completedCrit, quantity, reqQuantity = GetAchievementCriteriaInfo(achievementID, i)
        table.insert(criteriaList, {
            name = criteriaString,
            completed = completedCrit,
            quantity = quantity,
            reqQuantity = reqQuantity,
            type = criteriaType
        })
    end

    table.insert(self.activeAchievements, {
        id = achievementID,
        name = name,
        description = description,
        completed = completed,
        criteria = criteriaList
    })
end
