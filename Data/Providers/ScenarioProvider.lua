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

    local name, currentStage, numStages = C_Scenario.GetInfo()
    if not name then return end

    self.state.name = name
    self.state.currentStage = currentStage
    self.state.numStages = numStages

    local stepName, stepDescription = C_Scenario.GetStepInfo()
    self.state.stepName = stepName
    self.state.stepDescription = stepDescription

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
