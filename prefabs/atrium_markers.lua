local atriumroom_defs = require("prefabs/atriumroom_defs")

local assets =
{
	Asset("SCRIPT", "scripts/prefabs/atriumroom_defs.lua"),
}

local prefabs =
{
    "atrium_portal_fx",
    "charlie_boss_trial",
}

local function GetTeleportRadius()-- ent)
    return 9 + math.random() * 1 -- NOTE(Omar): has to be at least above 8, to be out of charlie boss aggro range
end

local function OnAdd(inst)
	inst.inittask = nil
    if not TheWorld.ismastersim then
        print("Any atrium marker entity should not exist on clients!", inst)
        inst:Remove()
		return
    end
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.ATRIUM, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})
end

local function OnRemove(inst)
    TheWorld:PushEvent("ms_unregister_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.ATRIUM, context = VIRTUALROOMCONTEXT.MARKER})
end

local TILE_SCALE = TILE_SCALE
local boundingbox = VIRTUALROOM_BOUNDINGBOXES[VIRTUALROOMSETS.ATRIUM]
local OUTER_MINX, OUTER_MAXX, OUTER_MINY, OUTER_MAXY = boundingbox.minx - 1, boundingbox.maxx + 1, boundingbox.miny - 1, boundingbox.maxy + 1
local INNER_MINX, INNER_MAXX, INNER_MINY, INNER_MAXY = -3 - 1, 3 + 1, -3 - 1, 3 + 1 -- 1 extra length to take into account overhang
local INNER_PHASE2_MINX, INNER_PHASE2_MAXX, INNER_PHASE2_MINY, INNER_PHASE2_MAXY = -4 - 1, 4 + 1, -4 - 1, 4 + 1 -- 1 extra length to take into account overhang
local CHECK_PLAYERS_DIMENSION_HOPPING_RADIUS = (OUTER_MAXX - OUTER_MINX) * SQRT2 * TILE_SCALE / 2

local function GetArenaBoundingBox(inst)
    if inst.unstable then
        return INNER_PHASE2_MINX, INNER_PHASE2_MAXX, INNER_PHASE2_MINY, INNER_PHASE2_MAXY
    end

    return INNER_MINX, INNER_MAXX, INNER_MINY, INNER_MAXY
end

local function InBoundingBox(otx, oty, minx, maxx, miny, maxy, tx, ty)
    return (otx + minx) <= tx and tx <= (otx + maxx) and (oty + miny) <= ty and ty <= (oty + maxy)
end

local function GetDimensionExits(otx, oty, padding)
    padding = padding or 0
    local exits = {}

    for xx = OUTER_MINX - padding, OUTER_MAXX + padding do
        local tx, ty = otx + xx, oty + OUTER_MINY - padding
        if TileGroupManager:IsLandTile(TheWorld.Map:GetTile(tx, ty)) then
            table.insert(exits, { x = tx, y = ty })
        end

        tx, ty = otx + xx, oty + OUTER_MAXY + padding
        if TileGroupManager:IsLandTile(TheWorld.Map:GetTile(tx, ty)) then
            table.insert(exits, { x = tx, y = ty })
        end
    end

    for yy = OUTER_MINY - padding, OUTER_MAXY + padding do
        local tx, ty = otx + OUTER_MINX - padding, oty + yy
        if TileGroupManager:IsLandTile(TheWorld.Map:GetTile(tx, ty)) then
            table.insert(exits, { x = tx, y = ty })
        end

        tx, ty = otx + OUTER_MAXX + padding, oty + yy
        if TileGroupManager:IsLandTile(TheWorld.Map:GetTile(tx, ty)) then
            table.insert(exits, { x = tx, y = ty })
        end
    end

    return exits
end

local function TeleportToOuter(inst, player, otx, oty, virtualroomset)
    local exits = GetDimensionExits(otx, oty)
    local exit = exits[math.random(#exits)]
    local x, y, z = TheWorld.Map:GetTileCenterPoint(exit.x, exit.y)

    local r = 6
    local theta = inst:GetAngleToPoint(x, y, z) * DEGREES

    x, z = x + math.cos(theta) * r, z - math.sin(theta) * r

    local teleportents = { player }
    player:PushEventImmediate("vault_teleport", {
        state = "charliearena_teleport",
        onplayerready = function(doer)
            virtualroomset:TeleportEntities(teleportents, x, y, z, 0)
        end,
    })
end

local function CheckPlayersDimensionHopping(inst, virtualroomset)
    local otx, oty = virtualroomset:GetOriginInTiles()
    local players, numberplayers = virtualroomset:GetPlayersInfo()
    local x, y, z = inst.Transform:GetWorldPosition()
    for _, player in ipairs(FindPlayersInRange(x, y, z, CHECK_PLAYERS_DIMENSION_HOPPING_RADIUS)) do
        local px, py, pz = player.Transform:GetWorldPosition()
        local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(px, 0, pz)
        if not player.sg or not player.sg:HasAnyStateTag("doing", "busy", "devoured") then
            if players[player] then
                local minx, maxx, miny, maxy = GetArenaBoundingBox(inst)
                if player:HasTag("playerghost") and not InBoundingBox(otx, oty, minx, maxx, miny, maxy, tx, ty) then
                    TeleportToOuter(inst, player, otx, oty, virtualroomset)
                end
            else
                if InBoundingBox(otx, oty, OUTER_MINX, OUTER_MAXX, OUTER_MINY, OUTER_MAXY, tx, ty) then
                    local teleportents = { player }
                    player:PushEventImmediate("vault_teleport", {
                        state = "charliearena_teleport",
                        fastforward = 4,
                        onplayerready = function(doer)
                            virtualroomset:TeleportEntities(teleportents, x, y, z, GetTeleportRadius)
                        end,
                    })
                end
            end
        end
    end
end

local function TryUpdatingPlayersDimensionHopping(inst, virtualroomset)
    if not virtualroomset:IsCurrentRoomLobby() then
        if inst.tp_players_in_out_task == nil then
            inst.tp_players_in_out_task = inst:DoPeriodicTask(0.5, CheckPlayersDimensionHopping, nil, virtualroomset)

            inst.visuals = {}
            local otx, oty = inst.components.virtualroomset:GetOriginInTiles()
            local exits = GetDimensionExits(otx, oty)
            for i, v in ipairs(exits) do
                local cloud = SpawnPrefab("miasma_cloud_arenabordervisual")
                cloud.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(v.x, v.y))
                table.insert(inst.visuals, cloud)
            end
        end
    elseif inst.tp_players_in_out_task then
        inst.tp_players_in_out_task:Cancel()
        inst.tp_players_in_out_task = nil

        for i, v in ipairs(inst.visuals) do
            v:Remove()
        end
        inst.visuals = nil
    end
end

local function OnLoad(inst)
	if inst.inittask then
		inst.inittask:Cancel()
		OnAdd(inst)
	end
    TryUpdatingPlayersDimensionHopping(inst, inst.components.virtualroomset)
end

local function OnShowRoom(inst, virtualroomset, roomname, teleportingentsdata)
    if virtualroomset:IsCurrentRoomLobby() then -- always reset if we're in the lobby now
        if virtualroomset.teleportingentsdata then
            virtualroomset.teleportingentsdata.radius = function() return 1.5 + math.random() * 3 end
        end
        virtualroomset:TryToReset()
    end
    TryUpdatingPlayersDimensionHopping(inst, virtualroomset)
end

local function OnReset(inst, virtualroomset)
    inst:SetPRNGSeed(virtualroomset, virtualroomset.customdata.prngseed + 1)
end

local function OnPostInit(inst, virtualroomset)
    inst:SetPRNGSeed(virtualroomset, virtualroomset.customdata.prngseed)
end

local function SetPRNGSeed(inst, virtualroomset, seed)
    virtualroomset.customdata.prngseed = seed
    virtualroomset.scratchpad.prng:SetSeed(seed)
end

local function OnTeleportedEntity(inst, virtualroomset, ent, x, z)
    SpawnPrefab("atrium_portal_fx").Transform:SetPosition(x, 0, z)
end

local function centerfn()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

    inst.SetPRNGSeed = SetPRNGSeed

    inst.teleporters = {}

    local virtualroomset = inst:AddComponent("virtualroomset")
    virtualroomset:DeclareVirtualRoomSetName(VIRTUALROOMSETS.ATRIUM)
    virtualroomset:SetTeleportingOutProhibited(true)
    virtualroomset:SetOnShowRoom(OnShowRoom)
    virtualroomset:SetOnReset(OnReset)
    virtualroomset:SetOnPostInit(OnPostInit)
    virtualroomset:SetOnTeleportedEntity(OnTeleportedEntity)
    virtualroomset:SetDoNotRotateRooms(true)
    virtualroomset:SetRoomDefinitions(atriumroom_defs) -- Do last.
    virtualroomset:SetKeepInventoryItemsthroughReset(true)
    local prngseed = hash(TheNet:GetSessionIdentifier())
    virtualroomset.customdata.prngseed = prngseed
    virtualroomset.scratchpad.prng = PRNG_Uniform(prngseed)


    inst:ListenForEvent("ms_charliearena_morphatrium", function(_world, data)
        local x, _, z = virtualroomset:GetOrigin()
        if not virtualroomset:TryStartTeleportSequence({
            targetroomname = "boss1",
            x = x,
            z = z,
            radius = GetTeleportRadius,
            state = "charliearena_teleport",
            onteleportcb = data ~= nil and data.cb or nil
        }) then
            -- if teleport sequence wasn't successful (e.g. loading when no players loaded) then set the room instantly
            if data and data.cb then
                data.cb()
            end
            virtualroomset:SetRoom("boss1")
        end
    end, TheWorld)

    inst:ListenForEvent("ms_charliearena_expand", function(_world)
        local tx, ty = virtualroomset:GetOriginInTiles()
        for y = -4, 4 do
            for x = -4, 4 do
                TheWorld.Map:SetTile(tx + x, ty + y, WORLD_TILES.BRICK)
            end
        end
        inst.unstable = true
    end, TheWorld)

	inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
	inst.OnLoad = OnLoad
	inst:ListenForEvent("onremove", OnRemove)

	return inst
end

return Prefab("atriummarker_gate_center", centerfn, assets, prefabs)
