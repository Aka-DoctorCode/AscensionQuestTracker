-- AscensionCooldownManager (AscensionCooldownManager) - Core.lua
local addonName, AscensionCooldownManager = ...
local AceAddon = LibStub("AceAddon-3.0")
local Ascension = AceAddon:NewAddon(AscensionCooldownManager, addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Default configuration defining the rows structure
local defaults = {
    profile = {
        -- The "Box" settings
        containerPosition = { point = "BOTTOM", x = 0, y = 300 },
        padding = 0, -- Spacing between rows/icons

        -- Individual Row Configuration
        -- Row 1 is at the bottom, Row 2 is stacked on top, etc.
        rows = {
            [1] = {
                maxIcons = 6,      -- Number of abilities in this row
                iconSize = 40,     -- Base height of icons
                aspectRatio = 1.0, -- 1.0 = Square, 1.5 = Rectangle (Wide)
                spacing = 0        -- Spacing between icons in this row
            },
            [2] = {
                maxIcons = 4,
                iconSize = 50, -- Larger icons for important spells
                aspectRatio = 1.0,
                spacing = 0
            },
            [3] = {
                maxIcons = 2,
                iconSize = 30,     -- Smaller icons
                aspectRatio = 2.0, -- Very wide bars (e.g., for timers)
                spacing = 0
            },
        }
    }
}

function Ascension:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionDB", defaults, true)

    -- Create the Main "Box" Container
    self:CreateMainContainer()

    -- Render the layout based on config
    self:UpdateLayout()

    -- Register chat command to test/reload
    self:RegisterChatCommand("AscensionCooldownManager", "ChatCommand")
end

function Ascension:CreateMainContainer()
    -- This is the "Box" you requested.
    -- Anchor Point: BOTTOM (Center is implied by SetPoint logic)
    self.mainContainer = CreateFrame("Frame", "AscensionCooldownManager_MainContainer", UIParent)
    self.mainContainer:SetSize(1, 1) -- Size will be dynamic, but starts small

    -- Apply saved position
    local pos = self.db.profile.containerPosition
    self.mainContainer:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    -- Visual debug background (Remove later to follow Principle 1: Delete unnecessary)
    self.mainContainer.bg = self.mainContainer:CreateTexture(nil, "BACKGROUND")
    self.mainContainer.bg:SetAllPoints(true)
    self.mainContainer.bg:SetColorTexture(0, 1, 0, 0.2) -- Green transparent to see the box
end

function Ascension:UpdateLayout()
    local profile = self.db.profile
    local container = self.mainContainer
    local previousRowTop = 0 -- Y offset tracker

    -- Clear previous frames (pseudo-code for logic structure, assume frame recycling later)
    -- In a real scenario, we would hide existing frames and re-allocate from a pool.

    -- Iterate through configured rows
    for rowIndex, rowConfig in ipairs(profile.rows) do
        -- Calculate dimensions for this specific row
        local iconHeight = rowConfig.iconSize
        local iconWidth = iconHeight * rowConfig.aspectRatio
        local rowSpacing = rowConfig.spacing
        local numIcons = rowConfig.maxIcons

        -- Calculate Total Row Width to center it
        -- Width = (All Icons) + (All Spacings)
        local totalRowWidth = (iconWidth * numIcons) + (rowSpacing * (numIcons - 1))

        -- Starting X position (Leftmost point) to ensure Center alignment
        -- We move left by half the total width relative to the container center (0)
        local startX = -(totalRowWidth / 2)

        -- Create/Update icons for this row
        for i = 1, numIcons do
            -- Create a placeholder frame for the icon (Visual Test)
            -- Naming convention: AscensionCooldownManager_Row[X]_Icon[Y]
            local frameName = string.format("AscensionCooldownManager_Row%d_Icon%d", rowIndex, i)
            local iconFrame = _G[frameName] or CreateFrame("Frame", frameName, container)

            iconFrame:SetSize(iconWidth, iconHeight)

            -- Debug visual
            if not iconFrame.tex then
                iconFrame.tex = iconFrame:CreateTexture(nil, "OVERLAY")
                iconFrame.tex:SetAllPoints()
                iconFrame.tex:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- Dark Grey
            end

            -- ANCHORING LOGIC:
            -- X: startX + (index-1 * (width + space)) + (width / 2)
            -- We anchor the icon's CENTER to the calculated position
            local xOffset = startX + ((i - 1) * (iconWidth + rowSpacing)) + (iconWidth / 2)
            local yOffset = previousRowTop + (iconHeight / 2)

            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("CENTER", container, "BOTTOM", xOffset, yOffset)
        end

        -- Update Y tracker for the next row to sit on top of this one
        previousRowTop = previousRowTop + iconHeight + profile.padding
    end

    -- Update Main Container size to encompass all rows (optional, mostly for drag/drop later)
    -- The width is the max width found among rows, height is previousRowTop
    container:SetSize(200, previousRowTop)
end

function Ascension:ChatCommand(input)
    if input == "update" then
        self:UpdateLayout()
        print("AscensionCooldownManager: Layout Updated")
    else
        print("Use '/AscensionCooldownManager update' to refresh layout")
    end
end
