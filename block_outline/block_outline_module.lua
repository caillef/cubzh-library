-- Black Lines when looking at a block

local blockOutlineModule = {}

local max_reach_dist = -1
local shapeTarget
local blockOutline

local function setBlockBlackLines(shape, block)
	if not shape or not block or shape ~= shapeTarget then
		if blockOutline then
			blockOutline:SetParent(nil)
		end
		return
	end
	if not blockOutline then
		blockOutline = MutableShape()
		blockOutline:AddBlock(Color(0, 0, 0, 0), 0, 0, 0)
		blockOutline.PrivateDrawMode = 8
		blockOutline.Pivot = { 0.5, 0.5, 0.5 }
		blockOutline.Scale = shape.Scale + 0.01
		blockOutline.Physics = PhysicsMode.Disabled
	end
	blockOutline:SetParent(World)
	blockOutline.Position = shape:BlockToWorld(block) + shape.Scale * 0.5

	LocalEvent:Send("block_outline.update", {
		block = block,
	})
end

local function displayBlackLines()
	local impact = Camera:CastRay(nil, Player)
	if not impact.Object or impact.Object ~= shapeTarget or impact.Distance > max_reach_dist then
		setBlockBlackLines()
		return
	end
	local impactBlock = Camera:CastRay(impact.Object)
	setBlockBlackLines(impact.Object, impactBlock.Block)
end

blockOutlineModule.setShape = function(_, shape)
	shapeTarget = shape
end

LocalEvent:Listen(LocalEvent.Name.Tick, function()
	if not shapeTarget then
		return
	end
	displayBlackLines()
end)

return blockOutlineModule
