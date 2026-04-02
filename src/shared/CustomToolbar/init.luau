--!strict
--[[
	CustomToolbar
	Drop-in replacement for Roblox's default backpack/hotbar.

	Usage:

		local CustomToolbar = require(path.to.CustomToolbar)

		-- Disable the default backpack
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

		-- Create with default settings (mirrors native look)
		local toolbar = CustomToolbar.new()
		toolbar:Mount()

		-- Or customise everything:
		local toolbar = CustomToolbar.new({
			theme = {
				slotSize = 70,
				slotSelectedColor = Color3.fromRGB(255, 170, 0),
				slotCornerRadius = 12,
				showToolName = false,
			},
			layout = {
				orientation = "Horizontal",
				position = UDim2.new(0.5, 0, 1, -20),
				maxVisibleSlots = 6,
			},
			keybindsEnabled = true,
			autoManageBackpack = true,
		})
		toolbar:Mount()

		-- Later, tear it down cleanly:
		toolbar:Destroy()

	API:
		CustomToolbar.new(config?) → ToolbarHandle
		ToolbarHandle:Mount()     → mounts the UI
		ToolbarHandle:Destroy()   → unmounts UI, cleans up
		ToolbarHandle:UpdateConfig(config) → live-update theme/layout

	Exports:
		CustomToolbar.Types   → type definitions
		CustomToolbar.Theme   → default theme table + mergeTheme()
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local Types = require(script.Types)
local Theme = require(script.Theme)
local ToolbarComponent = require(script.Toolbar)

export type ToolbarConfig = Types.ToolbarConfig
export type ThemeConfig = Types.ThemeConfig
export type LayoutConfig = Types.LayoutConfig
export type SlotData = Types.SlotData

----------------------------------------------------------------------
-- ToolbarHandle class
----------------------------------------------------------------------
local ToolbarHandle = {}
ToolbarHandle.__index = ToolbarHandle

function ToolbarHandle.new(config: Types.ToolbarConfig?)
	local self = setmetatable({}, ToolbarHandle)
	self._config = config or {} :: Types.ToolbarConfig
	self._root = nil :: any
	self._screenGui = nil :: ScreenGui?
	self._mounted = false
	return self
end

function ToolbarHandle:Mount()
	if self._mounted then
		warn("[CustomToolbar] Already mounted. Call :Destroy() first.")
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Disable native backpack
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CustomToolbar"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = (self._config.layout and self._config.layout.displayOrder) or 10
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	-- Mount React tree
	local element = React.createElement(ToolbarComponent, {
		config = self._config,
	})

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(element)
	self._mounted = true
end

function ToolbarHandle:UpdateConfig(config: Types.ToolbarConfig)
	self._config = config
	if self._mounted and self._root then
		local element = React.createElement(ToolbarComponent, {
			config = self._config,
		})
		self._root:render(element)
	end
end

function ToolbarHandle:Destroy()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	self._mounted = false
end

----------------------------------------------------------------------
-- Public module
----------------------------------------------------------------------
local CustomToolbar = {}

function CustomToolbar.new(config: Types.ToolbarConfig?): typeof(ToolbarHandle.new())
	return ToolbarHandle.new(config)
end

-- Re-exports for advanced usage
CustomToolbar.Types = Types
CustomToolbar.Theme = Theme
CustomToolbar.Component = ToolbarComponent

return CustomToolbar
