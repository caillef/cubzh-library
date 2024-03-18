--- bitWriter is a module that writes and read bits.
--- The goal is to optimize the size of the data
--- It is required that the data is read in the same order as the bits are written.
--- It is useful to reduce the size of chunk data.
--- Data type can only write byte and not bits, this module allows you to write individual bits that are packed in bytes.
--- For example to save a x,y,z position, instead of using data:WriteNumber3(Number3(200,245,23)) that will use 3 times the size of a float number, you could say that the max value is 255 so each position can be saved on 24 bits (8 bits per number).
--- Usage:
--- WRITE
--- Let's say you want to save x,y,z positions. Each value is between -500 and 500. As we must only use positive value, we will add 500 for each member to save values between 0 and 1000. We need to find on how many bits you can store values from 0 to 1000 => 10 bits (1024).
--- -20,50,400 is now 480,550,900.
--- To save this data, you can use the following code:
--- local data = Data()
--- local rest = bitWriter:writeNumbers(data, {
---     { value = 480, size = 10 }, -- x on 10 bits
---     { value = 550, size = 10 }, -- y on 10 bits
---     { value = 900, size = 10 }, -- z on 10 bits
--- })
--- assert(rest == 2) -- the returned value "rest" is the number of bits not used as the module can only write byte (8 bits).
--- -- Here the rest is 2 as we wrote 30 bits (4 bytes = 32 bits)
--- XXXXXXXX XXYYYYYY YYYYZZZZ ZZZZZZ00 <- the 0 are the 2 bits.
--- The rest can be used to add more data right after the previous data without loosing these 2 bits.
---
--- data.Cursor = data.Cursor - 1 -- move back the cursor by one
--- bitWriter:writeNumbers(data, {
---     { value = 3, size = 2 }
--- }, { offset = 6 }) -- here offset is 6 as only 2 bits are still available (XXXXXX00)
---
--- READ
---
--- The read function is very similar to the write function but instead of the value, you give a key.
--- data.Cursor = 0 (if you just wrote the data, bring the Cursor back to the first byte)
--- local list = bitWriter:readNumbers(data, {
---     { key = "x", size = 10 }, -- x on 10 bits
---     { key = "y", size = 10 }, -- x on 10 bits
---     { key = "z", size = 10 }, -- x on 10 bits
---     { key = "orientation", size = 2 }, -- orientation on 2 bits (0,1,2,3)
--- })
--- print(list.x)
---
--- check bitWriter.unit_tests to see more examples and run it (bitWriter:unit_tests()) to ensure it still works with your version of Cubzh.

local bitWriter = {}

bitWriter.readNumbers = function(_, data, sizes, config)
	local list = {}
	local offset = config.offset or 0
	local restBits = 8 - offset
	local byte = data:ReadUInt8()
	if offset > 0 then
		byte = byte & ((2 << (offset + 1)) - 1)
	end

	local function readValue(size, currentValue)
		currentValue = currentValue or 0

		local newRestBits = restBits - size
		-- if not enough to read, read byte and recursively call readValue
		if newRestBits < 0 then
			size = -newRestBits
			currentValue = currentValue + (byte << size)
			if data.Cursor <= data.Length then
				byte = data:ReadUInt8()
				restBits = 8
			else
				error("not enough bytes", 2)
			end
			return readValue(size, currentValue)
		end
		-- else add the value
		currentValue = currentValue + (byte >> newRestBits)
		local mask = ((1 << newRestBits) - 1)
		byte = byte & mask
		restBits = newRestBits
		if restBits == 0 then
			if data.Cursor < data.Length then
				byte = data:ReadUInt8()
				restBits = 8
			end
		end
		return currentValue
	end

	for _, value in ipairs(sizes) do
		local key = value.key
		local size = value.size
		list[key] = readValue(size)
	end
	return list
end

bitWriter.writeNumbers = function(_, data, list, config)
	local bytes = {}
	local offset = config.offset or 0
	local restBits = 8 - offset
	local uint8 = 0
	if offset > 0 then
		uint8 = data:ReadUInt8()
		data.Cursor = data.Cursor - 1
	end

	local function addBytes(value, size)
		local newRestBits = restBits - size
		-- if not enough space, write a part and recursively call addBytes
		if newRestBits < 0 then
			local toShift = size - restBits
			uint8 = uint8 + (value >> toShift)
			-- if 3 bytes (100), go to +1 (1000) and remove 1 (111)
			local mask = (1 << toShift) - 1
			value = value & mask
			size = size - restBits
			table.insert(bytes, uint8)
			uint8 = 0
			restBits = 8
			return addBytes(value, size)
		end
		-- else add the value
		uint8 = uint8 + (value << newRestBits)
		restBits = restBits - size
		if restBits == 0 then
			table.insert(bytes, uint8)
			uint8 = 0
			restBits = 8
		end
	end

	for _, v in ipairs(list) do
		local value = v.value
		local size = v.size
		assert(value < (1 << size), string.format("error: %d cannot be serialize with %d bits", value, size))
		addBytes(value, size)
	end

	-- add latest byte
	if restBits < 8 then
		table.insert(bytes, uint8)
	else
		restBits = 0
	end

	for _, v in ipairs(bytes) do
		data:WriteUInt8(v)
	end
	return restBits
end

bitWriter.unit_tests = function(self)
	local d = Data()
	local rest = self:writeNumbers(d, {
		{ value = 42, size = 12 }, -- x
		{ value = 42, size = 6 }, -- y
		{ value = 1, size = 1 }, -- z
		{ value = 2, size = 2 }, -- orientation
	})
	assert(rest == 3)

	-- right read file
	d.Cursor = 0
	local list = self:readNumbers(d, {
		{ key = "x", size = 12 },
		{ key = "y", size = 6 },
		{ key = "z", size = 1 },
		{ key = "orientation", size = 2 },
	})
	for k, v in pairs(list) do
		if k == "x" then
			assert(v == 42)
		end
		if k == "y" then
			assert(v == 42)
		end
		if k == "z" then
			assert(v == 1)
		end
		if k == "orientation" then
			assert(v == 2)
		end
	end

	-- wrong read file (x should be 12)
	d.Cursor = 0
	local list = self:readNumbers(d, {
		{ key = "x", size = 6 },
		{ key = "y", size = 6 },
		{ key = "z", size = 1 },
		{ key = "orientation", size = 3 },
	})
	for k, v in pairs(list) do
		if k == "x" then
			assert(v ~= 42)
		end
	end

	-- another example
	local d = Data()
	local rest = self:writeNumbers(d, {
		{ value = 424, size = 10 }, -- x
		{ value = 999, size = 10 }, -- y
		{ value = 200, size = 10 }, -- z
		{ value = 3, size = 2 }, -- orientation
	})
	assert(rest == 0)

	-- right read file
	d.Cursor = 0
	local list = self:readNumbers(d, {
		{ key = "x", size = 10 },
		{ key = "y", size = 10 },
		{ key = "z", size = 10 },
		{ key = "orientation", size = 2 },
	})
	for k, v in pairs(list) do
		if k == "x" then
			assert(v == 424)
		end
		if k == "y" then
			assert(v == 999)
		end
		if k == "z" then
			assert(v == 200)
		end
		if k == "orientation" then
			assert(v == 3)
		end
	end

	-- offset
	local d = Data()
	d.Cursor = 0
	local rest = self:writeNumbers(d, {
		{ value = 42, size = 10 }, -- x
		{ value = 42, size = 10 }, -- y
		{ value = 1, size = 10 }, -- z
	})
	assert(rest == 2)

	d.Cursor = d.Cursor - 1 -- move back the cursor by one
	local rest = self:writeNumbers(d, {
		{ value = 3, size = 2 }, -- orientation
	}, { offset = 8 - rest })
	assert(rest == 0)

	-- right read file
	d.Cursor = 0
	local list = self:readNumbers(d, {
		{ key = "x", size = 10 },
		{ key = "y", size = 10 },
		{ key = "z", size = 10 },
		{ key = "orientation", size = 2 },
	})
	for k, v in pairs(list) do
		if k == "x" then
			assert(v == 42)
		end
		if k == "y" then
			assert(v == 42)
		end
		if k == "z" then
			assert(v == 1)
		end
		if k == "orientation" then
			assert(v == 3)
		end
	end

	-- offset 2
	local d = Data()
	d:WriteUInt8(7 << 5) -- 11100000
	d.Cursor = 0
	local rest = self:writeNumbers(d, {
		{ value = 42, size = 6 }, -- x
		{ value = 42, size = 6 }, -- y
		{ value = 1, size = 1 }, -- z
		{ value = 2, size = 2 }, -- orientation
	}, { offset = 3 })
	assert(rest == 6)

	-- right read file
	d.Cursor = 0
	local list = self:readNumbers(d, {
		{ key = "x", size = 6 },
		{ key = "y", size = 6 },
		{ key = "z", size = 1 },
		{ key = "orientation", size = 2 },
	}, { offset = 3 })
	for k, v in pairs(list) do
		if k == "x" then
			assert(v == 42)
		end
		if k == "y" then
			assert(v == 42)
		end
		if k == "z" then
			assert(v == 1)
		end
		if k == "orientation" then
			assert(v == 2)
		end
	end

	print("unit tests success")
end

return bitWriter
