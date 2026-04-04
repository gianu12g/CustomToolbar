--!strict
--[[
	CustomToolbar – BackpackPanel
	Extension inventory grid showing overflow tools not on the hotbar.
	Always shows a fixed grid of slots (filled + empty) so players can
	drag items into any open cell. Mirrors Roblox backpack behaviour.

	Features:
		- Category tabs: shown to the right of the "Backpack" title when
		  at least one tool has a Category attribute. "All" is always first.
		  Tabs only appear for categories that have at least one item.
		- Expand mode (expandBackpack config): when true, the panel grows
		  downward to fit all items instead of clamping to a fixed cell count.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)
local Slot = require(script.Parent.Slot)

type Props = {
	visible: boolean,
	slots: { Types.SlotData },
	theme: Types.ThemeConfig,
	layout: Types.LayoutConfig,
	onClose: () -> (),
	-- Drag support
	onSlotMouseDown: ((index: number, source: string) -> ())?,
	onSlotHoverChange: ((index: number, source: string, hovering: boolean) -> ())?,
	dragOverIndex: number?,
	dragFromIndex: number?,
	isDragging: boolean?,
	minRows: number?,
	backpackSlotCount: number?, -- fixed total cells to display (overrides auto-calc)
	showEmptySlotBG: boolean?,  -- passed through to Slot for empty cell visibility
	expandBackpack: boolean?,   -- grow panel to fit all items (ignores backpackSlotCount cap)
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Collect unique category names present in the slot list (sorted).
local function getCategories(slots: { Types.SlotData }): { string }
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	for _, slot in slots do
		local cat = slot.category
		if cat and cat ~= "" and not seen[cat] then
			seen[cat] = true
			table.insert(list, cat)
		end
	end
	table.sort(list)
	return list
end

--- Filter slots to only those matching `category` (nil = show all).
--- Returns the filtered list AND a map from filtered-index → original-index
--- so that drag/drop callbacks can use the correct backpack array position.
local function filterSlots(slots: { Types.SlotData }, category: string?): ({ Types.SlotData }, { [number]: number })
	local filtered: { Types.SlotData } = {}
	local indexMap: { [number]: number } = {} -- filteredIdx → originalIdx
	for origIdx, slot in slots do
		if category == nil or slot.category == category then
			table.insert(filtered, slot)
			indexMap[#filtered] = origIdx
		end
	end
	return filtered, indexMap
end

---------------------------------------------------------------------------
-- Component
---------------------------------------------------------------------------

local function BackpackPanel(props: Props)
	local theme = props.theme
	local slotSize = theme.slotSize :: number
	local padding = theme.slotPadding :: number
	local columns = theme.panelColumns :: number
	local cornerRadius = theme.panelCornerRadius :: number
	local s = theme._scale or 1 -- viewport scale factor

	local minRows = props.minRows or 3
	local expandBackpack = props.expandBackpack or false

	------------------------------------------------------------------------
	-- Category tab state
	------------------------------------------------------------------------
	local categories = React.useMemo(function()
		return getCategories(props.slots)
	end, { props.slots } :: { any })

	local hasCategories = #categories > 0

	-- nil = "All" (show everything)
	local activeCategory, setActiveCategory = React.useState(nil :: string?)

	-- If the active category disappears (all its tools removed), reset to All
	React.useEffect(function()
		if activeCategory ~= nil then
			local found = false
			for _, cat in categories do
				if cat == activeCategory then
					found = true
					break
				end
			end
			if not found then
				setActiveCategory(nil)
			end
		end
	end, { categories, activeCategory } :: { any })

	local visibleSlots, filteredIndexMap = React.useMemo(function()
		return filterSlots(props.slots, activeCategory)
	end, { props.slots, activeCategory } :: { any })

	------------------------------------------------------------------------
	-- Index translation for drag support
	-- The parent (Toolbar/useDragAndDrop) tracks drag indices in terms of
	-- the FULL unfiltered backpack array. When a category filter is active,
	-- the grid shows a subset. We need bidirectional mapping:
	--   filteredIndexMap: filteredIdx → originalIdx  (for mouse-down/hover callbacks)
	--   reverseIndexMap:  originalIdx → filteredIdx  (for drag visual indicators)
	------------------------------------------------------------------------
	local reverseIndexMap = React.useMemo(function()
		local rev: { [number]: number } = {}
		for fIdx, oIdx in filteredIndexMap do
			rev[oIdx] = fIdx
		end
		return rev
	end, { filteredIndexMap } :: { any })

	-- Resolve parent drag indices to filtered grid positions
	local resolvedDragOverIndex: number? = nil
	local resolvedDragFromIndex: number? = nil
	if props.dragOverIndex then
		resolvedDragOverIndex = reverseIndexMap[props.dragOverIndex] or props.dragOverIndex
	end
	if props.dragFromIndex then
		resolvedDragFromIndex = reverseIndexMap[props.dragFromIndex] or props.dragFromIndex
	end

	-- Wrapped callbacks that translate filtered indices → original indices
	local function wrappedMouseDown(filteredIdx: number, source: string)
		if props.onSlotMouseDown then
			local origIdx = filteredIndexMap[filteredIdx] or filteredIdx
			props.onSlotMouseDown(origIdx, source)
		end
	end

	local function wrappedHoverChange(filteredIdx: number, source: string, hovering: boolean)
		if props.onSlotHoverChange then
			local origIdx = filteredIndexMap[filteredIdx] or filteredIdx
			props.onSlotHoverChange(origIdx, source, hovering)
		end
	end

	------------------------------------------------------------------------
	-- Grid sizing
	------------------------------------------------------------------------
	local slotCount = #visibleSlots

	local totalCells: number
	if expandBackpack then
		-- Grow to fit: always show at least minRows, expand if items exceed that
		local minCells = columns * minRows
		totalCells = math.max(slotCount + columns, minCells)
		local rows = math.ceil(totalCells / columns)
		totalCells = rows * columns
	elseif props.backpackSlotCount and props.backpackSlotCount > 0 then
		-- Fixed slot count from config — snap up to full rows
		local rows = math.ceil(props.backpackSlotCount / columns)
		totalCells = rows * columns
	else
		-- Auto-calc: at least minRows of slots so there are empty drop targets
		local minCells = columns * minRows
		totalCells = math.max(slotCount + columns, minCells) -- always at least one extra row
		local rows = math.ceil(totalCells / columns)
		totalCells = rows * columns -- snap to full rows
	end
	local rows = math.ceil(totalCells / columns)

	local gridWidth = (columns * slotSize) + ((columns - 1) * padding) + padding * 2
	local gridHeight = (rows * slotSize) + ((rows - 1) * padding) + padding * 2

	-- Add space for title bar (and category tabs row if categories exist)
	local titleHeight = math.round(28 * s)
	local tabRowHeight = if hasCategories then math.round(26 * s) else 0
	local panelHeight = gridHeight + titleHeight + tabRowHeight

	if not props.visible then
		return nil
	end

	------------------------------------------------------------------------
	-- Category tab elements
	------------------------------------------------------------------------
	local tabFont = theme.categoryTabFont or Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)
	local tabColor = theme.categoryTabColor or Color3.fromRGB(150, 150, 150)
	local tabActiveColor = theme.categoryTabActiveColor or Color3.fromRGB(255, 255, 255)
	local tabUnderlineColor = theme.categoryTabUnderlineColor or Color3.fromRGB(0, 162, 255)
	local tabFontSize = theme.categoryTabSize or math.round(12 * s)

	local tabElements: { [string]: any }? = nil
	if hasCategories then
		tabElements = {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, math.round(12 * s)),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			LeftPad = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, padding + math.round(2 * s)),
			}),
		}

		-- "All" tab is always first
		local allTabs = { "All" }
		for _, cat in categories do
			table.insert(allTabs, cat)
		end

		for order, label in allTabs do
			local isActive = (label == "All" and activeCategory == nil)
				or (label ~= "All" and activeCategory == label)

			tabElements["Tab_" .. label] = React.createElement("TextButton", {
				Text = label,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				FontFace = tabFont,
				TextColor3 = if isActive then tabActiveColor else tabColor,
				TextSize = tabFontSize,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = order,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ZIndex = 7,
				[React.Event.Activated] = function()
					if label == "All" then
						setActiveCategory(nil)
					else
						setActiveCategory(label)
					end
				end,
			}, {
				-- Active underline indicator
				Underline = if isActive then React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, math.round(2 * s)),
					Position = UDim2.new(0, 0, 1, -math.round(2 * s)),
					BackgroundColor3 = tabUnderlineColor,
					BorderSizePixel = 0,
					ZIndex = 8,
				}) else nil,
			})
		end
	end

	------------------------------------------------------------------------
	-- Build children
	------------------------------------------------------------------------
	local children: { [string]: any } = {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, cornerRadius),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = theme.slotBorderColor,
			Thickness = theme.slotBorderWidth,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		-- Title bar
		TitleBar = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, titleHeight),
			Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			Title = React.createElement("TextLabel", {
				Text = "Backpack",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(padding + math.round(2 * s), 0),
				BackgroundTransparency = 1,
				FontFace = theme.numberFont,
				TextColor3 = theme.nameColor,
				TextSize = math.round(13 * s),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 7,
			}),
			Divider = React.createElement("Frame", {
				Size = UDim2.new(1, -(padding * 2), 0, 1),
				Position = UDim2.new(0, padding, 1, -1),
				BackgroundColor3 = theme.slotBorderColor,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = 7,
			}),
		}),
	}

	-- Category tab row (sits between title bar and grid)
	if hasCategories and tabElements then
		children["TabRow"] = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, tabRowHeight),
			Position = UDim2.fromOffset(0, titleHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
			ClipsDescendants = true,
		}, tabElements)
	end

	-- Grid container (offset below title + tabs)
	local gridTopOffset = titleHeight + tabRowHeight
	children["GridContainer"] = React.createElement(
		"Frame",
		{
			Size = UDim2.new(1, 0, 1, -gridTopOffset),
			Position = UDim2.fromOffset(0, gridTopOffset),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 5,
		},
		(function()
			local gridChildren: { [string]: any } = {
				Padding = React.createElement("UIPadding", {
					PaddingTop = UDim.new(0, padding),
					PaddingBottom = UDim.new(0, padding),
					PaddingLeft = UDim.new(0, padding),
					PaddingRight = UDim.new(0, padding),
				}),
				Grid = React.createElement("UIGridLayout", {
					CellSize = UDim2.fromOffset(slotSize, slotSize),
					CellPadding = UDim2.fromOffset(padding, padding),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirectionMaxCells = columns,
				}),
			}

			-- Render ALL cells (filled slots + empty slots)
			for i = 1, totalCells do
				local slotData = visibleSlots[i] -- nil for empty cells
				gridChildren["Slot_" .. i] = React.createElement(Slot, {
					index = i,
					slotData = slotData,
					isSelected = false,
					theme = theme,
					source = "backpack",
					onMouseDown = wrappedMouseDown,
					onHoverChange = wrappedHoverChange,
					isDragOver = resolvedDragOverIndex == i,
					isBeingDragged = resolvedDragFromIndex == i,
					showEmptySlotBG = props.showEmptySlotBG,
				})
			end

			return gridChildren
		end)()
	)

	--------------------------------------------------------------
	-- Drag overlay: transparent frame covering the entire grid
	-- area (including padding gaps) that resolves cursor position
	-- to the nearest cell index. Only active during drags so it
	-- doesn't interfere with normal click/hover on slots.
	--------------------------------------------------------------
	if props.isDragging then
		children["DragOverlay"] = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, -gridTopOffset),
			Position = UDim2.fromOffset(0, gridTopOffset),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 10, -- above grid cells
			[React.Event.InputChanged] = function(rbx, input)
				if input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end

				-- Convert absolute cursor pos to local position within the grid.
				local absPos = rbx.AbsolutePosition
				local cursorX = input.Position.X - absPos.X
				local cursorY = input.Position.Y - absPos.Y

				-- Account for the grid padding
				cursorX = cursorX - padding
				cursorY = cursorY - padding

				-- Compute grid cell from local position
				local cellStep = slotSize + padding
				local col = math.clamp(math.floor(cursorX / cellStep) + 1, 1, columns)
				local row = math.clamp(math.floor(cursorY / cellStep) + 1, 1, rows)
				local cellIndex = (row - 1) * columns + col

				if cellIndex >= 1 and cellIndex <= totalCells then
					wrappedHoverChange(cellIndex, "backpack", true)
				end
			end,
			[React.Event.MouseLeave] = function()
				-- Clear hover when cursor leaves the panel entirely
				if resolvedDragOverIndex then
					wrappedHoverChange(resolvedDragOverIndex, "backpack", false)
				end
			end,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(gridWidth, panelHeight),
		Position = UDim2.new(0.5, 0, 0, math.round(-10 * s)),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = theme.panelBackgroundColor,
		BackgroundTransparency = theme.panelBackgroundTransparency,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, children)
end

return BackpackPanel
