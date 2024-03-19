--- EventLogger modules allow you to track player actions
--- Can be useful to detect first connection, or when a player does an action in your game to see the progress.
--- It can also be used for connection streak to give rewards to a player.
--- USAGE:
--- Modules = {
---    eventLogger = "github.com/caillef/cubzh-library/event_logger:a7320a5",
--- }
---
--- -- Here is an example to send a Welcome message on FirstConnection
--- LocalEvent:Listen("eventLoggerEvent", function(data)
---		if data.type == "FirstConnection" then
--- 		print("Welcome message")
---     end
--- end)
---
--- eventLogger:log(Player, "sessionsLog", { v = 1, date = Time.Unix() }, function(logs)
--- 	if #logs == 1 then
--- 		LocalEvent:Send("eventLoggerEvent", { type = "FirstConnection" })
--- 	end
---
--- 	if #logs > 1 then -- not first connection
--- 		print("Last connection", logs[#logs - 1].date)
--- 	end
--- end)
---
--- -- Maybe send a reward to the player if he played 7 days in a row?
--- eventLogger:get(Player, "sessionsLog", function(logs)
---		-- print all connections
---		for index,log in ipairs(logs) do
--- 		print("Entry", index, log.date)
--- 	end
--- end)

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
