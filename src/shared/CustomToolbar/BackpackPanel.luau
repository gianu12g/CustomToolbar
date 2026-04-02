--!strict
--[[
	CustomToolbar – BackpackPanel
	Extension inventory grid showing overflow tools not on the hotbar.
	Always shows a fixed grid of slots (filled + empty) so players can
	drag items into any open cell. Mirrors Roblox backpack behaviour.
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
}

local function BackpackPanel(props: Props)
	local theme = props.theme
	local slotSize = theme.slotSize :: number
	local padding = theme.slotPadding :: number
	local columns = theme.panelColumns :: number
	local cornerRadius = theme.panelCornerRadius :: number

	local slotCount = #props.slots
	local minRows = props.minRows or 3
	-- Always show at least minRows of slots so there are empty drop targets
	local minCells = columns * minRows
	local totalCells = math.max(slotCount + columns, minCells) -- always at least one extra row
	local rows = math.ceil(totalCells / columns)
	totalCells = rows * columns -- snap to full rows

	local gridWidth = (columns * slotSize) + ((columns - 1) * padding) + padding * 2
	local gridHeight = (rows * slotSize) + ((rows - 1) * padding) + padding * 2

	-- Add space for title bar
	local titleHeight = 28
	local panelHeight = gridHeight + titleHeight

	if not props.visible then
		return nil
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
				Size = UDim2.new(1, -8, 1, 0),
				Position = UDim2.fromOffset(padding + 2, 0),
				BackgroundTransparency = 1,
				FontFace = theme.numberFont,
				TextColor3 = theme.nameColor,
				TextSize = 13,
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

		-- Grid container (offset below title)
		GridContainer = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, -titleHeight),
			Position = UDim2.fromOffset(0, titleHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 5,
		}, (function()
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
				local slotData = props.slots[i] -- nil for empty cells
				gridChildren["Slot_" .. i] = React.createElement(Slot, {
					index = i,
					slotData = slotData,
					isSelected = false,
					theme = theme,
					source = "backpack",
					onMouseDown = props.onSlotMouseDown,
					onHoverChange = props.onSlotHoverChange,
					isDragOver = props.dragOverIndex == i,
					isBeingDragged = props.dragFromIndex == i,
				})
			end

			return gridChildren
		end)()),
	}

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(gridWidth, panelHeight),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = theme.panelBackgroundColor,
		BackgroundTransparency = theme.panelBackgroundTransparency,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, children)
end

return BackpackPanel
