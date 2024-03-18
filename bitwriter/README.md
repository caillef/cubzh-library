# bitWriter
bitWriter is a module that writes and read bits.
The goal is to optimize the size of the data
It is required that the data is read in the same order as the bits are written.
It is useful to reduce the size of chunk data.
Data type can only write byte and not bits, this module allows you to write individual bits that are packed in bytes.
For example to save a x,y,z position, instead of using data:WriteNumber3(Number3(200,245,23)) that will use 3 times the size of a float number, you could say that the max value is 255 so each position can be saved on 24 bits (8 bits per number).

## Usage

### Import

```lua
Modules = {
	bitWriter = "github.com/caillef/cubzh-library/bitwriter:873c6f1"
}
```

### Write

Let's say you want to save x,y,z positions. Each value is between -500 and 500. As we must only use positive value, we will add 500 for each member to save values between 0 and 1000. We need to find on how many bits you can store values from 0 to 1000 => 10 bits (1024).
-20,50,400 is now 480,550,900.
To save this data, you can use the following code:
```lua
local data = Data()
local rest = bitWriter:writeNumbers(d, {
    { value = 480, size = 10 }, -- x on 10 bits
    { value = 550, size = 10 }, -- y on 10 bits
    { value = 900, size = 10 }, -- z on 10 bits
})
assert(rest == 2) -- the returned value "rest" is the number of bits not used as the module can only write byte (8 bits).
```

Here the rest is 2 as we wrote 30 bits (4 bytes = 32 bits)
XXXXXXXX XXYYYYYY YYYYZZZZ ZZZZZZ00 <- the 0 are the 2 bits.
The rest can be used to add more data right after the previous data without loosing these 2 bits.

```lua
d.Cursor = d.Cursor - 1 -- move back the cursor by one
bitWriter:writeNumbers(d, {
    { value = 3, size = 2 }
}, { offset = 6 }) -- here offset is 6 as only 2 bits are still available (XXXXXX00)
```

### Read

The read function is very similar to the write function but instead of the value, you give a key.

```lua
d.Cursor = 0 -- (if you just wrote the data, bring the Cursor back to the first byte)
local list = bitWriter:readNumbers(d, {
    { key = "x", size = 10 }, -- x on 10 bits
    { key = "y", size = 10 }, -- x on 10 bits
    { key = "z", size = 10 }, -- x on 10 bits
    { key = "orientation", size = 2 }, -- orientation on 2 bits (0,1,2,3)
})
print(list.x)
```

## Unit tests

Check bitWriter.unit_tests to see more examples and run it (bitWriter:unit_tests()) to ensure it still works with your version of Cubzh.
