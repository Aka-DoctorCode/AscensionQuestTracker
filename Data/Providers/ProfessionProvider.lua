-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: ProfessionProvider.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

-------------------------------------------------------------------------------
-- 1. INITIALIZATION
-------------------------------------------------------------------------------
local _, addonTable = ...

local professionData = {}
addonTable.dataEngine:registerModule("ProfessionData", professionData)

professionData.activeRecipes = {}

function professionData:init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("TRACKED_RECIPE_UPDATE")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:SetScript("OnEvent", function()
        if addonTable.dataEngine then
            addonTable.dataEngine:queueUpdate()
        end
    end)
end

function professionData:update()
    wipe(self.activeRecipes)

    local trackedRecipes = C_TradeSkillUI.GetRecipesTracked(false)
    if not trackedRecipes then return end

    for _, recipeID in ipairs(trackedRecipes) do
        self:parseRecipe(recipeID)
    end
end

function professionData:parseRecipe(recipeID)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not recipeInfo then return end

    -- GetRecipeSchematic is the correct 12.x API (GetRecipeRequirements does not exist)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    local reqList = {}

    if schematic and schematic.reagentSlotSchematics then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local reagent = slot.reagents and slot.reagents[1]
            local itemName = reagent and reagent.itemID and C_Item.GetItemNameByID(reagent.itemID) or ""
            local owned = reagent and reagent.itemID and C_Item.GetItemCount(reagent.itemID, true) or 0
            table.insert(reqList, {
                name = itemName,
                totalRequired = slot.quantityRequired or 0,
                totalOwned = owned,
            })
        end
    end

    table.insert(self.activeRecipes, {
        id = recipeID,
        name = recipeInfo.name,
        icon = recipeInfo.icon,
        requirements = reqList
    })
end
