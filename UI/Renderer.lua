-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: Renderer.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local uiEngine = {}
addonTable.uiEngine = uiEngine

function uiEngine:init()
    self.collapsedQuests = self.collapsedQuests or {}
    self.collapsedCategories = self.collapsedCategories or {}
    local container = addonTable.ascensionTracker.contentFrame
    self.blockPool = CreateFramePool("Button", container, "AscensionQuestBlockTemplate")
    self.chipPool = CreateObjectPool(
        function()
            local chip = CreateFrame("Frame", nil, container, "BackdropTemplate")
            chip:SetHeight(20)
            chip:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
            })
            chip:SetBackdropColor(0, 0, 0, 0)
            chip:SetBackdropBorderColor(0, 0, 0, 0)

            -- Integrated Progress Bar Background (Thin line at bottom)
            chip.progressBar = CreateFrame("StatusBar", nil, chip)
            chip.progressBar:SetHeight(4)
            chip.progressBar:SetPoint("BOTTOMLEFT", chip, "BOTTOMLEFT", 0, -2)
            chip.progressBar:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 0, -2)
            chip.progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            chip.progressBar:SetMinMaxValues(0, 100)

            -- Higher FrameLevel for text
            chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            chip.text:SetPoint("LEFT", chip, "LEFT", 8, 0)
            chip.text:SetJustifyH("LEFT")

            chip.stackText = chip:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            chip.stackText:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", -2, 2)
            chip.stackText:SetJustifyH("RIGHT")
            chip.stackText:SetTextColor(1, 1, 0)

            return chip
        end,
        function(_, chip)
            chip:Hide()
            chip:ClearAllPoints()
            chip:SetParent(container)
        end
    )
    self.itemPool = CreateFramePool("Button", container, "AscensionQuestItemButtonTemplate")

    self.colors = {
        categoryHeader   = { 0.400, 0.750, 1.000, 1.00 }, -- #66BFFFFF
        dividerLine      = { 0.400, 0.750, 1.000, 1.00 }, -- #66BFFFFF
        header           = { 1.0, 0.82, 0.0 },            -- #FFD100
        title            = { 1.0, 0.82, 0.0 },            -- #FFD100
        progression      = { 0.8, 0.8, 0.8 },             -- #CCCCCC
        success          = { 0.1, 1.0, 0.1 },             -- #19FF19
        alert            = { 1.0, 0.1, 0.1 },             -- #FF1919
        surfaceDark      = { 0.040, 0.035, 0.060, 0.85 }, -- #0A090FD9
        surfaceHighlight = { 0.170, 0.140, 0.240, 1.00 }, -- #2B243DFF
        primaryHover     = { 0.298, 0.165, 0.522, 0.60 }, -- #4C2A8599
        textLight        = { 0.89, 0.91, 0.94, 1.0 },     -- #E3E8F0FF
        accent           = { 0.400, 0.000, 0.925, 1.00 }  -- #6600ECFF
    }

    self.headerPool = CreateObjectPool(
        function()
            local header = CreateFrame("Button", nil, container)
            header:SetHeight(20)

            header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.text:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
            header.text:SetJustifyH("LEFT")

            header.divider = header:CreateTexture(nil, "BACKGROUND")
            header.divider:SetColorTexture(unpack(self.colors.dividerLine))
            if PixelUtil then
                PixelUtil.SetHeight(header.divider, 2)
                PixelUtil.SetPoint(header.divider, "BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
                PixelUtil.SetPoint(header.divider, "BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
            else
                header.divider:SetHeight(2)
                header.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
                header.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
            end

            return header
        end,
        function(_, header)
            header:Hide()
            header:ClearAllPoints()
            header:SetParent(container)
        end
    )

    self.pendingItems = {}

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            self:processPendingItems()
            addonTable.dataEngine:queueUpdate()
        end
    end)

    self.dropdownFrame = CreateFrame("Frame", "AscensionQuestTrackerContextMenu", UIParent, "UIDropDownMenuTemplate")
end

function uiEngine:render()
    if InCombatLockdown() then
        return
    end

    if not addonTable.ascensionTracker or not addonTable.ascensionTracker.contentFrame then
        return
    end

    if not self.blockPool or not self.itemPool or not self.chipPool then
        return
    end

    self.itemPool:ReleaseAll()
    self.blockPool:ReleaseAll()
    self.chipPool:ReleaseAll()
    if self.headerPool then self.headerPool:ReleaseAll() end

    local padding = 5
    local previousFrame = nil
    local totalHeight = 0
    local container = addonTable.ascensionTracker.contentFrame
    local maxWidth = container:GetWidth()
    if not maxWidth or maxWidth <= 50 then
        maxWidth = 250
    end

    local aggregatedBlocks = {}

    local scData = addonTable.dataEngine.modules["ScenarioData"]
    if scData and scData.state and scData.state.name then
        local st = scData.state
        local objs = {}
        if st.stepName then
            table.insert(objs, {
                text = st.stepName,
                numFulfilled = 0,
                numRequired = 0,
                finished = false,
                isScenarioWidget = true
            })
        end
        if st.stepDescription and st.stepDescription ~= "" and st.stepDescription ~= st.stepName then
            table.insert(objs, {
                text = st.stepDescription,
                numFulfilled = 0,
                numRequired = 0,
                finished = false,
                isScenarioWidget = true
            })
        end
        if st.criteria then
            for _, c in ipairs(st.criteria) do
                local cName = c.name or ""
                local cLower = string.lower(cName)
                if not ((string.match(cLower, "death") or string.match(cLower, "muerte")) and string.match(cLower, "%d+/%d+")) then
                    local req = c.totalQuantity or 1
                    if c.isWeightedProgress and req == 0 then req = 100 end
                    table.insert(objs, {
                        text = "- " .. cName,
                        numFulfilled = c.quantity or 0,
                        numRequired = req,
                        finished = c.isCompleted,
                        isScenarioWidget = true
                    })
                end
            end
        end
        if st.bonusSteps then
            for _, bonusStep in ipairs(st.bonusSteps) do
                if bonusStep.name then
                    table.insert(objs, {
                        text = "[Bonus] " .. bonusStep.name,
                        numFulfilled = 0,
                        numRequired = 0,
                        finished = bonusStep.isCompleted,
                        isScenarioWidget = true
                    })
                end
                if bonusStep.criteria then
                    for _, bonusCriterion in ipairs(bonusStep.criteria) do
                        local req = bonusCriterion.totalQuantity or 1
                        table.insert(objs, {
                            text = "- " .. (bonusCriterion.name or ""),
                            numFulfilled = bonusCriterion.quantity or 0,
                            numRequired = req,
                            finished = bonusCriterion.isCompleted,
                            isScenarioWidget = true
                        })
                    end
                end
            end
        end
        if st.widgets then
            for _, widgetItem in ipairs(st.widgets) do
                table.insert(objs, {
                    text = widgetItem.text,
                    icon = widgetItem.icon,
                    spellID = widgetItem.spellID,
                    isIconOnly = widgetItem.isIconOnly,
                    category = widgetItem.category,
                    isCategoryHeader = widgetItem.isCategoryHeader,
                    isCurrency = widgetItem.isCurrency,
                    stacks = widgetItem.stacks,
                    numFulfilled = 0,
                    numRequired = 0,
                    finished = false,
                    isScenarioWidget = true
                })
            end
        end
        local catName = st.name or "Scenario"
        local title = ""
        if st.isMythicPlus then
            title = "[+" .. tostring(st.keystoneLevel) .. "]"
            if st.numDeaths then
                local deathsText = "Deaths: " .. tostring(st.numDeaths)
                if st.timeLost and st.timeLost > 0 then
                    deathsText = deathsText .. " (-" .. tostring(st.timeLost) .. "s)"
                end
                table.insert(objs, {
                    text = deathsText,
                    numFulfilled = 0,
                    numRequired = 0,
                    finished = false,
                    isScenarioWidget = true
                })
            end
            if st.affixes and #st.affixes > 0 then
                local affStr = "Affixes: "
                for i, affix in ipairs(st.affixes) do
                    affStr = affStr .. (affix.name or "")
                    if i < #st.affixes then affStr = affStr .. ", " end
                end
                table.insert(objs, {
                    text = affStr,
                    numFulfilled = 0,
                    numRequired = 0,
                    finished = false,
                    isScenarioWidget = true
                })
            end
        end
        if st.currentStage and st.numStages and st.numStages > 0 then
            if title ~= "" then title = title .. " " end
            title = title .. "Stage " .. tostring(st.currentStage) .. "/" .. tostring(st.numStages)
        end
        if title == "" then
            title = st.name
        end
        
        table.insert(aggregatedBlocks,
            { category = catName, id = "scenario", title = title, objectives = objs, type = "scenario" })
    end

    local questData = addonTable.dataEngine.modules["QuestData"]
    if questData and questData.activeQuests then
        -- 0. Completed quests
        for _, q in ipairs(questData.activeQuests) do
            if q.isComplete then
                table.insert(aggregatedBlocks,
                    { category = "Completed", id = q.id, title = q.title, isFailed = q.isFailed, isComplete = q
                    .isComplete, objectives = q.objectives, type = "quest", itemLink = q.itemLink, itemIcon = q.itemIcon, spellID =
                    q.spellID, spellTexture = q.spellTexture })
            end
        end
        -- 1. Local Quests (both Campaign and Secondary)
        for _, q in ipairs(questData.activeQuests) do
            if q.isLocal and not q.isComplete then
                table.insert(aggregatedBlocks,
                    { category = "Local Quests", id = q.id, title = q.title, isFailed = q.isFailed, isComplete = q
                    .isComplete, objectives = q.objectives, type = "quest", itemLink = q.itemLink, itemIcon = q.itemIcon, spellID =
                    q.spellID, spellTexture = q.spellTexture })
            end
        end
        -- 2. Remote Campaign quests
        for _, q in ipairs(questData.activeQuests) do
            if not q.isLocal and q.isCampaign and not q.isComplete then
                table.insert(aggregatedBlocks,
                    { category = "Campaign", id = q.id, title = q.title, isFailed = q.isFailed, isComplete = q
                    .isComplete, objectives = q.objectives, type = "quest", itemLink = q.itemLink, itemIcon = q.itemIcon, spellID =
                    q.spellID, spellTexture = q.spellTexture })
            end
        end
        -- 3. Remote Secondary quests
        for _, q in ipairs(questData.activeQuests) do
            if not q.isLocal and not q.isCampaign and not q.isComplete then
                table.insert(aggregatedBlocks,
                    { category = "Quests", id = q.id, title = q.title, isFailed = q.isFailed, isComplete = q.isComplete, objectives =
                    q.objectives, type = "quest", itemLink = q.itemLink, itemIcon = q.itemIcon, spellID = q.spellID, spellTexture =
                    q.spellTexture })
            end
        end
    end

    local wqData = addonTable.dataEngine.modules["WorldQuestData"]
    if wqData and wqData.activeQuests and #wqData.activeQuests > 0 then
        for _, q in ipairs(wqData.activeQuests) do
            local title = q.title
            local isExpiring = false
            if q.minutesLeft and q.minutesLeft < 15 then
                isExpiring = true
                title = title .. " |TInterface\\Icons\\INV_Misc_Time_01:14|t"
            end
            table.insert(aggregatedBlocks,
                {
                    category = "World Quests",
                    id = q.id,
                    title = title,
                    objectives = q.objectives,
                    type = "worldquest",
                    isExpiring =
                        isExpiring
                })
        end
    end

    local boData = addonTable.dataEngine.modules["BonusObjectiveData"]
    if boData and boData.activeQuests and #boData.activeQuests > 0 then
        for _, q in ipairs(boData.activeQuests) do
            table.insert(aggregatedBlocks,
                {
                    category = "Bonus Objectives",
                    id = q.id,
                    title = q.title,
                    objectives = q.objectives,
                    type =
                    "bonusobjective"
                })
        end
    end

    local achData = addonTable.dataEngine.modules["AchievementData"]
    if achData and achData.activeAchievements and #achData.activeAchievements > 0 then
        for _, a in ipairs(achData.activeAchievements) do
            local objs = {}
            for _, c in ipairs(a.criteria) do
                table.insert(objs,
                    { text = c.name, numFulfilled = c.quantity, numRequired = c.reqQuantity, finished = c.completed })
            end
            table.insert(aggregatedBlocks,
                { category = "Achievements", id = a.id, title = a.name, objectives = objs, type = "achievement" })
        end
    end

    local profData = addonTable.dataEngine.modules["ProfessionData"]
    if profData and profData.activeRecipes and #profData.activeRecipes > 0 then
        for _, r in ipairs(profData.activeRecipes) do
            local objs = {}
            for _, c in ipairs(r.requirements) do
                table.insert(objs,
                    { text = c.name, numFulfilled = c.totalOwned, numRequired = c.totalRequired, finished = (c.totalOwned >= c.totalRequired) })
            end
            table.insert(aggregatedBlocks,
                { category = "Professions", id = r.id, title = r.name, objectives = objs, type = "profession" })
        end
    end

    local tpData = addonTable.dataEngine.modules["TradingPostData"]
    if tpData and tpData.activeActivities and #tpData.activeActivities > 0 then
        for _, a in ipairs(tpData.activeActivities) do
            local objs = {}
            table.insert(objs, {
                text = "Progress",
                numFulfilled = a.progress,
                numRequired = a.threshold,
                finished = a.completed
            })
            table.insert(aggregatedBlocks,
                { category = "Traveler's Log", id = a.id, title = a.title, objectives = objs, type = "tradingpost" })
        end
    end

    local typo = addonTable.config and addonTable.config.db and addonTable.config.db.profile.typography
    local fontPath = "Fonts\\FRIZQT__.TTF"

    local currentCategory = nil

    for _, quest in ipairs(aggregatedBlocks) do
        if quest.category ~= currentCategory and quest.category then
            local headerFrame = self.headerPool:Acquire()
            headerFrame:SetWidth(maxWidth)
            headerFrame:Show()

            headerFrame.text:ClearAllPoints()
            headerFrame.text:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 0, 0)
            headerFrame.text:SetWidth(maxWidth)
            headerFrame.text:SetWordWrap(true)
            headerFrame.text:SetNonSpaceWrap(true)

            headerFrame.text:SetText(quest.category)
            headerFrame.text:SetTextColor(unpack(self.colors.categoryHeader))
            if typo then
                -- Increase header font size slightly
                headerFrame.text:SetFont(fontPath, (typo.headerSize or 14) + 4, typo.fontFlag)
            end

            headerFrame:ClearAllPoints()
            if previousFrame then
                headerFrame:SetPoint("TOP", previousFrame, "BOTTOM", 0, -padding)
                totalHeight = totalHeight + padding
            else
                headerFrame:SetPoint("TOP", container, "TOP", 0, 0)
            end

            local textHeight = headerFrame.text:GetStringHeight() or 14
            local hHeight = math.max(26, textHeight + 8)
            headerFrame:SetHeight(hHeight)
            totalHeight = totalHeight + hHeight
            previousFrame = headerFrame
            currentCategory = quest.category

            headerFrame.category = quest.category
            headerFrame:RegisterForClicks("LeftButtonUp")
            headerFrame:SetScript("OnClick", function(btn)
                uiEngine.collapsedCategories[btn.category] = not uiEngine.collapsedCategories[btn.category]
                if addonTable.dataEngine then addonTable.dataEngine:queueUpdate() end
            end)
        end

        if not self.collapsedCategories[quest.category] then
            local block = self.blockPool:Acquire()
            block:Show()

            block:SetWidth(maxWidth)
            if quest.type == "scenario" then
                block.title:SetWordWrap(true)
                block.title:SetNonSpaceWrap(true)
            else
                block.title:SetWordWrap(false)
                block.title:SetNonSpaceWrap(false)
            end

            block.questID = quest.id
            block.blockType = quest.type

            block:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            block:SetScript("OnClick", function(f, button)
                if IsShiftKeyDown() then
                    if f.blockType == "achievement" then
                        if C_ContentTracking and C_ContentTracking.StopTracking then
                            local stopType = Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual or 0
                            C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, f.questID, stopType)
                        elseif RemoveTrackedAchievement then
                            RemoveTrackedAchievement(f.questID)
                        end
                    elseif f.blockType == "profession" then
                        C_TradeSkillUI.SetRecipeTracked(f.questID, false, false)
                    elseif f.blockType == "tradingpost" then
                        if C_PerksActivities and C_PerksActivities.RemoveTrackedActivity then
                            C_PerksActivities.RemoveTrackedActivity(f.questID)
                        end
                    elseif f.blockType == "worldquest" and C_QuestLog.RemoveWorldQuestWatch then
                        C_QuestLog.RemoveWorldQuestWatch(f.questID)
                    else
                        C_QuestLog.RemoveQuestWatch(f.questID)
                    end
                elseif button == "LeftButton" then
                    self.collapsedQuests[f.questID] = not self.collapsedQuests[f.questID]
                    if addonTable.dataEngine then addonTable.dataEngine:queueUpdate() end
                elseif button == "RightButton" then
                    UIDropDownMenu_Initialize(self.dropdownFrame, function(frame, level, menuList)
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = "Open Details"
                        info.func = function()
                            if f.blockType == "achievement" and not InCombatLockdown() then
                                OpenAchievementFrameToAchievement(f.questID)
                            elseif f.blockType == "quest" or f.blockType == "worldquest" then
                                QuestMapFrame_OpenToQuestDetails(f.questID)
                            end
                        end
                        UIDropDownMenu_AddButton(info)

                        if f.blockType == "quest" or f.blockType == "worldquest" then
                            local superTrackInfo = UIDropDownMenu_CreateInfo()
                            superTrackInfo.text = "Super Track"
                            superTrackInfo.func = function()
                                if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                                    C_SuperTrack.SetSuperTrackedQuestID(f.questID)
                                end
                            end
                            UIDropDownMenu_AddButton(superTrackInfo)
                        end

                        if f.blockType == "quest" then
                            local shareInfo = UIDropDownMenu_CreateInfo()
                            shareInfo.text = "Share Quest"
                            shareInfo.func = function()
                                if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(f.questID) end
                                QuestLogPushQuest()
                            end
                            UIDropDownMenu_AddButton(shareInfo)

                            local abandonInfo = UIDropDownMenu_CreateInfo()
                            abandonInfo.text = "Abandon Quest"
                            abandonInfo.func = function()
                                if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(f.questID) end
                                C_QuestLog.SetAbandonQuest()
                                C_QuestLog.AbandonQuest()
                            end
                            UIDropDownMenu_AddButton(abandonInfo)
                        end
                    end, "MENU")
                    ToggleDropDownMenu(1, nil, self.dropdownFrame, "cursor", 3, -3)
                end
            end)

            local hasAction = (quest.itemLink or quest.spellID) and not quest.isComplete
            local contentOffsetX = hasAction and 34 or 0

            block.title:ClearAllPoints()
            block.title:SetPoint("TOPLEFT", block, "TOPLEFT", contentOffsetX, 0)
            block.title:SetWidth(maxWidth - contentOffsetX)

            block.title:SetText(quest.title)
            if typo then
                block.title:SetFont(fontPath, typo.titleSize, typo.fontFlag)
                if typo.dropShadow then
                    block.title:SetShadowOffset(typo.shadowX, typo.shadowY)
                else
                    block.title:SetShadowOffset(0, 0)
                end
            end

            if quest.isFailed then
                block.title:SetTextColor(unpack(self.colors.alert))
            elseif quest.isComplete then
                block.title:SetTextColor(unpack(self.colors.success))
            elseif quest.isExpiring then
                block.title:SetTextColor(unpack(self.colors.alert))
            else
                block.title:SetTextColor(unpack(self.colors.title))
            end

            block:ClearAllPoints()
            if previousFrame then
                block:SetPoint("TOP", previousFrame, "BOTTOM", 0, -padding)
            else
                block:SetPoint("TOP", container, "TOP", 0, 0)
            end

            -- Item/Spell button mapping
            if hasAction and not InCombatLockdown() then
                local itemBtn = self.itemPool:Acquire()
                itemBtn:SetParent(block)
                itemBtn:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
                itemBtn:SetFrameLevel(block:GetFrameLevel() + 10)
                itemBtn:RegisterForClicks("AnyUp", "AnyDown")

                if quest.spellID then
                    local spellName, spellIcon
                    if C_Spell and C_Spell.GetSpellInfo then
                        local info = C_Spell.GetSpellInfo(quest.spellID)
                        if info then spellName, spellIcon = info.name, info.iconID end
                    else
                        local name, _, icon = GetSpellInfo(quest.spellID)
                        spellName, spellIcon = name, icon
                    end
                    itemBtn.icon:SetTexture(quest.spellTexture or spellIcon)
                    itemBtn:SetAttribute("type1", "spell")
                    itemBtn:SetAttribute("spell1", spellName)
                    itemBtn.spellID = quest.spellID
                    itemBtn.itemLink = nil
                elseif quest.itemLink then
                    local spellID = quest.itemLink:match("Hspell:(%d+)")
                    if spellID then
                        local spellName, spellIcon
                        if C_Spell and C_Spell.GetSpellInfo then
                            local info = C_Spell.GetSpellInfo(tonumber(spellID))
                            if info then spellName, spellIcon = info.name, info.iconID end
                        else
                            local name, _, icon = GetSpellInfo(tonumber(spellID))
                            spellName, spellIcon = name, icon
                        end
                        itemBtn.icon:SetTexture(quest.itemIcon or spellIcon)
                        itemBtn:SetAttribute("type1", "spell")
                        itemBtn:SetAttribute("spell1", spellName)
                        itemBtn.spellID = tonumber(spellID)
                        itemBtn.itemLink = nil
                    else
                        itemBtn.icon:SetTexture(quest.itemIcon)
                        itemBtn:SetAttribute("type1", "item")
                        itemBtn:SetAttribute("item1", quest.itemLink)
                        itemBtn.spellID = nil
                        itemBtn.itemLink = quest.itemLink
                    end
                end

                itemBtn:RegisterForDrag("LeftButton")
                itemBtn:SetScript("OnDragStart", function(self)
                    if InCombatLockdown() then return end
                    if self.spellID then
                        PickupSpell(self.spellID)
                    elseif self.itemLink then
                        PickupItem(self.itemLink)
                    end
                end)

                RegisterStateDriver(itemBtn, "visibility", "[combat] hide; show")
                itemBtn:Show()
            elseif hasAction and InCombatLockdown() then
                table.insert(self.pendingItems,
                    { questID = quest.id, link = quest.itemLink, icon = quest.itemIcon, spellID = quest.spellID, spellTexture =
                    quest.spellTexture, anchor = block })
            end

            local titleHeight = block.title:GetStringHeight() or 14
            local blockHeight = (hasAction and math.max(28, titleHeight + 10)) or (titleHeight + 6)
            local currentX = 10 + contentOffsetX
            -- Reduce spacing between title and objectives by half, but adjust for actual title height
            local currentY = hasAction and -(titleHeight + 6) or -(titleHeight + 4)
            local rowHeight = 24
            local paddingX = 5

            if quest.objectives and not self.collapsedQuests[quest.id] then
                for _, obj in ipairs(quest.objectives) do
                    local numFulfilled = obj.numFulfilled or 0
                    local numRequired = obj.numRequired or 0
                    local isObjFinished = obj.finished or (numRequired > 0 and numFulfilled >= numRequired)

                    -- Strip x/x from text if objective is finished
                    local displayText = obj.text or ""
                    if isObjFinished then
                        displayText = string.gsub(displayText, "%s*%d+/%d+%s*$", "")
                        -- Sometimes WoW uses a colon before the numbers, strip trailing colon as well
                        displayText = string.gsub(displayText, ":%s*$", "")
                    end

                    -- Only render the objective if there is still text left to show or if it's icon only
                    if (displayText and displayText:match("%S")) or obj.isIconOnly then
                        local chip = self.chipPool:Acquire()
                        chip:SetParent(block)
                        if obj.isCategoryHeader then
                            chip.text:SetTextColor(unpack(self.colors.title))
                        else
                            chip.text:SetTextColor(unpack(self.colors.textLight))
                        end

                        chip.text:SetText(displayText)

                        if typo then
                            if obj.isCategoryHeader then
                                chip.text:SetFont(fontPath, typo.titleSize or (typo.bodySize + 2), typo.fontFlag)
                            else
                                chip.text:SetFont(fontPath, typo.bodySize, typo.fontFlag)
                            end
                            if typo.dropShadow then
                                chip.text:SetShadowOffset(typo.shadowX, typo.shadowY)
                            else
                                chip.text:SetShadowOffset(0, 0)
                            end
                        end

                        if obj.isCategoryHeader then
                            if currentX > 10 + contentOffsetX then
                                currentY = currentY - rowHeight - 4
                            end
                            currentX = contentOffsetX
                            currentY = currentY - 4
                        elseif not obj.isIconOnly then
                            if currentX > 10 + contentOffsetX then
                                currentY = currentY - rowHeight
                            end
                            currentX = 10 + contentOffsetX
                        end

                        local chipWidth = math.max(50, maxWidth - 10 - currentX)
                        local actualChipHeight = 20

                        if obj.isIconOnly then
                            if obj.category == "Anima Powers" then
                                chipWidth = 24
                                actualChipHeight = 24
                            else
                                chipWidth = 36        -- Fixed width for icon-only chips
                                actualChipHeight = 36 -- Increased height
                            end
                            chip.text:Hide()
                        else
                            chip.text:Show()
                        end

                        chip.text:SetWidth(math.max(20, chipWidth - 16))

                        if not obj.isIconOnly then
                            if obj.isScenarioWidget then
                                chip.text:SetWordWrap(true)
                                chip.text:SetNonSpaceWrap(true)
                                local textHeight = chip.text:GetStringHeight()
                                actualChipHeight = math.max(20, textHeight + 8)
                            else
                                chip.text:SetWordWrap(false)
                                chip.text:SetNonSpaceWrap(false)
                            end
                        end
                        chip:SetSize(chipWidth, actualChipHeight)

                        if obj.icon then
                            if not chip.icon then
                                chip.icon = chip:CreateTexture(nil, "OVERLAY")
                            end
                            if not chip.iconBorder then
                                chip.iconBorder = chip:CreateTexture(nil, "BACKGROUND")
                                chip.iconBorder:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                                chip.iconBorder:SetPoint("CENTER", chip.icon, "CENTER", 0, 0)
                            end
                            if obj.isIconOnly then
                                if obj.category == "Anima Powers" then
                                    chip.icon:SetSize(24, 24)
                                    chip.iconBorder:Hide()
                                else
                                    chip.icon:SetSize(32, 32)
                                    chip.iconBorder:SetSize(34, 34)
                                    if obj.category == "torment" then
                                        chip.iconBorder:SetVertexColor(0.8, 0.1, 0.1, 1) -- Red
                                        chip.iconBorder:Show()
                                    elseif obj.category == "blessing" then
                                        chip.iconBorder:SetVertexColor(0.1, 0.8, 0.1, 1) -- Green
                                        chip.iconBorder:Show()
                                    else
                                        chip.iconBorder:Hide()
                                    end
                                end
                            else
                                chip.icon:SetSize(16, 16)
                                chip.iconBorder:Hide()
                            end
                            chip.icon:SetPoint("LEFT", chip, "LEFT", 2, 0)
                            chip.icon:SetTexture(obj.icon)
                            chip.icon:Show()
                            chip.text:SetPoint("LEFT", chip, "LEFT", 24, 0)
                            chip.text:SetWidth(math.max(20, chipWidth - 32))
                        else
                            if chip.icon then chip.icon:Hide() end
                            if chip.iconBorder then chip.iconBorder:Hide() end
                            chip.text:SetPoint("LEFT", chip, "LEFT", 8, 0)
                            chip.text:SetWidth(math.max(20, chipWidth - 16))
                        end

                        if obj.stacks and obj.stacks > 1 then
                            chip.stackText:SetText(tostring(obj.stacks))
                            chip.stackText:Show()
                        else
                            chip.stackText:Hide()
                        end

                        if obj.isIconOnly and obj.spellID then
                            chip:EnableMouse(true)
                            chip:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetSpellByID(obj.spellID)
                                GameTooltip:Show()
                            end)
                            chip:SetScript("OnLeave", function(self)
                                GameTooltip:Hide()
                            end)
                        else
                            chip:EnableMouse(false)
                            chip:SetScript("OnEnter", nil)
                            chip:SetScript("OnLeave", nil)
                        end

                        -- Dynamic progress logic
                        local progressRatio = (numRequired > 0) and (numFulfilled / numRequired) or 1
                        chip.progressBar:SetValue(progressRatio * 100)

                        if quest.isComplete or isObjFinished then
                            chip.progressBar:SetAlpha(0)
                            chip.text:SetTextColor(unpack(self.colors.success))
                            chip:SetAlpha(1.0)
                        elseif numRequired == 0 then
                            chip.progressBar:SetAlpha(0)
                            chip:SetAlpha(1.0)
                            if obj.isCurrency then
                                chip.text:SetTextColor(0.4, 0.7, 1.0)
                            elseif obj.isCategoryHeader then
                                chip.text:SetTextColor(unpack(self.colors.title))
                            else
                                chip.text:SetTextColor(unpack(self.colors.textLight))
                            end
                        else
                            chip.progressBar:SetAlpha(1.0)
                            chip:SetAlpha(1.0)
                            if obj.isCategoryHeader then
                                chip.text:SetTextColor(unpack(self.colors.title))
                            else
                                chip.text:SetTextColor(unpack(self.colors.textLight))
                            end
                            -- Quester style gradient: Red -> Yellow -> Green
                            local r = math.min(1, 2 - 2 * progressRatio)
                            local g = math.min(1, 2 * progressRatio)
                            local b = 0
                            local alpha = self.colors.primaryHover[4] or 0.6
                            chip.progressBar:SetStatusBarColor(r, g, b, alpha)
                        end

                        -- Flex-wrap math: If X position + chip width exceeds container max width, wrap to new line
                        if currentX + chipWidth > maxWidth - 5 then
                            currentX = 10 + contentOffsetX
                            currentY = currentY - rowHeight
                        end

                        chip:SetPoint("TOPLEFT", block, "TOPLEFT", currentX, currentY)
                        chip:Show()

                        -- Advance currentX for next chip (if we had inline chips, but since chipWidth is ~maxWidth we usually wrap)
                        local currentPadding = (obj.category == "Anima Powers") and 1 or paddingX
                        currentX = currentX + chipWidth + currentPadding
                        rowHeight = actualChipHeight + 4
                    end
                end

                -- Expand block height for all rows used
                if currentX > 10 or currentY < -22 then
                    blockHeight = math.abs(currentY) + rowHeight
                end
            end

            block:SetHeight(blockHeight)
            previousFrame = block
            totalHeight = totalHeight + blockHeight + padding
        end
    end

    addonTable.ascensionTracker:updateHeight(totalHeight)
end

function uiEngine:processPendingItems()
    for _, item in ipairs(self.pendingItems) do
        local itemBtn = self.itemPool:Acquire()
        itemBtn:SetParent(item.anchor)
        itemBtn:SetPoint("TOPLEFT", item.anchor, "TOPLEFT", 0, 0)
        itemBtn:SetFrameLevel(item.anchor:GetFrameLevel() + 10)
        itemBtn:RegisterForClicks("AnyUp", "AnyDown")

        if item.spellID then
            local spellName, spellIcon
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(item.spellID)
                if info then spellName, spellIcon = info.name, info.iconID end
            else
                local name, _, icon = GetSpellInfo(item.spellID)
                spellName, spellIcon = name, icon
            end
            itemBtn.icon:SetTexture(item.spellTexture or spellIcon)
            itemBtn:SetAttribute("type1", "spell")
            itemBtn:SetAttribute("spell1", spellName)
            itemBtn.spellID = item.spellID
            itemBtn.itemLink = nil
        elseif item.link then
            local spellID = item.link:match("Hspell:(%d+)")
            if spellID then
                local spellName, spellIcon
                if C_Spell and C_Spell.GetSpellInfo then
                    local info = C_Spell.GetSpellInfo(tonumber(spellID))
                    if info then spellName, spellIcon = info.name, info.iconID end
                else
                    local name, _, icon = GetSpellInfo(tonumber(spellID))
                    spellName, spellIcon = name, icon
                end
                itemBtn.icon:SetTexture(item.icon or spellIcon)
                itemBtn:SetAttribute("type1", "spell")
                itemBtn:SetAttribute("spell1", spellName)
                itemBtn.spellID = tonumber(spellID)
                itemBtn.itemLink = nil
            else
                itemBtn.icon:SetTexture(item.icon)
                itemBtn:SetAttribute("type1", "item")
                itemBtn:SetAttribute("item1", item.link)
                itemBtn.spellID = nil
                itemBtn.itemLink = item.link
            end
        end

        itemBtn:RegisterForDrag("LeftButton")
        itemBtn:SetScript("OnDragStart", function(self)
            if InCombatLockdown() then return end
            if self.spellID then
                PickupSpell(self.spellID)
            elseif self.itemLink then
                PickupItem(self.itemLink)
            end
        end)

        RegisterStateDriver(itemBtn, "visibility", "[combat] hide; show")
        itemBtn:Show()
    end
    wipe(self.pendingItems)
end
