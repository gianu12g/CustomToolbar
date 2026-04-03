--!strict
--[[
	CustomToolbar – useDragAndDrop
	React hook that owns the entire drag-and-drop lifecycle.

	CRITICAL DESIGN DECISION: all drag state lives as React.useState so that
	state changes and UI updates happen in the same reconciliation pass.
	This is why the original system worked — never move drag state into an
	external store with async notification.

	Phases: Idle → Pending (press started) → Active (threshold met) → Complete/Cancel
	On complete: resolves drop target and applies slot mutations.
	On click (released before threshold): calls onSlotClick for equip/unequip.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(script.Parent.Types)

local DRAG_THRESHOLD = 5

---------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------

export type DragInfo = {
	source: string,
	index: number,
	slotData: Types.SlotData,
	startPos: Vector2,
}

export type HoverTarget = {
	targetType: string,
	targetIndex: number,
}

type UseDragConfig = {
	holdTimeClosed: number,
	holdTimeOpen: number,
	player: Player,
	-- Refs to current slot state (stale-closure-safe reads)
	hotbarRef: { current: { Types.SlotData? } },
	backpackRef: { current: { Types.SlotData } },
	selectedRef: { current: number? },
	backpackOpenRef: { current: boolean },
	-- State setters for slot mutations on drop
	setHotbarSlots: (any) -> (),
	setBackpackSlots: (any) -> (),
	setSelectedIndex: (any) -> (),
	setBackpackOpen: (any) -> (),
	-- Called when a slot is clicked (not dragged) for equip/unequip
	onSlotClick: (index: number, source: string) -> (),
}

type UseDragReturn = {
	isDragging: boolean,
	dragInfo: DragInfo?,
	mousePos: Vector2,
	hoverTarget: HoverTarget?,
	onSlotMouseDown: (index: number, source: string) -> (),
	onSlotHoverChange: (index: number, source: string, hovering: boolean) -> (),
	justDraggedRef: { current: boolean },
}

---------------------------------------------------------------------------
-- Hook
---------------------------------------------------------------------------

local function useDragAndDrop(config: UseDragConfig): UseDragReturn
	-----------------------------------------------------------------------
	-- Drag UI state (React-owned — synchronous updates, no timing gaps)
	-----------------------------------------------------------------------
	local dragInfo, setDragInfo = React.useState(nil :: DragInfo?)
	local isDragging, setIsDragging = React.useState(false)
	local mousePos, setMousePos = React.useState(Vector2.zero)
	local hoverTarget, setHoverTarget = React.useState(nil :: HoverTarget?)

	-- Hold timer
	local dragHoldReady, setDragHoldReady = React.useState(false)
	local dragHoldReadyRef = React.useRef(dragHoldReady)
	dragHoldReadyRef.current = dragHoldReady

	-- Refs for stale closure avoidance in UserInputService handlers
	local dragInfoRef = React.useRef(dragInfo)
	local isDraggingRef = React.useRef(isDragging)
	local hoverTargetRef = React.useRef(hoverTarget)
	dragInfoRef.current = dragInfo
	isDraggingRef.current = isDragging
	hoverTargetRef.current = hoverTarget

	-- Config ref (always latest)
	local configRef = React.useRef(config)
	configRef.current = config

	-- Track whether backpack was open before drag started
	local backpackWasOpenRef = React.useRef(false)

	-- Suppress ghost clicks on buttons after drag completes
	local justDraggedRef = React.useRef(false)

	-----------------------------------------------------------------------
	-- cancelDrag: reset all drag state
	-----------------------------------------------------------------------
	local function cancelDrag()
		setDragInfo(nil)
		setIsDragging(false)
		setHoverTarget(nil)
	end

	-----------------------------------------------------------------------
	-- completeDrag: resolve the drop target and apply slot mutations
	-----------------------------------------------------------------------
	local function completeDrag()
		local drag = dragInfoRef.current
		local hover = hoverTargetRef.current
		local wasDragging = isDraggingRef.current
		local cfg = configRef.current

		-- Flag to suppress ghost click on backpack button
		justDraggedRef.current = true
		task.delay(0.15, function()
			justDraggedRef.current = false
		end)

		if not drag or not wasDragging then
			cancelDrag()
			return
		end

		local srcType = drag.source
		local srcIdx = drag.index
		local srcSlot = drag.slotData

		if hover then
			local dstType = hover.targetType
			local dstIdx = hover.targetIndex

			------------------------------------------------------------
			-- Drop on backpack button → move hotbar item to backpack
			------------------------------------------------------------
			if dstType == "backpackButton" then
				if srcType == "hotbar" then
					cfg.setHotbarSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = nil
						return new
					end)
					cfg.setBackpackSlots(function(prev)
						local new = table.clone(prev)
						table.insert(new, srcSlot)
						return new
					end)
					if cfg.selectedRef.current == srcIdx then
						cfg.setSelectedIndex(nil)
						local humanoid = cfg.player.Character
							and cfg.player.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid:UnequipTools()
						end
					end
				end

			------------------------------------------------------------
			-- Hotbar → Hotbar: swap
			------------------------------------------------------------
			elseif srcType == "hotbar" and dstType == "hotbar" then
				cfg.setHotbarSlots(function(prev)
					local new = table.clone(prev)
					new[srcIdx], new[dstIdx] = new[dstIdx], new[srcIdx]
					return new
				end)
				local sel = cfg.selectedRef.current
				if sel == srcIdx then
					cfg.setSelectedIndex(dstIdx)
				elseif sel == dstIdx then
					cfg.setSelectedIndex(srcIdx)
				end

			------------------------------------------------------------
			-- Hotbar → Backpack slot: swap or insert
			------------------------------------------------------------
			elseif srcType == "hotbar" and dstType == "backpack" then
				local dstSlot = cfg.backpackRef.current[dstIdx]
				if dstSlot then
					-- Swap: backpack item goes to hotbar, hotbar item goes to backpack
					cfg.setHotbarSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = dstSlot
						return new
					end)
					cfg.setBackpackSlots(function(prev)
						local new = table.clone(prev)
						new[dstIdx] = srcSlot
						return new
					end)
				else
					-- Dropped on empty backpack cell → append to backpack, clear hotbar
					cfg.setHotbarSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = nil
						return new
					end)
					cfg.setBackpackSlots(function(prev)
						local new = table.clone(prev)
						table.insert(new, srcSlot)
						return new
					end)
				end
				if cfg.selectedRef.current == srcIdx then
					cfg.setSelectedIndex(nil)
					local humanoid = cfg.player.Character
						and cfg.player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:UnequipTools()
					end
				end

			------------------------------------------------------------
			-- Backpack → Hotbar: swap (or move if hotbar slot is empty)
			------------------------------------------------------------
			elseif srcType == "backpack" and dstType == "hotbar" then
				local dstSlot = cfg.hotbarRef.current[dstIdx]
				cfg.setHotbarSlots(function(prev)
					local new = table.clone(prev)
					new[dstIdx] = srcSlot
					return new
				end)
				if dstSlot then
					-- Displaced hotbar item takes the backpack slot
					cfg.setBackpackSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx] = dstSlot
						return new
					end)
				else
					-- Empty hotbar slot — just remove from backpack
					cfg.setBackpackSlots(function(prev)
						local new = {}
						for i, slot in prev do
							if i ~= srcIdx then
								table.insert(new, slot)
							end
						end
						return new
					end)
				end

			------------------------------------------------------------
			-- Backpack → Backpack: swap
			------------------------------------------------------------
			elseif srcType == "backpack" and dstType == "backpack" then
				local dstSlot = cfg.backpackRef.current[dstIdx]
				if dstSlot then
					cfg.setBackpackSlots(function(prev)
						local new = table.clone(prev)
						new[srcIdx], new[dstIdx] = new[dstIdx], new[srcIdx]
						return new
					end)
				end
			end
		end
		-- Drop on nothing → cancel (no change)

		cancelDrag()
	end

	-----------------------------------------------------------------------
	-- Stable callbacks for slot components (via useCallback + refs)
	-----------------------------------------------------------------------

	local onSlotMouseDown = React.useCallback(function(index: number, source: string)
		local cfg = configRef.current
		local slotData: Types.SlotData?
		if source == "hotbar" then
			slotData = cfg.hotbarRef.current[index]
		else
			slotData = cfg.backpackRef.current[index]
		end

		if not slotData then
			-- Empty slot click
			if source == "hotbar" then
				cfg.setSelectedIndex(nil)
			end
			return
		end

		local mouseLocation = UserInputService:GetMouseLocation()
		setDragInfo({
			source = source,
			index = index,
			slotData = slotData,
			startPos = mouseLocation,
		})
		setMousePos(mouseLocation)
	end, {})

	local onSlotHoverChange = React.useCallback(function(index: number, source: string, hovering: boolean)
		if hovering then
			setHoverTarget({
				targetType = source,
				targetIndex = index,
			})
		else
			-- Only clear if this slot is still the hovered target
			setHoverTarget(function(prev)
				if prev and prev.targetType == source and prev.targetIndex == index then
					return nil
				end
				return prev
			end)
		end
	end, {})

	-----------------------------------------------------------------------
	-- Effect: drag hold timer
	-----------------------------------------------------------------------
	React.useEffect(function()
		if not dragInfo then
			-- Reset hold readiness when drag is cancelled/completed
			setDragHoldReady(false)
			return function() end
		end

		-- Choose hold time: shorter when backpack is already open for quick rearranging
		local cfg = configRef.current
		local holdTime = if cfg.backpackOpenRef.current then cfg.holdTimeOpen else cfg.holdTimeClosed

		if holdTime <= 0 then
			setDragHoldReady(true)
			return function() end
		end

		-- Start a timer; drag becomes ready after holdTime seconds
		setDragHoldReady(false)
		local cancelled = false
		task.delay(holdTime, function()
			if not cancelled then
				setDragHoldReady(true)
			end
		end)

		return function()
			cancelled = true
		end
	end, { dragInfo } :: { any })

	-----------------------------------------------------------------------
	-- Effect: mouse/touch tracking + release detection
	-----------------------------------------------------------------------
	React.useEffect(function()
		if not dragInfo then
			return function() end
		end

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local pos = Vector2.new(input.Position.X, input.Position.Y)
				setMousePos(pos)

				if not isDraggingRef.current and dragInfoRef.current then
					local delta = pos - dragInfoRef.current.startPos
					if delta.Magnitude > DRAG_THRESHOLD and dragHoldReadyRef.current then
						setIsDragging(true)
						-- Auto-open backpack when drag starts
						local cfg = configRef.current
						cfg.setBackpackOpen(function(prev)
							backpackWasOpenRef.current = prev
							return true
						end)
					end
				end
			end
		end)

		local upConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if isDraggingRef.current then
					completeDrag()
					-- After drag completes, restore backpack open state
					if not backpackWasOpenRef.current then
						local cfg = configRef.current
						cfg.setBackpackOpen(false)
					end
				else
					-- Was a click, not a drag → equip/unequip if hotbar
					local info = dragInfoRef.current
					if info then
						local cfg = configRef.current
						cfg.onSlotClick(info.index, info.source)
					end
					cancelDrag()
				end
			end
		end)

		return function()
			moveConn:Disconnect()
			upConn:Disconnect()
		end
	end, { dragInfo } :: { any })

	-----------------------------------------------------------------------
	-- Return public interface
	-----------------------------------------------------------------------
	return {
		isDragging = isDragging,
		dragInfo = dragInfo,
		mousePos = mousePos,
		hoverTarget = hoverTarget,
		onSlotMouseDown = onSlotMouseDown,
		onSlotHoverChange = onSlotHoverChange,
		justDraggedRef = justDraggedRef,
	}
end

return useDragAndDrop
