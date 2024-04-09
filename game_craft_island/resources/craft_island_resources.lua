local resources = {
	{
		id = 1,
		key = "grass",
		name = "Grass",
		type = "block",
		miningType = "shovel",
		block = { color = Color(32, 122, 41) },
	},
	{
		id = 2,
		key = "dirt",
		name = "Dirt",
		type = "block",
		miningType = "shovel",
		block = { color = Color(155, 118, 83) },
	},
	{
		id = 3,
		key = "stone",
		name = "Stone",
		type = "block",
		miningType = "pickaxe",
		block = { color = Color(153, 153, 153) },
	},
	{
		id = 256,
		key = "pickaxe",
		name = "Pickaxe",
		type = "tool",
		fullname = "caillef.pickaxe",
		icon = {
			rotation = { math.pi * 0.25, math.pi * 0.5, 0 },
			pos = { 0, -0.05 },
			scale = 2,
		},
		tool = {
			type = "pickaxe",
			hand = {
				pos = { 0, 3, -2 },
				rotation = { math.pi * -0.5, 0, 0 },
				scale = 0.8,
			},
		},
	},
	{
		id = 257,
		key = "shovel",
		name = "Shovel",
		type = "tool",
		fullname = "caillef.shovel",
		icon = {
			rotation = { math.pi * 0.25, math.pi, math.pi * 0.25 },
			pos = { 0, -0.05 },
			scale = 2,
		},
		tool = {
			type = "shovel",
			hand = {
				pos = { 0, 3.5, -2 },
				rotation = { math.pi * -0.5, 0, 0 },
				scale = 0.6,
			},
		},
	},
	{
		id = 258,
		key = "axe",
		name = "Axe",
		type = "tool",
		fullname = "littlecreator.lc_stone_axe",
		icon = {
			rotation = { math.pi * 0.25, math.pi * 0.5, 0 },
			pos = { -0.04, -0.05 },
			scale = 2,
		},
		tool = {
			type = "axe",
			hand = {
				pos = { 0, 3, 0 },
				rotation = { math.pi * -0.5, 0, 0 },
				scale = 0.6,
			},
		},
	},
	{
		id = 259,
		key = "hoe",
		name = "Hoe",
		type = "tool",
		fullname = "aduermael.hoe",
		icon = {
			rotation = { math.pi * 0.25, math.pi * 0.5, 0 },
			pos = { -0.04, -0.05 },
			scale = 2,
		},
		tool = {
			type = "hoe",
			hand = {
				pos = { 0, 3, 0 },
				rotation = { math.pi, math.pi * 0.5, math.pi * -0.5 },
				scale = 0.6,
			},
		},
		rightClick = true,
	},
	{
		id = 512,
		key = "oak_tree",
		name = "Oak Tree",
		type = "asset",
		fullname = "voxels.oak_tree",
		miningType = "axe",
		canBePlaced = false,
		asset = {
			scale = 0.43,
			hp = 20,
			drop = { i_oak_log = { 4, 6 }, i_wooden_stick = { 0, 2 } },
		},
		loot = {
			oak_log = function()
				return 3 + math.random(3)
			end,
			wooden_stick = function()
				return 1 + math.random(2)
			end,
			oak_sapling = function()
				return 1 + (math.random() > 0.9 and 1 or 0)
			end,
		},
	},
	{
		id = 513,
		key = "oak_sapling",
		name = "Oak Sapling",
		type = "asset",
		fullname = "voxels.oak_tree",
		asset = {
			physics = false,
			scale = 0.1,
			hp = 1,
		},
		icon = {
			rotation = { 0, 0, 0 },
			pos = { 0, 0 },
			scale = 2,
		},
		grow = {
			asset = "oak_tree",
			after = function()
				return math.random(60 + 60)
			end,
		},
	},
	{
		id = 514,
		key = "oak_log",
		name = "Oak Log",
		type = "item",
		fullname = "voxels.oak",
		item = {},
		canBePlaced = false,
		icon = {
			rotation = { 0, -math.pi * 0.25, math.pi * 0.05 },
			pos = { 0, 0 },
			scale = 2,
		},
	},
	{
		id = 515,
		key = "wooden_stick",
		name = "Wooden Stick",
		type = "item",
		fullname = "mutt.stick",
		item = {},
		canBePlaced = false,
		icon = {
			rotation = { 0, -math.pi * 0.25, math.pi * 0.05 },
			pos = { 0, 0 },
			scale = 2,
		},
	},
	{
		id = 516,
		key = "wheat_seed",
		name = "Wheat Seed",
		type = "asset",
		fullname = "voxels.barley_chunk",
		assetTransformer = function(asset)
			local asset = MutableShape(asset)
			local maxY = asset.Height - 4
			for y = 0, maxY do
				for z = 0, asset.Depth do
					for x = 0, asset.Width do
						local b = asset:GetBlock(x, y, z)
						if b then
							b:Remove()
						end
					end
				end
			end
			asset.Pivot.Y = maxY
			return asset
		end,
		asset = {
			scale = 0.5,
			physics = false,
			hp = 1,
			blockUnderneath = "dirt",
		},
		icon = {
			rotation = { 0, -math.pi * 0.25, math.pi * 0.05 },
			pos = { 0, 0 },
			scale = 2,
		},
		grow = {
			asset = "wheat_step_1",
			after = function()
				return 10 + math.random(5)
			end,
		},
	},
	{
		id = 517,
		key = "wheat_step_1",
		name = "Wheat Step 1",
		type = "asset",
		fullname = "voxels.barley_chunk",
		assetTransformer = function(asset)
			local asset = MutableShape(asset)
			local maxY = asset.Height - 6
			for y = 0, maxY do
				for z = 0, asset.Depth do
					for x = 0, asset.Width do
						local b = asset:GetBlock(x, y, z)
						if b then
							b:Remove()
						end
					end
				end
			end
			asset.Pivot.Y = maxY
			return asset
		end,
		canBePlaced = false,
		asset = {
			scale = 0.5,
			physics = false,
			hp = 1,
		},
		grow = {
			asset = "wheat_step_2",
			after = function()
				return 10 + math.random(5)
			end,
		},
		loot = {
			wheat_seed = 1,
		},
	},
	{
		id = 518,
		key = "wheat_step_2",
		name = "Wheat Step 2",
		type = "asset",
		fullname = "voxels.barley_chunk",
		assetTransformer = function(asset)
			local asset = MutableShape(asset)
			local maxY = asset.Height - 8
			for y = 0, maxY do
				for z = 0, asset.Depth do
					for x = 0, asset.Width do
						local b = asset:GetBlock(x, y, z)
						if b then
							b:Remove()
						end
					end
				end
			end
			asset.Pivot.Y = maxY
			return asset
		end,
		canBePlaced = false,
		asset = {
			scale = 0.5,
			physics = false,
			hp = 1,
		},
		grow = {
			asset = "wheat",
			after = function()
				return math.random(30 + math.random(60))
			end,
		},
		loot = {
			wheat_seed = 1,
		},
	},
	{
		id = 519,
		key = "wheat",
		name = "Wheat",
		type = "asset",
		fullname = "voxels.wheat_chunk",
		canBePlaced = false,
		asset = {
			physics = false,
			scale = 0.5,
			hp = 1,
		},
		loot = {
			wheat = 1,
			wheat_seed = function()
				return math.random(2)
			end,
		},
		icon = {
			rotation = { 0, -math.pi * 0.25, math.pi * 0.05 },
			pos = { 0, 0 },
			scale = 2,
		},
	},
	{
		id = 520,
		key = "portal",
		name = "Portal",
		type = "asset",
		fullname = "buche.portal",
		canBePlaced = false,
		canBeDestroyed = false,
		asset = {
			physics = true,
			scale = 1.5,
			rotation = Number3(0, math.pi * 0.5, 0),
			pivot = function(asset)
				return asset.Pivot + Number3(0, 5, 0)
			end,
			hp = 1,
		},
	},
	{
		id = 521,
		key = "oak_planks",
		name = "Oak Planks",
		type = "texturedblock",
		texture = "planks.png",
		craft = {
			inputs = {
				{ key = "oak_log", amount = 1 },
			},
			outputAmount = 4,
		},
	},
}

return resources
