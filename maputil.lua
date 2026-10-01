local function RemoveEdge(nodes, edgeIndex)
	for _,node in pairs(nodes) do
		local validEdges = node.validedges
		for k = #validEdges,1,-1 do
			if validEdges[k] == edgeIndex then
				table.remove(validEdges,k)
			end
		end
	end
end

function GetClosestNode(x,y)
	local closestdist = math.huge
	local closestnode = nil
	local graph = TheWorld.topology
	for _,node in pairs(graph.nodes) do
		if #node.neighbours > 0 then
			local dx = node.x - x
			local dy = node.y - y
			local distsq = dx*dx + dy*dy
			if distsq < closestdist then
				closestdist = distsq
				closestnode = node
			end
		end
	end
	return closestnode
end

function GetClosestNodeToPlayer()
	local x,y,z = ThePlayer.Transform:GetWorldPosition()
	return GetClosestNode(x,z)
end

function ShowClosestNodeToPlayer()
	local node = GetClosestNodeToPlayer()
	local x = node.x
	local y = node.y
	TheWorld.minimap.MiniMap:ShowArea(x,0,y,15)
end

function cross(o, a, b)
   return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
end


-- @param points An array of [X, Y] coordinates
function convexHull(points)

	table.sort(points, function(a, b)
				return a[1] == b[1] and a[2] < b[2]  or a[1] < b[1]
			end
		)

	local lower = {}
	for i = 1,#points do
		while (#lower >= 2 and cross(lower[#lower - 1], lower[#lower -0], points[i]) <= 0) do
			table.remove(lower)
		end
		table.insert(lower,points[i])
	end

	local upper = {}
	for i = #points,1,-1 do
		while (#upper >= 2 and cross(upper[#upper - 1], upper[#upper - 0], points[i]) <= 0) do
			table.remove(upper)
		end
		table.insert(upper, points[i])
	end

	table.remove(upper)
	table.remove(lower)

	for i=1,#upper do
		table.insert(lower, upper[i])
	end

	return lower
end

function GrabSubGraphAroundNode(node, numnodes)
	local graph = TheWorld.topology
	local selected = {}
	local candidates = {}
	local pool = {}
	table.insert(selected, node)
	pool[node] = true

	for i=1,numnodes-1 do
		-- get all candidate nodes
		for i,v in pairs(node.neighbours) do
			local node1 = graph.nodes[v]
			if not pool[node1] then
				pool[node1]=true
				table.insert(candidates,node1)
			end
		end
		-- pick one of the candidates
		if #candidates > 0 then
			local sel = math.random(1,#candidates)
			local selnode = candidates[sel]
			table.insert(selected, selnode)
			table.remove(candidates, sel)
			node = selnode
		end
	end
	--[[
	for i,node1 in pairs(selected) do
		local x = node1.x
		local y = node1.y
		TheWorld.minimap.MiniMap:ShowArea(x,0,y,15)
	end
	]]
	return selected
end

function PlayerSub(count)
	local node = GetClosestNodeToPlayer()
	local x = node.x
	local y = node.y
	local res = GrabSubGraphAroundNode(node, count or 5)
	local points = {}
	for i,v in pairs(res) do
		table.insert(points, {v.x, v.y})
	end
	local ressorted =  convexHull(points)
	for i=1,#ressorted do
		local p1i = i
		local p2i = (i % #ressorted)+1
		local p1 = ressorted[p1i]
		local p2 = ressorted[p2i]
		local srcx = p1[1]
		local srcy = p1[2]
		local dstx = p2[1]
		local dsty = p2[2]
		local dx = dstx - srcx
		local dy = dsty - srcy
		local len = math.sqrt(dx*dx+dy*dy)
		dx = dx / len
		dy = dy / len
		for pt = 1,len/5 do
			local x = srcx + dx * 5 * pt
			local y = srcy + dy * 5 * pt
			TheWorld.minimap.MiniMap:ShowArea(x,0,y,8)
		end

	end
end

function MapHideAll()
	TheWorld.minimap.MiniMap:ClearRevealedAreas()
end

function DrawWalkableGrid(graph)
	local graph = graph or TheWorld.topology

	local debugdrawmap = CreateEntity("DrawWalkableGrid")
	debugdrawmap.entity:AddTransform()
	debugdrawmap.entity:SetCanSleep(false)
	SetDebugEntity(debugdrawmap)
	local draw = debugdrawmap.entity:AddDebugRender()
	draw:SetZ(0.1)

	for i=#graph.flattenedEdges,1,-1 do
		if graph.flattenedEdges[i] then
			local pi1 = graph.flattenedEdges[i][1]
			local pi2 = graph.flattenedEdges[i][2]
			local p1 = graph.flattenedPoints[pi1]
			local p2 = graph.flattenedPoints[pi2]
			local nodeIndices = graph.edgeToNodes[i]
			assert(#nodeIndices == 2)
			-- edge connecting two cells. See if the connection is traversable
			local nodeIndex1 = nodeIndices[1]
			local nodeIndex2 = nodeIndices[2]
			local node1 = graph.nodes[nodeIndex1]
			local node2 = graph.nodes[nodeIndex2]
			--local startpos = Point(node1.x,0,node1.y)
			--local endpos = Point(node2.x,0,node2.y)
			draw:Line(node1.x, node1.y, node2.x, node2.y, 255,255, 0, 255)
		end
	end
end

function ShowWalkableGrid(graph)
	local graph = graph or TheWorld.topology

	local debugdrawmap = CreateEntity("ShowWalkableGrid")
	debugdrawmap.entity:AddTransform()
	debugdrawmap.entity:SetCanSleep(false)
	SetDebugEntity(debugdrawmap)
	local draw = debugdrawmap.entity:AddDebugRender()
	draw:SetZ(0.1)

	for i=#graph.flattenedEdges,1,-1 do
		if graph.flattenedEdges[i] then
			local pi1 = graph.flattenedEdges[i][1]
			local pi2 = graph.flattenedEdges[i][2]
			local p1 = graph.flattenedPoints[pi1]
			local p2 = graph.flattenedPoints[pi2]
			local nodeIndices = graph.edgeToNodes[i]
			assert(#nodeIndices == 2)
			-- edge connecting two cells. See if the connection is traversable
			local nodeIndex1 = nodeIndices[1]
			local nodeIndex2 = nodeIndices[2]
			local node1 = graph.nodes[nodeIndex1]
			local node2 = graph.nodes[nodeIndex2]
			--local startpos = Point(node1.x,0,node1.y)
			--local endpos = Point(node2.x,0,node2.y)
			--draw:Line(node1.x, node1.y, node2.x, node2.y, 255,255, 0, 255)
			-- visit every 5 units
			local srcx = node1.x
			local srcy = node1.y
			local dstx = node2.x
			local dsty = node2.y
			local dx = dstx - srcx
			local dy = dsty - srcy
			local len = math.sqrt(dx*dx+dy*dy)
			dx = dx / len
			dy = dy / len
			for pt = 1,len/5 do
				local x = srcx + dx * 5 * pt
				local y = srcy + dy * 5 * pt
				TheWorld.minimap.MiniMap:ShowArea(x,0,y,3)
			end
		end
	end
end


function ReconstructTopology(graph)
	local graph = graph or TheWorld.topology


	--[[
	local debugdrawmap = CreateEntity()
	debugdrawmap.entity:AddTransform()
	debugdrawmap.entity:SetCanSleep(false)
	SetDebugEntity(debugdrawmap)
	local draw = debugdrawmap.entity:AddDebugRender()
	draw:SetZ(0.1)
	]]

	print("Reconstructing topology")
	local points = {}
	local flattenedPoints = {}
	print("\t...Sorting points")
	for idx,node in ipairs(graph.nodes) do
		node.verts = {}
		for i =1, #node.poly do
			local pt = node.poly[i]
			local key = tostring(pt[1]).."_"..tostring(pt[2])
			if not points[key] then
				table.insert(flattenedPoints,pt)
				points[key] = {index = #flattenedPoints}
			end
			table.insert(node.verts, points[key].index)
		end
	end


	print("\t...Sorting edges")
	local edges = {}
	local flattenedEdges = {}
	for idx,node in ipairs(graph.nodes) do
		node.validedges = {}
		local v1, v2
		local numverts = #node.poly
		-- get all edges, also the closing edge (#n to 1)
		for i =0, #node.poly-1 do
			v1 = node.verts[((i  ) % numverts) + 1]
			v2 = node.verts[((i+1) % numverts) + 1]
			--[[
			local p1 = node.poly[((i  ) % numverts) + 1]
			local p2 = node.poly[((i+1) % numverts) + 1]
			draw:Line(p1[1], p1[2], p2[1],p2[2], 255,266, 255, 255)
			]]
			if v2 < v1 then
				local temp = v1
				v1 = v2
				v2 = temp
			end
			local key = tostring(v1).."_"..tostring(v2)
			if not edges[key] then
				table.insert(flattenedEdges, {v1,v2})
				edges[key] = {index = #flattenedEdges}
			end
			table.insert(node.validedges, edges[key].index)
		end
		node.verts = nil
	end

	-- now sort the nodes per edge
	print("\t...Connecting nodes")
	local edgeToNodes = {}
	for idx,node in ipairs(graph.nodes) do
		local edges = node.validedges
		for i,v in pairs(edges) do
			if not edgeToNodes[v] then
				edgeToNodes[v] = {idx}
			else
				table.insert(edgeToNodes[v],idx)
			end
		end
	end

	-- Find out which node connections are actually valid, remove the ones that aren`t
	print("\t...Validating connections")
    local validcaps = {ignorewalls = true, ignorecreep = true}
    local function IsPathClearBetweenNodes(node1, node2, p1, p2)
        -- NOTES(JBK): We want to detect that there is land between two nodes so that it is always traversable.
        -- The old algorithm was a line check between node origins which for Voronoi generations is not a valid check for all configurations.
        -- So we will walk along the node edge and cast two clear rays from the node origins to this interpolated point and if that is clear the two nodes are traversable.
        local distmod = math.ceil(math.sqrt(distsq(p1[1], p1[2], p2[1], p2[2])) / TILE_SCALE)
        for j = 0, distmod - 1 do
            local t = j / distmod
            local x = Lerp(p1[1], p2[1], t)
            local z = Lerp(p1[2], p2[2], t)
            if TheWorld.Pathfinder:IsClear(node1.x, 0, node1.y, x, 0, z, validcaps) and TheWorld.Pathfinder:IsClear(node2.x, 0, node2.y, x, 0, z, validcaps) then
                return true
            end
        end
        return false
    end
	for i=#flattenedEdges,1,-1 do
		local pi1 = flattenedEdges[i][1]
		local pi2 = flattenedEdges[i][2]
		local p1 = flattenedPoints[pi1]
		local p2 = flattenedPoints[pi2]
		local nodeIndices = edgeToNodes[i]
		if #nodeIndices == 1 then
			-- This edge doesn't border 2 areas, who cares
			RemoveEdge(graph.nodes, i)
			-- and clear out this edge from the supporting structures
			edgeToNodes[i] = false
			flattenedEdges[i] = false

		elseif #nodeIndices == 2 then
			-- edge connecting two cells. See if the connection is traversable. If not, remove it
			local nodeIndex1 = nodeIndices[1]
			local nodeIndex2 = nodeIndices[2]
			local node1 = graph.nodes[nodeIndex1]
			local node2 = graph.nodes[nodeIndex2]
			if not IsPathClearBetweenNodes(node1, node2, p1, p2) then
				-- remove this index from all nodes
				RemoveEdge(graph.nodes, i)
				-- and clear out this edge from the supporting structures
				edgeToNodes[i] = false
				flattenedEdges[i] = false
				--draw:Line(node1.x, node1.y, node2.x, node2.y, 255,0, 0, 255)
			else
				--draw:Line(node1.x, node1.y, node2.x, node2.y, 255,255, 0, 255)
			end
		else 	-- #nodeIndices > 3
			-- Seems this was a triangle that was collapsed to a single point - again, who cares
			-- remove this index from all nodes
			RemoveEdge(graph.nodes, i)
			-- and clear out this edge from the supporting structures
			edgeToNodes[i] = false
			flattenedEdges[i] = false
		end
	end
	-- store the node's neighbours on the node
	print("\t...Housekeeping")
	for _,node in pairs(graph.nodes) do
		local knownnodes = {}
		for _,edge in ipairs(node.validedges) do
			local edgenodes = edgeToNodes[edge]
			if edgenodes then
				local node1Index = edgenodes[1]
				local node2Index = edgenodes[2]
				local node1 = graph.nodes[node1Index]
				local node2 = graph.nodes[node2Index]
				if node1 == node then
					knownnodes[node2Index] = true
				else
					knownnodes[node1Index] = true
				end

			end
		end
		node.neighbours = {}
		for nodeIndex,_ in pairs(knownnodes) do
			table.insert(node.neighbours, nodeIndex)
		end
	end
	print("\t...Done!")
	graph.edgeToNodes = edgeToNodes
	graph.flattenedEdges = flattenedEdges
	graph.flattenedPoints = flattenedPoints
end


StaticLayoutPlacer = nil -- Predeclare.
local function AddTopologyData(topology, left, top, width, height, room_id, tags)
    local index = #topology.ids + 1
    topology.ids[index] = room_id
    topology.story_depths[index] = 0

    local node = {}
    node.area = width * height
    node.c = 1 -- colour index
    node.cent = {left + (width / 2), top + (height / 2)}
    node.neighbours = {}
    node.poly = { {left, top},
                  {left + width, top},
                  {left + width, top + height},
                  {left, top + height}
                }
    node.tags  = tags
    node.type = NODE_TYPE.Default
    node.x = node.cent[1]
    node.y = node.cent[2]

    node.validedges = {}

    topology.nodes[index] = node

    return index
end
local function AddTileNodeIdsForArea(node_index, left, top, width, height)
    local map = TheWorld.Map
    for x = left, left + width do
        for y = top, top + height do
            map:SetTileNodeId(x, y, node_index)
        end
    end
end
local function TileFilter_Impassable(tileid)
    return TileGroupManager:IsImpassableTile(tileid)
end
local function ScanForStaticLayoutPosition_Spiral(tx, ty, size, displacement, filterfn)
    local map = TheWorld.Map
    local map_width, map_height = map:GetSize()
    map_width = map_width - size
    map_height = map_height - size

    local dx, dy = 1, 0
    local step = 1

    local tries = math.floor(10000 / displacement)
    while true do
        for j = 1, 2 do
            for i = 1, step do
                if tx > 0 and tx < map_width and ty > 0 and ty < map_height then
                    if map:IsAreaTilesFiltered(tx, ty, size, size, filterfn) then
                        return tx, ty
                    end
                end
                tries = tries - 1
                if tries < 0 then
                    return
                end

                tx = tx + dx * displacement
                ty = ty + dy * displacement
            end
            dx, dy = -dy, dx
        end
        step = step + 1
    end
end
local function SpawnLayout_AddFn(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
    local x = (points_x[current_pos_idx] - width/2.0)  * TILE_SCALE
    local y = (points_y[current_pos_idx] - height/2.0) * TILE_SCALE

    x = math.floor(x*100) / 100.0
    y = math.floor(y*100) / 100.0

    prefab_data.x = x
    prefab_data.z = y

    prefab_data.prefab = prefab

    local ent = SpawnSaveRecord(prefab_data)

    ent:LoadPostPass(Ents, FunctionOrValue(prefab_data.data))

    if ent.components.scenariorunner ~= nil then
        ent.components.scenariorunner:Run()
    end
end
local function TryToPlaceStaticLayoutNear(layout, tx, ty, scanmethodfn, scanfilterfn)
    local obj_layout = require("map/object_layout")
    local map = TheWorld.Map
    local topology = TheWorld.topology
    for padding = 6, 2, -1 do
        local offset = math.floor(padding / 2)
        local size = #layout.ground + padding
        for displacement = math.floor(size / 2), 1, -1 do
            local tx2, ty2 = scanmethodfn(tx, ty, size, displacement, scanfilterfn)
            if tx2 then
                local map_width, map_height = map:GetSize()
                local add_fn = {
                    fn = StaticLayoutPlacer.SpawnLayout_AddFn,
                    args = {entitiesOut={}, width=map_width, height=map_height, rand_offset=false}
                }
                obj_layout.Place({tx2 + offset, ty2 + offset}, layout.name, add_fn, nil, map)
                local tags, nodename
                if layout.add_topology then
                    tags = layout.add_topology.tags
                    nodename = layout.add_topology.room_id
                end
                tags = tags or {}
                nodename = nodename or ("GenericStatic:" .. layout.name)
                local topology_node_index = StaticLayoutPlacer.AddTopologyData(topology, tx2*TILE_SCALE - (map_width * 0.5 * TILE_SCALE), ty2*TILE_SCALE - (map_height * 0.5 * TILE_SCALE), size*TILE_SCALE, size*TILE_SCALE, nodename, tags)
                StaticLayoutPlacer.AddTileNodeIdsForArea(topology_node_index, tx2, ty2, size, size)
                return true
            end
        end
    end
    return false
end
StaticLayoutPlacer = {
    -- Helper functions
    AddTopologyData = AddTopologyData,
    AddTileNodeIdsForArea = AddTileNodeIdsForArea,
    SpawnLayout_AddFn = SpawnLayout_AddFn,

    -- scanmethodfn premade functions
    ScanForStaticLayoutPosition_Spiral = ScanForStaticLayoutPosition_Spiral,

    -- scanfilterfn premade functions
    TileFilter_Impassable = TileFilter_Impassable,

    -- The placer
    TryToPlaceStaticLayoutNear = TryToPlaceStaticLayoutNear,
}

