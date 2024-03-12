local REACH_DIST = 30

local interactionModule = {}

local interactionText = nil
local interactableObject = nil

interactionModule.addInteraction = function(_, obj, text, callback)
	obj.onInteract = callback
	obj.interactText = text
end

local function getAvailableInteraction()
	local impact = Camera:CastRay(nil, Player)
	local object = impact.Object
	if object.root then -- all multishape should be spawned with a "root" value
		object = object.root
	end
	if object.onInteract and impact.Distance <= REACH_DIST then
		return object
	end
end

local function setInteractableObject(obj)
	if interactableObject then
		interactionText:remove()
	end
	interactableObject = obj

	if not obj then
		return
	end
	local ui = require("uikit")
	interactionText = ui:createFrame(Color(0, 0, 0, 0.5))
	local interactionTextStr = ui:createText("F - " .. obj.interactText, Color.White)
	interactionTextStr:setParent(interactionText)
	interactionText.parentDidResize = function()
		interactionText.Width = interactionTextStr.Width + 12
		interactionText.Height = interactionTextStr.Height + 12
		interactionText.pos = {
			Screen.Width * 0.5 - interactionText.Width * 0.5,
			Screen.Height * 0.5 - interactionText.Height * 0.5 - 50,
		}
		interactionTextStr.pos = { 6, 6 }
	end
	interactionText:parentDidResize()
end

local function handleInteractions()
	local obj = getAvailableInteraction()
	if not obj then
		setInteractableObject(nil)
		return
	end
	-- do nothing if same object
	if obj == interactableObject then
		return
	end
	setInteractableObject(obj)
end

LocalEvent:Listen(LocalEvent.Name.Tick, function()
	handleInteractions()
end)

LocalEvent:Listen(LocalEvent.Name.KeyboardInput, function(char, _, _, down)
	if char == "f" and down and interactableObject then
		interactableObject.onInteract()
	end
end)

return interactionModule
