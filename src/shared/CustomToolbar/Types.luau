--!strict
--[[
	CustomToolbar – Type definitions
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

	-- Animations
	selectAnimationSpeed: number?,
	hoverAnimationSpeed: number?,
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
}

export type SlotData = {
	id: string,
	name: string,
	icon: string,
	tool: Tool?,
	order: number,
	onActivated: ((SlotData) -> ())?,
}

return true
