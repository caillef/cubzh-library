local gigax = {}

local CUBZH_API_TOKEN =
	"H4gjL-e9kvLF??2pz6oh=kJL497cBnsyCrQFdVkFadUkLnIaEamroYHb91GywMXrbGeDdmTiHxi8EqmJduCKPrDnfqWsjGuF0JJCUTrasGcBfGx=tlJCjq5q8jhVHWL?krIE74GT9AJ7qqX8nZQgsDa!Unk8GWaqWcVYT-19C!tCo11DcLvrnJPEOPlSbH7dDcXmAMfMEf1ZwZ1v1C9?2/BjPDeiAVTRlLFilwRFmKz7k4H-kCQnDH-RrBk!ZHl7"
local API_URL = "https://gig.ax"

local TRIGGER_AREA_SIZE = Number3(60, 30, 60)

local headers = {
	["Content-Type"] = "application/json",
	["Authorization"] = CUBZH_API_TOKEN,
}

-- HELPERS
local _helpers = {}

_helpers.lookAt = function(obj, target)
	if not target then
		require("ease"):linear(obj, 0.1).Forward = obj.initialForward
		obj.Tick = nil
		return
	end
	obj.Tick = function(self, _)
		_helpers.lookAtHorizontal(self, target)
	end
end

_helpers.lookAtHorizontal = function(o1, o2)
	local n3_1 = Number3.Zero
	local n3_2 = Number3.Zero
	n3_1:Set(o1.Position.X, 0, o1.Position.Z)
	n3_2:Set(o2.Position.X, 0, o2.Position.Z)
	require("ease"):linear(o1, 0.1).Forward = n3_2 - n3_1
end

-- Function to calculate distance between two positions
_helpers.calculateDistance = function(_, pos1, pos2)
	local dx = pos1.X - pos2.x
	local dy = pos1.Y - pos2.y
	local dz = pos1.Z - pos2.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

_helpers.findClosestLocation = function(_, playerPosition, locationData)
	if not locationData then
		return
	end
	-- Assume `playerPosition` holds the current position of the player
	local closestLocation = nil
	local smallestDistance = math.huge -- Large initial value

	for _, location in pairs(locationData) do
		local distance = _helpers:calculateDistance(playerPosition, location.position)
		if distance < smallestDistance then
			smallestDistance = distance
			closestLocation = location
		end
	end
	-- Closest location found, now send its ID to update the character's location
	return closestLocation
end

local engineId
gigax.updateCharacterLocation = function(_, characterId, locationId, position)
	local updateData = {
		current_location_id = locationId,
		position = { x = position.X, y = position.Y, z = position.Z },
	}

	if not characterId then
		return
	end

	local jsonData = JSON:Encode(updateData)
	-- Assuming `characterId` and `engineId` are available globally or passed appropriately
	local apiUrl = API_URL .. "/api/character/" .. characterId .. "?engine_id=" .. engineId

	HTTP:Post(apiUrl, headers, jsonData, function(response)
		if response.StatusCode ~= 200 then
			print("Error updating character location: " .. response.StatusCode)
			return
		end
	end)
end

gigax.updateCharacterPosition = function(_, characterId, position)
	local updateData = {
		position = { x = position.X, y = position.Y, z = position.Z },
	}

	if not characterId then
		return
	end

	local jsonData = JSON:Encode(updateData)
	-- Assuming `characterId` and `engineId` are available globally or passed appropriately
	local apiUrl = API_URL .. "/api/character/" .. characterId .. "?engine_id=" .. engineId

	HTTP:Post(apiUrl, headers, jsonData, function(response)
		if response.StatusCode ~= 200 then
			print("Error updating character location: " .. response.StatusCode)
			return
		end
	end)
end

Timer(5, function()
	print("is server", IsServer)
end)

if IsServer then
	local character
	local npcData = {}
	local locationData = {}

	-- Function to create and register an NPC
	local function registerNPC(avatarId, physicalDescription, psychologicalProfile, currentLocationName, skills)
		-- Add NPC to npcData table
		npcData[avatarId] = {
			name = avatarId,
			physical_description = physicalDescription,
			psychological_profile = psychologicalProfile,
			current_location_name = currentLocationName,
			skills = skills,
		}
	end

	-- Function to register a location
	local function registerLocation(name, position, description)
		locationData[name] = {
			position = { x = position._x, y = position._y, z = position._z },
			name = name,
			description = description,
		}
	end

	local function registerEngine(sender, simulationName)
		local apiUrl = API_URL .. "/api/engine/company/"

		-- Prepare the data structure expected by the backend
		local engineData = {
			name = simulationName, -- using Player.UserID to keep simulation name unique
			NPCs = {},
			locations = {}, -- Populate if you have dynamic location data similar to NPCs
		}
		for _, npc in pairs(npcData) do
			table.insert(engineData.NPCs, npc)
		end
		for _, loc in pairs(locationData) do
			table.insert(engineData.locations, loc)
		end

		local body = JSON:Encode(engineData)

		HTTP:Post(apiUrl, headers, body, function(res)
			if res.StatusCode ~= 201 then
				print("Error updating engine: " .. res.StatusCode)
				return
			end
			-- Decode the response body to extract engine and location IDs
			local responseData = JSON:Decode(res.Body)

			-- Save the engine_id for future use
			engineId = responseData.engine.id

			-- Saving all the _ids inside locationData table:
			for _, loc in ipairs(responseData.locations) do
				locationData[loc.name]._id = loc._id
			end

			-- same for characters:
			for _, npc in pairs(responseData.NPCs) do
				npcData[npc.name]._id = npc._id
				local e = Event()
				e.action = "NPCRegistered"
				e.npcName = npc.name
				e.npcPosition = Number3(npc.position.x, npc.position.y, npc.position.z)
				e.npcId = npc._id
				e["gigax.engineId"] = engineId
				e:SendTo(sender)
			end

			registerMainCharacter(locationData["Medieval Inn"]._id, sender)
		end)
	end

	local function registerMainCharacter(locationId, sender)
		-- Example character data, replace with actual data as needed
		local newCharacterData = {
			name = "oncheman",
			physical_description = "A human playing the game",
			current_location_id = locationId,
			position = { x = 0, y = 0, z = 0 },
		}

		-- Serialize the character data to JSON
		local jsonData = JSON:Encode(newCharacterData)

		local apiUrl = API_URL .. "/api/character/company/main?engine_id=" .. engineId

		-- Make the HTTP POST request
		HTTP:Post(apiUrl, headers, jsonData, function(response)
			if response.StatusCode ~= 200 then
				print("Error creating or fetching main character: " .. response.StatusCode)
			end
			character = JSON:Decode(response.Body)
			local e = Event()
			e.action = "mainCharacterCreated"
			e["character"] = character
			e:SendTo(sender)
		end)
	end

	local function stepMainCharacter(character, actionType, targetId, targetName, content)
		if not engineId then
			return
		end
		-- Now, step the character
		local stepUrl = API_URL .. "/api/character/" .. character._id .. "/step-no-ws?engine_id=" .. engineId
		local stepActionData = {
			character_id = character._id, -- Use the character ID from the creation/fetch response
			action_type = actionType,
			target = targetId,
			target_name = targetName,
			content = content,
		}
		local stepJsonData = JSON:Encode(stepActionData)

		HTTP:Post(stepUrl, headers, stepJsonData, function(stepResponse)
			if stepResponse.StatusCode ~= 200 then
				print("Error stepping character: " .. stepResponse.StatusCode)
				return
			end

			local actions = JSON:Decode(stepResponse.Body)
			-- Find the target character by id using the "target" field in the response:
			for _, action in ipairs(actions) do
				local e = Event()
				e.action = "NPCActionResponse"
				e.actionData = action
				e.actionType = action.action_type
				e:SendTo(Players)
			end
		end)
	end

	local function serverDidReceiveEvent(e)
		if e.action == "registerNPC" then
			registerNPC(e.avatarId, e.physicalDescription, e.psychologicalProfile, e.currentLocationName, e.skills)
		elseif e.action == "registerLocation" then
			registerLocation(e.name, e.position, e.description)
		elseif e.action == "registerEngine" then
			registerEngine(e.Sender, e.Sender.UserID .. "_" .. e.simulationName)
		elseif e.action == "stepMainCharacter" then
			stepMainCharacter(character, e.actionType, npcData["aduermael"]._id, npcData["aduermael"].name, e.content)
		elseif e.action == "updateCharacterLocation" then
			if character == nil then
				print("Character not created yet; cannot update location.")
				return
			end
			local closest = _helpers:findClosestLocation(e.position, locationData)
			-- if closest._id is different from the current location, update the character's location
			if closest._id ~= character.current_location._id and closest._id ~= nil then
				updateCharacterLocation(e.characterId, closest._id, e.position)
				character.current_location._id = closest._id
			end
		else
			print("Unknown Gigax message received from server.")
		end
	end

	LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
		print("server received event")

		serverDidReceiveEvent(e)
	end)

	gigax.serverDidReceiveEvent = serverDidReceiveEvent
else
	-- client

	gigax = {}

	local npcDataClient = {} -- map <name,table>
	local npcDataClientById = {}

	local actionCallbacks = {}
	local config = {}

	gigax.action = function(self, actionType, data)
		local e = Event()
		e.action = "stepMainCharacter"
		e.actionType = actionType
		if data then
			for k, v in pairs(data) do
				e[k] = v
			end
		end
		e:SendTo(Server)
	end

	gigax.getNpc = function(self, id)
		return npcDataClientById[id]
	end

	local skillOnAction = function(actionType, callback)
		actionCallbacks[actionType] = callback
	end

	local function clientDidReceiveEvent(e)
		if e.action == "NPCActionResponse" then
			local callback = actionCallbacks[string.lower(e.actionType)]
			if not callback then
				print("action not handled")
				return
			end
			callback(gigax, e.actionData, config)
		elseif e.action == "mainCharacterCreated" then
			-- Setup a new timer to delay the next update call
			characterId = e.character._id
			updateLocationTimer = Timer(0.5, true, function()
				local e = Event()
				e.action = "updateCharacterLocation"
				e.position = Player.Position
				e.characterId = characterId
				e:SendTo(Server)
			end)
		-- print("Character ID: " .. character._id)
		elseif e.action == "NPCRegistered" then
			-- Update NPC in the client side table to add the _id
			local npc = npcDataClient[e.npcName]
			npc._id = e.npcId
			npc.object.Position = e.npcPosition
			npcDataClientById[npc._id] = npc
			engineId = e["gigax.engineId"]
		end
	end

	local function createNPC(
		avatarId,
		physicalDescription,
		psychologicalProfile,
		currentLocationName,
		currentPosition,
		skills
	)
		-- Create the NPC's Object and Avatar
		local NPC = {}
		NPC.object = Object()
		World:AddChild(NPC.object)
		NPC.object.Position = currentPosition or Number3(0, 0, 0)
		NPC.object.Scale = 0.5
		NPC.object.Physics = PhysicsMode.Trigger
		NPC.object.CollisionBox = Box({
			-TRIGGER_AREA_SIZE.Width * 0.5,
			math.min(-TRIGGER_AREA_SIZE.Height, NPC.object.CollisionBox.Min.Y),
			-TRIGGER_AREA_SIZE.Depth * 0.5,
		}, {
			TRIGGER_AREA_SIZE.Width * 0.5,
			math.max(TRIGGER_AREA_SIZE.Height, NPC.object.CollisionBox.Max.Y),
			TRIGGER_AREA_SIZE.Depth * 0.5,
		})
		NPC.object.OnCollisionBegin = function(self, other)
			if other ~= Player then
				return
			end
			_helpers.lookAt(self.avatarContainer, other)
		end
		NPC.object.OnCollisionEnd = function(self, other)
			if other ~= Player then
				return
			end
			_helpers.lookAt(self.avatarContainer, nil)
		end

		local container = Object()
		container.Rotation = NPC.object.Rotation
		container.initialRotation = NPC.object.Rotation:Copy()
		container.initialForward = NPC.object.Forward:Copy()
		container:SetParent(NPC.object)
		container.Physics = PhysicsMode.Trigger
		NPC.object.avatarContainer = container

		NPC.avatar = require("avatar"):get(avatarId)
		NPC.avatar:SetParent(NPC.object.avatarContainer)
		NPC.avatar.Rotation.Y = math.pi * 2

		npcDataClient[avatarId] = {
			name = avatarId,
			avatar = NPC.avatar,
			object = NPC.object,
		}

		NPC.object.onIdle = function(obj)
			local animations = NPC.avatar.Animations
			if not animations or animations.Idle.IsPlaying then
				return
			end
			if animations.Walk.IsPlaying then
				animations.Walk:Stop()
			end
			animations.Idle:Play()
		end

		NPC.object.onMove = function(obj)
			local animations = NPC.avatar.Animations
			if not animations or animations.Walk.IsPlaying then
				return
			end
			if animations.Idle.IsPlaying then
				animations.Idle:Stop()
			end
			animations.Walk:Play()
		end

		NPC.current_location = { _id = 0 }
		Timer(1, function()
			local position = Map:WorldToBlock(NPC.avatar.Position)
			local closest = _helpers:findClosestLocation(position, locationData)
			if closest._id ~= NPC.current_location._id and closest._id ~= nil then
				updateCharacterLocation(NPC._id, closest._id, position)
				NPC.current_location._id = closest._id
			end
		end)

		local e = Event()
		e.action = "registerNPC"
		e.avatarId = avatarId
		e.physicalDescription = physicalDescription
		e.psychologicalProfile = psychologicalProfile
		e.currentLocationName = currentLocationName
		e.skills = skills
		e:SendTo(Server)
		return NPC
	end

	local function createLocation(name, position, description)
		local e = Event()
		e.action = "registerLocation"
		e.name = name
		e.position = position
		e.description = description
		e:SendTo(Server)
	end

	gigax.setConfig = function(_, _config)
		config = _config

		for _, elem in ipairs(config.skills) do
			skillOnAction(string.lower(elem.name), elem.callback)
		end
		for _, elem in ipairs(config.locations) do
			createLocation(elem.name, elem.pos, elem.description)
		end
		local cleanSkills = JSON:Decode(JSON:Encode(config.skills))
		for _, elem in ipairs(cleanSkills) do
			elem.callback = nil
		end
		for _, elem in ipairs(config.npcs) do
			createNPC(elem.name, elem.description, elem.mood, elem.location, elem.pos, cleanSkills)
		end

		Timer(2, function()
			-- Adding a timer here, otherwise engine is not ready yet
			local e = Event()
			e.action = "registerEngine"
			e.simulationName = config.simulationName
			e:SendTo(Server)
			print("send register Engine")
		end)
	end

	LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(event)
		clientDidReceiveEvent(event)
	end)
end

local character
local npcData = {}
local locationData = {}

-- Function to create and register an NPC
local function registerNPC(avatarId, physicalDescription, psychologicalProfile, currentLocationName, skills)
	-- Add NPC to npcData table
	npcData[avatarId] = {
		name = avatarId,
		physical_description = physicalDescription,
		psychological_profile = psychologicalProfile,
		current_location_name = currentLocationName,
		skills = skills,
	}
end

-- Function to register a location
local function registerLocation(name, position, description)
	locationData[name] = {
		position = { x = position._x, y = position._y, z = position._z },
		name = name,
		description = description,
	}
end

local function registerEngine(sender, simulationName)
	local apiUrl = API_URL .. "/api/engine/company/"

	-- Prepare the data structure expected by the backend
	local engineData = {
		name = simulationName, -- using Player.UserID to keep simulation name unique
		NPCs = {},
		locations = {}, -- Populate if you have dynamic location data similar to NPCs
	}
	for _, npc in pairs(npcData) do
		table.insert(engineData.NPCs, npc)
	end
	for _, loc in pairs(locationData) do
		table.insert(engineData.locations, loc)
	end

	local body = JSON:Encode(engineData)

	HTTP:Post(apiUrl, headers, body, function(res)
		if res.StatusCode ~= 201 then
			print("Error updating engine: " .. res.StatusCode)
			return
		end
		-- Decode the response body to extract engine and location IDs
		local responseData = JSON:Decode(res.Body)

		-- Save the engine_id for future use
		engineId = responseData.engine.id

		-- Saving all the _ids inside locationData table:
		for _, loc in ipairs(responseData.locations) do
			locationData[loc.name]._id = loc._id
		end

		-- same for characters:
		for _, npc in pairs(responseData.NPCs) do
			npcData[npc.name]._id = npc._id
			local e = Event()
			e.action = "NPCRegistered"
			e.npcName = npc.name
			e.npcPosition = Number3(npc.position.x, npc.position.y, npc.position.z)
			e.npcId = npc._id
			e["gigax.engineId"] = engineId
			e:SendTo(sender)
		end

		registerMainCharacter(locationData["Medieval Inn"]._id, sender)
	end)
end

local function registerMainCharacter(locationId, sender)
	-- Example character data, replace with actual data as needed
	local newCharacterData = {
		name = "oncheman",
		physical_description = "A human playing the game",
		current_location_id = locationId,
		position = { x = 0, y = 0, z = 0 },
	}

	-- Serialize the character data to JSON
	local jsonData = JSON:Encode(newCharacterData)

	local apiUrl = API_URL .. "/api/character/company/main?engine_id=" .. engineId

	-- Make the HTTP POST request
	HTTP:Post(apiUrl, headers, jsonData, function(response)
		if response.StatusCode ~= 200 then
			print("Error creating or fetching main character: " .. response.StatusCode)
		end
		character = JSON:Decode(response.Body)
		local e = Event()
		e.action = "mainCharacterCreated"
		e["character"] = character
		e:SendTo(sender)
	end)
end

local function stepMainCharacter(character, actionType, targetId, targetName, content)
	if not engineId then
		return
	end
	-- Now, step the character
	local stepUrl = API_URL .. "/api/character/" .. character._id .. "/step-no-ws?engine_id=" .. engineId
	local stepActionData = {
		character_id = character._id, -- Use the character ID from the creation/fetch response
		action_type = actionType,
		target = targetId,
		target_name = targetName,
		content = content,
	}
	local stepJsonData = JSON:Encode(stepActionData)

	HTTP:Post(stepUrl, headers, stepJsonData, function(stepResponse)
		if stepResponse.StatusCode ~= 200 then
			print("Error stepping character: " .. stepResponse.StatusCode)
			return
		end

		local actions = JSON:Decode(stepResponse.Body)
		-- Find the target character by id using the "target" field in the response:
		for _, action in ipairs(actions) do
			local e = Event()
			e.action = "NPCActionResponse"
			e.actionData = action
			e.actionType = action.action_type
			e:SendTo(Players)
		end
	end)
end

local function serverDidReceiveEvent(e)
	if e.action == "registerNPC" then
		registerNPC(e.avatarId, e.physicalDescription, e.psychologicalProfile, e.currentLocationName, e.skills)
	elseif e.action == "registerLocation" then
		registerLocation(e.name, e.position, e.description)
	elseif e.action == "registerEngine" then
		registerEngine(e.Sender, e.Sender.UserID .. "_" .. e.simulationName)
	elseif e.action == "stepMainCharacter" then
		stepMainCharacter(character, e.actionType, npcData["aduermael"]._id, npcData["aduermael"].name, e.content)
	elseif e.action == "updateCharacterLocation" then
		if character == nil then
			print("Character not created yet; cannot update location.")
			return
		end
		local closest = _helpers:findClosestLocation(e.position, locationData)
		-- if closest._id is different from the current location, update the character's location
		if closest._id ~= character.current_location._id and closest._id ~= nil then
			updateCharacterLocation(e.characterId, closest._id, e.position)
			character.current_location._id = closest._id
		end
	else
		print("Unknown Gigax message received from server.")
	end
end

LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
	print("server received event")

	serverDidReceiveEvent(e)
end)

gigax.serverDidReceiveEvent = serverDidReceiveEvent

return gigax
