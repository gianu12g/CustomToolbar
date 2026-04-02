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

-- Light Blue: soft, airy feel with sky-blue accents
local LightBlueTheme = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(220, 235, 250),
	slotBackgroundTransparency = 0.15,
	slotBorderColor = Color3.fromRGB(160, 195, 230),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(70, 160, 240),
	slotSelectedBorderColor = Color3.fromRGB(90, 180, 255),
	slotHoverColor = Color3.fromRGB(195, 220, 245),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(50, 70, 100),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(210, 228, 245),
	panelBackgroundTransparency = 0.1,
	panelCornerRadius = 10,
	panelColumns = 6,
}

-- Red: bold, dark look with crimson highlights
local RedTheme = {
	slotSize = 70,
	slotPadding = 6,
	slotCornerRadius = 10,
	slotBackgroundColor = Color3.fromRGB(45, 15, 15),
	slotBackgroundTransparency = 0.15,
	slotBorderColor = Color3.fromRGB(120, 40, 40),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(220, 40, 40),
	slotSelectedBorderColor = Color3.fromRGB(255, 70, 70),
	slotHoverColor = Color3.fromRGB(70, 25, 25),
	numberColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(230, 180, 180),
	iconColor = Color3.fromRGB(255, 255, 255),
	showToolName = false,
	panelBackgroundColor = Color3.fromRGB(35, 10, 10),
	panelBackgroundTransparency = 0.1,
	panelCornerRadius = 10,
	panelColumns = 6,
}

---------------------------------------------------------------------------
-- Start with the Light Blue theme
---------------------------------------------------------------------------
local toolbar = CustomToolbar.new({
	theme = LightBlueTheme,
	layout = {
		orientation = "Horizontal",
		position = UDim2.fromScale(0.5, 0.98),
		anchorPoint = Vector2.new(0.5, 1),
		maxVisibleSlots = 6,
	},
	keybindsEnabled = true,
	autoManageBackpack = true,
	backpackSlotCount = 18,
	dragHoldTime = 0.05,
})
toolbar:Mount()

---------------------------------------------------------------------------
-- After 10 seconds, live-swap to the Red theme via UpdateConfig
---------------------------------------------------------------------------
task.delay(10, function()
	toolbar:UpdateConfig({
		theme = RedTheme,
		layout = {
			orientation = "Horizontal",
			position = UDim2.fromScale(0.5, 0.98),
			anchorPoint = Vector2.new(0.5, 1),
			maxVisibleSlots = 6,
		},
		keybindsEnabled = true,
		autoManageBackpack = true,
		backpackSlotCount = 18,
		dragHoldTime = 0.05,
	})
end)
