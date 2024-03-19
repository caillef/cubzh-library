-- Black Lines when looking at a block

local blockOutline = nil
setBlockBlackLines = function(shape, block)
	if not shape or not block or shape ~= map then
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
end

displayBlackLines = function()
	local impact = Camera:CastRay(nil, Player)
	if not impact.Object or impact.Object ~= map or impact.Distance > REACH_DIST then
		setBlockBlackLines()
		return
	end
	local impactBlock = Camera:CastRay(impact.Object)
	setBlockBlackLines(impact.Object, impactBlock.Block)
	if holdLeftClick and blockMined.Position ~= impactBlock.Block.Position then
		startMineBlockInFront()
	end
end

LocalEvent:Listen(LocalEvent.Name.Tick, function()
	displayBlackLines()
end)

return blockOutline
