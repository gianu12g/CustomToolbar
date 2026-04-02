--!strict
--[[
	CustomToolbar – BackpackPanel
	Expandable grid that shows ALL tools (overflow beyond maxVisibleSlots).
	Opens above the toolbar bar when the backpack button is toggled.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)
local Slot = require(script.Parent.Slot)

type Props = {
	visible: boolean,
	slots: { Types.SlotData },
	selectedIndex: number?,
	theme: Types.ThemeConfig,
	layout: Types.LayoutConfig,
	onSelect: (index: number) -> (),
	onClose: () -> (),
}

local function BackpackPanel(props: Props)
	local theme = props.theme
	local slotSize = theme.slotSize :: number
	local padding = theme.slotPadding :: number
	local columns = theme.panelColumns :: number
	local cornerRadius = theme.panelCornerRadius :: number

	local slotCount = #props.slots
	local rows = math.ceil(slotCount / columns)

	local gridWidth = (columns * slotSize) + ((columns - 1) * padding) + padding * 2
	local gridHeight = (rows * slotSize) + ((rows - 1) * padding) + padding * 2

	if not props.visible then
		return nil
	end

	-- Empty state
	if slotCount == 0 then
		local emptyWidth = (columns * slotSize) + ((columns - 1) * padding) + padding * 2
		local emptyHeight = slotSize + padding * 2
		return React.createElement("Frame", {
			Size = UDim2.fromOffset(emptyWidth, emptyHeight),
			Position = UDim2.new(0.5, 0, 0, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = theme.panelBackgroundColor,
			BackgroundTransparency = theme.panelBackgroundTransparency,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, cornerRadius),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = theme.slotBorderColor,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			EmptyLabel = React.createElement("TextLabel", {
				Text = "No items",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = theme.nameFont,
				TextColor3 = theme.nameColor,
				TextSize = 14,
				ZIndex = 6,
			}),
		})
	end

	local children: { [string]: any } = {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, cornerRadius),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = theme.slotBorderColor,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
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

	for i, slotData in props.slots do
		children["Slot_" .. i] = React.createElement(Slot, {
			index = i,
			slotData = slotData,
			isSelected = props.selectedIndex == i,
			theme = theme,
			onSelect = props.onSelect,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(gridWidth, gridHeight),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = theme.panelBackgroundColor,
		BackgroundTransparency = theme.panelBackgroundTransparency,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, children)
end

return BackpackPanel
