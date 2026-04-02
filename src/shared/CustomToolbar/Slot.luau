--!strict
--[[
	CustomToolbar – Slot
	A single toolbar slot. Handles hover highlight, selection ring,
	number badge, tool icon, tool name label, and drag interactions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)

type Props = {
	index: number,
	slotData: Types.SlotData?,
	isSelected: boolean,
	theme: Types.ThemeConfig,
	source: string, -- "hotbar" | "backpack"
	onMouseDown: ((index: number, source: string) -> ())?,
	onHoverChange: ((index: number, source: string, hovering: boolean) -> ())?,
	isDragOver: boolean?,
	isBeingDragged: boolean?,
}

local function Slot(props: Props)
	local theme = props.theme
	local slotData = props.slotData
	local isSelected = props.isSelected
	local isHovered, setIsHovered = React.useState(false)
	local isDragOver = props.isDragOver or false
	local isBeingDragged = props.isBeingDragged or false

	local slotSize = theme.slotSize :: number
	local cornerRadius = theme.slotCornerRadius :: number

	-- Determine background color
	local bgColor: Color3
	if isDragOver then
		bgColor = theme.slotSelectedColor :: Color3
	elseif isSelected then
		bgColor = theme.slotSelectedColor :: Color3
	elseif isHovered and slotData then
		bgColor = theme.slotHoverColor :: Color3
	else
		bgColor = theme.slotBackgroundColor :: Color3
	end

	local borderColor: Color3
	if isDragOver then
		borderColor = theme.slotSelectedBorderColor :: Color3
	elseif isSelected then
		borderColor = theme.slotSelectedBorderColor :: Color3
	else
		borderColor = theme.slotBorderColor :: Color3
	end

	local transparency = theme.slotBackgroundTransparency :: number
	if isBeingDragged then
		transparency = 0.7
	end

	local iconSize = theme.iconSizeScale :: number

	return React.createElement("ImageButton", {
		Size = UDim2.fromOffset(slotSize, slotSize),
		BackgroundColor3 = bgColor,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = props.index,

		[React.Event.InputBegan] = function(_rbx, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if props.onMouseDown then
					props.onMouseDown(props.index, props.source)
				end
			end
		end,
		[React.Event.MouseEnter] = function()
			setIsHovered(true)
			if props.onHoverChange then
				props.onHoverChange(props.index, props.source, true)
			end
		end,
		[React.Event.MouseLeave] = function()
			setIsHovered(false)
			if props.onHoverChange then
				props.onHoverChange(props.index, props.source, false)
			end
		end,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, cornerRadius),
		}),

		Stroke = React.createElement("UIStroke", {
			Color = borderColor,
			Thickness = theme.slotBorderWidth,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		-- Number badge (top-left, hotbar only)
		NumberLabel = theme.showSlotNumbers and props.source == "hotbar" and React.createElement("TextLabel", {
			Text = tostring(props.index),
			Size = UDim2.fromOffset(18, 16),
			Position = UDim2.fromOffset(4, 2),
			BackgroundTransparency = 1,
			FontFace = theme.numberFont,
			TextColor3 = theme.numberColor,
			TextSize = theme.numberSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
		}),

		-- Tool icon
		Icon = slotData and React.createElement("ImageLabel", {
			Image = slotData.icon,
			ImageColor3 = theme.iconColor,
			ImageTransparency = isBeingDragged and 0.5 or 0,
			Size = UDim2.fromScale(iconSize, iconSize),
			Position = UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),

		-- Tool name (bottom)
		NameLabel = slotData and theme.showToolName and React.createElement("TextLabel", {
			Text = slotData.name,
			Size = UDim2.new(1, -4, 0, 14),
			Position = UDim2.new(0, 2, 1, -14),
			BackgroundTransparency = 1,
			FontFace = theme.nameFont,
			TextColor3 = theme.nameColor,
			TextSize = theme.nameSize,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		}),
	})
end

return Slot
