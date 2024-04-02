-- Inventory

local inventoryModule = {
	inventories = {},
	uiOpened = false,
	nbUIOpen = 0,
	listUIOpened = {},

	-- private
	nbAlwaysVisible = 0,
}

local resourcesByKey = {}
local resourcesById = {}

inventoryModule.setResources = function(_, _resourcesByKey, _resourcesById)
	resourcesByKey = _resourcesByKey
	resourcesById = _resourcesById
end

local isClient = type(Client.IsMobile) == "boolean"

if isClient then
	function getSlotIndexFromVisibleInventories(x, y)
		for key, inventory in pairs(inventoryModule.listUIOpened) do
			if inventory and key ~= "cursor" then
				local inventoryUi = inventory.ui
				if
					inventoryUi.pos.X <= x
					and x <= inventoryUi.pos.X + inventoryUi.Width
					and inventoryUi.pos.Y <= y
					and y <= inventoryUi.pos.Y + inventoryUi.Height
				then
					return key, inventoryUi:getSlotIndex(x - inventoryUi.pos.X, y - inventoryUi.pos.Y)
				end
			end
		end
	end

	LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
		local cursorSlot = inventoryModule.inventories.cursor.slots[1]
		if not cursorSlot.key then
			return
		end
		local inventoryKey, slotIndex = getSlotIndexFromVisibleInventories(pe.X * Screen.Width, pe.Y * Screen.Height)
		if not inventoryKey or not slotIndex or slotIndex < 1 then
			return
		end
		local inventory = inventoryModule.inventories[inventoryKey]
		if Client.IsMobile then
			inventory:selectSlot(slotIndex)
		else
			LocalEvent:Send("InvClearSlot", {
				key = "cursor",
				slotIndex = 1,
				callback = function()
					inventory:tryAddElement(cursorSlot.key, cursorSlot.amount, slotIndex)
				end,
			})
		end
	end, { topPriority = true })

	local saveInventoriesRequests = {}
	function saveInventory(iKey)
		if iKey == "cursor" then
			return
		end

		local request = saveInventoriesRequests[iKey]
		if request then
			request:Cancel()
		end
		saveInventoriesRequests[iKey] = Timer(0.1, function()
			local store = KeyValueStore("craftisland_inventories")
			local key = string.format("%s-%s", iKey, Player.UserID)
			local data = inventoryModule:serialize(iKey)
			store:Set(key, data, function(success)
				if not success then
					print("can't save")
					return
				end
			end)
		end)
	end
end -- end is client

inventoryModule.serialize = function(self, iKey)
	local inventory = self.inventories[iKey]
	if inventory == nil then
		return
	end
	local data = Data()
	data:WriteUInt8(1) -- version
	data:WriteUInt16(inventory.nbSlots) -- nbSlots
	for i = 1, inventory.nbSlots do
		local slot = inventory.slots[i]
		local id = slot.key and resourcesByKey[slot.key].id or 0
		data:WriteUInt16(math.floor(id))
		data:WriteUInt16(slot and slot.amount or 0)
	end
	return data
end

inventoryModule.deserialize = function(_, iKey, data)
	if not data or iKey == "cursor" then
		return
	end
	local version = data:ReadUInt8()
	if version ~= 1 then
		return
	end
	local inventory = inventoryModule.inventories[iKey]
	if not inventory then
		error("Inventory: can't find " .. iKey, 2)
	end
	local nbSlots = data:ReadUInt16()
	for slotIndex = 1, nbSlots do
		local id = data:ReadUInt16()
		local amount = data:ReadUInt16()
		if id > 0 then
			inventory:tryAddElement(resourcesById[id].key, amount, slotIndex)
		end
	end
end

inventoryModule.create = function(_, iKey, config)
	if not config.width or not config.height then
		return error("inventory: missing width or height in config", 2)
	end
	local nbSlots = config.width * config.height
	local alwaysVisible = config.alwaysVisible
	local selector = config.selector
	local toSave = true
	if config.toSave == false then
		toSave = false
	end

	local inventory = {}
	inventoryModule.inventories[iKey] = inventory

	inventory.onOpen = config.onOpen

	local slots = {}
	for i = 1, nbSlots do
		slots[i] = { index = i }
	end
	inventory.slots = slots
	inventory.nbSlots = nbSlots

	local function inventoryGetSlotIndexMatchingKey(key)
		for i = 1, nbSlots do
			if slots[i] and slots[i].key == key then
				return i
			end
		end
	end

	inventory.tryAddElement = function(_, rKey, amount, optionalSlot)
		if rKey == nil or amount == nil then
			return
		end
		local slotIndex = optionalSlot
		if slotIndex then
			if slots[slotIndex].key and slots[slotIndex].key ~= rKey then
				LocalEvent:Send("InvAdd", {
					key = "cursor",
					rKey = slots[slotIndex].key,
					amount = slots[slotIndex].amount,
					callback = function()
						slots[slotIndex].key = nil
						slots[slotIndex].amount = nil
						inventory:tryAddElement(rKey, amount, optionalSlot)
					end,
				})
				return
			end
		else
			slotIndex = inventoryGetSlotIndexMatchingKey(rKey)
		end
		if not slotIndex then
			-- try add to first empty slot
			for i = 1, nbSlots do
				if slots[i].key == nil then
					slotIndex = i
					break
				end
			end
		end
		if not slotIndex then
			LocalEvent:Send("invFailAdd(" .. iKey .. ")", { key = rKey, amount = amount })
			return false
		end

		slots[slotIndex] = { index = slotIndex, key = rKey, amount = (slots[slotIndex].amount or 0) + amount }
		LocalEvent:Send("invUpdateSlot(" .. iKey .. ")", slots[slotIndex])

		return true
	end

	inventory.tryRemoveElement = function(_, rKey, amount, optionalSlot)
		if rKey == nil or amount == nil then
			return
		end

		local slotIndex = optionalSlot
		if not slotIndex then
			slotIndex = inventoryGetSlotIndexMatchingKey(rKey)
		end
		if not slotIndex or amount > slots[slotIndex].amount then
			LocalEvent:Send("invFailRemove(" .. iKey .. ")", { key = rKey, amount = amount })
			return false
		end

		slots[slotIndex].amount = slots[slotIndex].amount - amount
		if slots[slotIndex].amount == 0 then
			slots[slotIndex] = { index = slotIndex }
		end
		LocalEvent:Send("invUpdateSlot(" .. iKey .. ")", slots[slotIndex])

		return true
	end

	inventory.clearSlotContent = function(_, slotIndex)
		if slotIndex == nil then
			return
		end
		local contentToClear = slots[slotIndex]
		slots[slotIndex] = { index = slotIndex }
		LocalEvent:Send("invUpdateSlot(" .. iKey .. ")", slots[slotIndex])
		return contentToClear
	end

	local bg
	local uiSlots = {}

	if iKey == "cursor" then
		local latestPointerPos
		LocalEvent:Listen(LocalEvent.Name.Tick, function()
			if not latestPointerPos or not inventory.slots[1].key then
				return
			end
			local pe = latestPointerPos
			inventory.ui.pos = { pe.X * Screen.Width - 20, pe.Y * Screen.Height - 20 }
			inventory.ui.pos.Z = -300
		end, { topPriority = true })
		LocalEvent:Listen(LocalEvent.Name.PointerMove, function(pe)
			latestPointerPos = pe
		end, { topPriority = true })
		LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
			latestPointerPos = pe
		end, { topPriority = true })
	end

	inventory.show = function(_)
		local ui = require("uikit")
		local padding = require("uitheme").current.padding

		bg = ui:createFrame(iKey == "cursor" and Color(0, 0, 0, 0) or Color(198, 198, 198))
		inventory.ui = bg

		local nbRows = config.height
		local nbColumns = config.width

		local cellSize = Screen.Width < 1000 and 40 or 60

		inventory.isVisible = true

		for j = 1, nbRows do
			for i = 1, nbColumns do
				local slotBg = ui:createFrame(iKey == "cursor" and Color(0, 0, 0, 0) or Color(85, 85, 85))
				local slot = ui:createFrame(iKey == "cursor" and Color(0, 0, 0, 0) or Color(139, 139, 139))
				slot:setParent(slotBg)
				local slotIndex = (j - 1) * nbColumns + i
				uiSlots[slotIndex] = slotBg
				slotBg.slot = slot
				slotBg.parentDidResize = function()
					slotBg.Size = cellSize
					slot.Size = slotBg.Size - padding
					slotBg.pos = { padding + (i - 1) * cellSize, padding + (nbRows - j) * cellSize }
					slot.pos = { padding * 0.5, padding * 0.5 }
				end
				slotBg:setParent(bg)
				if iKey ~= "cursor" then
					local cursorSlotOnPress
					if not Client.IsMobile then
						slotBg.onPress = function()
							local content = slots[slotIndex]
							cursorSlotOnPress = inventoryModule.inventories.cursor.slots[1]
							if not content.key then
								return
							end
							if sneak then
								LocalEvent:Send("InvAdd", {
									key = iKey == "hotbar" and "mainInventory" or "hotbar",
									rKey = content.key,
									amount = content.amount,
									callback = function()
										inventory:clearSlotContent(slotIndex)
									end,
								})
								return
							end
						end
						slotBg.onDrag = function()
							local cursorSlot = inventoryModule.inventories.cursor.slots[1]
							if cursorSlot.key then
								return
							end
							local content = slots[slotIndex]
							if not content.key then
								return
							end
							LocalEvent:Send("InvAdd", {
								key = "cursor",
								rKey = content.key,
								amount = content.amount,
								callback = function()
									inventory:clearSlotContent(slotIndex)
								end,
							})
						end
						slotBg.onRelease = function()
							local cursorSlot = inventoryModule.inventories.cursor.slots[1]
							if not cursorSlot.key and slots[slotIndex].key then
								local content = slots[slotIndex]
								LocalEvent:Send("InvAdd", {
									key = "cursor",
									rKey = content.key,
									amount = content.amount,
									callback = function()
										inventory:clearSlotContent(slotIndex)
									end,
								})
								return
							end
							if not cursorSlotOnPress.key then
								return
							end
							local key, amount = cursorSlot.key, cursorSlot.amount
							LocalEvent:Send("InvClearSlot", {
								key = "cursor",
								slotIndex = 1,
								callback = function()
									inventory:tryAddElement(key, amount, slotIndex)
								end,
							})
						end
					else
						-- mobile
						slotBg.onRelease = function()
							inventory:selectSlot(slotIndex)
						end
					end
				end
				LocalEvent:Send("invUpdateSlot(" .. iKey .. ")", slots[slotIndex])
			end
		end

		bg.getSlotIndex = function(_, x, y)
			x = x - padding + cellSize * 0.5
			y = y - padding + cellSize * 0.5
			return math.floor(x / (cellSize + padding))
				+ 1
				+ (nbRows - 1 - (math.floor(y / (cellSize + padding)))) * nbColumns
		end

		bg.parentDidResize = function()
			bg.Width = nbColumns * cellSize + 2 * padding
			bg.Height = nbRows * cellSize + 2 * padding

			bg.pos = config.uiPos and config.uiPos(bg)
				or { Screen.Width * 0.5 - bg.Width * 0.5, Screen.Height * 0.5 - bg.Height * 0.5 }
		end
		bg:parentDidResize()

		if not alwaysVisible then
			require("crosshair"):hide()
			Pointer:Show()
			require("controls"):turnOff()
			Player.Motion = { 0, 0, 0 }
		end
		inventory.isVisible = true

		if selector then
			inventory:selectSlot(1)
		end

		return bg
	end

	local prevSelectedSlotIndex
	inventory.selectSlot = function(_, index)
		index = index or prevSelectedSlotIndex
		if prevSelectedSlotIndex then
			uiSlots[prevSelectedSlotIndex]:setColor(Color(85, 85, 85))
		end
		if not uiSlots[index] then
			return
		end
		uiSlots[index]:setColor(Color.White)
		prevSelectedSlotIndex = index
		LocalEvent:Send("invSelect(" .. iKey .. ")", slots[index])
	end

	local loadingInventory = true

	local ui = require("uikit")
	LocalEvent:Listen("invUpdateSlot(" .. iKey .. ")", function(slot)
		if not loadingInventory and toSave then
			saveInventory(iKey)
		end

		if not uiSlots or not slot.index or inventory.isVisible == false then
			return
		end

		if selector then
			inventory:selectSlot() -- remove item in hand if reached 0 or add it if at least 1
		end

		if
			uiSlots[slot.index].key == slot.key
			and slot.amount
			and slot.amount > 1
			and uiSlots[slot.index].content.amountText
		then
			uiSlots[slot.index].content.amountText.Text = string.format("%d", slot.amount)
			uiSlots[slot.index].content.amountText:show()
			uiSlots[slot.index].content:parentDidResize()
			return
		end

		if uiSlots[slot.index].content then
			uiSlots[slot.index].content:remove()
			uiSlots[slot.index].content = nil
		end

		if slot.key == nil then
			return
		end

		uiSlots[slot.index].key = slot.key
		local uiSlot = uiSlots[slot.index].slot

		local content = ui:createFrame()

		local amountText = ui:createText(string.format("%d", slot.amount), Color.White, "small")
		content.amountText = amountText
		amountText.pos.Z = -500
		amountText:setParent(content)
		if slot.amount == 1 then
			amountText:hide()
		end

		local resource = resourcesByKey[slot.key]
		if resource.block then
			local b = MutableShape()
			b:AddBlock(resourcesByKey[slot.key].block.color, 0, 0, 0)

			local shape = ui:createShape(b)
			shape.pivot.Rotation = { math.pi * 0.1, math.pi * 0.25, 0 }
			shape:setParent(content)

			shape.parentDidResize = function()
				shape.Size = uiSlot.Width * 0.5
				shape.pos = { uiSlot.Width * 0.25, uiSlot.Height * 0.25 }
			end
		elseif resource.icon and resource.cachedShape then
			local obj = Shape(resource.cachedShape, { includeChildren = true })
			local shape = ui:createShape(obj, { spherized = true })
			shape:setParent(content)
			shape.pivot.Rotation = resource.icon.rotation
			shape.pivot.Scale = shape.pivot.Scale * resource.icon.scale

			shape.parentDidResize = function()
				shape.Size = math.min(uiSlot.Width * 0.5, uiSlot.Height * 0.5)
				shape.pos = Number3(uiSlot.Width * 0.25, uiSlot.Height * 0.25, 0)
					+ { resource.icon.pos[1] * uiSlot.Width, resource.icon.pos[2] * uiSlot.Height, 0 }
			end
		else -- unknown, red block
			local b = MutableShape()
			b:AddBlock(Color.Red, 0, 0, 0)

			local shape = ui:createShape(b)
			shape:setParent(content)

			shape.parentDidResize = function()
				shape.Size = uiSlot.Width * 0.5
				shape.pos = { uiSlot.Width * 0.25, uiSlot.Height * 0.25 }
			end
		end

		if slot.amount == 1 then
			amountText:hide()
		end
		content.parentDidResize = function()
			if not uiSlot then
				return
			end
			content.Size = uiSlot.Width
			amountText.pos = { content.Width - amountText.Width, 0 }
			amountText.pos.Z = -500
		end
		content:setParent(uiSlot)
		uiSlots[slot.index].content = content
	end)

	if selector then -- Hotbar
		LocalEvent:Listen(LocalEvent.Name.PointerWheel, function(delta)
			local newSlot = prevSelectedSlotIndex + (delta > 0 and 1 or -1)
			if newSlot <= 0 then
				newSlot = nbSlots
			end
			if newSlot > nbSlots then
				newSlot = 1
			end
			inventory:selectSlot(newSlot)
		end)
		LocalEvent:Listen(LocalEvent.Name.KeyboardInput, function(char, keycode, modifiers, down)
			if not down then
				return
			end
			local keys = { 82, 83, 84, 85, 86, 87, 88, 89, 81 }
			for i = 1, math.min(#keys, nbSlots) do
				if keycode == keys[i] then
					inventory:selectSlot(i)
					return
				end
			end
		end)
	end

	inventory.hide = function(_)
		if not bg then
			return
		end
		if alwaysVisible then
			return
		end
		inventory.isVisible = false
		bg:remove()
		bg = nil
		inventory.ui = nil

		Pointer:Hide()
		require("crosshair"):show()
		require("controls"):turnOn()
	end

	inventory.isVisible = false
	inventory.alwaysVisible = alwaysVisible
	if alwaysVisible then
		inventory:show()
		inventoryModule.listUIOpened[iKey] = inventory
		inventoryModule.nbUIOpen = inventoryModule.nbUIOpen + 1
		inventoryModule.nbAlwaysVisible = inventoryModule.nbAlwaysVisible + 1
	end

	if toSave then
		-- get value in KVS
		local kvsKey = string.format("%s-%s", iKey, Player.UserID)
		local store = KeyValueStore("craftisland_inventories")
		store:Get(kvsKey, function(success, results)
			if not success then
				print("failed to get kvs")
				return
			end
			if results[kvsKey] == nil then -- new player or new inventory
				loadingInventory = false
				saveInventory(iKey)
				return
			end
			inventoryModule:deserialize(iKey, results[kvsKey])
			loadingInventory = false
		end)
	else
		loadingInventory = false
	end

	return inventory
end

LocalEvent:Listen("InvAdd", function(data)
	local key = data.key
	local rKey = data.rKey
	local amount = data.amount
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't find " .. key, 2)
	end
	local success = inventory:tryAddElement(rKey, amount)
	if not data.callback then
		return
	end
	data.callback(success)
end)

LocalEvent:Listen("InvRemove", function(data)
	local key = data.key
	local rKey = data.rKey
	local amount = data.amount
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't find " .. key, 2)
	end
	local success = inventory:tryRemoveElement(rKey, amount)
	if not data.callback then
		return
	end
	data.callback(success)
end)

LocalEvent:Listen("InvClearAll", function(data)
	local key = data.key
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't find " .. key, 2)
	end
	for index = 1, inventory.nbSlots do
		inventory:clearSlotContent(index)
	end
	if not data.callback then
		return
	end
	data.callback()
end)

LocalEvent:Listen("InvClearSlot", function(data)
	local key = data.key
	local index = data.slotIndex
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't find " .. key, 2)
	end
	local success = inventory:clearSlotContent(index)
	if not data.callback then
		return
	end
	data.callback(success)
end)

LocalEvent:Listen("InvShow", function(data)
	local key = data.key
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't open " .. key, 2)
	end
	if inventory.alwaysVisible or inventory.isVisible then
		return
	end
	inventory:show()
	if inventory.onOpen then
		inventory:onOpen()
	end
	inventoryModule.listUIOpened[key] = inventory
	inventoryModule.nbUIOpen = inventoryModule.nbUIOpen + 1
	inventoryModule.uiOpened = true
end)

LocalEvent:Listen("InvHide", function(data)
	local key = data.key
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't close " .. key, 2)
	end
	if inventory.alwaysVisible or inventory.isVisible == false then
		return
	end
	inventory:hide()
	inventoryModule.nbUIOpen = inventoryModule.nbUIOpen - 1
	inventoryModule.listUIOpened[key] = nil
	if inventoryModule.nbUIOpen <= inventoryModule.nbAlwaysVisible then
		inventoryModule.uiOpened = false
	end
end)

LocalEvent:Listen("InvToggle", function(data)
	local key = data.key
	local inventory = inventoryModule.inventories[key]
	if not inventory then
		error("Inventory: can't close " .. key, 2)
	end
	if inventory.isVisible then
		LocalEvent:Send("InvHide", data)
	else
		LocalEvent:Send("InvShow", data)
	end
end)

return inventoryModule
