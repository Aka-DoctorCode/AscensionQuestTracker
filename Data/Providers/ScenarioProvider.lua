-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: ScenarioProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local scenarioData = {}
addonTable.dataEngine:registerModule("ScenarioData", scenarioData)

scenarioData.state = {}

function scenarioData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("SCENARIO_UPDATE")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function scenarioData:update()
    wipe(self.state)

    local scenarioInfo = C_Scenario.GetInfo()
    if type(scenarioInfo) == "table" then
        if not scenarioInfo.name then return end
        self.state.name = scenarioInfo.name
        self.state.currentStage = scenarioInfo.currentStage
        self.state.numStages = scenarioInfo.numStages
    else
        local name, currentStage, numStages = C_Scenario.GetInfo()
        if not name then return end
        self.state.name = name
        self.state.currentStage = currentStage
        self.state.numStages = numStages
    end

    local stepInfo = C_Scenario.GetStepInfo()
    if type(stepInfo) == "table" then
        self.state.stepName = stepInfo.title
        self.state.stepDescription = stepInfo.description
        self.state.numCriteria = stepInfo.numCriteria
    else
        local stepName, stepDescription, numCriteria = C_Scenario.GetStepInfo()
        self.state.stepName = stepName
        self.state.stepDescription = stepDescription
        self.state.numCriteria = numCriteria
    end

    self.state.criteria = {}
    if self.state.numCriteria and self.state.numCriteria > 0 then
        for i = 1, self.state.numCriteria do
            local successInfo, cInfo = false, nil
            if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
                successInfo, cInfo = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
            end
            
            if successInfo and type(cInfo) == "table" then
                table.insert(self.state.criteria, {
                    name = cInfo.description or "",
                    isCompleted = cInfo.completed,
                    quantity = cInfo.quantity,
                    totalQuantity = cInfo.totalQuantity,
                    isWeightedProgress = cInfo.isWeightedProgress
                })
            elseif C_Scenario.GetCriteriaInfo then
                local success, description, _, completed, quantity, totalQuantity, _, _, _, _, _, _, _, isWeightedProgress = pcall(C_Scenario.GetCriteriaInfo, i)
                if success and description then
                    table.insert(self.state.criteria, {
                        name = description,
                        isCompleted = completed,
                        quantity = quantity,
                        totalQuantity = totalQuantity,
                        isWeightedProgress = isWeightedProgress
                    })
                end
            end
        end
    end

    local activeKeystoneLevel, activeAffixIDs = C_ChallengeMode.GetActiveKeystoneInfo()
    if activeKeystoneLevel and activeKeystoneLevel > 0 then
        self.state.isMythicPlus = true
        self.state.keystoneLevel = activeKeystoneLevel
        
        local numDeaths, timeLost = C_ChallengeMode.GetDeathCount()
        self.state.numDeaths = numDeaths
        self.state.timeLost = timeLost

        self.state.affixes = {}
        for _, affixID in ipairs(activeAffixIDs) do
            local affixName, affixDesc, affixIcon = C_ChallengeMode.GetAffixInfo(affixID)
            table.insert(self.state.affixes, {
                id   = affixID,
                name = affixName,
                desc = affixDesc,
                icon = affixIcon
            })
        end
    end
end
