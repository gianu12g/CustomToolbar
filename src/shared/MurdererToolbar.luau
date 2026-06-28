--!strict
--[[
	MurdererToolbar
	A lightweight controller that DRIVES a hand-made ScreenGui hotbar
	(StarterGui.MurdererGUI) instead of building its UI in code.

	Unlike CustomToolbar / TheHostToolbar (which render their slots with
	React), this module binds to the existing manually-built instances:

		MurdererGUI                (ScreenGui, lives in the place's StarterGui)
		└─ innerParent             (Frame, aspect-locked)
		   ├─ toolbarBG            (rotated 45° container; 2x2 wrapping list)
		   │   └─ "1".."4"         slot Frames, each with an ICON ImageLabel
		   └─ IndicatorVectors*    number-label frames, mapped to slots by the
		                           digit shown in their TextLabel ("1".."4")

	Behaviour
	  • Disables the native backpack (this hotbar has no separate inventory).
	  • Up to `slotCount` tools map to slots. A Tool with a numeric "Slot"
	    attribute (1-4) claims that slot; the rest fill the remaining slots
	    and keep their position (no icon-jumping on equip/unequip).
	  • Slot icons are taken from each Tool.TextureId automatically.
	  • Selecting a slot (number key or click/tap) equips/unequips its tool.
	    The equipped slot turns `selectedColor` @ `selectedTransparency` and
	    shows its indicator; every other slot uses `normalColor` @
	    `normalTransparency` with its indicator hidden.

	API (mirrors the sibling toolbar modules)
	  MurdererToolbar.new(config?) -> handle
	  handle:Mount()
	  handle:Destroy()
	  handle._screenGui            -> the bound MurdererGUI ScreenGui (nil until it binds;
	                                  re-points at the new clone each respawn)

	Example
	  local MurdererToolbar = require(ReplicatedStorage.Shared.MurdererToolbar)
	  MurdererToolbar.new():Mount()
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- CollectionService tag added to the bound ScreenGui so other systems can find /
-- exclude it. Re-applied on every bind (the GUI re-clones on respawn).
local EXCLUDE_TAG = "Exclude"

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

export type Config = {
	guiName: string?, -- name of the hand-made ScreenGui (default "MurdererGUI")
	slotCount: number?, -- number of slots / max tools (default 4)

	normalColor: Color3?, -- unselected slot frame colour (default white)
	normalTransparency: number?, -- unselected slot frame transparency (default 0.9)
	selectedColor: Color3?, -- selected slot frame colour (default red)
	selectedTransparency: number?, -- selected slot frame transparency (default 0.7)

	keybindsEnabled: boolean?, -- number keys 1-9 select slots (default true)
	clickToSelect: boolean?, -- click / tap a slot to select it (default true)
	autoManageBackpack: boolean?, -- hide the native backpack/hotbar (default true)
}

local DEFAULTS = {
	guiName = "MurdererGUI",
	slotCount = 4,
	normalColor = Color3.fromRGB(255, 255, 255),
	normalTransparency = 0.9,
	selectedColor = Color3.fromRGB(255, 0, 0),
	selectedTransparency = 0.7,
	keybindsEnabled = true,
	clickToSelect = true,
	autoManageBackpack = true,
}

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
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
}

type Slot = {
	frame: Frame,
	image: ImageLabel?,
	button: TextButton,
	indicator: GuiObject?,
	tool: Tool?,
}

type Binding = {
	gui: ScreenGui,
	slots: { Slot },
	conns: { RBXScriptConnection },
	assigned: { [Tool]: number },
}

---------------------------------------------------------------------------
-- Handle
---------------------------------------------------------------------------

local ToolbarHandle = {}
ToolbarHandle.__index = ToolbarHandle

local function pick(value: any, fallback: any): any
	if value == nil then
		return fallback
	end
	return value
end

function ToolbarHandle.new(config: Config?)
	local self = setmetatable({}, ToolbarHandle)
	local cfg = config or {} :: Config

	self._cfg = {
		guiName = cfg.guiName or DEFAULTS.guiName,
		slotCount = cfg.slotCount or DEFAULTS.slotCount,
		normalColor = cfg.normalColor or DEFAULTS.normalColor,
		normalTransparency = pick(cfg.normalTransparency, DEFAULTS.normalTransparency),
		selectedColor = cfg.selectedColor or DEFAULTS.selectedColor,
		selectedTransparency = pick(cfg.selectedTransparency, DEFAULTS.selectedTransparency),
		keybindsEnabled = pick(cfg.keybindsEnabled, DEFAULTS.keybindsEnabled),
		clickToSelect = pick(cfg.clickToSelect, DEFAULTS.clickToSelect),
		autoManageBackpack = pick(cfg.autoManageBackpack, DEFAULTS.autoManageBackpack),
	}

	self._player = Players.LocalPlayer
	self._conns = {} :: { RBXScriptConnection }
	self._toolConns = {} :: { RBXScriptConnection }
	self._binding = nil :: Binding?
	self._screenGui = nil :: ScreenGui? -- the bound MurdererGUI (exposed, like TheHostToolbar)
	self._mounted = false
	return self
end

-- Disable the native backpack. Retries briefly because SetCoreGuiEnabled can
-- be rejected if called before the CoreGui has finished registering.
function ToolbarHandle:_disableBackpack()
	if not self._cfg.autoManageBackpack then
		return
	end
	task.spawn(function()
		for _ = 1, 30 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then
				return
			end
			task.wait(0.1)
		end
	end)
end

function ToolbarHandle:_gatherTools(): { Tool }
	local tools: { Tool } = {}
	local player = self._player

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, c in backpack:GetChildren() do
			if c:IsA("Tool") then
				table.insert(tools, c)
			end
		end
	end

	local char = player.Character
	if char then
		for _, c in char:GetChildren() do
			if c:IsA("Tool") then
				table.insert(tools, c)
			end
		end
	end

	-- Stable order so attribute-less tools don't shuffle between refreshes.
	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)
	return tools
end

-- Slot assignment: "Slot" attribute first, then keep prior assignments, then
-- fill whatever is left. Mirrors the request: attribute priority, rest filled.
function ToolbarHandle:_assignSlots()
	local b = self._binding
	if not b then
		return
	end
	local n = self._cfg.slotCount

	for i = 1, n do
		if b.slots[i] then
			b.slots[i].tool = nil
		end
	end

	local tools = self:_gatherTools()
	local leftovers: { Tool } = {}

	-- Pass 1 — honour an explicit numeric "Slot" attribute (highest priority).
	for _, tool in tools do
		local s = tonumber(tool:GetAttribute("Slot"))
		if s and b.slots[s] and b.slots[s].tool == nil then
			b.slots[s].tool = tool
			b.assigned[tool] = s
		else
			table.insert(leftovers, tool)
		end
	end

	-- Pass 2 — keep a tool in the slot it previously held, if still free.
	local rest: { Tool } = {}
	for _, tool in leftovers do
		local s = b.assigned[tool]
		if s and b.slots[s] and b.slots[s].tool == nil then
			b.slots[s].tool = tool
		else
			table.insert(rest, tool)
		end
	end

	-- Pass 3 — drop the remainder into the first free slots.
	local idx = 1
	for _, tool in rest do
		while idx <= n and b.slots[idx] and b.slots[idx].tool ~= nil do
			idx += 1
		end
		if idx > n then
			break
		end
		if b.slots[idx] then
			b.slots[idx].tool = tool
			b.assigned[tool] = idx
		end
	end
end

function ToolbarHandle:_refresh()
	local b = self._binding
	if not b then
		return
	end
	local cfg = self._cfg
	local char = self._player.Character

	for i = 1, cfg.slotCount do
		local slot = b.slots[i]
		if slot then
			local tool = slot.tool

			-- Icon: auto from the tool's TextureId; blank when the slot is empty.
			if slot.image then
				if tool and tool.TextureId ~= "" then
					slot.image.Image = tool.TextureId
					slot.image.ImageTransparency = 0
				else
					slot.image.Image = ""
					slot.image.ImageTransparency = 1
				end
			end

			-- Selected = this slot's tool is currently equipped (parented to char).
			local selected = tool ~= nil and char ~= nil and tool.Parent == char
			slot.frame.BackgroundColor3 = if selected then cfg.selectedColor else cfg.normalColor
			slot.frame.BackgroundTransparency = if selected then cfg.selectedTransparency else cfg.normalTransparency
			if slot.indicator then
				slot.indicator.Visible = selected
			end
		end
	end
end

function ToolbarHandle:_rebuild()
	self:_assignSlots()
	self:_refresh()
end

function ToolbarHandle:_selectSlot(n: number)
	local b = self._binding
	if not b then
		return
	end
	local slot = b.slots[n]
	if not slot or not slot.tool then
		return
	end
	local char = self._player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local tool = slot.tool
	pcall(function()
		if tool.Parent == char then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(tool)
		end
	end)
	-- Equip/unequip fires Character child events that also refresh, but do it
	-- now too so the highlight feels instant.
	self:_refresh()
end

function ToolbarHandle:_unbind()
	local b = self._binding
	if not b then
		return
	end
	for _, conn in b.conns do
		conn:Disconnect()
	end
	for _, slot in b.slots do
		if slot.button then
			slot.button:Destroy()
		end
	end
	self._binding = nil
	self._screenGui = nil
end

-- Bind to a concrete MurdererGUI instance (the PlayerGui copy). Re-runs each
-- time the GUI is (re)added, e.g. when ResetOnSpawn re-clones it on respawn.
function ToolbarHandle:_bind(gui: ScreenGui)
	self:_unbind()

	local innerParent = gui:WaitForChild("innerParent")
	local toolbarBG = innerParent:WaitForChild("toolbarBG")

	-- Map indicators to slot numbers by the digit shown in their label, since
	-- the instance names are not perfectly consistent.
	local indicators: { [number]: GuiObject } = {}
	for _, child in innerParent:GetChildren() do
		if child:IsA("GuiObject") and string.find(child.Name, "Indicator") then
			local label = child:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel?
			local num = label and tonumber(label.Text)
			if num then
				indicators[num] = child
			end
		end
	end

	local binding: Binding = {
		gui = gui,
		slots = {},
		conns = {},
		assigned = (setmetatable({}, { __mode = "k" }) :: any) :: { [Tool]: number },
	}

	for i = 1, self._cfg.slotCount do
		local frame = toolbarBG:FindFirstChild(tostring(i))
		if frame and frame:IsA("Frame") then
			-- Invisible, cross-platform (mouse + touch) click catcher.
			local button = Instance.new("TextButton")
			button.Name = "SlotButton"
			button.Text = ""
			button.BackgroundTransparency = 1
			button.AutoButtonColor = false
			button.Size = UDim2.fromScale(1, 1)
			button.ZIndex = 10
			button.Active = self._cfg.clickToSelect
			button.Parent = frame

			binding.slots[i] = {
				frame = frame,
				image = frame:FindFirstChildWhichIsA("ImageLabel") :: ImageLabel?,
				button = button,
				indicator = indicators[i],
				tool = nil,
			}

			if self._cfg.clickToSelect then
				local index = i
				table.insert(
					binding.conns,
					button.Activated:Connect(function()
						self:_selectSlot(index)
					end)
				)
			end
		end
	end

	self._binding = binding
	self._screenGui = gui
	gui.Enabled = true -- the GUI ships disabled in StarterGui; reveal it on mount/bind
	CollectionService:AddTag(gui, EXCLUDE_TAG)
	self:_rebuild()
end

-- (Re)connect Backpack + Character tool listeners. Called on mount and on each
-- respawn so a fresh Backpack/Character is always watched.
function ToolbarHandle:_hookTools()
	for _, conn in self._toolConns do
		conn:Disconnect()
	end
	self._toolConns = {}

	local player = self._player
	local function watch(container: Instance)
		table.insert(
			self._toolConns,
			container.ChildAdded:Connect(function(c)
				if c:IsA("Tool") then
					self:_rebuild()
				end
			end)
		)
		table.insert(
			self._toolConns,
			container.ChildRemoved:Connect(function(c)
				if c:IsA("Tool") then
					self:_rebuild()
				end
			end)
		)
	end

	task.spawn(function()
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			watch(backpack)
		end
		self:_rebuild()
	end)

	local char = player.Character
	if char then
		watch(char)
	end
end

function ToolbarHandle:Mount()
	if self._mounted then
		warn("[MurdererToolbar] Already mounted. Call :Destroy() first.")
		return
	end
	self._mounted = true

	local player = self._player
	local playerGui = player:WaitForChild("PlayerGui")

	self:_disableBackpack()

	-- Keyboard (persistent across respawns).
	if self._cfg.keybindsEnabled then
		table.insert(
			self._conns,
			UserInputService.InputBegan:Connect(function(input, _gameProcessed)
				-- Skip while the player is typing (chat / any TextBox). We do NOT
				-- gate on `gameProcessed`: with the native backpack disabled the
				-- top-row number keys can still be flagged as a CoreGui action,
				-- which would otherwise be swallowed before reaching the hotbar.
				if UserInputService:GetFocusedTextBox() then
					return
				end
				local n = NUMBER_KEYS[input.KeyCode]
				if n and n <= self._cfg.slotCount then
					self:_selectSlot(n)
				end
			end)
		)
	end

	-- Bind to the hand-made GUI now and whenever it is (re)added.
	table.insert(
		self._conns,
		playerGui.ChildAdded:Connect(function(child)
			if child.Name == self._cfg.guiName and child:IsA("ScreenGui") then
				self:_bind(child)
			end
		end)
	)
	local existing = playerGui:FindFirstChild(self._cfg.guiName)
	if existing and existing:IsA("ScreenGui") then
		self:_bind(existing)
	end

	-- Tool syncing (re-hook each spawn).
	self:_hookTools()
	table.insert(
		self._conns,
		player.CharacterAdded:Connect(function()
			self:_hookTools()
			self:_rebuild()
		end)
	)
end

function ToolbarHandle:Destroy()
	for _, conn in self._conns do
		conn:Disconnect()
	end
	self._conns = {}
	for _, conn in self._toolConns do
		conn:Disconnect()
	end
	self._toolConns = {}
	self:_unbind()
	self._mounted = false
end

---------------------------------------------------------------------------
-- Public module
---------------------------------------------------------------------------

local MurdererToolbar = {}

--- Create a new (unmounted) toolbar handle. Call :Mount() to activate it.
function MurdererToolbar.new(config: Config?): typeof(ToolbarHandle.new())
	return ToolbarHandle.new(config)
end

return MurdererToolbar
