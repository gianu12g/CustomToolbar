--[[
	Demo client script for CustomToolbar.
	This shows basic usage — drop-in with zero config,
	or fully themed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomToolbar = require(ReplicatedStorage.Shared.CustomToolbar)

---------------------------------------------------------------------------
-- Option A: Zero-config (mirrors native Roblox backpack look)
---------------------------------------------------------------------------
-- local toolbar = CustomToolbar.new()
-- toolbar:Mount()

---------------------------------------------------------------------------
-- Option B: Fully themed (uncomment to try)
---------------------------------------------------------------------------
local toolbar = CustomToolbar.new({
	theme = {
		slotSize = 72,
		slotPadding = 6,
		slotCornerRadius = 12,
		slotBackgroundColor = Color3.fromRGB(20, 20, 30),
		slotBackgroundTransparency = 0.2,
		slotBorderColor = Color3.fromRGB(60, 60, 80),
		slotSelectedColor = Color3.fromRGB(255, 170, 0),
		slotSelectedBorderColor = Color3.fromRGB(255, 200, 50),
		slotHoverColor = Color3.fromRGB(40, 40, 55),
		showToolName = false,
		panelColumns = 6,
	},
	layout = {
		orientation = "Horizontal",
		position = UDim2.fromScale(0.5, 0.98),
		anchorPoint = Vector2.new(0.5, 1),
		maxVisibleSlots = 6,
	},
	keybindsEnabled = true,
	autoManageBackpack = true,
	backpackSlotCount = 24,
	dragHoldTime = 0,
})
toolbar:Mount()

---------------------------------------------------------------------------
-- Live-update example (call anytime to re-theme without remounting)
---------------------------------------------------------------------------
--[[
task.delay(10, function()
	toolbar:UpdateConfig({
		theme = {
			slotSelectedColor = Color3.fromRGB(0, 255, 100),
		},
	})
end)
]]
