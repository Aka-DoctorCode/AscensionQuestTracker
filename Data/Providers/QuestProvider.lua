-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: QuestProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local questData = {}
addonTable.dataEngine:registerModule("QuestData", questData)

questData.activeQuests = {}

function questData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    self.eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function questData:update()
    wipe(self.activeQuests)

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for logIndex = 1, numEntries do
        local info = C_QuestLog.GetInfo(logIndex)
        if info and not info.isHeader then
            local questID = info.questID
            if not C_QuestLog.IsWorldQuest(questID) then
                -- Only include quests that are actively watched/tracked
                local watchType = C_QuestLog.GetQuestWatchType(questID)
                if watchType ~= nil then
                    self:parseQuest(questID, logIndex)
                end
            end
        end
    end
end

function questData:parseQuest(questID, logIndex)
    local info = C_QuestLog.GetInfo(logIndex)
    if not info then return end

    local isComplete = C_QuestLog.IsComplete(questID)
    local isFailed   = C_QuestLog.IsFailed(questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)

    -- GetQuestLogSpecialItemInfo requires the log index (not watch index)
    local itemLink, itemIcon = GetQuestLogSpecialItemInfo(logIndex)

    local campaignID   = info.campaignID
    local campaignInfo = nil
    if campaignID and campaignID > 0 then
        campaignInfo = C_CampaignInfo.GetCampaignInfo(campaignID)
    end

    local distanceSq = 0
    if C_QuestLog.GetDistanceSqToQuest then
        distanceSq = C_QuestLog.GetDistanceSqToQuest(questID) or 0
    end

    table.insert(self.activeQuests, {
        id           = questID,
        title        = info.title,
        level        = info.level,
        isBounty     = info.isBounty,
        isStory      = info.isStory,
        isComplete   = isComplete,
        isFailed     = isFailed,
        objectives   = objectives,
        itemIcon     = itemIcon,
        itemLink     = itemLink,
        distanceSq   = distanceSq,
        campaignInfo = campaignInfo
    })
end
