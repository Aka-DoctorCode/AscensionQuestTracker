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
    self.eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
    self.eventFrame:RegisterEvent("QUEST_TURNED_IN")
    self.eventFrame:RegisterEvent("QUEST_REMOVED")
    self.eventFrame:RegisterEvent("QUEST_ACCEPTED")
    self.eventFrame:RegisterEvent("QUEST_AUTOCOMPLETE")
    self.eventFrame:SetScript("OnEvent", function(_, eventName)
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
            if eventName == "QUEST_TURNED_IN" or eventName == "QUEST_REMOVED" or eventName == "QUEST_AUTOCOMPLETE" then
                C_Timer.After(0.15, function()
                    if addonTable.dataEngine then
                        addonTable.dataEngine:queueUpdate()
                    end
                end)
                C_Timer.After(0.4, function()
                    if addonTable.dataEngine then
                        addonTable.dataEngine:queueUpdate()
                    end
                end)
            end
        end
    end)
end

function questData:update()
    wipe(self.activeQuests)

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for logIndex = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(logIndex)
        if questInfo and not questInfo.isHeader then
            local questId = questInfo.questID
            if questId and not C_QuestLog.IsWorldQuest(questId) then
                local isFlaggedComplete = C_QuestLog.IsQuestFlaggedCompleted(questId)
                if not isFlaggedComplete then
                    local watchType = C_QuestLog.GetQuestWatchType(questId)
                    if watchType ~= nil then
                        self:parseQuest(questId, logIndex)
                    end
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

    local objectives, itemLink, itemIcon, spellID, spellName, spellTexture, spellFinished
    if not isComplete then
        objectives = C_QuestLog.GetQuestObjectives(questID)

        -- GetQuestLogSpecialItemInfo requires the log index (not watch index)
        itemLink, itemIcon = GetQuestLogSpecialItemInfo(logIndex)

        if GetQuestLogCriteriaSpell then
            local oldSelection = C_QuestLog.GetSelectedQuest()
            C_QuestLog.SetSelectedQuest(questID)
            spellID, spellName, spellTexture, spellFinished = GetQuestLogCriteriaSpell()
            if oldSelection then
                C_QuestLog.SetSelectedQuest(oldSelection)
            end
        end
    end

    local campaignID   = info.campaignID
    local campaignInfo = nil
    if campaignID and campaignID > 0 then
        campaignInfo = C_CampaignInfo.GetCampaignInfo(campaignID)
    end

    local isCampaign = (campaignID and campaignID > 0) or info.isStory or false

    local distanceSq = 999999999
    if C_QuestLog.GetDistanceSqToQuest then
        local dSq = C_QuestLog.GetDistanceSqToQuest(questID)
        if dSq then distanceSq = dSq end
    end

    local isLocal = info.isOnMap or false
    
    local distanceSq, onCont
    if C_QuestLog.GetDistanceSqToQuest then
        distanceSq, onCont = C_QuestLog.GetDistanceSqToQuest(questID)
    end

    if not isLocal then
        local uiMapID = C_Map.GetBestMapForUnit("player")
        if uiMapID then
            local questsOnMap = C_QuestLog.GetQuestsOnMap(uiMapID)
            if questsOnMap then
                for _, qInfo in ipairs(questsOnMap) do
                    local qID = type(qInfo) == "table" and qInfo.questID or qInfo
                    if qID == questID then
                        isLocal = true
                        break
                    end
                end
            end
        end
    end
    
    -- Weekly quests should not be moved to Local Quests, keep them in their original category
    if info.frequency == Enum.QuestFrequency.Weekly or info.frequency == 2 then
        isLocal = false
    end

    local isOnMap = info.isOnMap or false

    table.insert(self.activeQuests, {
        id           = questID,
        title        = info.title,
        level        = info.level,
        isBounty     = info.isBounty,
        isStory      = info.isStory,
        isCampaign   = isCampaign,
        isOnMap      = isOnMap,
        isLocal      = isLocal,
        isComplete   = isComplete,
        isFailed     = isFailed,
        objectives   = objectives,
        itemIcon     = itemIcon,
        itemLink     = itemLink,
        spellID      = spellID,
        spellTexture = spellTexture,
        distanceSq   = distanceSq,
        campaignInfo = campaignInfo
    })
    
    table.sort(self.activeQuests, function(a, b)
        if a.isOnMap ~= b.isOnMap then
            return a.isOnMap == true
        end
        local distA = a.distanceSq or 99999999
        local distB = b.distanceSq or 99999999
        if distA ~= distB then
            return distA < distB
        end
        return a.id < b.id
    end)
end
