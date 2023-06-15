local assets =
{
	Asset("ANIM", "anim/ruins_shadeling.zip"),
}

local prefabs =
{
	"ruinsrelic_chair_blueprint",
}

local LOOT =
{
	"ruinsrelic_chair_blueprint",
	"horrorfuel",
}

local function CalcSanityAura(inst, observer)
	return observer.components.sanity:IsCrazy()
		and -TUNING.SANITYAURA_MED
		or 0
end

local function KeepTargetFn()
	return false
end

local function DoDropLoot(inst)
	inst.components.lootdropper:DropLoot(inst:GetPosition())
	inst:PushEvent("ruins_shadeling_looted")
	if inst:IsAsleep() then
		inst:Remove()
	else
		inst.despawned = true
	end
end

local function DisableCombat(inst)
	inst:AddTag("NOCLICK")
	inst:AddTag("notarget")
end

local function OnDeath(inst)
	inst:RemoveEventCallback("death", OnDeath)
	inst:ListenForEvent("animover", inst.Remove)
	inst.AnimState:PlayAnimation("wake")
	inst:DoTaskInTime(25 * FRAMES, DisableCombat)
	inst:DoTaskInTime(57 * FRAMES, DoDropLoot)
end

local function Despawn(inst)
	if not (inst.despawned or inst.components.health:IsDead()) then
		if inst:IsAsleep() then
			inst:Remove()
		else
			inst.despawned = true
			inst:RemoveEventCallback("death", OnDeath)
			inst:ListenForEvent("animover", inst.Remove)
			inst.AnimState:PlayAnimation("wake")
			inst:DoTaskInTime(25 * FRAMES, DisableCombat)
		end
	end
end

local function TryRemoveOffScreen(inst)
	inst.sleeptask = nil
	--just don't want to remove when we're about to drop loot
	if inst.despawned or not inst.components.health:IsDead() then
		inst:Remove()
	end
end

local function OnEntitySleep(inst)
	if inst.sleeptask == nil then
		inst.sleeptask = inst:DoTaskInTime(1, TryRemoveOffScreen)
	end
end

local function OnEntityWake(inst)
	if inst.sleeptask ~= nil then
		inst.sleeptask:Cancel()
		inst.sleeptask = nil
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("shadowcreature")
	inst:AddTag("monster")
	inst:AddTag("shadow")
	inst:AddTag("shadow_aligned")
	inst:AddTag("gestaltnoloot")

	inst.AnimState:SetBank("ruins_shadeling")
	inst.AnimState:SetBuild("ruins_shadeling")
	inst.AnimState:PlayAnimation("sit", true)
	inst.AnimState:SetLightOverride(1)

	if not TheNet:IsDedicated() then
		-- this is purely view related
		inst:AddComponent("transparentonsanity")
		inst.components.transparentonsanity.most_alpha = .7
		inst.components.transparentonsanity.osc_amp = .1
		inst.components.transparentonsanity:ForceUpdate()
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aurafn = CalcSanityAura

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(1)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.hiteffectsymbol = "shad_head"

	inst:AddComponent("planarentity")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetLoot(LOOT)

	inst:ListenForEvent("death", OnDeath)
	inst.Despawn = Despawn
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake
	inst.persists = false

	return inst
end

return Prefab("ruins_shadeling", fn, assets, prefabs)
