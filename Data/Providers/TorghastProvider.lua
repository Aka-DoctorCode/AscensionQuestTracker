-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: TorghastProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local torghastData = {}
addonTable.dataEngine:registerModule("TorghastData", torghastData)

torghastData.state = {
    widgets = {},
    animaPowers = {},
    phantasma = nil,
    floorName = nil
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

function torghastData:init()
    self.activeWidgetSetIDs = { [252] = true, [291] = true, [514] = true }
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("SCENARIO_UPDATE")
    self.eventFrame:RegisterEvent("SCENARIO_STEP_UPDATE")
    self.eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    self.eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    self.eventFrame:RegisterEvent("UNIT_AURA")
    self.eventFrame:RegisterEvent("MAW_ANIMA_POWER_GAINED")
    self.eventFrame:RegisterEvent("MAW_ANIMA_POWER_LIST_TOGGLED")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            self.activeWidgetSetIDs = { [252] = true, [291] = true, [514] = true }
        end
        if event == "UNIT_AURA" then
            local unit = select(1, ...)
            if unit ~= "player" then return end
        end
        if event == "UPDATE_UI_WIDGET" then
            local widgetInfo = select(1, ...)
            if widgetInfo and type(widgetInfo) == "table" and widgetInfo.widgetSetID then
                if self:isTorghastScenario() then
                    self.activeWidgetSetIDs[widgetInfo.widgetSetID] = true
                end
            end
        end
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)

    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.1, function()
            if self:isTorghastScenario() and addonTable.dataEngine then
                addonTable.dataEngine:queueUpdate()
            end
        end)
    end
end

function torghastData:isTorghastScenario()
    local scenarioName = ""
    local scenarioWidgetSetId = nil

    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local okInfo, info = pcall(C_ScenarioInfo.GetScenarioInfo)
        if okInfo and type(info) == "table" then
            if info.name then scenarioName = string.lower(info.name) end
            if info.widgetSetID then scenarioWidgetSetId = info.widgetSetID end
        end
    end

    if scenarioName == "" and C_Scenario and C_Scenario.GetInfo then
        local resList = { pcall(C_Scenario.GetInfo) }
        if resList[1] and resList[2] and resList[2] ~= "" then
            scenarioName = string.lower(resList[2])
        end
        if resList[1] and resList[14] then
            scenarioWidgetSetId = resList[14]
        end
    end

    if string.find(scenarioName, "torghast")
       or string.find(scenarioName, "twisting corridors")
       or string.find(scenarioName, "pasillos sinuosos")
       or string.find(scenarioName, "torre de los condenados")
       or string.find(scenarioName, "tower of the damned") then
        return true
    end

    if scenarioWidgetSetId == 252 or scenarioWidgetSetId == 291 or scenarioWidgetSetId == 514 or scenarioWidgetSetId == 735 then
        return true
    end

    if self.activeWidgetSetIDs then
        if self.activeWidgetSetIDs[252] or self.activeWidgetSetIDs[291] or self.activeWidgetSetIDs[514] or self.activeWidgetSetIDs[735] then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- 2. DATA EXTRACTION
-------------------------------------------------------------------------------
function torghastData:extractWidgetData(widgetSetId, seenTexts)
    if not widgetSetId or widgetSetId == 0 or not C_UIWidgetManager or not C_UIWidgetManager.GetAllWidgetsBySetID then
        return
    end

    local ok, widgetList = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetId)
    if not ok or not widgetList then return end

    local currentOrderIndex = 0
    local currentWidgetId = 0

    local function addWidget(w, widgetType)
        if w.text then
            local lowerText = string.lower(w.text)
            if string.find(lowerText, "tarragrue") or string.find(lowerText, "anima power") or string.find(lowerText, "poder") then
                if string.find(lowerText, "tarragrue") or string.find(lowerText, "anima") or string.find(lowerText, "ánima") then
                    return
                end
            end
        end
        w.orderIndex = currentOrderIndex
        w.widgetID = currentWidgetId
        w.widgetSetID = widgetSetId
        w.widgetType = widgetType or "Widget"
        table.insert(self.state.widgets, w)
    end

    for _, widgetInfo in ipairs(widgetList) do
        local widgetId = type(widgetInfo) == "number" and widgetInfo or (type(widgetInfo) == "table" and (widgetInfo.widgetID or widgetInfo.widgetId))
        if widgetId then
            currentWidgetId = widgetId
            currentOrderIndex = 0

            -- Text Widgets
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

            -- Status Bar Widgets (Torghast Empowerment Bar!)
            if C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
                local okStatus, statusBarInfo = pcall(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo, widgetId)
                if okStatus and statusBarInfo then
                    local label = statusBarInfo.text or statusBarInfo.overrideBarText or statusBarInfo.label or ""
                    local val = statusBarInfo.barValue or 0
                    local maxVal = (statusBarInfo.barMax and statusBarInfo.barMax > 0) and statusBarInfo.barMax or 300
                    local tooltip = statusBarInfo.tooltip
                    local frameTextureKit = statusBarInfo.frameTextureKit
                    local isEmpowerment = false

                    if frameTextureKit == "jailerstower-scorebar" or widgetId == 3330 or (tooltip and string.find(string.lower(tostring(tooltip)), "empower")) then
                        label = "Torghast Empowerment"
                        isEmpowerment = true
                        maxVal = (statusBarInfo.barMax and statusBarInfo.barMax > 0) and statusBarInfo.barMax or 300
                    end

                    if isEmpowerment or isWidgetShown(statusBarInfo) then
                        if label == "" then label = "Objective" end

                        local barText = label .. ": " .. tostring(val) .. "/" .. tostring(maxVal)
                        if not seenTexts[barText] or isEmpowerment then
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
            end

            -- Spell Display Widgets (Torments, Blessings, Spells)
            local getSpellInfoFunc = C_UIWidgetManager.GetSpellDisplayVisualizationInfo or C_UIWidgetManager.GetSpellDisplayWidgetVisualizationInfo
            if getSpellInfoFunc then
                local okSpell, spellWidgetInfo = pcall(getSpellInfoFunc, widgetId)
                if okSpell and spellWidgetInfo and isWidgetShown(spellWidgetInfo) then
                    local spellsList = {}
                    if spellWidgetInfo.spellInfo then
                        table.insert(spellsList, spellWidgetInfo.spellInfo)
                    elseif spellWidgetInfo.spell then
                        table.insert(spellsList, spellWidgetInfo.spell)
                    elseif spellWidgetInfo.spells then
                        spellsList = spellWidgetInfo.spells
                    end

                    for _, sp in ipairs(spellsList) do
                        local sID = sp.spellID or sp.spellId or sp.id
                        local sName = sp.name
                        local sIcon = sp.icon or sp.spellIcon or sp.texture
                        if not sName and sID then
                            if C_Spell and C_Spell.GetSpellName then
                                local okName, spName = pcall(C_Spell.GetSpellName, sID)
                                if okName then sName = spName end
                            else
                                sName = GetSpellInfo and GetSpellInfo(sID) or nil
                            end
                        end
                        if not sIcon and sID then
                            if C_Spell and C_Spell.GetSpellTexture then
                                local okIcon, spIcon = pcall(C_Spell.GetSpellTexture, sID)
                                if okIcon then sIcon = spIcon end
                            else
                                sIcon = GetSpellTexture and GetSpellTexture(sID) or nil
                            end
                        end
                        if sName and sName ~= "" then
                            local text = "- " .. sName
                            if not seenTexts[text] then
                                seenTexts[text] = true
                                currentOrderIndex = spellWidgetInfo.orderIndex or 0
                                addWidget({
                                    text = text,
                                    spellID = sID,
                                    icon = sIcon,
                                    isIconOnly = true
                                }, "SpellDisplay")
                            end
                        end
                    end
                end
            end

            -- Icon & Text Widgets
            if C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo then
                local okIconText, iconTextInfo = pcall(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo, widgetId)
                if okIconText and iconTextInfo and isWidgetShown(iconTextInfo) and iconTextInfo.text and iconTextInfo.text ~= "" then
                    if not seenTexts[iconTextInfo.text] then
                        seenTexts[iconTextInfo.text] = true
                        currentOrderIndex = iconTextInfo.orderIndex or 0
                        addWidget({ text = iconTextInfo.text }, "IconAndText")
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 3. UPDATE LOGIC
-------------------------------------------------------------------------------
function torghastData:update()
    wipe(self.state)
    self.state.widgets = {}
    self.state.animaPowers = {}
    self.state.phantasma = nil
    self.state.floorName = nil

    if not self:isTorghastScenario() then
        return
    end

    -- 1. Floor & Step Info
    local stepWidgetSetId
    local stepName, stepDescription
    if C_ScenarioInfo and C_ScenarioInfo.GetStepInfo then
        local okStep, step = pcall(C_ScenarioInfo.GetStepInfo)
        if okStep and type(step) == "table" then
            stepName = step.title
            stepDescription = step.description
            stepWidgetSetId = step.widgetSetID
        end
    end

    if not stepName and C_Scenario and C_Scenario.GetStepInfo then
        local res = { pcall(C_Scenario.GetStepInfo) }
        if res[1] and res[2] then
            stepName = res[2]
            stepDescription = res[3]
            stepWidgetSetId = res[15]
        end
    end

    if stepName and stepName ~= "" then
        table.insert(self.state.widgets, { text = stepName, isCategoryHeader = true })
    end
    if stepDescription and stepDescription ~= "" and stepDescription ~= stepName then
        table.insert(self.state.widgets, { text = stepDescription, isScenarioWidget = true })
    end

    -- 2. Scenario Widgets & Empowerment Bar
    local seenTexts = {}
    local setIds = {}

    local scenarioWidgetSetId
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local okInfo, info = pcall(C_ScenarioInfo.GetScenarioInfo)
        if okInfo and type(info) == "table" and info.widgetSetID then
            scenarioWidgetSetId = info.widgetSetID
        end
    end

    if scenarioWidgetSetId then table.insert(setIds, scenarioWidgetSetId) end
    if stepWidgetSetId then table.insert(setIds, stepWidgetSetId) end

    if C_UIWidgetManager then
        local getters = {
            "GetTopCenterWidgetSetID",
            "GetBelowMinimapWidgetSetID",
            "GetPowerBarWidgetSetID",
            "GetMawBuffsWidgetSetID"
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

    local currentCat = nil
    for _, w in ipairs(self.state.widgets) do
        if w.text then
            local lowerText = string.lower(w.text)
            if string.find(lowerText, "torment") or string.find(lowerText, "tormento") then
                currentCat = "torment"
            elseif string.find(lowerText, "blessing") or string.find(lowerText, "bendici") then
                currentCat = "blessing"
            elseif w.isCategoryHeader or w.isEmpowerment or string.find(lowerText, "anima") then
                currentCat = nil
            end
        end
        if w.category == nil and currentCat then
            w.category = currentCat
        end
    end

    -- Guaranteed live check & update for Widget 3330 (Torghast Empowerment Bar)
    local liveVal = 0
    local liveMax = 300
    local liveTooltip = "Torghast Empowerment"
    if C_UIWidgetManager and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
        local okStatus, statusBarInfo = pcall(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo, 3330)
        if okStatus and statusBarInfo then
            liveVal = statusBarInfo.barValue or 0
            liveMax = (statusBarInfo.barMax and statusBarInfo.barMax > 0) and statusBarInfo.barMax or 300
            if statusBarInfo.tooltip then liveTooltip = statusBarInfo.tooltip end
        end
    end

    local empWidget = nil
    for _, w in ipairs(self.state.widgets) do
        if w.isEmpowerment then
            empWidget = w
            break
        end
    end

    if empWidget then
        empWidget.numFulfilled = liveVal
        empWidget.numRequired = liveMax
        if liveTooltip then empWidget.tooltip = liveTooltip end
        empWidget.text = "Torghast Empowerment: " .. tostring(liveVal) .. "/" .. tostring(liveMax)
    else
        local barText = "Torghast Empowerment: " .. tostring(liveVal) .. "/" .. tostring(liveMax)
        table.insert(self.state.widgets, {
            text = barText,
            numFulfilled = liveVal,
            numRequired = liveMax,
            isEmpowerment = true,
            tooltip = liveTooltip,
            widgetID = 3330,
            widgetType = "StatusBar"
        })
    end

    -- 3. Anima Powers (C_MawBuffs, AuraUtil, C_UnitAuras)
    local animaPowers = {}
    if C_MawBuffs and C_MawBuffs.GetMawBuffs then
        local okMaw, buffList = pcall(C_MawBuffs.GetMawBuffs)
        if okMaw and type(buffList) == "table" then
            for _, buff in ipairs(buffList) do
                local spellName = buff.name
                local spellIcon = buff.icon
                local spellID = buff.spellID
                if not spellName and spellID then
                    if C_Spell and C_Spell.GetSpellName then
                        spellName = C_Spell.GetSpellName(spellID)
                    else
                        spellName = GetSpellInfo(spellID)
                    end
                end
                table.insert(animaPowers, {
                    text = spellName or "",
                    icon = spellIcon,
                    spellID = spellID,
                    isIconOnly = true,
                    category = "Anima Powers",
                    stacks = buff.count or 1
                })
            end
        end
    end

    if #animaPowers == 0 and AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraData)
            if auraData and (auraData.isMaw or (auraData.name and (string.find(string.lower(auraData.name), "anima") or string.find(string.lower(auraData.name), "ánima")))) then
                table.insert(animaPowers, {
                    text = auraData.name or "",
                    icon = auraData.icon,
                    spellID = auraData.spellId,
                    isIconOnly = true,
                    category = "Anima Powers",
                    stacks = auraData.applications or 1
                })
            end
        end)
    end

    if #animaPowers == 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for _, filter in ipairs({"HELPFUL|MAW", "HELPFUL", "MAW"}) do
            local i = 1
            while true do
                local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
                if not auraData then break end
                if filter ~= "HELPFUL" or auraData.isMaw then
                    table.insert(animaPowers, {
                        text = auraData.name or "",
                        icon = auraData.icon,
                        spellID = auraData.spellId,
                        isIconOnly = true,
                        category = "Anima Powers",
                        stacks = auraData.applications or 1
                    })
                end
                i = i + 1
            end
            if #animaPowers > 0 then break end
        end
    end

    if #animaPowers > 0 then
        table.insert(self.state.widgets, { text = "Anima Powers:", isCategoryHeader = true })
        for _, ap in ipairs(animaPowers) do
            table.insert(self.state.widgets, ap)
        end
    end

    -- 4. Phantasma Currency
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local phantasmaIds = {1718, 1728}
        for _, cId in ipairs(phantasmaIds) do
            local okCurr, phantasmaInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, cId)
            if okCurr and phantasmaInfo and phantasmaInfo.quantity and phantasmaInfo.quantity > 0 then
                local text = "Phantasma: " .. tostring(phantasmaInfo.quantity)
                if not seenTexts[text] then
                    table.insert(self.state.widgets, { text = text, isCurrency = true })
                    seenTexts[text] = true
                end
                break
            end
        end
    end
end
