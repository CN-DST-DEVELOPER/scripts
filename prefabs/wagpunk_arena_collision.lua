local assets = {
    Asset("ANIM", "anim/wagpunk_shield_fx.zip"),
}
local prefabs = {
    "wagpunk_arena_collision_oneway",
}
local function AddPlane(triangles, x0, y0, z0, x1, y1, z1)
    table.insert(triangles, x0)
    table.insert(triangles, y0)
    table.insert(triangles, z0)

    table.insert(triangles, x0)
    table.insert(triangles, y1)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, y0)
    table.insert(triangles, z1)

    table.insert(triangles, x1)
    table.insert(triangles, y0)
    table.insert(triangles, z1)

    table.insert(triangles, x0)
    table.insert(triangles, y1)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, y1)
    table.insert(triangles, z1)
end
local function ApplyOffset(value, offset)
    if value < 0 then
        value = value - offset
    elseif value > 0 then
        value = value + offset
    end
    return value
end
local function BuildWagpunkArenaMesh(offset)
    local triangles = {}
    local index_total = #WAGPUNK_ARENA_COLLISION_DATA
    local v0 = WAGPUNK_ARENA_COLLISION_DATA[index_total]
    local index = 1
    for index = 1, index_total do
        local v1 = WAGPUNK_ARENA_COLLISION_DATA[index]
        local x0, z0 = v0[1], v0[2]
        local x1, z1 = v1[1], v1[2]
        if offset then
            x0 = ApplyOffset(x0, offset)
            z0 = ApplyOffset(z0, offset)
            x1 = ApplyOffset(x1, offset)
            z1 = ApplyOffset(z1, offset)
        end
        AddPlane(triangles, x0, 0, z0, x1, 7, z1) --high enuf to contain flying drones

        v0 = v1
    end
    return triangles
end

local function CreateFX()
    local inst = CreateEntity()

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")

    inst.Transform:SetEightFaced()

    inst.AnimState:SetBank("wagpunk_shield_fx")
    inst.AnimState:SetBuild("wagpunk_shield_fx")
    inst.AnimState:SetMultColour(0, 0.25 + 0.5 * math.random(), 0.25 + 0.75 * math.random(), 0.5 + math.random() * 0.5)

    return inst
end

local function CreateFX_TooClose(inst, closestindex)
    local fx = CreateFX()

    fx.AnimState:PlayAnimation("hit_loop")
    fx.AnimState:PushAnimation("hit_pst", false)
    fx:ListenForEvent("animqueueover", fx.Remove)
    fx:ListenForEvent("onremove", function()
        inst.clientbarrierfx = nil
    end)

    -- FIXME(JBK): Make this a projection of the player to the barrier.

    return fx
end

local function CreateFX_Oneshot(inst, closestindex, bias, index_total)
    -- Move around a bit but not too far from the closest.
    local current_index = math.random(-bias, bias + 1) -- Bias the upper with + 1 to combat always looking at previous_index.
    current_index = current_index + closestindex
    if current_index < 1 then
        current_index = current_index + index_total
    elseif current_index > index_total then
        current_index = current_index - index_total
    end

    -- Get a previous for line operations.
    local previous_index = current_index - 1
    if previous_index < 1 then
        previous_index = index_total
    end
    local v0 = WAGPUNK_ARENA_COLLISION_DATA[previous_index]
    local v1 = WAGPUNK_ARENA_COLLISION_DATA[current_index]

    -- Calculate facings.
    local x0, z0 = v0[1], v0[2]
    local x1, z1 = v1[1], v1[2]
    local dz, dx = z1 - z0, x1 - x0
    local angle = math.atan2(-dz, dx)
    local dsq = dx * dx + dz * dz
    local fx = CreateFX()
    fx.Transform:SetRotation(angle * RADIANS - 90)
    fx.AnimState:PlayAnimation(tostring(math.random(3)))
    fx:ListenForEvent("animover", fx.Remove)

    local t = math.random()
    local height = (1 - math.sqrt(math.random())) * 8 -- Bias towards lower values more.
    fx.Transform:SetPosition(Lerp(x0, x1, t), height, Lerp(z0, z1, t))

    fx.entity:SetParent(inst.entity)
end

local function ClearCooldown(inst)
    inst.clientbarrierfxcooldowntask = nil
end

local function UpdateClientFX(inst)
    if ThePlayer then
        local index_total = #WAGPUNK_ARENA_COLLISION_DATA
        local x, y, z = ThePlayer.Transform:GetWorldPosition()
        local cx, cy, cz = inst.Transform:GetWorldPosition()

        local closestindex, closestdsq = 1, math.huge
        for i, v in ipairs(WAGPUNK_ARENA_COLLISION_DATA) do
            local dx, dz = (x - cx) - v[1], (z - cz) - v[2]
            local dsq = dx * dx + dz * dz
            if dsq < closestdsq then
                closestindex = i
                closestdsq = dsq
            end
        end

        local closestdist = math.sqrt(closestdsq)
        local playerdensityamount = math.floor(Lerp(1, 4, 8 / (closestdist + 0.01)))
        for i = 1, playerdensityamount do
            inst:DoTaskInTime((i-1) * (0.1 + math.random() * 0.1), CreateFX_Oneshot, closestindex, 1, index_total) -- Player focused.
        end
        local circleindex = inst.currentclientfxindex
        for i = 1, 4 do
            inst:DoTaskInTime((i-1) * (0.1 + math.random() * 0.1), CreateFX_Oneshot, circleindex, 1, index_total) -- Circling arena.
            circleindex = circleindex + math.random(1, 3)
            if circleindex > index_total then
                circleindex = circleindex - index_total
            end
        end
        inst.currentclientfxindex = circleindex

        --if closestdist < 4 then
        --    if not inst.clientbarrierfxcooldowntask and not inst.clientbarrierfx then
        --        inst.clientbarrierfx = CreateFX_TooClose(inst, closestindex)
        --        inst.clientbarrierfxcooldowntask = inst:DoTaskInTime(15, ClearCooldown)
        --    end
        --end
    end
end

local function UpdateClientFXTick(inst)
    inst:UpdateClientFX()
end

local function OnEntitySleep(inst)
    if inst.updateclientfxtask then
        inst.updateclientfxtask:Cancel()
        inst.updateclientfxtask = nil
    end
end

local function OnEntityWake(inst)
    if inst.updateclientfxtask then
        inst.updateclientfxtask:Cancel()
        inst.updateclientfxtask = nil
    end
    inst.updateclientfxtask = inst:DoPeriodicTask(0.75, UpdateClientFXTick)
end

local CLEARSPOT_ONEOF_TAGS = {"structure", "wall"}
local CLEARSPOT_CANT_TAGS = {"INLIMBO", "NOCLICK", "FX", "irreplaceable"}
local function DestroyEntitiesInBarrier(inst)
    local _world = TheWorld
    local _map = _world.Map
    local thickness = TUNING.WAGPUNK_ARENA_COLLISION_NOBUILD_THICKNESS

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, 40, nil, CLEARSPOT_CANT_TAGS, CLEARSPOT_ONEOF_TAGS)
    for _, ent in ipairs(ents) do
        if ent:IsValid() then
            local ex, ey, ez = ent.Transform:GetWorldPosition()
            if _map:IsXZWithThicknessInWagPunkArenaAndBarrierIsUp(ex, ez, thickness) then
                DestroyEntity(ent, _world)
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.LAND_OCEAN_LIMITS)
    inst.Physics:SetCollisionMask(
        COLLISION.ITEMS,
        COLLISION.CHARACTERS,
		COLLISION.FLYERS,
        COLLISION.GIANTS
    )
    inst.Physics:SetTriangleMesh(BuildWagpunkArenaMesh())

    inst:AddTag("NOBLOCK")
    inst:AddTag("ignorewalkableplatforms")

    inst.entity:SetPristine()
    if not TheNet:IsDedicated() then
        inst.currentclientfxindex = 1
        inst.UpdateClientFX = UpdateClientFX
        inst.OnEntitySleep = OnEntitySleep
        inst.OnEntityWake = OnEntityWake
    end
    if not TheWorld.ismastersim then
        return inst
    end
    inst.persists = false

    inst.DestroyEntitiesInBarrier = DestroyEntitiesInBarrier

    return inst
end

-----------------------------------------------------

local function TryToResolveGoodSpot(ent, map, ax, az, oneway_size)
    local x, y, z = ent.Transform:GetWorldPosition()
    local dx, dz = x - ax, z - az
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist > 0 then
        dx = dx / dist
        dz = dz / dist
        local perfectdisttoinside = ent:GetPhysicsRadius(0) * 2 + oneway_size + 0.1 -- Small pad to make it not touch the other physics wall on teleporting.
        local testx, testz, disttoinside
        for distbonus = 0, 4, 2 do
            disttoinside = perfectdisttoinside + distbonus
            -- First test the NESW directions.
            testx, testz = x, z + disttoinside
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            testx, testz = x + disttoinside, z
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            testx, testz = x, z - disttoinside
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            testx, testz = x - disttoinside, z
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            -- Now the diagonals starting with NE.
            testx, testz = x + disttoinside, z + disttoinside
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            testx, testz = x + disttoinside, z - disttoinside
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            testx, testz = x - disttoinside, z - disttoinside
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
            testx, testz = x - disttoinside, z + disttoinside
            if map:IsPointInWagPunkArena(testx, 0, testz) then
                return testx, testz
            end
        end
    end
    return nil, nil
end
local function GetIn(ent, oneway_size)
    ent.oncollide_onewaytask = nil
    if ent.components.locomotor and ent.components.locomotor.pathcaps and ent.components.locomotor.pathcaps.ignoreLand then
        return
    end
    local map = TheWorld.Map
    local ax, az = map:GetWagPunkArenaCenterXZ()
    if ax then
        local x, z = TryToResolveGoodSpot(ent, map, ax, az, oneway_size)
        if x then
            if ent.Physics then
                ent.Physics:Teleport(x, 0, z)
            else
                ent.Transform:SetPosition(x, 0, z)
            end
        else -- We failed to find a good spot eject at arena center.
            if ent.Physics then
                ent.Physics:Teleport(ax, 0, az)
            else
                ent.Transform:SetPosition(ax, 0, az)
            end
        end
        if ent.sg and ent.sg:HasStateTag("boathopping") then
            -- NOTES(JBK): Pushing an event here is out of order for timing with boathopping so we will handle the event directly as it has higher priority for this state.
            ent.sg:HandleEvent("cancelhop")
        end
    end
end

local function OnCollide_oneway(inst, other)
    if inst:IsValid() and other:IsValid() then
        if not other.oncollide_onewaytask then -- Get off of physics thread.
            other.oncollide_onewaytask = other:DoTaskInTime(0, GetIn, inst.oneway_size)
        end
    end
end

local function fn_oneway()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.LAND_OCEAN_LIMITS)
    inst.Physics:SetCollisionMask(
        COLLISION.ITEMS,
        COLLISION.CHARACTERS,
		COLLISION.FLYERS,
        COLLISION.GIANTS
    )
    inst.oneway_size = 0.4 -- A size of 0.5 can result in a corner that touches the normal tile boundary so keep it below that.
    inst.Physics:SetTriangleMesh(BuildWagpunkArenaMesh(inst.oneway_size))

    inst:AddTag("NOBLOCK")
    inst:AddTag("ignorewalkableplatforms")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    inst.persists = false

    inst.Physics:SetCollisionCallback(OnCollide_oneway)

    return inst
end

return Prefab("wagpunk_arena_collision", fn, assets, prefabs),
    Prefab("wagpunk_arena_collision_oneway", fn_oneway)