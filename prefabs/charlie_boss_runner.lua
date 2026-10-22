local assets =
{
	Asset("ANIM", "anim/shadow_insanity_player.zip"),
}

local prefabs =
{
	"nightmarefuel",
}

local brain = require("brains/charlie_boss_runnerbrain")
SetSharedLootTable("charlie_boss_runner",
{
    { "nightmarefuel",  0.5 },
})

local function OnAttackOther(inst, data)
	local target = data ~= nil and data.target or nil
	if target and target:IsValid() then
		if target.components.pinnable and target.components.pinnable:IsStuck() then
            target:PushEvent("knockback", { knocker = inst, radius = 2, strengthmult = 1 })
		end
	end
end

local TARGET_MUST_TAGS, TARGET_CANT_TAGS, TARGET_ONEOF_TAGS
local function IsValidTarget(guy, inst)
	return not FindClosestQueenTorch(guy)
end
local function RetargetFn(inst)
	return FindEntity(inst, TUNING.CHARLIE_BOSS_RUNNER_TARGET_RANGE, IsValidTarget, TARGET_MUST_TAGS, TARGET_CANT_TAGS, TARGET_ONEOF_TAGS)
end

local function KeepTargetFn(inst, target)
	return not FindClosestQueenTorch(target)
end

local function OnAttacked(inst, data) -- probably doesn't matter but it could be a 0 damage attack?
    inst.components.combat:SetTarget(data.attacker)
end

local function CreateHairFx(inst)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("shadow_insanity_player")
	fx.AnimState:SetBuild("shadow_insanity_player")
	fx.AnimState:PlayAnimation("flame_hair_fx", true)
	fx.AnimState:SetLightOverride(1)

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, "follow", 0, 0, 0, true)

	return fx
end

local function OnColourChanged(inst, r, g, b, a)
	for _, v in ipairs(inst.highlightchildren) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local HIGHLIGHT_OVERRIDE = { 0.1, 0.1, 0.1 }

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddLight()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.Light:SetIntensity(0.3)
	inst.Light:SetRadius(0.4)
	inst.Light:SetFalloff(0.9)
	inst.Light:SetColour(0.5, 0, 0)

    MakeCharacterPhysics(inst, 10, 0.5)
    RemovePhysicsColliders(inst)
    inst.Physics:SetCollisionGroup(COLLISION.SANITY)
    inst.Physics:CollidesWith(COLLISION.SANITY)
    inst.Physics:CollidesWith(COLLISION.WORLD)

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("shadow_insanity_player")
	inst.AnimState:SetBuild("shadow_insanity_player")
	inst.AnimState:PlayAnimation("walk_loop", true)
	inst.AnimState:SetLightOverride(1)

	inst:AddTag("character")
	inst:AddTag("shadow")
	inst:AddTag("shadow_aligned")
	inst:AddTag("gestaltnoloot")
	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("notraptrigger")

	inst.highlightoverride = HIGHLIGHT_OVERRIDE
	inst.highlightflashaddoverride = 0.1

	inst:AddComponent("spawnfader")
	inst:AddComponent("colouraddersync")

	if not TheNet:IsDedicated() then
		inst.highlightchildren = { CreateHairFx(inst) }
		inst.components.colouraddersync:SetColourChangedFn(OnColourChanged)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

    inst.scrapbook_hidehealth = true
	inst.scrapbook_anim = "scrapbook"

	if TARGET_MUST_TAGS == nil then
		TARGET_MUST_TAGS = { "_combat", "_health" }
		TARGET_CANT_TAGS = { "NOCLICK", "INLIMBO", "playerghost" }
		TARGET_ONEOF_TAGS = { "_sanity", "crazy" }
	end

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.CHARLIE_BOSS_RUNNER_WALKSPEED
    inst.components.locomotor.runspeed = TUNING.CHARLIE_BOSS_RUNNER_RUNSPEED
	inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = { ignorecreep = true }

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.CHARLIE_BOSS_RUNNER_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.CHARLIE_BOSS_RUNNER_DAMAGE)
    inst.components.combat:SetRetargetFunction(0.5, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat:SetRange(TUNING.CHARLIE_BOSS_RUNNER_POUNCE_RANGE)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('charlie_boss_runner')

	inst:AddComponent("knownlocations")

    inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("onattackother", OnAttackOther)

	inst:SetStateGraph("SGcharlie_boss_runner")
	inst:SetBrain(brain)

	inst.persists = false

	return inst
end

return Prefab("charlie_boss_runner", fn, assets, prefabs)
