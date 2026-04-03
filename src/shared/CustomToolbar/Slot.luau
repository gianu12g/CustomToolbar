--!strict
--[[
	CustomToolbar – Slot
	A single toolbar slot. Handles hover highlight, selection ring,
	number badge, tool icon, tool name label, drag interactions,
	and rarity-based animated border effects via RarityOutline.

	All animated rarities use the same spinning gradient outline effect,
	just with different colours and speeds. Common has no animation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local Types = require(script.Parent.Types)
local RarityOutline = require(script.Parent.RarityOutline)

---------------------------------------------------------------------------
-- Rarity → outline rotation speed (degrees/sec). Higher = faster spin.
-- Common has no animated outline. All others use the same spinning
-- gradient outline effect, just with different rarity colours.
---------------------------------------------------------------------------
local RARITY_SPEED: { [string]: number } = {
	Common    = 0,
	Uncommon  = 55,
	Rare      = 65,
	Epic      = 75,
	Legendary = 85,
	Mythic    = 95,
}

---------------------------------------------------------------------------

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
	showEmptySlotBG: boolean?, -- when false, empty slots are fully transparent (default true)
}

local function Slot(props: Props)
	local theme = props.theme
	local slotData = props.slotData
	local isSelected = props.isSelected
	local isHovered, setIsHovered = React.useState(false)
	local isDragOver = props.isDragOver or false
	local isBeingDragged = props.isBeingDragged or false
	local showEmptyBG = if props.showEmptySlotBG == nil then true else props.showEmptySlotBG
	local isEmptyHidden = not slotData and not showEmptyBG and not isDragOver

	local slotSize = theme.slotSize :: number
	local cornerRadius = theme.slotCornerRadius :: number
	local s = theme._scale or 1 -- viewport scale factor

	-- Resolve rarity info
	local rarity: string? = if slotData then slotData.rarity else nil
	local rarityColor: Color3? = nil
	if rarity and theme.rarityColors then
		rarityColor = (theme.rarityColors :: any)[rarity]
	end
	local hasAnimatedEffect = rarity ~= nil and rarity ~= "Common" and rarityColor ~= nil

	-- Ref to the actual Roblox ImageButton instance (for imperative outline calls)
	local slotRef = React.useRef(nil :: any)

	-- Track the active outline effect so we can clean it up
	local effectRef = React.useRef(nil :: any)

	-- Track whether the ref has been set (triggers re-render so useEffect fires)
	local refReady, setRefReady = React.useState(false)
	local refCallback = React.useCallback(function(rbx: any)
		slotRef.current = rbx
		if rbx and not refReady then
			setRefReady(true)
		end
	end, {})

	-----------------------------------------------------------------------
	-- Effect: apply / tear down spinning rarity outline when rarity changes
	-----------------------------------------------------------------------
	React.useEffect(function()
		-- Clean up any previous effect
		if effectRef.current then
			pcall(function()
				effectRef.current:Destroy()
			end)
			effectRef.current = nil
		end

		local instance = slotRef.current
		if not instance or not rarity or not rarityColor then
			return function()
				if effectRef.current then
					pcall(function()
						effectRef.current:Destroy()
					end)
					effectRef.current = nil
				end
			end
		end

		if not hasAnimatedEffect then
			-- Common or unknown rarity → just tint the existing stroke
			local stroke = instance:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = rarityColor
			end
			return function() end
		end

		-- Apply the spinning gradient outline
		local speed = RARITY_SPEED[rarity] or 70

		-- Resolve preset: per-tool override → theme rarity preset → nil (single-colour)
		local preset: string? = nil
		if slotData and slotData.outlinePreset then
			preset = slotData.outlinePreset
		elseif rarity and theme.rarityPresets then
			preset = (theme.rarityPresets :: any)[rarity]
		end

		local ok, effect = pcall(function()
			return RarityOutline.new(
				instance,
				rarityColor,
				speed,
				theme.slotBorderWidth, -- match the theme's stroke thickness
				preset
			)
		end)

		if ok and effect then
			effectRef.current = effect
		end

		return function()
			if effectRef.current then
				pcall(function()
					effectRef.current:Destroy()
				end)
				effectRef.current = nil
			end
		end
	end, { rarity, rarityColor, refReady } :: { any })

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

	-- Border colour: selection/drag states override rarity colour
	local borderColor: Color3
	if isDragOver then
		borderColor = theme.slotSelectedBorderColor :: Color3
	elseif isSelected then
		borderColor = theme.slotSelectedBorderColor :: Color3
	elseif rarityColor and not hasAnimatedEffect then
		-- Static rarity colour (Common or unknown tier)
		borderColor = rarityColor
	else
		borderColor = theme.slotBorderColor :: Color3
	end

	local transparency = theme.slotBackgroundTransparency :: number
	if isEmptyHidden then
		transparency = 1
	elseif isBeingDragged then
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

		ref = refCallback,

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

		-- UIStroke: rendered only for non-animated slots. For animated rarity slots,
		-- RarityOutline creates its own stroke so we skip this to avoid doubling.
		-- Also hidden when the slot is empty and showEmptySlotBG is false.
		Stroke = not hasAnimatedEffect and not isEmptyHidden and React.createElement("UIStroke", {
			Color = borderColor,
			Thickness = theme.slotBorderWidth,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		-- Number badge (top-left, hotbar only)
		NumberLabel = theme.showSlotNumbers and props.source == "hotbar" and React.createElement("TextLabel", {
			Text = tostring(props.index),
			Size = UDim2.fromOffset(math.round(18 * s), math.round(16 * s)),
			Position = UDim2.fromOffset(math.round(4 * s), math.round(2 * s)),
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
			Size = UDim2.new(1, math.round(-4 * s), 0, math.round(14 * s)),
			Position = UDim2.new(0, math.round(2 * s), 1, math.round(-14 * s)),
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
