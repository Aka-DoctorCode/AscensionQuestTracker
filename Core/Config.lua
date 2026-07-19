-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: Config.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local config = {}
addonTable.config = config

function config:init()
    local defaults = {
        profile = {
            position = {
                x = -300,
                y = -200,
                anchor = "TOPRIGHT",
                useEditMode = true,
                showMoveFrame = false,
            },
            sizing = {
                maxHeight = 600,
                maxWidth = 250,
                blockPadding = 5,
                linePadding = 2,
            },
            typography = {
                font = "Friz Quadrata TT",
                headerSize = 14,
                titleSize = 12,
                bodySize = 10,
                fontFlag = "OUTLINE",
                dropShadow = true,
                shadowX = 1,
                shadowY = -1,
            },
            automation = {
                hideNativeTracker = true,
                hideInCombat = false,
                hideInInstanced = false,
                hideInPvP = false,
                focusMode = false,
                autoCollapseAll = false,
            },
            colors = {
                header = {1.0, 0.82, 0.0, 1},
                title = {1.0, 0.82, 0.0, 1},
                active = {0.8, 0.8, 0.8, 1},
                complete = {0.1, 1.0, 0.1, 1},
                failed = {1.0, 0.1, 0.1, 1},
                backgroundAlpha = 0,
            }
        }
    }

    if LibStub and LibStub("AceDB-3.0", true) then
        self.db = LibStub("AceDB-3.0"):New("AscensionQuestTrackerDB", defaults, true)
    else
        self.db = { 
            profile = defaults.profile,
            keys = {},
            sv = {},
            defaults = defaults,
            parent = {}
        }
    end

    local lib = LibStub and LibStub("AscensionSuit-UI", true)
    if lib then
        local ctx = lib:CreateContext()

        local buildFuncs = {
            function(panel) -- General
                local layout = lib.LayoutModel:new(ctx)
                layout:reset(panel.content, -15)
                layout:header("generalHeader", "General & Spatial Layout")
                layout:checkbox("useEditMode", "Unlock in Edit Mode", nil,
                    function() return self.db.profile.position.useEditMode end,
                    function(v) self.db.profile.position.useEditMode = v end
                )
                layout:checkbox("showMoveFrame", "Always Show Drag Handle", "Show the drag handle consistently. If off, only shows on hover.",
                    function() return self.db.profile.position.showMoveFrame end,
                    function(v)
                        self.db.profile.position.showMoveFrame = v
                    end
                )
                layout:slider("maxHeight", "Maximum Height", 300, 1400, 10,
                    function() return self.db.profile.sizing.maxHeight end,
                    function(v)
                        self.db.profile.sizing.maxHeight = v
                        if addonTable.dataEngine then
                            addonTable.dataEngine:queueUpdate()
                        end
                    end
                )
                layout:slider("maxWidth", "Frame Width", 150, 600, 10,
                    function() return self.db.profile.sizing.maxWidth end,
                    function(v)
                        self.db.profile.sizing.maxWidth = v
                        if addonTable.ascensionTracker and addonTable.ascensionTracker.updateWidth then
                            addonTable.ascensionTracker:updateWidth(v)
                        end
                        if addonTable.dataEngine then
                            addonTable.dataEngine:queueUpdate()
                        end
                    end
                )
            end,
            function(panel) -- Appearance
                local layout = lib.LayoutModel:new(ctx)
                layout:reset(panel.content, -15)
                layout:header("appearanceHeader", "Appearance & Typography")
                layout:dropdown("fontPicker", "Font",
                    { {label = "Friz Quadrata TT", value = "Friz Quadrata TT"} },
                    function() return self.db.profile.typography.font end,
                    function(v) self.db.profile.typography.font = v end
                )
                layout:slider("titleSize", "Title Font Size", 8, 24, 1,
                    function() return self.db.profile.typography.titleSize end,
                    function(v) 
                        self.db.profile.typography.titleSize = v 
                        if addonTable.dataEngine then addonTable.dataEngine:queueUpdate() end
                    end
                )
                layout:slider("headerSize", "Section Header Font Size", 8, 24, 1,
                    function() return self.db.profile.typography.headerSize end,
                    function(v) 
                        self.db.profile.typography.headerSize = v 
                        if addonTable.dataEngine then addonTable.dataEngine:queueUpdate() end
                    end
                )
                layout:slider("bodySize", "Objective Font Size", 8, 24, 1,
                    function() return self.db.profile.typography.bodySize end,
                    function(v) 
                        self.db.profile.typography.bodySize = v 
                        if addonTable.dataEngine then addonTable.dataEngine:queueUpdate() end
                    end
                )
                -- Pass nil tooltip explicitly so the swap inside LayoutModel does not fire and corrupt setter
                layout:colorPicker("headerColor", "Zone Headers", nil,
                    function() return unpack(self.db.profile.colors.header) end,
                    function(r, g, b, a) self.db.profile.colors.header = {r, g, b, a} end,
                    nil, true
                )
                layout:colorPicker("completeColor", "Completion State", nil,
                    function() return unpack(self.db.profile.colors.complete) end,
                    function(r, g, b, a) self.db.profile.colors.complete = {r, g, b, a} end,
                    nil, true
                )
                layout:slider("backgroundAlpha", "Background Alpha", 0, 100, 5,
                    function() return math.floor((self.db.profile.colors.backgroundAlpha or 0) * 100) end,
                    function(v) 
                        self.db.profile.colors.backgroundAlpha = v / 100
                        if addonTable.ascensionTracker and addonTable.ascensionTracker.updateBackground then
                            addonTable.ascensionTracker:updateBackground()
                        end
                    end
                )
            end,
            function(panel) -- Automation
                local layout = lib.LayoutModel:new(ctx)
                layout:reset(panel.content, -15)
                layout:header("automationHeader", "Automation & Visibility")
                layout:checkbox("hideNativeTracker", "Hide Blizzard Tracker", "Hide the default in-game objective tracker. Requires /reload.",
                    function() return self.db.profile.automation.hideNativeTracker end,
                    function(v) 
                        self.db.profile.automation.hideNativeTracker = v 
                        if not StaticPopupDialogs["ASCENSION_TRACKER_RELOAD"] then
                            StaticPopupDialogs["ASCENSION_TRACKER_RELOAD"] = {
                                text = "Changing the Blizzard Tracker visibility requires a UI reload. Reload now?",
                                button1 = "Yes",
                                button2 = "No",
                                OnAccept = function()
                                    ReloadUI()
                                end,
                                timeout = 0,
                                whileDead = true,
                                hideOnEscape = true,
                                preferredIndex = 3,
                            }
                        end
                        StaticPopup_Show("ASCENSION_TRACKER_RELOAD")
                    end
                )
                layout:checkbox("hideInCombat", "Hide in Combat", nil,
                    function() return self.db.profile.automation.hideInCombat end,
                    function(v) self.db.profile.automation.hideInCombat = v end
                )
                layout:checkbox("hideInInstanced", "Auto-Collapse in Dungeons", nil,
                    function() return self.db.profile.automation.hideInInstanced end,
                    function(v) self.db.profile.automation.hideInInstanced = v end
                )
                layout:checkbox("autoCollapseAll", "Auto Collapse Blizzard Tracker", "Automatically collapse the native Blizzard tracker on load.",
                    function() return self.db.profile.automation.autoCollapseAll end,
                    function(v) 
                        self.db.profile.automation.autoCollapseAll = v
                        if v and ObjectiveTrackerFrame and ObjectiveTrackerFrame.SetCollapsed then
                            ObjectiveTrackerFrame:SetCollapsed(true)
                        elseif not v and ObjectiveTrackerFrame and ObjectiveTrackerFrame.SetCollapsed then
                            ObjectiveTrackerFrame:SetCollapsed(false)
                        end
                    end
                )
                layout:checkbox("hideInPvP", "Hide in Instanced PvP", nil,
                    function() return self.db.profile.automation.hideInPvP end,
                    function(v) self.db.profile.automation.hideInPvP = v end
                )
                layout:checkbox("focusMode", "Focus Mode", nil,
                    function() return self.db.profile.automation.focusMode end,
                    function(v) self.db.profile.automation.focusMode = v end
                )
            end,
            function(panel) -- Content
                local layout = lib.LayoutModel:new(ctx)
                layout:reset(panel.content, -15)
                layout:header("contentHeader", "Content Tracking Matrix")
                layout:checkbox("trackCampaign", "Campaign Quests", nil, function() return true end, function() end)
                layout:checkbox("trackWorldQuests", "World Quests & Bonus Objectives", nil, function() return true end, function() end)
                layout:checkbox("trackAchievements", "Achievements", nil, function() return true end, function() end)
                layout:checkbox("trackProfessions", "Profession Reagents & Recipes", nil, function() return true end, function() end)
                layout:checkbox("trackTradingPost", "Trading Post / Traveler's Log", nil, function() return true end, function() end)
            end,
            function(panel) -- Database
                local layout = lib.LayoutModel:new(ctx)
                layout:reset(panel.content, -15)
                layout:header("databaseHeader", "Database & Profiles")
                layout:label("dbInfo", "Profile management is handled by AceDB.")
            end,
        }

        self.frame = ctx:createMainFrame({
            name = "AscensionQuestTrackerConfig",
            title = "Ascension Quest Tracker",
            tabNames = { "General", "Appearance", "Automation", "Content", "Database" },
            tabFuncs = buildFuncs,
            width = 600,
            height = 500
        })

        if lib.Integration and lib.Integration.registerBlizzardPanel then
            lib.Integration:registerBlizzardPanel(
                "AscensionQuestTracker",
                "Ascension Tracker",
                function() self.frame:Show() end
            )
        end
    end

    SLASH_AQT1 = "/aqt"
    SlashCmdList["AQT"] = function()
        if self.frame then
            self.frame:Show()
        end
    end
end

