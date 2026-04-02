--!strict
--[[
	CustomToolbar – Theme
	Provides sensible defaults that closely match Roblox's native backpack bar,
	plus a deepMerge helper so consumers only override what they care about.
]]

local Types = require(script.Parent.Types)

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

-- Shallow merge: overrides win, nils fall back to default
function Theme.mergeTheme(overrides: Types.ThemeConfig?): Types.ThemeConfig
	if not overrides then
		return table.clone(DEFAULT_THEME)
	end
	local merged = table.clone(DEFAULT_THEME)
	for key, value in overrides :: any do
		(merged :: any)[key] = value
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

-- Reference resolution the default pixel values are designed for
Theme.REFERENCE_WIDTH = 1366
Theme.REFERENCE_HEIGHT = 768

--- Compute a viewport scale factor from the current viewport size.
--- Uses the smaller axis ratio to keep proportions uniform.
function Theme.computeScale(viewportSize: Vector2): number
	local sx = viewportSize.X / Theme.REFERENCE_WIDTH
	local sy = viewportSize.Y / Theme.REFERENCE_HEIGHT
	return math.min(sx, sy)
end

--- Return a new theme with every pixel-based value multiplied by `scale`.
--- The `_scale` field is also stored so child components can scale their
--- own hardcoded offsets.
function Theme.scaleTheme(base: Types.ThemeConfig, scale: number): Types.ThemeConfig
	if scale == 1 then
		local out = table.clone(base)
		out._scale = 1
		return out
	end

	local scaled = table.clone(base)
	scaled.slotSize        = math.round((base.slotSize :: number) * scale)
	scaled.slotPadding     = math.round((base.slotPadding :: number) * scale)
	scaled.slotCornerRadius = math.round((base.slotCornerRadius :: number) * scale)
	scaled.numberSize      = math.round((base.numberSize :: number) * scale)
	scaled.nameSize        = math.round((base.nameSize :: number) * scale)
	scaled.backpackButtonSize = math.round((base.backpackButtonSize :: number) * scale)
	scaled.panelCornerRadius  = math.round((base.panelCornerRadius :: number) * scale)
	scaled._scale = scale
	return scaled
end

function Theme.getDefaultTheme(): Types.ThemeConfig
	return table.clone(DEFAULT_THEME)
end

function Theme.getDefaultLayout(): Types.LayoutConfig
	return table.clone(DEFAULT_LAYOUT)
end

return Theme
