local assets_hitfx =
{
	Asset("ANIM", "anim/shadow_insanity1_basic.zip"),
}

local prefabs =
{
	"charlie_boss_aoe_flame_fx",
	"charlie_boss_minion_hit_fx",
}

local AOEUtil = require("aoeutil")

--copied to "charlie_boss_projectiles.lua"
local function DoFlash(v, flashparams)
	if #flashparams > 0 then
		local c = table.remove(flashparams, 1)
		v.components.colouradder:PushColour("charlie_boss_minion", c, 0, 0, 0)
	else
		v.components.colouradder:PopColour("charlie_boss_minion")
		v._charlie_boss_minion_flash_task:Cancel()
		v._charlie_boss_minion_flash_task = nil
	end
end

local function OnAttackOther(inst, v)
	if v:IsValid() then
		if v.components.colouradder == nil then
			v:AddComponent("colouradder")
		end
		if v._charlie_boss_minion_flash_task then
			v._charlie_boss_minion_flash_task:Cancel()
		end
		local flashparams = { 0.65, 0.6, 0.5, 0.3 }
		v._charlie_boss_minion_flash_task = v:DoPeriodicTask(0, DoFlash, nil, flashparams)
		DoFlash(v, flashparams)

		local fx = SpawnPrefab("charlie_boss_minion_hit_fx")
		local r, sz, ht = GetCombatFxSize(v)
		local scale = math.clamp(r / 1.5, 0.5, 1)
		local yoffs = (ht == "high" and 2.5) or (ht == "low" and 0) or 1.5
		local x1, y1, z1 = v.Transform:GetWorldPosition()
		fx.Transform:SetPosition(x1, y1 + yoffs * scale, z1)
		fx.AnimState:SetScale(math.random() < 0.5 and -scale or scale, scale)

		if v.components.pinnable and v.components.pinnable:IsStuck() then
			if inst.caster and inst.caster:IsValid() then
				v:PushEvent("knockback", { knocker = inst.caster, radius = math.sqrt(inst:GetDistanceSqToInst(inst.caster)) + 3, strengthmult = 1 })
			else
				v:PushEvent("knockback", { knocker = inst, radius = 3, strengthmult = 1 })
			end
		end
	end
end

local function OnUpdate(inst, dt)
	if not inst.caster:IsValid() then
		inst:RemoveComponent("updatelooper")
		return
	end
	AOEUtil.Attack(inst, 2.4, inst.caster:GetAOEAttackTagSet(), inst._targets, nil, inst.caster, inst, inst)
end

local function OnJumpOut(inst)
	if inst.speed then
		inst.Physics:SetMotorVel(inst.speed * inst.speedmult, 0, 0)
	end
end

local function OnImpact(inst)
	inst.Physics:SetMotorVel(0, 0, 0)
	inst.Physics:Stop()

	SpawnPrefab("charlie_boss_aoe_flame_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
end

local function OnEndHits(inst)
	inst:RemoveComponent("updatelooper")
	inst:RemoveEventCallback("onattackother", inst._onattackother, inst.caster)
end

local function InitMinion(inst, speed, caster, targets)
	inst.speed = speed

	if caster then
		inst.caster = caster
		inst._targets = targets

		inst:ListenForEvent("resetboss", function() inst:Remove() end, caster)

		inst._onattackother = function(caster, data)
			if data and data.target and data.projectile == inst then
				OnAttackOther(inst, data.target)
			end
		end
		inst:ListenForEvent("onattackother", inst._onattackother, caster)

		inst.components.updatelooper:AddOnUpdateFn(OnUpdate)
		OnUpdate(inst, 0)
	end
end

local function MakeMinion(name, data)
	local assets =
	{
		Asset("ANIM", "anim/"..data.build..".zip"),
	}

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		MakeProjectilePhysics(inst)

		if data.facings == 6 then
			inst.Transform:SetSixFaced()
		elseif data.facings == 4 then
			inst.Transform:SetFourFaced()
		end

		inst.AnimState:SetBank(data.bank)
		inst.AnimState:SetBuild(data.build)
		inst.AnimState:PlayAnimation("charlie_atk")
		inst.AnimState:OverrideSymbol("shadowcreature_body_white", data.build, "white")
		inst.AnimState:OverrideSymbol("shadowcreature_body_red", data.build, "red")
		inst.AnimState:SetSymbolLightOverride("shadowcreature_body_red", 1)

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")

		--weapon (from weapon component) added to pristine state for optimization
		inst:AddTag("weapon")

		--projectile (from projectile component) added to pristine state for optimization
		inst:AddTag("projectile")

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("updatelooper")

		inst:AddComponent("weapon")
		inst.components.weapon:SetDamage(TUNING.CHARLIE_BOSS_MINION_DAMAGE)
		--weapon planar damage stacks with boss, so no need to add our own

		inst:AddComponent("projectile")

		inst:ListenForEvent("animover", inst.Remove)
		inst.persists = false

		inst:DoTaskInTime(data.jumpout_frame * FRAMES, OnJumpOut)
		inst:DoTaskInTime(data.impact_frame * FRAMES, OnImpact)
		inst:DoTaskInTime((data.impact_frame + 3) * FRAMES, OnEndHits)

		inst.speedmult = data.speedmult
		inst.InitMinion = InitMinion

		return inst
	end

	return Prefab(name, fn, assets, prefabs)
end

--------------------------------------------------------------------------

local function hitfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("shadowcreature1")
	inst.AnimState:SetBuild("shadow_insanity1_basic")
	inst.AnimState:PlayAnimation("charlie_atk_fx")
	inst.AnimState:SetFinalOffset(7)
	inst.AnimState:SetSymbolLightOverride("shadow_dust_parts", 1)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local minion_data =
{
	["charlie_boss_minion1"] =
	{
		bank = "shadowcreature1",
		build = "shadow_insanity1_basic",
		facings = 4,
		jumpout_frame = 2,
		impact_frame = 17,
		speedmult = 0.7,
	},

	["charlie_boss_minion2"] =
	{
		bank = "shadowcreature2",
		build = "shadow_insanity2_basic",
		facings = 6,
		jumpout_frame = 3,
		impact_frame = 13,
		speedmult = 1,
	},
}

local ret =
{
	Prefab("charlie_boss_minion_hit_fx", hitfxfn, assets_hitfx),
}
for k, v in pairs(minion_data) do
	table.insert(ret, MakeMinion(k, v))
end

return unpack(ret)
