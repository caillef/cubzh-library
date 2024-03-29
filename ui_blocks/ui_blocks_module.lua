local ui_blocks = {}

ui_blocks.createTriptych = function(_, config)
	local ui = require("uikit")

	local node = ui:createFrame(config.color)

	local dir = config.dir or "horizontal"

	local left = config.left or config.top
	local center = config.center
	local right = config.right or config.bottom

	if left then
		left:setParent(node)
	end
	if center then
		center:setParent(node)
	end
	if right then
		right:setParent(node)
	end

	node.parentDidResize = function()
		if not node.parent then
			return
		end
		node.Width = node.parent.Width
		node.Height = node.parent.Height

		if center then
			center.pos = { node.Width * 0.5 - center.Width * 0.5, node.Height * 0.5 - center.Height * 0.5 }
		end

		if dir == "horizontal" then
			if left then
				left.pos = { 0, node.Height * 0.5 - left.Height * 0.5 }
			end
			if right then
				right.pos = { node.Width - right.Width, node.Height * 0.5 - right.Height * 0.5 }
			end
		end
		if dir == "vertical" then
			if left then
				left.pos = { node.Width * 0.5 - left.Width * 0.5, node.Height - left.Height }
			end
			if right then
				right.pos = { node.Width * 0.5 - right.Width * 0.5, 0 }
			end
		end
	end

	return node
end

ui_blocks.createColumns = function(_, config)
	local ui = require("uikit")

	local node = ui:createFrame()

	local nodes = config.nodes

	local nbColumns = #nodes
	if not nbColumns or nbColumns < 1 then
		error("config.nodes must have at least two nodes")
		return
	end

	local columns = {}
	for i = 1, nbColumns do
		local column = ui:createFrame()
		nodes[i]:setParent(column)
		column:setParent(node)
		table.insert(columns, column)
	end
	node.columns = columns

	node.parentDidResize = function()
		if not node.parent then
			return
		end
		node.Width = node.parent.Width
		node.Height = node.parent.Height
		local columnWidth = math.floor(node.Width / nbColumns)
		for k, column in ipairs(columns) do
			column.Width = columnWidth
			column.Height = node.Height
			column.pos = { (k - 1) * columnWidth, 0 }
		end
	end

	return node
end

ui_blocks.createRows = function(_, config)
	local ui = require("uikit")

	local node = ui:createFrame()

	local nodes = config.nodes

	local nbRows = #nodes
	if not nbRows or nbRows < 1 then
		error("config.nodes must have at least two nodes")
		return
	end

	local rows = {}
	for i = 1, nbRows do
		local row = ui:createFrame()
		nodes[i]:setParent(row)
		row:setParent(node)
		table.insert(rows, row)
	end
	node.rows = rows

	node.parentDidResize = function()
		if not node.parent then
			return
		end
		node.Width = node.parent.Width
		node.Height = node.parent.Height
		local rowHeight = math.floor(node.Height / nbRows)
		for k, row in ipairs(rows) do
			row.Width = node.Width
			row.Height = rowHeight
			row.pos = { 0, node.Height - k * rowHeight }
		end
	end

	return node
end

ui_blocks.createLineContainer = function(_, config)
	local uiContainer = require("ui_container")

	local node
	if config.dir == "vertical" then
		node = uiContainer:createVerticalContainer()
	else
		node = uiContainer:createHorizontalContainer()
	end

	for _, info in ipairs(config.nodes) do
		if info.type == "separator" then
			node:pushSeparator()
		elseif info.type == "gap" then
			node:pushGap()
		elseif info.type == "node" then
			node:pushElement(info.node)
		else
			node:pushElement(info)
		end
	end

	return node
end

ui_blocks.setNodePos = function(_, node, horizontalAnchor, verticalAnchor, margins)
	margins = margins or 0
	if type(margins) ~= "table" then
		-- left, bottom, right, top
		margins = { margins, margins, margins, margins }
	end

	local x = 0
	local y = 0

	local parentWidth = node.parent and node.parent.Width or Screen.Width
	local parentHeight = node.parent and node.parent.Height or (Screen.Height - Screen.SafeArea.Top)

	if horizontalAnchor == "left" then
		x = margins[3]
	elseif horizontalAnchor == "center" then
		x = parentWidth * 0.5 - node.Width * 0.5
	elseif horizontalAnchor == "right" then
		x = parentWidth - margins[1] - node.Width
	end

	if verticalAnchor == "bottom" then
		y = margins[2]
	elseif verticalAnchor == "center" then
		y = parentHeight * 0.5 - node.Height * 0.5
	elseif verticalAnchor == "top" then
		y = parentHeight - margins[4] - node.Height
	end

	node.pos = { x, y }
end

-- Only works on node that are not resized // where parentDidResize is not set
-- If you need to define parentDidResize, use setNodePos
ui_blocks.anchorNode = function(_, node, horizontalAnchor, verticalAnchor, margins)
	node.parentDidResize = function()
		ui_blocks:setNodePos(node, horizontalAnchor, verticalAnchor, margins)
	end
	node:parentDidResize()
	return node
end

ui_blocks.createBlock = function(_, config)
	local ui = require("uikit")

	local node = ui:createFrame()

	local subnode
	if config.triptych then
		subnode = ui_blocks:createTriptych(config.triptych)
	elseif config.columns then
		subnode = ui_blocks:createColumns({ nodes = config.columns })
	elseif config.rows then
		subnode = ui_blocks:createRows({ nodes = config.rows })
	elseif config.horizontal then
		subnode = ui_blocks:createHorizontalContainer({ nodes = config.horizontal })
	elseif config.vertical then
		subnode = ui_blocks:createVerticalContainer({ nodes = config.vertical })
	end
	subnode:setParent(node)

	node.parentDidResize = function()
		if config.parentDidResize then
			config.parentDidResize(node)
		end
		node.Width = config.width and config.width(node) or (node.parent and node.parent.Width or Screen.Width)
		node.Height = config.height and config.height(node)
			or (node.parent and node.parent.Height or Screen.Height - Screen.SafeArea.Top)
		node.pos = config.pos and config.pos(node) or { 0, 0 }
	end
	node:parentDidResize()

	return node
end

return ui_blocks
