--!strict
--[[
	CustomToolbar – Theme
	Provides sensible defaults that closely match Roblox's native backpack bar,
	plus a deepMerge helper so consumers only override what they care about.
]]

local Types = require(script.Parent.Types)

local DEFAULT_RARITY_COLORS: { [string]: Color3 } = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(80, 200, 80),
	Rare      = Color3.fromRGB(70, 130, 255),
	Epic      = Color3.fromRGB(180, 70, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic    = Color3.fromRGB(255, 50, 50),
}

-- Default outline preset per rarity tier.
-- nil / absent = use the single-colour shine gradient.
-- Valid values: "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
local DEFAULT_RARITY_PRESETS: { [string]: string } = {
	Mythic = "Rainbow",
}

local DEFAULT_THEME: Types.ThemeConfig = {
	-- Slot visuals
	slotSize = 65,
	slotPadding = 5,
	slotCornerRadius = 8,
	slotBackgroundColor = Color3.fromRGB(31, 31, 31),
	slotBackgroundTransparency = 0.3,
	slotBorderColor = Color3.fromRGB(85, 85, 85),
	slotBorderWidth = 1,
	slotSelectedColor = Color3.fromRGB(0, 162, 255),
	slotSelectedBorderColor = Color3.fromRGB(0, 200, 255),
	slotHoverColor = Color3.fromRGB(50, 50, 50),

	-- Number label (top-left corner of slot)
	numberFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	numberColor = Color3.fromRGB(220, 220, 220),
	numberSize = 12,
	showSlotNumbers = true,

	-- Tool name label (below icon)
	nameFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	nameColor = Color3.fromRGB(200, 200, 200),
	nameSize = 10,
	showToolName = true,

	-- Icon
	iconSizeScale = 0.65,
	iconColor = Color3.fromRGB(255, 255, 255),

	-- Backpack button
	backpackButtonIcon = "rbxasset://textures/ui/TopBar/inventoryOn.png",
	backpackButtonSize = 45,

	-- Backpack panel
	panelBackgroundColor = Color3.fromRGB(25, 25, 25),
	panelBackgroundTransparency = 0.15,
	panelCornerRadius = 10,
	panelColumns = 7,

	-- Rarity
	rarityColors = DEFAULT_RARITY_COLORS,
	rarityPresets = DEFAULT_RARITY_PRESETS,

	-- Category tabs
	categoryTabFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
	categoryTabColor = Color3.fromRGB(150, 150, 150),
	categoryTabActiveColor = Color3.fromRGB(255, 255, 255),
	categoryTabUnderlineColor = Color3.fromRGB(0, 162, 255),
	categoryTabSize = 12,

	-- Animations
	selectAnimationSpeed = 0.15,
	hoverAnimationSpeed = 0.1,
}

local DEFAULT_LAYOUT: Types.LayoutConfig = {
	orientation = "Horizontal",
	position = UDim2.new(0.5, 0, 1, -12),
	anchorPoint = Vector2.new(0.5, 1),
	maxVisibleSlots = 9,
	displayOrder = 10,
}

local Theme = {}

-- Shallow merge: overrides win, nils fall back to default.
-- rarityColors is deep-merged so partial overrides preserve defaults.
function Theme.mergeTheme(overrides: Types.ThemeConfig?): Types.ThemeConfig
	if not overrides then
		return table.clone(DEFAULT_THEME)
	end
	local merged = table.clone(DEFAULT_THEME)
	for key, value in overrides :: any do
		if key == "rarityColors" and type(value) == "table" then
			local base = table.clone(DEFAULT_RARITY_COLORS)
			for name, color in value :: any do
				base[name] = color
			end
			(merged :: any)[key] = base
		elseif key == "rarityPresets" and type(value) == "table" then
			local base = table.clone(DEFAULT_RARITY_PRESETS)
			for name, preset in value :: any do
				base[name] = preset
			end
			(merged :: any)[key] = base
		else
			(merged :: any)[key] = value
		end
	end
	return merged
end

function Theme.mergeLayout(overrides: Types.LayoutConfig?): Types.LayoutConfig
	if not overrides then
		return table.clone(DEFAULT_LAYOUT)
	end
	local merged = table.clone(DEFAULT_LAYOUT)
	for key, value in overrides :: any do
		(merged :: any)[key] = value
	end
	return merged
end

---------------------------------------------------------------------------
-- Viewport-based scaling
---------------------------------------------------------------------------

Theme.REFERENCE_WIDTH = 1366
Theme.REFERENCE_HEIGHT = 768

--- Compute a uniform scale factor from viewport size.
function Theme.computeScale(viewportSize: Vector2): number
	local sx = viewportSize.X / Theme.REFERENCE_WIDTH
	local sy = viewportSize.Y / Theme.REFERENCE_HEIGHT
	return math.min(sx, sy)
end

-- Pixel-valued keys that should be scaled with viewport size.
local SCALABLE_KEYS: { [string]: boolean } = {
	slotSize = true,
	slotPadding = true,
	slotCornerRadius = true,
	slotBorderWidth = true,
	numberSize = true,
	nameSize = true,
	backpackButtonSize = true,
	panelCornerRadius = true,
	categoryTabSize = true,
}

--- Return a copy of the theme with pixel values multiplied by `scale`.
function Theme.scaleTheme(theme: Types.ThemeConfig, scale: number): Types.ThemeConfig
	local scaled = table.clone(theme)
	for key in SCALABLE_KEYS do
		local val = (scaled :: any)[key]
		if type(val) == "number" then
			(scaled :: any)[key] = math.round(val * scale)
		end
	end
	-- Store scale factor so components can use it for ad-hoc scaling
	scaled._scale = scale
	return scaled
end

return Theme