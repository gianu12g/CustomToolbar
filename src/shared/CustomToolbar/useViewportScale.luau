--!strict
--[[
	CustomToolbar – useViewportScale
	React hook that tracks the camera's viewport size and returns a
	uniform scale factor. Decouples viewport logic from the main component.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Theme = require(script.Parent.Theme)

local function useViewportScale(): number
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

	return Theme.computeScale(viewportSize)
end

return useViewportScale
