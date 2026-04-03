--!strict
--[[
	CustomToolbar – useKeyboardInput
	React hook for keyboard shortcuts (1-9 number keys, backquote toggle).
	Gamepad bumper support can be added here later.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

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

type UseKeyboardInputConfig = {
	enabled: boolean,
	maxSlots: number,
	hotbarRef: { current: any },
	onSelectSlot: (index: number) -> (),
	onToggleBackpack: () -> (),
}

local function useKeyboardInput(config: UseKeyboardInputConfig)
	-- Store config in a ref so the effect closure always reads the latest
	local configRef = React.useRef(config)
	configRef.current = config

	React.useEffect(function()
		if not config.enabled then
			return function() end
		end

		local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			local cfg = configRef.current

			-- Number keys 1-9 → select hotbar slot
			local slotNum = NUMBER_KEYS[input.KeyCode]
			if slotNum and slotNum <= cfg.maxSlots then
				local slot = cfg.hotbarRef.current[slotNum]
				if slot then
					cfg.onSelectSlot(slotNum)
				end
				return
			end

			-- Backquote (`) toggles backpack panel
			if input.KeyCode == Enum.KeyCode.Backquote then
				cfg.onToggleBackpack()
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, { config.enabled } :: { any })
end

return useKeyboardInput
