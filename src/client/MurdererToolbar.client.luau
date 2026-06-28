--!strict
--[[
	Client mount — MurdererToolbar

	Drives the hand-made StarterGui.MurdererGUI (the 4-slot diamond hotbar).
	One client script per toolbar module — see also TheHostToolbar.client.luau.

	The UI itself is built by hand in the place (StarterGui.MurdererGUI); this
	only adds behaviour. Tool → slot mapping:
	  • Give a Tool a numeric attribute to pin it:  tool:SetAttribute("Slot", 2)
	  • Tools without a "Slot" attribute fill the remaining slots in order.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MurdererToolbar = require(ReplicatedStorage.Shared.MurdererToolbar)

local toolbar = MurdererToolbar.new({
	-- guiName              = "MurdererGUI", -- name of the hand-made ScreenGui
	-- slotCount            = 4,

	-- Selected (equipped) slot look:
	selectedColor = Color3.fromRGB(255, 0, 0),
	selectedTransparency = 0.7,
	-- Unselected slot look:
	normalColor = Color3.fromRGB(255, 255, 255),
	normalTransparency = 0.9,

	keybindsEnabled = true, -- number keys 1-4
	clickToSelect = true, -- click / tap a slot
	autoManageBackpack = true, -- hide the native backpack
})

toolbar:Mount()
