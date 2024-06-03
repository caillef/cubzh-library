-- Module to create floating island

--[[
USAGE
Modules = {
    floating_island_generator = "github.com/caillef/cubzh-library/floating_island_generator:82d22a5"
}

Client.OnStart = function()
    floating_island_generator:generateIslands({
		nbIslands = 20, -- number of islands
		minSize = 4, -- min size of island
		maxSize = 7, -- max size of island
		safearea = 200, -- min dist of islands from 0,0,0
		dist = 750, -- max dist of islands
	})
end
--]]

local floating_island_generator = {}

local cachedTree

local COLORS = {
	GRASS = Color(19, 133, 16),
	DIRT = Color(107, 84, 40),
	STONE = Color.Grey,
}

local function islandHeight(x, z, radius)
	local distance = math.sqrt(x * x + z * z)
	local normalizedDistance = distance / radius
	local maxy = -((1 + radius) * 2 - (normalizedDistance ^ 4) * distance)
	return maxy
end

local function onReady(callback)
	Object:Load("knosvoxel.oak_tree", function(obj)
		cachedTree = obj
		callback()
	end)
end

local function create(radius)
	local shape = MutableShape()
	shape.Pivot = { 0.5, 0.5, 0.5 }
	for z = -radius, radius do
		for x = -radius, radius do
			local maxy = islandHeight(x, z, radius)
			shape:AddBlock(COLORS.DIRT, x, -2, z)
			shape:AddBlock(COLORS.GRASS, x, -1, z)
			shape:AddBlock(COLORS.GRASS, x, 0, z)
			if maxy <= -3 then
				shape:AddBlock(COLORS.DIRT, x, -3, z)
			end
			for y = maxy, -3 do
				shape:AddBlock(COLORS.STONE, x, y, z)
			end
		end
	end

	local xShift = math.random(-radius, radius)
	local zShift = math.random(-radius, radius)
	for z = -radius, radius do
		for x = -radius, radius do
			local maxy = islandHeight(x, z, radius) - 2
			shape:AddBlock(COLORS.DIRT, x + xShift, -2 + 2, z + zShift)
			shape:AddBlock(COLORS.GRASS, x + xShift, -1 + 2, z + zShift)
			shape:AddBlock(COLORS.GRASS, x + xShift, 0 + 2, z + zShift)
			if maxy <= -3 + 2 then
				shape:AddBlock(COLORS.DIRT, x + xShift, -3 + 2, z + zShift)
			end
			for y = maxy, -3 + 2 do
				shape:AddBlock(COLORS.STONE, x + xShift, y, z + zShift)
			end
		end
	end

	for _ = 1, math.random(1, 2) do
		local obj = Shape(cachedTree, { includeChildren = true })
		obj.Position = { 0, 0, 0 }
		local box = Box()
		box:Fit(obj, true)
		obj.Pivot = Number3(obj.Width / 2, box.Min.Y + obj.Pivot.Y + 4, obj.Depth / 2)
		obj:SetParent(shape)
		require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Physics = PhysicsMode.Disabled
		end)
		local coords = Number3(math.random(-radius + 1, radius - 1), 0, math.random(-radius + 1, radius - 1))
		while shape:GetBlock(coords) do
			coords.Y = coords.Y + 1
		end
		obj.Scale = math.random(70, 150) / 1000
		obj.Rotation.Y = math.random(1, 4) * math.pi * 0.25
		obj.LocalPosition = coords
	end

	return shape
end

floating_island_generator.generateIslands = function(_, config)
	config = config or {}
	local nbIslands = config.nbIslands or 20
	local minSize = config.minSize or 4
	local maxSize = config.maxSize or 7
	local dist = config.dist or 750
	local safearea = config.safearea or 200
	onReady(function()
		for i = 1, nbIslands do
			local island = create(math.random(minSize, maxSize))
			island:SetParent(World)
			island.Scale = Map.Scale
			island.Physics = PhysicsMode.Disabled
			local x = math.random(-dist, dist)
			local z = math.random(-dist, dist)
			while (x >= -safearea and x <= safearea) and (z >= -safearea and z <= safearea) do
				x = math.random(-dist, dist)
				z = math.random(-dist, dist)
			end
			island.Position = {
				x + (Map.Width * 0.5) * Map.Scale.X,
				math.random(300) - 150,
				z + (Map.Depth * 0.5) * Map.Scale.Z,
			}
			local t = x + z
			LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
				t = t + dt
				island.Position.Y = island.Position.Y + math.sin(t) * 0.02
			end)
		end
	end)
end

return floating_island_generator
