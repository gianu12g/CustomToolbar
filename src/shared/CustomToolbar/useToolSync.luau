--!strict
--[[
	CustomToolbar – useToolSync
	React hook that watches the player's Backpack and Character for Tool
	changes and keeps the hotbar/backpack slot arrays in sync.

	Preserves existing slot assignments, prunes removed tools, and places
	new tools in the first empty hotbar slot (overflow goes to backpack).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(script.Parent.Types)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function gatherTools(player: Player): { Tool }
	local tools: { Tool } = {}

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)

	return tools
end

local function toolToSlotData(tool: Tool, order: number): Types.SlotData
	local rarity: string? = nil
	local outlinePreset: string? = nil
	pcall(function()
		local r = tool:GetAttribute("Rarity")
		if type(r) == "string" and r ~= "" then
			rarity = r
		end
		local p = tool:GetAttribute("OutlinePreset")
		if type(p) == "string" and p ~= "" then
			outlinePreset = p
		end
	end)

	return {
		id = tool.Name .. "_" .. tostring(order),
		name = tool.Name,
		icon = tool.TextureId ~= "" and tool.TextureId or "rbxasset://textures/ui/GuiImagePlaceholder.png",
		tool = tool,
		order = order,
		rarity = rarity,
		outlinePreset = outlinePreset,
		onActivated = nil,
	}
end

---------------------------------------------------------------------------
-- Hook
---------------------------------------------------------------------------

type UseToolSyncConfig = {
	enabled: boolean,
	maxSlots: number,
	hotbarRef: { current: { Types.SlotData? } },
	backpackRef: { current: { Types.SlotData } },
	setHotbarSlots: (any) -> (),
	setBackpackSlots: (any) -> (),
	setSelectedIndex: (any) -> (),
}

local function useToolSync(config: UseToolSyncConfig)
	local player = Players.LocalPlayer

	React.useEffect(function()
		if not config.enabled then
			return function() end
		end

		local alive = true
		local connections: { RBXScriptConnection } = {}

		local function refresh()
			if not alive then
				return
			end

			local tools = gatherTools(player)
			local currentHotbar = config.hotbarRef.current
			local currentBackpack = config.backpackRef.current

			-- Build set of tool instances that still exist
			local toolExists: { [Tool]: boolean } = {}
			for _, tool in tools do
				toolExists[tool] = true
			end

			-- Preserve existing assignments, remove dead tools
			local newHotbar: { Types.SlotData? } = {}
			for i = 1, config.maxSlots do
				local slot = currentHotbar[i]
				if slot and slot.tool and toolExists[slot.tool] then
					newHotbar[i] = slot
				end
			end

			local newBackpack: { Types.SlotData } = {}
			for _, slot in currentBackpack do
				if slot.tool and toolExists[slot.tool] then
					table.insert(newBackpack, slot)
				end
			end

			-- Track what's already assigned
			local assigned: { [Tool]: boolean } = {}
			for _, slot in newHotbar do
				if slot and slot.tool then
					assigned[slot.tool] = true
				end
			end
			for _, slot in newBackpack do
				if slot.tool then
					assigned[slot.tool] = true
				end
			end

			-- Place unassigned (new) tools: fill hotbar first, overflow to backpack
			local orderCounter = #tools
			for _, tool in tools do
				if not assigned[tool] then
					local placed = false
					for j = 1, config.maxSlots do
						if not newHotbar[j] then
							orderCounter += 1
							newHotbar[j] = toolToSlotData(tool, orderCounter)
							placed = true
							break
						end
					end
					if not placed then
						orderCounter += 1
						table.insert(newBackpack, toolToSlotData(tool, orderCounter))
					end
				end
			end

			config.setHotbarSlots(newHotbar)
			config.setBackpackSlots(newBackpack)

			-- Update selection to follow the currently equipped tool
			local character = player.Character
			if character then
				local equippedTool = character:FindFirstChildOfClass("Tool")
				if equippedTool then
					for i = 1, config.maxSlots do
						local sd = newHotbar[i]
						if sd and sd.tool == equippedTool then
							config.setSelectedIndex(i)
							return
						end
					end
					-- Equipped tool isn't on hotbar → deselect
					config.setSelectedIndex(nil)
				else
					config.setSelectedIndex(nil)
				end
			end
		end

		local function watchCharacter(char: Model)
			table.insert(connections, char.ChildAdded:Connect(refresh))
			table.insert(connections, char.ChildRemoved:Connect(refresh))
			task.defer(refresh)
		end

		-- Spawn for the yielding WaitForChild call
		task.spawn(function()
			local backpack = player:WaitForChild("Backpack", 10)
			if not alive then
				return
			end
			if backpack then
				table.insert(connections, backpack.ChildAdded:Connect(refresh))
				table.insert(connections, backpack.ChildRemoved:Connect(refresh))
			end
			refresh()
		end)

		table.insert(connections, player.CharacterAdded:Connect(function(char)
			watchCharacter(char)
		end))

		if player.Character then
			watchCharacter(player.Character)
		end

		refresh()

		return function()
			alive = false
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { config.enabled } :: { any })
end

return useToolSync
