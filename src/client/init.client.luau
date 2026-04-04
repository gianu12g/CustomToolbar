--[[
	CustomToolbar — Client entry point.
	Swap between the bare-minimum mount and the fully themed example below.

	TOOL SETUP (in Studio or via server script):

		-- Rarity tier (drives border colour + animation speed)
		tool:SetAttribute("Rarity", "Epic")

		-- Optional: override the gradient preset for one specific tool
		tool:SetAttribute("OutlinePreset", "Toxic")

		-- Category (enables filter tabs in the backpack panel)
		tool:SetAttribute("Category", "Weapons")

	Built-in rarity tiers:
		Common, Uncommon, Rare, Epic, Legendary, Mythic

	Available gradient presets:
		"Rainbow", "Fire", "Ice", "Toxic", "Galaxy"

	Category tabs appear automatically in the backpack title bar
	whenever at least one tool has a Category attribute set.
	Only categories with items are shown. "All" is always first.
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
			--Mythic    = Color3.fromRGB(249, 68, 255),
			-- Divine = Color3.fromRGB(255, 255, 255), -- custom tier example
		},

		-- Rarity gradient presets (key = rarity name, value = preset name)
		-- Available presets: "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
		-- Omit a tier to use the default single-colour shine.
		-- Individual tools can override with: tool:SetAttribute("OutlinePreset", "Toxic")
		rarityPresets = {
			--Mythic    = "Rainbow",
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
	showEmptySlotBG = false,
	expandBackpack = true, -- true = grid scrolls when items exceed visible slots (panel stays fixed size)
	maxCategoryTabs = 10, -- max category tabs shown (excludes "All"); nil = default 4
})
toolbar:Mount()
