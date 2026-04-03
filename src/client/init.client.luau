--[[
	CustomToolbar — Client entry point.
	Swap between the bare-minimum mount and the fully themed example below.

	TOOL SETUP (in Studio or via server script):

		-- Rarity tier (drives border colour + animation speed)
		tool:SetAttribute("Rarity", "Epic")

		-- Optional: override the gradient preset for one specific tool
		tool:SetAttribute("OutlinePreset", "Toxic")

	Built-in rarity tiers:
		Common, Uncommon, Rare, Epic, Legendary, Mythic

	Available gradient presets:
		"Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomToolbar = require(ReplicatedStorage.Shared.CustomToolbar)

---------------------------------------------------------------------------
-- 1) ZERO-CONFIG — mirrors the native Roblox backpack look
---------------------------------------------------------------------------
-- local toolbar = CustomToolbar.new()
-- toolbar:Mount()

local toolbar = CustomToolbar.new({

	----- THEME -----
	-- Controls all visual styling. Every field is optional;
	-- anything you leave out falls back to the built-in default.
	theme = {

		-- Slot appearance
		slotSize = 70, -- pixel size of each slot square
		slotPadding = 6, -- gap between slots (pixels)
		slotCornerRadius = 10, -- rounded corner radius (pixels)
		slotBackgroundColor = Color3.fromRGB(28, 34, 44),
		slotBackgroundTransparency = 0.05, -- 0 = opaque, 1 = invisible
		slotBorderColor = Color3.fromRGB(72, 96, 130), -- default border (non-rarity)
		slotBorderWidth = 2, -- border thickness (pixels)
		slotSelectedColor = Color3.fromRGB(70, 130, 220), -- background when selected
		slotSelectedBorderColor = Color3.fromRGB(120, 170, 255), -- border when selected
		slotHoverColor = Color3.fromRGB(40, 50, 64), -- background on hover

		-- Number badge (top-left of hotbar slots)
		showSlotNumbers = true, -- show 1-9 labels
		numberFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		numberColor = Color3.fromRGB(255, 255, 255),
		numberSize = 12,

		-- Tool name label (bottom of slot)
		showToolName = false, -- toggle name visibility
		nameFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
		nameColor = Color3.fromRGB(220, 230, 245),
		nameSize = 10,

		-- Tool icon
		iconSizeScale = 0.65, -- 0–1, fraction of slot size
		iconColor = Color3.fromRGB(255, 255, 255),

		-- Backpack toggle button
		backpackButtonIcon = "rbxasset://textures/ui/TopBar/inventoryOn.png",
		backpackButtonSize = 45,

		-- Backpack panel (grid that opens when you click the button)
		panelBackgroundColor = Color3.fromRGB(18, 22, 30),
		panelBackgroundTransparency = 0.02,
		panelCornerRadius = 10,
		panelColumns = 7, -- columns in the backpack grid

		-- Animations
		selectAnimationSpeed = 0.15, -- seconds for selection tween
		hoverAnimationSpeed = 0.1, -- seconds for hover tween

		-- Rarity border colours (key = Tool:GetAttribute("Rarity") value)
		-- Only override the ones you want — the rest keep defaults.
		rarityColors = {
			-- Common    = Color3.fromRGB(180, 180, 180),
			-- Uncommon  = Color3.fromRGB(80, 200, 80),
			-- Rare      = Color3.fromRGB(70, 130, 255),
			-- Epic      = Color3.fromRGB(180, 70, 255),
			-- Legendary = Color3.fromRGB(255, 170, 0),
			-- Mythic    = Color3.fromRGB(255, 50, 50),
			-- Divine = Color3.fromRGB(255, 255, 255), -- custom tier example
		},

		-- Rarity gradient presets (key = rarity name, value = preset name)
		-- Available presets: "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
		-- Omit a tier to use the default single-colour shine.
		-- Individual tools can override with: tool:SetAttribute("OutlinePreset", "Toxic")
		rarityPresets = {
			-- Mythic    = "Rainbow",
			-- Legendary = "Fire",
			-- Epic      = "Galaxy",
			-- Rare      = "Ice",
			-- Uncommon intentionally omitted → uses default shine
			-- Common has no animation regardless
		},
	},

	----- LAYOUT -----
	-- Controls positioning and slot count.
	layout = {
		orientation = "Horizontal", -- "Horizontal" or "Vertical"
		position = UDim2.fromScale(0.5, 0.98), -- screen position
		anchorPoint = Vector2.new(0.5, 1), -- anchor relative to position
		maxVisibleSlots = 6, -- hotbar slot count
		displayOrder = 10, -- ScreenGui.DisplayOrder
	},

	----- BEHAVIOUR -----
	autoManageBackpack = true, -- auto-sync tools from player.Backpack
	keybindsEnabled = true, -- 1-9 number key shortcuts
	gamepadEnabled = true, -- bumper scroll on gamepad
	backpackSlotCount = 18, -- total cells in the backpack panel
	dragHoldTime = 0.5, -- seconds to hold before drag starts (backpack closed)
	dragHoldTimeOpen = 0.05, -- seconds to hold before drag starts (backpack open)
})
toolbar:Mount()

---------------------------------------------------------------------------
-- 2) FULLY THEMED — uncomment this block and comment out the above
--    to see every available setting with explanations
---------------------------------------------------------------------------

--[[

---------------------------------------------------------------------------
-- Theme presets (pick one, or make your own)
---------------------------------------------------------------------------

-- Slate Blue: clean, modern, high contrast
local SlateBlueTheme: CustomToolbar.ThemeConfig = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(28, 34, 44),
	slotBackgroundTransparency = 0.05,
	slotBorderColor = Color3.fromRGB(72, 96, 130),
	slotBorderWidth = 2,
	slotSelectedColor = Color3.fromRGB(70, 130, 220),
	slotSelectedBorderColor = Color3.fromRGB(120, 170, 255),
	slotHoverColor = Color3.fromRGB(40, 50, 64),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(220, 230, 245),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(18, 22, 30),
	panelBackgroundTransparency = 0.02,
	panelCornerRadius = 10,
	panelColumns = 6,
}

-- Frost Blue: brighter, airy
local FrostBlueTheme: CustomToolbar.ThemeConfig = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(52, 66, 84),
	slotBackgroundTransparency = 0.08,
	slotBorderColor = Color3.fromRGB(110, 150, 205),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(90, 170, 255),
	slotSelectedBorderColor = Color3.fromRGB(180, 220, 255),
	slotHoverColor = Color3.fromRGB(68, 84, 106),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(235, 243, 255),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(34, 42, 56),
	panelBackgroundTransparency = 0.04,
	panelCornerRadius = 10,
	panelColumns = 6,
}

-- Crimson Black: deep red, high contrast
local CrimsonBlackTheme: CustomToolbar.ThemeConfig = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(30, 16, 18),
	slotBackgroundTransparency = 0.04,
	slotBorderColor = Color3.fromRGB(110, 48, 56),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(200, 52, 72),
	slotSelectedBorderColor = Color3.fromRGB(255, 110, 130),
	slotHoverColor = Color3.fromRGB(46, 22, 26),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(245, 220, 225),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(18, 10, 12),
	panelBackgroundTransparency = 0.02,
	panelCornerRadius = 10,
	panelColumns = 6,
}

-- Emerald Dark: rich green, easy on the eyes
local EmeraldDarkTheme: CustomToolbar.ThemeConfig = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(20, 34, 30),
	slotBackgroundTransparency = 0.05,
	slotBorderColor = Color3.fromRGB(56, 120, 98),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(46, 190, 140),
	slotSelectedBorderColor = Color3.fromRGB(120, 255, 200),
	slotHoverColor = Color3.fromRGB(28, 48, 42),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(220, 245, 235),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(12, 22, 20),
	panelBackgroundTransparency = 0.02,
	panelCornerRadius = 10,
	panelColumns = 6,
}

-- Gold Night: warm premium feel
local GoldNightTheme: CustomToolbar.ThemeConfig = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(34, 28, 18),
	slotBackgroundTransparency = 0.04,
	slotBorderColor = Color3.fromRGB(130, 102, 42),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(220, 170, 60),
	slotSelectedBorderColor = Color3.fromRGB(255, 220, 120),
	slotHoverColor = Color3.fromRGB(48, 40, 24),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(245, 235, 205),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(20, 16, 10),
	panelBackgroundTransparency = 0.02,
	panelCornerRadius = 10,
	panelColumns = 6,
}

-- Violet Steel: cool purple, stylish
local VioletSteelTheme: CustomToolbar.ThemeConfig = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(30, 26, 40),
	slotBackgroundTransparency = 0.05,
	slotBorderColor = Color3.fromRGB(96, 78, 140),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(150, 95, 255),
	slotSelectedBorderColor = Color3.fromRGB(200, 160, 255),
	slotHoverColor = Color3.fromRGB(42, 36, 56),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(235, 228, 250),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(18, 14, 24),
	panelBackgroundTransparency = 0.02,
	panelCornerRadius = 10,
	panelColumns = 6,
}

---------------------------------------------------------------------------
-- Pick a theme and mount with every available setting
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Theme cycling demo (uncomment to preview all themes in a loop)
---------------------------------------------------------------------------
-- local themes = {
-- 	SlateBlueTheme,
-- 	FrostBlueTheme,
-- 	CrimsonBlackTheme,
-- 	EmeraldDarkTheme,
-- 	GoldNightTheme,
-- 	VioletSteelTheme,
-- }
--
-- task.spawn(function()
-- 	local index = 1
-- 	while true do
-- 		toolbar:UpdateConfig({
-- 			theme = themes[index],
-- 			layout = {
-- 				orientation = "Horizontal",
-- 				position = UDim2.fromScale(0.5, 0.98),
]]
