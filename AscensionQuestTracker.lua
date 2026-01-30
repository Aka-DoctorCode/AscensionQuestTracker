--------------------------------------------------------------------------------
-- NAMESPACE & CONSTANTS
--------------------------------------------------------------------------------
local addonName, addonTable = ...
local AQT = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)

-- VISUAL ASSETS
local ASSETS = {
    font = "Fonts\\FRIZQT__.TTF",
    fontHeaderSize = 13,
    fontTextSize = 10,
    barTexture = "Interface\\Buttons\\WHITE8x8",
    barHeight = 4,
    padding = 10,
    spacing = 15,
    
    colors = {
        header = {r = 1, g = 0.9, b = 0.5}, -- Yellow
        timerHigh = {r = 1, g = 1, b = 1}, -- White
        timerLow = {r = 1, g = 0.2, b = 0.2}, -- Red
        campaign = {r = 1, g = 0.5, b = 0.25}, -- Orange
        quest = {r = 1, g = 0.85, b = 0.3}, -- Yellow
        wq = {r = 0.3, g = 0.7, b = 1}, -- Blue
        achievement = {r = 0.8, g = 0.8, b = 1}, -- Light Blue
        complete = {r = 0.2, g = 1, b = 0.2}, -- Green
        active = {r = 1, g = 1, b = 1}, -- White
        zone = {r = 1, g = 1, b = 0.6}, -- Zone Header
    }
}

--------------------------------------------------------------------------------
-- OPTIMIZATION: POOLED TABLES (Reduce GC)
--------------------------------------------------------------------------------
local pooled_quests = {}
local pooled_grouped = {}
local pooled_zoneOrder = {}
local pooled_watchedIDs = {}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local function SafelySetText(fontString, text)
    if not fontString or type(fontString) ~= "table" then return end
    fontString:SetText(text or "")
end

local function FormatTime(seconds)
    if not seconds or type(seconds) ~= "number" then return "00:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

local function SafePlaySound(soundID)
    if not soundID then return end
    pcall(PlaySound, soundID)
end

local function GetQuestDistanceStr(questID)
    if not C_QuestLog.GetDistanceSqToQuest then return nil end
    local distSq = C_QuestLog.GetDistanceSqToQuest(questID)
    if not distSq or distSq < 0 then return nil end
    local yards = math.sqrt(distSq)
    if yards > 1000 then
        return string.format("%.1fkm", yards / 1000)
    else
        return string.format("%dm", math.floor(yards))
    end
end

--------------------------------------------------------------------------------
-- UI OBJECT POOLS
--------------------------------------------------------------------------------

AQT.lines = {}
AQT.bars = {}
AQT.itemButtons = {}
AQT.completions = {} -- Store quest completion state for sound notifications
AQT.inBossCombat = false

AQT.GetLine = function(self, index)
    if not self.lines[index] then
        local f = CreateFrame("Button", nil, self)
        f:SetSize(200, 16)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetAllPoints(f)
        f.text:SetJustifyH("RIGHT")
        f.text:SetWordWrap(true)
        f.text:SetShadowColor(0, 0, 0, 1)
        f.text:SetShadowOffset(1, -1)
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.lines[index] = f
    end
    local line = self.lines[index]
    line:EnableMouse(false)
    line:SetScript("OnClick", nil)
    line:SetScript("OnEnter", nil)
    line:SetScript("OnLeave", nil)
    line.text:SetAlpha(1)
    line.text:SetTextColor(1, 1, 1)
    return line
end

AQT.GetBar = function(self, index)
    if not self.bars[index] then
        local b = CreateFrame("StatusBar", nil, self, "BackdropTemplate")
        b:SetStatusBarTexture(ASSETS.barTexture)
        b:SetMinMaxValues(0, 1)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ASSETS.barTexture)
        bg:SetAllPoints(true)
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
        b.bg = bg
        self.bars[index] = b
    end
    return self.bars[index]
end

-- Secure Item Button Pool
AQT.GetItemButton = function(self, index)
    if not self.itemButtons[index] then
        local name = "AQTItemButton" .. index
        local b = CreateFrame("Button", name, self, "SecureActionButtonTemplate")
        b:SetSize(22, 22)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        
        b:SetAttribute("type", "item")
        self.itemButtons[index] = b
    end
    return self.itemButtons[index]
end

--------------------------------------------------------------------------------
-- RENDER MODULES
--------------------------------------------------------------------------------

-- 1. SCENARIOS (M+, Delves)
local function RenderScenario(startY, lineIdx, barIdx)
    local yOffset = startY
    if not C_Scenario or not C_Scenario.IsInScenario() then return yOffset, lineIdx, barIdx end

    local timerID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if timerID then
        local level = (C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo())
        local _, _, timeLimit = (C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(timerID))
        local _, elapsedTime = GetWorldElapsedTime(1)
        local timeRem = (timeLimit or 0) - (elapsedTime or 0)

        local header = AQT:GetLine(lineIdx)
        header.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize + 2, "OUTLINE")
        header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        SafelySetText(header.text, string.format("+%d Keystone", level or 0))
        header:Show()
        yOffset = yOffset - 18
        lineIdx = lineIdx + 1

        local timerLine = AQT:GetLine(lineIdx)
        timerLine.text:SetFont(ASSETS.font, 18, "OUTLINE")
        timerLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        SafelySetText(timerLine.text, FormatTime(timeRem))
        timerLine:Show()
        yOffset = yOffset - 22
        lineIdx = lineIdx + 1

        local timeBar = AQT:GetBar(barIdx)
        timeBar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260
        timeBar:SetSize(width - 20, 6)
        timeBar:SetMinMaxValues(0, timeLimit or 1)
        timeBar:SetValue(timeLimit - timeRem)
        
        if timeRem < 60 then
            timeBar:SetStatusBarColor(ASSETS.colors.timerLow.r, ASSETS.colors.timerLow.g, ASSETS.colors.timerLow.b)
        else
            timeBar:SetStatusBarColor(ASSETS.colors.timerHigh.r, ASSETS.colors.timerHigh.g, ASSETS.colors.timerHigh.b)
        end
        timeBar:Show()
        yOffset = yOffset - 12
        barIdx = barIdx + 1
    end
    
    -- Scenario Objectives
    local stageName, stageDesc, numStages = C_Scenario.GetStepInfo()
    if stageName and C_Scenario.GetStepCriteriaInfo then
        for i = 1, 15 do
            local name, type, completed, quantity, totalQuantity, flags, assetID, staticText, displayTimeLeft, scenarioID = C_Scenario.GetStepCriteriaInfo(i)
            if name and name ~= "" and not completed then
                local line = AQT:GetLine(lineIdx)
                line.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                
                local text = name
                if totalQuantity and totalQuantity > 0 then
                    text = string.format("%s: %d/%d", name, quantity, totalQuantity)
                end
                
                SafelySetText(line.text, text)
                line:Show()
                yOffset = yOffset - 12
                lineIdx = lineIdx + 1
            end
        end
    end
    
    return yOffset - ASSETS.spacing, lineIdx, barIdx
end

-- 2. QUESTS (GROUPED BY ZONE + DISTANCE SORTED)
local function RenderQuests(startY, lineIdx, barIdx, itemIdx)
    local shouldHide = AscensionQuestTrackerDB and AscensionQuestTrackerDB.hideOnBoss
    if shouldHide and AQT.inBossCombat then return startY, lineIdx, barIdx, itemIdx end

    local yOffset = startY
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then return yOffset, lineIdx, barIdx, itemIdx end

    local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260
    local superTrackedQuestID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()

    -- 1. Gather & Sort Data
    table.wipe(pooled_quests)
    table.wipe(pooled_watchedIDs)
    
    if C_QuestLog.GetQuestIDForWatch then
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local id = C_QuestLog.GetQuestIDForWatch(i)
            if id then table.insert(pooled_watchedIDs, id) end
        end
    elseif C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then
                table.insert(pooled_watchedIDs, info.questID)
            end
        end
    end

    for _, qID in ipairs(pooled_watchedIDs) do
        local logIdx = C_QuestLog.GetLogIndexForQuestID(qID)
        local info = C_QuestLog.GetInfo(logIdx)
        if info and not info.isHidden then
            local dist = 999999999
            if C_QuestLog.GetDistanceSqToQuest then
                dist = C_QuestLog.GetDistanceSqToQuest(qID) or 999999999
            end
            if qID == superTrackedQuestID then dist = -1 end -- Top priority
            
            -- WQ Time Remaining
            local timeRem = 0
            if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
                timeRem = C_TaskQuest.GetQuestTimeLeftMinutes(qID) or 0
            end

            table.insert(pooled_quests, {
                id = qID,
                info = info,
                distValue = dist,
                mapID = info.mapID or 0,
                timeRem = timeRem
            })
        end
    end

    table.sort(pooled_quests, function(a, b) return a.distValue < b.distValue end)

    -- 2. Group by Zone
    table.wipe(pooled_grouped)
    table.wipe(pooled_zoneOrder)
    
    for _, q in ipairs(pooled_quests) do
        if not pooled_grouped[q.mapID] then
            pooled_grouped[q.mapID] = {}
            table.insert(pooled_zoneOrder, q.mapID)
        end
        table.insert(pooled_grouped[q.mapID], q)
    end

    -- 3. Render
    for _, mapID in ipairs(pooled_zoneOrder) do
        -- Zone Header
        local mapInfo = C_Map.GetMapInfo(mapID)
        local zoneName = (mapInfo and mapInfo.name) or "Unknown Zone"
        
        local zLine = AQT:GetLine(lineIdx)
        zLine.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize - 1, "OUTLINE")
        zLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        zLine.text:SetTextColor(ASSETS.colors.zone.r, ASSETS.colors.zone.g, ASSETS.colors.zone.b)
        SafelySetText(zLine.text, zoneName)
        zLine:Show()
        yOffset = yOffset - 14
        lineIdx = lineIdx + 1

        for _, quest in ipairs(pooled_grouped[mapID]) do
            local qID = quest.id
            local info = quest.info
            local isComplete = C_QuestLog.IsComplete(qID)
            local isWorldQuest = C_QuestLog.IsWorldQuest(qID)
            local isSuperTracked = (qID == superTrackedQuestID)

            -- Notification Sound
            if isComplete and not AQT.completions[qID] then
                if SOUNDKIT and SOUNDKIT.UI_QUEST_COMPLETE then
                    SafePlaySound(SOUNDKIT.UI_QUEST_COMPLETE)
                end
                AQT.completions[qID] = true
            elseif not isComplete then
                AQT.completions[qID] = nil
            end

            local color = ASSETS.colors.quest
            if info.campaignID and info.campaignID > 0 then color = ASSETS.colors.campaign end
            if isWorldQuest then color = ASSETS.colors.wq end
            if isComplete then color = ASSETS.colors.complete end
            if isSuperTracked then color = ASSETS.colors.active end

            -- Quest Item Check
            local itemLink, itemIcon, itemCount, showItemWhenComplete = GetQuestLogSpecialItemInfo(C_QuestLog.GetLogIndexForQuestID(qID))
            if itemIcon and (not isComplete or showItemWhenComplete) then
                if not InCombatLockdown() then
                    local iBtn = AQT:GetItemButton(itemIdx)
                    iBtn:SetPoint("TOPRIGHT", AQT, "TOPLEFT", width - 20, yOffset - 2) -- Offset to the left of the title
                    iBtn.icon:SetTexture(itemIcon)
                    iBtn.count:SetText(itemCount > 1 and itemCount or "")
                    iBtn:SetAttribute("item", itemLink)
                    iBtn:Show()
                    itemIdx = itemIdx + 1
                end
            end

            -- Title
            local title = AQT:GetLine(lineIdx)
            title:EnableMouse(true)
            title:SetSize(width - (itemIcon and 30 or 0), 16)
            title:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
            title.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
            title.text:SetTextColor(color.r, color.g, color.b)

            local distStr = GetQuestDistanceStr(qID)
            local displayText = info.title
            
            -- WQ Timer
            if quest.timeRem > 0 and quest.timeRem < 1440 then -- Less than 24h
                 displayText = string.format("[%dm] %s", quest.timeRem, displayText)
            end
            
            if distStr then displayText = string.format("[%s] %s", distStr, displayText) end
            if isSuperTracked then displayText = "> " .. displayText end
            if isComplete then displayText = displayText .. " (Ready)" end
            SafelySetText(title.text, displayText)

            -- Interaction
            title:SetScript("OnClick", function(_, btn)
                if IsShiftKeyDown() and btn == "LeftButton" then
                    local link = GetQuestLink(qID)
                    if link then ChatEdit_InsertLink(link) end
                    return
                end
                
                if btn == "LeftButton" then
                    C_SuperTrack.SetSuperTrackedQuestID(qID)
                    C_QuestLog.SetSelectedQuest(qID)
                    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                        SafePlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                elseif btn == "RightButton" then
                    if MenuUtil and MenuUtil.CreateContextMenu then
                        -- Modern Context Menu (MenuUtil)
                        MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                            rootDescription:CreateTitle(info.title)
                            rootDescription:CreateButton("Focus / SuperTrack", function() C_SuperTrack.SetSuperTrackedQuestID(qID) end)
                            rootDescription:CreateButton("Open Map", function() QuestMapFrame_OpenToQuestDetails(qID) end)
                            rootDescription:CreateButton("Share", function() C_QuestLog.ShareQuest(qID) end)
                            rootDescription:CreateButton("|cffff4444Abandon|r", function() QuestMapFrame_AbandonQuest(qID) end)
                            rootDescription:CreateButton("Stop Tracking", function() C_QuestLog.RemoveQuestWatch(qID) end)
                        end)
                    else
                        -- Fallback for older clients: Just remove watch
                        C_QuestLog.RemoveQuestWatch(qID)
                    end
                end
            end)

            title:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                if not pcall(GameTooltip.SetHyperlink, GameTooltip, "quest:"..qID) then
                    GameTooltip:SetQuestLogItem(C_QuestLog.GetLogIndexForQuestID(qID))
                end
                
                -- Add explicit rewards summary if needed (basic rewards are usually in the item tooltip)
                local xp = GetQuestLogRewardXP(qID) or 0
                local money = GetQuestLogRewardMoney(qID) or 0
                if xp > 0 or money > 0 then
                     GameTooltip:AddLine(" ")
                     GameTooltip:AddLine("Rewards:", 1, 0.8, 0)
                     if xp > 0 then GameTooltip:AddLine(string.format("XP: %d", xp), 1, 1, 1) end
                     if money > 0 then GameTooltip:AddLine(GetMoneyString(money), 1, 1, 1) end
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ffffShift-Click:|r Link to Chat", 0, 1, 1)
                GameTooltip:AddLine("|cffffaa00Right-Click:|r Context Menu", 1, 0.6, 0)
                GameTooltip:Show()
            end)
            title:SetScript("OnLeave", function() GameTooltip:Hide() end)

            title:Show()
            yOffset = yOffset - 15
            lineIdx = lineIdx + 1

            -- Campaign Progress
            if info.campaignID and C_CampaignInfo then
                local cInfo = C_CampaignInfo.GetCampaignInfo(info.campaignID)
                if cInfo then
                     local cLine = AQT:GetLine(lineIdx)
                     cLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                     cLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize - 1, "ITALIC")
                     -- Example: "The War Within (2/5)"
                     local text = cInfo.name 
                     if cInfo.chapterID and C_CampaignInfo.GetChapterInfo then
                         local chInfo = C_CampaignInfo.GetChapterInfo(cInfo.chapterID)
                         if chInfo and chInfo.name then text = text .. ": " .. chInfo.name end
                     end
                     SafelySetText(cLine.text, text)
                     cLine.text:SetTextColor(ASSETS.colors.campaign.r, ASSETS.colors.campaign.g, ASSETS.colors.campaign.b)
                     cLine:Show()
                     yOffset = yOffset - 10
                     lineIdx = lineIdx + 1
                end
            end

            -- Objectives
            if not isComplete then
                local objectives = C_QuestLog.GetQuestObjectives(qID)
                for _, obj in ipairs(objectives or {}) do
                    if obj.text and not obj.finished then
                        local oLine = AQT:GetLine(lineIdx)
                        oLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                        oLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                        SafelySetText(oLine.text, obj.text)
                        oLine:Show()
                        yOffset = yOffset - 12
                        lineIdx = lineIdx + 1

                        if obj.numRequired and obj.numRequired > 0 then
                            local bar = AQT:GetBar(barIdx)
                            bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                            bar:SetSize(width - 20, ASSETS.barHeight)
                            bar:SetValue(obj.numFulfilled / obj.numRequired)
                            bar:SetStatusBarColor(color.r, color.g, color.b)
                            bar:Show()
                            yOffset = yOffset - 8
                            barIdx = barIdx + 1
                        end
                    end
                end
                end

            -- Bonus Objective Bar (World Quests / Bonus Objectives)
            if not isComplete and C_TaskQuest and C_TaskQuest.GetQuestProgressBarInfo then
                local progress = C_TaskQuest.GetQuestProgressBarInfo(qID)
                if progress then
                    local pLine = AQT:GetLine(lineIdx)
                    pLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                    pLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                    SafelySetText(pLine.text, string.format("Progress: %d%%", progress))
                    pLine:Show()
                    yOffset = yOffset - 12
                    lineIdx = lineIdx + 1

                    local bar = AQT:GetBar(barIdx)
                    bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                    bar:SetSize(width - 20, ASSETS.barHeight)
                    bar:SetValue(progress / 100)
                    bar:SetStatusBarColor(ASSETS.colors.wq.r, ASSETS.colors.wq.g, ASSETS.colors.wq.b)
                    bar:Show()
                    yOffset = yOffset - 8
                    barIdx = barIdx + 1
                end
            end
            yOffset = yOffset - 6
        end
    end
    return yOffset, lineIdx, barIdx, itemIdx
end

-- 3. ACHIEVEMENTS
local function RenderAchievements(startY, lineIdx)
    local yOffset = startY
    local tracked = GetTrackedAchievements and { GetTrackedAchievements() } or {}
    if #tracked == 0 then return yOffset, lineIdx end

    local header = AQT:GetLine(lineIdx)
    header.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
    header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    header.text:SetTextColor(ASSETS.colors.header.r, ASSETS.colors.header.g, ASSETS.colors.header.b)
    SafelySetText(header.text, "Achievements")
    header:Show()
    yOffset = yOffset - 16
    lineIdx = lineIdx + 1

    for _, achID in ipairs(tracked) do
        local id, name, _, completed = GetAchievementInfo(achID)
        if not completed and id then
            local line = AQT:GetLine(lineIdx)
            line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
            line.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
            line.text:SetTextColor(ASSETS.colors.achievement.r, ASSETS.colors.achievement.g, ASSETS.colors.achievement.b)
            SafelySetText(line.text, name)
            
            line:EnableMouse(true)
            line:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetAchievementByID(achID)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() GameTooltip:Hide() end)
            line:SetScript("OnClick", function()
                if not AchievementFrame then AchievementFrame_LoadUI() end
                AchievementFrame_SelectAchievement(achID)
            end)
            
            line:Show()
            yOffset = yOffset - 14
            lineIdx = lineIdx + 1
            
            -- Detailed Criteria
            local numCriteria = GetAchievementNumCriteria(achID)
            for i = 1, numCriteria do
                local cName, _, cComp, cQty, cReq = GetAchievementCriteriaInfo(achID, i)
                if not cComp and (bit.band(select(7, GetAchievementCriteriaInfo(achID, i)), 1) ~= 1) then -- Skip hidden
                    local cLine = AQT:GetLine(lineIdx)
                    cLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                    cLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                    
                    local cText = cName
                    if cReq and cReq > 1 then
                        cText = string.format("%s: %d/%d", cName, cQty, cReq)
                    end
                    SafelySetText(cLine.text, cText)
                    cLine.text:SetTextColor(0.8, 0.8, 0.8)
                    cLine:Show()
                    yOffset = yOffset - 12
                    lineIdx = lineIdx + 1
                end
            end
            yOffset = yOffset - 4
        end
    end
    return yOffset, lineIdx
end

--------------------------------------------------------------------------------
-- UPDATE LOGIC
--------------------------------------------------------------------------------

function AQT:FullUpdate()
    for _, l in ipairs(AQT.lines) do l:Hide() end
    for _, b in ipairs(AQT.bars) do b:Hide() end
    if not InCombatLockdown() then
        for _, itm in ipairs(AQT.itemButtons) do itm:Hide() end
    end
    
    local y, lIdx, bIdx = RenderScenario(-ASSETS.padding, 1, 1)
    local itemIdx = 1
    y, lIdx, bIdx, itemIdx = RenderQuests(y, lIdx, bIdx, itemIdx)
    RenderAchievements(y, lIdx)
    
    local h = math.abs(y) + ASSETS.padding
    AQT:SetHeight(h < 50 and 50 or h)
end

local function Initialize()
    if not AscensionQuestTrackerDB then 
        AscensionQuestTrackerDB = { scale = 1, width = 260, hideOnBoss = true, locked = false } 
    end
    
    local db = AscensionQuestTrackerDB
    AQT:SetSize(db.width or 260, 100)
    AQT:SetScale(db.scale or 1)
    
    if db.position then
        AQT:ClearAllPoints()
        AQT:SetPoint(db.position.point, UIParent, db.position.relativePoint, db.position.x, db.position.y)
    else
        AQT:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    end

    AQT:SetMovable(true)
    AQT:EnableMouse(not db.locked) 
    AQT:RegisterForDrag("LeftButton")
    
    AQT:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        AscensionQuestTrackerDB.position = { point = point, relativePoint = rel, x = x, y = y }
    end)
    
    AQT:SetScript("OnDragStart", function(self)
        if not AscensionQuestTrackerDB.locked then self:StartMoving() end
    end)
    
    AQT:FullUpdate()
    print("|cff00ff00Ascension Quest Tracker:|r v2.0 Initialized.")
end

AQT:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.1, Initialize)
    elseif event == "ENCOUNTER_START" then 
        AQT.inBossCombat = true
        self.isDirty = true
    elseif event == "ENCOUNTER_END" then 
        AQT.inBossCombat = false
        self.isDirty = true
    elseif event == "QUEST_TURNED_IN" then
        if SOUNDKIT and SOUNDKIT.UI_QUEST_LOG_QUEST_ABANDONED then
            SafePlaySound(SOUNDKIT.UI_QUEST_LOG_QUEST_ABANDONED) -- Simple feedback
        end
        self.isDirty = true
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        self.isDirty = true
        -- Auto SuperTrack closest quest in new zone
        C_Timer.After(2, function()
             if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID and #pooled_quests > 0 then
                  local bestID, bestDist = nil, 999999
                  for _, q in ipairs(pooled_quests) do
                      if q.distValue and q.distValue > 0 and q.distValue < bestDist then
                          bestDist = q.distValue
                          bestID = q.id
                      end
                  end
                  if bestID then C_SuperTrack.SetSuperTrackedQuestID(bestID) end
             end
        end)
    else
        self.isDirty = true
    end
end)

AQT:RegisterEvent("PLAYER_LOGIN")
AQT:RegisterEvent("QUEST_LOG_UPDATE")
AQT:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
AQT:RegisterEvent("SUPER_TRACKING_CHANGED")
AQT:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
AQT:RegisterEvent("SCENARIO_UPDATE")
AQT:RegisterEvent("ENCOUNTER_START")
AQT:RegisterEvent("ENCOUNTER_END")
AQT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
AQT:RegisterEvent("QUEST_TURNED_IN")
AQT:RegisterEvent("QUEST_ACCEPTED")
AQT:RegisterEvent("QUEST_REMOVED")
AQT:RegisterEvent("UNIT_QUEST_LOG_CHANGED")

local t = 0
AQT.isDirty = true -- Update on load
AQT:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    
    -- Event-Driven Update (Throttled)
    if self.isDirty then
        AQT:FullUpdate()
        self.isDirty = false
        t = 0
        return
    end
    
    -- Periodic Update (Distances & Timers)
    if t > 1.0 then 
        AQT:FullUpdate()
        t = 0
    end
end)