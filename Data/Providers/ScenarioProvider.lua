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

scenarioData.state = {
    widgets = {},
    criteria = {},
    bonusSteps = {},
    affixes = {}
}

local function isWidgetShown(info)
    if not info then return false end
    if info.shownState == nil then return true end
    if info.shownState == 1 then return true end
    if Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown then
        return info.shownState == Enum.WidgetShownState.Shown
    end
    return info.shownState > 0
end

function scenarioData:init()
    -- Hardcode known Torghast sets that aren't exposed via generic getters in modern API
    self.activeWidgetSetIDs = { [1]=true, [252]=true }
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("SCENARIO_UPDATE")
    self.eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    self.eventFrame:RegisterEvent("SCENARIO_BONUS_VISIBILITY_CHANGED")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    self.eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    self.eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_UI_WIDGET" then
            local widgetInfo = ...
            if widgetInfo and type(widgetInfo) == "table" and widgetInfo.widgetSetID then
                if C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then
                    self.activeWidgetSetIDs[widgetInfo.widgetSetID] = true
                end
            end
        end
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function scenarioData:extractWidgetData(widgetSetId, seenTexts)
    if not widgetSetId or widgetSetId == 0 or not C_UIWidgetManager or not C_UIWidgetManager.GetAllWidgetsBySetID then
        return
    end

    if not self.state.widgets then
        self.state.widgets = {}
    end

    local ok, widgetList = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetId)
    if not ok or not widgetList then return end

    local tempWidgets = {}
    local currentOrderIndex = 0

    local currentWidgetId = 0

    local function addWidget(w, widgetType)
        if w.text then
            local lowerText = string.lower(w.text)
            
            -- Filter out rogue "death x/y" widgets
            if (string.match(lowerText, "death") or string.match(lowerText, "muerte")) and string.match(lowerText, "%d+/%d+") then
                return
            end

            if string.find(lowerText, "tarragrue") or string.find(lowerText, "anima power") or string.find(lowerText, "poder") then
                -- Try to exclude localized anima power headers and Tarragrue warnings
                if string.find(lowerText, "tarragrue") or string.find(lowerText, "anima") or string.find(lowerText, "ánima") or string.find(lowerText, "nima") then
                    return
                end
            end
        end
        w.orderIndex = currentOrderIndex
        w.widgetID = currentWidgetId
        w.widgetSetID = widgetSetId
        w.widgetType = widgetType or "Widget"
        table.insert(tempWidgets, w)
    end

    -- Sort widgets by orderIndex to fix Torghast headers showing in wrong places
    table.sort(widgetList, function(a, b)
        local orderA = type(a) == "table" and a.orderIndex or 0
        local orderB = type(b) == "table" and b.orderIndex or 0
        if orderA == orderB then
            local idA = type(a) == "table" and (a.widgetID or a.widgetId) or (type(a) == "number" and a or 0)
            local idB = type(b) == "table" and (b.widgetID or b.widgetId) or (type(b) == "number" and b or 0)
            return idA < idB
        end
        return orderA < orderB
    end)

    for _, widgetInfo in ipairs(widgetList) do
        local widgetId = type(widgetInfo) == "number" and widgetInfo or (type(widgetInfo) == "table" and (widgetInfo.widgetID or widgetInfo.widgetId))
        if widgetId then
            currentWidgetId = widgetId
            currentOrderIndex = 0

            if C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo then
                local okText, textInfo = pcall(C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo, widgetId)
                if okText and textInfo and isWidgetShown(textInfo) and textInfo.text and textInfo.text ~= "" then
                    if not seenTexts[textInfo.text] then
                        seenTexts[textInfo.text] = true
                        currentOrderIndex = textInfo.orderIndex or 0
                        addWidget({ text = textInfo.text }, "TextWithState")
                    end
                end
            end

            if C_UIWidgetManager.GetSpellDisplayWidgetVisualizationInfo then
                local okSpell, spellInfo = pcall(C_UIWidgetManager.GetSpellDisplayWidgetVisualizationInfo, widgetId)
                if okSpell and spellInfo and isWidgetShown(spellInfo) and spellInfo.spellInfo then
                    local spellName = spellInfo.spellInfo.name
                    if not spellName and spellInfo.spellInfo.spellID and C_Spell and C_Spell.GetSpellName then
                        local okName, spName = pcall(C_Spell.GetSpellName, spellInfo.spellInfo.spellID)
                        if okName then spellName = spName end
                    end
                    local spellIcon = spellInfo.spellInfo.spellIcon or spellInfo.spellInfo.icon
                    if not spellIcon and spellInfo.spellInfo.spellID then
                        if C_Spell and C_Spell.GetSpellTexture then
                            local okIcon, spIcon = pcall(C_Spell.GetSpellTexture, spellInfo.spellInfo.spellID)
                            if okIcon then spellIcon = spIcon end
                        else
                            spellIcon = GetSpellTexture(spellInfo.spellInfo.spellID)
                        end
                    end
                    if spellName and spellName ~= "" then
                        local text = "- " .. spellName
                        if not seenTexts[text] then
                            seenTexts[text] = true
                            currentOrderIndex = spellInfo.orderIndex or 0
                            addWidget({ text = text, spellID = spellInfo.spellInfo.spellID, icon = spellIcon })
                        end
                    end
                end
            end

            if C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo then
                local okIconText, iconTextInfo = pcall(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo, widgetId)
                if okIconText and iconTextInfo and isWidgetShown(iconTextInfo) and iconTextInfo.text and iconTextInfo.text ~= "" then
                    if not seenTexts[iconTextInfo.text] then
                        seenTexts[iconTextInfo.text] = true
                        currentOrderIndex = iconTextInfo.orderIndex or 0
                        addWidget({ text = iconTextInfo.text })
                    end
                end
            end
            
            if C_UIWidgetManager.GetStateIconWidgetVisualizationInfo then
                local okState, stateInfo = pcall(C_UIWidgetManager.GetStateIconWidgetVisualizationInfo, widgetId)
                if okState and stateInfo and isWidgetShown(stateInfo) and stateInfo.iconInfo then
                    local name = stateInfo.iconInfo.tooltip or ""
                    if name ~= "" and not seenTexts[name] then
                        seenTexts[name] = true
                        currentOrderIndex = stateInfo.orderIndex or 0
                        addWidget({ text = name, icon = stateInfo.iconInfo.icon })
                    end
                end
            end

            if C_UIWidgetManager.GetTextRowWidgetVisualizationInfo then
                local okRow, rowInfo = pcall(C_UIWidgetManager.GetTextRowWidgetVisualizationInfo, widgetId)
                if okRow and rowInfo and isWidgetShown(rowInfo) and rowInfo.text and rowInfo.text ~= "" then
                    if not seenTexts[rowInfo.text] then
                        seenTexts[rowInfo.text] = true
                        currentOrderIndex = rowInfo.orderIndex or 0
                        addWidget({ text = rowInfo.text })
                    end
                end
            end

            if C_UIWidgetManager.GetBulletTextListWidgetVisualizationInfo then
                local okBullet, bulletInfo = pcall(C_UIWidgetManager.GetBulletTextListWidgetVisualizationInfo, widgetId)
                if okBullet and bulletInfo and isWidgetShown(bulletInfo) and bulletInfo.textEntries then
                    currentOrderIndex = bulletInfo.orderIndex or 0
                    for _, entry in ipairs(bulletInfo.textEntries) do
                        if entry.text and entry.text ~= "" and not seenTexts[entry.text] then
                            seenTexts[entry.text] = true
                            addWidget({ text = entry.text })
                        end
                    end
                end
            end

            if C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
                local okStatus, statusBarInfo = pcall(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo, widgetId)
                if okStatus and statusBarInfo and isWidgetShown(statusBarInfo) then
                    local label = statusBarInfo.text or statusBarInfo.overrideBarText or statusBarInfo.label or ""
                    local val = statusBarInfo.barValue or 0
                    local maxVal = statusBarInfo.barMax or 100
                    local tooltip = statusBarInfo.tooltip
                    local frameTextureKit = statusBarInfo.frameTextureKit
                    local isEmpowerment = false

                    if frameTextureKit == "jailerstower-scorebar" or widgetId == 3330 or (tooltip and string.find(string.lower(tostring(tooltip)), "empower")) then
                        label = "Torghast Empowerment"
                        isEmpowerment = true
                    end

                    if label == "" then
                        label = "Objective"
                    end

                    local barText = label .. ": " .. tostring(val) .. "/" .. tostring(maxVal)
                    if not seenTexts[barText] then
                        seenTexts[barText] = true
                        currentOrderIndex = statusBarInfo.orderIndex or 0
                        addWidget({
                            text = barText,
                            numFulfilled = val,
                            numRequired = maxVal,
                            isEmpowerment = isEmpowerment,
                            tooltip = tooltip
                        }, "StatusBar")
                    end
                end
            end

            if C_UIWidgetManager.GetPowerBarWidgetVisualizationInfo then
                local okPower, powerInfo = pcall(C_UIWidgetManager.GetPowerBarWidgetVisualizationInfo, widgetId)
                if okPower and powerInfo and isWidgetShown(powerInfo) then
                    local label = powerInfo.text or powerInfo.overrideBarText or powerInfo.label or powerInfo.tooltip or "Empowerment"
                    if label == "" then label = "Empowerment" end
                    local val = powerInfo.barValue or 0
                    local maxVal = powerInfo.barMax or 100
                    local barText = label .. ": " .. tostring(val) .. "/" .. tostring(maxVal)
                    if not seenTexts[barText] then
                        seenTexts[barText] = true
                        currentOrderIndex = powerInfo.orderIndex or 0
                        addWidget({
                            text = barText,
                            numFulfilled = val,
                            numRequired = maxVal
                        })
                    end
                end
            end

            if C_UIWidgetManager.GetScenarioHeaderTimerWidgetVisualizationInfo then
                local okTimer, timerInfo = pcall(C_UIWidgetManager.GetScenarioHeaderTimerWidgetVisualizationInfo, widgetId)
                if okTimer and timerInfo and isWidgetShown(timerInfo) then
                    local label = timerInfo.headerText or timerInfo.text or timerInfo.title or "Timer"
                    local val = timerInfo.barValue or timerInfo.timerValue or timerInfo.val or 0
                    local maxVal = timerInfo.barMax or timerInfo.timerMax or timerInfo.maxVal or 100
                    local barText = label .. ": " .. tostring(val) .. "/" .. tostring(maxVal)
                    if not seenTexts[barText] then
                        seenTexts[barText] = true
                        currentOrderIndex = timerInfo.orderIndex or 0
                        addWidget({
                            text = barText,
                            numFulfilled = val,
                            numRequired = maxVal
                        })
                    end
                end
            end

            if C_UIWidgetManager.GetScenarioHeaderCurrenciesAndHooksWidgetVisualizationInfo then
                local okHeader, headerInfo = pcall(C_UIWidgetManager.GetScenarioHeaderCurrenciesAndHooksWidgetVisualizationInfo, widgetId)
                if okHeader and headerInfo and isWidgetShown(headerInfo) and headerInfo.currencies then
                    currentOrderIndex = headerInfo.orderIndex or 0
                    for _, curr in ipairs(headerInfo.currencies) do
                        local text = (curr.text or "") .. ": " .. tostring(curr.amount or 0)
                        if text ~= "" and not seenTexts[text] then
                            seenTexts[text] = true
                            addWidget({ text = text, isCurrency = true })
                        end
                    end
                end
            end

            if C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo then
                local okCurr, currInfo = pcall(C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo, widgetId)
                if okCurr and currInfo and isWidgetShown(currInfo) then
                    currentOrderIndex = currInfo.orderIndex or 0
                    if currInfo.text and currInfo.text ~= "" and not seenTexts[currInfo.text] then
                        seenTexts[currInfo.text] = true
                        addWidget({ text = currInfo.text, icon = currInfo.icon })
                    end
                    if currInfo.currencies then
                        for _, curr in ipairs(currInfo.currencies) do
                            local text = (curr.text or "") .. ": " .. tostring(curr.amount or 0)
                            if text ~= "" and not seenTexts[text] then
                                seenTexts[text] = true
                                addWidget({ text = text, isCurrency = true })
                            end
                        end
                    end
                end
            end

            if C_UIWidgetManager.GetTextureWithStateWidgetVisualizationInfo then
                local okTex, texInfo = pcall(C_UIWidgetManager.GetTextureWithStateWidgetVisualizationInfo, widgetId)
                if okTex and texInfo and isWidgetShown(texInfo) and texInfo.text and texInfo.text ~= "" then
                    if not seenTexts[texInfo.text] then
                        seenTexts[texInfo.text] = true
                        currentOrderIndex = texInfo.orderIndex or 0
                        addWidget({ text = texInfo.text })
                    end
                end
            end

            if C_UIWidgetManager.GetDiscreteProgressStepsVisualizationInfo then
                local okProg, progInfo = pcall(C_UIWidgetManager.GetDiscreteProgressStepsVisualizationInfo, widgetId)
                if okProg and progInfo and isWidgetShown(progInfo) then
                    local text = progInfo.text
                    if not text or text == "" then text = "Empowerment" end
                    local val = progInfo.progressVal or progInfo.numFullSteps or 0
                    local maxVal = progInfo.progressMax or progInfo.numTotalSteps or 100
                    local barText = text .. ": " .. tostring(val) .. "/" .. tostring(maxVal)
                    if not seenTexts[barText] then
                        seenTexts[barText] = true
                        currentOrderIndex = progInfo.orderIndex or 0
                        addWidget({
                            text = barText,
                            numFulfilled = val,
                            numRequired = maxVal
                        })
                    end
                end
            end

            if C_UIWidgetManager.GetSpellDisplayVisualizationInfo then
                local okSpell, widgetSpellInfo = pcall(C_UIWidgetManager.GetSpellDisplayVisualizationInfo, widgetId)
                if okSpell and widgetSpellInfo and isWidgetShown(widgetSpellInfo) then
                    local icon = nil
                    
                    if widgetSpellInfo.spellInfo and widgetSpellInfo.spellInfo.spellID then
                        local isSpellActive = true
                        if widgetSpellInfo.spellInfo.shownState ~= nil then
                            isSpellActive = widgetSpellInfo.spellInfo.shownState > 0
                        end
                        
                        if isSpellActive then
                            local spellID = widgetSpellInfo.spellInfo.spellID
                            if C_Spell and C_Spell.GetSpellInfo then
                                local spellData = C_Spell.GetSpellInfo(spellID)
                                if spellData then
                                    icon = spellData.iconID
                                end
                            elseif GetSpellInfo then
                                local _, _, sIcon = GetSpellInfo(spellID)
                                icon = sIcon
                            end
                            
                            if icon then
                                local identifierKey = "IconOnly_" .. tostring(spellID)
                                if not seenTexts[identifierKey] then
                                    seenTexts[identifierKey] = true
                                    currentOrderIndex = widgetSpellInfo.orderIndex or 0
                                    addWidget({ text = "", isIconOnly = true, spellID = spellID, icon = icon })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    
    
    -- Now sort the captured tempWidgets by orderIndex
    table.sort(tempWidgets, function(a, b)
        return (a.orderIndex or 0) < (b.orderIndex or 0)
    end)
    
    local currentCategory = nil
    -- And append them to the real widgets list
    for _, w in ipairs(tempWidgets) do
        if w.text and w.text:match(":$") then
            local lowerText = string.lower(w.text)
            if string.find(lowerText, "torment") then
                currentCategory = "torment"
            elseif string.find(lowerText, "blessing") or string.find(lowerText, "bendici") then
                currentCategory = "blessing"
            else
                currentCategory = nil
            end
        end
        if w.isIconOnly then
            w.category = currentCategory
        end
        table.insert(self.state.widgets, w)
    end
end

function scenarioData:update()
    wipe(self.state)
    self.state.widgets = {}
    self.state.criteria = {}
    self.state.bonusSteps = {}
    self.state.affixes = {}

    -- Yield to TorghastData if inside Torghast
    local tgData = addonTable.dataEngine.modules["TorghastData"]
    if tgData and tgData.isTorghastScenario and tgData:isTorghastScenario() then
        return
    end

    local inScenario = C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario()
    local scenarioName, currentStage, numStages, scenarioWidgetSetId

    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local okInfo, info = pcall(C_ScenarioInfo.GetScenarioInfo)
        if okInfo and type(info) == "table" and info.name then
            scenarioName = info.name
            currentStage = info.currentStage
            numStages = info.numStages
            scenarioWidgetSetId = info.widgetSetID
        end
    end

    if not scenarioName and C_Scenario and C_Scenario.GetInfo then
        local res = { pcall(C_Scenario.GetInfo) }
        if res[1] and res[2] and res[2] ~= "" then
            scenarioName = res[2]
            currentStage = res[3]
            numStages = res[4]
            scenarioWidgetSetId = res[14]
        end
    end

    local stepWidgetSetId
    local stepName, stepDescription, numCriteria
    if C_ScenarioInfo and C_ScenarioInfo.GetStepInfo then
        local okStep, step = pcall(C_ScenarioInfo.GetStepInfo)
        if okStep and type(step) == "table" then
            stepName = step.title
            stepDescription = step.description
            numCriteria = step.numCriteria
            stepWidgetSetId = step.widgetSetID
        end
    end

    if not stepName and C_Scenario and C_Scenario.GetStepInfo then
        local res = { pcall(C_Scenario.GetStepInfo) }
        if res[1] and res[2] then
            stepName = res[2]
            stepDescription = res[3]
            numCriteria = res[4]
            stepWidgetSetId = res[15]
        end
    end

    if not scenarioName then
        scenarioName = stepName
    end

    if not inScenario and not scenarioName then
        return
    end

    self.state.name = scenarioName or "Scenario"
    self.state.currentStage = currentStage
    self.state.numStages = numStages
    self.state.stepName = stepName
    self.state.stepDescription = stepDescription
    self.state.numCriteria = numCriteria

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
            elseif C_Scenario and C_Scenario.GetCriteriaInfo then
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

    local bonusStepIds = C_Scenario and C_Scenario.GetBonusSteps and C_Scenario.GetBonusSteps()
    if bonusStepIds then
        for _, stepIndex in ipairs(bonusStepIds) do
            local okBonusStep, bonusStepName, bonusStepDesc, criteriaCount, _, _, _, bonusStepCompleted = pcall(C_Scenario.GetStepInfo, stepIndex)
            if okBonusStep then
                local bonusCriteria = {}
                if criteriaCount and criteriaCount > 0 then
                    for i = 1, criteriaCount do
                        local success, description, _, completed, quantity, totalQuantity = pcall(C_Scenario.GetCriteriaInfoByStep, stepIndex, i)
                        if success and description then
                            table.insert(bonusCriteria, {
                                name = description,
                                isCompleted = completed,
                                quantity = quantity,
                                totalQuantity = totalQuantity
                            })
                        end
                    end
                end

                local lowerName = string.lower(bonusStepName or "")
                if (bonusStepName == nil or bonusStepName == "" or lowerName == "bonus objective" or lowerName == "objetivo adicional") then
                    if bonusStepDesc and bonusStepDesc ~= "" then
                        bonusStepName = bonusStepDesc
                    elseif #bonusCriteria > 0 and bonusCriteria[1].name then
                        bonusStepName = bonusCriteria[1].name
                    end
                end

                table.insert(self.state.bonusSteps, {
                    name = bonusStepName,
                    description = bonusStepDesc,
                    isCompleted = bonusStepCompleted,
                    criteria = bonusCriteria
                })
            end
        end
    end

    local seenTexts = {}
    local setIds = {}
    if scenarioWidgetSetId then table.insert(setIds, scenarioWidgetSetId) end
    if stepWidgetSetId then table.insert(setIds, stepWidgetSetId) end
    
    if C_UIWidgetManager then
        local getters = {
            "GetTopCenterWidgetSetID",
            "GetBelowMinimapWidgetSetID",
            "GetPowerBarWidgetSetID",
            "GetMawBuffsWidgetSetID",
            "GetStateIconWidgetSetID",
            "GetScenarioHeaderCurrenciesAndHooksWidgetSetID",
            "GetBulletTextListWidgetSetID"
        }
        for _, getter in ipairs(getters) do
            if C_UIWidgetManager[getter] then
                local ok, id = pcall(C_UIWidgetManager[getter])
                if ok and id and id > 0 then
                    table.insert(setIds, id)
                end
            end
        end
    end

    if self.activeWidgetSetIDs then
        for id, active in pairs(self.activeWidgetSetIDs) do
            if active and id > 0 then
                table.insert(setIds, id)
            end
        end
    end

    local seenSetIds = {}
    for _, setId in ipairs(setIds) do
        if setId and setId > 0 and not seenSetIds[setId] then
            seenSetIds[setId] = true
            self:extractWidgetData(setId, seenTexts)
        end
    end

    if C_Scenario.IsInScenario() then
        local animaPowers = {}
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local i = 1
            while true do
                local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "MAW")
                if not auraData then break end
                table.insert(animaPowers, {
                    text = auraData.name or "",
                    icon = auraData.icon,
                    spellID = auraData.spellId,
                    isIconOnly = true,
                    category = "Anima Powers",
                    stacks = auraData.applications or 0
                })
                i = i + 1
            end
        else
            for i = 1, 100 do
                local name, icon, count, _, _, _, _, _, _, spellId = UnitAura("player", i, "MAW")
                if not name then break end
                table.insert(animaPowers, {
                    text = name,
                    icon = icon,
                    spellID = spellId,
                    isIconOnly = true,
                    category = "Anima Powers",
                    stacks = count or 0
                })
            end
        end

        if #animaPowers > 0 then
            self.state.widgets = self.state.widgets or {}
            
            -- Cleanup old text-based Anima Powers and tag category headers
            local filteredWidgets = {}
            for _, w in ipairs(self.state.widgets) do
                local keep = true
                if w.text and not w.isIconOnly then
                    local lowerText = string.lower(w.text)
                    if string.find(lowerText, "anima power") or string.find(lowerText, "poder.*nima") then
                        keep = false
                    elseif string.find(lowerText, "torment") or string.find(lowerText, "blessing") or string.find(lowerText, "bendici") then
                        w.isCategoryHeader = true
                    else
                        for _, ap in ipairs(animaPowers) do
                            if ap.text and ap.text ~= "" and string.find(w.text, ap.text, 1, true) then
                                keep = false
                                break
                            end
                        end
                    end
                end
                if keep then
                    table.insert(filteredWidgets, w)
                end
            end
            self.state.widgets = filteredWidgets

            table.insert(self.state.widgets, { text = "Anima Powers:", isCategoryHeader = true })
            for _, ap in ipairs(animaPowers) do
                table.insert(self.state.widgets, ap)
            end
        end
    end



    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local okKey, activeKeystoneLevel, activeAffixIDs = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if okKey and activeKeystoneLevel and activeKeystoneLevel > 0 then
            self.state.isMythicPlus = true
            self.state.keystoneLevel = activeKeystoneLevel
            
            local okDeath, numDeaths, timeLost = pcall(C_ChallengeMode.GetDeathCount)
            if okDeath then
                self.state.numDeaths = numDeaths
                self.state.timeLost = timeLost
            end

            if activeAffixIDs then
                for _, affixID in ipairs(activeAffixIDs) do
                    local okAffix, affixName, affixDesc, affixIcon = pcall(C_ChallengeMode.GetAffixInfo, affixID)
                    if okAffix then
                        table.insert(self.state.affixes, {
                            id   = affixID,
                            name = affixName,
                            desc = affixDesc,
                            icon = affixIcon
                        })
                    end
                end
            end
        end
    end


end
