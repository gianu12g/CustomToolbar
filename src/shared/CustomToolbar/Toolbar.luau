--!strict
--[[
	CustomToolbar – Toolbar
	The main bar component. Renders a hotbar with a fixed number of visible slots,
	a backpack toggle button, and the BackpackPanel overlay for overflow storage.
	Supports full mouse drag between hotbar and backpack.

	Hotbar: quick-access slots (1–maxVisibleSlots), equippable via click or number keys.
	Backpack: overflow storage. Drag items between hotbar and backpack to organise.

	Drag interactions:
		- Hotbar ↔ Hotbar: swap slots
		- Hotbar → Backpack slot: swap
		- Hotbar → Backpack button: move to backpack (hotbar slot becomes empty)
		- Backpack → Hotbar: swap (or fill if hotbar slot is empty)
		- Backpack ↔ Backpack: swap
		- Drop on nothing: cancel (no change)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)
local Theme = require(script.Parent.Theme)
local Slot = require(script.Parent.Slot)
local BackpackPanel = require(script.Parent.BackpackPanel)

type Props = {
	config: Types.ToolbarConfig?,
}

local DRAG_THRESHOLD = 5

-- Map KeyCode Enum values for 1-9
local NUMBER_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

-- Helper: read tools from player Backpack + Character
local function gatherTools(player: Player): { Tool }
	local tools: { Tool } = {}

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)

	return tools
end

local function toolToSlotData(tool: Tool, order: number): Types.SlotData
	return {
		id = tool.Name .. "_" .. tostring(order),
		name = tool.Name,
		icon = tool.TextureId ~= "" and tool.TextureId or "rbxasset://textures/ui/GuiImagePlaceholder.png",
		tool = tool,
		order = order,
		onActivated = nil,
	}
end

---------------------------------------------------------------------------
-- Component
---------------------------------------------------------------------------
local function Toolbar(props: Props)
	local config = props.config or {} :: Types.ToolbarConfig

	local autoManage = if config.autoManageBackpack == nil then true else config.autoManageBackpack
	local keybinds = if config.keybindsEnabled == nil then true else config.keybindsEnabled
	local dragHoldTime = config.dragHoldTime or 0
	local backpackSlotCount = config.backpackSlotCount

	---------------------------------------------------------------------------
	-- Viewport-based scaling
	---------------------------------------------------------------------------
	local camera = Workspace.CurrentCamera
	local viewportSize, setViewportSize = React.useState(function()
		return if camera then camera.ViewportSize else Vector2.new(Theme.REFERENCE_WIDTH, Theme.REFERENCE_HEIGHT)
	end)

	React.useEffect(function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return function() end
		end

		setViewportSize(cam.ViewportSize)

		local conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewportSize(cam.ViewportSize)
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	local scale = Theme.computeScale(viewportSize)

	-- Apply viewport scale to the base theme so every pixel value adjusts
	local theme = React.useMemo(function()
		local base = Theme.mergeTheme(config.theme)
		return Theme.scaleTheme(base, scale)
	end, { config.theme, scale } :: { any })

	-- Scale the layout position offset (the -12 bottom margin)
	local layout = React.useMemo(function()
		local base = Theme.mergeLayout(config.layout)
		-- Scale the offset components of the position
		local pos = base.position :: UDim2
		base.position = UDim2.new(
			pos.X.Scale, math.round(pos.X.Offset * scale),
			pos.Y.Scale, math.round(pos.Y.Offset * scale)
		)
		return base
	end, { config.layout, scale } :: { any })

	local maxSlots = layout.maxVisibleSlots :: number

	-- GUI inset for mouse → ScreenGui coordinate correction
	local guiInset = React.useMemo(function()
		local inset = GuiService:GetGuiInset()
		return inset
	end, {})

	local player = Players.LocalPlayer

	---------------------------------------------------------------------------
	-- State
	---------------------------------------------------------------------------
	local hotbarSlots, setHotbarSlots = React.useState({} :: { Types.SlotData? })
	local backpackSlots, setBackpackSlots = React.useState({} :: { Types.SlotData })
	local selectedIndex, setSelectedIndex = React.useState(nil :: number?)
	local backpackOpen, setBackpackOpen = React.useState(false)

	-- Drag state
	local dragInfo, setDragInfo = React.useState(nil :: {
		source: string,
		index: number,
		slotData: Types.SlotData,
		startPos: Vector2,
	}?)
	local isDragging, setIsDragging = React.useState(false)
	local mousePos, setMousePos = React.useState(Vector2.zero)
	local hoverTarget, setHoverTarget = React.useState(nil :: {
		targetType: string,
		targetIndex: number,
	}?)

	-- "Just finished a drag" flag to suppress ghost clicks on buttons
	local justDraggedRef = React.useRef(false)

	-- Drag hold timer: tracks whether the hold duration has elapsed
	local dragHoldReady, setDragHoldReady = React.useState(dragHoldTime == 0)
	local dragHoldReadyRef = React.useRef(dragHoldReady)
	dragHoldReadyRef.current = dragHoldReady

	-- Refs for stale closure avoidance in effects/callbacks
	local hotbarRef = React.useRef(hotbarSlots)
	local backpackRef = React.useRef(backpackSlots)
	local selectedRef = React.useRef(selectedIndex)
	local dragInfoRef = React.useRef(dragInfo)
	local isDraggingRef = React.useRef(isDragging)
	local hoverTargetRef = React.useRef(hoverTarget)

	hotbarRef.current = hotbarSlots
	backpackRef.current = backpackSlots
	selectedRef.current = selectedIndex
	dragInfoRef.current = dragInfo
	isDraggingRef.current = isDragging
	hoverTargetRef.current = hoverTarget

	---------------------------------------------------------------------------
	-- Equip / unequip a hotbar slot (click interaction)
	---------------------------------------------------------------------------
	local function selectSlot(index: number)
		local currentHotbar = hotbarRef.current
		local currentSelected = selectedRef.current
		local slotData = currentHotbar[index]

		if not slotData or not slotData.tool then
			-- Clicked empty slot → deselect
			setSelectedIndex(nil)
			return
		end

		-- Custom callback
		if slotData.onActivated then
			slotData.onActivated(slotData)
		end

		-- If same slot clicked again → unequip
		if currentSelected == index then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
			setSelectedIndex(nil)
			return
		end

		-- Equip the tool
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and slotData.tool then
			humanoid:EquipTool(slotData.tool)
		end
		setSelectedIndex(index)
	end

	---------------------------------------------------------------------------
	-- Drag helpers
	---------------------------------------------------------------------------
	local function cancelDrag()
		setDragInfo(nil)
		setIsDragging(false)
		setHoverTarget(nil)
	end

	local function completeDrag()
		local drag = dragInfoRef.current
		local hover = hoverTargetRef.current
		local wasDragging = isDraggingRef.current

		-- Flag to suppress ghost click on backpack button
		justDraggedRef.current = true
		task.delay(0.15, function()
			justDraggedRef.current = false
		end)

		if not drag or not wasDragging then
			cancelDrag()
			return
		end

		local srcType = drag.source
		local srcIdx = drag.index
		local srcSlot = drag.slotData

		if hover then
			local dstType = hover.targetType
			local dstIdx = hover.targetIndex

			----------------------------------------------------------------
			-- Drop on backpack button → move hotbar item to backpack
			----------------------------------------------------------------
			if dstType == "backpackButton" then
				if srcType == "hotbar" then
					setHotbarSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = nil
						return new
					end)
					setBackpackSlots(function(prev)
						local new = table.clone(prev)
						table.insert(new, srcSlot)
						return new
					end)
					if selectedRef.current == srcIdx then
						setSelectedIndex(nil)
						local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then humanoid:UnequipTools() end
					end
				end
				-- Dragging backpack item to backpack button does nothing

			----------------------------------------------------------------
			-- Hotbar → Hotbar: swap
			----------------------------------------------------------------
			elseif srcType == "hotbar" and dstType == "hotbar" then
				setHotbarSlots(function(prev)
					local new = table.clone(prev)
					new[srcIdx], new[dstIdx] = new[dstIdx], new[srcIdx]
					return new
				end)
				local sel = selectedRef.current
				if sel == srcIdx then
					setSelectedIndex(dstIdx)
				elseif sel == dstIdx then
					setSelectedIndex(srcIdx)
				end

			----------------------------------------------------------------
			-- Hotbar → Backpack slot: swap or insert into empty cell
			----------------------------------------------------------------
			elseif srcType == "hotbar" and dstType == "backpack" then
				local dstSlot = backpackRef.current[dstIdx]
				if dstSlot then
					-- Swap: backpack item goes to hotbar, hotbar item goes to backpack
					setHotbarSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = dstSlot
						return new
					end)
					setBackpackSlots(function(prev)
						local new = table.clone(prev)
						new[dstIdx] = srcSlot
						return new
					end)
				else
					-- Dropped on empty backpack cell → append to backpack, clear hotbar slot
					setHotbarSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = nil
						return new
					end)
					setBackpackSlots(function(prev)
						local new = table.clone(prev)
						table.insert(new, srcSlot)
						return new
					end)
				end
				if selectedRef.current == srcIdx then
					setSelectedIndex(nil)
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then humanoid:UnequipTools() end
				end

			----------------------------------------------------------------
			-- Backpack → Hotbar: swap (or move if hotbar slot is empty)
			----------------------------------------------------------------
			elseif srcType == "backpack" and dstType == "hotbar" then
				local dstSlot = hotbarRef.current[dstIdx]
				setHotbarSlots(function(prev)
					local new = table.clone(prev)
					new[dstIdx] = srcSlot
					return new
				end)
				if dstSlot then
					-- Displaced hotbar item takes the backpack slot
					setBackpackSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = dstSlot
						return new
					end)
				else
					-- Empty hotbar slot — just remove from backpack
					setBackpackSlots(function(prev)
						local new = {}
						for i, slot in prev do
							if i ~= srcIdx then
								table.insert(new, slot)
							end
						end
						return new
					end)
				end

			----------------------------------------------------------------
			-- Backpack → Backpack: swap or reorder
			----------------------------------------------------------------
			elseif srcType == "backpack" and dstType == "backpack" then
				local dstSlot = backpackRef.current[dstIdx]
				if dstSlot then
					-- Both occupied → swap
					setBackpackSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx], new[dstIdx] = new[dstIdx], new[srcIdx]
						return new
					end)
				else
					-- Dragged to empty cell → item stays, nothing changes visually
					-- (auto-arrange keeps items packed, so this is a no-op)
				end
			end
		end
		-- Drop on nothing → cancel (no change)

		cancelDrag()
	end

	---------------------------------------------------------------------------
	-- Callbacks for Slot / BackpackPanel (stable via useCallback + refs)
	---------------------------------------------------------------------------
	local onSlotMouseDown = React.useCallback(function(index: number, source: string)
		local slotData: Types.SlotData?
		if source == "hotbar" then
			slotData = hotbarRef.current[index]
		else
			slotData = backpackRef.current[index]
		end

		if not slotData then
			-- Empty slot click
			if source == "hotbar" then
				setSelectedIndex(nil)
			end
			return
		end

		local mouseLocation = UserInputService:GetMouseLocation()
		setDragInfo({
			source = source,
			index = index,
			slotData = slotData,
			startPos = mouseLocation,
		})
		setMousePos(mouseLocation)
	end, {})

	local onSlotHoverChange = React.useCallback(function(index: number, source: string, hovering: boolean)
		if hovering then
			setHoverTarget({
				targetType = source,
				targetIndex = index,
			})
		else
			-- Only clear if this slot is still the hovered target
			setHoverTarget(function(prev)
				if prev and prev.targetType == source and prev.targetIndex == index then
					return nil
				end
				return prev
			end)
		end
	end, {})

	---------------------------------------------------------------------------
	-- Track whether backpack was already open before a drag started
	---------------------------------------------------------------------------
	local backpackWasOpenRef = React.useRef(false)

	---------------------------------------------------------------------------
	-- Effect: drag hold timer (wait dragHoldTime seconds before allowing drag)
	---------------------------------------------------------------------------
	React.useEffect(function()
		if not dragInfo then
			-- Reset hold readiness when drag is cancelled/completed
			setDragHoldReady(dragHoldTime == 0)
			return function() end
		end

		if dragHoldTime <= 0 then
			setDragHoldReady(true)
			return function() end
		end

		-- Start a timer; drag becomes ready after dragHoldTime seconds
		setDragHoldReady(false)
		local cancelled = false
		task.delay(dragHoldTime, function()
			if not cancelled then
				setDragHoldReady(true)
			end
		end)

		return function()
			cancelled = true
		end
	end, { dragInfo, dragHoldTime } :: { any })

	---------------------------------------------------------------------------
	-- Effect: drag tracking (mouse move + mouse up via UserInputService)
	---------------------------------------------------------------------------
	React.useEffect(function()
		if not dragInfo then
			return function() end
		end

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local pos = Vector2.new(input.Position.X, input.Position.Y)
				setMousePos(pos)

				if not isDraggingRef.current and dragInfoRef.current then
					local delta = pos - dragInfoRef.current.startPos
					if delta.Magnitude > DRAG_THRESHOLD and dragHoldReadyRef.current then
						setIsDragging(true)
						-- Auto-open backpack when drag starts
						setBackpackOpen(function(prev)
							backpackWasOpenRef.current = prev
							return true
						end)
					end
				end
			end
		end)

		local upConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if isDraggingRef.current then
					completeDrag()
					-- After drag completes, restore backpack open state to what it was before
					if not backpackWasOpenRef.current then
						setBackpackOpen(false)
					end
				else
					-- Was a click, not a drag → equip/unequip if hotbar
					local info = dragInfoRef.current
					if info and info.source == "hotbar" then
						selectSlot(info.index)
					end
					cancelDrag()
				end
			end
		end)

		return function()
			moveConn:Disconnect()
			upConn:Disconnect()
		end
	end, { dragInfo } :: { any })

	---------------------------------------------------------------------------
	-- Effect: auto-manage tools from Backpack / Character
	---------------------------------------------------------------------------
	React.useEffect(function()
		if not autoManage then
			return function() end
		end

		local alive = true
		local connections: { RBXScriptConnection } = {}

		local function refresh()
			if not alive then
				return
			end

			local tools = gatherTools(player)
			local currentHotbar = hotbarRef.current
			local currentBackpack = backpackRef.current

			-- Build set of tool instances that still exist
			local toolExists: { [Tool]: boolean } = {}
			for _, tool in tools do
				toolExists[tool] = true
			end

			-- Preserve existing assignments, remove dead tools
			local newHotbar: { Types.SlotData? } = {}
			for i = 1, maxSlots do
				local slot = currentHotbar[i]
				if slot and slot.tool and toolExists[slot.tool] then
					newHotbar[i] = slot
				end
			end

			local newBackpack: { Types.SlotData } = {}
			for _, slot in currentBackpack do
				if slot.tool and toolExists[slot.tool] then
					table.insert(newBackpack, slot)
				end
			end

			-- Track what's already assigned
			local assigned: { [Tool]: boolean } = {}
			for _, slot in newHotbar do
				if slot and slot.tool then
					assigned[slot.tool] = true
				end
			end
			for _, slot in newBackpack do
				if slot.tool then
					assigned[slot.tool] = true
				end
			end

			-- Place unassigned (new) tools: fill hotbar first, overflow to backpack
			local orderCounter = #tools
			for _, tool in tools do
				if not assigned[tool] then
					local placed = false
					for j = 1, maxSlots do
						if not newHotbar[j] then
							orderCounter += 1
							newHotbar[j] = toolToSlotData(tool, orderCounter)
							placed = true
							break
						end
					end
					if not placed then
						orderCounter += 1
						table.insert(newBackpack, toolToSlotData(tool, orderCounter))
					end
				end
			end

			setHotbarSlots(newHotbar)
			setBackpackSlots(newBackpack)

			-- Update selection to follow the currently equipped tool
			local character = player.Character
			if character then
				local equippedTool = character:FindFirstChildOfClass("Tool")
				if equippedTool then
					for i = 1, maxSlots do
						local sd = newHotbar[i]
						if sd and sd.tool == equippedTool then
							setSelectedIndex(i)
							return
						end
					end
					-- Equipped tool isn't on hotbar → deselect
					setSelectedIndex(nil)
				else
					setSelectedIndex(nil)
				end
			end
		end

		local function watchCharacter(char: Model)
			table.insert(connections, char.ChildAdded:Connect(refresh))
			table.insert(connections, char.ChildRemoved:Connect(refresh))
			task.defer(refresh)
		end

		-- Spawn for the yielding WaitForChild call
		task.spawn(function()
			local backpack = player:WaitForChild("Backpack", 10)
			if not alive then
				return
			end
			if backpack then
				table.insert(connections, backpack.ChildAdded:Connect(refresh))
				table.insert(connections, backpack.ChildRemoved:Connect(refresh))
			end
			refresh()
		end)

		table.insert(connections, player.CharacterAdded:Connect(function(char)
			watchCharacter(char)
		end))

		if player.Character then
			watchCharacter(player.Character)
		end

		refresh()

		return function()
			alive = false
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { autoManage } :: { any })

	---------------------------------------------------------------------------
	-- Effect: keyboard input (1-9 keys, backquote for backpack panel)
	---------------------------------------------------------------------------
	React.useEffect(function()
		if not keybinds then
			return function() end
		end

		local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			-- Number keys 1-9 → select hotbar slot
			local slotNum = NUMBER_KEYS[input.KeyCode]
			if slotNum and slotNum <= maxSlots then
				local slot = hotbarRef.current[slotNum]
				if slot then
					selectSlot(slotNum)
				end
				return
			end

			-- Backquote (`) toggles backpack panel
			if input.KeyCode == Enum.KeyCode.Backquote then
				setBackpackOpen(function(prev)
					return not prev
				end)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, { keybinds } :: { any })

	---------------------------------------------------------------------------
	-- Render
	---------------------------------------------------------------------------
	local slotSize = theme.slotSize :: number
	local padding = theme.slotPadding :: number
	local isHorizontal = layout.orientation == "Horizontal"

	-- Build slot children for the hotbar
	local barChildren: { [string]: any } = {}

	-- Layout
	if isHorizontal then
		barChildren["Layout"] = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, padding),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
	else
		barChildren["Layout"] = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, padding),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
	end

	-- Hotbar slots
	for i = 1, maxSlots do
		local isDragOverSlot = isDragging and hoverTarget
			and hoverTarget.targetType == "hotbar" and hoverTarget.targetIndex == i
		local isBeingDraggedSlot = isDragging and dragInfo
			and dragInfo.source == "hotbar" and dragInfo.index == i

		barChildren["Slot_" .. i] = React.createElement(Slot, {
			index = i,
			slotData = hotbarSlots[i],
			isSelected = selectedIndex == i,
			theme = theme,
			source = "hotbar",
			onMouseDown = onSlotMouseDown,
			onHoverChange = onSlotHoverChange,
			isDragOver = isDragOverSlot or false,
			isBeingDragged = isBeingDraggedSlot or false,
		})
	end

	-- Backpack toggle button (also a drop target during drag)
	local backpackBtnSize = theme.backpackButtonSize :: number
	local isBackpackBtnDragOver = isDragging and hoverTarget
		and hoverTarget.targetType == "backpackButton"

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
			-- Suppress toggle if we just finished a drag on this button
			if justDraggedRef.current then
				return
			end
			setBackpackOpen(function(prev)
				return not prev
			end)
		end,
		[React.Event.MouseEnter] = function()
			-- Register as drop target during drag
			setHoverTarget(function(prev)
				if dragInfoRef.current then
					return {
						targetType = "backpackButton",
						targetIndex = 0,
					}
				end
				return prev
			end)
		end,
		[React.Event.MouseLeave] = function()
			setHoverTarget(function(prev)
				if prev and prev.targetType == "backpackButton" then
					return nil
				end
				return prev
			end)
		end,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, theme.slotCornerRadius),
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
	local itemCount = maxSlots + 1 -- +1 for backpack button
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
	if isDragging and hoverTarget and hoverTarget.targetType == "backpack" then
		bpDragOverIdx = hoverTarget.targetIndex
	end
	if isDragging and dragInfo and dragInfo.source == "backpack" then
		bpDragFromIdx = dragInfo.index
	end

	-- Drag ghost (floating image that follows cursor)
	local ghostElement = nil
	if isDragging and dragInfo then
		local ghostSize = slotSize * 0.8
		ghostElement = React.createElement("ImageLabel", {
			Image = dragInfo.slotData.icon,
			ImageColor3 = theme.iconColor,
			Size = UDim2.fromOffset(ghostSize, ghostSize),
			Position = UDim2.fromOffset(
				mousePos.X - ghostSize / 2,
				mousePos.Y - guiInset.Y - ghostSize / 2
			),
			BackgroundColor3 = theme.slotBackgroundColor,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 100,
			ScaleType = Enum.ScaleType.Fit,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, theme.slotCornerRadius),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = theme.slotSelectedBorderColor,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
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
				onSlotMouseDown = onSlotMouseDown,
				onSlotHoverChange = onSlotHoverChange,
				dragOverIndex = bpDragOverIdx,
				dragFromIndex = bpDragFromIdx,
				isDragging = isDragging,
				backpackSlotCount = backpackSlotCount,
			}),
		}),

		-- Floating drag ghost (direct child of ScreenGui for absolute positioning)
		DragGhost = ghostElement,
	})
end

return Toolbar
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    