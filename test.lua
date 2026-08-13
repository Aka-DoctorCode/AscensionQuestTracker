C_Timer = {
    After = function(t, cb) cb() end,
    NewTimer = function(t, cb) return {Cancel = function() end} end
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 0 end
}
function CreateFrame(t, n, p, tp)
    return {
        RegisterEvent = function(...) end,
        SetScript = function(...) end,
        GetFrameLevel = function() return 1 end,
        SetHeight = function() end,
        GetWidth = function() return 250 end,
        CreateFontString = function() return {SetPoint = function() end, SetJustifyH = function() end} end
    }
end
function CreateFramePool() return {ReleaseAll = function() end, Acquire = function() return {Show=function()end} end} end
function CreateObjectPool(c, r) return {ReleaseAll = function() end, Acquire = function() return c() end} end
function unpack(t) return 1,2,3 end
addonTable = {
    ascensionTracker = {
        contentFrame = CreateFrame()
    },
    config = { db = { profile = { automation = { autoCollapseAll = false } } } }
}
function pcall(cb, ...) return cb(...) end

assert(loadfile("/Applications/World of Warcraft/_retail_/Interface/AddOns/AscensionQuestTracker/Data/DataEngine.lua"))(nil, addonTable)
addonTable.dataEngine:init()
addonTable.dataEngine:handleEvent("QUEST_TURNED_IN")

print("SUCCESS")
