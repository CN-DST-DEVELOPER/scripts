local assets =
{
	Asset("ANIM", "anim/shadow_thrall_mouth.zip"),
}

local prefabs =
{
	"voidcloth",
	"horrorfuel",
	"nightmarefuel",
	"shadowthrall_mouth_dupe_fx",
}

local brain = require("brains/shadowthrall_mouth_brain")

SetSharedLootTable("shadowthrall_mouth",
{
	{ "voidcloth",		1.00 },
	{ "voidcloth",		1.00 },
	{ "voidcloth",		1.00 },
	{ "voidcloth",		0.33 },
	{ "horrorfuel",		1.00 },
	{ "horrorfuel",		0.50 },
	{ "nightmarefuel",	1.00 },
	{ "nightmarefuel",	1.00 },
	{ "nightmarefuel",	0.67 },
})

local ALL_SHADOWTHRALL_MOUTHS = {}
local MASS = 50
local PHYSICS_RADIUS = 0.75

local function DisplayNameFn(inst)
	return ThePlayer and ThePlayer:HasTag("player_shadow_aligned") and STRINGS.NAMES.SHADOWTHRALL_MOUTH_ALLEGIANCE or nil
end

local function OnNewState(inst, data)
	if inst.sg:HasStateTag("stealth") then
		if not inst._stealth then
			inst._stealth = true
			inst.Transform:SetNoFaced()
			inst.DynamicShadow:Enable(false)
			RemovePhysicsColliders(inst)
			inst:AddTag("stealth")
			inst.components.combat.battlecryenabled = false
			inst.components.combat:SetAttackPeriod(TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_PERIOD)
			inst.components.combat:SetRange(TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_RANGE)
		end
		if not inst._stealthlit and not (data and data.statename == "stealth_on") then
			inst._stealthlit = true
			inst.AnimState:SetLightOverride(1)
		end
	elseif inst._stealth then
		inst._stealth = nil
		inst.Transform:SetSixFaced()
		if inst._stealthlit then
			inst._stealthlit = nil
			inst.AnimState:SetLightOverride(0)
		end
		inst.DynamicShadow:Enable(true)
		ChangeToCharacterPhysics(inst)
		inst:RemoveTag("stealth")
		inst.components.combat.battlecryenabled = true
		inst.components.combat:SetAttackPeriod(TUNING.SHADOWTHRALL_MOUTH_ATTACK_PERIOD)
		inst.components.combat:SetRange(TUNING.SHADOWTHRALL_MOUTH_ATTACK_RANGE)
	end
end

local function OnRooted(inst)
	if inst.dupe.components.rooted == nil then
		inst.dupe:AddComponent("rooted")
	end
	inst.dupe.components.rooted:AddSource(inst)
end

local function OnUnrooted(inst)
	if inst.dupe.components.rooted then
		inst.dupe.components.rooted:RemoveSource(inst)
    end
end

local function RetargetFn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local target = inst.components.combat.target
	if target then
		local range = TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_RANGE
		if target.isplayer and target:GetDistanceSqToPoint(x, y, z) < range * range then
			--Keep target
			return
		end
	end

	--V2C: WARNING: FindClosestPlayerInRange returns 2 values, which
	--              we don't want to return as our 2nd return value.  
	local player--[[, rangesq]] = FindClosestPlayerInRange(x, y, z, TUNING.SHADOWTHRALL_AGGRO_RANGE, true)
	return player
end

local function KeepTargetFn(inst, target)
	return inst.components.combat:CanTarget(target)
		and inst:IsNear(target, TUNING.SHADOWTHRALL_DEAGGRO_RANGE)
end

local _all_bite_targets = {}

local function TryRegisterBiteTarget(inst, target)
	if target then
		if inst._bite_target == target then
			local task = _all_bite_targets[target]
			if Periodic.is_instance(task) then
				task:Cancel()
			end
			_all_bite_targets[target] = true
			return true
		elseif inst._bite_target == nil and target:IsValid() and _all_bite_targets[target] == nil then
			if inst._stealth then
				for k in pairs(ALL_SHADOWTHRALL_MOUTHS) do
					if not (k._stealth or k.components.combat:InCooldown()) and k.components.combat:TargetIs(target) then
						return false
					end
				end
			end
			inst._bite_target = target
			_all_bite_targets[target] = true
			return true
		end
	end
	return false
end

local function OnBiteTargetCooldown(_, target)
	_all_bite_targets[target] = nil
end

local function ClearBiteTarget(inst, cooldown)
	if inst._bite_target then
		local task = _all_bite_targets[inst._bite_target]
		if Periodic.is_instance(task) then
			task:Cancel()
		end
		if cooldown then
			_all_bite_targets[inst._bite_target] = TheWorld:DoTaskInTime(cooldown, OnBiteTargetCooldown, inst._bite_target)
		else
			_all_bite_targets[inst._bite_target] = nil
		end
		inst._bite_target = nil
	end
end

local function OnRemoveEntity_Client(inst)
	ALL_SHADOWTHRALL_MOUTHS[inst] = nil
end

local function OnRemoveEntity_Server(inst)
	OnRemoveEntity_Client(inst)
	inst.dupe:Remove()
	ClearBiteTarget(inst)
end

local function OnSave(inst, data)
	data.stealth = inst._stealth or nil
end

local function OnLoad(inst, data)
	if data and data.stealth and not inst._stealth then
		inst.sg:GoToState("stealth_idle")
	end
end

--------------------------------------------------------------------------

local function OnCollide(inst, other, world_position_on_a_x, world_position_on_a_y, world_position_on_a_z, world_position_on_b_x, world_position_on_b_y, world_position_on_b_z, world_normal_on_b_x, world_normal_on_b_y, world_normal_on_b_z, lifetime_in_frames)
	if other.prefab == "charliearena_spike" and
		not inst.sg.statemem.collided and
		(	inst.sg.currentstate.name == "shrouden_bite" or
			inst.sg.currentstate.name == "shrouden_bite_loop"
		) and
		inst:IsValid()
	then
		local rot = inst.Transform:GetRotation()
		local rot1 = inst:GetAngleToPoint(world_position_on_a_x, 0, world_position_on_a_z)
		if DiffAngle(rot, rot1) < 75 then
			inst.sg.statemem.collided = true
		end
	end
end

local function ShouldAvoidAggroFn(target, inst)
	return false --false means target should not aggro on us - _-""
end

local function OnShroudenSummon(inst, shrouden, target)
	inst.shrouden = shrouden
	inst.persists = false
	inst.OnEntitySleep = inst.Remove
	inst:ListenForEvent("resetboss", function() inst:Remove() end, shrouden)

	inst:SetPrefabNameOverride(shrouden.prefab) -- for death announce
	inst:AddTag("NOCLICK")
	inst:AddTag("notarget")
	inst:AddTag("toughworker")
	inst:SetBrain(nil)
	inst.components.health:SetInvincible(true)
	inst.components.combat:SetRetargetFunction(nil)
	inst.components.combat:SetKeepTargetFunction(nil)
	inst.components.combat.shouldavoidaggrofn = ShouldAvoidAggroFn
	inst.components.planardamage:AddBonus(shrouden, TUNING.SHROUDEN_SUMMONS_BONUS_PLANAR_DAMAGE, "summoned")
	inst.components.lootdropper:SetLoot(nil)
	inst.components.lootdropper:SetLootSetupFn(nil)
	--inst.components.lootdropper.GetWintersFeastOrnaments = nil

	inst.Physics:SetCollisionCallback(OnCollide)

	inst.sg:GoToState("shrouden_bite", target)
end

--------------------------------------------------------------------------

--Runs on clients
local function CanMouseThrough(inst)
	return inst:HasTag("stealth"), true
end

local function lootsetfn(lootdropper)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)    
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(PHYSICS_RADIUS)
	MakeCharacterPhysics(inst, MASS, inst.physicsradiusoverride)
	inst.DynamicShadow:SetSize(2, 1)
	inst.Transform:SetSixFaced()

	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("shadowthrall")
	inst:AddTag("shadow_aligned")

	inst.AnimState:SetBank("shadow_thrall_mouth")
	inst.AnimState:SetBuild("shadow_thrall_mouth")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetSymbolLightOverride("fin_red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_red_particle", 1)
	inst.AnimState:SetSymbolLightOverride("smile_parts_02", 1)

	inst.CanMouseThrough = CanMouseThrough
	inst.displaynamefn = DisplayNameFn

	ALL_SHADOWTHRALL_MOUTHS[inst] = true

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst.OnRemoveEntity = OnRemoveEntity_Client

		return inst
	end

	inst.dupe = SpawnPrefab("shadowthrall_mouth_dupe_fx")
	inst.dupe:RemoveFromScene()
	inst.dupe.main = inst

	inst:AddComponent("inspectable")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.SHADOWTHRALL_MOUTH_WALKSPEED

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.SHADOWTHRALL_MOUTH_HEALTH)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.SHADOWTHRALL_MOUTH_BITE_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.SHADOWTHRALL_MOUTH_ATTACK_PERIOD)
	inst.components.combat:SetRange(TUNING.SHADOWTHRALL_MOUTH_ATTACK_RANGE)
	inst.components.combat:SetRetargetFunction(3, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.forcefacing = false
	inst.components.combat.hiteffectsymbol = "head_base"

	inst:AddComponent("timer")

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SHADOWTHRALL_MOUTH_BITE_PLANAR_DAMAGE)

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("shadowthrall_mouth")
	--inst.components.lootdropper.GetWintersFeastOrnaments = GetWintersFeastOrnaments
	inst.components.lootdropper.y_speed = 4
	inst.components.lootdropper.y_speed_variance = 3
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("colouradder")
	inst.components.colouradder:AttachChild(inst.dupe)

	inst:AddComponent("bloomer")
	inst.components.bloomer:AttachChild(inst.dupe)

	inst:AddComponent("knownlocations")

	inst:SetStateGraph("SGshadowthrall_mouth")
	inst:SetBrain(brain)

	inst:ListenForEvent("newstate", OnNewState)
	inst.dupe:ListenForEvent("rooted", OnRooted, inst)
	inst.dupe:ListenForEvent("unrooted", OnUnrooted, inst)

	inst._bite_target = nil
	inst.TryRegisterBiteTarget = TryRegisterBiteTarget
	inst.ClearBiteTarget = ClearBiteTarget
	inst.OnRemoveEntity = OnRemoveEntity_Server
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnShroudenSummon = OnShroudenSummon

    if IsSpecialEventActive(SPECIAL_EVENTS.YOTS) then
        inst.components.lootdropper:SetLootSetupFn(lootsetfn)
    end

	return inst
end

local function dupe_OnAnimOver(inst)
	if inst.main then
		inst.main:PushEvent("dupe_animover")
	end
end

local function dupefxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst.entity:AddPhysics()
	inst.Physics:SetMass(MASS)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(5)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(COLLISION.GROUND)
	inst.Physics:SetCapsule(PHYSICS_RADIUS, 1)

	inst.DynamicShadow:SetSize(2, 1)

	inst.Transform:SetSixFaced()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("shadow_thrall_mouth")
	inst.AnimState:SetBuild("shadow_thrall_mouth")
	inst.AnimState:SetSymbolLightOverride("fin_red", 1)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	inst:AddComponent("colouradder")
	inst:AddComponent("bloomer")

	inst:ListenForEvent("animover", dupe_OnAnimOver)

	return inst
end

return Prefab("shadowthrall_mouth", fn, assets, prefabs),
	Prefab("shadowthrall_mouth_dupe_fx", dupefxfn, assets)
