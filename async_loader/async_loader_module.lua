--- Like Promise.all in javascript, you give a list of callbacks and a final callback to call when everything is finished
--- Each callback takes a "done" callback as first parameter
--- USAGE
--- Modules = {
---     async_loader = "github.com/caillef/cubzh-library/async_loader"
--- }
---
--- local cachedShape = nil
--- local list = {
---     function(done)
---         -- get something from the KeyValueStore
---         Timer(1, function()
---             -- received the info in a callback
---             done()
---         end)
---     end,
---     function(done)
---         -- load a shape
---         Object:Load("repo.name", function(obj)
---             cachedShape = obj
---             done()
---         end)
---     end
--- }
---
--- async_loader:start(list, function()
---     print("everything is done!")
--- end)

local asyncLoader = {}

asyncLoader.start = function(_, list, callback)
	local nbWaiting = #list
	local currentWaiting = 0

	local function loadedOneMore()
		currentWaiting = currentWaiting + 1
		if currentWaiting == nbWaiting then
			callback()
		end
	end

	for _, func in ipairs(list) do
		func(loadedOneMore)
	end
end

return asyncLoader
