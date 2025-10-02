local defs = require("prefabs/vaultroom_defs")

local SAVE_RADIUS = 28
local SAVE_NO_TAGS = { "INLIMBO" }
local SAVE_CONTAINER_TAGS = { "_inventory", "_container" }

local VaultRoom = Class(function(self, inst)
	self.inst = inst
	self.roomid = nil
end)

function VaultRoom:GetCurrentRoomId()
	return self.roomid
end

function VaultRoom:LayoutNewRoom(id)
	assert(self.roomid == nil)
	local def = defs[id]
	if def == nil then
		assert(false)
		return
	end

	self.roomid = id

	local x, _, z = self.inst.Transform:GetWorldPosition()
	if def.TerraformRoomAtXZ then
		def.TerraformRoomAtXZ(self.inst, x, z)
	else
		defs.ResetTerraformRoomAtXZ(self.inst, x, z)
	end
	if def.LayoutNewRoomAtXZ then
		POPULATING = true --@V2C: hope this is safe XD
		def.LayoutNewRoomAtXZ(self.inst, x, z)
		POPULATING = false
	end
end

local function _inroom(ent, map, tile_x, tile_y)
	local x1, _, z1 = ent.Transform:GetWorldPosition()
	local tx, ty = map:GetTileCoordsAtPoint(x1, 0, z1)
	if math.abs(tx - tile_x) <= 5 and math.abs(ty - tile_y) <= 5 then
		return true
	end
	local tile = map:GetTile(tx, ty)
	return tile == WORLD_TILES.VAULT
		or (tile == WORLD_TILES.IMPASSABLE and map:IsVisualGroundAtPoint(x1, 0, z1))
end

local _SKIP = 1
local _SAVE = 2
local _KEEP = 3
local function _getunloadaction(ent, map, tile_x, tile_y)
	if not ent:IsValid() or ent.entity:GetParent() or ent:HasTag("staysthroughvirtualrooms") then
		return _SKIP
	end

	local owner = ent
	while true do
		local nextowner =
			(owner.components.spell and owner.components.spell.target) or
			(owner.components.formationleader and owner.components.formationleader.target) or
			(owner.components.follower and owner.components.follower:GetLeader()) or
			(owner.components.inventoryitem and owner.components.inventoryitem.owner)
		--NOTE: inventoryitem.owner check only applies after we've found spell target
		--      or leader, since we already did a GetParent() check on ourself above.

		if nextowner and nextowner:IsValid() then
			owner = nextowner
		else
			break
		end
	end

	if owner ~= ent and owner.entity:GetParent() or not _inroom(owner, map, tile_x, tile_y) then
		return _SKIP
	elseif owner.isplayer or owner:HasTag("irreplaceable") then
		return _KEEP
	end
	return _SAVE
end

function VaultRoom:UnloadRoom(save)
	--assert(self.roomid ~= nil)
	local def = defs[self.roomid]
	if def == nil then
		--assert(false)
		return
	end

	self.roomid = nil

	local x, _, z = self.inst.Transform:GetWorldPosition()
	local map = TheWorld.Map
	local tile_x, tile_y = map:GetTileCoordsAtPoint(x, 0, z)

	local recbyguid, refs, toremove
	if save then
		save = { ents = {} }
		recbyguid = {}
		refs = {}
		toremove = {}
	end

	for i, v in ipairs(TheSim:FindEntities(x, 0, z, SAVE_RADIUS, nil, SAVE_NO_TAGS, SAVE_CONTAINER_TAGS)) do
		if _getunloadaction(v, map, tile_x, tile_y) == _SAVE then
			local container = v.components.inventory or v.components.container
			if container then
				container:DropEverythingWithTag("irreplaceable")
			end
		end
	end

	POPULATING = true --@V2C: hope this is safe XD

	local ents = TheSim:FindEntities(x, 0, z, SAVE_RADIUS, nil, SAVE_NO_TAGS)
	local keepidx = 0
	for i = 1, #ents do
		local v = ents[i]
		ents[i] = nil

		local unloadaction = _getunloadaction(v, map, tile_x, tile_y)
		if unloadaction == _SKIP then
			--Do nothing.
		elseif unloadaction == _SAVE then
			if save then
				table.insert(toremove, v) --defer removal so we can save references
				if v.persists and v.prefab --[[and v.Transform and v.entity:GetParent() == nil redundant checks]] then
					local record, new_refs = v:GetSaveRecord()
					record.prefab = nil

					if new_refs then
						refs[v.GUID] = v
						for _, guid in pairs(new_refs) do
							refs[guid] = v
						end
					end

					recbyguid[v.GUID] = record

					if save.ents[v.prefab] == nil then
						save.ents[v.prefab] = {}
					end
					table.insert(save.ents[v.prefab], record)
				end
			else
				v:Remove()
			end
		else--if unloadaction == _KEEP then
			--Don't remove entities that aren't saved by the room
			keepidx = keepidx + 1
			ents[keepidx] = v
		end
	end

	if refs then
		for guid, v in pairs(refs) do
			local record = recbyguid[guid]
			if record then
				record.id = guid
			else
				print("Missing reference:", v, "->", guid, Ents[guid])
			end
		end
	end

	if toremove then
		for i, v in ipairs(toremove) do
			v:Remove()
		end
	end

	POPULATING = false

	if save and next(save.ents) then
		save.world_time = math.floor((TheWorld.state.cycles + TheWorld.state.time) * 100 + 0.5) * 0.01
	else
		save = nil
	end

	return save, ents --remaining entities that weren't saved/removed
end

function VaultRoom:ResetRoom()
	if self.roomid then
		self:UnloadRoom()
	end
	local x, _, z = self.inst.Transform:GetWorldPosition()
	defs.ResetTerraformRoomAtXZ(self.inst, x, z)
end

function VaultRoom:LoadRoom(id, data)
	if data == nil then
		self:LayoutNewRoom(id)
		return
	end

	assert(self.roomid == nil)
	local def = defs[id]
	if def == nil then
		assert(false)
		return
	end

	self.roomid = id

	local x, _, z = self.inst.Transform:GetWorldPosition()
	if def.TerraformRoomAtXZ then
		def.TerraformRoomAtXZ(self.inst, x, z)
	else
		defs.ResetTerraformRoomAtXZ(self.inst, x, z)
	end

	POPULATING = true --@V2C: hope this is safe XD
	local newents = {}
	for prefab, ents in pairs(data.ents) do
		for i, v in ipairs(ents) do
			v.prefab = v.prefab or prefab -- prefab field is stripped out when entities are saved in global entity collections, so put it back
			SpawnSaveRecord(v, newents)
		end
	end
	--post pass in neccessary to hook up references
	for _, v in pairs(newents) do
		v.entity:LoadPostPass(newents, v.data)
	end
	POPULATING = false

	if data.world_time then
		local dt = (TheWorld.state.cycles + TheWorld.state.time - data.world_time) * TUNING.TOTAL_DAY_TIME
		if dt > 0 then
			for _, v in pairs(newents) do
				if v.entity:IsValid() then
					v.entity:LongUpdate(dt)
				end
			end
		end
	end
end

function VaultRoom:OnSave()
	return self.roomid and { room = self.roomid } or nil
end

function VaultRoom:OnLoad(data)--, ents)
	self.roomid = data and data.room or nil
end

return VaultRoom
