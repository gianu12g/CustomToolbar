--!strict
--[[
	CustomToolbar – Toolbar
	The main bar component. Renders visible slots in a row/column,
	a backpack toggle button, and the BackpackPanel overlay.
	Manages selection state, keyboard input, and tool equipping.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)
local Theme = require(script.Parent.Theme)
local Slot = require(script.Parent.Slot)
local BackpackPanel = require(script.Parent.BackpackPanel)

type Props = {
	config: Types.ToolbarConfig?,
}

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

	-- Tools in Backpack (unequipped)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	-- Tool currently equipped (in character)
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	-- Sort alphabetically for stable ordering
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

local function Toolbar(props: Props)
	local config = props.config or {} :: Types.ToolbarConfig
	local theme = React.useMemo(function()
		return Theme.mergeTheme(config.theme)
	end, { config.theme })

	local layout = React.useMemo(function()
		return Theme.mergeLayout(config.layout)
	end, { config.layout })

	local autoManage = if config.autoManageBackpack == nil then true else config.autoManageBackpack
	local keybinds = if config.keybindsEnabled == nil then true else config.keybindsEnabled
	local maxSlots = layout.maxVisibleSlots :: number

	-- State
	local slots, setSlots = React.useState({} :: { Types.SlotData })
	local selectedIndex, setSelectedIndex = React.useState(nil :: number?)
	local backpackOpen, setBackpackOpen = React.useState(false)
	local player = Players.LocalPlayer

	-- Use refs to avoid stale closures in effects/callbacks
	local slotsRef = React.useRef(slots)
	local selectedRef = React.useRef(selectedIndex)
	slotsRef.current = slots
	selectedRef.current = selectedIndex

	-- Toggle equip/unequip for a slot index
	local function selectSlot(index: number)
		local currentSlots = slotsRef.current
		local currentSelected = selectedRef.current
		local slotData = currentSlots[index]
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
	-- Auto-manage: listen to Backpack/Character tool changes
	-- IMPORTANT: useEffect must return cleanup synchronously (no yielding).
	-- All yielding work (WaitForChild) goes inside task.spawn.
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
			local newSlots: { Types.SlotData } = {}
			for i, tool in tools do
				table.insert(newSlots, toolToSlotData(tool, i))
			end
			setSlots(newSlots)

			-- Update selection to follow equipped tool
			local character = player.Character
			if character then
				local equippedTool = character:FindFirstChildOfClass("Tool")
				if equippedTool then
					for i, sd in newSlots do
						if sd.tool == equippedTool then
							setSelectedIndex(i)
							return
						end
					end
				end
			end
		end

		local function watchCharacter(char: Model)
			table.insert(connections, char.ChildAdded:Connect(refresh))
			table.insert(connections, char.ChildRemoved:Connect(refresh))
			task.defer(refresh)
		end

		-- Spawn a thread for the yielding WaitForChild call
		task.spawn(function()
			local backpack = player:WaitForChild("Backpack", 10)
			if not alive then
				return
			end
			if backpack then
				table.insert(connections, backpack.ChildAdded:Connect(refresh))
				table.insert(connections, backpack.ChildRemoved:Connect(refresh))
			end
			-- Refresh after connections are in place
			refresh()
		end)

		-- Watch character swaps (non-yielding)
		table.insert(connections, player.CharacterAdded:Connect(function(char)
			watchCharacter(char)
		end))

		if player.Character then
			watchCharacter(player.Character)
		end

		-- Also do an immediate refresh in case Backpack already exists
		refresh()

		return function()
			alive = false
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { autoManage } :: { any })

	---------------------------------------------------------------------------
	-- Keyboard input (1–9 keys and backquote for backpack)
	-- Uses refs so the effect doesn't need to re-subscribe on every state change.
	---------------------------------------------------------------------------
	React.useEffect(function()
		if not keybinds then
			return function() end
		end

		local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			-- Number keys 1-9
			local slotNum = NUMBER_KEYS[input.KeyCode]
			if slotNum and slotNum <= #slotsRef.current then
				selectSlot(slotNum)
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

	-- Visible slots (clamped to maxSlots)
	local visibleSlots: { Types.SlotData? } = {}
	for i = 1, maxSlots do
		visibleSlots[i] = slots[i] -- may be nil (empty slot)
	end

	-- Build slot children
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

	for i = 1, maxSlots do
		barChildren["Slot_" .. i] = React.createElement(Slot, {
			index = i,
			slotData = slots[i],
			isSelected = selectedIndex == i,
			theme = theme,
			onSelect = selectSlot,
		})
	end

	-- Backpack toggle button
	local backpackBtnSize = theme.backpackButtonSize :: number
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
			setBackpackOpen(function(prev)
				return not prev
			end)
		end,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, theme.slotCornerRadius),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = backpackOpen and (theme.slotSelectedBorderColor :: Color3) or (theme.slotBorderColor :: Color3),
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

	return React.createElement("Frame", {
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
			slots = slots,
			selectedIndex = selectedIndex,
			theme = theme,
			layout = layout,
			onSelect = function(index: number)
				selectSlot(index)
				setBackpackOpen(false)
			end,
			onClose = function()
				setBackpackOpen(false)
			end,
		}),
	})
end

return Toolbar
