local easing = require("easing")

----------------------------------------------------------------------------------------------------------------------------------------

local STATE = {
    MOVING = 1,
    IDLE = 2,
    DEAD = 3,
    DIGESTING = 4,
}

local CHUNK_STATE ={
    EMERGE = 1,
    MOVING = 2,
    IDLE = 3,
    TRANSITION_TO_SEGMENTED = 4,
}

local DIGESTING_STATE = {
    DOING = 1,
    WAITING = 2,
}

local CHUNK_TEMPLATE = {
    state = CHUNK_STATE.MOVING,
    startpos = nil,
    segments = {},
    rotation = nil,
    groundpoint_start = nil,
    groundpoint_end = nil,
    ease = 1,
    nextseg = 0,
    segtimeMax = 1,
    segmentstotal = 0,
}

----------------------------------------------------------------------------------------------------------------------------------------

local WORM_LENGTH = 3
local DELAY_TO_MOVE_UNDERGROUND = 0.4
local SHAKE_DIST = 40
local THORN_EASE_THRESHOLD = 0.5

----------------------------------------------------------------------------------------------------------------------------------------

local function ShouldDoSpikeDamage(chunk)
    return chunk.ease == nil or chunk.ease >= THORN_EASE_THRESHOLD
end

local function Knockback(source, target)
    if target == nil or (target.components.health ~= nil and target.components.health:IsDead()) or target:HasTag("noattack") then
        return
    end

    local mult = 1
    local heavymult = 1.3

    local strengthmult = (target.components.inventory ~= nil and target.components.inventory:ArmorHasTag("heavyarmor") or target:HasTag("heavybody")) and heavymult or mult

    target:PushEvent("knockback", { knocker = source, radius = 2, strengthmult = strengthmult, forcelanded = false })
end

local function ToggleOffPhysics(inst)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.GROUND)
end

local function ToggleOnPhysics(inst)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
    inst.Physics:CollidesWith(COLLISION.OBSTACLES)
    inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
    inst.Physics:CollidesWith(COLLISION.GIANTS)
end

----------------------------------------------------------------------------------------------------------------------------------------

local function SpawnDirt(inst, chunk, pt, start, instant)
    local dirt = SpawnPrefab("worm_boss_dirt")

    dirt.Transform:SetPosition(pt.x, 0, pt.z)

    dirt.chunk = chunk
    dirt.worm = inst

    local state =
        (instant and "dirt_idle"    ) or
        (start   and #inst.chunks == 1 and "dirt_emerge_loop_pre") or
        (start   and "dirt_pre_slow") or
        "dirt_emerge"

    dirt:dirt_playanimation(state)

    if start then
        chunk.dirt_start = dirt

        if not instant then
            dirt:AddTag("notarget")

            ToggleOffPhysics(dirt)
        end
    else
        chunk.dirt_end = dirt

        dirt.components.groundpounder:GroundPound()
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, 1, inst, SHAKE_DIST)

        -- For segments created before dirt_end:
        for _, segment in ipairs(chunk.segments) do
            segment:SetHighlightOwners(chunk.dirt_end, chunk.dirt_start)
        end

        dirt.components.highlightchild:SetOwner(chunk.dirt_start)
        chunk.dirt_start.components.highlightchild:SetOwner(dirt)
    end
end

local function IsDevouring(inst, target)
    return
        target ~= nil
        and target:IsValid()
        and target.sg ~= nil
        and target.sg:HasStateTag("devoured")
        and target.sg.statemem.attacker == inst
end

local function DoChew(inst, target, useimpactsound)
    if not useimpactsound then
        target.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_med_dull")
    end

    if IsDevouring(inst, target) then
        local dmg, spdmg = inst.components.combat:CalcDamage(target)
        local noimpactsound = target.components.combat.noimpactsound

        if target:HasTag("player") then
            target:ShakeCamera(CAMERASHAKE.VERTICAL, .2, .015, 0.5, inst, SHAKE_DIST)
        end

        target.components.combat.noimpactsound = not useimpactsound
        target.components.combat:GetAttacked(inst, dmg, nil, nil, spdmg)
        target.components.combat.noimpactsound = noimpactsound

        if target.components.sanity then
            target.components.sanity:DoDelta(-TUNING.SANITY_SUPERTINY)
        end
    end
end

local function ChewAll(inst)
    if inst.devoured == nil then
        return
    end

    for _, ent in ipairs(inst.devoured) do
        if ent.prefab ~= nil and ent.components.combat ~= nil and ent.components.health ~= nil then -- NOTES(DiogoW): Checking prefab because we have fillers in this table.
            DoChew(inst, ent, false)
        end
    end
end

local function DoSpitOut(inst, target, spitfromhead, spitfromlocatoin)
    if IsDevouring(inst, target) and target:HasOneOfTags("player", "devourable") then
        local source =
            (spitfromlocatoin and target   ) or
            (spitfromhead     and inst.head) or
            inst.tail

		target.sg.currentstate:HandleEvent(target.sg, "spitout", { spitter = source, starthigh = true, radius = inst:GetPhysicsRadius(0) + 3, strengthmult = 1 , rot=math.random()*360 })

    elseif not target:HasOneOfTags("player", "irreplaceable") then
        target:Remove()
    end
end

local function SpitAll(inst, spitfromhead, spitfromlocatoin)
    local pt = spitfromhead and inst.head:GetPosition() or inst.chunks[1].groundpoint_end

    -- Don't change groundpoint_end itself...
    pt = Vector3(pt.x, 5, pt.z)

    if inst.devoured ~= nil then
        for _, ent in ipairs(inst.devoured) do
            if ent.prefab ~= nil then -- NOTES(DiogoW): Checking prefab because we have fillers in this table.
                DoSpitOut(inst, ent, spitfromhead, spitfromlocatoin)

            elseif not spitfromhead and inst.tail ~= nil then
                for p=1, 3 do
                    local poop = SpawnPrefab("poop")

                    inst.tail.components.lootdropper:FlingItem(poop, pt)
                end
            end
        end

        inst.devoured = nil
    end

    local items = inst.components.inventory:FindItems(function() return true end)

    if #items > 0 then
        for i=#items, 1, -1 do
            local item = items[i]

            inst.components.inventory:RemoveItem(item, true)

            if spitfromhead or not inst.tail then
                inst.head.components.lootdropper:FlingItem(item, pt)
                inst:SetState(STATE.IDLE)

            elseif inst.head ~= nil then
                inst.tail.components.lootdropper:FlingItem(item, pt)
            end
        end
    end
end

local function UpdateDigestingPlayersLocations(inst, source)
    if source == nil or inst.devoured == nil then
        return
    end

    inst.Transform:SetPosition(source.Transform:GetWorldPosition())

    ChewAll(inst)
end

local function Digest(inst)
    -- Otherwise, begin digestion.
    if inst.devoured == nil then
        return
    end

    inst:SetState(STATE.DIGESTING)

    for _, ent in ipairs(inst.devoured) do
        if ent.sg and ent.sg:HasStateTag("devoured") and ent:HasTag("player") then
            ent._wormdigestionsound:set(true)
        end
    end

    --

    for i=#inst.chunks, 1, -1 do
        local chunk = inst.chunks[i]

        if chunk ~= nil and chunk.head == nil then
            chunk.digesting = DIGESTING_STATE.WAITING
            break
        end
    end
end

local function HasFood(inst)
    return inst.components.inventory:NumItems() > 0 or (inst.devoured ~= nil and #inst.devoured > 0)
end

local function ShouldMove(inst)
    if inst.state == STATE.DEAD or HasFood(inst) then
        return false
    end

    -- Find target close to "head"?
    if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() and not inst.components.combat.target.components.health:IsDead() then
        local lastchunk = inst.chunks[#inst.chunks]

        if lastchunk.dirt_start ~= nil and lastchunk.dirt_start:IsValid() then
            local dist = lastchunk.dirt_start:GetDistanceSqToInst(inst.components.combat.target)

            if dist <= TUNING.WORM_BOSS_MELEE_RANGE * TUNING.WORM_BOSS_MELEE_RANGE then
                if inst.head == nil then
                    return false
                end
            end
        end
    end

    return true
end

local function TransferCreatureInventory(inst, target)
    local inst_inv = inst.components.inventory
    if inst_inv == nil then
        return
    end

    local target_inv = target.components.inventory
    if target_inv == nil then
        return
    end

    for k in pairs(target_inv.itemslots) do
        local item = target_inv:RemoveItemBySlot(k)

        if item ~= nil and item.persists then
            inst_inv:GiveItem(item)
        end
    end

    for k in pairs(target_inv.equipslots) do
        local equip = target_inv:Unequip(k)

        if equip ~= nil and equip.persists then
            inst_inv:GiveItem(equip)
        end
    end

    local activeitem = target_inv:GetActiveItem()

    if activeitem ~= nil and activeitem.persists then
        inst_inv:GiveItem(activeitem)
    end
end

local function OnThingExitDevouredState(inst, data)
    inst:RemoveEventCallback("newstate", OnThingExitDevouredState)

    if inst.components.health ~= nil then
        if inst.components.oldager ~= nil then
            -- Fast forward Wanda's overtime damage, so she doesn't die when getting out.
            inst.components.oldager:FastForwardDamageOverTime()
        end

        inst.components.health:SetMinHealth(0)
    end
end

local FOOD_CANT_TAGS = { "INLIMBO", "NOCLICK", "FX", "DECOR", "largecreature", "worm_boss_piece", "noattack", "notarget", "playerghost" }
local FOOD_ONEOF_TAGS = { "_inventoryitem", "character", "smallcreature"}

local function CollectThingsToEat(inst, source)
    local pt = source:GetPosition()

    local ents = TheSim:FindEntities(pt.x, 0, pt.z, TUNING.WORM_BOSS_EAT_RANGE, nil, FOOD_CANT_TAGS, FOOD_ONEOF_TAGS)

    if #ents <= 0 then
        return false
    end

    local ate = false
    local calories = 0
    for _, ent in ipairs(ents) do
        if ent.components.health == nil or not ent.components.health:IsDead() then
            if inst.components.combat.target == ent then
                inst.components.combat:DropTarget()
            end

            if ent.components.inventoryitem ~= nil then
                if not inst.components.inventory:IsFull() then
                    if ent.components.edible then
                        calories = calories + ent.components.edible.hungervalue
                    end

                    inst.components.inventory:GiveItem(ent)

                    ate = true

                elseif inst.head ~= nil then
                    inst.head.components.lootdropper:FlingItem(ent)
                end
            else
                local devoured = false

                if ent.sg ~= nil and not ent.sg:HasStateTag("knockback") then
                    if ent:IsValid() and ent:GetDistanceSqToPoint(pt) < TUNING.WORM_BOSS_EAT_CREATURE_RANGE * TUNING.WORM_BOSS_EAT_CREATURE_RANGE then
                        if inst.devoured == nil then
                            inst.devoured = {}
                        end

                        if ent:HasOneOfTags("player", "devourable") then
                            ent.sg:HandleEvent("devoured", { attacker = inst, ignoresetcamdist = true })

                            local minhealth = ent.components.health ~= nil and ent.components.health.minhealth or nil

                            if minhealth == 0 then
                                ent.components.health:SetMinHealth(1)

                                ent:ListenForEvent("newstate", OnThingExitDevouredState)
                            end

                            table.insert(inst.devoured, ent)

                        elseif not ent:HasTag("irreplaceable") then
                            TransferCreatureInventory(inst, ent)

                            ent:Remove()

                            table.insert(inst.devoured, { blankfiller = true })
                        end

                        ate = true
                        devoured = true
                    end
                end

                if devoured == false then
                    Knockback(source, ent)
                end
            end
        end
    end
    if calories > 0 then
        inst.chews = math.min(math.ceil(calories/20),4)
    end
    return ate
end

local function SpawnTail(inst, chunk, instant)
    local rotation = math.atan2(chunk.groundpoint_end.z - chunk.groundpoint_start.z, chunk.groundpoint_start.x - chunk.groundpoint_end.x) * RADIANS

    local tail = SpawnPrefab("worm_boss_tail")

    tail.Transform:SetPosition(chunk.groundpoint_end:Get())
    tail.Transform:SetRotation(rotation)

    chunk.tail = tail
    chunk.tail.worm = inst
    chunk.tail.dirt = chunk.dirt_end

    chunk.tail:SetHighlightOwners(chunk.dirt_end, chunk.dirt_start)

    inst.tail = chunk.tail

    tail.sg:GoToState(instant and "idle" or "idle_pre")
    chunk.dirt_end.AnimState:PlayAnimation("dirt_idle")

    return tail
end

local function EmergeHead(inst, chunk, instant)
    -- Instant is for loading the game.
    if inst.new_crack then
        inst.new_crack:Remove()
        inst.new_crack= nil
    end

    local ate_on_emerge = false
    local isdead = inst.components.health:IsDead()

    if not (instant or isdead) then
        ate_on_emerge = CollectThingsToEat(inst, chunk.dirt_start)
    end

    local hasfood = HasFood(inst)

    if (instant or isdead) or (hasfood or not ShouldMove(inst)) then
        inst:SetState(STATE.IDLE)

        for _, chunk in ipairs(inst.chunks) do
            chunk.state = CHUNK_STATE.IDLE
        end

        local head = SpawnPrefab("worm_boss_head")
        head.Transform:SetPosition(chunk.groundpoint_start:Get())

        head.worm = inst
        head.chunk = chunk

        inst.head = head
        chunk.head = head

        local rotation = math.random()*360

        if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
            rotation = head:GetAngleToPoint(inst.components.combat.target.Transform:GetWorldPosition())

        elseif inst.chunks[#inst.chunks-1] ~= nil then
            local previouschunk = inst.chunks[#inst.chunks-1]

            local other = previouschunk.dirt_end or previouschunk.dirt_start

            if other ~= nil and other:IsValid() then
                rotation = other:GetAngleToPoint(chunk.dirt_start.Transform:GetWorldPosition())
            end
        end

        head.Transform:SetRotation(rotation)
        inst.Transform:SetRotation(rotation)

        if hasfood or not instant or isdead then
            head.sg:GoToState("emerge", { ate = ate_on_emerge, hasfood = hasfood, dead = isdead, loading = instant })

        elseif instant then
            head.sg:GoToState("idle")
        end

        head:SetHighlightOwners(chunk.dirt_end, chunk.dirt_start)
    else
        for _, chunk in ipairs(inst.chunks) do
            chunk.state = CHUNK_STATE.MOVING
        end
    end

    -- Reset the time it will chase a target for.
    if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
        if chunk.dirt_start:IsValid() and chunk.dirt_start:GetDistanceSqToInst(inst.components.combat.target) < 4*4 then
            inst.targettime = GetTime()
        end
    end

    if not instant and #inst.chunks > WORM_LENGTH then
        local testchunk = inst.chunks[1]

        testchunk.lastrun = true

        if testchunk.dirt_start:IsValid() and not testchunk.dirt_start.AnimState:IsCurrentAnimation("dirt_pst") then
            testchunk.dirt_start.AnimState:PlayAnimation("dirt_pst")
        end
    end

    if isdead then
        inst.state = STATE.DEAD

        for _, chunk in ipairs(inst.chunks) do
            if chunk.dirt_start ~= nil and chunk.dirt_start:IsValid() then
                chunk.dirt_start:AddTag("notarget")
            end

            if chunk.dirt_end ~= nil and chunk.dirt_end:IsValid() then
                chunk.dirt_end:AddTag("notarget")
            end
        end
    end
end

local chunkID = 1

local function CreateNewChunk(inst, pt, instant)
    local newchunk = deepcopy(CHUNK_TEMPLATE)

    newchunk.ID = chunkID
    chunkID = chunkID + 1
    newchunk.groundpoint_start = pt
    newchunk.state = CHUNK_STATE.EMERGE

    table.insert(inst.chunks, newchunk)

    SpawnDirt(inst, newchunk, newchunk.groundpoint_start, true, instant)

    inst.Transform:SetPosition(pt:Get())

    return newchunk
end

local WORM_MOVEMENT_BLOCKING_TAGS = { "worm_boss_dirt" }

local function IsPointValid(pt)
    local tile = TheWorld.Map:GetTileAtPoint(pt.x, 0, pt.z)

    -- Bridges are not valid points.
    return not GROUND_INVISIBLETILES[tile] and TheSim:CountEntities(pt.x, 0, pt.z, 4, WORM_MOVEMENT_BLOCKING_TAGS) <= 0
end

local function FindOffsetForNewChunk(inst, lastchunk)
    if lastchunk.groundpoint_end == nil then
        return
    end

    local angle
    local range = 6

    while range <= 15 do
        if inst.components.combat.target ~= nil then
            angle = lastchunk.dirt_end:GetAngleToPoint(inst.components.combat.target.Transform:GetWorldPosition()) * DEGREES
        else
            angle = lastchunk.dirt_start:GetAngleToPoint(lastchunk.groundpoint_end:Get()) * DEGREES
            angle = angle + (math.random()*PI) - PI/2
        end

        local offset = FindWalkableOffset(lastchunk.groundpoint_end, angle, range, 16, true, true, IsPointValid, false, false)

        if offset ~= nil then
            return offset
        end

        range = range + 1
    end

    -- We don't a nearby point to go, reappear somewhere...

    while range <= 30 do
        local theta = TWOPI * math.random()

        local offset = FindWalkableOffset(lastchunk.groundpoint_end, theta, range, 16, true, true, IsPointValid, false, false)

        if offset ~= nil then
            return offset
        end

        range = range + 1
    end
end

local function PlotNextChunk(inst, lastchunk)
    if inst.state == STATE.DEAD then
        return
    end

    local offset = FindOffsetForNewChunk(inst, lastchunk)

    if offset ~= nil then
        return offset + lastchunk.groundpoint_end
    end
end

local function FindNewEndPoint(inst, chunk)
    local blocked = true
    local range = 6

    local angle = math.random()*TWOPI

    if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() and chunk.dirt_start:IsValid() then
        angle = chunk.dirt_start:GetAngleToPoint(inst.components.combat.target.Transform:GetWorldPosition()) * DEGREES
    end

    if angle < 0 then
        angle = angle + TWOPI
    end

    local half_PI = PI/2

    if angle == half_PI or angle == 3*half_PI or angle == 5*half_PI or angle == 7*half_PI then
        angle = math.random() < 0.5 and angle + PI/32 or angle - PI/32
    end

    while range <= 15 do
        local offset = FindWalkableOffset(chunk.groundpoint_start, angle, range, 16, true, true, IsPointValid, false, false)

        if offset ~= nil then
            chunk.groundpoint_end = chunk.groundpoint_start  + offset

            return offset
        end

        range = range + 1
    end
end

local function UpdateSegmentArt(segment)
    segment.build =
        (    segment.head   and "worm_boss"                ) or
        (    segment.tail   and "worm_boss"                ) or
        (not segment.spiked and "worm_boss_segment_2_build") or
        "worm_boss_segment"

    segment.AnimState:SetBuild(segment.build)
end

local function UpdateSegmentAnimPosition(segment, percentdist, useframe)
    local anim =
        (segment.head and "head") or
        (segment.tail and "tail") or
        "segment"

    if useframe then
        segment.AnimState:PlayAnimation(anim)
        segment.AnimState:SetFrame(math.floor(percentdist*(segment.AnimState:GetCurrentAnimationNumFrames()))-1)
    else
        segment.AnimState:SetPercent(anim, percentdist)
    end
end

local function Internal_CreateChunk(inst, pt)
    if inst.createnewchunktask ~= nil then
        inst.createnewchunktask:Cancel()
        inst.createnewchunktask = nil
    end

    inst.new_crack = SpawnPrefab("worm_boss_dirt_ground_fx")
    inst.new_crack.Transform:SetPosition(pt.x, 0, pt.z)

    CreateNewChunk(inst, pt)
end

local function SetCreateChunkTask(inst, pt)
    inst.createnewchunktask = inst:DoTaskInTime(DELAY_TO_MOVE_UNDERGROUND, Internal_CreateChunk, pt)
    inst.createnewchunktask._target_pt = pt
end

local function MoveSegmentUnderGround(inst, chunk, test_segment, percent, instant)
    table.removearrayvalue(chunk.segments, test_segment)

    if #chunk.segments <= 0 then
        table.removearrayvalue(inst.chunks, chunk)
    end

    if test_segment.head then
        SpawnDirt(inst, chunk, chunk.groundpoint_end, false, instant)

        if not instant then
            CollectThingsToEat(inst, chunk.dirt_end)

            local newpt = PlotNextChunk(inst, chunk)

            if newpt ~= nil then
                SetCreateChunkTask(inst, newpt)
            end
        end
    end

    if not instant and test_segment.DoThornDamage and ShouldDoSpikeDamage(chunk) then
        test_segment:DoThornDamage()
    end

    UpdateSegmentArt(test_segment)
    UpdateSegmentAnimPosition(test_segment, .95, true)

    chunk.segmentstotal = chunk.segmentstotal - 1

    if #chunk.segments <= 0 and chunk.dirt_end:IsValid() then
        chunk.dirt_end.AnimState:PlayAnimation("dirt_pst_slow")
    end

    if chunk.lastsegment ~= nil then
        inst:ReturnSegmentToPool(chunk.lastsegment)
    end

    chunk.lastsegment = test_segment
    chunk.lastsegment.AnimState:SetFinalOffset(-2)
end

local function AddSegment(inst, chunk, tail, instant)
    if chunk.tailfinished then
        return
    end

    local segment = inst:GetSegmentFromPool()

    if not chunk.spiked then
        segment.spiked = true
        chunk.spiked = true
    else
        chunk.spiked = nil
    end

    segment.segtime = chunk.segtimeMax * 0.01
    segment.worm = inst

    local p0 = Vector3(chunk.groundpoint_start.x, 0, chunk.groundpoint_start.z)
    local p1 = Vector3(chunk.groundpoint_end.x,   0, chunk.groundpoint_end.z  )

    segment._dirt_start_x:set(chunk.groundpoint_start.x)
    segment._dirt_start_z:set(chunk.groundpoint_start.z)
    segment._dirt_end_x:set(chunk.groundpoint_end.x)
    segment._dirt_end_z:set(chunk.groundpoint_end.z)

    local pdelta = p1 - p0

    local t = segment.segtime/chunk.segtimeMax

    local pf = (pdelta * t) + p0

    pf.y = 0

    segment.setheight = pf.y

    segment.Transform:SetPosition(pf:Get())
    segment.Transform:SetRotation(segment:GetAngleToPoint(chunk.groundpoint_end:Get()))

    segment:UpdatePredictionData(chunk.ease, segment.segtime)  -- Prease update client prediction in worm_boss.lua in any calculation changes are made here.

    if ShouldDoSpikeDamage(chunk) then
        segment:DoThornDamage()
    end

    table.insert(chunk.segments, segment)

    chunk.segmentstotal = chunk.segmentstotal + 1

    if not chunk.head_added then
        chunk.head_added = true
        segment.head = true
    end

    if tail then
        chunk.tailfinished = true
        segment.tail = true
    end

    UpdateSegmentArt(segment)
    UpdateSegmentAnimPosition(segment, 0)

    segment:SetHighlightOwners(chunk.dirt_end, chunk.dirt_start)
end

local function IsChunkMoving(inst, chunk)
    return chunk.state == CHUNK_STATE.MOVING or chunk.state == CHUNK_STATE.EMERGE
end

local function SpawnAboveGroundHeadCorpse(inst, headchunk)
    for _, segment in ipairs(headchunk.segments) do
        for i=#headchunk.segments, 1, -1 do
            inst:ReturnSegmentToPool(headchunk.segments[i])
        end
    end

    headchunk.segments = {}

    EmergeHead(inst, headchunk, true)
    inst.head:PushEvent("death",{loop=true})

    if headchunk.dirt_start ~= nil then
        headchunk.dirt_start.AnimState:PlayAnimation("dirt_emerge")
    end
end

local function SpawnUnderGroundHeadCorpse(inst)

    local pt = nil
    if inst.createnewchunktask == nil then
        if #inst.chunks > 0 then
            pt = inst.chunks[#inst.chunks].groundpoint_start
        else
            return
        end
    else
        pt = inst.createnewchunktask._target_pt
        inst.createnewchunktask:Cancel()
        inst.createnewchunktask = nil
    end

	local headchunk = CreateNewChunk(inst, pt, true)


    EmergeHead(inst, headchunk, true)
    inst.head.sg:GoToState("emerge", { dead = true } )

    if headchunk.dirt_start ~= nil then
        headchunk.dirt_start.AnimState:PlayAnimation("dirt_emerge")
    end

end

local function UpdateRegularChunk(inst, chunk, dt, instant)
    -- SET END POINT FOR ANY OF THIS TO MAKE SENSE

    if not chunk.groundpoint_end then
        FindNewEndPoint(inst, chunk)

        if not chunk.groundpoint_end then
            return
        end
    end

    for _, segment in ipairs(chunk.segments) do
        segment.percentdist = segment.segtime/chunk.segtimeMax
        UpdateSegmentAnimPosition(segment, segment.percentdist)
    end

    local rate = 1/60
    local speed = 0

    -- IF THIS SEGMENT IS MOVING or THE LAST ONE, ACCELL (THE TAIL WILL CONVERT TO THE PREFAB IF IT SHOULD STOP)
    if IsChunkMoving(inst, chunk) or (chunk.lastrun and chunk.tail == nil) then
        chunk.ease = math.min(chunk.ease + rate, 1) -- ACCELL
    else
        chunk.ease = math.max(chunk.ease - rate, 0) -- BRAKE
    end

    speed = chunk.ease

    if speed > 0.1 then
        if chunk.dirt_start and chunk.dirt_start:IsValid() and chunk.dirt_start.AnimState:IsCurrentAnimation("dirt_idle") then
            chunk.dirt_start.AnimState:PlayAnimation("dirt_move", true)
        end

        if chunk.dirt_end and chunk.dirt_end:IsValid() and chunk.dirt_end.AnimState:IsCurrentAnimation("dirt_idle") and not chunk.tail then
            chunk.dirt_end.AnimState:PlayAnimation("dirt_move", true)
        end
    else
        if chunk.dirt_start and chunk.dirt_start:IsValid() and chunk.dirt_start.AnimState:IsCurrentAnimation("dirt_move") then
            chunk.dirt_start.AnimState:PlayAnimation("dirt_idle", true)
        end

        if chunk.dirt_end and chunk.dirt_end:IsValid() and chunk.dirt_end.AnimState:IsCurrentAnimation("dirt_move") then
            chunk.dirt_end.AnimState:PlayAnimation("dirt_idle", true)
        end
    end

    -- Movement sound.
    if chunk.dirt_start and chunk.dirt_start:IsValid() then
        chunk.dirt_start.SoundEmitter:SetParameter("speed", "intensity", speed)
    end

    if chunk.dirt_end and chunk.dirt_end:IsValid() then
        chunk.dirt_end.SoundEmitter:SetParameter("speed", "intensity", speed)
    end

    -- MOVE SEGMENTS ALONG TOWARD ENDPOINT
    for i = #chunk.segments, 1, -1 do
        local segment = chunk.segments[i]

        local p1 = chunk.groundpoint_end
        local p0 = chunk.groundpoint_start

        local pdelta = p1 - p0

        segment:UpdatePredictionData(speed, segment.segtime) -- Prease update client prediction in worm_boss.lua in any calculation changes are made here.

        segment.segtime = math.min(segment.segtime + (dt * speed), chunk.segtimeMax)

        local t = segment.segtime/chunk.segtimeMax

        local tmod = easing.inOutQuad(t, 0, 1, 1)

        local pf = (pdelta * tmod) + p0

        segment.setheight = pf.y

        segment.Transform:SetPosition(pf:Get())

        -- REACHED JUST ABOUT TO THE END, TIME TO GO UNDERGROUND.
        if t > 0.98 then
            if not chunk.loopcomplete then
                inst:PushEvent("bodycomplete")
                chunk.loopcomplete = true
            end

            MoveSegmentUnderGround(inst, chunk, segment, t, instant)
        end
    end

    -- CHECK CONVERSION TO SEPARATE TAIL PIECE IF THIS IS THE END BIT AND NOT MOVING
    if chunk.lastrun then
        local final_seg = chunk.segments[#chunk.segments]

        if final_seg and final_seg.segtime/chunk.segtimeMax > 0.75 and (instant or not IsChunkMoving(inst, chunk)) then
            for i=#chunk.segments, 1, -1 do
                inst:ReturnSegmentToPool(chunk.segments[i])
                table.remove(chunk.segments, i)
                chunk.segmentstotal = chunk.segmentstotal - 1
            end

            if chunk.lastsegment ~= nil then
                inst:ReturnSegmentToPool(chunk.lastsegment)
                chunk.lastsegment = nil
            end

            if chunk.dirt_end:IsValid() then
                chunk.dirt_end.AnimState:PlayAnimation("dirt_idle")
            end

            SpawnTail(inst, chunk, instant)
        end
    end

    if (inst.state == STATE.IDLE or inst.state == STATE.DIGESTING) and not chunk.lastrun and chunk.ease == 0 then
        if chunk.segments and #chunk.segments > 0 then
            local function positionandscale(segment, scale, height)
                if scale and segment then
                    segment.scalegoal = scale
                end

                if height and segment then
                    segment.heightgoal = segment.setheight * height
                end
            end

            local SEGMENTIDLETIME = 0.2

            if chunk.digesting == DIGESTING_STATE.DOING then
                SEGMENTIDLETIME = 0.14 --0.2
            end

            if not chunk.idletimer then
                chunk.idletimer = SEGMENTIDLETIME + (math.random() *1)
                chunk.idlesegment = 0
            end

            chunk.idletimer = chunk.idletimer - dt

            -- DO SOME STUFF TO ALTER THE SIZE OF THE SEGMENTS for idle or digesting
            if chunk.idletimer <= 0 or chunk.digesting == DIGESTING_STATE.WAITING then
                chunk.idletimer = SEGMENTIDLETIME

                -- RESETS THINGS
                if chunk.segments[chunk.idlesegment -1] then
                    positionandscale(chunk.segments[chunk.idlesegment-1], inst.child_scale, 1)
                end

                if chunk.segments[chunk.idlesegment +1] then
                    positionandscale(chunk.segments[chunk.idlesegment+1], inst.child_scale, 1)
                end

                if chunk.segments[chunk.idlesegment] then
                    positionandscale(chunk.segments[chunk.idlesegment], inst.child_scale, 1)
                end

                if chunk.segments[chunk.idlesegment-2] then
                    positionandscale(chunk.segments[chunk.idlesegment-2], inst.child_scale, 1)
                end

                if chunk.segments[chunk.idlesegment+2] then
                    positionandscale(chunk.segments[chunk.idlesegment+2], inst.child_scale, 1)
                end


                chunk.idlesegment = chunk.idlesegment +1

                -- move player along if digesting
                if chunk.digesting == DIGESTING_STATE.DOING and chunk.segments[chunk.idlesegment] then
                    UpdateDigestingPlayersLocations(inst, chunk.segments[chunk.idlesegment])
                end

                -- reset idlesegment if it's reached the end or needs to start digesting
                if chunk.idlesegment > #chunk.segments or chunk.digesting == DIGESTING_STATE.WAITING then
                    chunk.idlesegment = 0
                end

                -- DO DIGESTION BULGE CHUNK BY CHUNK
                if chunk.digesting == DIGESTING_STATE.WAITING then
                    chunk.digesting = DIGESTING_STATE.DOING

                elseif chunk.digesting == DIGESTING_STATE.DOING and chunk.idlesegment == #chunk.segments then
                    local lastchunk = nil

                    for _, testchunk in ipairs(inst.chunks) do
                        if testchunk.digesting == DIGESTING_STATE.DOING then
                            if lastchunk == nil then
                                UpdateDigestingPlayersLocations(inst, inst.tail)

                                if inst.tail ~= nil then
                                    inst.tail:PushEvent("spit")
                                end
                            else
                                lastchunk.digesting = DIGESTING_STATE.WAITING
                            end
                        else
                            if not testchunk.tail then
                                lastchunk = testchunk
                            end
                        end
                    end

                    chunk.digesting = nil
                end
            end

            local HEIGHT_SUB = 0.97
            local HEIGHT = 0.95

            local SCALE = inst.child_scale + 0.1
            local SCALE_SUB = inst.child_scale + 0.05
            local SCALE_SUB_SUB = inst.child_scale + 0.01

            local digest = 1
            if chunk.digesting == DIGESTING_STATE.DOING then
                digest = 1.18

                if chunk.segments[chunk.idlesegment-2] then
                    positionandscale(chunk.segments[chunk.idlesegment-2], SCALE_SUB_SUB*digest, 1)
                end

                if chunk.segments[chunk.idlesegment+2] then
                    positionandscale(chunk.segments[chunk.idlesegment+2], SCALE_SUB_SUB*digest, 1)
                end
            end

            if chunk.segments[chunk.idlesegment-1] then
                positionandscale(chunk.segments[chunk.idlesegment-1], SCALE_SUB*digest, HEIGHT_SUB)
            end

            if chunk.segments[chunk.idlesegment+1] then
                positionandscale(chunk.segments[chunk.idlesegment+1], SCALE_SUB*digest, HEIGHT_SUB)
            end

            if chunk.segments[chunk.idlesegment] then
                positionandscale(chunk.segments[chunk.idlesegment], SCALE*digest, HEIGHT)
            end

            for i, segment in ipairs(chunk.segments)do
                local SCALE_VEL = 0.008

                if chunk.digesting == DIGESTING_STATE.DOING then
                    SCALE_VEL = 0.016
                end

                if segment.scalegoal then
                    local scale = segment.Transform:GetScale()

                    if scale ~= segment.scalegoal then
                        if scale > segment.scalegoal then
                            scale = math.max(scale - SCALE_VEL, segment.scalegoal )
                        else
                            scale = math.min(scale + SCALE_VEL, segment.scalegoal )
                            if scale == segment.scalegoal then
                                --segment.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/boss/pugalisk/scales")
                            end
                        end
                    end

                    segment.Transform:SetScale(scale, scale, scale)
                end

                local HEIGHT_VEL = 0.005

                if segment.heightgoal then
                    local pf = segment:GetPosition()

                    if pf.y ~= segment.heightgoal then
                        if pf.y > segment.heightgoal then
                            pf.y = math.max(pf.y - HEIGHT_VEL,segment.heightgoal)
                        else
                            pf.y = math.min(pf.y + HEIGHT_VEL,segment.heightgoal)
                        end
                    end

                    segment.Transform:SetPosition(pf:Get())
                end
            end
        end
    else
        chunk.idletimer = nil
        chunk.idlesegment = nil
    end

    if chunk.hit and chunk.hit > 0 then
        local scale = Remap(chunk.hit, 1, 0, 0.75, 1)

        for i, segment in ipairs(chunk.segments) do
            segment.Transform:SetScale(scale, scale, scale)

            if chunk.hit == 1 then
                segment.hitevent:push()
            end

            local x, y, z = segment.Transform:GetWorldPosition()
            segment.Transform:SetPosition(x, 0, z)
        end

        if chunk.lastsegment ~= nil then
            chunk.lastsegment.Transform:SetScale(scale, scale, scale)

            if chunk.hit == 1 then
                chunk.lastsegment.hitevent:push()
            end

            local x, y, z = chunk.lastsegment.Transform:GetWorldPosition()
            chunk.lastsegment.Transform:SetPosition(x, 0, z)
        end

        chunk.hit = chunk.hit - (dt * 5)
    end

    if chunk.nextseg <= 0 then
        AddSegment(inst, chunk, chunk.lastrun, instant)
        chunk.nextseg = 1/15  -- 1/12
    else
        chunk.nextseg = chunk.nextseg - (dt * speed)
    end
end

local function UpdateRegularDeadChunk(inst, chunk, dt, instant)
    if inst.chunks[inst.current_death_chunk] ~= chunk then
        return
    end

    if not chunk.death_timer then
        chunk.death_timer = 0
    end

    if not chunk.death_currengsegment then
        chunk.death_currengsegment = 1
    end

    if chunk.death_timer > 0 then
        chunk.death_timer = chunk.death_timer - dt

        return
    end

    chunk.death_timer = 0.05

    if chunk.tail then
        chunk.tail:PushEvent("death")
    end

    local segment = chunk.segments[chunk.death_currengsegment]

    if segment and segment:IsValid() then
        if chunk.digesting == DIGESTING_STATE.DOING and chunk.idlesegment and chunk.segments[chunk.idlesegment] then
            SpitAll(inst, nil , true)
        end

        local frame = segment.AnimState:GetCurrentAnimationFrame()
        local maxframe = segment.AnimState:GetCurrentAnimationNumFrames()

        local percent = 0

        if frame > maxframe/2 then
            frame = frame - (maxframe/2)
        else
            frame = maxframe/2 - frame
        end

        percent = frame/(maxframe/2)

        segment.AnimState:PlayAnimation("segment_death")
        maxframe = segment.AnimState:GetCurrentAnimationNumFrames()
        frame = math.floor(maxframe*percent)
        segment.AnimState:SetFrame(frame)

        local x, y, z = segment.Transform:GetWorldPosition()
        x = x + (math.random() * 1) - 0.5
        z = z + (math.random() * 1) - 0.5

        segment.Transform:SetPosition(x,y,z)
    end

    if segment == chunk.segments[#chunk.segments] or #chunk.segments == 0 then
        inst.current_death_chunk = inst.current_death_chunk - 1

        if inst.current_death_chunk <= 0 then
            inst:PushEvent("death_ended")
        end
    else
        chunk.death_currengsegment = chunk.death_currengsegment + 1
    end
end

local function UpdateRegularDeadChunk_Simplified(inst, chunk, dt, instant)
    if chunk.tail then
        chunk.tail:PushEvent("death")
        inst.tail = nil

        for i, testchunk in ipairs(inst.chunks) do
            if testchunk == chunk then
                table.remove(inst.chunks, i)

                break
            end
        end
    end

    if chunk.head then
        return
    end

    if inst.chunks[1] == chunk then
        chunk.lastrun = true

        if chunk.dirt_start ~= nil and chunk.dirt_start:IsValid() and not chunk.dirt_start.AnimState:IsCurrentAnimation("dirt_pst") then
            chunk.dirt_start.AnimState:PlayAnimation("dirt_pst")
        end
    end

    for i = #chunk.segments, 1, -1 do
        local segment = chunk.segments[i]

        segment.percentdist = segment.segtime/chunk.segtimeMax
        UpdateSegmentAnimPosition(segment, segment.percentdist)

        local p1 = chunk.groundpoint_end
        local p0 = chunk.groundpoint_start

        local pdelta = p1 - p0

        segment.segtime = math.min(segment.segtime + dt, chunk.segtimeMax)

        local t = segment.segtime/chunk.segtimeMax

        segment:UpdatePredictionData(1, segment.segtime) -- Prease update client prediction in worm_boss.lua in any calculation changes are made here.

        local tmod = easing.inOutQuad(t, 0, 1, 1)

        local pf = (pdelta * tmod) + p0

        segment.setheight = pf.y

        inst.Transform:SetPosition(pf:Get())

        -- REACHED JUST ABOUT TO THE END, TIME TO GO UNDERGROUND.
        if t > 0.98 then
            if not chunk.loopcomplete then
                inst:PushEvent("bodycomplete")
                chunk.loopcomplete = true
            end

            MoveSegmentUnderGround(inst, chunk, segment, t, instant)
        end
    end

    if chunk.nextseg <= 0 then
        AddSegment(inst, chunk, chunk.lastrun, instant)
        chunk.nextseg = 1/15
    else
        chunk.nextseg = chunk.nextseg - dt
    end

    if #inst.chunks <= 1 then
        if chunk.lastsegment ~= nil then
            inst:ReturnSegmentToPool(chunk.lastsegment)
            chunk.lastsegment = nil
        end
    end
end

local function UpdateChunk(inst, chunk, dt, instant)
    if chunk.state == CHUNK_STATE.EMERGE then
        return
    end

    if chunk.head ~= nil then
        if inst.state == STATE.DEAD then

            return
        end

        if ShouldMove(inst) then
            chunk.head:PushEvent("worm_boss_move")
        end

        return
    end

    if chunk.tail ~= nil then
        if inst.state == STATE.DEAD then
            -- Nothing!

        elseif IsChunkMoving(inst, chunk) then
            chunk.tail:PushEvent("death")
            inst.tail = nil

            for i, testchunk in ipairs(inst.chunks) do
                if testchunk == chunk then
                    table.remove(inst.chunks, i)

                    break
                end
            end

            return
        end
    end

    if inst.state ~= STATE.DEAD then
        UpdateRegularChunk(inst, chunk, dt, instant)
    else
        UpdateRegularDeadChunk(inst, chunk, dt, instant)
    end
end

return {
    CHUNK_STATE = CHUNK_STATE,
    CHUNK_TEMPLATE = CHUNK_TEMPLATE,
    STATE = STATE,
    WORM_LENGTH = WORM_LENGTH,
    MAX_SEGTIME = CHUNK_TEMPLATE.segtimeMax,

    ChewAll = ChewAll,
    CreateNewChunk = CreateNewChunk,
    Digest = Digest,
    EmergeHead = EmergeHead,
    Knockback = Knockback,
    MoveSegmentUnderGround = MoveSegmentUnderGround,
    SetCreateChunkTask = SetCreateChunkTask,
    ShouldDoSpikeDamage = ShouldDoSpikeDamage,
    ShouldMove = ShouldMove,
    SpawnAboveGroundHeadCorpse = SpawnAboveGroundHeadCorpse,
    SpawnDirt = SpawnDirt,
    SpawnTail = SpawnTail,
    SpawnUnderGroundHeadCorpse = SpawnUnderGroundHeadCorpse,
    SpitAll = SpitAll,
    ToggleOffPhysics = ToggleOffPhysics,
    ToggleOnPhysics = ToggleOnPhysics,
    UpdateChunk = UpdateChunk,
}