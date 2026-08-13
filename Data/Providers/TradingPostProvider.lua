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
    self.eventFrame:RegisterEvent("PERKS_ACTIVITIES_TRACKED_UPDATED")
    self.eventFrame:RegisterEvent("PERKS_ACTIVITY_COMPLETED")
    self.eventFrame:RegisterEvent("PERKS_PROGRAM_DATA_REFRESH")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function tradingPostData:update()
    wipe(self.activeActivities)

    if C_PerksActivities and C_PerksActivities.GetMonthlyPlayerEarnedTender then
        self.monthlyTender = C_PerksActivities.GetMonthlyPlayerEarnedTender() or 0
    else
        self.monthlyTender = 0
    end

    local trackedList = nil
    if C_PerksActivities then
        if C_PerksActivities.GetTrackedActivities then
            trackedList = C_PerksActivities.GetTrackedActivities()
        elseif C_PerksActivities.GetTrackedPerksActivities then
            trackedList = C_PerksActivities.GetTrackedPerksActivities()
        end
    end

    if type(trackedList) == "table" and trackedList.trackedIDs then
        trackedList = trackedList.trackedIDs
    end

    if not trackedList or type(trackedList) ~= "table" then return end

    for _, activityId in ipairs(trackedList) do
        if type(activityId) == "number" and activityId > 0 then
            local activityInfo = nil
            if C_PerksActivities.GetActivityInfo then
                activityInfo = C_PerksActivities.GetActivityInfo(activityId)
            elseif C_PerksActivities.GetPerksActivityInfo then
                activityInfo = C_PerksActivities.GetPerksActivityInfo(activityId)
            end

            if activityInfo then
                local requirementList = {}
                if activityInfo.requirementsList and type(activityInfo.requirementsList) == "table" and #activityInfo.requirementsList > 0 then
                    for _, requirementInfo in ipairs(activityInfo.requirementsList) do
                        if requirementInfo and requirementInfo.requirementText and requirementInfo.requirementText ~= "" then
                            table.insert(requirementList, {
                                text = requirementInfo.requirementText,
                                finished = requirementInfo.completed or false
                            })
                        end
                    end
                end

                table.insert(self.activeActivities, {
                    id = activityId,
                    title = activityInfo.activityName or ("Activity " .. tostring(activityId)),
                    progress = activityInfo.completedCriteriaCount or 0,
                    threshold = activityInfo.threshold or 0,
                    completed = activityInfo.completed or false,
                    requirements = requirementList
                })
            end
        end
    end
end

