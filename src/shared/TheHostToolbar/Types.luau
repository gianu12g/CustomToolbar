--!strict
--[[
	TheHostToolbar – Type definitions
	No external dependencies. Import this module for shared types.
]]

export type ThemeConfig = {
	-- Slot visuals
	slotSize: number?,
	slotPadding: number?,
	slotCornerRadius: number?,
	slotBackgroundColor: Color3?,
	slotBackgroundTransparency: number?,
	slotBorderColor: Color3?,
	slotBorderWidth: number?,
	slotSelectedColor: Color3?,
	slotSelectedBorderColor: Color3?,
	slotHoverColor: Color3?,

	-- Fake textured stroke (image-based border — a real UIStroke is a vector
	-- and cannot be textured, so we fake one with a layered ImageLabel)
	fakeStroke: boolean?,             -- enable the image-based border
	fakeStrokeImage: string?,         -- border texture asset id
	fakeStrokeColor: Color3?,         -- ImageColor3 tint applied to the texture
	fakeStrokeTransparency: number?,  -- 0 = opaque, 1 = invisible
	fakeStrokeThickness: number?,     -- ring width as a fraction of slot size (per side)

	-- Number label
	numberFont: Font?,
	numberColor: Color3?,
	numberSize: number?,
	showSlotNumbers: boolean?,

	-- Tool name label
	nameFont: Font?,
	nameColor: Color3?,
	nameSize: number?,
	showToolName: boolean?,

	-- Icon
	iconSizeScale: number?, -- 0–1, fraction of slot size
	iconColor: Color3?,

	-- Backpack button
	backpackButtonIcon: string?, -- image asset id
	backpackButtonSize: number?,

	-- Backpack panel
	panelBackgroundColor: Color3?,
	panelBackgroundTransparency: number?,
	panelCornerRadius: number?,
	panelColumns: number?,

	-- Rarity colours (key = rarity name from Tool:GetAttribute("Rarity"))
	rarityColors: { [string]: Color3 }?,

	-- Rarity outline presets (key = rarity name, value = preset name)
	-- Maps rarity tiers to named gradient presets ("Rainbow", "Fire", "Ice", "Toxic", "Galaxy").
	-- Individual tools can override this via SlotData.outlinePreset.
	rarityPresets: { [string]: string }?,

	-- Category tabs (shown in backpack panel title bar)
	categoryTabFont: Font?,
	categoryTabColor: Color3?,            -- text colour for inactive tabs
	categoryTabActiveColor: Color3?,      -- text colour for the selected tab
	categoryTabUnderlineColor: Color3?,   -- underline bar for the selected tab
	categoryTabSize: number?,             -- font size for tab labels

	-- Animations
	selectAnimationSpeed: number?,
	hoverAnimationSpeed: number?,

	-- Viewport scaling (set automatically, not user-configured)
	_scale: number?,
}

export type LayoutConfig = {
	orientation: ("Horizontal" | "Vertical")?,
	position: UDim2?,
	anchorPoint: Vector2?,
	maxVisibleSlots: number?,
	displayOrder: number?,
}

export type ToolbarConfig = {
	theme: ThemeConfig?,
	layout: LayoutConfig?,
	autoManageBackpack: boolean?, -- watch player Backpack for tools (default true)
	keybindsEnabled: boolean?,    -- 1-9 number keys (default true)
	gamepadEnabled: boolean?,     -- bumper scroll (default true)
	backpackSlotCount: number?,   -- total cells shown in backpack panel (default: auto from columns × rows)
	showEmptySlotBG: boolean?,    -- show background on empty backpack slots (default true)
	dragHoldTime: number?,        -- seconds to hold before drag begins when backpack is closed (default 0)
	dragHoldTimeOpen: number?,    -- seconds to hold before drag begins when backpack is open (default 0)
	expandBackpack: boolean?,     -- allow scrolling when items exceed visible slot count (default false)
	maxCategoryTabs: number?,     -- max category tabs shown (excludes "All"; default 4)
}

export type SlotData = {
	id: string,
	name: string,
	icon: string,
	tool: Tool?,
	order: number,
	rarity: string?,
	category: string?, -- Tool:GetAttribute("Category") — used for backpack filter tabs
	outlinePreset: string?, -- per-tool override: "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
	onActivated: ((SlotData) -> ())?,
}

return true
