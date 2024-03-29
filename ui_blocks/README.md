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
	ui_blocks = "github.com/caillef/cubzh-library/ui_blocks:873c6f1"
}
```

### Node Anchors

Easiest way to place your ui node in a specific corner or in the center.

#### anchorNode

Set the position of a noce based on its parent.

Parameters:
1) ui node: the UI node
2) horizontal align: can be "left"/"center"/"right" (if nil, center by default)
3) vertical align: can be "bottom"/"center"/"top" (if nil, center by default)
4) margin: a single number or { marginLeft, marginBottom, marginRight, marginTop }

⚠️ This function only works if you do not define parentDidResize. Check `setNodePos` for more information.

```lua
local playBtn = ui:createButton("Play")
ui_blocks:anchorNode(playBtn, "right", "top", 5)
```

#### setNodePos

If we need to define parentDidResize, we can't use the `anchorNode` function. For example here, we need to resize the button based on the Screen Width, so we use setNodePos. The parameters are the same as anchorNode.

```lua
local leaderboardBtn = ui:createButton("Leaderboard")
leaderboardBtn.parentDidResize = function()
    leaderboardBtn.Width = Screen.Width * 0.3
    ui_blocks:setNodePos(leaderboardBtn, "left", "top", { 0, 0, 20, 40 }) -- 20 margin left, 40 margin top
end
leaderboardBtn:parentDidResize()
```

### createBlock

This function can create 5 types of blocks:

1) Triptych: if horizontal, you can set node for left/center/right. if vertical, you can set node for top/center/bottom.
2) Columns: they all have the same size
3) Rows: they all have the same size
4) Horizontal Container: list of elements that will be pushed one after the other horizontally
5) Vertical Container: list of elements that will be pushed one after the other vertically

⚠️ do not redefined parentDidResize on a block, it will break the responsiveness of the block.

#### Columns

```lua
-- smallThree and bigEight are centered based on their parents (that are columns)
local classicText = ui:createText("Hello", Color.White, "small")
ui_blocks:anchorNode(classicText, "center", "center")

local buttonHello2 = ui:createButton("Hello 2")
ui_blocks:anchorNode(buttonHello2, "right", "top", 4)

local classicText3 = ui:createText("Hello 3", Color.White, "small")
ui_blocks:anchorNode(classicText3, "left", "bottom", { 0, 2, 10, 0 })

local columns = ui_blocks:createBlock({
    height = function(node) return buttonHello2.Height * 3 end,
    columns = {
        -- you can push as many elements as you want here as columns
        classicText,
        buttonHello2,
        classicText3,
    }
})
```