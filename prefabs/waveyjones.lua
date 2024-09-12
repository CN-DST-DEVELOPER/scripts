local assets =
{
    Asset("ANIM", "anim/shadow_wavey_jones.zip"),
    --Asset("ANIM", "anim/shadow_wavey_jones.zip"),
}

local prefabs =
{
    "waveyjones_arm",
    "waveyjones_marker"
}

local assets_hand =
{
    Asset("ANIM", "anim/shadow_wavey_jones_hand.zip"),
}

local prefabs_hand =
{
    "waveyjones_hand_art",
    "shadowhand_fx",
}

local assets_arm =
{

}

local prefabs_arm =
{
    "waveyjones_hand"
}

local handbrain = require("brains/waveyjoneshandbrain")

local function remove_when_scared_ends(inst)
    if inst.AnimState:IsCurrentAnimation("scared") then
        inst:Remove()
    end
end

local function scarearm(arm)
    if arm then
        if arm.hand then
            if arm.hand.handart then
                arm.hand.handart:PushEvent("onscared")
            end
            arm.hand:PushEvent("onscared")
        end
        arm:PushEvent("onscared")
    end
end

local function scareaway(inst)
    inst.persists = false
    if inst and inst:IsValid() then
        scarearm(inst.arm1)

        scarearm(inst.arm2)

        if not inst.AnimState:IsCurrentAnimation("scared") then
            inst.SoundEmitter:PlaySound("dangerous_sea/creatures/wavey_jones/scared")
            inst.AnimState:PlayAnimation("scared")
        end
        inst:ListenForEvent("animover", remove_when_scared_ends)
    end
end

local function test_for_scared(inst, dt)
    if not inst.AnimState:IsCurrentAnimation("scared") then
        local x, y, z = inst.Transform:GetWorldPosition()
        local players = FindPlayersInRange(x, y, z, 0.5)
        if #players > 0 then
            scareaway(inst)
        end
    end
end

local function spawnarm_on_initialize(inst, boat, spacing, entname, left)
    if not boat or not boat:IsValid() then return end

    local bx,by,bz = boat.Transform:GetWorldPosition()
    local x,y,z = inst.Transform:GetWorldPosition()
    local primeangle = boat:GetAngleToPoint(x, y, z) * DEGREES
    local radius = boat.components.hull:GetRadius() - 0.5
    local offset1 = Vector3(radius * math.cos( primeangle + spacing ), 0, -radius * math.sin( primeangle + spacing ))

    local new_arm = SpawnPrefab("waveyjones_arm")
    new_arm.Transform:SetPosition(bx+offset1.x,0,bz+offset1.z)
    local arm_angle = new_arm:GetAngleToPoint(bx, by, bz)
    new_arm.Transform:SetRotation(arm_angle)
    new_arm.jones = inst
    new_arm.left = left
    inst[entname] = new_arm
end

local function waveyjones_initialize(inst)
    local boat = inst.components.entitytracker:GetEntity("boat")
    if not boat then
        return
    end

    inst:DoTaskInTime(0.5, spawnarm_on_initialize, boat, 0.5, "arm1", false)
    inst:DoTaskInTime(0.7, spawnarm_on_initialize, boat, -0.5, "arm2", true)
end

local function playlaugh_delay(inst)
    if inst.AnimState:IsCurrentAnimation("laugh") then
        inst.SoundEmitter:PlaySound("dangerous_sea/creatures/wavey_jones/laugh")
    end
end
local function waveyjones_laugh(inst)
    if not inst.components.timer:TimerExists("laughter") and not inst.AnimState:IsCurrentAnimation("scared") then
        inst.components.timer:StartTimer("laughter", 5)

        inst.AnimState:PlayAnimation("laugh")
        inst:DoTaskInTime(15*FRAMES, playlaugh_delay)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("shadow_wavey_jones")
    inst.AnimState:SetBank("shadow_wavey_jones")
    inst.AnimState:PlayAnimation("idle_in", true)
    inst.AnimState:PushAnimation("idle", true)
    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_WAVES)
    inst.AnimState:SetFinalOffset(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)

    inst.no_wet_prefix = true

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:AddComponent("entitytracker")

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(test_for_scared)

    inst:AddComponent("timer")

    inst:DoTaskInTime(0, waveyjones_initialize)

    inst:ListenForEvent("onremove", scareaway)

    inst:ListenForEvent("laugh", waveyjones_laugh)

    return inst
end

--
local function ClearWaveyJonesTarget(inst)
    if inst.waveyjonestarget then
        TheWorld:removewaveyjonestarget(inst.waveyjonestarget)
        inst.waveyjonestarget = nil
    end
end

local function resetposition(inst)
    if not inst.arm then return end

    local ax, ay, az = inst.arm.Transform:GetWorldPosition()
    local arm_rotation = inst.arm.Transform:GetRotation()

    inst.Transform:SetPosition(ax, ay, az)
    inst.sg:GoToState("in")
    inst.components.timer:StartTimer("reactiondelay", 2)
    inst.Transform:SetRotation(arm_rotation)
    if inst.handart then
        inst.handart.Transform:SetRotation(arm_rotation)
        inst.handart.Transform:SetPosition(ax, ay, az)
        inst.handart.pauserotation = true
    end
end
local rotatearthand = function(inst)
    if not inst.handart or not inst.handart:IsValid() then
        return
    end

    inst.handart.Transform:SetPosition(inst.Transform:GetWorldPosition())

    if not inst.handart.pauserotation and inst.arm then
        local x,y,z = inst.Transform:GetWorldPosition()

        local dist = inst:GetDistanceSqToInst(inst.arm)
        local rotation
        if dist < 0.5 * 0.5 then
            rotation = inst.arm.Transform:GetRotation()
        else
            rotation = inst.arm:GetAngleToPoint(x,y,z)
        end
        inst.handart.Transform:SetRotation( rotation )
    end
end

local function playernear(inst)
    inst:PushEvent("trapped")
end

local function playerfar(inst)
    inst:PushEvent("released")
end

local function waveyjones_hand_initialize(inst)
    local handart = SpawnPrefab("waveyjones_hand_art")
    if inst.left then
        handart.AnimState:SetScale(1,-1)
    end
    handart.sg:GoToState("in")
    inst.handart = handart
    inst.handart.parent = inst
    inst.handart.pauserotation = true
    inst.handart.Transform:SetRotation( inst.Transform:GetRotation() )

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnWallUpdateFn(rotatearthand)

    inst.components.timer:StartTimer("reactiondelay", 2)
end

local function handfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()

    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst, 10, .5)

    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.WAVEYJONES.HAND.WALK_SPEED
    inst:SetStateGraph("SGwaveyjoneshand")

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(0.8,1.2)
    inst.components.playerprox:SetOnPlayerNear(playernear)
    inst.components.playerprox:SetOnPlayerFar(playerfar)

    inst:AddComponent("timer")

    inst:SetBrain(handbrain)

    inst.ClearWaveyJonesTarget = ClearWaveyJonesTarget

    inst:ListenForEvent("onremove", inst.ClearWaveyJonesTarget)

    inst:ListenForEvent("onscared", inst.Remove)

    inst.rotatearthand = rotatearthand
    inst.resetposition = resetposition

    inst:DoTaskInTime(0, waveyjones_hand_initialize)

    return inst
end

--
local HANDART_STATES = {
    "in",
    "idle",
    "moving",
    "premoving",
    "loop_action_anchor_pst",
    "loop_action_anchor",
    "short_action",
    "moving",
    "premoving",
    "trapped",
    "trapped_pst",
    "scared_relocate",
    "scared",
}
local HANDART_GOTO_FNS = {}
for _, state in pairs(HANDART_STATES) do
    HANDART_GOTO_FNS["go_to_"..state] = function(inst)
        inst.sg:GoToState(state)
    end
end

local function spawn_shadowhand_fx(inst)
    local fx = SpawnPrefab("shadowhand_fx")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
end
local function periodic_fx_queue(inst)
    inst:DoTaskInTime(math.random()*0.5, spawn_shadowhand_fx)
end

local function handartfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("shadow_wavey_jones_hand")
    inst.AnimState:SetBank("shadow_wavey_jones_hand")
    inst.AnimState:PlayAnimation("hand_in_loop")

    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_SKYSHADOWS)
    inst.AnimState:SetFinalOffset(2)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)

    inst:AddTag("NOCLICK")
    inst:AddTag("DECOR")

    inst.no_wet_prefix = true

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:SetStateGraph("SGwaveyjoneshand_art")

    inst:ListenForEvent("onscared", HANDART_GOTO_FNS.go_to_scared)

    inst:ListenForEvent("STATE_IN", HANDART_GOTO_FNS.go_to_in)
    inst:ListenForEvent("STATE_IDLE", HANDART_GOTO_FNS.go_to_idle)
    inst:ListenForEvent("STATE_MOVING", HANDART_GOTO_FNS.go_to_moving)
    inst:ListenForEvent("STATE_PREMOVING", HANDART_GOTO_FNS.go_to_premoving)
    inst:ListenForEvent("STATE_LOOP_ACTION_ANCHOR_PST", HANDART_GOTO_FNS.go_to_loop_action_anchor_pst)
    inst:ListenForEvent("STATE_LOOP_ACTION_ANCHOR", HANDART_GOTO_FNS.go_to_loop_action_anchor)
    inst:ListenForEvent("STATE_SHORT_ACTION", HANDART_GOTO_FNS.go_to_short_action)
    inst:ListenForEvent("STATE_TRAPPED", HANDART_GOTO_FNS.go_to_trapped)
    inst:ListenForEvent("STATE_TRAPPED_PST", HANDART_GOTO_FNS.go_to_trapped_pst)
    inst:ListenForEvent("STATE_SCARED_RELOCATE", HANDART_GOTO_FNS.go_to_scared_relocate)

    inst:DoPeriodicTask(2, periodic_fx_queue)

    return inst
end

--
local function waveyjones_arm_initialize(inst)
    local hand = SpawnPrefab("waveyjones_hand")
    local x,y,z = inst.Transform:GetWorldPosition()
    hand.Transform:SetRotation(inst.Transform:GetRotation())
    hand.Transform:SetPosition(x,y,z)
    hand.arm = inst
    hand.sg:GoToState("in")
    hand.left = inst.left

    inst.hand = hand
end

local function armfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst, 10, .5)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:DoTaskInTime(0, waveyjones_arm_initialize)

    inst:ListenForEvent("onscared", inst.Remove)

    return inst
end

--
local function angles_sort(a, b) return a < b end
local function spawnjones(inst,boat)

    local x,y,z = inst.Transform:GetWorldPosition()
    local jones = SpawnPrefab("waveyjones")
    local angle = math.random()*360

    local players = FindPlayersInRange(x, y, z, boat.components.hull:GetRadius(), true)
    local angles = {}
    if #players > 0 then
        for _,player in pairs(players)do
            local px,py,pz = player.Transform:GetWorldPosition()
            table.insert(angles,boat:GetAngleToPoint(px, py, pz))
        end

        local biggest = nil

        table.sort(angles, angles_sort)
        if #angles > 1 then
            for i,subangle in ipairs(angles)do
                local diff = subangle - (angles[i-1] or angles[#angles])
                if diff < 0 then
                    diff = 360 + diff
                end
                if biggest == nil or diff > biggest then
                    biggest = diff
                    angle = angles[i] - diff/2
                end
            end
        elseif #angles == 1 then
            angle = angles[1] + 180
        end
    end
    jones.Transform:SetRotation(angle-90)
    angle = angle * DEGREES
    local radius = boat.components.hull:GetRadius() - 0.5
    local offset = Vector3(radius * math.cos( angle ), 0, -radius * math.sin( angle))

    local bx, _, bz = boat.Transform:GetWorldPosition()
    jones.Transform:SetPosition(bx + offset.x, 0, bz + offset.z)
    jones.components.entitytracker:TrackEntity("boat", boat)

    inst.jones = jones

    inst:ListenForEvent("onremove", function(_)
        inst.jones = nil
        inst.components.timer:StartTimer("respawndelay", TUNING.WAVEYJONES.RESPAWN_TIMER)
        if not inst.jonesremovedcount then
            inst.jonesremovedcount = 0
        end
        inst.jonesremovedcount = inst.jonesremovedcount +1
        if inst.jonesremovedcount >= 3 then
            inst.SoundEmitter:KillSound("creeping")
            inst:Remove()
        end
    end, jones)
end

local function marker_timer_done(inst, data)
    if data.name == "respawndelay" then
        if inst.components.entitytracker:GetEntity("boat") then
            local boat = inst.components.entitytracker:GetEntity("boat")
            local player = FindClosestPlayerToInst(boat,boat.components.hull:GetRadius(),true)
            if player then
                spawnjones(inst,boat)
            else
                inst.components.timer:StartTimer("respawndelay", 1)
            end
        end
    end
end

local function marker_wallupdate(inst, dt)
    local intensity = (inst.components.timer:TimerExists("respawndelay")
            and Remap(inst.components.timer:GetTimeLeft("respawndelay"), TUNING.WAVEYJONES.RESPAWN_TIMER, 0, 0, 1))
        or 1
    inst.SoundEmitter:SetParameter("creeping", "intensity", intensity)
end

local function markerfn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("entitytracker")

    inst:AddComponent("timer")

    inst.components.timer:StartTimer("respawndelay", TUNING.WAVEYJONES.RESPAWN_TIMER)

    inst.SoundEmitter:PlaySound("dangerous_sea/creatures/wavey_jones/appear_LP", "creeping")

    inst:WatchWorldState("phase", function(src,phase)
        if phase ~= "night" then
            if inst.jones then
                scareaway(inst.jones)
            end
            inst.SoundEmitter:KillSound("creeping")
            inst:Remove()
        end
    end)

    inst:ListenForEvent("timerdone", marker_timer_done)

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnWallUpdateFn(marker_wallupdate)

    return inst
end


return  Prefab("waveyjones", fn, assets, prefabs),
        Prefab("waveyjones_hand", handfn,  {}, prefabs_hand),
        Prefab("waveyjones_hand_art", handartfn, assets_hand, {}),
        Prefab("waveyjones_arm", armfn, assets_arm, prefabs_arm),
        Prefab("waveyjones_marker", markerfn, assets, prefabs)