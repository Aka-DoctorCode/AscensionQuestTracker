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

            -- Integrated Progress Bar Background
            chip.progressBar = CreateFrame("StatusBar", nil, chip)
            chip.progressBar:SetAllPoints(chip)
            chip.progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            chip.progressBar:SetMinMaxValues(0, 100)

            -- Higher FrameLevel for text
            chip.text = chip.progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            chip.text:SetPoint("LEFT", chip, "LEFT", 8, 0)
            chip.text:SetJustifyH("LEFT")

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
        header           = { 1.0, 0.82, 0.0 },          -- #FFD100
        title            = { 1.0, 0.82, 0.0 },          -- #FFD100
        progression      = { 0.8, 0.8, 0.8 },           -- #CCCCCC
        success          = { 0.1, 1.0, 0.1 },           -- #19FF19
        alert            = { 1.0, 0.1, 0.1 },           -- #FF1919
        surfaceDark      = { 0.040, 0.035, 0.060, 0.85 }, -- #0A090FD9
        surfaceHighlight = { 0.170, 0.140, 0.240, 1.00 }, -- #2B243DFF
        primaryHover     = { 0.298, 0.165, 0.522, 0.60 }, -- #4C2A8599
        textLight        = { 0.89, 0.91, 0.94, 1.0 },   -- #E3E8F0FF
        accent           = { 0.400, 0.000, 0.925, 1.00 } -- #6600ECFF
    }

    self.headerPool = CreateObjectPool(
        function()
            local header = CreateFrame("Button", nil, container)
            header:SetHeight(20)

            header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.text:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -2)
            header.text:SetJustifyH("LEFT")

            header.divider = header:CreateTexture(nil, "BACKGROUND")
            header.divider:SetColorTexture(unpack(self.colors.dividerLine))
            header.divider:SetHeight(1)
            header.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
            header.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

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

    self.itemPool:ReleaseAll()
    self.blockPool:ReleaseAll()
    self.chipPool:ReleaseAll()
    if self.headerPool then self.headerPool:ReleaseAll() end

    local padding = 5
    local previousFrame = nil
    local totalHeight = 0
    local container = addonTable.ascensionTracker.contentFrame
    local maxWidth = container:GetWidth()

    local aggregatedBlocks = {}

    local questData = addonTable.dataEngine.modules["QuestData"]
    if questData and questData.activeQuests then
        for _, q in ipairs(questData.activeQuests) do
            table.insert(aggregatedBlocks,
                { category = "Campaign / Quests", id = q.id, title = q.title, isFailed = q.isFailed, objectives = q
                .objectives, type = "quest" })
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
                { category = "World Quests", id = q.id, title = title, objectives = q.objectives, type = "worldquest", isExpiring =
                isExpiring })
        end
    end

    local boData = addonTable.dataEngine.modules["BonusObjectiveData"]
    if boData and boData.activeQuests and #boData.activeQuests > 0 then
        for _, q in ipairs(boData.activeQuests) do
            table.insert(aggregatedBlocks,
                { category = "Bonus Objectives", id = q.id, title = q.title, objectives = q.objectives, type =
                "bonusobjective" })
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

            headerFrame.text:SetText(quest.category)
            headerFrame.text:SetTextColor(unpack(self.colors.categoryHeader))
            if typo then
                headerFrame.text:SetFont(fontPath, typo.headerSize or 14, typo.fontFlag)
            end

            headerFrame:ClearAllPoints()
            if previousFrame then
                headerFrame:SetPoint("TOP", previousFrame, "BOTTOM", 0, -padding * 2)
                totalHeight = totalHeight + (padding * 2)
            else
                headerFrame:SetPoint("TOP", container, "TOP", 0, 0)
            end

            local hHeight = 20
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
            block.title:SetWordWrap(false)

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

            -- Item button mapping
            if quest.itemLink and not InCombatLockdown() then
                local itemBtn = self.itemPool:Acquire()
                itemBtn:SetPoint("TOPLEFT", block, "TOPLEFT", -25, 0)
                itemBtn.icon:SetTexture(quest.itemIcon)
                itemBtn:SetAttribute("type", "item")
                itemBtn:SetAttribute("item", quest.itemLink)
                RegisterStateDriver(itemBtn, "visibility", "[combat] hide; show")
                itemBtn:Show()
            elseif quest.itemLink and InCombatLockdown() then
                table.insert(self.pendingItems,
                    { questID = quest.id, link = quest.itemLink, icon = quest.itemIcon, anchor = block })
            end

            local blockHeight = 20
            local currentX = 10
            local currentY = -22
            local rowHeight = 24
            local paddingX = 5

            if quest.objectives and not self.collapsedQuests[quest.id] then
                for _, obj in ipairs(quest.objectives) do
                    local chip = self.chipPool:Acquire()
                    chip:SetParent(block)
                    chip.text:SetTextColor(unpack(self.colors.textLight))

                    local numFulfilled = obj.numFulfilled or 0
                    local numRequired = obj.numRequired or 1

                    chip.text:SetText(obj.text)
                    if typo then
                        chip.text:SetFont(fontPath, typo.bodySize, typo.fontFlag)
                        if typo.dropShadow then
                            chip.text:SetShadowOffset(typo.shadowX, typo.shadowY)
                        else
                            chip.text:SetShadowOffset(0, 0)
                        end
                    end

                    -- Force chip to be full width of the frame container
                    local chipWidth = maxWidth - 20

                    chip.text:SetWidth(chipWidth - 16)
                    chip.text:SetWordWrap(false)
                    chip:SetWidth(chipWidth)

                    -- Dynamic progress logic
                    local progressRatio = (numRequired > 0) and (numFulfilled / numRequired) or 1
                    chip.progressBar:SetValue(progressRatio * 100)

                    if obj.finished or numFulfilled >= numRequired then
                        chip:SetAlpha(0.5)
                        chip.progressBar:SetStatusBarColor(0, 1, 0, 1) -- Green when finished
                    else
                        chip:SetAlpha(1.0)
                        -- Quester style gradient: Red -> Yellow -> Green
                        local r = math.min(1, 2 - 2 * progressRatio)
                        local g = math.min(1, 2 * progressRatio)
                        local b = 0
                        local alpha = self.colors.primaryHover[4] or 0.6
                        chip.progressBar:SetStatusBarColor(r, g, b, alpha)
                    end

                    -- Flex-wrap math: If X position + chip width exceeds container max width, wrap to new line
                    if currentX + chipWidth > maxWidth - 10 then
                        currentX = 10
                        currentY = currentY - rowHeight
                    end

                    chip:SetPoint("TOPLEFT", block, "TOPLEFT", currentX, currentY)
                    chip:Show()

                    -- Advance currentX for next chip
                    currentX = currentX + chipWidth + paddingX
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
        itemBtn:SetPoint("TOPLEFT", item.anchor, "TOPLEFT", -25, 0)
        itemBtn.icon:SetTexture(item.icon)
        itemBtn:SetAttribute("type", "item")
        itemBtn:SetAttribute("item", item.link)
        RegisterStateDriver(itemBtn, "visibility", "[combat] hide; show")
        itemBtn:Show()
    end
    wipe(self.pendingItems)
end
