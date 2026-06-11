local prefabs =
{
    "nightmarefuel",
}

local prefabs_ruinsnightmare =
{
	"ruinsnightmare_horn_attack",
	"nightmarefuel",
	"horrorfuel",
}

local brain = require( "brains/nightmarecreaturebrain")

local function retargetfn(inst)
    local maxrangesq = TUNING.SHADOWCREATURE_TARGET_DIST * TUNING.SHADOWCREATURE_TARGET_DIST
    local rangesq, rangesq1, rangesq2 = maxrangesq, math.huge, math.huge
    local target1, target2 = nil, nil
    for i, v in ipairs(AllPlayers) do
        if --[[v.components.sanity:IsCrazy() and]] not v:HasTag("playerghost") then
            local distsq = v:GetDistanceSqToInst(inst)
            if distsq < rangesq then
                if inst.components.shadowsubmissive:TargetHasDominance(v) then
                    if distsq < rangesq1 and inst.components.combat:CanTarget(v) then
                        target1 = v
                        rangesq1 = distsq
                        rangesq = math.max(rangesq1, rangesq2)
                    end
                elseif distsq < rangesq2 and inst.components.combat:CanTarget(v) then
                    target2 = v
                    rangesq2 = distsq
                    rangesq = math.max(rangesq1, rangesq2)
                end
            end
        end
    end

    if target1 ~= nil and rangesq1 <= math.max(rangesq2, maxrangesq * .25) then
        --Targets with shadow dominance have higher priority within half targeting range
        --Force target switch if current target does not have shadow dominance
        return target1, not inst.components.shadowsubmissive:TargetHasDominance(inst.components.combat.target)
    end
    return target2
end

SetSharedLootTable("nightmare_creature",
{
    {"nightmarefuel", 1.0},
    {"nightmarefuel", 0.5},
})

local function CanShareTargetWith(dude)
    return dude:HasTag("nightmarecreature") and not dude.components.health:IsDead()
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        inst.components.combat:SetTarget(data.attacker)
        inst.components.combat:ShareTarget(data.attacker, 30, CanShareTargetWith, 1)
    end
end

local function OnDeath(inst, data)
    if data ~= nil and data.afflicter ~= nil and data.afflicter:HasTag("crazy") and inst.components.lootdropper.loot == nil then
        --max one nightmarefuel if killed by a crazy NPC (e.g. Bernie)
        inst.components.lootdropper:SetLoot({ "nightmarefuel" })
        inst.components.lootdropper:SetChanceLootTable(nil)
    end
end

local function ScheduleCleanup(inst)
    inst:DoTaskInTime(math.random() * TUNING.NIGHTMARE_SEGS.DAWN * TUNING.SEG_TIME, function()
        inst.components.lootdropper:SetLoot({})
        inst.components.lootdropper:SetChanceLootTable(nil)
        inst.components.health:Kill()
    end)
end

local function OnNightmareDawn(inst, dawn)
    if dawn then
        ScheduleCleanup(inst)
    end
end

local function CLIENT_ShadowSubmissive_HostileToPlayerTest(inst, player)
	if player:HasTag("shadowdominance") then
		return false
	end
	--V2C: nightmare creatures are always visible and hostile, unlike shadowcreatures
	return true

	--[[local combat = inst.replica.combat
	if combat ~= nil and combat:GetTarget() == player then
		return true
	end
	local sanity = player.replica.sanity
	if sanity ~= nil and sanity:IsCrazy() then
		return true
	end
	return false]]
end

--------------------------------------------------------------------------------------------------------------------------------

local RUINSNIGHTMARE_SCRAPBOOK_HIDE = { "red" }

local WALK_SOUNDNAME = "WALK_SOUNDNAME"

local function RuinsNightmare_OnNewState(inst, data)
    if inst.sg:HasStateTag("moving") then
        if not inst.SoundEmitter:PlayingSound(WALK_SOUNDNAME) then
            inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/movement", WALK_SOUNDNAME)
        end

    elseif data ~= nil and data.statename == "walk_stop" then
        inst.SoundEmitter:KillSound(WALK_SOUNDNAME)
        inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/movement_pst")
    else
        inst.SoundEmitter:KillSound(WALK_SOUNDNAME)
    end
end

SetSharedLootTable("ruinsnightmare",
{
    { "nightmarefuel", 1.00 },
    { "nightmarefuel", 1.00 },
    { "nightmarefuel", 0.50 },
    { "nightmarefuel", 0.25 },
})

SetSharedLootTable("ruinsnightmare_rifts",
{
    { "horrorfuel",    1.00 },
    { "horrorfuel",    1.00 },
    { "horrorfuel",    0.50 },
    { "nightmarefuel", 1.00 },
    { "nightmarefuel", 0.67 },
})


local function RuinsNightmare_CheckRift(inst)
    local riftspawner = TheWorld.components.riftspawner

    if riftspawner ~= nil and riftspawner:IsShadowPortalActive() then
        if inst.components.planarentity == nil then
            inst:AddComponent("planarentity")

            inst:AddComponent("planardamage")
            inst.components.planardamage:SetBaseDamage(TUNING.RUINSNIGHTMARE_PLANAR_DAMAGE)

            inst.components.lootdropper:SetChanceLootTable("ruinsnightmare_rifts")
            inst.components.locomotor.walkspeed = TUNING.RUINSNIGHTMARE_SPEED_RIFTS

            inst.AnimState:ShowSymbol("red")
            inst.AnimState:SetLightOverride(1)
            inst.AnimState:SetMultColour(1, 1, 1, 0.65)
        end

    elseif inst.components.planarentity ~= nil then
        inst:RemoveComponent("planarentity")
        inst:RemoveComponent("planardamage")

        inst.components.lootdropper:SetChanceLootTable("ruinsnightmare")
        inst.components.locomotor.walkspeed = TUNING.RUINSNIGHTMARE_SPEED

        inst.AnimState:HideSymbol("red")
        inst.AnimState:SetLightOverride(0)
        inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    end
end

--------------------------------------------------------------------------------------------------------------------------------

local function MakeShadowCreature(data)
    local bank = data.bank
    local build = data.build

    local assets =
    {
        Asset("ANIM", "anim/"..data.build..".zip"),
    }

    local sounds =
    {
        attack = "dontstarve/sanity/creature"..data.num.."/attack",
        attack_grunt = "dontstarve/sanity/creature"..data.num.."/attack_grunt",
        death = "dontstarve/sanity/creature"..data.num.."/die",
        idle = "dontstarve/sanity/creature"..data.num.."/idle",
        taunt = "dontstarve/sanity/creature"..data.num.."/taunt",
        appear = "dontstarve/sanity/creature"..data.num.."/appear",
        disappear = "dontstarve/sanity/creature"..data.num.."/dissappear",
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.Transform:SetFourFaced()

        MakeCharacterPhysics(inst, 10, data.physics_rad or 1.5)
        RemovePhysicsColliders(inst)
        inst.Physics:SetCollisionGroup(COLLISION.SANITY)
        inst.Physics:CollidesWith(COLLISION.SANITY)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("idle_loop")
        inst.AnimState:SetMultColour(1, 1, 1, 0.5)
        inst.AnimState:UsePointFiltering(true)

        inst:AddTag("nightmarecreature")
        inst:AddTag("gestaltnoloot")
        inst:AddTag("monster")
        inst:AddTag("hostile")
        inst:AddTag("shadow")
        inst:AddTag("notraptrigger")
        inst:AddTag("shadow_aligned")

		--shadowsubmissive (from shadowsubmissive component) added to pristine state for optimization
		inst:AddTag("shadowsubmissive")

		inst.HostileToPlayerTest = CLIENT_ShadowSubmissive_HostileToPlayerTest

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
	    inst.components.locomotor:SetTriggersCreep(false)
        inst.components.locomotor.pathcaps = { ignorecreep = true }
        inst.components.locomotor.walkspeed = data.speed
        inst.sounds = sounds

        inst:SetStateGraph(data.stategraph or "SGshadowcreature")
        inst:SetBrain(brain)

        inst:AddComponent("sanityaura")
        inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE

        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(data.health)

        inst:AddComponent("combat")
        inst.components.combat:SetDefaultDamage(data.damage)
        inst.components.combat:SetAttackPeriod(data.attackperiod)
        inst.components.combat:SetRetargetFunction(3, retargetfn)

        inst:AddComponent("shadowsubmissive")

        inst:AddComponent("lootdropper")
        inst.components.lootdropper:SetChanceLootTable("nightmare_creature")

        inst:ListenForEvent("attacked", OnAttacked)
        inst:ListenForEvent("death", OnDeath)

        inst:WatchWorldState("isnightmaredawn", OnNightmareDawn)

        inst:AddComponent("knownlocations")

        if data.master_postinit ~= nil then
            data.master_postinit(inst, data)
        end

        return inst
    end

	return Prefab(data.name, fn, assets, data.prefabs or prefabs)
end

local data =
{
    {
        name = "crawlingnightmare",
        build = "shadow_insanity1_basic",
        bank = "shadowcreature1",
        num = 1,
        speed = TUNING.CRAWLINGHORROR_SPEED,
        health = TUNING.CRAWLINGHORROR_HEALTH,
        damage = TUNING.CRAWLINGHORROR_DAMAGE,
        attackperiod = TUNING.CRAWLINGHORROR_ATTACK_PERIOD,
        sanityreward = TUNING.SANITY_MED,
    },
    {
        name = "nightmarebeak",
        build = "shadow_insanity2_basic",
        bank = "shadowcreature2",
        num = 2,
        speed = TUNING.TERRORBEAK_SPEED,
        health = TUNING.TERRORBEAK_HEALTH,
        damage = TUNING.TERRORBEAK_DAMAGE,
        attackperiod = TUNING.TERRORBEAK_ATTACK_PERIOD,
        sanityreward = TUNING.SANITY_LARGE,
    },
    {
        name = "ruinsnightmare",
        build = "shadow_insanity3_basic",
        bank = "shadowcreature3",
        num = 3,
        speed = TUNING.RUINSNIGHTMARE_SPEED,
        health = TUNING.RUINSNIGHTMARE_HEALTH,
        damage = TUNING.RUINSNIGHTMARE_DAMAGE,
        attackperiod = TUNING.RUINSNIGHTMARE_ATTACK_PERIOD,
        sanityreward = TUNING.SANITY_HUGE,
        physics_rad = 2,
        stategraph = "SGruinsnightmare",
        master_postinit = function(inst)
            inst.scrapbook_hide = RUINSNIGHTMARE_SCRAPBOOK_HIDE

            inst.AnimState:HideSymbol("red")

            inst.components.combat:SetRange(TUNING.RUINSNIGHTMARE_ATTACK_RANGE)

            inst.components.lootdropper:SetChanceLootTable("ruinsnightmare")

            inst._onnewstate = RuinsNightmare_OnNewState
            inst._onriftchanged = function(world) RuinsNightmare_CheckRift(inst) end

            inst._onriftchanged(TheWorld)

            inst:ListenForEvent("newstate", inst._onnewstate)
            inst:ListenForEvent("ms_riftaddedtopool",     inst._onriftchanged, TheWorld)
            inst:ListenForEvent("ms_riftremovedfrompool", inst._onriftchanged, TheWorld)
		end,
		prefabs = prefabs_ruinsnightmare,
    },
}

local ret = {}
for i, v in ipairs(data) do
    table.insert(ret, MakeShadowCreature(v))
end

return unpack(ret)
