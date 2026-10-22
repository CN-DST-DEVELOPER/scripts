local assets =
{
    Asset("ANIM", "anim/charliearena_spike.zip"),
}

local prefabs =
{
    "dreadstone",
    "charliearena_spike_explode_fx",
}

SetSharedLootTable( 'charliearena_spike',
{
    {'dreadstone',  1.00},
})

local AOEUtil = require("aoeutil")

local AOE_TAGSET
local function GetAOEAttackTagSet(inst) -- only if not tied to shrouden (debug)
	if AOE_TAGSET == nil then
		AOE_TAGSET = AOEUtil.AttackTagSet()
		AOE_TAGSET:AppendCantTags("shadowthrall", "shadow", "shadowcreature", "shadowchesspiece", "shadowboss")
		-- AOE_TAGSET:Register() don't register tags for the debug ones
	end
	return AOE_TAGSET
end

local function PlayCrackSound(inst, vol)
    inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, vol)
end

local function OnSoundTask(inst, vol)
    inst.soundtask = nil
    PlayCrackSound(inst, vol)
end

local AOE_RADIUS = 1
local function DoDamage(inst)
    inst.task = nil
    inst:RemoveTag("NOCLICK")
    inst.Physics:SetActive(true)
    inst.components.workable:SetWorkable(true)
    inst.AnimState:SetLayer(LAYER_WORLD)
    inst.AnimState:SetSortOrder(0)
    PlayCrackSound(inst, 1)
	PreventCharacterCollisionsWithPlacedObjects(inst)

    local tagset
    if inst.shrouden and inst.shrouden:IsValid() then
        tagset = inst.shrouden:GetAOEAttackTagSet()
    else
        tagset = GetAOEAttackTagSet(inst)
        inst.shrouden = nil
    end

    local targets = {}
    AOEUtil.WorkAndDig(inst, AOE_RADIUS, targets)
    AOEUtil.Attack(inst, AOE_RADIUS, tagset, targets)
end

local function Spawn(inst)
    inst.spawn_task = nil
    inst:Show()
    inst:AddTag("NOCLICK")
    inst.Physics:SetActive(false)
    inst.components.workable:SetWorkable(false)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:PlayAnimation("spike"..inst.variation.."_pre", false)
    inst.AnimState:PushAnimation("spike"..inst.variation.."_loop", true)
    PlayCrackSound(inst, .1)
    inst.soundtask = inst:DoTaskInTime(15 * FRAMES, OnSoundTask, .25)
    inst.task = inst:DoTaskInTime(29 * FRAMES, DoDamage)
end

local function Destroy(inst)
    if inst.destroy_task then
        inst.destroy_task:Cancel()
        inst.destroy_task = nil
    end
    if inst.soundtask then
        inst.soundtask:Cancel()
        inst.soundtask = nil
    end
    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end
    if inst.explosion_task then
        inst.explosion_task:Cancel()
        inst.explosion_task = nil
    end
    if inst.spawn_task then
        inst.spawn_task:Cancel()
        inst.spawn_task = nil
    end
	inst.Physics:SetActive(false)
    inst.SoundEmitter:PlaySound("dontstarve/impacts/lava_arena/fossilized_break")
    inst.AnimState:PlayAnimation("spike_pst")
    inst:ListenForEvent("animover", inst.Remove)
    inst.persists = false
end

local function DestroyInTime(inst, time)
    if inst.destroy_task then
        inst.destroy_task:Cancel()
    end
    inst.destroy_task = inst:DoTaskInTime(time, Destroy)
end

local function OnWorkFinished(inst, worker)
    local pt = inst:GetPosition()
    if worker and worker.isplayer then -- loot only from player
        inst:AddComponent("lootdropper")
        inst.components.lootdropper:SetChanceLootTable("charliearena_spike")
        inst.components.lootdropper:DropLoot(pt)
    end

    Destroy(inst)
end

local function ResetPlayerProx(inst) -- Small Hack to get the player prox running constantly.
    inst.components.playerprox.isclose = false
end

local OnUpdate
local EXPLODE_RADIUS = 3
local function IsValidToWork(v, inst)
    return v.prefab ~= "charliearena_spike"
end

local function DoExplosion(inst)
    inst.explosion_task = nil

    local tagset
    if inst.shrouden and inst.shrouden:IsValid() then
        tagset = inst.shrouden:GetAOEAttackTagSet()
    else
        tagset = GetAOEAttackTagSet(inst)
        inst.shrouden = nil
    end

    inst:RemoveTag("groundspike")
    inst.components.combat:SetDefaultDamage(0)
    inst.components.planardamage:SetBaseDamage(TUNING.CHARLIEARENA_SPIKE_EXPLOSION_PLANAR_DAMAGE)

    local targets = {}
    AOEUtil.WorkAndDig(inst, {
        radius = EXPLODE_RADIUS,
        work_filterfn = IsValidToWork,
    }, targets)
    AOEUtil.Attack(inst, EXPLODE_RADIUS, tagset, targets)

    SpawnPrefab("charliearena_spike_explode_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())

    inst.AnimState:SetAddColour(.6, .2, .2, 0)
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)
    Destroy(inst)
end

OnUpdate = function(inst, dt)
    if inst.flash < 1 then
        inst.flash = inst.flash + dt * inst.timescale
        local c = math.min(1, inst.flash * 1)
        inst.AnimState:SetAddColour(c, c * .2, c * .2, 0)
        inst.AnimState:SetMultColour(1, 1 - c, 1 - c, 1)
    else
        if inst.blink then
            inst.blink = (inst.blink % 4) + 1
            local c = math.min(1, (inst.blink > 2 and 0.6 or 1))
            inst.AnimState:SetAddColour(c, c * .2, c * .2, 0)
            inst.AnimState:SetMultColour(1, 1 - c, 1 - c, 1)
        else
            inst.flash = 1
            inst.blink = math.random(4)
            inst.AnimState:SetAddColour(1, .2, .2, 0)
            inst.AnimState:SetMultColour(1, 1 - .8, 1 - .8, 1)
            inst.explosion_task = inst:DoTaskInTime(.6 + math.random() * .25, DoExplosion)
        end
    end
end

local function StartExplosionSequence(inst)
    inst.flash = 0
    inst.timescale = 1.2 + .3 * math.random()
    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(OnUpdate)
    OnUpdate(inst, 0)
end

local function OnPlayerNear(inst, player)
    if player and player.components.sanity and player.components.sanity:IsLunacyMode()
        and not inst:HasTag("NOCLICK")
        and inst.entity:IsVisible()
        and not inst.components.updatelooper then
        StartExplosionSequence(inst)
        player:PushEvent("ms_dreadstonespikeexploding")
    else
        if inst.reset_prox_task ~= nil then
            inst.reset_prox_task:Cancel()
        end
        inst.reset_prox_task = inst:DoTaskInTime(0, ResetPlayerProx)
    end
end

local function SetShrouden(inst, shrouden)
    inst.shrouden = shrouden
    inst.components.planardamage:AddBonus(shrouden, TUNING.SHROUDEN_SUMMONS_BONUS_PLANAR_DAMAGE, "summoned")
    inst:ListenForEvent("resetboss", function() inst:Remove() end, shrouden)
end

local function OnShroudenSummon(inst, shrouden)
    inst:Hide()
    inst.Physics:SetActive(false)
    SetShrouden(inst, shrouden)

    inst.spawn_task = inst:DoTaskInTime(math.random() * .5, inst.Spawn)
end

local function KeepTargetFn()
    return false
end

local function OnSave(inst, data)
    data.variation = inst.variation
end

local function OnLoad(inst, data)
    if data and data.variation then
        inst.variation = data.variation
        if inst.variation ~= 1 then
            inst.AnimState:PlayAnimation("spike"..inst.variation.."_loop", true)
        end
    end
end

local function spikefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(0.8)
	MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.AnimState:SetBank("charliearena_spike")
    inst.AnimState:SetBuild("charliearena_spike")
    inst.AnimState:PlayAnimation("spike1_loop", true)
    inst.AnimState:SetSymbolLightOverride("dreadstone_red", 1)
    inst.AnimState:SetSymbolLightOverride("ground_light", 1)

    inst:AddTag("groundspike")
    inst:AddTag("toughworker")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.variation = math.random(3)
    if inst.variation ~= 1 then
        inst.AnimState:PlayAnimation("spike"..inst.variation.."_loop", true)
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetOnFinishCallback(OnWorkFinished)
    inst.components.workable:SetMaxWork(TUNING.CHARLIEARENA_SPIKE_WORK)
    inst.components.workable:SetWorkLeft(TUNING.CHARLIEARENA_SPIKE_WORK)
	inst.components.workable:SetRequiresToughWork(true)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.CHARLIEARENA_SPIKE_DAMAGE)
    inst.components.combat.playerdamagepercent = .5
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SHADOWTHRALL_HANDS_PLANAR_DAMAGE)

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(3.5, 4)
    inst.components.playerprox:SetOnPlayerNear(OnPlayerNear)

    inst.Spawn = Spawn
    inst.Destroy = Destroy
    inst.DestroyInTime = DestroyInTime

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.SetShrouden = SetShrouden
    inst.OnShroudenSummon = OnShroudenSummon

    return inst
end

--------------------------------------------------------------------------

local function fx_OnEntityWake(inst)
    inst.OnEntityWake = nil
	inst.SoundEmitter:PlaySound("rifts2/shrouden/pillar_explode")
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("charliearena_spike")
	inst.AnimState:SetBuild("charliearena_spike")
	inst.AnimState:PlayAnimation("explode")
	inst.AnimState:SetSymbolLightOverride("sb_cloud_scale_1", 1)
	inst.AnimState:SetSymbolLightOverride("hit_2", 1)
	inst.AnimState:SetSymbolLightOverride("sleepcloud_pre", 1)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

    inst.OnEntityWake = fx_OnEntityWake

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

--NOTE: "charliearena_spike" prefab name is used in some shrouden checks, please do not rename.
return Prefab("charliearena_spike", spikefn, assets, prefabs),
	Prefab("charliearena_spike_explode_fx", fxfn, assets)
