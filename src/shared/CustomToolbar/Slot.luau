--!strict
--[[
	CustomToolbar – Slot
	A single toolbar slot. Handles hover highlight, selection ring,
	number badge, tool icon, tool name label, drag interactions,
	and rarity-based animated border effects via RarityOutline.

	Border rendering has two paths:
	  • Fake textured stroke (theme.fakeStroke = true) — a larger textured
	    ImageLabel sits behind a slightly smaller inner Frame that holds the
	    fill + content, so only a ring of the texture shows around the edges.
	    This is the only way to texture a "stroke"; a real UIStroke is a
	    vector and cannot display an image. Replicates the ExampleFakeUIStroke
	    design (border + inner share a per-corner UICorner; inner has a black
	    45° gradient; selected slots brighten the border background).
	  • Classic flat slot with a vector UIStroke border (fallback).

	cornerVariant ("left" | "center" | "right") drives the per-corner radii so
	a row of slots reads as one rounded pill (left rounds the left edge, right
	rounds the right edge, center is square).
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
-- Per-corner radii for the fake-stroke variants (matches ExampleFakeUIStroke).
-- Applied identically to the border ImageLabel and the inner fill Frame.
---------------------------------------------------------------------------
local ROUND = UDim.new(0.3, 0)
local SHARP = UDim.new(0, 0)
local CORNER_VARIANTS: { [string]: { tl: UDim, tr: UDim, br: UDim, bl: UDim } } = {
	left   = { tl = ROUND, tr = SHARP, br = SHARP, bl = ROUND },
	center = { tl = SHARP, tr = SHARP, br = SHARP, bl = SHARP },
	right  = { tl = SHARP, tr = ROUND, br = ROUND, bl = SHARP },
}

-- Inner fill gradient: solid black, fading from ~0.38 opacity at the
-- two 45° corners to fully transparent in the centre (subtle vignette).
local FILL_GRADIENT_COLOR = ColorSequence.new(Color3.new(0, 0, 0))
local FILL_GRADIENT_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.38125),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 0.38125),
})

-- Build a fresh UICorner element for a variant (callers need distinct elements).
local function makeUICorner(variant: string)
	local r = CORNER_VARIANTS[variant] or CORNER_VARIANTS.center
	return React.createElement("UICorner", {
		TopLeftRadius = r.tl,
		TopRightRadius = r.tr,
		BottomRightRadius = r.br,
		BottomLeftRadius = r.bl,
	})
end

---------------------------------------------------------------------------

type Props = {
	index: number,
	slotData: Types.SlotData?,
	isSelected: boolean,
	theme: Types.ThemeConfig,
	source: string, -- "hotbar" | "backpack"
	cornerVariant: string?, -- "left" | "center" | "right" (default "center")
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
	local isEmptyHidden = not slotData and not showEmptyBG
	local cornerVariant = props.cornerVariant or "center"

	local slotSize = theme.slotSize :: number
	local cornerRadius = theme.slotCornerRadius :: number
	local s = theme._scale or 1 -- viewport scale factor

	-- Fake textured stroke (image-based border; replaces the vector UIStroke).
	local fakeStroke = theme.fakeStroke == true
	local fakeStrokeImage = theme.fakeStrokeImage or ""
	local fakeStrokeColor = theme.fakeStrokeColor or Color3.new(1, 1, 1)
	local fakeStrokeTransparency = theme.fakeStrokeTransparency or 0
	local fakeStrokeThickness = theme.fakeStrokeThickness or 0.07
	-- Inner fill scale: subtract the ring width from both sides.
	local innerScale = math.clamp(1 - 2 * fakeStrokeThickness, 0.1, 1)

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

		-- When the fake textured stroke is active it owns the border entirely;
		-- skip the vector rarity outline so we never double up.
		if fakeStroke then
			return function()
				if effectRef.current then
					pcall(function()
						effectRef.current:Destroy()
					end)
					effectRef.current = nil
				end
			end
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
	end, { rarity, rarityColor, refReady, fakeStroke } :: { any })

	-- Determine background color (classic path / inner fill base)
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

	-- Border colour: selection/drag states override rarity colour (classic path)
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

	-- Dim unequipped hotbar slots by 0.2 transparency ("20%") so the equipped
	-- slot reads as active. The equipped slot (isSelected) and all backpack slots
	-- render at full/current values; equipping also shows the 0.6 border highlight.
	local dim = if props.source == "hotbar" and not isSelected then 0.2 else 0

	local iconSize = theme.iconSizeScale :: number
	local iconFill = fakeStroke -- example fills the slot with the item image

	-- Slot content shared by both render paths (icon, name label).
	local content: { [string]: any } = {
		-- Tool icon (fills the slot when fakeStroke matches the example)
		Icon = slotData and React.createElement("ImageLabel", {
			Image = slotData.icon,
			ImageColor3 = theme.iconColor,
			ImageTransparency = math.min((isBeingDragged and 0.5 or 0) + dim, 1),
			Size = if iconFill then UDim2.fromScale(1, 1) else UDim2.fromScale(iconSize, iconSize),
			Position = if iconFill then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ScaleType = if iconFill then Enum.ScaleType.Stretch else Enum.ScaleType.Fit,
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
			TextTransparency = dim,
			ZIndex = 3,
		}),
	}

	-- Slot number indicator: a circular badge centred just below the slot,
	-- replacing the old top-left number label. Mirrors the user-designed
	-- "SlotIndicator" frame: rounded grey badge with a scaled white numeral and
	-- a black outline. Hotbar only; gated by showSlotNumbers. Fades with the
	-- slot when unequipped (dim).
	local slotIndicator = (theme.showSlotNumbers and props.source == "hotbar") and React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		Position = UDim2.fromScale(0.5, 1.2),
		BackgroundColor3 = Color3.fromRGB(97, 97, 97),
		BackgroundTransparency = math.min(0 + dim, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = React.createElement("UIStroke", {
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 0.05,
			Transparency = math.min(0.83 + dim, 1),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		}),
		Label = React.createElement("TextLabel", {
			Text = tostring(props.index),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.49, 0.49),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = theme.numberFont,
			TextColor3 = theme.numberColor,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTransparency = math.min(0 + dim, 1),
			ZIndex = 4,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 0.05,
				Transparency = math.min(0 + dim, 1),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			}),
		}),
	})

	-- Shared props for the root ImageButton (size + input handling).
	local rootProps: { [string]: any } = {
		Size = UDim2.fromOffset(slotSize, slotSize),
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
	}

	-----------------------------------------------------------------------
	-- Render path A: fake textured stroke (image-based border).
	-- Border ImageLabel fills the slot; a slightly smaller inner Frame holds
	-- the fill + content on top, so only a ring of the texture peeks out.
	-- Selected/drag-over slots brighten the border background (1 → 0.6).
	-----------------------------------------------------------------------
	if fakeStroke and not isEmptyHidden then
		local highlight = isSelected or isDragOver

		-- Inner fill: hover lightens slightly; equipped (selected) brightens more
		-- so an equipped slot reads clearly different from unequipped ones
		-- (on top of the border-background highlight below).
		local baseFill: Color3 = if isHovered and slotData
			then (theme.slotHoverColor :: Color3)
			else (theme.slotBackgroundColor :: Color3)
		local fillColor: Color3 = if isSelected then baseFill:Lerp(Color3.new(1, 1, 1), 0.3) else baseFill

		local innerChildren: { [string]: any } = {
			Corner = makeUICorner(cornerVariant),
			Gradient = React.createElement("UIGradient", {
				Rotation = 45,
				Color = FILL_GRADIENT_COLOR,
				Transparency = FILL_GRADIENT_TRANSPARENCY,
			}),
		}
		for key, value in content do
			innerChildren[key] = value
		end

		rootProps.BackgroundTransparency = 1

		return React.createElement("ImageButton", rootProps, {
			Border = React.createElement("ImageLabel", {
				Image = fakeStrokeImage,
				ImageColor3 = fakeStrokeColor,
				ImageTransparency = math.min(fakeStrokeTransparency + dim, 1),
				ScaleType = Enum.ScaleType.Stretch,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = if highlight then 0.6 else 1,
			}, {
				BorderCorner = makeUICorner(cornerVariant),
				Inner = React.createElement("Frame", {
					Size = UDim2.fromScale(innerScale, innerScale),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = fillColor,
					BackgroundTransparency = math.min(transparency + dim, 1),
					BorderSizePixel = 0,
				}, innerChildren),
			}),
			SlotIndicator = slotIndicator,
		})
	end

	-----------------------------------------------------------------------
	-- Render path B: classic flat slot with a vector UIStroke border.
	-----------------------------------------------------------------------
	rootProps.BackgroundColor3 = bgColor
	rootProps.BackgroundTransparency = transparency

	content.Corner = React.createElement("UICorner", {
		CornerRadius = UDim.new(0, cornerRadius),
	})

	-- UIStroke: rendered only for non-animated slots. For animated rarity slots,
	-- RarityOutline creates its own stroke so we skip this to avoid doubling.
	-- Also hidden when the slot is empty and showEmptySlotBG is false.
	content.Stroke = not hasAnimatedEffect and not isEmptyHidden and React.createElement("UIStroke", {
		Color = borderColor,
		Thickness = theme.slotBorderWidth,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	content.SlotIndicator = slotIndicator

	return React.createElement("ImageButton", rootProps, content)
end

return Slot
