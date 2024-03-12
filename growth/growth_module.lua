local growth = {}
local list = {}
local time = 0

growth.add = function(_, asset, growthAfter, onGrowth)
	asset.growthAt = time + growthAfter
	asset.onGrowth = onGrowth
	table.insert(list, asset)
end

growth.remove = function(_, asset)
	for k, v in ipairs(list) do
		if v == asset then
			table.remove(list, k)
			asset:RemoveFromParent()
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
			asset:onGrowth()
			growth:remove(asset)
		end
	end
end)

return growth
