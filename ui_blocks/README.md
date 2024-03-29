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

You can't use more than one type when calling createBlock (you can't define columns and triptych for example)

In the config of a block, you can have up to 4 properties + 1 type:
```lua
local topBar = ui_blocks:createBlock({
    -- if width or height are not defined, take the full width and height of the parent
    width = function(node, elems) return 200 end,
    height = function(node, elems) return node.parent.Height end,
    pos = function(node) return { 10, 20 } end,
    postload = function(node, elems)
        -- here you can do actions on the node or the elements you loaded
    end

    -- then you define either triptych, columns, rows, horizontal or vertical.
```

`elems` is a way to retrieve a block that you created inside the config. See Triptych example under to understand how to use the height of an element to define the height of the block for example.

⚠️ do not redefined parentDidResize on a block, it will break the responsiveness of the block.

#### Triptych

Triptych is the best way to anchor elements on the left/center/right of an horizontal triptych or top/center/bottom of a vertical triptych.

You need to define the horizontal or vertical using `dir` for direction.

Example of an horizontal triptych for a topbar
```lua
local topBar = ui_blocks:createBlock({
    -- width is full width, height is closeBtn.Height
    -- we can access the elements we define in the triptych using keys (see definition of right in triptych)
    height = function(_, elems) return elems.closeBtn.Height end,
    triptych = {
        dir = "horizontal",
        color = Color(0,0,0,0.5),
        center = { key = "title", node = ui:createText("Shop", Color.White) },
        right = { key = "closeBtn", node = ui:createButton("X") },
    },
    -- called once all the objects are created, you can access elems[key]
    postload = function(node, elems)
        -- here we adjust the width so that the button is a square
        elems.closeBtn.Width = elems.closeBtn.Height
        elems.closeBtn.onRelease = function()
            print("close")
        end
    end,
})
```

Example of a vertical triptych
```lua
-- right panel with "top" at the top, "bottom" at the bottom
local rightPanel = ui_blocks:createBlock({
    triptych = {
        dir = "vertical",
        color = Color.Blue, -- background color
        top = { node = ui:createText("top") },
        -- center is not defined here
        bottom = { node = ui:createText("bottom") },
    },
})
```

```lua
-- main container with 2 columns, the red area (future scroll view) and the blue created above
local container = ui_blocks:createBlock({
    height = function(node) return node.parent and node.parent.Height - topBar.Height or 0 end,
    columns = { leftPanel, rightPanel },
})

-- window is a vertical triptych with the topbar and the bottom (height of bottom is computed above)
local window = ui_blocks:createBlock({
    width = function() return Screen.Width * 0.8 end,
    height = function(_, elems) return Screen.Height * 0.7 end,
    pos = function(node) return { Screen.Width * 0.5 - node.Width * 0.5, Screen.Height * 0.5 - node.Height * 0.5 } end,
    triptych = {
        dir = "vertical",
        color = Color(0,0,0,0.5),
        top = { key = "topBar", node = topBar },
        bottom = { key = "container", node = container },
    },
    name = "window",
})
window:parentDidResize()
```

#### Columns and Rows

Columns and Rows will divide equally the space based on the size of the parent node.

```lua
local classicText = ui:createText("Hello", Color.White, "small")
ui_blocks:anchorNode(classicText, "center", "bottom")

local buttonHello2 = ui:createButton("Hello 2")
ui_blocks:anchorNode(buttonHello2, "right", "top", 4)

local classicText3 = ui:createText("Hello 3", Color.White, "small")
ui_blocks:anchorNode(classicText3, "left", "bottom", { 0, 2, 10, 0 })

local columns = ui_blocks:createBlock({
    -- to make rows, replace this with "rows"
    columns = {
        -- you can push as many elements as you want here as columns
        classicText,
        buttonHello2,
        classicText3,
    }
})

local frame = ui:createFrame(Color.Blue)
frame.parentDidResize = function()
    frame.Width = 400
    frame.Height = 200
    frame.pos = { 5, 5 }
end

columns:setParent(frame)
```