local defs = {
    internal = {},
    layouts = {},
}

local TILE_SCALE = TILE_SCALE
local IMPASSABLE = WORLD_TILES.IMPASSABLE

--------------------------------------------------------------------------

if TheSim then -- updateprefabs guard
    AddIsTileInvalidForPathing_VirtualRoomSet(VIRTUALROOMSETS.VAULT, function(map, tx, ty)
        return IsVaultTileInvalid(tx, ty) or TileGroupManager:IsInvalidTile(map:GetTile(tx, ty))
    end)
end

--------------------------------------------------------------------------

--[[
A short template for layouts.
defs.layouts.roomnamehere = {
    ApplyFloorTiles = function(inst, virtualroomset)
        virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        -- Spawn entities.
    end,
}
]]

--------------------------------------------------------------------------

local function CreateDefaultFloorTiles()
    local VIRTUALROOM_DONOTCARE_TILE = VIRTUALROOM_DONOTCARE_TILE
    local V = WORLD_TILES.VAULT
    local defaultfloortiles = {}
    defs.defaultfloortiles = defaultfloortiles
    for _, maskbit in ipairs(VIRTUALROOM_BOUNDINGBOXES[VIRTUALROOMSETS.VAULT].mask) do
        if maskbit == 0 then
            table.insert(defaultfloortiles, VIRTUALROOM_DONOTCARE_TILE)
        else
            table.insert(defaultfloortiles, V)
        end
    end
end
CreateDefaultFloorTiles()

--------------------------------------------------------------------------

defs.internal.DIRECTIONS_TO_MARKER = {
    [VIRTUALROOMDIRECTIONS.N] = "vaultmarker_vault_north",
    [VIRTUALROOMDIRECTIONS.E] = "vaultmarker_vault_east",
    [VIRTUALROOMDIRECTIONS.S] = "vaultmarker_vault_south",
    [VIRTUALROOMDIRECTIONS.W] = "vaultmarker_vault_west",
    [VIRTUALROOMDIRECTIONS.OUT] = "vaultmarker_vault_south",
}

defs.internal.DIRECTIONS_TO_MARKER_TELEPORTERUSE = {
    [VIRTUALROOMDIRECTIONS.N] = "vaultmarker_vault_south",
    [VIRTUALROOMDIRECTIONS.E] = "vaultmarker_vault_west",
    [VIRTUALROOMDIRECTIONS.S] = "vaultmarker_vault_north",
    [VIRTUALROOMDIRECTIONS.W] = "vaultmarker_vault_east",
    [VIRTUALROOMDIRECTIONS.IN] = "vaultmarker_vault_south",
    [VIRTUALROOMDIRECTIONS.OUT] = "vaultmarker_lobby_to_vault",
}

defs.internal.IsLinkBroken = function(virtualroomset, roomnameorroomindex, direction)
    local virtualroom = virtualroomset.rooms[roomnameorroomindex]
    if not virtualroom then
        return false
    end

    local link = virtualroom.links and virtualroom.links[direction] or nil
    if not link then
        return false
    end

    if not link.broken then
        return false
    end

    local repairedlinks = virtualroomset.customdata.repairedlinks[roomnameorroomindex]
    if not repairedlinks then
        return true
    end

    local directionname = VIRTUALROOMDIRECTIONS_INDEX[direction]
    return repairedlinks[directionname] == nil
end

defs.internal.IsOtherRoomLinkBroken = function(virtualroomset, roomnameorroomindex, direction)
    local virtualroom = virtualroomset.rooms[roomnameorroomindex]
    if virtualroom then
        local links = virtualroom.links
        if links then
            local link = links[direction]
            if link and link.linkedroom and link.linkeddirection then
                return defs.internal.IsLinkBroken(virtualroomset, link.linkedroom, link.linkeddirection)
            end
        end
    end
    return false
end

defs.internal.DoOnArriveTeleporters_HACK = function(virtualroomset, x, z)
    -- FIXME(JBK): This is a hack using the room destination point to figure out what the new room's teleporter inst is when the room has finished loading.
    local teleporters = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.TELEPORTER)
    if teleporters then
        for _, teleporter in ipairs(teleporters) do
            local tx, ty, tz = teleporter.Transform:GetWorldPosition()
            if distsq(x, z, tx, tz) < 1 then
                teleporter.components.virtualroomteleporter:OnArrive()
            end
        end
    end
end

defs.internal.GetTeleportersForDirection = function(virtualroomset, direction)
    local teleporters = nil
    for _, teleporter in ipairs(virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.TELEPORTER)) do
        if teleporter.components.virtualroomteleporter:GetDirection() == direction then
            if not teleporters then
                teleporters = {teleporter}
            else
                table.insert(teleporters, teleporter)
            end
        end
    end

    return teleporters
end

defs.internal.CreateTeleporter = function(shuffleddirection, direction)
    local markerprefab = defs.internal.DIRECTIONS_TO_MARKER[shuffleddirection]
    local markers = TheWorld.components.virtualroommanager:GetVirtualRoomEntities(VIRTUALROOMSETS.VAULT, VIRTUALROOMCONTEXT.MARKER)
    local marker = FindFirstPrefabInArray(markers, markerprefab)
    local x, y, z = marker.Transform:GetWorldPosition()
    local _world = TheWorld
    local _map = _world.Map
    local cx, cy, cz = _map:GetTileCenterPoint(x, y, z)
    if shuffleddirection == VIRTUALROOMDIRECTIONS.N then
        if _map:IsImpassableTileAtPoint(cx, cy, cz - TILE_SCALE) then
            z = z + 0.4
        end
    elseif shuffleddirection == VIRTUALROOMDIRECTIONS.E then
        if _map:IsImpassableTileAtPoint(cx - TILE_SCALE, cy, cz) then
            x = x + 0.4
        end
    elseif shuffleddirection == VIRTUALROOMDIRECTIONS.S then
        if _map:IsImpassableTileAtPoint(cx, cy, cz + TILE_SCALE) then
            z = z - 0.4
        end
    elseif shuffleddirection == VIRTUALROOMDIRECTIONS.W then
        if _map:IsImpassableTileAtPoint(cx + TILE_SCALE, cy, cz) then
            x = x - 0.4
        end
    end

    local teleporter = SpawnPrefab("vault_teleporter")
    teleporter.Transform:SetPosition(x, y, z)
    direction = direction or VIRTUALROOMDIRECTIONS.N
    shuffleddirection = shuffleddirection or VIRTUALROOMDIRECTIONS.N
    teleporter.components.virtualroomteleporter:SetDirection(direction)
    teleporter.components.virtualroomteleporter:SetShuffledDirection(shuffleddirection)
    teleporter.components.virtualroomteleporter:OnForceRegisterEntity()
    teleporter:OnPlaced()
    teleporter:UpdateTeleporterPoweredState()
    return teleporter
end

defs.internal.CreateTeleportersForRoomSet = function(virtualroomset)
    local virtualroom = virtualroomset:GetCurrentRoom()
    local links = virtualroom.links
    for _, directionname in ipairs(VIRTUALROOMDIRECTIONS_INDEX) do
        local direction = VIRTUALROOMDIRECTIONS[directionname]
        local link = links[direction]
        if link then
            local shuffleddirection = VIRTUALROOMDIRECTIONS[virtualroom.shuffleddirections[direction]]
            local teleporter = defs.internal.CreateTeleporter(shuffleddirection, direction)
            if defs.internal.IsLinkBroken(virtualroomset, virtualroom.roomname, direction) then
                teleporter:MakeBroken()
                teleporter:SpawnOrb()
            end
        end
    end
end

--------------------------------------------------------------------------

defs.layouts.puzzle1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dty = -3, 3 do
            for dtx = -3, 3 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
            end
        end
        virtualroomset:SetFloorTileInBatch(-3, 4, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(-2, 4, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(2, 4, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(3, 4, IMPASSABLE)
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)

        local trial = SpawnPrefab("abysspillar_trial")
        trial.Transform:SetPosition(x + 1.5 * TILE_SCALE, 0, z - 4 * TILE_SCALE)
        trial:SetSpawnXZ(x, z - 4 * TILE_SCALE)

        --runes
        local rune = SpawnPrefab("vault_rune")
        rune:SetId("puzzle1")
        rune.Transform:SetPosition(x - 1.5 * TILE_SCALE, 0, z - 4 * TILE_SCALE)

        --back columns
        local brokenvar = math.random(3)
        SpawnPrefab("vault_pillar"):MakeBroken(brokenvar == 1).Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z + 4 * TILE_SCALE)
        SpawnPrefab("vault_pillar"):MakeBroken(brokenvar == 2).Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z + 4 * TILE_SCALE)

        --exit light
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z + 4 * TILE_SCALE)

        --variations
        local activeminion, lightvar

        --minion statue columns
        for dx = -2.5, 2.5, 5 do
            local x1 = x + dx * TILE_SCALE
            local left = x1 < x

            if activeminion == nil then
                activeminion = math.random(-1, 1) * 2
            else
                local old = activeminion
                activeminion = math.random(-1, 0) * 2
                if activeminion >= old then
                    activeminion = activeminion + 2
                end
            end

            if lightvar == nil then
                lightvar = math.random(-1, 1) * 2
            else
                local old = lightvar
                lightvar = math.random(-1, 0) * 2
                if lightvar >= old then
                    lightvar = lightvar + 2
                end
            end

            for i = 2, -2, -2 do
                local z1 = z + i * TILE_SCALE

                local pillar = SpawnPrefab("vault_pillar"):MakeCapped(2)
                pillar.Transform:SetPosition(x1, 0, z1)

                local minion = SpawnPrefab("abysspillar_minion")
                minion:SetOnBigPillar(pillar, left)
                if i == activeminion then
                    trial:SetMinion(minion, left)
                else
                    minion:MakeBroken()
                end

                SpawnPrefab("vault_chandelier"):SetVariation(i == lightvar and 2 or 1).Transform:SetPosition(x1, 0, z1)
            end
        end
    end,
}

--------------------------------------------------------------------------



defs.layouts.puzzle2 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dty = -4, 4 do
            for dtx = -4, 4 do
                if dty >= 3 or math.abs(dtx) >= (dty <= -3 and 2 or 3) then
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                end
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --runes
        local rune = SpawnPrefab("vault_rune")
        rune:SetId("puzzle2")
        rune.Transform:SetPosition(x, 0, z - 3 * TILE_SCALE)

        --torches
        local trial = SpawnPrefab("lightsout_trial")
        trial.Transform:SetPosition(x, 0, z)
        trial:SetupPuzzle()

        --variations
        local brokenvar = math.random(4)
        local i = 1

        --columns
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 3.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x - 3.5 * TILE_SCALE, 0, z + dx * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + 3.5 * TILE_SCALE, 0, z + dx * TILE_SCALE)
        end
        for zsign = -1, 1, 2 do
            for xsign = -1, 1, 2 do
                if brokenvar < i then
                    brokenvar = math.random(i, i + 2)
                end
                for dx = 2.5, 3.5, 1 do
                    local dz = 6 - dx
                    SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * xsign * TILE_SCALE, 0, z + dz * zsign * TILE_SCALE)
                    i = i + 1
                end
            end
            brokenvar = math.random(i, i + 3)
        end

        --ground
        local groundvars = { 3, 4, 5, 3, 4, 5, 3, 4, 5 }
        local groundorientations = { 1, 2, 3, 4, 1, 2, 3, 4, math.random(4) }
        for dx = -1.5, 1.5, 1.5 do
            for dz = -1.5, 1.5, 1.5 do
                SpawnPrefab("vault_ground_pattern_fx"):SetVariation(table.remove(groundvars, math.random(#groundvars))):SetOrientation(table.remove(groundorientations, math.random(#groundorientations))).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
            end
        end

        --lights
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)
    end,
}

--------------------------------------------------------------------------

local function hall_ApplyFloorTiles(inst, virtualroomset)
    for dty = -4, 4 do
        for dtx = -4, 4 do
            if dty ~= 0 and dtx ~= 0 and not (dty <= 1 and dty >= -1 and dtx <= 1 and dtx >= -1) then
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
            end
        end
    end
end

local function hall_CreateRoomEntities(inst, virtualroomset, issecurity)
    local x, _, z = virtualroomset:GetOrigin()
    defs.internal.CreateTeleportersForRoomSet(virtualroomset)
    --variations
    local seed = virtualroomset.customdata.seed or hash(TheNet:GetSessionIdentifier())
    local groundvar = bit.band(seed, 1) == 1
    local lightvar = math.random(3)
    local brokenvar = math.random(8)
    local broken2
    local i = 1

    --columns
    for dx = -1.5, 1.5, 3 do
        for dz = -3.5, 3.5, 7 do
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x + dz * TILE_SCALE, 0, z + dx * TILE_SCALE)
            i = i + 2
            if not broken2 and brokenvar < i then
                broken2 = true
                brokenvar = math.random(8)
            end
        end
        for dz = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dz * TILE_SCALE, 0, z + dx * TILE_SCALE)
        end
    end

    --lights
    if lightvar > 2 then
        local r = issecurity and 2 or 1 + math.random()
        local theta = math.random() * TWOPI
        SpawnPrefab("vault_chandelier_broken").Transform:SetPosition(x + math.cos(theta) * r, 0, z - math.sin(theta) * r)
        SpawnPrefab("vault_chandelier_decor"):SetVariation(math.random() < 0.5 and 1 or 3).Transform:SetPosition(x, 0, z)
    else
        SpawnPrefab("vault_chandelier"):SetVariation(lightvar).Transform:SetPosition(x, 0, z)
    end

    if issecurity then
        --spark
        SpawnPrefab("vault_security_desk").Transform:SetPosition(x, 0, z)
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
    else
        --ground
        local roomname = virtualroomset:GetCurrentRoomName()
        if roomname then
            local _, n = string.match(roomname, "^(hall)(%d+)")
            roomname = tonumber(n)
        end
        if roomname then
            if (roomname == 1 or roomname == 4 or roomname == 7) == groundvar then
                SpawnPrefab("vault_ground_pattern_fx"):SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
            end
        elseif math.random() < 0.5 then
            SpawnPrefab("vault_ground_pattern_fx"):SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
        end
    end
end

local securityhalldef = {
    ApplyFloorTiles = hall_ApplyFloorTiles,
    CreateRoomEntities = function(inst, virtualroomset)
        hall_CreateRoomEntities(inst, virtualroomset, true)
    end,
}
local halldef = {
    ApplyFloorTiles = hall_ApplyFloorTiles,
    CreateRoomEntities = function(inst, virtualroomset)
        hall_CreateRoomEntities(inst, virtualroomset, false)
    end,
}

defs.layouts.hall1 = shallowcopy(securityhalldef)
defs.layouts.hall2 = shallowcopy(securityhalldef)
defs.layouts.hall3 = shallowcopy(securityhalldef)
-- hall4 is not used
defs.layouts.hall5 = shallowcopy(halldef)
defs.layouts.hall6 = shallowcopy(halldef)
defs.layouts.hall7 = shallowcopy(halldef)

--------------------------------------------------------------------------

defs.layouts.lore1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dtx = -4, 4 do
            if dtx ~= 0 then
                for dty = 2, 4 do
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                    virtualroomset:SetFloorTileInBatch(dtx, -dty, IMPASSABLE)
                end
            end
        end
        for dty = -1, 1, 2 do
            virtualroomset:SetFloorTileInBatch(-4, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(4, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-1, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(1, dty, IMPASSABLE)
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)

        --variations
        local groundvar = math.random(2)
        local brokenvar = math.random(4)
        local broken2
        local i = 1

        --runes
        local rune = SpawnPrefab("vault_rune")
        rune:SetId("lore1")
        rune.Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 1 and 2 or 1):SetOrientation(math.random(4)).Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_compass").Transform:SetPosition(x - 3 * TILE_SCALE, 0, z + 0.5 * TILE_SCALE)

        --statues
        local statue = SpawnPrefab("vault_statue")
        statue:SetId("king")
        statue:SetScene("lore1")
        statue.Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 2 and 2 or 1):SetOrientation(math.random(4)).Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z)
        local theta = math.random() * TWOPI
        SpawnPrefab("vault_chandelier_broken").Transform:SetPosition(x + 2.5 * TILE_SCALE + 2.5 * math.cos(theta), 0, z - 2.5 * math.sin(theta))
        SpawnPrefab("vault_chandelier_decor"):SetVariation(math.random() < 0.5 and 1 or 3).Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_chandelier_decor"):SetVariation(2).Transform:SetPosition(x, 0, z)

        --columns
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 3.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 3.5 * TILE_SCALE)
        end
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
        end
        for dx = -3.5, 3.5, 7 do
            for dz = -2.5, 2.5, 5 do
                SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
                i = i + 1
                if not broken2 and brokenvar < i then
                    broken2 = true
                    brokenvar = math.random(4)
                end
            end
        end
    end,
}

--------------------------------------------------------------------------

defs.layouts.lore2 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dtx = -4, 4 do
            if dtx ~= 0 then
                for dty = 3, 4 do
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                    virtualroomset:SetFloorTileInBatch(dtx, -dty, IMPASSABLE)
                end
            end
        end
        for dty = -2, 2 do
            if dty ~= 0 then
                for dtx = 3, 4 do
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                    virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
                end
            end
        end
        for dty = -2, 2, 4 do
            for dtx = -2, 2, 4 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --runes
        local rune = SpawnPrefab("vault_rune")
        rune:SetId("lore2")
        rune.Transform:SetPosition(x, 0, z - 1.5 * TILE_SCALE)

        --statues
        local statue = SpawnPrefab("vault_statue")
        statue:SetId("gate")
        statue:SetScene("lore2")
        statue.Transform:SetPosition(x, 0, z)

        local statueids = { "ancient1", "ancient2", "ancient3", "bug1", "bug2", "bug3" }
        local dtheta = TWOPI / 7
        local extra = 4 * DEGREES
        local theta = 90 * DEGREES + dtheta - 2.5 * extra
        dtheta = dtheta + extra
        local r = 1.2 * TILE_SCALE
        for i = 1, 6 do
            statue = SpawnPrefab("vault_statue")
            statue:SetId(table.remove(statueids, math.random(#statueids)))
            statue:SetScene("lore2")
            statue.Transform:SetPosition(x + r * math.cos(theta), 0, z - 0.8 * r * math.sin(theta))
            theta = theta + dtheta
        end

        --variations
        local brokenvar = math.random(8)
        local i = 1

        --columns
        for dx = -2.5, 2.5, 5 do
            for dz = -2.5, 2.5, 5 do
                SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
                i = i + 1
            end
        end
        if brokenvar < i then
            brokenvar = math.random(3, 8)
        end
        for dx = -1.5, 1.5, 3 do
            for dz = -3.5, 3.5, 7 do
                SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
                SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dz * TILE_SCALE, 0, z + dx * TILE_SCALE)
                i = i + 1
            end
        end

        --lights
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

        --ground
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
    end,
}

--------------------------------------------------------------------------


defs.layouts.lore3 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dty = 3, 4 do
            virtualroomset:SetFloorTileInBatch(-4, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(4, dty, IMPASSABLE)
        end
        for dty = 1, 2 do
            for dtx = 3, 4 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
            end
        end
        for dtx = 2, 4 do
            virtualroomset:SetFloorTileInBatch(dtx, -1, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-dtx, -1, IMPASSABLE)
        end
        for dty = -4, -2 do
            for dtx = 1, 4 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --runes
        local rune = SpawnPrefab("vault_rune")
        rune:SetId("lore3")
        rune.Transform:SetPosition(x, 0, z)

        --variations
        local brokenvarbk = math.random(0, 2) * 7 - 3.5
        local brokenvarfr = math.random(5)
        local i = 1
        local guardvars = { 1, 1, 2, 2, 2, 3, 3, math.random(3) } --1 & 3 are quite similar

        --statues
        for dx = -1.5, 1.5, 1 do
            local statue = SpawnPrefab("vault_statue")
            statue:SetId("guard"..table.remove(guardvars, math.random(#guardvars)))
            statue:SetScene("lore3")
            statue.Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 1.5 * TILE_SCALE)
        end
        for dx = -2, 2, 1 do
            if dx ~= 0 then
                local statue = SpawnPrefab("vault_statue")
                statue:SetId("guard"..table.remove(guardvars, math.random(#guardvars)))
                statue:SetScene("lore3")
                statue.Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 3 * TILE_SCALE)
            end
        end

        --columns
        for dx = -3.5, 3.5, 7 do
            SpawnPrefab("vault_pillar"):MakeBroken(dx == brokenvarbk).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 1.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvarfr).Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 1.5 * TILE_SCALE)
            i = i + 1
        end
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 1.5 * TILE_SCALE)
        end
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvarfr).Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 3.5 * TILE_SCALE)
            i = i + 1
        end

        --lights
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

        --ground
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)

        --beta
        --SpawnPrefab("temp_beta_msg").Transform:SetPosition(x + 0.55 * TILE_SCALE, 0, z + 4.6 * TILE_SCALE)
    end,
}

--------------------------------------------------------------------------

defs.layouts.teleport1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dtx = -4, 4 do
            if dtx ~= 0 then
                virtualroomset:SetFloorTileInBatch(dtx, 4, IMPASSABLE)
            end
        end
        for dty = -1, 3 do
            if dty ~= 0 then
                virtualroomset:SetFloorTileInBatch(4, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-4, dty, IMPASSABLE)
            end
        end
        for dty = 2, 3 do
            for dtx = 2, 3 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
            end
        end
        for dtx = 2, 4 do
            virtualroomset:SetFloorTileInBatch(dtx, -2, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-dtx, -2, IMPASSABLE)
        end
        for dty = -4, -3 do
            for dtx = -4, 4 do
                if dtx ~= 0 then
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                end
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --runes
        local rune = SpawnPrefab("vault_rune")
        rune:SetId("teleport1")
        rune.Transform:SetPosition(x, 0, z)

        --variations
        local brokenvar = math.random(0, 2) * 5 - 2.5

        --columns
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeBroken(brokenvar == dx).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar").Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
        end
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 3.5 * TILE_SCALE)
        end

        --lights
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

        --ground
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
    end,
}

--------------------------------------------------------------------------

defs.layouts.mask1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dtx = -5, 5, 10 do
            for dty = -1, 1 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
            end
        end
        for dtx = -4, 4 do
            if dtx ~= 0 then
                virtualroomset:SetFloorTileInBatch(dtx, 4, IMPASSABLE)
                for dty = -4, -2 do
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                end
            end
        end
        for dtx = 2, 4 do
            for dty = 2, 3 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
            end
        end
        virtualroomset:SetFloorTileInBatch(-4, 1, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(4, 1, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(1, -1, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(-1, -1, IMPASSABLE)
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --husks
        SpawnPrefab("ancient_husk"):SetId("handmaid").Transform:SetPosition(x, 0, z + TILE_SCALE)
        SpawnPrefab("ancient_husk"):SetId("mason").Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("ancient_husk"):SetId("architect").Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z)
    
        --masks
        SpawnPrefab("mask_ancient_handmaidhat").Transform:SetPosition(x + 0.4, 0, z + TILE_SCALE - 2)
        SpawnPrefab("mask_ancient_masonhat").Transform:SetPosition(x - 2.5 * TILE_SCALE + 0.5, 0, z - 2.25)
        SpawnPrefab("mask_ancient_architecthat").Transform:SetPosition(x + 2.5 * TILE_SCALE - 1.5, 0, z - 1.85)
    
        --variations
        local groundvar = math.random(2)
        local groundvar1 = math.random(4)
        local groundvar2 = math.random(3)
        groundvar2 = groundvar2 >= groundvar1 and groundvar2 + 1 or groundvar2
        local lightvar = math.random(3)
        local lightvar1 = math.random(2)
        local lightvar2 = lightvar1 == 1 and 2 or 1
        local brokenvar = math.random(4)
        local broken2
        local i = 1
    
        --columns
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 3.5 * TILE_SCALE)
            i = i + 2
            if not broken2 and brokenvar < i then
                brokenvar = math.random(i, 8)
            end
        end
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
        end
        for dx = -3.5, 3.5, 7 do
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
            i = i + 1
        end
        if brokenvar < i then
            brokenvar = math.random(5, 8)
        end
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 3.5 * TILE_SCALE)
            i = i + 1
        end
        for dx = -3.5, 3.5, 7 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
        end
    
        --lights
        SpawnPrefab("vault_chandelier"):SetVariation(lightvar == 1 and lightvar1 or lightvar2).Transform:SetPosition(x, 0, z + TILE_SCALE)
        SpawnPrefab("vault_chandelier"):SetVariation(lightvar == 2 and lightvar1 or lightvar2).Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_chandelier"):SetVariation(lightvar == 3 and lightvar1 or lightvar2).Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z)
    
        --ground
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 1 and 1 or 2):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z + TILE_SCALE)
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 2 and 1 or 2):SetOrientation(groundvar1).Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z)
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(groundvar == 2 and 1 or 2):SetOrientation(groundvar2).Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z)
    end,
}

--------------------------------------------------------------------------

defs.layouts.generator1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dty = 2, 4 do
            for dtx = -4, 4 do
                if dtx ~= 0 then
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                end
            end
        end
        for dtx = 3, 4 do
            virtualroomset:SetFloorTileInBatch(dtx, 1, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-dtx, 1, IMPASSABLE)
        end
        for dtx = 3, 4 do
            virtualroomset:SetFloorTileInBatch(dtx, -1, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-dtx, -1, IMPASSABLE)
        end
        for dtx = 2, 4 do
            virtualroomset:SetFloorTileInBatch(dtx, -2, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-dtx, -2, IMPASSABLE)
        end
        for dty = -4, -3 do
            for dtx = -4, 4 do
                if dtx ~= 0 then
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                end
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --switch
        SpawnPrefab("vault_switch_base").Transform:SetPosition(x, 0, z)

        --spark
        SpawnPrefab("vault_security_desk").Transform:SetPosition(x + 2 * TILE_SCALE, 0, z - 1 * TILE_SCALE)
        SpawnPrefab("vault_security_desk").Transform:SetPosition(x - 2 * TILE_SCALE, 0, z - 1 * TILE_SCALE)
        SpawnPrefab("vault_compass").Transform:SetPosition(x + (math.random() < 0.5 and 1.5 or -1.5) * TILE_SCALE, 0, z - 0.75 * TILE_SCALE)

        --variations
        local lightvar = math.random(3)
        local lightvar1 = math.random(2)
        local lightvar2 = lightvar1 == 1 and 2 or 1
        local brokenvar = math.random(4)
        local i = 1

        --columns
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 3.5 * TILE_SCALE)
        end
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
        end
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
            i = i + 1
        end
        for dz = 1.5, -1.5, -3 do
            for dx = -3.5, 3.5, 7 do
                SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
                i = i + 1
                if brokenvar < i and i <= 5 then
                    brokenvar = math.random(i, 6)
                end
            end
        end
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
        end
        for dx = -1.5, 1.5, 3 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z - 3.5 * TILE_SCALE)
        end

        --lights
        for i = 1, 3 do
            local theta = (90 + 120 * i) * DEGREES
            local r = 2.95
            SpawnPrefab("vault_chandelier"):SetVariation(lightvar == i and lightvar1 or lightvar2).Transform:SetPosition(x + math.cos(theta) * r, 0, z - math.sin(theta) * r)
        end

        --ground
        SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
    end,
}

--------------------------------------------------------------------------

local function fountain_ApplyFloorTiles(inst, virtualroomset)
    for dty = 2, 4 do
        for dtx = -4, 4 do
            if dtx ~= 0 then
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(dtx, -dty, IMPASSABLE)
            end
        end
    end
    for dty = -1, 1, 2 do
        for dtx = 3, 4 do
            virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
        end
    end
end

local function fountain_CreateRoomEntities(inst, virtualroomset, product)
    local x, _, z = virtualroomset:GetOrigin()
    defs.internal.CreateTeleportersForRoomSet(virtualroomset)
    --fountain
    local fountain = SpawnPrefab("archive_lockbox_dispencer")
    fountain:SetProductOrchestrina(product)
    fountain.Transform:SetPosition(x, 0, z)

    --variations
    local brokenvart = math.random(4)
    local brokenvarb = math.random(4)
    local broken2t, broken2b
    local it, ib = 1, 1

    --columns
    for dz = -1.5, 1.5, 3 do
        for dx = -3.5, 3.5, 7 do
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
        end
    end
    for dz = -2.5, 2.5, 5 do
        for dx = -2.5, 2.5, 5 do
            SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
        end
    end
    for dx = -1.5, 1.5, 3 do
        for dz = 2.5, 3.5, 1 do
            SpawnPrefab("vault_pillar"):MakeBroken(brokenvart == it).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
            it = it + 1
        end
        if not broken2t and brokenvart < it then
            broken2t = true
            brokenvart = math.random(4)
        end
        for dz = -3.5, -2.5, 1 do
            SpawnPrefab("vault_pillar"):MakeBroken(brokenvarb == ib).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
            ib = ib + 1
        end
        if not broken2b and brokenvarb < ib then
            broken2b = true
            brokenvarb = math.random(4)
        end
    end

    --lights
    SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)

    --ground
    SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(math.random(2)):SetOrientation(math.random(4)).Transform:SetPosition(x, 0, z)
end


defs.layouts.fountain1 = {
    ApplyFloorTiles = fountain_ApplyFloorTiles,
    CreateRoomEntities = function(inst, virtualroomset)
        fountain_CreateRoomEntities(inst, virtualroomset, "turf_vault")
    end,
}
defs.layouts.fountain2 = {
    ApplyFloorTiles = fountain_ApplyFloorTiles,
    CreateRoomEntities = function(inst, virtualroomset)
        fountain_CreateRoomEntities(inst, virtualroomset, "vaultrelic")
    end,
}

--------------------------------------------------------------------------

defs.layouts.playbill1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dty = 3, 4 do
            for dtx = -4, 4 do
                if dtx ~= 0 then
                    virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                    virtualroomset:SetFloorTileInBatch(dtx, -dty, IMPASSABLE)
                end
            end
        end
        for dty = 1, 2 do
            for dtx = -4, -3 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, -dty, IMPASSABLE)
            end
            for dtx = 3 - dty, 4 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, -dty, IMPASSABLE)
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        --variations
        local lightvar = math.random(3)
        local groundvar = math.random(2)
        local brokenvar = math.random(4)
        local playbillvar = math.random(2)
        local tablevar = math.random(2)
        local i = 1
        local stoolvars = { 1, 2, 3, 4 }
        --shuffle
        for i = 1, #stoolvars - 1 do
            local rnd = math.random(i, #stoolvars)
            if rnd ~= i then
                local tmp = stoolvars[i]
                stoolvars[i] = stoolvars[rnd]
                stoolvars[rnd] = tmp
            end
        end

        --furniture
        for j = 1, 2 do
            local spread = j > 1 and -1 or 1
            local x1 = x - spread * TILE_SCALE
            local z1 = z + spread * TILE_SCALE
            SpawnPrefab("vault_ground_pattern_fx"):HideCenter():SetVariation(j == groundvar and 2 or 1):SetOrientation(math.random(4)).Transform:SetPosition(x1, 0, z1)
            local decortable = SpawnPrefab("vault_table_round")
            decortable:SetVariation(j == tablevar and 3 or 2)
            decortable.Transform:SetPosition(x1, 0, z1)
            if j == playbillvar then
                decortable.components.furnituredecortaker:AcceptDecor(SpawnPrefab("playbill_the_vault"), TheWorld)
            else
                decortable.components.furnituredecortaker:AcceptDecor(SpawnPrefab("vault_compass"), TheWorld)
            end
            SpawnPrefab("vault_chandelier"):SetVariation(j == lightvar and 2 or 1).Transform:SetPosition(x1, 0, z1)
            local theta = math.random() * TWOPI
            local delta = TWOPI / 3
            local r = 2.1
            for i = 1, 3 do
                theta = theta + delta
                local stool = SpawnPrefab("vault_stool")
                local rnd = math.random()
                rnd = math.clamp(math.ceil(rnd * rnd * 3), 1, 3)
                rnd = table.remove(stoolvars, rnd)
                table.insert(stoolvars, rnd)
                stool:SetVariation(rnd)
                stool.Transform:SetPosition(x1 + r * math.cos(theta), 0, z1 - r * math.sin(theta))
                stool.Transform:SetRotation(theta * RADIANS + 180)
            end
        end
        SpawnPrefab("vault_chandelier_decor"):SetVariation(2).Transform:SetPosition(x, 0, z)

        --columns
        for dx = -1.5, 1.5, 3 do
            for dz = -3.5, 3.5, 7 do
                SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
                SpawnPrefab("vault_pillar"):MakeCapped(1):AttachRelic().Transform:SetPosition(x + dz * TILE_SCALE, 0, z + dx * TILE_SCALE)
            end
        end
        SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x - 2.5 * TILE_SCALE, 0, z + 3.5 * TILE_SCALE)
        SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x - 3.5 * TILE_SCALE, 0, z + 2.5 * TILE_SCALE)
        i = i + 2
        if brokenvar < i then
            brokenvar = math.random(2, 4)
        end
        SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + 2.5 * TILE_SCALE, 0, z - 3.5 * TILE_SCALE)
        SpawnPrefab("vault_pillar"):MakeBroken(i + 1 == brokenvar).Transform:SetPosition(x + 3.5 * TILE_SCALE, 0, z - 2.5 * TILE_SCALE)
        i = i + 2
        brokenvar = math.random(5, 7)
        for dx = 1.5, 2.5, 1 do
            local dz = 4 - dx
            SpawnPrefab("vault_pillar"):MakeBroken(i == brokenvar).Transform:SetPosition(x + dx * TILE_SCALE, 0, z + dz * TILE_SCALE)
            SpawnPrefab("vault_pillar"):MakeCapped(2):AttachRelic().Transform:SetPosition(x - dx * TILE_SCALE, 0, z - dz * TILE_SCALE)
            i = i + 1
        end
    end,
}

--------------------------------------------------------------------------

defs.layouts.decon1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        for dtx = 3, 4 do
            for dty = -4, 4 do
                virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
                virtualroomset:SetFloorTileInBatch(-dtx, dty, IMPASSABLE)
            end
        end
        for dty = -2, 2 do
            virtualroomset:SetFloorTileInBatch(2, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-2, dty, IMPASSABLE)
        end
        for dty = -1, 1 do
            virtualroomset:SetFloorTileInBatch(5, dty, IMPASSABLE)
            virtualroomset:SetFloorTileInBatch(-5, dty, IMPASSABLE)
        end
        virtualroomset:SetFloorTileInBatch(1, 2, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(1, -2, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(-1, 2, IMPASSABLE)
        virtualroomset:SetFloorTileInBatch(-1, -2, IMPASSABLE)
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        -- Invalid tiles for pathfinding
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x, 0, z)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x + TILE_SCALE, 0, z)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x - TILE_SCALE, 0, z)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x + TILE_SCALE, 0, z + TILE_SCALE)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x - TILE_SCALE, 0, z + TILE_SCALE)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x + TILE_SCALE, 0, z - TILE_SCALE)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x - TILE_SCALE, 0, z - TILE_SCALE)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x, 0, z + TILE_SCALE)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x, 0, z - TILE_SCALE)

        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x, 0, z + TILE_SCALE * 2)
        SpawnPrefab("vault_invalidtile").Transform:SetPosition(x, 0, z - TILE_SCALE * 2)

        -- Mist generators.
        local mist1 = SpawnPrefab("vault_decon_mister")
        local mist2 = SpawnPrefab("vault_decon_mister")
        local mist3 = SpawnPrefab("vault_decon_mister")
        local mist4 = SpawnPrefab("vault_decon_mister")
        local PLACEMENT_SIZE = 3.5 -- 14 units for the square and we have one mister in the center of each quadrant of the square.
        mist1.Transform:SetPosition(x + PLACEMENT_SIZE, 0, z + PLACEMENT_SIZE)
        mist2.Transform:SetPosition(x - PLACEMENT_SIZE, 0, z + PLACEMENT_SIZE)
        mist3.Transform:SetPosition(x + PLACEMENT_SIZE, 0, z - PLACEMENT_SIZE)
        mist4.Transform:SetPosition(x - PLACEMENT_SIZE, 0, z - PLACEMENT_SIZE)

        -- Doors.
        local door1 = SpawnPrefab("vault_decon_door_collision")
        local door2 = SpawnPrefab("vault_decon_door_collision")
        door1.Transform:SetPosition(x, 0, z - TILE_SCALE * 2)
        door2.Transform:SetPosition(x, 0, z + TILE_SCALE * 2)

        -- Sanity adjusters.
        local sanityadjuster = SpawnPrefab("vault_sanity_adjuster")
        sanityadjuster.Transform:SetPosition(x, 0, z + 0.8)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x + TILE_SCALE + 2, 0, z + TILE_SCALE * 5 - 2)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x - TILE_SCALE - 2, 0, z + TILE_SCALE * 5 - 2)

        -- Mist switch.
        local switch = SpawnPrefab("vault_decon_switch")
        switch.Transform:SetPosition(x + TILE_SCALE * 1.3, 0, z)
        switch.components.entitytracker:TrackEntity("door1", door1)
        switch.components.entitytracker:TrackEntity("door2", door2)
        switch.components.entitytracker:TrackEntity("mist1", mist1)
        switch.components.entitytracker:TrackEntity("mist2", mist2)
        switch.components.entitytracker:TrackEntity("mist3", mist3)
        switch.components.entitytracker:TrackEntity("mist4", mist4)
        switch.components.entitytracker:TrackEntity("sanityadjuster", sanityadjuster)

        -- Reset switches in case of key entry with the door in the opposite state from where the player needs to get to.
        local switch_reset = SpawnPrefab("vault_decon_switch_reset")
        switch_reset.Transform:SetPosition(x + TILE_SCALE, 0, z - TILE_SCALE * 3)
        switch_reset.components.entitytracker:TrackEntity("switch", switch)
        local switch_reset2 = SpawnPrefab("vault_decon_switch_reset2")
        switch_reset2.Transform:SetPosition(x + TILE_SCALE, 0, z + TILE_SCALE * 3)
        switch_reset2.components.entitytracker:TrackEntity("switch", switch)

        -- Pillars
        local brokenvar = math.random(4)
        SpawnPrefab("vault_pillar"):MakeBroken(1 == brokenvar).Transform:SetPosition(x + TILE_SCALE * 3, 0, z + TILE_SCALE)
        SpawnPrefab("vault_pillar"):MakeBroken(2 == brokenvar).Transform:SetPosition(x + TILE_SCALE * 3, 0, z - TILE_SCALE)
        SpawnPrefab("vault_pillar"):MakeBroken(3 == brokenvar).Transform:SetPosition(x - TILE_SCALE * 3, 0, z + TILE_SCALE)
        SpawnPrefab("vault_pillar"):MakeBroken(4 == brokenvar).Transform:SetPosition(x - TILE_SCALE * 3, 0, z - TILE_SCALE)
        brokenvar = math.random(2)
        SpawnPrefab("vault_pillar"):MakeBroken(1 == brokenvar).Transform:SetPosition(x + TILE_SCALE * 3.5, 0, z + TILE_SCALE * 3.5)
        SpawnPrefab("vault_pillar"):MakeBroken(2 == brokenvar).Transform:SetPosition(x - TILE_SCALE * 3.5, 0, z + TILE_SCALE * 3.5)
        brokenvar = math.random(2)
        SpawnPrefab("vault_pillar"):MakeBroken(1 == brokenvar).Transform:SetPosition(x + TILE_SCALE * 3.5, 0, z - TILE_SCALE * 3.5)
        SpawnPrefab("vault_pillar"):MakeBroken(2 == brokenvar).Transform:SetPosition(x - TILE_SCALE * 3.5, 0, z - TILE_SCALE * 3.5)

        -- Lights.
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x - TILE_SCALE * 1.5, 0, z - TILE_SCALE * 3.5)
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x + TILE_SCALE * 1.5, 0, z - TILE_SCALE * 3.5)
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x, 0, z)
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x - TILE_SCALE * 1.5, 0, z + TILE_SCALE * 3.5)
        SpawnPrefab("vault_chandelier"):SetVariation(math.random(2)).Transform:SetPosition(x + TILE_SCALE * 1.5, 0, z + TILE_SCALE * 3.5)

        switch:SetDoorStates(true) -- Always at the end for the switch to setup the room.
    end,
}

--------------------------------------------------------------------------

defs.layouts.key1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        -- Do nothing.
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        defs.internal.CreateTeleportersForRoomSet(virtualroomset)
        local trial = SpawnPrefab("vault_key_trial")
        trial.Transform:SetPosition(x, 0, z)
        trial:InitializeLayout()

        -- Sanity adjusters.
        --  Center column.
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x, 0, z + TILE_SCALE * 4 + 1.5)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x, 0, z)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x, 0, z - (TILE_SCALE * 4 + 1.5))
        --  Right column.
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x + TILE_SCALE * 4 - 2.5, 0, z + TILE_SCALE * 2 + 2.5)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x + TILE_SCALE * 4 + 1.5, 0, z)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x + TILE_SCALE * 4 - 2.5, 0, z - (TILE_SCALE * 2 + 2.5))
        --  Left column.
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x - (TILE_SCALE * 4 - 2.5), 0, z + TILE_SCALE * 2 + 2.5)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x - (TILE_SCALE * 4 + 1.5), 0, z)
        SpawnPrefab("vault_sanity_adjuster_alwaysincreasing").Transform:SetPosition(x - (TILE_SCALE * 4 - 2.5), 0, z - (TILE_SCALE * 2 + 2.5))
    end,
}
--------------------------------------------------------------------------

defs.internal.ResetAllRepairedLinks = function(virtualroomset)
    virtualroomset.customdata.repairedlinks = {}
    virtualroomset:InvalidateClosestDirectionCache()
end

local CURRENT_VERSION = 1
defs.InitializeLayout = function(virtualroomset)
    virtualroomset:SetVersion(CURRENT_VERSION) -- Mandatory call for InitializeLayout to have proper versioning control for this file.

    defs.internal.ResetAllRepairedLinks(virtualroomset)

    --------------------------------------------------------------------------
    -- NOTES(JBK): Adjusting the virtual room declarations will need a new CURRENT_VERSION number above.
    virtualroomset:DeclareVirtualRoom("mask1")
    virtualroomset:DeclareVirtualRoom("teleport1")
    virtualroomset:DeclareVirtualRoom("hall3")
    virtualroomset:DeclareVirtualRoom("puzzle1")
    virtualroomset:DeclareVirtualRoom("lore3")
    virtualroomset:DeclareVirtualRoom("key1")
    virtualroomset:DeclareVirtualRoom("hall1")
    virtualroomset:DeclareVirtualRoom("lore1")
    virtualroomset:DeclareVirtualRoom("puzzle2")
    virtualroomset:DeclareVirtualRoom("hall6")
    virtualroomset:DeclareVirtualRoom("hall2")
    virtualroomset:DeclareVirtualRoom("lore2")
    virtualroomset:DeclareVirtualRoom("hall5")
    virtualroomset:DeclareVirtualRoom("hall7")
    virtualroomset:DeclareVirtualRoom("fountain2")
    virtualroomset:DeclareVirtualRoom("generator1")
    virtualroomset:DeclareVirtualRoom("playbill1")
    virtualroomset:DeclareVirtualRoom("fountain1")
    virtualroomset:DeclareVirtualRoom("decon1")
    --------------------------------------------------------------------------
    virtualroomset:LinkVirtualRooms("mask1", VIRTUALROOMDIRECTIONS.N, "teleport1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("mask1", VIRTUALROOMDIRECTIONS.OUT, VIRTUALROOMLOBBY, nil)
    virtualroomset:MakeLinkRigid("mask1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:MakeLinkRigid("mask1", VIRTUALROOMDIRECTIONS.OUT)

    virtualroomset:LinkVirtualRooms("teleport1", VIRTUALROOMDIRECTIONS.N, "hall3", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("teleport1", VIRTUALROOMDIRECTIONS.E, "hall2", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("teleport1", VIRTUALROOMDIRECTIONS.S, "mask1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("teleport1", VIRTUALROOMDIRECTIONS.W, "hall1", VIRTUALROOMDIRECTIONS.E)
    virtualroomset:MakeLinkRigid("teleport1", VIRTUALROOMDIRECTIONS.S)

    virtualroomset:LinkVirtualRooms("hall3", VIRTUALROOMDIRECTIONS.N, "puzzle1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("hall3", VIRTUALROOMDIRECTIONS.E, "lore2", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("hall3", VIRTUALROOMDIRECTIONS.S, "teleport1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("hall3", VIRTUALROOMDIRECTIONS.W, "lore1", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("puzzle1", VIRTUALROOMDIRECTIONS.N, "lore3", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("puzzle1", VIRTUALROOMDIRECTIONS.E, "hall6", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("puzzle1", VIRTUALROOMDIRECTIONS.S, "hall3", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("puzzle1", VIRTUALROOMDIRECTIONS.W, "hall5", VIRTUALROOMDIRECTIONS.E)
    virtualroomset:MakeLinkRigid("puzzle1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:MakeLinkRigid("puzzle1", VIRTUALROOMDIRECTIONS.S)

    virtualroomset:LinkVirtualRooms("lore3", VIRTUALROOMDIRECTIONS.N, "decon1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRoomsBroken("lore3", VIRTUALROOMDIRECTIONS.E, "generator1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("lore3", VIRTUALROOMDIRECTIONS.S, "puzzle1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("lore3", VIRTUALROOMDIRECTIONS.W, "fountain2", VIRTUALROOMDIRECTIONS.E)
    virtualroomset:MakeLinkRigid("lore3", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:MakeLinkRigid("lore3", VIRTUALROOMDIRECTIONS.S)

    virtualroomset:LinkVirtualRooms("decon1", VIRTUALROOMDIRECTIONS.S, "lore3", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("decon1", VIRTUALROOMDIRECTIONS.N, "key1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:MakeLinkRigid("decon1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:MakeLinkRigid("decon1", VIRTUALROOMDIRECTIONS.S)

    virtualroomset:LinkVirtualRooms("key1", VIRTUALROOMDIRECTIONS.S, "decon1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:MakeLinkRigid("key1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:MakeRoomGrueImmuneArea("key1")

    virtualroomset:LinkVirtualRooms("hall1", VIRTUALROOMDIRECTIONS.N, "lore1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("hall1", VIRTUALROOMDIRECTIONS.E, "teleport1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("hall1", VIRTUALROOMDIRECTIONS.S, "fountain2", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("hall1", VIRTUALROOMDIRECTIONS.W, "playbill1", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("lore1", VIRTUALROOMDIRECTIONS.N, "hall5", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("lore1", VIRTUALROOMDIRECTIONS.E, "hall3", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("lore1", VIRTUALROOMDIRECTIONS.S, "hall1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("lore1", VIRTUALROOMDIRECTIONS.W, "puzzle2", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("hall5", VIRTUALROOMDIRECTIONS.N, "fountain2", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("hall5", VIRTUALROOMDIRECTIONS.E, "puzzle1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("hall5", VIRTUALROOMDIRECTIONS.S, "lore1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("hall5", VIRTUALROOMDIRECTIONS.W, "fountain1", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRoomsBroken("fountain2", VIRTUALROOMDIRECTIONS.N, "hall1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("fountain2", VIRTUALROOMDIRECTIONS.E, "lore3", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRoomsBroken("fountain2", VIRTUALROOMDIRECTIONS.S, "hall5", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRoomsBroken("fountain2", VIRTUALROOMDIRECTIONS.W, "hall7", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("hall2", VIRTUALROOMDIRECTIONS.N, "lore2", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("hall2", VIRTUALROOMDIRECTIONS.E, "playbill1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("hall2", VIRTUALROOMDIRECTIONS.S, "generator1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("hall2", VIRTUALROOMDIRECTIONS.W, "teleport1", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("lore2", VIRTUALROOMDIRECTIONS.N, "hall6", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("lore2", VIRTUALROOMDIRECTIONS.E, "puzzle2", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("lore2", VIRTUALROOMDIRECTIONS.S, "hall2", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("lore2", VIRTUALROOMDIRECTIONS.W, "hall3", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("hall6", VIRTUALROOMDIRECTIONS.N, "generator1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("hall6", VIRTUALROOMDIRECTIONS.E, "fountain1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("hall6", VIRTUALROOMDIRECTIONS.S, "lore2", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("hall6", VIRTUALROOMDIRECTIONS.W, "puzzle1", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("generator1", VIRTUALROOMDIRECTIONS.N, "hall2", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("generator1", VIRTUALROOMDIRECTIONS.E, "hall7", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("generator1", VIRTUALROOMDIRECTIONS.S, "hall6", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("generator1", VIRTUALROOMDIRECTIONS.W, "lore3", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("playbill1", VIRTUALROOMDIRECTIONS.N, "puzzle2", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("playbill1", VIRTUALROOMDIRECTIONS.E, "hall1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("playbill1", VIRTUALROOMDIRECTIONS.S, "hall7", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("playbill1", VIRTUALROOMDIRECTIONS.W, "hall2", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("puzzle2", VIRTUALROOMDIRECTIONS.N, "fountain1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("puzzle2", VIRTUALROOMDIRECTIONS.E, "lore1", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("puzzle2", VIRTUALROOMDIRECTIONS.S, "playbill1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("puzzle2", VIRTUALROOMDIRECTIONS.W, "lore2", VIRTUALROOMDIRECTIONS.E)
    virtualroomset:MakeLinkRigid("puzzle2", VIRTUALROOMDIRECTIONS.S)

    virtualroomset:LinkVirtualRoomsBroken("fountain1", VIRTUALROOMDIRECTIONS.N, "hall7", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRoomsBroken("fountain1", VIRTUALROOMDIRECTIONS.E, "hall5", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("fountain1", VIRTUALROOMDIRECTIONS.S, "puzzle2", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRoomsBroken("fountain1", VIRTUALROOMDIRECTIONS.W, "hall6", VIRTUALROOMDIRECTIONS.E)

    virtualroomset:LinkVirtualRooms("hall7", VIRTUALROOMDIRECTIONS.N, "playbill1", VIRTUALROOMDIRECTIONS.S)
    virtualroomset:LinkVirtualRooms("hall7", VIRTUALROOMDIRECTIONS.E, "fountain2", VIRTUALROOMDIRECTIONS.W)
    virtualroomset:LinkVirtualRooms("hall7", VIRTUALROOMDIRECTIONS.S, "fountain1", VIRTUALROOMDIRECTIONS.N)
    virtualroomset:LinkVirtualRooms("hall7", VIRTUALROOMDIRECTIONS.W, "generator1", VIRTUALROOMDIRECTIONS.E)
end

defs.DeleteLayout = function(virtualroomset)
    defs.internal.ResetAllRepairedLinks(virtualroomset)
end

return defs
