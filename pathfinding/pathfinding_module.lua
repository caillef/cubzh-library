local pathfinding = {}
local objectsMoving = {}
local pfMap -- defined at the end of createPathfindingMap
local f = math.floor

local _followPath = function(object, path, idx)
	if not path[idx] then
		return
	end
	local OFFSET_XZ = Number3(0.5, 0, 0.5)
	object.destination = (Number3(path[idx].x, path[idx].y, path[idx].z) + OFFSET_XZ) * Map.Scale
	object.Forward = { object.destination.X - object.Position.X, 0, object.destination.Z - object.Position.Z }
end

local _moveNoPhysics = function(object, dt)
	if not object.destination then
		-- if follow, keep objects in table
		if object.target then
			return
		end

		print("DEBUG stop a")
		object:stopMovement()
		return
	end
	local dest = Number3(object.destination.X, 0, object.destination.Z)
	local pos = Number3(object.Position.X, 0, object.Position.Z)
	local test = math.sqrt(2)
	if (dest - pos).Length < test then -- checking on a 2D plane only
		object.Position = object.destination
		object.pfStep = object.pfStep - 1
		if object.pfPath[object.pfStep] ~= nil then
			_followPath(object, object.pfPath, object.pfStep)
		else
			print("DEBUG stop b")

			object:stopMovement()
		end
	else
		_followPath(object, object.pfPath, object.pfStep)
		object.moveDir = (object.destination - object.Position):Normalize()
		object.Position = object.Position + object.moveDir * 40 * dt

		if object.onMove then
			object:onMove()
		end
	end
end

pathfinding.createPathfindingMap = function(_, config) -- Takes the map as argument
	local defaultPathfindingConfig = {
		map = Map,
		pathHeight = 3,
		pathLevel = 1,
		obstacleGroups = { 3 },
	}

	local _config = require("config"):merge(defaultPathfindingConfig, config)

	local map2d = {} --create a 2D map to store which blocks can be walked on with a height map
	local box = Box({ 0, 0, 0 }, _config.map.Scale) --create a box the size of a block
	local dist = _config.map.Scale.Y * _config.pathHeight -- check for ~3 blocks up
	local dir = Number3.Up -- checking up
	for x = 0, _config.map.Width do
		map2d[x] = {}
		for z = 0, _config.map.Depth do
			local h = _config.pathLevel -- default height is the path level
			for y = 0, _config.map.Height do
				if _config.map:GetBlock(x, y, z) then
					h = y + 1
				end -- adjust height by checking all blocks on the column to
			end
			box.Min = { x, h, z } * _config.map.Scale
			box.Max = box.Min + _config.map.Scale
			local data = h -- by default, store the height for the pathfinder
			local impact = box:Cast(dir, dist, _config.obstacleGroups) -- check object above the retained height
			if impact.Object ~= nil then
				data = impact.Object
			end -- if any, store the object for further use
			map2d[x][z] = data
		end
	end
	pfMap = map2d
	return map2d
end

local setStopMovementCallback = function(obj)
	obj.stopMovement = function(object)
		object.target = nil
		object.destination = nil
		for k, v in ipairs(objectsMoving) do
			if v == object then
				table.remove(objectsMoving, k)
			end
		end
		if object.onIdle then
			object:onIdle()
		end
	end
end

pathfinding.followObject = function(_, source, target)
	if source.stopMovement then
		print("DEBUG stop c")

		source:stopMovement()
	end

	source.target = target
	setStopMovementCallback(source)
	table.insert(objectsMoving, source)

	-- every one second compute path
	local followHandler = Timer(1, true, function()
		local origin = Map:WorldToBlock(source.Position)
		origin = Number3(f(origin.X), f(origin.Y), f(origin.Z))
		local destination = Map:WorldToBlock(target.Position)
		destination = Number3(f(destination.X), f(destination.Y), f(destination.Z))

		-- if too close, stop following
		if (destination - origin).Length < 5 then
			source.destination = nil
			return
		end

		local path = pathfinding:findPath(origin, destination)
		if path then
			source.destination = destination
			source.pfPath = path
			source.pfStep = #path - 1
		else
			source.destination = nil
		end
	end)
	return {
		Stop = function()
			followHandler:Cancel()
			print("DEBUG stop d")

			source:stopMovement()
		end,
	}
end

pathfinding.moveObjectTo = function(_, obj, origin, destination)
	if obj.stopMovement then
		print("DEBUG stop e")

		obj:stopMovement()
	end
	setStopMovementCallback(obj)

	origin = Number3(f(origin.X), f(origin.Y), f(origin.Z))
	destination = Number3(f(destination.X), f(destination.Y), f(destination.Z))

	local path = pathfinding:findPath(origin, destination, pfMap)
	if not path then
		return false
	end
	obj.destination = destination
	obj.pfPath = path
	obj.pfStep = #path - 1
	table.insert(objectsMoving, obj)
	return true
end

pathfinding.findPath = function(_, origin, destination)
	local kCount = 500
	local diagonalsAllowed = true
	local kClimb = 1

	local directNeighbors = {
		{ x = -1, z = 0 },
		{ x = 0, z = 1 },
		{ x = 1, z = 0 },
		{ x = 0, z = -1 },
	}
	local diagonalNeighbours = {
		{ x = -1, z = 0 },
		{ x = 0, z = 1 },
		{ x = 1, z = 0 },
		{ x = 0, z = -1 },
		{ x = -1, z = -1 },
		{ x = 1, z = -1 },
		{ x = 1, z = 1 },
		{ x = -1, z = 1 },
	}

	local createNode = function(x, y, z, parent)
		local node = {}
		node.x, node.y, node.z, node.parent = x, y, z, parent
		return node
	end

	local heuristic = function(x1, x2, z1, z2, y1, y2)
		local dx = x1 - x2
		local dz = z1 - z2
		local dy = y1 - y2
		local h = dx * dx + dz * dz + dy * dy
		return h
	end

	local elapsed = function(parentNode)
		return parentNode.g + 1
	end

	local calculateScores = function(node, endNode)
		node.g = node.parent and elapsed(node.parent) or 0
		node.h = heuristic(node.x, endNode.x, node.z, endNode.z, node.y, endNode.y)
		node.f = node.g + node.h
	end

	local listContains = function(list, node)
		for _, v in ipairs(list) do
			if v.x == node.x and v.y == node.y and v.z == node.z then
				return v
			end
		end
		return false
	end

	local getChildren = function(node, map)
		local children = {}
		local neighbors = diagonalsAllowed and diagonalNeighbours or directNeighbors
		local parentHeight = map[node.x][node.z]
		if parentHeight == nil or type(parentHeight) == "table" then
			print(JSON:Encode(parentHeight))
			return {}
		end

		for _, neighbor in ipairs(neighbors) do
			local x = node.x + neighbor.x
			local z = node.z + neighbor.z
			local y = map[x][z]
			if type(y) == "integer" and math.abs(y - parentHeight) <= kClimb then
				table.insert(children, { x = x, y = y, z = z })
			end
		end
		return children
	end

	-- Init lists to run the nodes & a count as protection for while
	local openList = {}
	local closedList = {}
	local count = 0
	-- Setup startNode and endNode
	local endNode = createNode(destination.X, destination.Y, destination.Z, nil)
	local startNode = createNode(origin.X, origin.Y, origin.Z, nil)
	-- Calculate starting node score
	calculateScores(startNode, endNode)
	-- Insert the startNode as first node to examine
	table.insert(openList, startNode)
	-- While there are nodes to examine and the count is under kCount (and the function did not return)
	while #openList > 0 and count < kCount do
		count = count + 1
		-- Sort openList with ascending f
		table.sort(openList, function(a, b)
			return a.f > b.f
		end)
		-- Examine the last node
		local currentNode = table.remove(openList)
		table.insert(closedList, currentNode)
		if listContains(closedList, endNode) then
			local path = {}
			local current = currentNode
			while current ~= nil do
				table.insert(path, current)
				current = current.parent
			end
			return path
		end
		-- Generate children based on map and test function
		local children = getChildren(currentNode, pfMap)
		for _, child in ipairs(children) do
			-- Create child node
			local childNode = createNode(child.x, child.y, child.z, currentNode)
			-- Check if it's already been examined
			if not listContains(closedList, childNode) then
				-- Check if it's already planned to be examined with a bigger f (meaning further away)
				if not listContains(openList, childNode) then -- or self.listContains(openList, childNode).f > childNode.f then
					calculateScores(childNode, endNode)
					table.insert(openList, childNode)
				end
			end
		end
	end
	return false
end

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	for _, obj in ipairs(objectsMoving) do
		_moveNoPhysics(obj, dt)
	end
end)

return pathfinding
