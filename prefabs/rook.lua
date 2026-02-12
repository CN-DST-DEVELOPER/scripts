local clockwork_common = require "prefabs/clockwork_common"
local RuinsRespawner = require "prefabs/ruinsrespawner"

local assets =
{
    Asset("ANIM", "anim/rook.zip"),
    Asset("ANIM", "anim/rook_build.zip"),
    Asset("ANIM", "anim/rook_nightmare.zip"),
    Asset("SOUND", "sound/chess.fsb"),
    Asset("SCRIPT", "scripts/prefabs/clockwork_common.lua"),
    Asset("SCRIPT", "scripts/prefabs/ruinsrespawner.lua"),

	--see ground_chunks_breaking, now converted to client-side spawn for rook
	Asset("ANIM", "anim/ground_chunks_breaking.zip"),

	--previously only for minotaur, now used for the stun states
	Asset("ANIM", "anim/rook_attacks.zip"),
}

local prefabs =
{
    "gears",
    "collapse_small",
}

local prefabs_nightmare =
{
    "gears",
    "thulecite_pieces",
    "nightmarefuel",
    "collapse_small",
    "rook_nightmare_ruinsrespawner_inst",
}

local brain = require "brains/rookbrain"

SetSharedLootTable("rook",
{
    {"gears",  1.0},
    {"gears",  1.0},
})

SetSharedLootTable("rook_nightmare",
{
    {"gears",            1.0},
    {"nightmarefuel",    0.6},
    {"thulecite_pieces", 0.5},
})

local function Retarget(inst)
    return clockwork_common.Retarget(inst, TUNING.ROOK_TARGET_DIST)
end

local function KeepTarget(inst, target)
	return (inst.sg ~= nil and inst.sg:HasStateTag("running") and not inst:IsAsleep())
        or clockwork_common.KeepTarget(inst, target)
end

local function onothercollide(inst, other)
	if other:IsValid() and
		other.components.workable and
		other.components.workable:CanBeWorked() and
		other.components.workable.action ~= ACTIONS.NET
	then
		SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
		other.components.workable:Destroy(inst)
	else
		inst.recentlycharged[other] = nil
	end
end

local function DoCollideShake(inst)
	inst._shaketask = nil
	ShakeAllCameras(CAMERASHAKE.SIDE, 0.3, 0.02, 0.05, inst, 40)
end

local function oncollide(inst, other)
	if other and not other.isplayer and other:IsValid() and
		other.components.workable and
		other.components.workable:CanBeWorked() and
		other.components.workable:GetWorkAction() ~= ACTIONS.NET and
		inst:IsValid()
	then
		local t = GetTime()
		if (inst.recentlycharged[other] or -math.huge) + 3 <= t then
			local vx, _, vz = inst.Physics:GetVelocity()
			if vx * vx + vz * vz >= 42 then
				if inst._shaketask == nil then
					inst._shaketask = inst:DoTaskInTime(0, DoCollideShake)
				end
				inst:DoTaskInTime(2 * FRAMES, onothercollide, other)
				inst.recentlycharged[other] = t + 2 * FRAMES
			end
		end
	end
end

--------------------------------------------------------------------------

local function CreateGroundFx()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()

	inst.AnimState:SetBank("ground_breaking")
	inst.AnimState:SetBuild("ground_chunks_breaking")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetFinalOffset(3)

	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

local function OnGroundFx_Client(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local fx = CreateGroundFx()
	fx.Transform:SetPosition(x, 0, z)
	fx.SoundEmitter:PlaySound("dontstarve/common/stone_drop")
end

local function SpawnGroundFx(inst)
	inst.groundfx:push()
	if not TheNet:IsDedicated() then
		OnGroundFx_Client(inst)
	end
end

local function InitGroundFx_Client(inst)
	inst:ListenForEvent("rook.groundfx", OnGroundFx_Client)
end

--------------------------------------------------------------------------

local function MakeRook(name, common_postinit, master_postinit, _assets, _prefabs)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddDynamicShadow()
		inst.entity:AddNetwork()

		MakeCharacterPhysics(inst, 50, 1.5)

		inst.DynamicShadow:SetSize(3, 1.25)
		inst.Transform:SetFourFaced()
		inst.Transform:SetScale(0.66, 0.66, 0.66)

		inst.AnimState:SetBank("rook")

		inst:AddTag("monster")
		inst:AddTag("hostile")
		inst:AddTag("chess")
		inst:AddTag("rook")

		inst.groundfx = net_event(inst.GUID, "rook.groundfx")

		if common_postinit then
			common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			inst:ListenForEvent(0, InitGroundFx_Client)
			return inst
		end

		inst.override_combat_fx_size = "med"
		inst.kind = "" --for sound paths *unused?*
		inst.soundpath = "dontstarve/creatures/rook/"
		inst.effortsound = "dontstarve/creatures/rook/steam"

		inst.recentlycharged = {}
		inst.Physics:SetCollisionCallback(oncollide)

		inst:AddComponent("combat")
		inst.components.combat.hiteffectsymbol = "spring"
		inst.components.combat.playerdamagepercent = TUNING.ROOK_DAMAGE_PLAYER_PERCENT
		inst.components.combat:SetRange(2) --NOTE: this accounts for 0.66 scaling!
		inst.components.combat:SetAttackPeriod(TUNING.ROOK_ATTACK_PERIOD)
		inst.components.combat:SetDefaultDamage(TUNING.ROOK_DAMAGE)
		inst.components.combat:SetRetargetFunction(3, Retarget)
		inst.components.combat:SetKeepTargetFunction(KeepTarget)

		inst:AddComponent("follower")

		inst:AddComponent("health")
		inst.components.health:SetMaxHealth(TUNING.ROOK_HEALTH)

		inst:AddComponent("inspectable")
		inst:AddComponent("knownlocations")

		inst:AddComponent("lootdropper")

		inst:AddComponent("locomotor")
		inst.components.locomotor.walkspeed = TUNING.ROOK_WALK_SPEED
		inst.components.locomotor.runspeed =  TUNING.ROOK_RUN_SPEED
    	-- boat hopping setup
	    inst.components.locomotor:SetAllowPlatformHopping(true)

		inst:AddComponent("embarker")
		inst:AddComponent("drownable")

		inst:AddComponent("sleeper")
		inst.components.sleeper:SetWakeTest(clockwork_common.ShouldWake)
		inst.components.sleeper:SetSleepTest(clockwork_common.ShouldSleep)
		inst.components.sleeper:SetResistance(3)

		MakeLargeBurnableCharacter(inst, "swap_fire", nil, 1.4)
		MakeMediumFreezableCharacter(inst, "innerds")
		MakeHauntablePanic(inst)

		inst:SetStateGraph("SGrook")
		inst:SetBrain(brain)

		inst:ListenForEvent("attacked", clockwork_common.OnAttacked)
		inst:ListenForEvent("newcombattarget", clockwork_common.OnNewCombatTarget)

		clockwork_common.InitHomePosition(inst)
		clockwork_common.MakeBefriendable(inst)

		inst.SpawnGroundFx = SpawnGroundFx

		if master_postinit then
			master_postinit(inst)
		end

		return inst
	end

	return Prefab(name, fn, _assets, _prefabs)
end

--------------------------------------------------------------------------

local function normal_common_postinit(inst)
	inst.AnimState:SetBuild("rook_build")

	inst:AddTag("largecreature")
end

local function normal_master_postinit(inst)
	inst.components.lootdropper:SetChanceLootTable("rook")

	clockwork_common.MakeHealthRegen(inst)
end

--------------------------------------------------------------------------

local function nightmare_common_postinit(inst)
	inst.AnimState:SetBuild("rook_nightmare")

	inst:AddTag("cavedweller")
	inst:AddTag("shadow_aligned")
end

local function nightmare_master_postinit(inst)
	inst.kind = "_nightmare"
	inst.soundpath = "dontstarve/creatures/rook_nightmare/"
	inst.effortsound = "dontstarve/creatures/rook_nightmare/rattle"

	inst:AddComponent("acidinfusible")
	inst.components.acidinfusible:SetFXLevel(2)
	inst.components.acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.WEAKER)

	inst.components.lootdropper:SetChanceLootTable("rook_nightmare")
end

--------------------------------------------------------------------------

local function onruinsrespawn(inst, respawner)
	if not respawner:IsAsleep() then
		inst.sg:GoToState("ruinsrespawn")
	end
end

return MakeRook("rook", normal_common_postinit, normal_master_postinit, assets, prefabs),
	MakeRook("rook_nightmare", nightmare_common_postinit, nightmare_master_postinit,assets, prefabs_nightmare),
    RuinsRespawner.Inst("rook_nightmare", onruinsrespawn), RuinsRespawner.WorldGen("rook_nightmare", onruinsrespawn)
