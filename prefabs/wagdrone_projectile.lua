local assets =
{
	Asset("ANIM", "anim/wagdrone_projectile.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagdrone_common.lua"),
}

local easing = require("easing")
local WagdroneCommon = require("prefabs/wagdrone_common")

local function FxPostUpdate(fx)
	fx.AnimState:SetFrame(fx.entity:GetParent().AnimState:GetCurrentAnimationFrame())
	--V2C: It's generally NOT OK to modify updatelooper during PostUpdate loop,
	--     but we'll do it here because we know that nothing external should be
	--     affecting or interacting with this client fx entity.
	fx:RemoveComponent("updatelooper")
end

local function OnShowBase(inst)
	if not inst.showbase:value() then
		return
	end

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

	fx.entity:SetParent(inst.entity)
	fx:ListenForEvent("animover", fx.Remove)

	if not TheWorld.ismastersim then
		if inst.AnimState:IsCurrentAnimation("crackle_hit") then
			fx.AnimState:SetFrame(inst.AnimState:GetCurrentAnimationFrame())
		else
			fx:AddComponent("updatelooper")
			fx.components.updatelooper:AddPostUpdateFn(FxPostUpdate)
		end
	end
end

local function DisableHits(inst, OnUpdate)
	inst.showbase:set_local(false)
	inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)
	inst.Light:Enable(false)
end

local RADIUS = 2 - 0.5
local PADDING = 3

local function OnUpdate(inst, dt)
	local hitduration = 18 * FRAMES
	local x, y, z = inst.Transform:GetWorldPosition()
	if inst.targets == nil then
		if y < 0.1 then
			inst.Physics:Stop()
			inst.Physics:Teleport(x, 0, z)
			inst.Physics:SetActive(false)
			inst.AnimState:PlayAnimation("crackle_hit")
			inst:DoTaskInTime(hitduration, DisableHits, OnUpdate)
			inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 2 * FRAMES, inst.Remove)
			inst.showbase:set(true)
			if not TheNet:IsDedicated() then
				OnShowBase(inst)
			end
			inst.targets = {}
			inst.fadet = 0
			inst.fadeflicker = 0
			inst.Light:SetRadius(0.5)
			inst.Light:SetFalloff(0.625)
		else
			local k = math.max(0, 5 - y)
			k = easing.outQuad(k, 0, 1, 5)
			inst.Light:SetRadius(0.5 - k * 0.1)
			inst.Light:SetFalloff(0.5 + k * 0.35)
			inst.Light:SetIntensity(0.8 + k * 0.15)
			return --still falling
		end
	end

	if dt > 0 then
		inst.fadet = inst.fadet + dt
		inst.fadeflicker = (inst.fadeflicker + 1) % 4
	end
	local light = easing.inQuad(inst.fadet, 0.4, -0.4, hitduration)
	inst.Light:SetIntensity(inst.fadeflicker < 2 and light or light * 0.65)

	for i, v in ipairs(WagdroneCommon.FindShockTargets(x, z, RADIUS + PADDING)) do
		if inst.targets[v] == nil and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = RADIUS + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, 0, z) < range * range and
				v.components.combat and
				inst.components.combat:CanTarget(v)
			then
				if IsEntityElectricImmune(v) then
					inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_FLYING_DAMAGE * TUNING.WAGDRONE_FLYING_INSULATED_DAMAGE_MULT)
					inst.components.combat:DoAttack(v, nil, nil, "electric")
					inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_FLYING_DAMAGE)
				else
					inst.components.combat:DoAttack(v, nil, nil, "electric")
					v:PushEventImmediate("electrocute") -- (NOTE): Don't add electric tag to laserwire, or it counts as a fork attack! we dont want that!
				end
				inst.targets[v] = true
			end
		end
	end
end

local function Launch(inst, x, y, z)
	inst.Follower:StopFollowing()
	inst.entity:SetParent(nil)
	inst.Physics:Teleport(x, y, z)
	inst.Physics:SetMotorVel(0, -15, 0)
	inst.AnimState:SetScale(1, 1)
	inst.Light:Enable(true)
	inst.components.updatelooper:AddOnUpdateFn(OnUpdate)
	inst.SoundEmitter:KillSound("charging")
	inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/electro_ball_explode")
end

local function AttachTo(inst, parent)
	inst.entity:SetParent(parent.entity)
	inst.Follower:FollowSymbol(parent.GUID, "light")
	inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/beamlp_a", "charging")
end

local function KeepTargetFn(inst)--, target)
	return false
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddNetwork()
	inst.entity:AddFollower()

	inst.entity:AddPhysics()
	inst.Physics:SetMass(1)
	inst.Physics:SetSphere(0.5)

	inst.AnimState:SetBuild("wagdrone_projectile")
	inst.AnimState:SetBank("wagdrone_projectile")
	inst.AnimState:PlayAnimation("projectile_loop", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetScale(0.65, 0.65)

	inst.Light:SetRadius(0.5)
	inst.Light:SetIntensity(0.8)
	inst.Light:SetFalloff(0.5)
	inst.Light:SetColour(255/255, 255/255, 236/255)
	inst.Light:Enable(false)

	inst.showbase = net_bool(inst.GUID, "wagdrone_projectile.showbase", "showbasedirty")

	inst:SetPrefabNameOverride("wagdrone_flying") --for death announce

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst:AddTag("notarget")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("showbasedirty", OnShowBase)

		return inst
	end

	inst:AddComponent("updatelooper")

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_FLYING_DAMAGE)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.ignorehitrange = true

	inst.AttachTo = AttachTo
	inst.Launch = Launch

	inst.persists = false

	return inst
end

return Prefab("wagdrone_projectile_fx", fn, assets)
