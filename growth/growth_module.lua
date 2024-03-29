--- growth module to transform an asset into another one
--- USAGE
--- local pos = Number3(10,2,30)
--- object.Position = pos
--- growth:add(object, 5, function(obj)
---   print("removing ".. obj.. " from parent")
---   obj:RemoveFromParent()
--- end, function()
---   local newObj = Shape(...)
---   newObj:SetParent(World)
---   newObj.Position = pos
--- end)
---
--- -- if you need to remove the object because the player broke it for example
--- growth:remove(object)

local growth = {}
local list = {}
local time = 0

growth.add = function(_, asset, growthAfter, onRemove, onGrowth)
	asset.growthAt = time + growthAfter
	asset.onGrowth = onGrowth
	asset.onRemove = onRemove
	table.insert(list, asset)
end

growth.remove = function(_, asset)
	for k, v in ipairs(list) do
		if v == asset then
			table.remove(list, k)
			asset:onRemove()
		end
	end
end

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	time = time + dt
	for i = #list, 1, -1 do -- start from end to be able to remove assets
		local asset = list[i]
		if not asset then
			return
		end
		if time >= asset.growthAt then
			growth:remove(asset)
			asset:onGrowth()
		end
	end
end)

return growth
