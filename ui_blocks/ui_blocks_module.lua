local ui_blocks = {}

ui_blocks.createTriptych = function(_, config)
	local ui = require("uikit")

	local node = ui:createFrame(config.color)

	local dir = config.dir or "horizontal"

	local left = config.left or config.top
	local center = config.center
	local right = config.right or config.bottom

	local elems = {}
	if left then
		left.node:setParent(node)
		table.insert(elems, left)
	end
	if center then
		center.node:setParent(node)
		table.insert(elems, center)
	end
	if right then
		right.node:setParent(node)
		table.insert(elems, right)
	end

	node.parentDidResize = function()
		if not node.parent then
			return
		end
		node.Width = node.parent.Width
		node.Height = node.parent.Height

		if center then
			center.node.pos =
				{ node.Width * 0.5 - center.node.Width * 0.5, node.Height * 0.5 - center.node.Height * 0.5 }
		end

		if dir == "horizontal" then
			if left then
				left.node.pos = { 0, node.Height * 0.5 - left.node.Height * 0.5 }
			end
			if right then
				right.node.pos = { node.Width - right.node.Width, node.Height * 0.5 - right.node.Height * 0.5 }
			end
		end
		if dir == "vertical" then
			if left then
				left.node.pos = { node.Width * 0.5 - left.node.Width * 0.5, node.Height - left.node.Height }
			end
			if right then
				right.node.pos = { node.Width * 0.5 - right.node.Width * 0.5, 0 }
			end
		end
	end

	return node, elems
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
		local column = ui:createFrame(Color(math.random(), math.random(), math.random()))
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

ui_blocks.createLineContainer = function(_, config)
	local uiContainer = require("ui_container")
	local ui = require("uikit")

	local node
	if config.dir == "vertical" then
		node = uiContainer:createVerticalContainer()
	else
		node = uiContainer:createHorizontalContainer()
	end

	local elems = {}

	for _, info in ipairs(config.nodes) do
		if info.type == "separator" then
			node:pushSeparator()
		elseif info.type == "gap" then
			node:pushGap()
		elseif info.type == "button" then
			local btn = ui:createButton(info.text)
			if info.color then
				btn:setColor(info.color)
			end
			btn.onRelease = function()
				if info.callback then
					info.callback()
				end
			end
			node:pushElement(btn)
			if info.key then
				elems[info.key] = btn
			end
		elseif info.type == "node" then
			node:pushElement(info.node)
			if info.key then
				elems[info.key] = info.node
			end
		else
			node:pushElement(info)
		end
	end

	return node, elems
end
ui_blocks.anchorNode = function(_, node, horizontalAnchor, verticalAnchor, margins)
	margins = margins or 0
	if type(margins) ~= "table" then
		-- left, bottom, right, top
		margins = { margins, margins, margins, margins }
	end
	node.parentDidResize = function()
		local x = 0
		local y = 0

		if horizontalAnchor == "left" then
			x = margins[3]
		elseif horizontalAnchor == "center" then
			x = node.parent.Width * 0.5 - node.Width * 0.5
		elseif horizontalAnchor == "right" then
			x = node.parent.Width - margins[1] - node.Width
		end

		if verticalAnchor == "bottom" then
			x = margins[2]
		elseif verticalAnchor == "center" then
			x = node.parent.Height * 0.5 - node.Height * 0.5
		elseif verticalAnchor == "top" then
			x = node.parent.Height - margins[4] - node.Height
		end

		node.pos = { x, y }
	end

	return node
end

ui_blocks.createBlock = function(_, config)
	local ui = require("uikit")

	local node = ui:createFrame()

	local elems = {}

	local subnode
	local subElems
	if config.triptych then
		subnode, subElems = ui_blocks:createTriptych(config.triptych)
	elseif config.columns then
		subnode = ui_blocks:createColumns({ nodes = config.columns })
	elseif config.horizontal then
		subnode, subElems = ui_blocks:createHorizontalContainer({ nodes = config.horizontal })
	elseif config.vertical then
		subnode, subElems = ui_blocks:createVerticalContainer({ nodes = config.vertical })
	end
	subnode:setParent(node)

	if subElems then
		for _, v in ipairs(subElems) do
			if v.key then
				elems[v.key] = v.node
			end
		end
	end

	if config.postload then
		config.postload(node, elems)
	end

	node.parentDidResize = function()
		node.Width = config.width and config.width(node, elems) or (node.parent and node.parent.Width or 0)
		node.Height = config.height and config.height(node, elems) or (node.parent and node.parent.Height or 0)
		node.pos = config.pos and config.pos(node) or { 0, 0 }
	end

	return node, elems
end

return ui_blocks
