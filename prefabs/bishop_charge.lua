local clockwork_common = require("prefabs/clockwork_common")
local easing = require("easing")

local assets = --Deprecated
{
	Asset("PKGREF", "anim/bishop_attack.zip"),
	Asset("PKGREF", "sound/chess.fsb"),
}

local assets2 =
{
	Asset("ANIM", "anim/wagdrone_projectile.zip"),
	Asset("SOUND", "sound/chess.fsb"),
}

--------------------------------------------------------------------------
--Deprecated old bishop attack

local function OnHit(inst, owner, target)
    SpawnPrefab("bishop_charge_hit").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end

local function OnAnimOver(inst)
    inst:DoTaskInTime(.3, inst.Remove)
end

local function OnThrown(inst)
    inst:ListenForEvent("animover", OnAnimOver)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("bishop_attack")
    inst.AnimState:SetBuild("bishop_attack")
    inst.AnimState:PlayAnimation("idle")

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(30)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetHitDist(2)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(OnThrown)

    return inst
end

local function PlayHitSound(proxy)
    local inst = CreateEntity()

    --[[Non-networked entity]]

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/shotexplo")

    inst:Remove()
end

local function hit_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    --Dedicated server does not need to spawn the local fx
    if not TheNet:IsDedicated() then
        --Delay one frame in case we are about to be removed
        inst:DoTaskInTime(0, PlayHitSound)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:DoTaskInTime(.5, inst.Remove)

    return inst
end

--------------------------------------------------------------------------
--New bishop attack

local FX_SCALE = 1.25

local function ShowBase(inst)
	local fx = CreateEntity()

	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")

	fx.AnimState:SetBank("wagdrone_projectile")
	fx.AnimState:SetBuild("wagdrone_projectile")
	fx.AnimState:PlayAnimation("crackle_projection")
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetLightOverride(1)
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(3)
	fx.AnimState:SetScale(FX_SCALE, FX_SCALE)

	fx.entity:SetParent(inst.entity)
	fx:ListenForEvent("animover", fx.Remove)

	return fx
end

local function Base_PostUpdate_Client(fx)
	fx.AnimState:SetFrame(fx.entity:GetParent().AnimState:GetCurrentAnimationFrame())
	fx:RemoveComponent("updatelooper")
end

local function ShowBase_Client(inst)
	local fx = ShowBase(inst)
	fx:AddComponent("updatelooper")
	fx.components.updatelooper:AddPostUpdateFn(Base_PostUpdate_Client)	
end

local RADIUS = 2.5 - 0.5
local PADDING = 3
local HIT_DURATION = 18 * FRAMES

local function OnUpdate(inst, dt)
	if not inst._soundplayed then
		inst._soundplayed = true
		inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/shotexplo")
	end
	if dt > 0 then
		inst.fadet = inst.fadet + dt
		inst.fadeflicker = (inst.fadeflicker + 1) % 4
	end
	local light = easing.inQuad(inst.fadet, 0.4, -0.4, HIT_DURATION)
	inst.Light:SetIntensity(inst.fadeflicker < 2 and light or light * 0.65)

	local combat = inst.caster and inst.caster:IsValid() and inst.caster.components.combat or inst.components.combat
	local dmg = combat.defaultdamage
	if combat.inst ~= inst then
		combat.ignorehitrange = true
	end

	local x, _, z = inst.Transform:GetWorldPosition()
	clockwork_common.FindAOETargetsAtXZ(combat.inst, x, z, RADIUS + PADDING,
		function(v)--, combat_inst) --combat_inst may or may not be same as inst
			if not inst.targets[v] then
				local range = RADIUS + v:GetPhysicsRadius(0)
				if v:GetDistanceSqToPoint(x, 0, z) < range * range then
					if IsEntityElectricImmune(v) then
						combat:SetDefaultDamage(dmg * TUNING.BISHOP_INSULATED_DAMAGE_MULT)
						combat:DoAttack(v, nil, nil, "electric")
						combat:SetDefaultDamage(dmg)
					else
						combat:DoAttack(v, nil, nil, "electric")
					end
					--V2C: "electrocute" immediately with no data to prevent forking from "electric" stimuli attack.
					--NOTE: players (e.g. wx) still have electrocute state even if "electricdamageimmune"
					v:PushEventImmediate("electrocute", { attacker = combat.inst, stimuli = "electric", numforks = 0 })
					inst.targets[v] = true
				end
			end
		end)

	if combat.inst ~= inst then
		combat.ignorehitrange = false
	end
end

local function DisableHits(inst)
	inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)
	inst.Light:Enable(false)
	inst.targets = nil
end

local function KeepTargetFn(inst)--, target)
	return false
end

local function SetupCaster(inst, caster)
	inst.caster = caster
	inst:SetPrefabNameOverride(caster.prefab) --for death announce
	if not inst._soundplayed then
		inst._soundplayed = true
		inst.SoundEmitter:PlaySound("dontstarve/creatures/bishop/shotexplo")
	end
	if inst.targets then
		OnUpdate(inst, 0)
	end
end

local function fx2fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddNetwork()

	inst.AnimState:SetBuild("wagdrone_projectile")
	inst.AnimState:SetBank("wagdrone_projectile")
	inst.AnimState:PlayAnimation("crackle_hit")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetScale(FX_SCALE, FX_SCALE)

	inst.Light:SetRadius(0.5)
	inst.Light:SetIntensity(0.4)
	inst.Light:SetFalloff(0.625)
	inst.Light:SetColour(255/255, 255/255, 236/255)

	inst:SetPrefabNameOverride("bishop") --for death announce

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst:AddTag("notarget")

	inst:AddComponent("updatelooper")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst.components.updatelooper:AddPostUpdateFn(ShowBase_Client)

		return inst
	end

	if not TheNet:IsDedicated() then
		ShowBase(inst)
	end

	inst.components.updatelooper:AddOnUpdateFn(OnUpdate)

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.BISHOP_DAMAGE)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.ignorehitrange = true


	inst.targets = {}
	inst.fadet = 0
	inst.fadeflicker = 0
	inst:DoTaskInTime(HIT_DURATION, DisableHits)
	inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 2 * FRAMES, inst.Remove)

	inst.persists = false

	inst.SetupCaster = SetupCaster

	return inst
end

return Prefab("bishop_charge", fn, assets), --deprecated
	Prefab("bishop_charge_hit", hit_fn), --deprecated
	--new ones below
	Prefab("bishop_charge2_fx", fx2fn, assets2)
