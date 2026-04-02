--[[
	Demo client script for CustomToolbar.
	This shows basic usage — drop-in with zero config,
	or fully themed. Includes preset themes and a live UpdateConfig demo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomToolbar = require(ReplicatedStorage.Shared.CustomToolbar)

---------------------------------------------------------------------------
-- Theme presets
---------------------------------------------------------------------------

-- Slate Blue: clean, modern, high contrast
local SlateBlueTheme = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(28, 34, 44),
	slotBackgroundTransparency = 0.05,
	slotBorderColor = Color3.fromRGB(72, 96, 130),
	slotBorderWidth = 1,
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

-- Frost Blue: brighter blue theme, but with much better readability
local FrostBlueTheme = {
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

-- Crimson Black: stronger version of your red theme
local CrimsonBlackTheme = {
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

-- Emerald Dark: readable and rich without being too saturated
local EmeraldDarkTheme = {
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

-- Gold Night: strong contrast, premium-looking
local GoldNightTheme = {
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

-- Violet Steel: stylish but still very legible
local VioletSteelTheme = {
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
-- Start with the Light Blue theme
---------------------------------------------------------------------------
local toolbar = CustomToolbar.new({
	theme = SlateBlueTheme,
	layout = {
		orientation = "Horizontal",
		position = UDim2.fromScale(0.5, 0.98),
		anchorPoint = Vector2.new(0.5, 1),
		maxVisibleSlots = 6,
	},
	keybindsEnabled = true,
	autoManageBackpack = true,
	backpackSlotCount = 18,
	dragHoldTime = 0.5,
	dragHoldTimeOpen = 0.05,
})
toolbar:Mount()

---------------------------------------------------------------------------
-- Cycle themes every 2 seconds for recording
---------------------------------------------------------------------------
-- local themes = {
-- 	SlateBlueTheme,
-- 	FrostBlueTheme,
-- 	CrimsonBlackTheme,
-- 	EmeraldDarkTheme,
-- 	GoldNightTheme,
-- 	VioletSteelTheme,
-- }

-- task.spawn(function()
-- 	local index = 1

-- 	while true do
-- 		toolbar:UpdateConfig({
-- 			theme = themes[index],
-- 			layout = {
-- 				orientation = "Horizontal",
-- 				position = UDim2.fromScale(0.5, 0.98),
-- 				anchorPoint = Vector2.new(0.5, 1),
-- 				maxVisibleSlots = 6,
-- 			},
-- 			keybindsEnabled = true,
-- 			autoManageBackpack = true,
-- 			backpackSlotCount = 18,
-- 			dragHoldTime = 0.05,
-- 		})

-- 		index += 1
-- 		if index > #themes then
-- 			index = 1
-- 		end

-- 		task.wait(2)
-- 	end
-- end)
