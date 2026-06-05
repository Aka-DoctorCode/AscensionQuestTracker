-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: WidgetProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local widgetData = {}
addonTable.dataEngine:registerModule("WidgetData", widgetData)

function widgetData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function widgetData:update()
    local topCenterID   = C_UIWidgetManager.GetTopCenterWidgetSetID()
    local belowMinimapID = C_UIWidgetManager.GetBelowMinimapWidgetSetID()

    -- Resolve setID->frame once here, avoiding duplicate C API calls inside processWidgetFrame
    local frameMap = {
        [topCenterID]    = UIWidgetTopCenterContainerFrame,
        [belowMinimapID] = UIWidgetBelowMinimapContainerFrame,
    }

    for _, widgetFrame in pairs(frameMap) do
        self:processWidgetFrame(widgetFrame)
    end
end

function widgetData:processWidgetFrame(widgetFrame)
    if not widgetFrame then return end
    local contentFrame = addonTable.ascensionTracker.contentFrame
    widgetFrame:SetParent(contentFrame)

    for _, region in ipairs({widgetFrame:GetRegions()}) do
        if region:IsObjectType("Texture") then
            region:SetAlpha(0)
        end
    end

    for _, child in ipairs({widgetFrame:GetChildren()}) do
        if not child:IsObjectType("StatusBar") then
            for _, region in ipairs({child:GetRegions()}) do
                if region:IsObjectType("Texture") then
                    region:SetAlpha(0)
                end
            end
        end
    end
end
