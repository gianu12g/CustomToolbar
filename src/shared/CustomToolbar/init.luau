--!strict
--[[
	CustomToolbar
	Drop-in replacement for Roblox's default backpack/hotbar.

	─────────────────────────────────────────────────────────────
	QUICK START
	─────────────────────────────────────────────────────────────

		local CustomToolbar = require(path.to.CustomToolbar)

		-- Create with defaults (mirrors the native look) and mount
		local toolbar = CustomToolbar.new()
		toolbar:Mount()

	─────────────────────────────────────────────────────────────
	FULL EXAMPLE — theme, layout, rarity presets
	─────────────────────────────────────────────────────────────

		local toolbar = CustomToolbar.new({
			theme = {
				-- Slot appearance
				slotSize          = 70,
				slotCornerRadius  = 12,
				slotSelectedColor = Color3.fromRGB(255, 170, 0),
				showToolName      = false,

				-- Override rarity colours per tier
				rarityColors = {
					Legendary = Color3.fromRGB(255, 200, 50),
				},

				-- Assign gradient presets per rarity tier
				-- Available presets: "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
				rarityPresets = {
					Mythic    = "Rainbow",
					Legendary = "Fire",
					Epic      = "Galaxy",
					Rare      = "Ice",
				},
			},

			layout = {
				orientation   = "Horizontal",
				position      = UDim2.new(0.5, 0, 1, -20),
				maxVisibleSlots = 6,
			},

			keybindsEnabled    = true,
			autoManageBackpack = true,
		})
		toolbar:Mount()

	─────────────────────────────────────────────────────────────
	PER-TOOL PRESET OVERRIDE
	─────────────────────────────────────────────────────────────

	Any Tool instance can override its rarity tier's preset by
	setting an attribute in Studio or at runtime:

		tool:SetAttribute("OutlinePreset", "Toxic")

	This takes priority over the theme's rarityPresets mapping,
	so one Legendary sword can glow "Toxic" while every other
	Legendary uses "Fire".

	─────────────────────────────────────────────────────────────
	API
	─────────────────────────────────────────────────────────────

		CustomToolbar.new(config?)              → ToolbarHandle
		ToolbarHandle:Mount()                   → mounts UI to PlayerGui
		ToolbarHandle:UpdateConfig(config)      → live-update theme/layout
		ToolbarHandle:Destroy()                 → unmounts UI, cleans up

	─────────────────────────────────────────────────────────────
	RE-EXPORTS
	─────────────────────────────────────────────────────────────

		CustomToolbar.Types      → type definitions (ThemeConfig, SlotData, etc.)
		CustomToolbar.Theme      → default theme + mergeTheme() / scaleTheme()
		CustomToolbar.Component  → raw React component for advanced embedding
]]

---------------------------------------------------------------------------
-- Services & dependencies
---------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local Types = require(script.Types)
local Theme = require(script.Theme)
local ToolbarComponent = require(script.Toolbar)

-- Re-export types so consumers can do: local cfg: CustomToolbar.ToolbarConfig = { ... }
export type ToolbarConfig = Types.ToolbarConfig
export type ThemeConfig = Types.ThemeConfig
export type LayoutConfig = Types.LayoutConfig
export type SlotData = Types.SlotData

---------------------------------------------------------------------------
-- ToolbarHandle — controls the lifecycle of a single toolbar instance
---------------------------------------------------------------------------

local ToolbarHandle = {}
ToolbarHandle.__index = ToolbarHandle

--- Create a new (unmounted) toolbar handle.
--- Call :Mount() to render it, :Destroy() to tear it down.
function ToolbarHandle.new(config: Types.ToolbarConfig?)
	local self = setmetatable({}, ToolbarHandle)
	self._config = config or {} :: Types.ToolbarConfig
	self._root = nil :: any         -- ReactRoblox root
	self._screenGui = nil :: ScreenGui?
	self._mounted = false
	return self
end

--- Mount the toolbar into PlayerGui. Automatically disables the
--- native backpack so the two don't fight for input.
function ToolbarHandle:Mount()
	if self._mounted then
		warn("[CustomToolbar] Already mounted. Call :Destroy() first.")
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CustomToolbar"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = (self._config.layout and self._config.layout.displayOrder) or 10
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	local element = React.createElement(ToolbarComponent, {
		config = self._config,
	})
	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(element)
	self._mounted = true
end

--- Swap in a new config at runtime without unmounting.
--- Only the fields you provide are changed; everything else keeps
--- its current value until the next React render reconciles.
function ToolbarHandle:UpdateConfig(config: Types.ToolbarConfig)
	self._config = config
	if self._mounted and self._root then
		local element = React.createElement(ToolbarComponent, {
			config = self._config,
		})
		self._root:render(element)
	end
end

--- Unmount the React tree, destroy the ScreenGui, and release all
--- references. Safe to call multiple times.
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

---------------------------------------------------------------------------
-- Public module table
---------------------------------------------------------------------------

local CustomToolbar = {}

--- Convenience constructor — equivalent to ToolbarHandle.new(config).
function CustomToolbar.new(config: Types.ToolbarConfig?): typeof(ToolbarHandle.new())
	return ToolbarHandle.new(config)
end

-- Re-exports for advanced usage / composition
CustomToolbar.Types     = Types             -- type definitions
CustomToolbar.Theme     = Theme             -- default theme + merge helpers
CustomToolbar.Component = ToolbarComponent  -- raw React component

return CustomToolbar
