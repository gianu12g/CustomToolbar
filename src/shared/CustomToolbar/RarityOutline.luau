--!strict
--[[
	RarityOutline
	A lightweight spinning gradient outline effect for toolbar slots.
	Replaces ezVisualz — same look as "RainbowOutline" but with
	custom rarity colours instead of a rainbow.

	Usage:
		local effect = RarityOutline.new(guiObject, rarityColor, speed)
		effect:Destroy()
]]

local RunService = game:GetService("RunService")

local RarityOutline = {}
RarityOutline.__index = RarityOutline

export type RarityOutline = {
	Instance: GuiObject,
	Stroke: UIStroke,
	Gradient: UIGradient,
	Connection: RBXScriptConnection,
	Destroy: (self: RarityOutline) -> (),
}

--[[
	Build a colour sequence from a single rarity colour.
	Creates a gradient: base → lighter highlight → base
	so the spinning outline has a visible "shine" sweep.
]]
local function buildColorSequence(color: Color3): ColorSequence
	local highlight = color:Lerp(Color3.new(1, 1, 1), 0.55)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.35, color),
		ColorSequenceKeypoint.new(0.5, highlight),
		ColorSequenceKeypoint.new(0.65, color),
		ColorSequenceKeypoint.new(1, color),
	})
end

--[[
	Named preset colour sequences.
	Each loops seamlessly (first and last keypoints match)
	so the spinning gradient has no visible seam.
]]
local PRESETS: { [string]: ColorSequence } = {
	Rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromHSV(0 / 360, 1, 1)),    -- red
		ColorSequenceKeypoint.new(0.17, Color3.fromHSV(60 / 360, 1, 1)),   -- yellow
		ColorSequenceKeypoint.new(0.33, Color3.fromHSV(120 / 360, 1, 1)),  -- green
		ColorSequenceKeypoint.new(0.5,  Color3.fromHSV(180 / 360, 1, 1)),  -- cyan
		ColorSequenceKeypoint.new(0.67, Color3.fromHSV(240 / 360, 1, 1)),  -- blue
		ColorSequenceKeypoint.new(0.83, Color3.fromHSV(300 / 360, 1, 1)),  -- magenta
		ColorSequenceKeypoint.new(1,    Color3.fromHSV(0 / 360, 1, 1)),    -- back to red
	}),

	Fire = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(200, 30, 0)),    -- deep red
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 100, 0)),   -- orange
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(255, 200, 30)),  -- yellow-gold
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 100, 0)),   -- orange
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(200, 30, 0)),    -- back to deep red
	}),

	Ice = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(60, 150, 255)),   -- sky blue
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(130, 220, 255)), -- light cyan
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(230, 245, 255)), -- near-white frost
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(130, 220, 255)), -- light cyan
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(60, 150, 255)),   -- back to sky blue
	}),

	Toxic = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(30, 200, 50)),    -- neon green
		ColorSequenceKeypoint.new(0.2,  Color3.fromRGB(10, 80, 20)),     -- dark green
		ColorSequenceKeypoint.new(0.4,  Color3.fromRGB(140, 30, 200)),   -- vivid purple
		ColorSequenceKeypoint.new(0.6,  Color3.fromRGB(50, 10, 50)),     -- near-black purple
		ColorSequenceKeypoint.new(0.8,  Color3.fromRGB(30, 200, 50)),    -- neon green
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(30, 200, 50)),    -- seamless loop
	}),

	Galaxy = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(90, 20, 180)),    -- deep purple
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(220, 60, 180)),   -- hot pink
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(60, 80, 220)),    -- rich blue
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 40, 220)),   -- magenta-violet
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(90, 20, 180)),    -- back to deep purple
	}),
}

-- Expose presets so other scripts can reference them by name
RarityOutline.Presets = PRESETS

--[[
	Creates the spinning outline effect.

	@param uiInstance  The GuiObject to attach the outline to.
	@param color       The rarity base colour (ignored when preset is provided).
	@param speed       Rotation speed (degrees per second). ~65-75 feels smooth.
	@param thickness   Stroke thickness in pixels. Default 3.
	@param preset      Optional preset name ("Rainbow", "Fire", "Ice", "Toxic", "Galaxy").
	                   When provided, overrides the single-colour gradient.
]]
function RarityOutline.new(uiInstance: GuiObject, color: Color3, speed: number?, thickness: number?, preset: string?): RarityOutline
	local self = setmetatable({}, RarityOutline) :: any

	local strokeThickness = thickness or 3
	local rotationSpeed = speed or 70

	-- Create the UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1) -- white base so UIGradient colors aren't multiplied to black
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = strokeThickness
	stroke.Parent = uiInstance

	-- Create the UIGradient on the stroke
	local gradient = Instance.new("UIGradient")
	gradient.Color = if preset and PRESETS[preset] then PRESETS[preset] else buildColorSequence(color)
	gradient.Transparency = NumberSequence.new(0)
	gradient.Parent = stroke

	self.Instance = uiInstance
	self.Stroke = stroke
	self.Gradient = gradient

	-- Spin the gradient
	local rotation = 0
	self.Connection = RunService.Heartbeat:Connect(function(dt)
		if not stroke.Parent then
			self:Destroy()
			return
		end
		rotation = (rotation + rotationSpeed * dt) % 360
		gradient.Rotation = rotation
	end)

	return self
end

function RarityOutline:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self.Gradient then
		self.Gradient:Destroy()
		self.Gradient = nil
	end
	if self.Stroke then
		self.Stroke:Destroy()
		self.Stroke = nil
	end
end

return RarityOutline
