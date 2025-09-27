local assets =
{
	Asset("ANIM", "anim/wagboss_leg.zip"),
	Asset("ANIM", "anim/wagboss_robot.zip"),
}

local assets_fx =
{
	Asset("ANIM", "anim/wagboss_leg.zip"),
}

local prefabs =
{
	"wagboss_robot_leg_fx",
}

local function KillMe(inst)
	inst:AddTag("NOCLICK")
	inst:RemoveComponent("lunarsupernovablocker")
	inst.Physics:SetActive(false)
	inst.DynamicShadow:Enable(false)
	inst.persists = false
	if not inst:IsAsleep() then
		ErodeAway(inst)
		inst.OnEntitySleep = inst.Remove
	elseif POPULATING then
		inst:DoStaticTaskInTime(0, inst.Remove)
	else
		inst:Remove()
	end
end

local function OnStartBlocking(inst)
	inst.AnimState:PlayAnimation("jiggle", true)
	inst.AnimState:SetLightOverride(0.2)
end

local function OnStopBlocking(inst)
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetLightOverride(0)
end

local function MakeLandedAtXZ(inst, x, z)
	if x then
		inst.Physics:Teleport(x, 0, z)
		if ShouldEntitySink(inst, true) then
			SinkEntity(inst)
			return
		end
	end
	inst:RemoveComponent("updatelooper")
	inst.landedt = nil
	inst.landsfx = nil
	ChangeToObstaclePhysics(inst, 0.9)
	inst:AddTag("blocker")
	if not POPULATING then
		local boss = inst.components.entitytracker:GetEntity("boss")
		if boss then
			inst:ListenForEvent("onremove", inst._onremoveboss, boss)
		else
			KillMe(inst)
			return
		end
	end
	inst:AddComponent("lunarsupernovablocker")
	inst.components.lunarsupernovablocker:SetOnStartBlockingFn(OnStartBlocking)
	inst.components.lunarsupernovablocker:SetOnStopBlockingFn(OnStopBlocking)
end

local function DoLandingSfx(inst)
	if inst.landsfx then
		inst.landsfx = false --false so we won't play again
		inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/foot_land")
	end
end

local function UpdateLanding(inst, dt)
	local x, y, z = inst.Transform:GetWorldPosition()
	if y then
		local vx, vy, vz = inst.Physics:GetVelocity()
		vy = vy or 0
		if vy == 0 and (vx or 0) == 0 and (vz or 0) == 0 then
			inst.Physics:Stop()
			inst.Physics:Teleport(x, 0, z)
			DoLandingSfx(inst)
			MakeLandedAtXZ(inst, x, z)
		elseif (vy <= 0 and y + vy * dt * 1.5 < 0.01) and ShouldEntitySink(inst, true) then
			SinkEntity(inst)
		elseif y < 0.01 then
			DoLandingSfx(inst)
			inst.landedt = inst.landedt + dt
			if inst.landedt > FRAMES * 2 then
				inst.Physics:Stop()
				MakeLandedAtXZ(inst, x, z)
			end
		else
			inst.landedt = 0
			if inst.landsfx == nil then
				inst.landsfx = true
			end
		end
	else
		inst.Physics:Stop()
		MakeLandedAtXZ(inst, nil, nil)
	end
end

local function StartTrackingBoss(inst, boss)
	local oldboss = inst.components.entitytracker:GetEntity("boss")
	if boss ~= oldboss then
		if oldboss then
			inst:RemoveEventCallback("onremove", inst._onremoveboss, oldboss)
			inst.components.entitytracker:ForgetEntity("boss")
		end
		if boss and boss:IsValid() then
			inst.components.entitytracker:TrackEntity("boss", boss)
			if inst.landedt == nil then
				inst:ListenForEvent("onremove", inst._onremoveboss, boss)
			end
		end
	end
end

local function OnLoad(inst)--, data, ents)
	local x, y, z = inst.Transform:GetWorldPosition()
	if y < 0.01 then
		inst.Physics:Stop()
		MakeLandedAtXZ(inst, x, z)
	end
end

local function OnLoadPostPass(inst)--, ents, data)
	if inst.landedt == nil then
		local boss = inst.components.entitytracker:GetEntity("boss")
		if boss then
			inst:ListenForEvent("onremove", inst._onremoveboss, boss)
		else
			KillMe(inst)
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddPhysics()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst:AddTag("mech")

	inst.Transform:SetEightFaced()

	inst.DynamicShadow:SetSize(2.5, 0.7)

	inst.AnimState:SetBank("wagboss_leg")
	inst.AnimState:SetBuild("wagboss_robot")
	inst.AnimState:PlayAnimation("idle")

	inst:SetDeploySmartRadius(1.25)
	inst:SetPhysicsRadiusOverride(1.25)

	inst.Physics:SetMass(100)
	inst.Physics:SetFriction(0.2)
	inst.Physics:SetDamping(0)
	inst.Physics:SetRestitution(0.55)
	inst.Physics:SetCollisionGroup(COLLISION.ITEMS)
	inst.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.OBSTACLES,
		COLLISION.SMALLOBSTACLES
	)
	inst.Physics:SetSphere(0.9)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(UpdateLanding)
	inst.landedt = FRAMES * 2
	--inst.landsfx = nil

	inst:AddComponent("colouradder")

	inst:AddComponent("entitytracker")

	inst._onremoveboss = function(--[[boss]]) KillMe(inst) end

	inst.StartTrackingBoss = StartTrackingBoss
	inst.OnLoad = OnLoad
	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

local function CreateFx2()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("wagboss_lunar_blast")
	inst.AnimState:SetBuild("wagboss_lunar_blast")
	inst.AnimState:PlayAnimation("supernova_hit_large", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.3)
	inst.AnimState:SetFinalOffset(1)

	return inst
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("wagboss_leg")
	inst.AnimState:SetBuild("wagboss_leg")
	inst.AnimState:PlayAnimation("ground_spray", true)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.3)

	if not TheNet:IsDedicated() then
		local fx = CreateFx2()
		fx.entity:SetParent(inst.entity)
		fx.Transform:SetPosition(0.6, 0, 0)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("wagboss_robot_leg", fn, assets),
	Prefab("wagboss_robot_leg_fx", fxfn, assets_fx)
