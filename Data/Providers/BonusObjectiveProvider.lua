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

local function getZoneMapId(mapId)
    local currentMapId = mapId
    local mapInfo = C_Map.GetMapInfo(currentMapId)
    
    while mapInfo and mapInfo.mapType and mapInfo.mapType > Enum.UIMapType.Zone do
        currentMapId = mapInfo.parentMapID
        mapInfo = C_Map.GetMapInfo(currentMapId)
    end
    
    return currentMapId or mapId
end

local function fetchMapTasks(uiMapId)
    if C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        return C_TaskQuest.GetQuestsOnMap(uiMapId) or {}
    end
    return {}
end

local function isQuestTracked(questId)
    if not questId then return false end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questId) then return true end
    if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(questId) ~= nil then return true end
    if C_QuestLog.IsQuestWatched and C_QuestLog.IsQuestWatched(questId) then return true end
    return false
end

local function isWorldQuest(questId)
    if C_QuestLog.IsWorldQuest then
        return C_QuestLog.IsWorldQuest(questId)
    end
    return false
end

local function getQuestTitle(questId)
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local title = C_TaskQuest.GetQuestInfoByQuestID(questId)
        if title and title ~= "" then return title end
    end
    local questInfo = C_QuestLog.GetInfo(questId)
    return questInfo and questInfo.title
end

function bonusObjectiveData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("QUEST_ACCEPTED")
    self.eventFrame:RegisterEvent("QUEST_REMOVED")
    self.eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    self.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function bonusObjectiveData:update()
    wipe(self.activeQuests)

    local uiMapId = C_Map.GetBestMapForUnit("player")
    if not uiMapId then return end

    local zoneMapId = getZoneMapId(uiMapId)
    local processedQuests = {}

    local mapIdsToScan = { uiMapId }
    if zoneMapId ~= uiMapId then
        table.insert(mapIdsToScan, zoneMapId)
    end

    for _, mapId in ipairs(mapIdsToScan) do
        local taskPois = fetchMapTasks(mapId)
        for _, poi in ipairs(taskPois) do
            local questId = poi.questId or poi.questID
            if questId and not processedQuests[questId] then
                local isTracked = poi.inProgress or isQuestTracked(questId)
                if isTracked then
                    self:parseBonusObjective(questId)
                    processedQuests[questId] = true
                end
            end
        end
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for logIndex = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(logIndex)
        if questInfo and not questInfo.isHeader then
            local questId = questInfo.questID
            if questId and not processedQuests[questId] and not isWorldQuest(questId) then
                local tagInfo = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questId)
                local isBonusType = (questInfo.questType == Enum.QuestTagType.Bonus or (tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Bonus))
                if isBonusType then
                    self:parseBonusObjective(questId)
                    processedQuests[questId] = true
                end
            end
        end
    end
end

function bonusObjectiveData:parseBonusObjective(questId)
    local isWq = isWorldQuest(questId)
    if isWq then return end

    local taskName = getQuestTitle(questId)

    local objectiveList = {}
    if C_QuestLog.GetQuestObjectives then
        local rawObjectives = C_QuestLog.GetQuestObjectives(questId)
        if rawObjectives and #rawObjectives > 0 then
            for _, objectiveInfo in ipairs(rawObjectives) do
                local objText = objectiveInfo.text or ""
                if objText == "" and C_TaskQuest and C_TaskQuest.GetQuestObjectiveInfo then
                    local taskText = C_TaskQuest.GetQuestObjectiveInfo(questId, #objectiveList + 1, false)
                    if taskText then objText = taskText end
                end
                table.insert(objectiveList, {
                    text = objText,
                    numFulfilled = objectiveInfo.numFulfilled or 0,
                    numRequired = objectiveInfo.numRequired or 0,
                    finished = objectiveInfo.finished or false
                })
            end
        end
    end

    if #objectiveList == 0 and C_TaskQuest and C_TaskQuest.GetQuestObjectiveInfo then
        local objIndex = 1
        while objIndex <= 10 do
            local text, finished, numFulfilled, numRequired = C_TaskQuest.GetQuestObjectiveInfo(questId, objIndex, false)
            if not text or text == "" then break end
            table.insert(objectiveList, {
                text = text,
                numFulfilled = numFulfilled or 0,
                numRequired = numRequired or 0,
                finished = finished or false
            })
            objIndex = objIndex + 1
        end
    end

    local lowerName = string.lower(taskName or "")
    local isGenericName = (taskName == nil or taskName == "" 
        or lowerName == "bonus objective" 
        or lowerName == "objetivo adicional"
        or lowerName == "bonus objective:" 
        or string.find(lowerName, "^bonus objective")
        or string.find(lowerName, "^objetivo adicional"))

    if isGenericName and #objectiveList > 0 and objectiveList[1].text and objectiveList[1].text ~= "" then
        taskName = objectiveList[1].text
    elseif isGenericName and (not taskName or taskName == "") then
        taskName = "Bonus Objective"
    end

    if C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questId)
        if tagInfo and tagInfo.tagName and tagInfo.tagName ~= "" 
           and tagInfo.tagName ~= "Bonus Objective" 
           and tagInfo.tagName ~= "Objetivo adicional" then
            if not string.find(taskName, "%[" .. tagInfo.tagName .. "%]") then
                taskName = "[" .. tagInfo.tagName .. "] " .. taskName
            end
        end
    end

    table.insert(self.activeQuests, {
        id = questId,
        title = taskName,
        objectives = objectiveList
    })
end
