local easy_onboarding = {}

local currentStep = 0
local steps = {}
local stopCallbackData

easy_onboarding.startOnboarding = function(self, config)
	currentStep = 1
	steps = config.steps
	stopCallbackData = steps[1].start(self, currentStep)
end

easy_onboarding.createTextStep = function(_, str)
	local ui = require("uikit")
	local node = ui:createFrame(Color(0, 0, 0, 0.5))
	local text = ui:createText(str, Color.White)
	text:setParent(node)
	node.parentDidResize = function()
		node.Width = text.Width + text.Height
		node.Height = text.Height * 2
		text.pos = { node.Width * 0.5 - text.Width * 0.5, node.Height * 0.5 - text.Height * 0.5 }
		node.pos = { Screen.Width * 0.5 - node.Width * 0.5, Screen.Height * 0.2 - node.Height * 0.5 }
	end
	node:parentDidResize()
	return node
end

easy_onboarding.next = function(self)
	if not steps[currentStep] then
		return
	end
	steps[currentStep].stop(self, stopCallbackData)
	currentStep = currentStep + 1
	if not steps[currentStep] then
		return
	end
	stopCallbackData = steps[currentStep].start(self, currentStep)
end

return easy_onboarding
