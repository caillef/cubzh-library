local eventLogger = {}

eventLogger.log = function(_, player, eventName, eventData, callback)
	local store = KeyValueStore("eventlogger")
	store:Get(player.UserID, function(success, results)
		if not success then
			error("Can't access event logger")
		end
		local data = results[player.UserID] or {}
		data[eventName] = data[eventName] or {}
		table.insert(data[eventName], eventData)
		store:Set(player.UserID, data, function(success)
			if not success then
				error("Can't access event logger")
			end
			if not callback then
				return
			end
			callback(data[eventName])
		end)
	end)
end

eventLogger.get = function(_, player, eventNames, callback)
	if type(eventNames) == "string" then
		eventNames = { eventNames }
	end

	local store = KeyValueStore("eventlogger")
	store:Get(player.UserID, function(success, results)
		if not success then
			error("Can't access event logger")
		end
		local finalResults = {}
		if not results[player.UserID] then
			callback(finalResults)
			return
		end
		for _, key in ipairs(eventNames) do
			finalResults[key] = results[player.UserID][key]
		end
		callback(finalResults)
	end)
end

return eventLogger
