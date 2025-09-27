local assets =
{
	Asset("ANIM", "anim/abyss_pillar_minion.zip"),
	Asset("ANIM", "anim/abyss_pillar_minion_broken_build.zip"),
}

local function MakeBroken(inst)
	inst.broken = true
	inst.AnimState:PlayAnimation("broken")
	inst.AnimState:SetBuild("abyss_pillar_minion_broken_build")
end

local function IsActivated(inst)
	return inst.sg ~= nil
end

local function PreActivate(inst)
	if inst.sg == nil then
		inst.AnimState:PlayAnimation("turn_on_pre")
		inst.SoundEmitter:PlaySound("rifts6/sequitor/jump")
	end
end

local function Activate(inst)
	if inst.sg == nil then
		inst.Physics:SetActive(true)
		inst.Transform:SetEightFaced()
		inst:SetStateGraph("SGabysspillar_minion")
		if not inst:IsAsleep() then
			inst.sg:GoToState("activate")
		end
	end
end

local function Deactivate(inst)
	if inst.sg then
		inst:ClearStateGraph()
		inst:RemoveTag("ignorewalkableplatformdrowning")
		inst.Physics:SetActive(false)
		inst.Transform:SetTwoFaced()
		inst.Transform:SetRotation(0)
		if not inst:IsAsleep() then
			inst.AnimState:PlayAnimation("turn_off_pst")
			inst.AnimState:PushAnimation("idle_off", false)
			inst.SoundEmitter:PlaySound("rifts6/sequitor/jump_land")
		else
			inst.AnimState:PlayAnimation("idle_off")
		end
		inst.SoundEmitter:KillSound("loop")
	elseif not inst.AnimState:IsCurrentAnimation("idle_off") then
		inst.AnimState:PlayAnimation("idle_off")
	end
end

local function Flip(inst)
	if not inst:IsActivated() then
		inst.Transform:SetRotation(180)
	end
end

local function GetBigPillar(inst)
	local bigpillar = inst.components.entitytracker:GetEntity("leftpillar")
	if bigpillar then
		return bigpillar, true --left
	end
	bigpillar = inst.components.entitytracker:GetEntity("rightpillar")
	if bigpillar then
		return bigpillar, false --right
	end
end

local function SetOnBigPillar(inst, bigpillar, leftminion)
	inst:Deactivate()
	inst.Physics:Teleport(bigpillar.Transform:GetWorldPosition())
	inst.Follower:FollowSymbol(bigpillar.GUID, "follow_cap", 0, 0, 0, true, true)
	if not leftminion then
		inst:Flip()
	end
	inst.components.entitytracker:ForgetEntity("leftpillar")
	inst.components.entitytracker:ForgetEntity("rightpillar")
	inst.components.entitytracker:TrackEntity(leftminion and "leftpillar" or "rightpillar", bigpillar)
end

local function RemoveFromBigPillar(inst)
	inst.Follower:StopFollowing()
end

local function OnSave(inst, data)
	data.broken = inst.broken or nil
	data.activated = inst:IsActivated() or nil
end

local function OnLoad(inst, data)--, ents)
	if data and data.broken then
		inst:MakeBroken()
	end
end

local function OnLoadPostPass(inst, ents, data)
	--Cancel any in progress attempts; return all tracked minions back to their off pillar.
	local bigpillar, leftminion = inst:GetBigPillar()
	if bigpillar then
		inst:SetOnBigPillar(bigpillar, leftminion)
	elseif data and data.activated then
		--Shouldn't reach here for properly tracked minions
		inst:Activate()
	end
end

local function DisplayNameFn(inst)
	return inst.AnimState:IsCurrentAnimation("idle_off") and STRINGS.NAMES.VAULT_STATUE or nil
end

local function GetStatus(inst, viewer)
	return inst:IsActivated() and "ACTIVATED" or nil
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(0.5)
	MakeGhostPhysics(inst, 1, inst.physicsradiusoverride)
	inst.Physics:SetActive(false)

	inst:AddTag("monster")
	inst:AddTag("soulless")
	inst:AddTag("mech")
	inst:AddTag("notarget")
	inst:AddTag("NOBLOCK")
	inst:AddTag("electricdamageimmune")

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("abyss_pillar_minion")
	inst.AnimState:SetBuild("abyss_pillar_minion")
	inst.AnimState:PlayAnimation("idle_off")

	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("locomotor")
	inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED
	inst.components.locomotor:SetAllowPlatformHopping(true)

	inst:AddComponent("embarker")
	inst.components.embarker.embark_speed = TUNING.WILSON_RUN_SPEED * 2

	inst:AddComponent("entitytracker")

	inst.MakeBroken = MakeBroken
	inst.IsActivated = IsActivated
	inst.PreActivate = PreActivate
	inst.Activate = Activate
	inst.Deactivate = Deactivate
	inst.Flip = Flip
	inst.GetBigPillar = GetBigPillar
	inst.SetOnBigPillar = SetOnBigPillar
	inst.RemoveFromBigPillar = RemoveFromBigPillar
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

return Prefab("abysspillar_minion", fn, assets)
