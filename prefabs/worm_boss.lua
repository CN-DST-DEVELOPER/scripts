
local assets =
{
    Asset("ANIM", "anim/worm_boss.zip"),
    Asset("ANIM", "anim/worm_boss_segment.zip"),
    Asset("ANIM", "anim/worm_boss_segment_2_build.zip"),
    Asset("SCRIPT", "scripts/prefabs/worm_boss_util.lua"),
}

local prefabs =
{
    "worm_boss_dirt",
    "worm_boss_dirt_ground_fx",
    "worm_boss_head",
    "worm_boss_segment",
}

-----------------------------------------------------------------------------------------------------------------------

local WORMBOSS_UTILS = require("prefabs/worm_boss_util")
local easing = require("easing")

-----------------------------------------------------------------------------------------------------------------------

SetSharedLootTable("worm_boss",
{
    { "monstermeat",  1.00 },
    { "monstermeat",  1.00 },
    { "monstermeat",  1.00 },
    { "monstermeat",  0.66 },
    { "monstermeat",  0.66 },
    { "wormlight",    1.00 },
})

-----------------------------------------------------------------------------------------------------------------------

local function GenerateLoot(inst, pos)
    local loottable = {
        boneshard = 25,
        rocks = 20,
        flint = 15,
        nitre = 15,
        monstermeat = 15,
        goldnugget = 4,
        slurtle_shellpieces = 2,
        tentaclespots = 2,
        lightbulb = 2,
        wormlight = 2,
        guano = 2,
        redgem = 2,
        bluegem = 2,
        purplegem = 2,
        trinket_17 = 1,
        trinket_12 = 1,
        orangegem = 1,
        yellowgem = 1,
        greengem = 1,
        thulecite = 1,
        fossil_piece = 1,
    }

    local choice = weighted_random_choice(loottable)

    if choice ~= nil then
        inst.components.lootdropper:FlingItem(SpawnPrefab(choice), pos)
    end
end

local SHAKE_DIST = 40

local RETARGET_MUST_TAGS  = { "_combat" }
local RETARGET_CANT_TAGS  = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }
local RETARGET_ONEOF_TAGS = { "character", "animal", "monster" }

local function RetargetFn(inst)
    local head = next(inst.chunks) ~= nil and inst.chunks[#inst.chunks].dirt_start or nil

    local target = FindEntity(
        head or inst,
        TUNING.WORM_BOSS_TARGET_DIST,
        function(guy) return inst.components.combat:CanTarget(guy) end,
        RETARGET_MUST_TAGS,
        RETARGET_CANT_TAGS,
        RETARGET_ONEOF_TAGS
    )

    return target
end

local function KeepTargetFn(inst, target)
    if not inst:IsValid() then -- FIXME(DiogoW): Find out why combat is updating after we got removed...
        return false
    end

    return
        (inst.targettime == nil or (GetTime() - inst.targettime) <= 20)
        and inst.components.combat:CanTarget(target)
        and inst:IsNear(target, TUNING.WORM_BOSS_TARGET_DIST)
end

local function NewTarget(inst, data)
    if data.target ~= data.oldtarget then
        inst.targettime = GetTime()
    end
end

local function OnAttacked(inst,data)
    if inst.components.combat.target and inst.components.combat.target:HasTag("player") then
        if inst:GetDistanceSqToInst(inst.components.combat.target) < 20*20 then
            return
        end
    end

    if data.attacker and data.attacker:HasTag("player") then
        inst.components.combat:SetTarget(data.attacker)
    end
end

local function OnUpdate(inst, dt)
    if #inst.chunks < 1 then
        WORMBOSS_UTILS.CreateNewChunk(inst, inst:GetPosition())
    end

    for _, chunk in ipairs(inst.chunks) do
        WORMBOSS_UTILS.UpdateChunk(inst, chunk, dt)
    end
end

-----------------------------------------------------------------------------------------------------------------------

local DECAY_THORNS_EFFECT_TIME = 3
local NUM_THORNS_TO_KNOCKBACK = 3

local function ProcessThornDamage(inst, target)
    inst.SoundEmitter:PlaySound("rifts4/worm_boss/spike_slice")

    target.components.combat:GetAttacked(inst, TUNING.WORM_BOSS_SPINES)

    local owner = inst.worm or inst
    owner._thorns_targets = owner._thorns_targets or {}

    local targets = owner._thorns_targets

    local currenttime = GetTime()

    -- Limit hits... do knockback.
    if targets[target] == nil then
        targets[target] = { [currenttime] = true }
    else
        targets[target][currenttime] = true
    end

    for time, _ in pairs(shallowcopy(targets[target])) do
        if currenttime > (time + DECAY_THORNS_EFFECT_TIME) then
            targets[target][time] = nil
        end
    end

    if GetTableSize(targets[target]) >= NUM_THORNS_TO_KNOCKBACK then
        targets[target] = nil

        WORMBOSS_UTILS.Knockback(inst, target)
    end
end

-----------------------------------------------------------------------------------------------------------------------

local function OnDeath(inst, data)
    inst.state = WORMBOSS_UTILS.STATE.DEAD

    if inst.new_crack ~= nil then
        inst.new_crack:Remove()
        inst.new_crack= nil
    end

    local freehead  = false  -- The regular head is present.
    local headchunk = nil    -- The head is in the a segmented form.

    for _, chunk in ipairs(inst.chunks) do
        if chunk.lastsegment ~= nil then
            chunk.lastsegment:Remove()
        end
        if chunk.dirt_start ~= nil and chunk.dirt_start:IsValid() then
            chunk.dirt_start:AddTag("notarget")
            chunk.dirt_start.AnimState:PlayAnimation("dirt_idle")
            chunk.dirt_start.persists = false
        end

        if chunk.dirt_end ~= nil and chunk.dirt_end:IsValid() then
            chunk.dirt_end:AddTag("notarget")
            chunk.dirt_end.AnimState:PlayAnimation("dirt_idle")
            chunk.dirt_end.persists = false
        end

        for _, segment in ipairs(chunk.segments) do
            if segment.head then
                headchunk = chunk
                break
            end
        end
        if chunk.head then
           freehead = true
        end
    end

    inst.headlootdropped = nil
    if inst.head then
        inst.headlootdropped = Vector3(inst.head.Transform:GetWorldPosition())
    elseif inst.createnewchunktask then
        inst.headlootdropped = inst.createnewchunktask._target_pt
    elseif inst.chunks and inst.chunks[#inst.chunks] and inst.chunks[#inst.chunks].groundpoint_start then
        inst.headlootdropped = inst.chunks[#inst.chunks].groundpoint_start
    end

    if headchunk ~= nil then
       WORMBOSS_UTILS.SpawnAboveGroundHeadCorpse(inst, headchunk)
    elseif freehead and inst.head ~= nil then
       inst.head:PushEvent("death")

    else
       WORMBOSS_UTILS.SpawnUnderGroundHeadCorpse(inst)
    end

    inst.current_death_chunk = math.max(1, #inst.chunks - 1)
end

local function _PlayDirstPstSlowAnim(dirt)
    dirt.AnimState:PlayAnimation("dirt_pst_slow")
end

local SEGMENT_ERODE_TIME = 6

local function OnDeathEnded(inst)
    if inst.devoured then
        WORMBOSS_UTILS.SpitAll(inst, nil, true)
    end

    if inst.head ~= nil then
        inst.head:PushEvent("death_ended")
    end

    for _, chunk in ipairs(inst.chunks) do
        for i,segment in ipairs(chunk.segments)do
            if not segment.AnimState:IsCurrentAnimation("segment_death_pst") then
                segment.AnimState:PlayAnimation("segment_death_pst")
            end
        end

        if chunk.dirt_start ~= nil then
            chunk.dirt_start:DoTaskInTime(math.random()*3 + 4, _PlayDirstPstSlowAnim)
        end

        if chunk.dirt_end ~= nil then
            chunk.dirt_end:DoTaskInTime(math.random()*3 + 4, _PlayDirstPstSlowAnim)
        end

        --for _, segment in ipairs(chunk.segments) do
            --ErodeAway(segment, SEGMENT_ERODE_TIME)
        --end
    end


    inst.Transform:SetPosition(inst.chunks[#inst.chunks].dirt_start.Transform:GetWorldPosition()) -- For inventory:DropEverything position.

    inst.components.inventory:DropEverything(true)
    inst.components.lootdropper:DropLoot()
    inst.headlootdropped = nil

    inst:Remove()
end

-----------------------------------------------------------------------------------------------------------------------

local function SerializePosition(pos)
    return pos ~= nil and { x = pos.x, z = pos.z } or nil
end

local function DeserializePosition(data)
    return Vector3(data.x, 0, data.z)
end

local function OnSave(inst, data)
    data.state = inst.state

    if inst.state == WORMBOSS_UTILS.STATE.DEAD then

        if inst.headlootdropped then
            data.headlootdropped =SerializePosition(inst.headlootdropped)
        end

        data.lootspots = {}
        for i, chunk in ipairs(inst.chunks) do
            for s,segment in ipairs(chunk.segments)do
                if not segment:IsInLimbo() and not segment.AnimState:IsCurrentAnimation("segment_death_pst") then
                    table.insert(data.lootspots,SerializePosition(Vector3(segment.Transform:GetWorldPosition()) ))
                end
            end
        end

    else
        if inst.createnewchunktask ~= nil   then
            data.new_chunk_pos = SerializePosition(inst.createnewchunktask._target_pt)
        end

        if #inst.chunks <= 1 then
            return -- Not really worth saving any chunk...
        end

        data.chunks = {}
        data.lootspots = {}

        for i, chunk in ipairs(inst.chunks) do
            local savechunk = {}

            savechunk.groundpoint_start = SerializePosition(chunk.groundpoint_start)
            savechunk.groundpoint_end   = SerializePosition(chunk.groundpoint_end  )

            table.insert(data.chunks, savechunk)
        end
    end
end

local function OnLoad(inst, data)

    if data == nil then
        return
    end

    inst:SetState(data.state)

    if inst.state == WORMBOSS_UTILS.STATE.DEAD then
        -- all the prefabs don't persist, just spawning the unspawned loot in post pass, then removing.
        return
    end

    local headchunk = nil

    if data.chunks ~= nil then
        local head = data.new_chunk_pos == nil and #data.chunks or nil -- The head is always the last chunk, if it exist...
        local tail = #data.chunks > WORMBOSS_UTILS.WORM_LENGTH and 1 or nil -- The tail is always the first chunk, when it's complete.

        for i, chunkdata in ipairs(data.chunks) do
            local newchunk = WORMBOSS_UTILS.CreateNewChunk(inst, DeserializePosition(chunkdata.groundpoint_start), true)

            if chunkdata.groundpoint_end ~= nil then
                newchunk.groundpoint_end = DeserializePosition(chunkdata.groundpoint_end)
            end

            if i == tail then
                newchunk.lastrun = true

                -- Create the things that would be there if the chunk is a tail.
                WORMBOSS_UTILS.SpawnDirt(inst, newchunk, newchunk.groundpoint_end, false, true)
                newchunk.dirt_start:Remove()
            end

            if i == head then
                headchunk = newchunk
            else
                newchunk.state = WORMBOSS_UTILS.CHUNK_STATE.MOVING

                -- Update the chunks until we have a regular chunk or we have turned into a tail prefab.
                while not newchunk.loopcomplete and newchunk.tail == nil do
                    WORMBOSS_UTILS.UpdateChunk(inst, newchunk, FRAMES, true)
                end
            end
        end
    end

    if data.new_chunk_pos ~= nil then
        WORMBOSS_UTILS.SetCreateChunkTask(inst, DeserializePosition(data.new_chunk_pos))
    end

    if headchunk ~= nil then
        WORMBOSS_UTILS.EmergeHead(inst, headchunk, true) -- Deferred head creation because the head emergion changes the worm state.
    end
end


local function OnLoadPostPass(inst, newents, data)
    if data then
        if data.lootspots then
            for i,spot in ipairs(data.lootspots) do
                local pos = DeserializePosition(spot)
                GenerateLoot(inst, pos)
                GenerateLoot(inst, pos)
                GenerateLoot(inst, pos)
            end
        end
        if data.headlootdropped then
            local pos = DeserializePosition(data.headlootdropped)
            inst.Transform:SetPosition(pos.x,pos.y,pos.z)
            inst.components.lootdropper:DropLoot()
            inst.components.inventory:DropEverything(true)
        end
    end
    if inst.state == WORMBOSS_UTILS.STATE.DEAD then
        inst:Remove()
    end
end

-----------------------------------------------------------------------------------------------------------------------

local function SetState(inst, state)
    if inst.state ~= WORMBOSS_UTILS.STATE.DEAD then
        inst.state = state
    end
end

local function OnRemoveEntity(inst)
    if inst.segment_pool ~= nil then
        for i, v in ipairs(inst.segment_pool) do
            v:Remove()
        end

        inst.segment_pool = {}
    end

    if inst.components.health:IsDead() then
        return -- Let the death logic remove the chunks.
    end

    if inst.new_crack ~= nil then
        inst.new_crack:Remove()
        inst.new_crack= nil
    end

    for _, chunk in ipairs(inst.chunks) do
        if chunk.lastsegment ~= nil then
            chunk.lastsegment:Remove()
        end

        if chunk.dirt_start ~= nil then
            chunk.dirt_start:Remove()
        end

        if chunk.dirt_end ~= nil then
            chunk.dirt_end:Remove()
        end

        if chunk.head ~= nil then
            chunk.head:Remove()
        end

        if chunk.tail ~= nil then
            chunk.tail:Remove()
        end

        for _, segment in ipairs(chunk.segments) do
            segment:Remove()
        end
    end
end

local OFFSCREEN_REMOVAL_DELAY = 30

local function Worm_TestForRemoval(inst)
    if inst._sleeptime == nil or (GetTime() - inst._sleeptime <= OFFSCREEN_REMOVAL_DELAY) then
        return
    end

    for _, chunk in ipairs(inst.chunks) do
        if chunk.dirt_start ~= nil and chunk.dirt_start.entity:IsAwake() then
            return
        end

        if chunk.dirt_end ~= nil and chunk.dirt_end.entity:IsAwake() then
            return
        end
    end

    inst:Remove()
end

local function Worm_OnEntitySleep(inst)
    if inst.sleeptask ~= nil then
        inst.sleeptask:Cancel()
        inst.sleeptask = nil
    end

    inst._sleeptime = GetTime()

    inst.sleeptask = inst:DoPeriodicTask(5, Worm_TestForRemoval, OFFSCREEN_REMOVAL_DELAY)
end

local function Worm_OnEntityWake(inst)
    inst._sleeptime = nil

    if inst.sleeptask ~= nil then
        inst.sleeptask:Cancel()
        inst.sleeptask = nil
    end
end

-----------------------------------------------------------------------------------------------------------------------

local function Worm_GetSegmentFromPool(inst)
    local segment = table.remove(inst.segment_pool)

    if segment == nil then
        segment = SpawnPrefab("worm_boss_segment")
    else
        segment:Restart()
    end

    return segment
end

local function Worm_ReturnSegmentToPool(inst, segment)
    segment:RemoveFromScene()
    segment:SetHighlightOwners(nil, nil)

    table.insert(inst.segment_pool, segment)
end

local function PushMusic(inst)
    if ThePlayer == nil then
        inst._playingmusic = false
    elseif ThePlayer:IsNear(inst, inst._playingmusic and 40 or 20) then
        inst._playingmusic = true
        ThePlayer:PushEvent("triggeredevent", { name = "worm_boss" })
    elseif inst._playingmusic and not ThePlayer:IsNear(inst, 50) then
        inst._playingmusic = false
    end
end
local function hounded_overridelocation(inst,pt)
    local newpt = FindWalkableOffset(pt, math.random()* TWOPI, math.random()*6+8, 16, nil, true)
    return newpt + pt
end
-----------------------------------------------------------------------------------------------------------------------

local function fn() -- FIXME(DiogoW): Can this one be a CLASSIFIED/non-networked prefab?
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:AddPhysics() -- For loot drop position.

    inst:AddTag("NOCLICK")
    inst:AddTag("INLIMBO")
    inst:AddTag("NOBLOCK")
    inst:AddTag("groundpound_immune")
    inst:AddTag("worm_boss_piece")
    inst:AddTag("epic")
    inst:AddTag("wet")

    inst:SetPhysicsRadiusOverride(1.15)
    inst.Physics:SetActive(false)

    inst.entity:SetPristine()


    if not TheNet:IsDedicated() then
        inst._playingmusic = false
        inst:DoPeriodicTask(1, PushMusic, 0)
    end

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_bank  = "worm_boss"
    inst.scrapbook_build = "worm_boss"
    inst.scrapbook_anim  = "head_idle_loop"

    inst.child_scale = 1
    inst.chunks = {}
    inst.segment_pool = {}

    inst.SetState = SetState
    inst.GetSegmentFromPool = Worm_GetSegmentFromPool
    inst.ReturnSegmentToPool = Worm_ReturnSegmentToPool

    inst:SetState(WORMBOSS_UTILS.STATE.EMERGE)

    inst:AddComponent("timer")

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("worm_boss")

    inst:AddComponent("inventory")
    inst.components.inventory:DisableDropOnDeath()

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.WORM_BOSS_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.WORM_BOSS_DAMAGE)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(OnUpdate)

    inst._ondeath = OnDeath
    inst._ondeathended = OnDeathEnded

    inst:ListenForEvent("death", inst._ondeath)
    inst:ListenForEvent("death_ended", inst._ondeathended)
    inst:ListenForEvent("newcombattarget", NewTarget)
    inst:ListenForEvent("attacked", OnAttacked)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass
    inst.hounded_overridelocation = hounded_overridelocation

    inst.OnEntitySleep = Worm_OnEntitySleep
    inst.OnEntityWake = Worm_OnEntityWake

    inst.OnRemoveEntity = OnRemoveEntity

    return inst
end

-----------------------------------------------------------------------------------------------------------------------

local function OnSyncOwnerDirty(inst)
    inst:OnSetHighlightOwners(inst.syncowner1:value(), inst.syncowner2:value())
end

function HighlightHandler_OnRemoveEntity(inst)
    for _, owner in pairs(inst._owners) do
        if owner.components.colouradder ~= nil then
            owner.components.colouradder:DetachChild(inst)
        end

        if owner.highlightchildren ~= nil then
            table.removearrayvalue(owner.highlightchildren, inst)
        end
    end
end

function SetHighlightOwners(inst, owner1, owner2)
    if inst.syncowner1 ~= nil then
        inst.syncowner1:set(owner1)
    end

    if inst.syncowner2 ~= nil then
        inst.syncowner2:set(owner2)
    end

    inst:OnSetHighlightOwners(owner1, owner2)
end

local function HighlightHandler_SetOwner(inst, index, owner)
    if inst._owners[index] ~= nil then
        if not TheNet:IsDedicated() then
            inst.AnimState:SetHighlightColour()

            table.removearrayvalue(inst._owners[index].highlightchildren, inst)
        end

        if inst._owners[index].components.colouradder ~= nil then
            inst._owners[index].components.colouradder:DetachChild(inst)
        end
    end

    inst._owners[index] = owner ~= nil and owner:IsValid() and owner or nil

    if inst._owners[index] ~= nil then
        if not TheNet:IsDedicated() then
            if inst._owners[index].highlightchildren == nil then
                inst._owners[index].highlightchildren = { inst }
            else
                table.insert(inst._owners[index].highlightchildren, inst)
            end
        end

        if inst._owners[index].components.colouradder ~= nil then
            inst._owners[index].components.colouradder:AttachChild(inst)
        end
    end
end

function OnSetHighlightOwners(inst, owner1, owner2)
    HighlightHandler_SetOwner(inst, inst.syncowner1, owner1)
    HighlightHandler_SetOwner(inst, inst.syncowner2, owner2)

    if not TheNet:IsDedicated() then
        inst.client_forward_target = owner1 or owner2
    end
end

local function AddHighlightHandler(inst)
    if inst.Network == nil then
        return
    end

    inst._owners = {}

    inst.syncowner1 = net_entity(inst.GUID, "syncowner1", "hightlighownerdirty")
    inst.syncowner2 = net_entity(inst.GUID, "syncowner2", "hightlighownerdirty")

    inst.OnSetHighlightOwners = OnSetHighlightOwners

    inst:ListenForEvent("onremove", HighlightHandler_OnRemoveEntity)

    if not TheWorld.ismastersim then
        inst:ListenForEvent("hightlighownerdirty", OnSyncOwnerDirty)
    else
        inst.SetHighlightOwners = SetHighlightOwners
    end
end

local function headfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddPhysics() -- For loot drop position.
    inst.entity:AddNetwork()

    inst:AddTag("groundpound_immune")
    inst:AddTag("worm_boss_piece")

    inst.Transform:SetSixFaced()

    inst:SetPhysicsRadiusOverride(1.15)
    inst.Physics:SetActive(false)

    inst.AnimState:SetBank("worm_boss")
    inst.AnimState:SetBuild("worm_boss")
    inst.AnimState:PlayAnimation("head_idle_loop")

    inst.AnimState:SetFinalOffset(-3)

    AddHighlightHandler(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.head = true

    inst:AddComponent("lootdropper") -- Used in worm_boss_util.lua


    inst:SetStateGraph("SGworm_boss_head")

    inst.persists = false

    return inst
end

-----------------------------------------------------------------------------------------------------------------------

local function tailfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddPhysics() -- For loot drop position.
    inst.entity:AddNetwork()

    inst:AddTag("groundpound_immune")
    inst:AddTag("worm_boss_piece")

    inst.Transform:SetSixFaced()

    inst:SetPhysicsRadiusOverride(1.15)
    inst.Physics:SetActive(false)

    inst.AnimState:SetBank("worm_boss")
    inst.AnimState:SetBuild("worm_boss")
    inst.AnimState:PlayAnimation("tail_idle_loop")
    inst.AnimState:SetFinalOffset(-3)

    AddHighlightHandler(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.tail = true

    inst:AddComponent("lootdropper") -- Used in worm_boss_util.lua

    inst:SetStateGraph("SGworm_boss_tail")

    inst.persists = false

    return inst
end

-----------------------------------------------------------------------------------------------------------------------

local THORNS_AOE_RADIUS = 2
local THORNS_AOE_MUST_TAGS  =  { "_combat" }
local THRORNS_AOE_CANT_TAGS =  { "worm_boss_piece", "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

local AOE_DAMAGE_RADIUS_PADDING = 3

local function DoThornDamage(inst)
    if not inst.spiked then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    for _, target in ipairs(TheSim:FindEntities(x, y, z, THORNS_AOE_RADIUS + AOE_DAMAGE_RADIUS_PADDING, THORNS_AOE_MUST_TAGS, THRORNS_AOE_CANT_TAGS)) do
        if target ~= inst and
            not inst.ignore[target] and
            target:IsValid() and not target:IsInLimbo() and
            not (target.components.health ~= nil and target.components.health:IsDead())
        then
            local range = THORNS_AOE_RADIUS + target:GetPhysicsRadius(0)
            local x1, y1, z1 = target.Transform:GetWorldPosition()
            local dx = x1 - x
            local dz = z1 - z

            if (dx * dx + dz * dz) < (range * range) and target.components.combat:CanBeAttacked() then
                inst.ignore[target] = true
                ProcessThornDamage(inst, target)
            end
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------

local function Segment_Restart(inst)
    --V2C: possible that client may get the same piece recycled back in on the same packet
    inst.Transform:ClearTransformationHistory()

    inst.Transform:SetScale(1, 1, 1)

    inst.AnimState:SetBank("worm_boss")
    inst.AnimState:SetBuild("worm_boss_segment")
    inst.AnimState:PlayAnimation("segment")

    inst.AnimState:SetFinalOffset(-3)
    inst.AnimState:SetHighlightColour()

    inst.ignore = {}

    inst.worm = nil
    inst.tail = nil
    inst.head = nil
    inst.build = nil
    inst.spiked = nil
    inst.segtime = nil
    inst.percentdist = nil
    inst.scalegoal = nil
    inst.heightgoal = nil
    inst.setheight = nil
    inst.client_forward_target = nil

    inst._speed:set(0)
    inst._segtime:set(0)

    inst:ReturnToScene()
end

local function Segment_OnAnimOver(inst)
    if inst.AnimState:IsCurrentAnimation("tail") or inst.AnimState:IsCurrentAnimation("head") then
        if inst.worm ~= nil and inst.worm.segment_pool ~= nil then
            inst.worm:ReturnSegmentToPool(inst)
        else
            inst:Remove()
        end

    elseif inst.AnimState:IsCurrentAnimation("segment_death") then
        inst.AnimState:PlayAnimation("segment_death_pst")
        GenerateLoot(inst)
        GenerateLoot(inst)
        GenerateLoot(inst)

    elseif inst.AnimState:IsCurrentAnimation("segment_death_pst") then
        ErodeAway(inst, SEGMENT_ERODE_TIME)
    end
end

local function Segment_UpdatePredictionData(inst, speed, segtime)
    inst._speed:set(speed)
    inst._segtime:set(segtime)
end

local SEGMENT_PREDICTED_FRAMES = 3

local function CLIENT_Segment_OnUpdate(inst, dt)
    if inst._hit and inst._hit > 0 then
        local scale = Remap(inst._hit, 1, 0, 0.75, 1)

        inst.Transform:SetScale(scale, scale, scale)

        inst._hit = inst._hit - (dt * 5)
    end

    if inst._predictionsleft <= 0 then
        return
    end

    inst._predictionsleft = inst._predictionsleft - 1

    local speed = inst._speed:value()

    if speed <= 0 or inst._groundpoint_start == nil then
        return
    end

    inst._segtime:set_local(math.min(inst._segtime:value() + (dt * speed), WORMBOSS_UTILS.MAX_SEGTIME))

    local time = inst._segtime:value() / WORMBOSS_UTILS.MAX_SEGTIME

    local tmod = easing.inOutQuad(time, 0, 1, 1)
    local pdelta = inst._groundpoint_end - inst._groundpoint_start

    local pf = (pdelta * tmod) + inst._groundpoint_start

    inst.Transform:SetPosition(pf:Get())

    local anim =
        (inst.AnimState:IsCurrentAnimation("head") and "head") or
        (inst.AnimState:IsCurrentAnimation("tail") and "tail") or
        "segment"

    local adjust = inst._segtime:value() < .98 and speed > .5 and FRAMES or 0

    inst.AnimState:SetPercent(anim, time - adjust)
end

local function OnSegTimeDirty(inst)
    inst._predictionsleft = SEGMENT_PREDICTED_FRAMES
end

local function OnDirtPositionDirty(inst)
    inst._groundpoint_start = Vector3(inst._dirt_start_x:value(), 0, inst._dirt_start_z:value())
    inst._groundpoint_end   = Vector3(inst._dirt_end_x:value(),   0, inst._dirt_end_z:value()  )
end

local function OnHitEvent(inst)
    inst._hit = 1
end

local function segmentfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(4, 2)

    inst:AddTag("groundpound_immune")
    inst:AddTag("worm_boss_piece")
    inst:AddTag("NOINTERPOLATE")

    inst.Transform:SetEightFaced()

    inst.AnimState:SetBank("worm_boss")
    inst.AnimState:SetBuild("worm_boss_segment")
    inst.AnimState:PlayAnimation("segment")

    inst.AnimState:SetFinalOffset(-3)

    inst:SetPrefabNameOverride("worm_boss") -- For death announce.

    AddHighlightHandler(inst)

    inst._segtime = net_float(inst.GUID, "worm_boss_segment._segtime", "segtimedirty")
    inst._segtime:set(0)

    inst._speed = net_float(inst.GUID, "worm_boss_segment._speed")
    inst._speed:set(0)

    inst._dirt_start_x = net_float(inst.GUID, "worm_boss_segment._dirt_start_x", "dirtpositiondirty")
    inst._dirt_start_z = net_float(inst.GUID, "worm_boss_segment._dirt_start_z", "dirtpositiondirty")
    inst._dirt_end_x   = net_float(inst.GUID, "worm_boss_segment._dirt_end_x"  , "dirtpositiondirty")
    inst._dirt_end_z   = net_float(inst.GUID, "worm_boss_segment._dirt_end_z"  , "dirtpositiondirty")

    inst.hitevent = net_event(inst.GUID, "worm_boss_segment.hitevent")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst._predictionsleft = 0
        inst._hit = 0

        inst:AddComponent("updatelooper")
        inst.components.updatelooper:AddOnUpdateFn(CLIENT_Segment_OnUpdate)
        
        inst:ListenForEvent("segtimedirty", OnSegTimeDirty)
        inst:ListenForEvent("dirtpositiondirty", OnDirtPositionDirty)
        inst:ListenForEvent("worm_boss_segment.hitevent", OnHitEvent)

        return inst
    end

    inst.ignore = {}

    inst.DoThornDamage = DoThornDamage
    inst.OnAnimOver = Segment_OnAnimOver
    inst.Restart = Segment_Restart
    inst.UpdatePredictionData = Segment_UpdatePredictionData

    inst:AddComponent("lootdropper")

    inst:ListenForEvent("animover", inst.OnAnimOver)

    inst.persists = false

    return inst
end

-----------------------------------------------------------------------------------------------------------------------

local function Dirt_EmergeHead(inst)
        inst:RemoveTag("notarget")
        inst.components.groundpounder:GroundPound()
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, 1, inst, SHAKE_DIST)
        WORMBOSS_UTILS.ToggleOnPhysics(inst)
        WORMBOSS_UTILS.EmergeHead(inst.worm, inst.chunk)

        inst:dirt_playanimation("dirt_emerge")
end

local function Dirt_OnAnimOver(inst)

    if inst.AnimState:IsCurrentAnimation("dirt_emerge") then
        inst:dirt_playanimation("dirt_idle")

    elseif inst.AnimState:IsCurrentAnimation("dirt_pre") then
        inst.components.groundpounder:GroundPound()
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, 1, inst, SHAKE_DIST)
        inst:dirt_playanimation("dirt_idle")

    elseif inst.AnimState:IsCurrentAnimation("dirt_emerge_loop_pre") then
        inst:dirt_playanimation("dirt_emerge_loop", true)
        inst:DoTaskInTime(4,function() Dirt_EmergeHead(inst) end)
        inst:DoTaskInTime(2,function()
            if inst.worm then
                inst.worm.new_crack = SpawnPrefab("worm_boss_dirt_ground_fx")
                local pt = Vector3(inst.Transform:GetWorldPosition())
                inst.worm.new_crack.Transform:SetPosition(pt.x, 0, pt.z)
            end
        end)
    elseif inst.AnimState:IsCurrentAnimation("dirt_pre_slow") then
        Dirt_EmergeHead(inst)
    elseif inst.AnimState:IsCurrentAnimation("dirt_segment_in_pre") then
        if inst.chunk ~= nil and inst.chunk.ease > 0 then
            inst:dirt_playanimation("dirt_segment_in_pst")
        end

    elseif inst.AnimState:IsCurrentAnimation("dirt_pst") or inst.AnimState:IsCurrentAnimation("dirt_pst_slow") then
        inst:Remove()
    end
end

local function Dirt_OnAttacked(inst)
    if inst.chunk ~= nil and inst.worm.state ~= WORMBOSS_UTILS.STATE.DEAD then
        inst.chunk.hit = 1
        if inst.chunk.tail then
            inst.chunk.tail:PushEvent("attacked")
        end
    end
end

local function Dirt_DamageRedirectFn(inst, attacker, damage, weapon, stimuli)
    -- If attacker is close, and chunk is moving, do thorn damage.
    if inst.worm ~= nil and
        (inst.worm.head == nil or inst.chunk.head ~= inst.worm.head) and
        (inst.worm.tail == nil or inst.chunk.tail ~= inst.worm.tail) and
        WORMBOSS_UTILS.ShouldDoSpikeDamage(inst.chunk)
    then
        local x, y, z = inst.Transform:GetWorldPosition()

        if attacker:IsValid() and not attacker:IsInLimbo() and not (attacker.components.health ~= nil and attacker.components.health:IsDead()) and attacker.components.combat then
            local range = TUNING.DEFAULT_ATTACK_RANGE + 0.5 + attacker:GetPhysicsRadius(0)
            local x1, y1, z1 = attacker.Transform:GetWorldPosition()
            local dx = x1 - x
            local dz = z1 - z

            if (dx * dx + dz * dz) < (range * range) and attacker.components.combat:CanBeAttacked() then
                ProcessThornDamage(inst, attacker)
            end
        end
    end

    if inst.chunk.head ~= nil then
        inst.chunk.head:PushEvent("attacked")
    end

    return inst.worm ~= nil and inst.worm:IsValid() and inst.worm or nil
end

local function dirt_playanimation(inst, anim, loop)
    inst.AnimState:PlayAnimation(anim, loop)

    if anim ~= "dirt_emerge_loop" and anim ~= "dirt_emerge_loop_pre" and inst.SoundEmitter:PlayingSound("roil") then
        inst.SoundEmitter:KillSound("roil")
    end

    if inst.AnimState:IsCurrentAnimation("dirt_emerge") then
        inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_emerge")
    elseif inst.AnimState:IsCurrentAnimation("dirt_pre_fast") then
        inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_pre")
    elseif inst.AnimState:IsCurrentAnimation("dirt_pst") then
        inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_pst_fast")
    elseif inst.AnimState:IsCurrentAnimation("dirt_pre_slow") then
        inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_pre_slow")
    elseif inst.AnimState:IsCurrentAnimation("dirt_pst_slow") then
        inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_pst_slow")
    elseif inst.AnimState:IsCurrentAnimation("dirt_emerge_loop_pre") then
        if not inst.SoundEmitter:PlayingSound("roil") then
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_roil_lp", "roil")
        end
    elseif inst.AnimState:IsCurrentAnimation("dirt_emerge_loop") then
        if not inst.SoundEmitter:PlayingSound("roil") then
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_roil_lp", "roil")
        end
    end
end

local function CalcSanityAura(inst)
    if inst.chunk and (inst.chunk.head or not inst.chunk.dirt_end ) and inst.worm and inst.worm.state ~= WORMBOSS_UTILS.STATE.DEAD then
        return inst.worm.components.combat.target ~= nil and -TUNING.SANITYAURA_HUGE or -TUNING.SANITYAURA_LARGE
    end
    return 0
end

local function dirtfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1)

    inst.Transform:SetEightFaced()

    inst.AnimState:SetBank("worm_boss")
    inst.AnimState:SetBuild("worm_boss")
    inst.AnimState:PlayAnimation("dirt_idle")
    inst.AnimState:SetFinalOffset(0)

    inst.AnimState:Hide("mouseover")

    inst:AddTag("worm_boss_dirt")
    inst:AddTag("hostile")
    inst:AddTag("groundpound_immune")
    inst:AddTag("worm_boss_piece")
    inst:AddTag("wet")

    inst:SetPrefabNameOverride("worm_boss")

    inst:AddComponent("highlightchild")

    inst.scrapbook_proxy = "worm_boss"

    inst.dirt_playanimation = dirt_playanimation

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("colouradder")

    inst:AddComponent("health")
    inst.components.health:SetInvincible(true)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.WORM_BOSS_DAMAGE)
    inst.components.combat.playerdamagepercent = 0.75
    inst.components.combat.redirectdamagefn = Dirt_DamageRedirectFn

    inst:AddComponent("groundpounder")
    inst.components.groundpounder:UseRingMode()
    inst.components.groundpounder.destroyer = true
    inst.components.groundpounder.damageRings = 2
    inst.components.groundpounder.destructionRings = 1
    inst.components.groundpounder.platformPushingRings = 1
    inst.components.groundpounder.groundpounddamagemult = 30/TUNING.WORM_BOSS_DAMAGE
    inst.components.groundpounder.numRings = 2
    inst.components.groundpounder.radiusStepDistance = 2
    inst.components.groundpounder.ringWidth = 1.5

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aurafn = CalcSanityAura

    inst:ListenForEvent("attacked", Dirt_OnAttacked)
    inst:ListenForEvent("animover", Dirt_OnAnimOver)

    inst.persists = false

    inst.SoundEmitter:PlaySound("rifts4/worm_boss/movement", "speed")
    inst.SoundEmitter:SetParameter("speed", "intensity", 0)

    return inst
end

-----------------------------------------------------------------------------------------------------------------------

local function dirt_ground_fx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.AnimState:SetBank("worm_boss")
    inst.AnimState:SetBuild("worm_boss")
    inst.AnimState:PlayAnimation("ground_rumble", false)
    inst.AnimState:PushAnimation("ground_rumble_loop", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.SoundEmitter:PlaySound("rifts4/worm_boss/ground_crack")

    inst.persists = false

    return inst
end

return
    Prefab("worm_boss",                fn,                assets, prefabs),
    Prefab("worm_boss_head",           headfn,            assets, prefabs),
    Prefab("worm_boss_tail",           tailfn,            assets, prefabs),
    Prefab("worm_boss_segment",        segmentfn,         assets, prefabs),
    Prefab("worm_boss_dirt",           dirtfn,            assets, prefabs),
    Prefab("worm_boss_dirt_ground_fx", dirt_ground_fx_fn, assets, prefabs)
