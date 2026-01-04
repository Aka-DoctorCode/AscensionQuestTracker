local ADDON_NAME = "AscensionCooldownManager"
local ATS = CreateFrame("Frame")

-- Default settings
local DEFAULTS = {
    enabled = true,
    debug = false,
    perSpec = {} -- Stores format: [specID] = { ["raid"] = "LoadoutName", ... }
}

-- Database handling
local function EnsureDB()
    if type(AscensionCooldownManagerDB) ~= "table" then
        AscensionCooldownManagerDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if AscensionCooldownManagerDB[k] == nil then
            AscensionCooldownManagerDB[k] = v
        end
    end
end

-- Logging
local function Log(msg, ...)
    if AscensionCooldownManagerDB and AscensionCooldownManagerDB.debug then
        print("|cff00ccff[AscensionCooldownManager]|r:", msg, ...)
    end
end

-- Wrapper de Compatibilidad para WoW 11.0.7+
local function GetConfigInfo(configID)
    if not configID then return nil end
    if C_Traits and C_Traits.GetConfigInfo then
        return C_Traits.GetConfigInfo(configID)
    end
    if C_ClassCooldown and C_ClassCooldown.GetConfigInfo then
        return C_ClassCooldown.GetConfigInfo(configID)
    end
    return nil
end

local function CanSwapCooldown()
    if InCombatLockdown() then return false end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return false end
    return true
end

local function GetCurrentContext()
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        if instanceType == "pvp" or instanceType == "arena" then
            return "pvp"
        elseif instanceType == "raid" then
            local isLegacy = false
            if C_Loot and C_Loot.IsLegacyLootModeEnabled then isLegacy = C_Loot.IsLegacyLootModeEnabled() end
            return isLegacy and "raid_legacy" or "raid"
        elseif instanceType == "party" then
            return "dungeons"
        elseif instanceType == "scenario" then
            return "delve"
        end
    end
    return "world"
end

local function GetActiveLoadout()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, nil end
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil, nil end

    -- Intentamos obtener el ID activo real
    local activeConfigID = C_ClassCooldown.GetActiveConfigID()

    -- Si es nil (por cambios sin guardar), usamos el último guardado conocido
    if not activeConfigID then
        activeConfigID = C_ClassCooldown.GetLastSelectedSavedConfigID(specID)
    end

    if activeConfigID then
        local info = GetConfigInfo(activeConfigID)
        return activeConfigID, (info and info.name) or nil
    end
    return nil, nil
end

local function FindLoadoutIDByName(targetName)
    if not targetName or targetName == "" then return nil end
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local specID = GetSpecializationInfo(specIndex)

    local configIDs = C_ClassCooldown.GetConfigIDsBySpecID(specID)
    if not configIDs then return nil end

    for _, configID in ipairs(configIDs) do
        local info = GetConfigInfo(configID)
        -- Comparamos nombres ignorando mayúsculas/minúsculas
        if info and info.name and string.lower(info.name) == string.lower(targetName) then
            return configID
        end
    end
    return nil
end

-- Core Logic
local lastContextSignature = nil

local function CheckAndPromptSwitch(force)
    -- 1. Ensure DB exists before reading 'enabled'
    if not AscensionTalentDB_V2 or not AscensionTalentDB_V2.enabled then return end
    if not CanSwapCooldown() then return end

    local context = GetCurrentContext()
    local specIndex = GetSpecialization()
    if not specIndex then return end

    local specID = GetSpecializationInfo(specIndex)
    -- 2. Added nil check for specID to prevent indexing nil later
    if not specID then return end

    -- 3. Robust nil check for nested table initialization
    if not AscensionTalentDB_V2.perSpec then
        AscensionTalentDB_V2.perSpec = {}
    end

    if not AscensionTalentDB_V2.perSpec[specID] then
        AscensionTalentDB_V2.perSpec[specID] = {}
    end
    -- AscensionTalentDB_V2.perSpec[specID] = AscensionTalentDB_V2.perSpec[specID] or {}

    local desiredLoadoutName = AscensionTalentDB_V2.perSpec[specID][context]
    if not desiredLoadoutName or desiredLoadoutName == "" or desiredLoadoutName == "-" then return end

    local activeID, activeName = GetActiveLoadout()
    local desiredID = FindLoadoutIDByName(desiredLoadoutName)

    if not desiredID then return end -- Loadout no existe (borrado o renombrado)

    -- Si ya estamos en el loadout deseado, no hacer nada
    if activeID == desiredID and not force then return end

    -- Evitar spam del prompt si ya se mostró para esta situación
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local currentSignature = string.format("%s:%s:%s", context, tostring(mapID), tostring(desiredID))

    if not force and lastContextSignature == currentSignature then return end
    lastContextSignature = currentSignature

    if ATS_ShowSwitchPrompt then
        ATS_ShowSwitchPrompt(context, activeName, desiredLoadoutName, desiredID)
    end
end

-- Events
ATS:RegisterEvent("PLAYER_LOGIN")
ATS:RegisterEvent("PLAYER_ENTERING_WORLD")
ATS:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ATS:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ATS:RegisterEvent("PLAYER_REGEN_ENABLED")

ATS:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        if ATS_InitUI then ATS_InitUI() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.5, function() CheckAndPromptSwitch(false) end)
    else
        C_Timer.After(1.5, function() CheckAndPromptSwitch(false) end)
    end
end)

-- Slash Commands
SLASH_AscensionCooldownManager1 = "/ats"
SLASH_AscensionCooldownManager2 = "/AscensionCooldownManager"

SlashCmdList["AscensionCooldownManager"] = function(msg)
    local cmd = msg:lower()
    if cmd == "debug" then
        if AscensionTalentDB_V2 then
            AscensionTalentDB_V2.debug = not AscensionTalentDB_V2.debug
            print("Ascension Debug:", AscensionTalentDB_V2.debug)
        end
    elseif cmd == "check" then
        lastContextSignature = nil
        print("Ascension: Checking Cooldown...")
        CheckAndPromptSwitch(true)
    else
        if ATS_ToggleConfig then ATS_ToggleConfig() end
    end
end
