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
	local dx = pos1.X - pos2.X
	local dy = pos1.Y - pos2.Y
	local dz = pos1.Z - pos2.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

_helpers.findClosestLocation = function(_, position, locationData)
	if not locationData then
		return
	end
	local closestLocation = nil
	local smallestDistance = math.huge -- Large initial value

	for _, location in pairs(locationData) do
		local distance = _helpers:calculateDistance(
			position,
			Map:WorldToBlock(Number3(location.position.x, location.position.y, location.position.z))
		)
		if distance < smallestDistance then
			smallestDistance = distance
			closestLocation = location
		end
	end
	-- Closest location found, now send its ID to update the character's location
	return closestLocation
end

if IsServer then
	-- SERVER
	local simulations = {}

	local function registerMainCharacter(simulation, locationId, done)
		-- Example character data, replace with actual data as needed
		local newCharacterData = {
			name = simulation.player.Username,
			physical_description = "A human playing the game",
			current_location_id = locationId,
			position = { x = 0, y = 0, z = 0 },
		}

		-- Serialize the character data to JSON
		local jsonData = JSON:Encode(newCharacterData)

		local apiUrl = API_URL .. "/api/character/company/main?engine_id=" .. simulation.engineId

		-- Make the HTTP POST request
		HTTP:Post(apiUrl, headers, jsonData, function(response)
			if response.StatusCode ~= 200 then
				print("Error creating or fetching main character: " .. response.StatusCode)
			end
			simulation.character = JSON:Decode(response.Body)
			done()
		end)
	end

	local function registerEngine(player, simulationName, config)
		local apiUrl = API_URL .. "/api/engine/company/"

		local simulation = {
			engineId = nil,
			character = nil,
			locations = {},
			NPCs = {},
			config = config,
			player = player,
		}
		simulation.player.simulationName = simulationName
		simulations[simulationName] = simulation

		-- Prepare the data structure expected by the backend
		local engineData = {
			name = simulationName, -- using Player.UserID to keep simulation name unique
			NPCs = {},
			locations = {}, -- Populate if you have dynamic location data similar to NPCs
			radius,
		}

		-- remove functions in skill
		local cleanSkills = JSON:Decode(JSON:Encode(config.skills))
		for _, elem in ipairs(cleanSkills) do
			elem.callback = nil
			elem.onEndCallback = nil
		end

		for _, npc in pairs(config.NPCs) do
			simulation.NPCs[npc.name] = {
				name = npc.name,
				physical_description = npc.physicalDescription,
				psychological_profile = npc.psychologicalProfile,
				current_location_name = npc.currentLocationName,
				skills = cleanSkills,
			}
			table.insert(engineData.NPCs, simulation.NPCs[npc.name])
		end

		for _, loc in ipairs(config.locations) do
			simulation.locations[loc.name] = {
				name = loc.name,
				position = { x = loc.position.X, y = loc.position.Y, z = loc.position.Z },
				description = loc.description,
			}
			table.insert(engineData.locations, simulation.locations[loc.name])
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
			simulation.engineId = responseData.engine.id

			-- Saving all the _ids inside locationData table:
			for _, loc in ipairs(responseData.locations) do
				simulation.locations[loc.name]._id = loc._id
			end

			-- same for characters:
			for _, npc in pairs(responseData.NPCs) do
				simulation.NPCs[npc.name]._id = npc._id
				simulation.NPCs[npc.name].position = Number3(npc.position.x, npc.position.y, npc.position.z)

				-- TODO: check hwy we need this
				simulation.NPCs[npc.name].skills = nil
			end

			registerMainCharacter(simulation, simulation.locations["Medieval Inn"]._id, function()
				local e = Event()
				e.action = "linkEngine"
				e.simulation = {
					NPCs = simulation.NPCs,
					locations = simulation.locations,
					engineId = simulation.engineId,
					character = simulation.character,
				}
				e:SendTo(simulation.player)
			end)
		end)
	end

	local function stepMainCharacter(simulation, actionType, content)
		if not simulation then
			return
		end
		local character = simulation.character
		-- Now, step the character
		local stepUrl = API_URL .. "/api/character/" .. character._id .. "/step-no-ws?engine_id=" .. simulation.engineId
		local stepActionData = {
			character_id = character._id, -- Use the character ID from the creation/fetch response
			action_type = actionType,
			target_name = "aduermael",
			target = simulation.NPCs["aduermael"]._id,
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
		local simulation = simulations[e.Sender.simulationName]
		if not simulation then
			print("no simulation available for ", e.Sender.Username, e.Sender.simulationName)
			return
		end
		if e.action == "stepMainCharacter" then
			stepMainCharacter(simulation, e.actionType, e.content)
		else
			print("Unknown Gigax message received from server.")
		end
	end

	local config
	gigax.setConfig = function(_, _config)
		config = _config
	end

	LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(player)
		if not config then
			print("Error: Call gigax:setConfig(config) in Server.OnStart")
			return
		end
		player.simulationName = player.UserID .. "_" .. config.simulationName
		registerEngine(player, player.simulationName, config)
	end)

	LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
		serverDidReceiveEvent(e)
	end)
else
	-- CLIENT
	local npcDataClient = {} -- map <name,table>
	local npcDataClientById = {}

	local simulation = nil

	local waitingLinkNPCs = {}

	local actionCallbacks = {}
	local onEndCallbacks = {}

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

	local skillOnAction = function(actionType, callback, onEndCallback)
		actionCallbacks[actionType] = callback
		onEndCallbacks[actionType] = onEndCallback
	end

	gigax.updateCharacterPosition = function(_, simulation, characterId, position)
		if not simulation then
			return
		end
		local closest = _helpers:findClosestLocation(position, simulation.locations)
		if not closest then
			print("can't update character position: no closest location found, id:", characterId, position)
			return
		end
		local location_id = closest._id

		local updateData = {
			current_location_id = location_id,
			position = { x = position.X, y = position.Y, z = position.Z },
		}

		local jsonData = JSON:Encode(updateData)
		local apiUrl = API_URL .. "/api/character/" .. characterId .. "?engine_id=" .. simulation.engineId

		HTTP:Post(apiUrl, headers, jsonData, function(response)
			if response.StatusCode ~= 200 then
				print("Error updating character location: " .. response.StatusCode)
				return
			end
		end)
	end

	local onEndData
	local prevAction
	local function clientDidReceiveEvent(e)
		if e.action == "linkEngine" then
			simulation = e.simulation
			for name, npc in pairs(waitingLinkNPCs) do
				if simulation.NPCs[name] then
					npc._id = simulation.NPCs[name]._id

					npcDataClient[name] = npc
					npcDataClientById[npc._id] = npc
					npcDataClient[name]._id = npc._id
					npcDataClient[name].object.Position = simulation.NPCs[name].position
				else
					print("Can't link NPC", name)
				end
			end
			engineId = simulation.engineId

			updateLocationTimer = Timer(1, true, function()
				local position = Map:WorldToBlock(Player.Position)
				gigax:updateCharacterPosition(simulation, simulation.character._id, position)
			end)
		elseif e.action == "NPCActionResponse" then
			local currentAction = string.lower(e.actionType)
			if onEndData and onEndCallbacks[prevAction] then
				onEndCallbacks[prevAction](gigax, onEndData, currentAction)
			end
			local callback = actionCallbacks[currentAction]
			prevAction = string.lower(e.actionType)
			if not callback then
				print("action not handled")
				return
			end
			onEndData = callback(gigax, e.actionData, config)
		end
	end

	local function createNPC(name, currentPosition)
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

		NPC.avatar = require("avatar"):get(name)
		NPC.avatar:SetParent(NPC.object.avatarContainer)
		NPC.avatar.Rotation.Y = math.pi * 2

		NPC.name = name
		npcDataClient[name] = {
			name = name,
			avatar = NPC.avatar,
			object = NPC.object,
		}

		NPC.object.onIdle = function()
			local animations = NPC.avatar.Animations
			NPC.object.avatarContainer.LocalRotation = { 0, 0, 0 }
			if not animations or animations.Idle.IsPlaying then
				return
			end
			if animations.Walk.IsPlaying then
				animations.Walk:Stop()
			end
			animations.Idle:Play()
		end

		NPC.object.onMove = function()
			local animations = NPC.avatar.Animations
			NPC.object.avatarContainer.LocalRotation = { 0, 0, 0 }
			if not animations or animations.Walk.IsPlaying then
				return
			end
			if animations.Idle.IsPlaying then
				animations.Idle:Stop()
			end
			animations.Walk:Play()
		end

		waitingLinkNPCs[name] = NPC

		-- review this to update location and position
		Timer(1, true, function()
			if not simulation then
				return
			end
			local position = Map:WorldToBlock(NPC.object.Position)
			gigax:updateCharacterPosition(simulation, NPC._id, position)
		end)
		return NPC
	end

	gigax.setConfig = function(_, _config)
		config = _config

		for _, elem in ipairs(config.skills) do
			skillOnAction(string.lower(elem.name), elem.callback, elem.onEndCallback)
		end
		for _, elem in ipairs(config.NPCs) do
			createNPC(elem.name, elem.position)
		end
	end

	LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(event)
		clientDidReceiveEvent(event)
	end)
end

return gigax
