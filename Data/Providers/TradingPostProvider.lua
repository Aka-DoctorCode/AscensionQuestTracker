-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: TradingPostProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local tradingPostData = {}
addonTable.dataEngine:registerModule("TradingPostData", tradingPostData)

tradingPostData.activeActivities = {}
tradingPostData.monthlyTender = 0

function tradingPostData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PERKS_ACTIVITIES_UPDATED")
    self.eventFrame:RegisterEvent("PERKS_ACTIVITY_COMPLETED")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function tradingPostData:update()
    wipe(self.activeActivities)

    if C_PerksActivities.GetMonthlyPlayerEarnedTender then
        self.monthlyTender = C_PerksActivities.GetMonthlyPlayerEarnedTender()
    else
        self.monthlyTender = 0
    end

    if self.monthlyTender >= 1000 then
        -- Cap reached, hide
        return
    end

    local tracked = nil
    if C_PerksActivities.GetTrackedActivities then
        tracked = C_PerksActivities.GetTrackedActivities()
    elseif C_PerksActivities.GetTrackedPerksActivities then
        tracked = C_PerksActivities.GetTrackedPerksActivities()
    end
    
    if not tracked then return end

    for _, activityID in ipairs(tracked) do
        local info = nil
        if C_PerksActivities.GetActivityInfo then
            info = C_PerksActivities.GetActivityInfo(activityID)
        elseif C_PerksActivities.GetPerksActivityInfo then
            info = C_PerksActivities.GetPerksActivityInfo(activityID)
        end
        if info then
            table.insert(self.activeActivities, {
                id = activityID,
                title = info.activityName,
                progress = info.completedCriteriaCount,
                threshold = info.threshold,
                completed = info.completed
            })
        end
    end
end
