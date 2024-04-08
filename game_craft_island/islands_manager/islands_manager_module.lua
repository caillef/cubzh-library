local islandsManager = {}

----- RAW IMPORT

local bitWriter = {}

bitWriter.readNumbers = function(_, data, sizes, config)
	local list = {}
	local offset = config.offset or 0
	local restBits = 8 - offset
	local byte = data:ReadUInt8()
	if offset > 0 then
		byte = byte & ((2 << (offset + 1)) - 1)
	end

	local function readValue(size, currentValue)
		currentValue = currentValue or 0

		local newRestBits = restBits - size
		-- if not enough to read, read byte and recursively call readValue
		if newRestBits < 0 then
			size = -newRestBits
			currentValue = currentValue + (byte << size)
			if data.Cursor <= data.Length then
				byte = data:ReadUInt8()
				restBits = 8
			else
				error("not enough bytes", 2)
			end
			return readValue(size, currentValue)
		end
		-- else add the value
		currentValue = currentValue + (byte >> newRestBits)
		local mask = ((1 << newRestBits) - 1)
		byte = byte & mask
		restBits = newRestBits
		if restBits == 0 then
			if data.Cursor < data.Length then
				byte = data:ReadUInt8()
				restBits = 8
			end
		end
		return currentValue
	end

	for _, value in ipairs(sizes) do
		local key = value.key
		local size = value.size
		list[key] = readValue(size)
	end
	return list
end

bitWriter.writeNumbers = function(_, data, list, config)
	local bytes = {}
	local offset = config.offset or 0
	local restBits = 8 - offset
	local uint8 = 0
	if offset > 0 then
		uint8 = data:ReadUInt8()
		data.Cursor = data.Cursor - 1
	end

	local function addBytes(value, size)
		local newRestBits = restBits - size
		-- if not enough space, write a part and recursively call addBytes
		if newRestBits < 0 then
			local toShift = size - restBits
			uint8 = uint8 + (value >> toShift)
			-- if 3 bytes (100), go to +1 (1000) and remove 1 (111)
			local mask = (1 << toShift) - 1
			value = value & mask
			size = size - restBits
			table.insert(bytes, uint8)
			uint8 = 0
			restBits = 8
			return addBytes(value, size)
		end
		-- else add the value
		uint8 = uint8 + (value << newRestBits)
		restBits = restBits - size
		if restBits == 0 then
			table.insert(bytes, uint8)
			uint8 = 0
			restBits = 8
		end
	end

	for _, v in ipairs(list) do
		local value = v.value
		local size = v.size
		assert(value < (1 << size), string.format("error: %d cannot be serialize with %d bits", value, size))
		addBytes(value, size)
	end

	-- add latest byte
	if restBits < 8 then
		table.insert(bytes, uint8)
	else
		restBits = 0
	end

	for _, v in ipairs(bytes) do
		data:WriteUInt8(v)
	end
	return restBits
end

------ END RAW IMPORT

local CANCEL_SAVE_SECONDS_INTERVAL = 3

local islandsKey = "islands"

local store = KeyValueStore(islandsKey)

local saveTimer = nil

local resourcesById
local blockIdByColors

local function colorToStr(color)
	return string.format("%d-%d-%d", color.R, color.G, color.B)
end

local serialize = function(map, assets)
	if not blockIdByColors then
		blockIdByColors = {}
		for _, v in pairs(resourcesById) do
			if v.type == "block" then
				blockIdByColors[colorToStr(v.block.color)] = v.id
			end
		end
	end

	local d = Data()
	d:WriteUInt8(1) -- version
	local nbBlocksAssetsCursor = d.Cursor
	d:WriteUInt32(0) -- nb blocks and assets
	local nbBlocksAssets = 0

	local offset = 0

	for z = map.Min.Z, map.Max.Z do
		for y = map.Min.Y, map.Max.Y do
			for x = map.Min.X, map.Max.X do
				local b = map:GetBlock(x, y, z)
				if b then
					local id = blockIdByColors[colorToStr(b.Color)]
					if not id then
						error("block not recognized")
					end

					local pos = b.Coords
					if offset > 0 then
						d.Cursor = d.Cursor - 1
					end
					local rest = bitWriter:writeNumbers(d, {
						{ value = math.floor(pos.X + 500), size = 10 }, -- x
						{ value = math.floor(pos.Y + 500), size = 10 }, -- y
						{ value = math.floor(pos.Z + 500), size = 10 }, -- z
						{ value = 0, size = 3 }, -- ry
						{ value = id, size = 11 }, -- id
						{ value = 0, size = 1 }, -- extra length
					}, { offset = offset })
					--offset = 8 - rest
					nbBlocksAssets = nbBlocksAssets + 1
				end
			end
		end
	end

	for _, v in ipairs(assets) do
		if v ~= nil and not v.skipSave then
			local pos = v.mapPos
			local id = v.info.id
			bitWriter:writeNumbers(d, {
				{ value = math.floor(pos.X + 500), size = 10 }, -- x
				{ value = math.floor(pos.Y + 500), size = 10 }, -- y
				{ value = math.floor(pos.Z + 500), size = 10 }, -- z
				{ value = 0, size = 3 }, -- ry
				{ value = id, size = 11 }, -- id
				{ value = 0, size = 1 }, -- extra length
			})
			nbBlocksAssets = nbBlocksAssets + 1
		end
	end

	d.Cursor = nbBlocksAssetsCursor
	d:WriteUInt32(nbBlocksAssets)
	d.Cursor = d.Length

	return d
end

local deserialize = function(data, callback)
	local islandInfo = {
		blocks = {},
		assets = {},
	}
	local version = data:ReadUInt8()
	if version == 1 then
		local nbBlocks = data:ReadUInt32()
		local byteOffset = 0
		local function loadNextBlocksAssets(offset, limit)
			for i = offset, offset + limit - 1 do
				if i >= nbBlocks then
					return callback(islandInfo)
				end
				if byteOffset > 0 then
					data.Cursor = data.Cursor - 1
				end
				local blockOrAsset = bitWriter:readNumbers(data, {
					{ key = "X", size = 10 }, -- x
					{ key = "Y", size = 10 }, -- y
					{ key = "Z", size = 10 }, -- z
					{ key = "ry", size = 3 }, -- ry
					{ key = "id", size = 11 }, -- id
					{ key = "extraLength", size = 1 }, -- extra length
				}, { offset = byteOffset })

				blockOrAsset.X = blockOrAsset.X - 500
				blockOrAsset.Y = blockOrAsset.Y - 500
				blockOrAsset.Z = blockOrAsset.Z - 500

				if resourcesById[blockOrAsset.id].block then
					table.insert(islandInfo.blocks, blockOrAsset)
				else
					table.insert(islandInfo.assets, blockOrAsset)
				end
			end
			Timer(0.02, function()
				loadNextBlocksAssets(offset + limit, limit)
			end)
		end
		loadNextBlocksAssets(0, 500)
	else
		error(string.format("version %d not valid", version))
	end
end

islandsManager.saveIsland = function(_, map, assets)
	if saveTimer then
		saveTimer:Cancel()
	end
	saveTimer = Timer(CANCEL_SAVE_SECONDS_INTERVAL, function()
		local data = serialize(map, assets)
		store:Set(Player.UserID, data, function(success)
			if not success then
				print("can't save your island, please come back in a few minutes")
			end
		end)
	end)
end

islandsManager.getIsland = function(_, player, callback)
	store:Get(player.UserID, function(success, results)
		if not success then
			error("Can't retrieve island")
			callback()
		end
		callback(results[player.UserID])
	end)
end

islandsManager.loadIsland = function(_, resourcesByKey, _resourcesById, callback)
	resourcesById = _resourcesById
	local playerIsland = Object()

	local map = MutableShape()
	map.Shadow = true
	map:SetParent(World)
	map.Physics = PhysicsMode.StaticPerBlock
	map.Scale = 7.5
	map.Pivot.Y = 1

	islandsManager:getIsland(Player, function(islandData)
		if not islandData then
			for z = -10, 10 do
				for y = -10, 0 do
					for x = -10, 10 do
						map:AddBlock(
							resourcesByKey[y == 0 and "grass" or (y < -3 and "stone" or "dirt")].block.color,
							x,
							y,
							z
						)
					end
				end
			end
			map:GetBlock(-5, 0, -4):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-5, 0, -5):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-5, 0, -6):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-4, 0, -4):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-4, 0, -5):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-4, 0, -6):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-3, 0, -4):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-3, 0, -5):Replace(resourcesByKey.dirt.block.color)
			map:GetBlock(-3, 0, -6):Replace(resourcesByKey.dirt.block.color)
			return callback(map, playerIsland, {
				{ id = resourcesByKey["oak_tree"].id, X = 5, Y = 1, Z = 5 },
				{ id = resourcesByKey["oak_sapling"].id, X = -5, Y = 1, Z = 5 },
				{ id = resourcesByKey["wheat_seed"].id, X = -5, Y = 1, Z = -4 },
				{ id = resourcesByKey["wheat_seed"].id, X = -5, Y = 1, Z = -5 },
				{ id = resourcesByKey["wheat_seed"].id, X = -5, Y = 1, Z = -6 },
				{ id = resourcesByKey["wheat_seed"].id, X = -4, Y = 1, Z = -4 },
				{ id = resourcesByKey["wheat_seed"].id, X = -4, Y = 1, Z = -5 },
			})
		end
		deserialize(islandData, function(islandInfo)
			for _, b in ipairs(islandInfo.blocks) do
				map:AddBlock(resourcesById[b.id].block.color, b.X, b.Y, b.Z)
			end
			callback(map, playerIsland, islandInfo.assets)
		end)
	end)
end

islandsManager.resetIsland = function()
	islandsManager:saveIsland(MutableShape(), {})
end

return islandsManager
