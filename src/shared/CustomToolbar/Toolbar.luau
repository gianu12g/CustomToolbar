--!strict
--[[
	CustomToolbar – Toolbar
	Main React component. Orchestrates hooks and renders the hotbar,
	backpack panel, and drag ghost.

	All state is React state. Drag timing is handled by useDragAndDrop
	which keeps drag state as useState to ensure synchronous UI updates
	within the same React reconciliation pass.

	Drag interactions:
		- Hotbar <-> Hotbar: swap slots
		- Hotbar -> Backpack slot: swap
		- Hotbar -> Backpack button: move to backpack (hotbar slot becomes empty)
		- Backpack -> Hotbar: swap (or fill if hotbar slot is empty)
		- Backpack <-> Backpack: swap
		- Drop on nothing: cancel (no change)
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)
local Theme = require(script.Parent.Theme)
local Slot = require(script.Parent.Slot)
local BackpackPanel = require(script.Parent.BackpackPanel)
local DragGhost = require(script.Parent.DragGhost)
local useViewportScale = require(script.Parent.useViewportScale)
local useToolSync = require(script.Parent.useToolSync)
local useKeyboardInput = require(script.Parent.useKeyboardInput)
local useDragAndDrop = require(script.Parent.useDragAndDrop)

type Props = {
	config: Types.ToolbarConfig?,
}

---------------------------------------------------------------------------
-- Component
---------------------------------------------------------------------------
local function Toolbar(props: Props)
	local config = props.config or {} :: Types.ToolbarConfig

	local autoManage = if config.autoManageBackpack == nil then true else config.autoManageBackpack
	local keybinds = if config.keybindsEnabled == nil then true else config.keybindsEnabled
	local dragHoldTimeClosed = config.dragHoldTime or 0
	local dragHoldTimeOpen = config.dragHoldTimeOpen or 0
	local backpackSlotCount = config.backpackSlotCount
	local showEmptySlotBG = if config.showEmptySlotBG == nil then true else config.showEmptySlotBG
	local expandBackpack = if config.expandBackpack == nil then false else config.expandBackpack
	local maxCategoryTabs = config.maxCategoryTabs

	local player = Players.LocalPlayer

	-----------------------------------------------------------------------
	-- Viewport scaling (hook)
	-----------------------------------------------------------------------
	local scale = useViewportScale()

	local theme = React.useMemo(function()
		local base = Theme.mergeTheme(config.theme)
		return Theme.scaleTheme(base, scale)
	end, { config.theme, scale } :: { any })

	local layout = React.useMemo(function()
		local base = Theme.mergeLayout(config.layout)
		local pos = base.position :: UDim2
		base.position = UDim2.new(
			pos.X.Scale, math.round(pos.X.Offset * scale),
			pos.Y.Scale, math.round(pos.Y.Offset * scale)
		)
		return base
	end, { config.layout, scale } :: { any })

	local maxSlots = layout.maxVisibleSlots :: number

	-- GUI inset for mouse -> ScreenGui coordinate correction
	local guiInset = React.useMemo(function()
		return GuiService:GetGuiInset()
	end, {})

	-----------------------------------------------------------------------
	-- Slot state (React-owned)
	-----------------------------------------------------------------------
	local hotbarSlots, setHotbarSlots = React.useState({} :: { Types.SlotData? })
	local backpackSlots, setBackpackSlots = React.useState({} :: { Types.SlotData })
	local selectedIndex, setSelectedIndex = React.useState(nil :: number?)
	local backpackOpen, setBackpackOpen = React.useState(false)

	-- Refs for stale-closure-safe access in hooks and callbacks
	local hotbarRef = React.useRef(hotbarSlots)
	local backpackRef = React.useRef(backpackSlots)
	local selectedRef = React.useRef(selectedIndex)
	local backpackOpenRef = React.useRef(backpackOpen)
	hotbarRef.current = hotbarSlots
	backpackRef.current = backpackSlots
	selectedRef.current = selectedIndex
	backpackOpenRef.current = backpackOpen

	-----------------------------------------------------------------------
	-- Equip / unequip a hotbar slot (click interaction)
	-----------------------------------------------------------------------
	local function selectSlot(index: number)
		local currentHotbar = hotbarRef.current
		local currentSelected = selectedRef.current
		local slotData = currentHotbar[index]

		if not slotData or not slotData.tool then
			setSelectedIndex(nil)
			return
		end

		if slotData.onActivated then
			slotData.onActivated(slotData)
		end

		if currentSelected == index then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
			setSelectedIndex(nil)
			return
		end

		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and slotData.tool then
			humanoid:EquipTool(slotData.tool)
		end
		setSelectedIndex(index)
	end

	-----------------------------------------------------------------------
	-- Drag and drop (hook — ALL drag state is React state)
	-----------------------------------------------------------------------
	local drag = useDragAndDrop({
		holdTimeClosed = dragHoldTimeClosed,
		holdTimeOpen = dragHoldTimeOpen,
		player = player,
		hotbarRef = hotbarRef,
		backpackRef = backpackRef,
		selectedRef = selectedRef,
		backpackOpenRef = backpackOpenRef,
		setHotbarSlots = setHotbarSlots,
		setBackpackSlots = setBackpackSlots,
		setSelectedIndex = setSelectedIndex,
		setBackpackOpen = setBackpackOpen,
		onSlotClick = function(index: number, source: string)
			if source == "hotbar" then
				selectSlot(index)
			end
		end,
	})

	-----------------------------------------------------------------------
	-- Tool sync (hook)
	-----------------------------------------------------------------------
	useToolSync({
		enabled = autoManage,
		maxSlots = maxSlots,
		hotbarRef = hotbarRef,
		backpackRef = backpackRef,
		setHotbarSlots = setHotbarSlots,
		setBackpackSlots = setBackpackSlots,
		setSelectedIndex = setSelectedIndex,
	})

	-----------------------------------------------------------------------
	-- Keyboard input (hook)
	-----------------------------------------------------------------------
	useKeyboardInput({
		enabled = keybinds,
		maxSlots = maxSlots,
		hotbarRef = hotbarRef,
		onSelectSlot = selectSlot,
		onToggleBackpack = function()
			setBackpackOpen(function(prev)
				return not prev
			end)
		end,
	})

	-----------------------------------------------------------------------
	-- Render
	-----------------------------------------------------------------------
	local slotSize = theme.slotSize :: number
	local padding = theme.slotPadding :: number
	local isHorizontal = layout.orientation == "Horizontal"

	-- Build hotbar slot children
	local barChildren: { [string]: any } = {}

	-- Layout
	barChildren["Layout"] = React.createElement("UIListLayout", {
		FillDirection = if isHorizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	-- Hotbar slots
	for i = 1, maxSlots do
		local isDragOverSlot = drag.isDragging and drag.hoverTarget
			and drag.hoverTarget.targetType == "hotbar" and drag.hoverTarget.targetIndex == i
		local isBeingDraggedSlot = drag.isDragging and drag.dragInfo
			and drag.dragInfo.source == "hotbar" and drag.dragInfo.index == i

		barChildren["Slot_" .. i] = React.createElement(Slot, {
			index = i,
			slotData = hotbarSlots[i],
			isSelected = selectedIndex == i,
			theme = theme,
			source = "hotbar",
			onMouseDown = drag.onSlotMouseDown,
			onHoverChange = drag.onSlotHoverChange,
			isDragOver = isDragOverSlot or false,
			isBeingDragged = isBeingDraggedSlot or false,
		})
	end

	-- Backpack toggle button (also a drop target during drag)
	local backpackBtnSize = theme.backpackButtonSize :: number
	local cornerRadius = theme.slotCornerRadius :: number
	local isBackpackBtnDragOver = drag.isDragging and drag.hoverTarget
		and drag.hoverTarget.targetType == "backpackButton"

	barChildren["BackpackBtn"] = React.createElement("ImageButton", {
		Size = UDim2.fromOffset(backpackBtnSize, backpackBtnSize),
		BackgroundColor3 = theme.slotBackgroundColor,
		BackgroundTransparency = theme.slotBackgroundTransparency,
		Image = theme.backpackButtonIcon,
		ImageColor3 = theme.iconColor,
		ScaleType = Enum.ScaleType.Fit,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = maxSlots + 1,

		[React.Event.Activated] = function()
			if drag.justDraggedRef.current then
				return
			end
			setBackpackOpen(function(prev)
				return not prev
			end)
		end,
		-- Register as drop target during drag. The visual check
		-- (isBackpackBtnDragOver) already guards on drag.isDragging,
		-- so unconditional hover reporting is safe.
		[React.Event.MouseEnter] = function()
			drag.onSlotHoverChange(0, "backpackButton", true)
		end,
		[React.Event.MouseLeave] = function()
			drag.onSlotHoverChange(0, "backpackButton", false)
		end,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, cornerRadius),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if isBackpackBtnDragOver
				then (theme.slotSelectedBorderColor :: Color3)
				elseif backpackOpen
				then (theme.slotSelectedBorderColor :: Color3)
				else (theme.slotBorderColor :: Color3),
			Thickness = theme.slotBorderWidth,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	-- Compute bar size
	local itemCount = maxSlots + 1
	local barWidth, barHeight
	if isHorizontal then
		barWidth = (itemCount * slotSize) + ((itemCount - 1) * padding) + padding * 2
		barHeight = slotSize + padding * 2
	else
		barWidth = slotSize + padding * 2
		barHeight = (itemCount * slotSize) + ((itemCount - 1) * padding) + padding * 2
	end

	barChildren["Padding"] = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, padding),
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft = UDim.new(0, padding),
		PaddingRight = UDim.new(0, padding),
	})

	-- Backpack panel drag state
	local bpDragOverIdx: number? = nil
	local bpDragFromIdx: number? = nil
	if drag.isDragging and drag.hoverTarget and drag.hoverTarget.targetType == "backpack" then
		bpDragOverIdx = drag.hoverTarget.targetIndex
	end
	if drag.isDragging and drag.dragInfo and drag.dragInfo.source == "backpack" then
		bpDragFromIdx = drag.dragInfo.index
	end

	-- Drag ghost
	local ghostElement = nil
	if drag.isDragging and drag.dragInfo then
		ghostElement = React.createElement(DragGhost, {
			slotData = drag.dragInfo.slotData,
			mousePos = drag.mousePos,
			guiInset = guiInset,
			theme = theme,
		})
	end

	return React.createElement(React.Fragment, nil, {
		-- Main toolbar frame (hotbar bar + backpack panel)
		ToolbarFrame = React.createElement("Frame", {
			Size = UDim2.fromOffset(barWidth, barHeight),
			Position = layout.position,
			AnchorPoint = layout.anchorPoint,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Bar = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, barChildren),

			Panel = React.createElement(BackpackPanel, {
				visible = backpackOpen,
				slots = backpackSlots,
				theme = theme,
				layout = layout,
				onClose = function()
					setBackpackOpen(false)
				end,
				onSlotMouseDown = drag.onSlotMouseDown,
				onSlotHoverChange = drag.onSlotHoverChange,
				dragOverIndex = bpDragOverIdx,
				dragFromIndex = bpDragFromIdx,
				isDragging = drag.isDragging,
				backpackSlotCount = backpackSlotCount,
				showEmptySlotBG = showEmptySlotBG,
				expandBackpack = expandBackpack,
				maxCategoryTabs = maxCategoryTabs,
			}),
		}),

		-- Floating drag ghost (direct child of ScreenGui for absolute positioning)
		DragGhost = ghostElement,
	})
end

return Toolbar
