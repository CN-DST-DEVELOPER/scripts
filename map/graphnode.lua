require "class"
require "map/terrain"
require "mathutil"

local PrefabSwaps = require("prefabswaps")

-- Save characters in the save file
local DENSITY_PRECISION = 1/10000

local function getFilteredSpawnWeight(list,weight,prefab)
	local total = 0

	for i,weightList in pairs(list)do
		if type(weightList) == "table" then
			total = total + weightList.weight
		else
			local add = true

			for cat,catdata in pairs(PrefabSwaps.GetBasePrefabSwaps())do
				for swap,swapData in ipairs(catdata)do
					if swapData.primary and prefab == i then
						add = false -- remove it if the prefab is a primary, will be added in later
					end
					if add then
						for p,prefab2 in ipairs(swapData.prefabs)do
							if not swapData.primary and i == prefab2 then
								add = false -- remove all alternate prefabs, only keep the primaries.
							end
						end
					end
				end
			end
			if add then
				--print(total ,"+",weightList,"=", total + weightList,i)
				total = total + weightList
			end
		end
	end

	total = total + weight -- add the prefabs weight to the total at the end.

	--print("final weight",weight / total)
	return  weight / total --getPercentFromWeigth(list,weight)
end

local function recurseTable(dataTable, removed, fn)
	local deleteList = {}
	local addList = {}

	for k,v in pairs(dataTable)do
		if type(v) == "table" then
			v = recurseTable(v, fn)
		else
			local add, delete = fn(k, fn)
			if add then
				table.insert(addList,{prefab=add,weight=v})
			end
			if delete then
				table.insert(deleteList,k)
			end

			if not add and delete then
				removed[k] = v
			end
		end
	end

	for k,v in ipairs(deleteList)do
		--print("REMOVING PREFAB",v)
		dataTable[v] = nil
	end

	-- this isn't really adding a prefab, it's replacing one that may have just been removed with it's actual name. eg: ground_sticks
	for k,v in ipairs(addList)do
		--print("ADDING PREFAB",v.prefab)
		dataTable[v.prefab] = v.weight
	end

	return dataTable,removed
end

local function filterPrefabsForGlobalSwaps(params, removed)

	--REMOVE PREFABS NOT USED IN THIS WORLD
	local function removeUnusedPrefabs(testData, fn)
        return false, PrefabSwaps.IsPrefabInactive(testData)
	end

	--CHANGE MARKED UP PREFABS TO THEIR ACTUAL PREFAB NAME
	local function swapToActualPrefabs(testData, fn)
        local prefab = PrefabSwaps.ResolvePrefabProxy(testData)
        if prefab ~= testData then
            return prefab, true
        end
        return false, false
	end

	if type(params) == "table" then
		params,removed = recurseTable(params, removed, removeUnusedPrefabs)
		params,removed = recurseTable(params, removed, swapToActualPrefabs)
	end

	return params, removed
end


Node = Class(function(self, id, data)
	self.id = id
	self.graph = nil
	self.delta_graph = nil

    -- Graph properties
    self.edges = {}

    -- Data
    self.data = data

    -- Search
    self.visited = false

    self.colour = data.colour or {r=255,g=255,b=0,a=55}


    self.ents = nil
    self.populateFn = nil
    self.tileFn = nil
    self.populated = false
    self.children_populated = false


    if self.data.custom_tiles ~= nil then
 		self:SetTilesFunction(self.data.custom_tiles)
    	self.data.custom_tiles = nil
    end
    if self.data.custom_objects ~= nil then
 		self:SetPopulateFunction(self.data.custom_objects)
    	self.data.custom_objects = nil
    end

end)

function Node:SaveEncode(map)

	local pos_x, pos_y = WorldSim:GetSite(self.id)
	local c_x, c_y = WorldSim:GetSiteCentroid(self.id)
	c_x = math.floor((c_x-map.width/2.0)*TILE_SCALE*100)/100.0
	c_y = math.floor((c_y-map.height/2.0)*TILE_SCALE*100)/100.0

	local poly_x, poly_y = WorldSim:GetSitePolygon(self.id)
	local poly_def = {}
	for current_pos_idx = 1, #poly_x  do
		poly_def[current_pos_idx] = {math.floor((poly_x[current_pos_idx]-map.width/2.0)*TILE_SCALE), math.floor((poly_y[current_pos_idx]-map.height/2.0)*TILE_SCALE)}
		current_pos_idx = current_pos_idx + 1
	end
	return {
				x = math.floor((pos_x-map.width/2.0)*TILE_SCALE),
				y = math.floor((pos_y-map.height/2.0)*TILE_SCALE),
				cent = {c_x, c_y},
				poly = poly_def,
				type = self.data.type,
				c = self.colour,
				area = WorldSim:GetSiteArea(self.id),
                tags = self.data.tags,
            }

end

function Node:SetPosition(position)
	self.data.position = position
end

function Node:GetPosition()
	return self.data.position
end

function Node:IsConnectedTo(node)
	assert(node)

	for k,edge in pairs(self.edges) do
		if edge.node1 == node or edge.node2 == node then
			return true
		end
	end

	return false
end

function PopulateWorld_AddEntity(prefab, tile_x, tile_y, tile_value, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
	if _G.WorldSim ~= nil then
		WorldSim:ReserveTile(tile_x, tile_y)
	end

	local x = (tile_x - width/2.0)*TILE_SCALE
	local y = (tile_y - height/2.0)*TILE_SCALE

	if rand_offset == nil or rand_offset == true then
		x = x + math.random()*2-1
		y = y + math.random()*2-1
	end

	x = math.floor(x*100)/100.0
	y = math.floor(y*100)/100.0

	if entitiesOut[prefab] == nil then
		entitiesOut[prefab] = {}
	end

	local save_data = {x=x, z=y}
	if prefab_data then

		if prefab_data.data then
			if type(prefab_data.data) == "function" then
				save_data["data"] = prefab_data.data()
			else
				save_data["data"] = prefab_data.data
			end
		end
		if prefab_data.id then
			save_data["id"] = prefab_data.id
		end
		if prefab_data.scenario then
			save_data["scenario"] = prefab_data.scenario
		end
        if prefab_data.skinname then
            save_data["skinname"] = prefab_data.skinname
        end
	end
	table.insert(entitiesOut[prefab], save_data)

	if prefab_list[prefab] == nil then
		prefab_list[prefab] = 0
	end
	prefab_list[prefab] = prefab_list[prefab] + 1

end


function Node:AddEntity(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
	local tile = WorldSim:GetTile(points_x[current_pos_idx], points_y[current_pos_idx])
	if not TileGroupManager:IsLandTile(tile) then
		return
	end

	PopulateWorld_AddEntity(prefab, points_x[current_pos_idx], points_y[current_pos_idx], tile, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
end

function Node:ConvertGround(spawnFn, entitiesOut, width, height, world_gen_choices)
	if not self.data.terrain_contents then
		return
	end
	local obj_layout = require("map/object_layout")
	local prefab_list = {}

	local area = WorldSim:GetSiteArea(self.id)

	-- Get the list of special items for this node
	local add_fn = {fn=function(...) self:AddEntity(...) end,args={entitiesOut=entitiesOut, width=width, height=height, rand_offset = false, debug_prefab_list=prefab_list}}

	local scratchpad = {} -- shared data between all entries in countstaticlayouts. This is not shared with countprefabs.
	if self.data.terrain_contents.countstaticlayouts ~= nil then
		for k,count in pairs(self.data.terrain_contents.countstaticlayouts) do
            --print("STATIC LAYOUTS: adding a "..k.." to "..self.id)
			if type(count) == "function" then
				count = count(area, k, scratchpad)
			end

			for i=1, count do
				obj_layout.Convert(self.id, k, add_fn)
			end
		end
	end

	if self.data.terrain_contents_extra and self.data.terrain_contents_extra.static_layouts then
		for i,layout in pairs(self.data.terrain_contents_extra.static_layouts) do
			obj_layout.Convert(self.id, layout, add_fn)
		end
	end

end

function Node:SetPopulateFunction(custom_objects_data)
	self.custom_objects_data = custom_objects_data
	self.populated = false
	-- Set tag to run here
end

function Node:SetTilesFunction(custom_tiles_data)
	self.custom_tiles_data = custom_tiles_data
	-- Set tag to run here
end

function Node:PopulateViaFunction()
	if self.custom_objects_data == nil then
		return
	end

	--print(self.id.." SetTilesViaFunction() Populate function running...")
	data.node = self
	self.custom_objects_data.GeneratorFunction(self.id, self.custom_objects_data.data)

	self.populated = true
end

function Node:SetTilesViaFunction(entities, width, height)
	if self.custom_tiles_data == nil then
		return
	end

	self.custom_tiles_data.data.node = self
	self.custom_tiles_data.data.width = width
	self.custom_tiles_data.data.height = height
	self.custom_tiles_data.GeneratorFunction(self.id, entities, self.custom_tiles_data.data)
	self.populated = true
end

local function resolveswappableprefabs(table)
	local tbl = {}

	for k,v in pairs(table) do
		if type(v) == "table" then
			local choice = GetRandomItem(v.prefabs)
			tbl[choice] = v.weight
		else
			tbl[k] = v
		end
	end
	return tbl
end

function Node:PopulateVoronoi(spawnFn, entitiesOut, width, height, world_gen_choices, prefabDensities)
	if self.populated == true then
		--table.insert(entitiesOut[prefab], save_data)
		return
	end

	if TileGroupManager:IsImpassableTile(self.data.value) then
		return
	end

	if not self.data.terrain_contents or (self.data.terrain_contents.countprefabs == nil and self.data.terrain_contents.distributeprefabs == nil) then
		return
	end

	local prefab_list = {}
	local generate_these = {}
	local pos_needed = 0

	local points_x, points_y, points_type = WorldSim:GetPointsForSite(self.id)
	if #points_x == 0 then
		print(self.id.." Cant process points")
		return
	end
	local current_pos_idx = 1

	--print("Number of points returned: " .. tostring(#points_x) .. " for site " .. self.id)

	local area = #points_x

	local scratchpad = {} -- shared data between all entries in countprefabs. This is not shared with countstaticlayouts.
	if self.data.terrain_contents.countprefabs ~= nil then
		for prefab, count in pairs(self.data.terrain_contents.countprefabs) do
			if type(count) == "function" then
				count = count(area, prefab, scratchpad)
			end
			generate_these[prefab] = count
			pos_needed = pos_needed + count
		end

		if #points_x < math.floor(pos_needed) then
			print(self.id.." Didnt get enough points for all prefabs, got "..#points_x .." need ".. pos_needed)
			return
		end

		if self.data.terrain_contents.countprefabs_uses_filters then
			local cur_pt = #points_x

			while next(generate_these) ~= nil do
				local prefab = spawnFn.pickspawncountprefabforground(generate_these, points_type[cur_pt])
				if prefab ~= nil then
					local prefab_data = {}
					prefab_data.data = self.data.terrain_contents.prefabdata and self.data.terrain_contents.prefabdata[prefab] or nil
					self:AddEntity(prefab, points_x, points_y, cur_pt, entitiesOut, width, height, prefab_list, prefab_data)

					generate_these[prefab] = generate_these[prefab] - 1
					if generate_these[prefab] == 0 then
						generate_these[prefab] = nil
					end

					table.remove(points_x, cur_pt)
					table.remove(points_y, cur_pt)
					table.remove(points_type, cur_pt)
					if #points_x == 0 then
						print(self.id.." countprefabs used all the points")
						return
					end
				end
				cur_pt = cur_pt - 1
				if cur_pt <= 0 then
					break
				end
			end

			for p, c in pairs(generate_these) do
				print ("Warning: CountPrefabs could not be placed : " .. c .. " " .. p .. " in site " .. self.id)
			end
		else
			for prefab, count in pairs(generate_these) do
				for id = 1, count do
					if current_pos_idx > #points_x then
						break
					end

					local prefab_data = {}
					prefab_data.data = self.data.terrain_contents.prefabdata and self.data.terrain_contents.prefabdata[prefab] or nil
					self:AddEntity(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data)

					--print("Creating count:", current_pos_idx, self.id, prefab)

					current_pos_idx = current_pos_idx + 1
				end
				if current_pos_idx > #points_x then
					print(self.id.." Didnt get enough points for all counted prefabs, bailed at "..current_pos_idx )
					return
				end
			end
		end
	end

	-- Loop through the tags and add any items they generate
	if self.data.terrain_contents_extra and self.data.terrain_contents_extra.prefabs and #self.data.terrain_contents_extra.prefabs > 0 then
		for i, prefab in ipairs(self.data.terrain_contents_extra.prefabs) do
			local prefabname, data = prefab, nil
			if type(prefab) == "table" then
				assert(#prefab == 2, "Data prefabs must have a name and data.")
				prefabname = prefab[1]
				data = prefab[2]
			end
			self:AddEntity(prefabname, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, data)
			current_pos_idx = current_pos_idx + 1
			if current_pos_idx > #points_x then
				print(self.id.." Didnt get enough points for all extra contents, bailed at "..current_pos_idx )
				return
			end
		end
	end

	local removed = {}

	if self.data.terrain_contents.distributepercent and self.data.terrain_contents.distributeprefabs then

		local idx_left = {}

		local distributeprefabs = resolveswappableprefabs(self.data.terrain_contents.distributeprefabs)

		distributeprefabs, removed = filterPrefabsForGlobalSwaps(distributeprefabs, removed)

		for current_pos_idx = current_pos_idx, #points_x  do
			if math.random() < self.data.terrain_contents.distributepercent then
				local prefab = spawnFn.pickspawnprefab(distributeprefabs, points_type[current_pos_idx])
				if prefab ~= nil then
					local prefab_data = {}
					prefab_data.data = self.data.terrain_contents.prefabdata and self.data.terrain_contents.prefabdata[prefab] or nil
					self:AddEntity(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data)
				else
					table.insert(idx_left, current_pos_idx)
					--print(self.id.." prefab nil for "..current_pos_idx.. " type "..points_type[current_pos_idx])
				end
			else
			--print(self.id.."-",current_pos_idx.. " type "..points_type[current_pos_idx])
				table.insert(idx_left, current_pos_idx)
			end
		end
		-- converts the removed prefabs to a percent of the distrubute percents
		for prefab,v in pairs(removed)do
		--	print(self.id,prefab,"percent of weight:",getFilteredSpawnWeight(self.data.terrain_contents.distributeprefabs,v,prefab),"distribute percent:", self.data.terrain_contents.distributepercent)
			removed[prefab] = getFilteredSpawnWeight(self.data.terrain_contents.distributeprefabs,v,prefab) *  self.data.terrain_contents.distributepercent
		end

		self:PopulateExtra(world_gen_choices, spawnFn, {points_type=points_type, points_x=points_x, points_y=points_y, idx_left=idx_left, entitiesOut=entitiesOut, width=width, height=height, prefab_list=prefab_list})
	end

 	prefabDensities[self.id] ={}
 	if self.data.terrain_contents.distributepercent then
		for prefab,v in pairs(prefab_list) do
			-- convererts from actual numbers to a percentage of the distribute percent
			prefabDensities[self.id][prefab] = v/#points_x

		end
	end
	-- merges the items removed due to prefab swaps back into the list
	for prefab,v in pairs(removed)do
		prefabDensities[self.id][prefab] = v
	end

end


function Node:PopulateChildren(spawnFn, entitiesOut, width, height, backgroundRoom, perTerrain, world_gen_choices, prefabDensities)
	-- Fill in any background sites that we have generated

	if self.children_populated == true then
		return
	end
	self.children_populated = true

	local children = WorldSim:GetChildrenForSite(self.id)

	--if not perTerrain then
		--print("Background room:", backgroundRoom)
		--dumptable(backgroundRoom, 1)
		--print("\tContents")
		--dumptable(backgroundRoom.contents,2)
	--else
		--print("Background rooms:", backgroundRoom)
		--dumptable(backgroundRoom, 1)
	--end

	if children ~= nil then

		for i,id in ipairs(children) do

            local prefab_list = {}

			local points_x, points_y, points_type = WorldSim:GetPointsForSite(id) -- minus the sites that have been taken
			if points_x == nil then
				print(self.id.." Cant process points")
				return
			end

			-- need to stash this incase we are on a multi-terrain ground
			local room = backgroundRoom

			local idx_left = {}

			for current_pos_idx = 1, #points_x do
				if perTerrain then -- For use in biomes with mixed tile types (caves mostly)
					room = backgroundRoom[points_type[current_pos_idx]]
				end

				if room.contents.distributepercent and math.random() < room.contents.distributepercent then
					local prefab = spawnFn.pickspawnprefab(room.contents.distributeprefabs, points_type[current_pos_idx])
					if prefab ~= nil then
						local prefab_data = {}
						prefab_data.data = room.contents.prefabdata and backgroundRoom.contents.prefabdata[prefab] or nil
						self:AddEntity(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data)
					else
						--print(self.id.." prefab nil for "..current_pos_idx.. " type "..points_type[current_pos_idx])
						table.insert(idx_left, current_pos_idx)
					end
				else
					--print(self.id.."-",current_pos_idx.. " type "..points_type[current_pos_idx])
					table.insert(idx_left, current_pos_idx)
				end
			end

			self:PopulateExtra(world_gen_choices, spawnFn, {points_type=points_type, points_x=points_x, points_y=points_y, idx_left=idx_left, entitiesOut=entitiesOut, width=width, height=height, prefab_list=prefab_list})

            prefabDensities[self.id] ={}
            for k,v in pairs(prefab_list) do
                prefabDensities[self.id][k] = RoundToNearest(v / #points_x, DENSITY_PRECISION)
            end
		end
	end

end

function Node:PopulateExtra(world_gen_choices, spawnFn, data)
	-- We have a bunch of unused positions that we can use.
	-- loop through anything > 'default' (ie 1)
	-- add in % more
	--print("world_gen_choices...", world_gen_choices, #idx_left)
	if world_gen_choices ~= nil and #data.idx_left >0 then

		local amount_to_generate = {}
		for prefab,amt in pairs(world_gen_choices) do
			if not PrefabSwaps.IsPrefabInactive(prefab) then
				if type(amt) == "number" then
					if data.prefab_list[prefab] then
						amount_to_generate[prefab] = math.floor(data.prefab_list[prefab]*amt) - data.prefab_list[prefab]
					end
				else
					if amt.clumpcount > 0 and 0.25 > math.random() then
						amt.clumpcount = amt.clumpcount - 1
						amount_to_generate[prefab] = math.random(amt.clumpsize[1], amt.clumpsize[2])
					end
				end
			end
		end

		for idx = 1, #data.idx_left do

			-- Choose random prefab
			local prefab = spawnFn.pickspawnprefab(amount_to_generate, data.points_type[data.idx_left[idx]])

			if prefab ~= nil then
				local prefab_data = {}
				prefab_data.data = (self.data.terrain_contents and self.data.terrain_contents.prefabdata and self.data.terrain_contents.prefabdata[prefab]) or nil
				self:AddEntity(prefab, data.points_x, data.points_y, data.idx_left[idx], data.entitiesOut, data.width, data.height, data.prefab_list, prefab_data)

				amount_to_generate[prefab] = amount_to_generate[prefab] - 1

				-- Remove any complete items from the list
				if amount_to_generate[prefab] <= 0 then
					--print("Generated enough",prefab)
					amount_to_generate[prefab] = nil
				end
			end
		end
	end
end
