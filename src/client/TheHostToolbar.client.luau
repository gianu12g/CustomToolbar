-- --!strict
-- --[[
-- 	Client mount — TheHostToolbar

-- 	Game-specific build with the fake textured stroke look ON by default.
-- 	One client script per toolbar module — see also MurdererToolbar.client.luau.

-- 	(Previously this lived in init.client.luau, which was truncated mid-config;
-- 	the config below is the completed version.)

-- 	TOOL SETUP (in Studio or via server script):
-- 		tool:SetAttribute("Rarity", "Epic")          -- border colour + anim speed
-- 		tool:SetAttribute("OutlinePreset", "Toxic")  -- per-tool gradient override
-- 		tool:SetAttribute("Category", "Weapons")     -- enables backpack filter tabs

-- 	Built-in rarity tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic
-- 	Gradient presets:      "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
-- ]]

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local TheHostToolbar = require(ReplicatedStorage.Shared.TheHostToolbar)

-- -- Zero-config alternative: TheHostToolbar.new():Mount()

-- local toolbar = TheHostToolbar.new({

-- 	----- THEME -----
-- 	theme = {

-- 		-- Slot appearance
-- 		slotSize = 70, -- pixel size of each slot square
-- 		slotPadding = 6, -- gap between slots (pixels)
-- 		slotCornerRadius = 10, -- rounded corner radius (pixels)
-- 		slotBackgroundColor = Color3.fromRGB(43, 43, 43), -- inner fill (matches ExampleFakeUIStroke)
-- 		slotBackgroundTransparency = 0, -- 0 = opaque, 1 = invisible
-- 		slotBorderColor = Color3.fromRGB(60, 60, 60), -- panel border / divider / scrollbar tint
-- 		slotBorderWidth = 2, -- border thickness (pixels)
-- 		slotSelectedColor = Color3.fromRGB(70, 130, 220), -- background when selected
-- 		slotSelectedBorderColor = Color3.fromRGB(120, 170, 255), -- border when selected
-- 		slotHoverColor = Color3.fromRGB(55, 55, 55), -- background on hover

-- 		-- Number badge (top-left of hotbar slots)
-- 		showSlotNumbers = true, -- 1-9 labels shown via the SlotIndicator badge
-- 		numberFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
-- 		numberColor = Color3.fromRGB(255, 255, 255),
-- 		numberSize = 12,

-- 		-- Tool name label (bottom of slot)
-- 		showToolName = false, -- toggle name visibility
-- 		nameFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
-- 		nameColor = Color3.fromRGB(220, 230, 245),
-- 		nameSize = 10,

-- 		-- Tool icon
-- 		iconSizeScale = 0.65, -- 0–1, fraction of slot size
-- 		iconColor = Color3.fromRGB(255, 255, 255),

-- 		-- Fake textured border (image-based "stroke" — real UIStrokes can't be textured)
-- 		fakeStroke = true,
-- 		fakeStrokeImage = "rbxassetid://74303582569088",
-- 		fakeStrokeColor = Color3.fromRGB(255, 255, 255),
-- 		fakeStrokeTransparency = 0.45,
-- 		fakeStrokeThickness = 0.05, -- ring width as a fraction of slot size (per side)

-- 		-- Backpack toggle button
-- 		backpackButtonIcon = "rbxasset://textures/ui/TopBar/inventoryOn.png",
-- 		backpackButtonSize = 45,

-- 		-- Backpack panel (grid; toggled with the ` backquote key)
-- 		panelBackgroundColor = Color3.fromRGB(29, 29, 29),
-- 		panelBackgroundTransparency = 0,
-- 		panelCornerRadius = 10,
-- 		panelColumns = 4, -- columns in the backpack grid (8 slots = clean 4x2 grid)

-- 		-- Animations
-- 		selectAnimationSpeed = 0.15, -- seconds for selection tween
-- 		hoverAnimationSpeed = 0.1, -- seconds for hover tween

-- 		-- Rarity border colours (key = Tool:GetAttribute("Rarity") value)
-- 		-- Only override the ones you want — the rest keep defaults.
-- 		rarityColors = {
-- 			-- Common    = Color3.fromRGB(180, 180, 180),
-- 			-- Uncommon  = Color3.fromRGB(80, 200, 80),
-- 			-- Rare      = Color3.fromRGB(70, 130, 255),
-- 			-- Epic      = Color3.fromRGB(180, 70, 255),
-- 			-- Legendary = Color3.fromRGB(255, 170, 0),
-- 			-- Mythic    = Color3.fromRGB(249, 68, 255),
-- 		},

-- 		-- Rarity gradient presets (key = rarity name, value = preset name)
-- 		-- Available presets: "Rainbow", "Fire", "Ice", "Toxic", "Galaxy"
-- 		rarityPresets = {
-- 			-- Mythic    = "Rainbow",
-- 			-- Legendary = "Fire",
-- 			-- Epic      = "Galaxy",
-- 			-- Rare      = "Ice",
-- 		},
-- 	},

-- 	----- LAYOUT -----
-- 	layout = {
-- 		orientation = "Horizontal", -- "Horizontal" or "Vertical"
-- 		position = UDim2.new(0, 24, 1, -24), -- 24px from the left & bottom edges (lower-left corner)
-- 		anchorPoint = Vector2.new(0, 1), -- anchor the toolbar's bottom-left corner
-- 		maxVisibleSlots = 3, -- hotbar slot count (active slots)
-- 		displayOrder = 10, -- ScreenGui.DisplayOrder
-- 	},

-- 	----- BEHAVIOUR -----
-- 	autoManageBackpack = true, -- auto-sync tools from player.Backpack
-- 	keybindsEnabled = true, -- 1-9 number keys select hotbar slots
-- })

-- toolbar:Mount()
