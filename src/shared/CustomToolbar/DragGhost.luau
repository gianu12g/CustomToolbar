--!strict
--[[
	CustomToolbar – DragGhost
	Floating image that follows the cursor during a drag operation.
	Pure render component — zero state, zero logic.

	mousePos is expected in viewport space (from GetMouseLocation),
	which maps directly to the ScreenGui with IgnoreGuiInset = false.
	No GUI inset correction is needed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)

type Props = {
	slotData: Types.SlotData,
	mousePos: Vector2,
	theme: Types.ThemeConfig,
}

local function DragGhost(props: Props)
	local theme = props.theme
	local slotSize = theme.slotSize :: number
	local ghostSize = slotSize * 0.8
	local cornerRadius = theme.slotCornerRadius :: number

	return React.createElement("ImageLabel", {
		Image = props.slotData.icon,
		ImageColor3 = theme.iconColor,
		Size = UDim2.fromOffset(ghostSize, ghostSize),
		Position = UDim2.fromOffset(
			props.mousePos.X - ghostSize / 2,
			props.mousePos.Y - ghostSize / 2
		),
		BackgroundColor3 = theme.slotBackgroundColor,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 100,
		ScaleType = Enum.ScaleType.Fit,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, cornerRadius),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = theme.slotSelectedBorderColor,
			Thickness = theme.slotBorderWidth,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

return DragGhost
