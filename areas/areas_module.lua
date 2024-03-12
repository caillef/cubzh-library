local areas = {}

local MIN_Y_POSITION_BEFORE_TELEPORTATION = -250
local fallCallback -- function called when a player falls (set in teleportTo)

local function addArea(name, config)
	areas[name] = config
end

local function hideAllAreas()
	for _, area in pairs(areas) do
		area:hide()
	end
end

local function teleportTo(name)
	hideAllAreas()
	local area = areas[name]
	if not area then
		return
	end
	area:show()
	Player.Position = type(area.getSpawnPosition) == "function" and area:getSpawnPosition() or area.getSpawnPosition
	Player.Rotation.Y = type(area.getSpawnRotation) == "function" and area:getSpawnRotation() or area.getSpawnRotation

	local currentArea = area:getName()
	LocalEvent:Send("areas.CurrentArea", currentArea)
	fallCallback = function()
		teleportTo(name)
	end
	require("multi"):action("changeArea", { area = currentArea })
	Player.Motion = { 0, 0, 0 }

	for _, p in pairs(Players) do
		if p ~= Player then
			p.IsHidden = p.area ~= currentArea
		end
	end
end

LocalEvent:Listen("areas.TeleportTo", function(name)
	teleportTo(name)
end)

LocalEvent:Listen("areas.AddArea", function(config)
	addArea(config.name, config)
end)

LocalEvent:Listen(LocalEvent.Name.Tick, function()
	if fallCallback and Player.Position.Y < MIN_Y_POSITION_BEFORE_TELEPORTATION then
		fallCallback()
	end
end)
