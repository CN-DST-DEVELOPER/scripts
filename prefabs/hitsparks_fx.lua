local assets =
{
	Asset("ANIM", "anim/lavaarena_hit_sparks_fx.zip"),
}

local function PushColour(inst, r, g, b)
	if inst.target.components.colouradder == nil then
		inst.target:AddComponent("colouradder")
	end
	inst.target.components.colouradder:PushColour(inst, r, g, b, 0)
end

local function PopColour(inst)
	if inst.target:IsValid() then
		inst.target.components.colouradder:PopColour(inst)
	end
end

local function UpdateFlash(inst)
	if inst.target:IsValid() then
		if inst.flashstep < 4 then
			local value = (inst.flashstep > 2 and 4 - inst.flashstep or inst.flashstep) * .05
			PushColour(inst, value, value, value, 0)
			inst.flashstep = inst.flashstep + 1
			return
		else
			PopColour(inst)
		end
	end
	inst.OnRemoveEntity = nil
	inst.components.updatelooper:RemoveOnUpdateFn(UpdateFlash)
end

local function Setup(inst, attacker, target, projectile)
	local x, y, z = target.Transform:GetWorldPosition()
	local radius = target:GetPhysicsRadius(.5)
	local source = projectile or attacker
	if source ~= nil and source:IsValid() then
		local angle = (source.Transform:GetRotation() + 180) * DEGREES
		x = x + math.cos(angle) * radius
		z = z - math.sin(angle) * radius
	end
	inst.Transform:SetPosition(x, .5, z)

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(UpdateFlash)
	inst.target = target
	inst.flashstep = 1
	inst.OnRemoveEntity = PopColour
	UpdateFlash(inst)
end

local function PlaySparksAnim(proxy)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetFromProxy(proxy.GUID)

	inst.AnimState:SetBank("hits_sparks")
	inst.AnimState:SetBuild("lavaarena_hit_sparks_fx")
	inst.AnimState:PlayAnimation("hit_3")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetFinalOffset(1)
	inst.AnimState:SetScale(proxy.flip:value() and -.7 or .7, .7)

	inst:ListenForEvent("animover", inst.Remove)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		--Delay one frame so that we are positioned properly before starting the effect
		--or in case we are about to be removed
		inst:DoTaskInTime(0, PlaySparksAnim)
	end

	inst.flip = net_bool(inst.GUID, "hitsparks_fx.flip")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false
	inst:DoTaskInTime(1, inst.Remove)

	inst.flip:set(math.random() < .5)

	inst.Setup = Setup

	return inst
end

return Prefab("hitsparks_fx", fn, assets)
