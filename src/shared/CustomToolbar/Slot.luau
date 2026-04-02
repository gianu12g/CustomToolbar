--!strict
--[[
	CustomToolbar – Slot
	A single toolbar slot. Handles hover highlight, selection ring,
	number badge, tool icon, and tool name label.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)

type Props = {
	index: number,
	slotData: Types.SlotData?,
	isSelected: boolean,
	theme: Types.ThemeConfig,
	onSelect: (index: number) -> (),
}

local function Slot(props: Props)
	local theme = props.theme
	local slotData = props.slotData
	local isSelected = props.isSelected
	local isHovered, setIsHovered = React.useState(false)

	local slotSize = theme.slotSize :: number
	local cornerRadius = theme.slotCornerRadius :: number

	-- Determine background color
	local bgColor: Color3
	if isSelected then
		bgColor = theme.slotSelectedColor :: Color3
	elseif isHovered and slotData then
		bgColor = theme.slotHoverColor :: Color3
	else
		bgColor = theme.slotBackgroundColor :: Color3
	end

	local borderColor: Color3
	if isSelected then
		borderColor = theme.slotSelectedBorderColor :: Color3
	else
		borderColor = theme.slotBorderColor :: Color3
	end

	local iconSize = theme.iconSizeScale :: number

	return React.createElement("ImageButton", {
		Size = UDim2.fromOffset(slotSize, slotSize),
		BackgroundColor3 = bgColor,
		BackgroundTransparency = theme.slotBackgroundTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = props.index,

		[React.Event.Activated] = function()
			props.onSelect(props.index)
		end,
		[React.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setIsHovered(false)
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

		-- Number badge (top-left)
		NumberLabel = theme.showSlotNumbers and React.createElement("TextLabel", {
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
