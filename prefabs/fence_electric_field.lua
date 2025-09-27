local assets =
{
	Asset("ANIM", "anim/fence_electric_field_fx.zip"),
}

local function CreateSegFx(seg, rot, scale, pos_y)
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBuild("fence_electric_field_fx")
	fx.AnimState:SetBank("fence_electric_field_fx")
	fx.AnimState:PlayAnimation("beam", true)
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetScale(scale, 1)
	fx.AnimState:SetMultColour(1, 1, 1, 0.4 + math.random() * 0.1)
	fx.AnimState:UsePointFiltering(true)

	fx.persists = false

	fx.Transform:SetRotation(rot)

	fx.entity:SetParent(seg.entity)
	fx.Follower:FollowSymbol(seg.GUID, "marker", 0, pos_y, 0)

	fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)

	fx.persists = false

	return fx
end

local function CreateSegAt(inst, x, z, rot, scale, isend)
	local seg = CreateEntity()

	seg:AddTag("FX")
	seg:AddTag("NOCLICK")
	--[[Non-networked entity]]
	seg.entity:SetCanSleep(false)
	seg.persists = false

	seg.entity:AddTransform()
	seg.entity:AddAnimState()

	seg.entity:SetParent(inst.entity)
	seg.Transform:SetPosition(x, 0, z)

	seg.AnimState:SetBuild("fence_electric_field_fx")
	seg.AnimState:SetBank("fence_electric_field_fx")
	seg.AnimState:PlayAnimation("follow_marker_fence_2")

	seg.persists = false

	--fx will be ground oriented, but raised by following the billboard "follow_marker_fence_2" symbol
	seg.fx = CreateSegFx(seg, rot, scale, 0)
	seg.fx2 = CreateSegFx(seg, rot, scale, 65)

	return seg
end

local function ClearSegs(inst)
	if inst.segs then
		for i, v in ipairs(inst.segs) do
			v:Remove()
		end
		inst.segs = nil
	end

	if not TheWorld.ismastersim then
		return
	end

	inst.SoundEmitter:KillSound("linked_lp")

	inst.Physics:SetCollides(true) --We're unloaded, activate our physics!
	inst.Physics:SetCollisionCallback(nil)
end
--local OnEntitySleep = ClearSegs --this is set in prefab constructor

local MAX_LEN = 15
local SEG_LEN = 2.15 -- Bolt is 324 pixels long in file, 324 / 150 = 2.15~
local TARGET_SPACING = 4
local TARGET_RANGE = 0.1 --distance from beam

local SHOCK_COOLDOWNS = {
	--SMALLCREATURE = 0.5,
	DEFAULT = 1,
	CHARACTER = 2,
	EPIC = 3,
}

local function ObjectNonPermanence(inst)
	inst:RemoveEventCallback("onremove", ObjectNonPermanence, inst.panic_electric_field)
    inst.panic_electric_field = nil
end

local function ClearForgetTask(inst)
	if inst.forget_field_task then
		inst.forget_field_task:Cancel()
		inst.forget_field_task = nil
	end
end

local function GetShockCooldown(inst)
	return (inst:HasTag("character") and SHOCK_COOLDOWNS.CHARACTER
		or inst:HasTag("epic") and SHOCK_COOLDOWNS.EPIC
		or SHOCK_COOLDOWNS.DEFAULT)
		+
		(inst._electrocute_resist or 0)
end

--local GLOBAL_SHOCK_TARGETS = setmetatable({}, { __mode = 'k' })
local BrainCommon = require("brains/braincommon")

local function CanShockEnt(ent)
	return not IsEntityElectricImmune(ent) and CanEntityBeElectrocuted(ent)
		-- Because the above two don't check for nointerrupt, even though they probably should. FIXME
		and (ent.sg == nil or (not ent.sg:HasAnyStateTag("dead", "nointerrupt", "noelectrocute") or ent.sg:HasStateTag("canelectrocute")))
end

local function DoCollideShock(other, inst)
	local t = GetTime()
	if (inst.targets[other] or -math.huge) < t and
		other:IsValid() and not other:IsInLimbo()
	then
		if not IsEntityDead(other) and CanShockEnt(other) then
			ClearForgetTask(other)

			--TODO MORE WHEN WET?
			if BrainCommon.HasElectricFencePanicTriggerNode(other) and other.panic_electric_field ~= inst then
				other:PushEvent("shocked_by_new_field", inst)

            	other.panic_electric_field = inst
				other:ListenForEvent("onremove", ObjectNonPermanence, inst) --Just in case?
			end

			other:PushEventImmediate("electrocute", {duration=TUNING.ELECTROCUTE_SHORT_DURATION, noburn=true})
			other.forget_field_task = other:DoTaskInTime(TUNING.ELECTRIC_FIELD_MOB_PANICTIME, ObjectNonPermanence)
		end

		inst.targets[other] = t + GetShockCooldown(other)
	end

	other.do_collide_shock_task = nil
end

-- NOTE(Omar): A little trick!
-- Collision callbacks still run even if Physics:SetCollides is false
-- And physics are gonna be a bit more reliable than our old detection
local function OnCollisionCallback(inst, other,
	world_position_on_a_x, world_position_on_a_y, world_position_on_a_z,
	world_position_on_b_x, world_position_on_b_y, world_position_on_b_z,
	world_normal_on_b_x, world_normal_on_b_y, world_normal_on_b_z,
	lifetime_in_frames)

	if not (other ~= nil and other:IsValid() and inst:IsValid()) then
        return
    end

	if not other.do_collide_shock_task then
		if other.components.locomotor and CanShockEnt(other) and (inst.targets[other] or -math.huge) < GetTime() then
			other.components.locomotor:Stop()
		end

		other.do_collide_shock_task = other:DoTaskInTime(0, DoCollideShock, inst) -- Next frame for physics safety
	end
end

local function AddPlane(triangles, x0, y0, z0, x1, y1, z1)
    table.insert(triangles, x0)
    table.insert(triangles, y0)
    table.insert(triangles, z0)

    table.insert(triangles, x0)
    table.insert(triangles, y1)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, y0)
    table.insert(triangles, z1)

    table.insert(triangles, x1)
    table.insert(triangles, y0)
    table.insert(triangles, z1)

    table.insert(triangles, x0)
    table.insert(triangles, y1)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, y1)
    table.insert(triangles, z1)
end

local HALFPI = PI/2
local function BuildFenceMesh(halflen, rot)
    local triangles = {}

	local cos_rot, cos_rot_op = math.cos(rot), math.cos(rot + HALFPI)
	local sin_rot, sin_rot_op = math.sin(rot), math.sin(rot + HALFPI)

	local x0, z0 = halflen * cos_rot, halflen * -sin_rot
	local x1, z1 = -halflen * cos_rot, -halflen * -sin_rot

	local x2, z2 = x0, z0
	local x3, z3 = x1, z1

	x0, z0 = x0 + cos_rot_op * TARGET_RANGE, z0 - sin_rot_op * TARGET_RANGE
	x1, z1 = x1 + cos_rot_op * TARGET_RANGE, z1 - sin_rot_op * TARGET_RANGE

	x2, z2 = x2 + cos_rot_op * -TARGET_RANGE, z2 - sin_rot_op * -TARGET_RANGE
	x3, z3 = x3 + cos_rot_op * -TARGET_RANGE, z3 - sin_rot_op * -TARGET_RANGE

	AddPlane(triangles, x0, 0, z0, x1, 5, z1)
	AddPlane(triangles, x2, 0, z2, x3, 5, z3)

    return triangles
end

local function RefreshSegs(inst)
	local len = inst.len:value() / 255 * MAX_LEN
	local rot = inst.rot:value() / 255 * 360
	local theta = rot * DEGREES
	local costheta = math.cos(theta)
	local sintheta = math.sin(theta)

	if inst.segs == nil and not TheNet:IsDedicated() then
		inst.segs = {}
		local num = math.max(1, math.floor(len / SEG_LEN + 0.5))
		local scale = len / (num * SEG_LEN)
		local spacing = len / num
		local dx = spacing * costheta
		local dz = -spacing * sintheta
		local dstart = (1 - num) / 2
		local x = dx * dstart
		local z = dz * dstart
		for i = 1, num do
			inst.segs[i] = CreateSegAt(inst, x, z, rot, scale, i == 1 or i == num)
			x = x + dx
			z = z + dz
		end
	end

	if not TheWorld.ismastersim then
		return
	end

	if not inst.SoundEmitter:PlayingSound("linked_lp") then
	    inst.SoundEmitter:PlaySound("dontstarve/common/together/electric_fence/linked_lp", "linked_lp")
    end

	inst.Physics:SetTriangleMesh(BuildFenceMesh(len * 0.5, rot * DEGREES))
	inst.Physics:SetCollides(false)
	inst.Physics:SetCollisionCallback(OnCollisionCallback)

	if inst.targetx == nil then
		inst.targetx = {}
		inst.targetz = {}
		local num = math.floor(len / TARGET_SPACING) + 1
		local dx = TARGET_SPACING * costheta
		local dz = -TARGET_SPACING * sintheta
		local dstart = (1 - num) / 2
		local x, y, z = inst.Transform:GetWorldPosition()
		local x = x + dx * dstart
		local z = z + dz * dstart
		for i = 1, num do
			inst.targetx[i] = x
			inst.targetz[i] = z
			x = x + dx
			z = z + dz
		end
	end
end

local function OnBeamDirty(inst)
	ClearSegs(inst)
	RefreshSegs(inst)
end

local function SetBeam(inst, len, rot)
	inst.len:set_local(0) --force dirty, because we might be calling this when moved
	inst.len:set(math.min(255, math.floor(len / MAX_LEN * 255 + 0.5)))
	inst.rot:set(math.floor((rot < 0 and rot + 360 or rot) / 360 * 255 + 0.5))

	if not inst:IsAsleep() then
		OnBeamDirty(inst)
	end
end

--TODO fix on boats
local function SetUpPhysics(inst)
	inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.GROUND) --EVERYTHING should interact with the fence, so set it as GROUND for now.
    inst.Physics:SetCollisionMask(
        --COLLISION.ITEMS,
		COLLISION.OBSTACLES,
        COLLISION.CHARACTERS,
		COLLISION.FLYERS,
        COLLISION.GIANTS
    )
	inst.Physics:SetCollides(false)
	inst.Physics:SetDontRemoveOnSleep(true)
end

local function ForcePhysicsUpdate(inst) --HACK! We need to force a physics update for entities that stay still
	inst.Physics:Stop()
end

local UPDATE_PERIOD = 1
local function OnEntityWake(inst)
	RefreshSegs(inst)
	if inst.update_physics_task then
		inst.update_physics_task:Cancel()
		inst.update_physics_task = nil
	end
	inst.update_physics_task = inst:DoPeriodicTask(UPDATE_PERIOD, ForcePhysicsUpdate)
end

local function OnEntitySleep(inst)
	if inst.update_physics_task then
		inst.update_physics_task:Cancel()
		inst.update_physics_task = nil
	end
	ClearSegs(inst)
end

local function CanMouseThrough() -- So that we don't block trying to select other entities.
	return true, false
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	SetUpPhysics(inst) -- Realistically this is only needed for server side, but there are almost NO C++ components that should be added on one side and not the other (except for ClientSleepable)
	--Otherwise we run into deserialization errors on the SoundEmitter component. I'm surprised there weren't more issues!
	--
	inst:AddTag("CLASSIFIED")
	inst:AddTag("notarget")
	inst:AddTag("no_collision_callback_for_other")

	inst.len = net_byte(inst.GUID, "fence_electric_field.len", "beamdirty")
	inst.rot = net_byte(inst.GUID, "fence_electric_field.rot", "beamdirty")

	inst.CanMouseThrough = CanMouseThrough

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("beamdirty", OnBeamDirty)

		return inst
	end

	inst.Physics:SetCollisionCallback(OnCollisionCallback)

	inst.targets = {}

	inst.SetBeam = SetBeam
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake

	inst.persists = false

	return inst
end

return Prefab("fence_electric_field", fn, assets)