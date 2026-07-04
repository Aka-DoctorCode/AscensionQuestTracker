-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: BonusObjectiveProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local bonusObjectiveData = {}
addonTable.dataEngine:registerModule("BonusObjectiveData", bonusObjectiveData)

bonusObjectiveData.activeQuests = {}

local function getZoneMapID(mapID)
    local currentMapID = mapID
    local mapInfo = C_Map.GetMapInfo(currentMapID)
    
    while mapInfo and mapInfo.mapType and mapInfo.mapType > Enum.UIMapType.Zone do
        currentMapID = mapInfo.parentMapID
        mapInfo = C_Map.GetMapInfo(currentMapID)
    end
    
    return currentMapID or mapID
end

local function fetchMapTasks(uiMapID)
    if C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        return C_TaskQuest.GetQuestsOnMap(uiMapID) or {}
    end
    return {}
end

local function isQuestTracked(qID)
    if not qID then return false end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(qID) then return true end
    if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(qID) ~= nil then return true end
    if C_QuestLog.IsQuestWatched and C_QuestLog.IsQuestWatched(qID) then return true end
    return false
end

local function isWorldQuest(questID)
    if C_QuestLog.IsWorldQuest then
        return C_QuestLog.IsWorldQuest(questID)
    end
    return false
end

local function getQuestTitle(questID)
    if C_TaskQuest.GetQuestInfoByQuestID then
        return C_TaskQuest.GetQuestInfoByQuestID(questID)
    end
    local info = C_QuestLog.GetInfo(questID)
    return info and info.title
end

function bonusObjectiveData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("QUEST_ACCEPTED")
    self.eventFrame:RegisterEvent("QUEST_REMOVED")
    self.eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function bonusObjectiveData:update()
    wipe(self.activeQuests)

    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return end

    local zoneMapID = getZoneMapID(uiMapID)
    local processedQuests = {}

    local taskPOIs = fetchMapTasks(zoneMapID)
    for _, poi in ipairs(taskPOIs) do
        local qID = poi.questId or poi.questID
        local tracked = poi.inProgress or isQuestTracked(qID)
        if qID and tracked then
            self:parseBonusObjective(qID)
            processedQuests[qID] = true
        end
    end
end

function bonusObjectiveData:parseBonusObjective(questID)
    local isWQ = isWorldQuest(questID)
    if isWQ then return end -- World Quests are handled in WorldQuestProvider

    local taskName = getQuestTitle(questID)
    if not taskName then
        return -- Hide bonus objectives if not completely loaded
    end
    
    if C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo and tagInfo.tagName and tagInfo.tagName ~= "" and tagInfo.tagName ~= "Bonus Objective" then
            taskName = "[" .. tagInfo.tagName .. "] " .. taskName
        end
    end
        
    -- Pull objectives
    local objectives = {}
    if C_QuestLog.GetQuestObjectives then
        local objs = C_QuestLog.GetQuestObjectives(questID)
        if objs then
            for _, obj in ipairs(objs) do
                table.insert(objectives, {
                    text = obj.text,
                    numFulfilled = obj.numFulfilled,
                    numRequired = obj.numRequired,
                    finished = obj.finished
                })
            end
        end
    end

    table.insert(self.activeQuests, {
        id = questID,
        title = taskName,
        objectives = objectives
    })
end
