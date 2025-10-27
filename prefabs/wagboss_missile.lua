local easing = require("easing")

local assets =
{
	Asset("ANIM", "anim/missile_fx.zip"),
}

local prefabs =
{
	"missile_explosion_fx",
	"wagboss_missile_target_fx",
	"ash",
}

local CIRCLING_PERIOD = 2

local function CreateMissileLoop()
	local looper = CreateEntity()

	--[[Non-networked entity]]
	--looper.entity:SetCanSleep(false)
	looper.persists = false

	looper.entity:AddTransform()
	looper.entity:AddAnimState()
	looper.entity:AddFollower()

	looper:AddTag("FX")
	looper:AddTag("NOCLICK")

	looper.AnimState:SetBank("missile_fx")
	looper.AnimState:SetBuild("missile_fx")
	looper.AnimState:PlayAnimation("missile_loop", true)
	looper.AnimState:SetSymbolBloom("fx_missile_white")
	looper.AnimState:SetSymbolLightOverride("fx_missile_white", 0.3)
	looper.AnimState:SetLightOverride(0.1)

	return looper
end

local function CreateRotator()
	local rotator = CreateEntity()

	--[[Non-networked entity]]
	--rotator.entity:SetCanSleep(false)
	rotator.persists = false

	rotator.entity:AddTransform()
	rotator.entity:AddAnimState()
	rotator.entity:AddDynamicShadow()

	rotator:AddTag("FX")
	rotator:AddTag("NOCLICK")

	rotator.Transform:SetSixFaced()

	rotator.AnimState:SetBank("missile_fx")
	rotator.AnimState:SetBuild("missile_fx")
	rotator.AnimState:PlayAnimation("missile_rotation")
	rotator.AnimState:Pause()

	rotator.isnew = true

	local looper = CreateMissileLoop()
	looper.entity:SetParent(rotator.entity)
	looper.Follower:FollowSymbol(rotator.GUID, "fx_missile_follow", 0, 0, 0, true)

	return rotator
end

--------------------------------------------------------------------------

local function RememberVisualLaunchPt(inst)
	local launcher = inst.launcher:value()
	if launcher and launcher.AnimState:IsCurrentAnimation("atk_missile") then
		local t = launcher.AnimState:GetCurrentAnimationTime()
		if t < 0.9 then
			local x, y, z, found = launcher.AnimState:GetSymbolPosition("missile_follow_"..tostring(inst.id:value()))
			if found then
				if inst.launchpt then
					inst.launchpt.x, inst.launchpt.y, inst.launchpt.z = x, y, z
				else
					inst.launchpt = Vector3(x, y, z) --visual start pt
				end
				inst.launch_t0 = GetTime() - t

				if inst.pt0 == nil then
					inst.pt0 = inst:GetPosition() --physical start pt
				end
			end
		else
			inst.launchpt = nil
			inst.launch_t0 = nil
			inst.pt0 = nil
		end
	end
end

local function UpdateLaunchOffset(inst)
	if inst.rotator then
		if inst.rotator.isnew then
			inst.rotator.isnew = nil
			RememberVisualLaunchPt(inst)
		end
		if inst.launchpt then
			local t = GetTime() - inst.launch_t0
			if t < 0.9 then
				local k = 1 - t / 0.9
				k = k * k
				local offsx = inst.launchpt.x - inst.pt0.x
				local offsy = inst.launchpt.y - inst.pt0.y
				local offsz = inst.launchpt.z - inst.pt0.z
				local theta = inst.Transform:GetRotation() * DEGREES
				local sintheta = math.sin(theta)
				local costheta = math.cos(theta)
				local x1 = costheta * offsx - sintheta * offsz
				local z1 = sintheta * offsx + costheta * offsz
				inst.rotator.Transform:SetPosition(x1 * k, offsy * k, z1 * k)
			else
				inst.rotator.Transform:SetPosition(0, 0, 0)
				inst.launchpt = nil
				inst.launch_t0 = nil
				inst.pt0 = nil
			end
		end
	elseif inst.launchpt == nil then
		RememberVisualLaunchPt(inst)
	end

	if inst.launchpt == nil then
		inst.components.updatelooper:RemovePostUpdateFn(UpdateLaunchOffset)
	end
end

local function UpdateShadow(inst)--, dt)
	local x, y, z = inst.rotator.Transform:GetWorldPosition()
	local k = math.clamp(y / 5, 0, 1)
	k = 1 - k * k
	inst.rotator.DynamicShadow:SetSize(1.35 * k, 0.9 * k)
end

local function UpdateAnimTilt(inst)
	inst.rotator.AnimState:SetFrame(inst.tilt:value())
end

local function UpdateCircling_Client(inst, dt)
	if dt > 0 then
		local t = inst.t + dt
		inst.t = t

		local pct = t / CIRCLING_PERIOD
		local tilt = math.floor(pct * 60 + 0.5)
		if tilt <= 60 then
			inst.tilt:set_local(tilt)
			UpdateAnimTilt(inst)
		end
	end
end

local function OnTiltDirty_Client(inst)
	UpdateAnimTilt(inst)
	if inst.circling:value() then
		if inst.t == nil then
			inst.components.updatelooper:AddOnUpdateFn(UpdateCircling_Client)
		end
		inst.t = inst.tilt:value() / 60 * CIRCLING_PERIOD
	elseif inst.t then
		inst.t = nil
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateCircling_Client)
	end
end

local function InitializeVisualMissile(inst)
	if inst.showtask then
		inst.showtask:Cancel()
		inst.showtask = nil
	end
	if inst.rotator == nil then
		inst.rotator = CreateRotator()
		inst.rotator.entity:SetParent(inst.entity)

		inst.components.updatelooper:AddOnUpdateFn(UpdateShadow)
		UpdateShadow(inst)

		if TheWorld.ismastersim then
			UpdateAnimTilt(inst)
		else
			inst:ListenForEvent("tiltdirty", OnTiltDirty_Client)
			OnTiltDirty_Client(inst)
		end
	end
end

local function OnLaunchDirty_Client(inst)
	if inst.pending then
		inst.pending = nil
		inst.components.updatelooper:AddPostUpdateFn(UpdateLaunchOffset)
	end

	if inst.shown:value() then
		InitializeVisualMissile(inst)
	elseif inst.showtask == nil then
		--Assume server wants missile hidden for 1 frame of animation.
		--Waiting on the next packet may be too late.
		inst.showtask = inst:DoTaskInTime(0, InitializeVisualMissile)
	end
end

local AOE_RANGE = 1.2

local function UpdateFlightPath(inst, dt)
	local pt = inst.targetpos
	if inst.target then
		if inst.target:IsValid() then
			pt.x, pt.y, pt.z = inst.target.Transform:GetWorldPosition()
		else
			inst.target = nil
		end
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local dx = pt.x - x
	local dz = pt.z - z
	local dsq = dx * dx + dz * dz
	local physrad

	if inst.target then
		physrad = inst.target:GetPhysicsRadius(0)
		if y < math.max(0.5, physrad) * 2.5 then
			local range = 0.5 + physrad
			if dsq < range * range then
				inst.grouptargets[inst.target] = true
				inst.target:PushEvent("wagboss_missile_target_detonated")
				inst:Detonate()
				return
			end
		end
	end
	if y < 0.5 and not inst.retargeting then
		if physrad then
			local range = AOE_RANGE + physrad
			if dsq < range * range then
				inst.grouptargets[inst.target] = true
				inst.target:PushEvent("wagboss_missile_target_detonated")
			end
		end
		inst:Detonate()
		return
	end

	local t = inst.t + dt
	inst.t = t

	if dsq ~= 0 and not inst.retargeting then
		local dir = inst.Transform:GetRotation()
		local dir1 = math.atan2(-dz, dx) * RADIANS
		local diff = ReduceAngle(dir1 - dir)
		local k = t < 4 and easing.inQuad(t, 0, 0.5, 4) or 0.5
		inst.Transform:SetRotation(dir + diff * k)
	end

	local g = -1

	local circling = not inst.retargeting and t < CIRCLING_PERIOD
	if circling then
		local pct = t / CIRCLING_PERIOD
		local tilt = math.floor(pct * 60 + 0.5)
		if tilt ~= inst.tilt:value() then
			inst.tilt:set_local(tilt)
			if inst.rotator then
				UpdateAnimTilt(inst)
			end
		end

		local amp = easing.outQuad(t, 4, -2, CIRCLING_PERIOD)
		local theta = pct * TWOPI
		local circ = TWOPI * amp
		inst.speed = circ / CIRCLING_PERIOD
		local vx = math.sin(theta) * inst.speed
		local vy = math.cos(theta) * inst.speed
		inst.Physics:SetMotorVel(vx, vy - g, 0)

		if inst.soundtracking and inst.soundtracking ~= 0.3 then
			inst.soundtracking = 0.3
			inst.SoundEmitter:SetParameter("tracking", "distance", 0.3)
		end
	elseif not inst.retargeting then
		local dy = pt.y - y + 1 --aim a little above target base (i.e. ground)
		if dsq ~= 0 or dy ~= 0 then
			local dist = math.sqrt(dsq)
			local pct = 0.5 - math.atan2(dist, math.abs(dy)) / TWOPI
			local tilt = math.floor(pct * 60 + 0.5)
			local diff = tilt - inst.tilt:value()
			while diff > 30 do
				diff = diff - 60
			end
			while diff < -30 do
				diff = diff + 60
			end
			if diff ~= 0 then
				tilt = inst.tilt:value() + (diff > 0 and 1 or -1)
				if tilt > 60 then
					tilt = tilt - 60
				elseif tilt < 0 then
					tilt = tilt + 60
				end
				inst.tilt:set(tilt)
				if inst.rotator then
					UpdateAnimTilt(inst)
				end
			end

			local theta = tilt / 60 * TWOPI
			inst.speed = t < 4 and easing.inQuad(t - 2, TWOPI, TWOPI * 2, 2) or TWOPI * 3
			local vx = math.sin(theta) * inst.speed
			local vy = math.cos(theta) * inst.speed
			inst.Physics:SetMotorVel(vx, vy - g, 0)
		end

		if inst.soundtracking then
			local dsq3d = dsq + dy * dy
			local distparam = dsq3d < 100 and 0.1 or 0.2
			if inst.soundtracking ~= distparam then
				inst.soundtracking = distparam
				inst.SoundEmitter:SetParameter("tracking", "distance", distparam)
			end
		end
	else
		local prd = CIRCLING_PERIOD / 2
		local pct = math.min(1, t / prd)
		if inst.reversed then
			pct = 1 - pct
		end
		local tilt = math.min(60, math.floor(pct * 60 + 0.5))
		if tilt ~= inst.tilt:value() then
			inst.tilt:set(tilt)
			if inst.rotator then
				UpdateAnimTilt(inst)
			end
		end

		local amp = 1
		local theta = pct * TWOPI
		local circ = TWOPI * amp
		inst.speed = (inst.speed or TWOPI) * 0.9 + TWOPI * 0.1
		local vx = math.sin(theta) * inst.speed
		local vy = math.cos(theta) * inst.speed
		inst.Physics:SetMotorVel(vx, vy - g, 0)

		if y > 5 and (pct >= 1 or pct <= 0) then
			inst.t = 0
			inst.retargeting = nil
			inst.reversed = nil
		end

		if inst.soundtracking and inst.soundtracking ~= 0.3 then
			inst.soundtracking = 0.3
			inst.SoundEmitter:SetParameter("tracking", "distance", 0.3)
		end
	end

	if inst.circling:value() ~= circling then
		inst.circling:set(circling)

		--force sync
		local tilt = inst.tilt:value()
		inst.tilt:set_local(tilt)
		inst.tilt:set(tilt)
	end

	if inst.target then
		inst.target:PushEvent("epicscare", { scarer = inst, duration = 1 })
	end
end

local function Launch(inst, id, launcher, targetorpos, dir, grouptargets)
	if not inst.pending then
		return
	end
	inst.pending = nil

	--shared table to keep track of what our group of missiles have already hit
	inst.grouptargets = grouptargets

	local x, y, z = launcher.Transform:GetWorldPosition()
	inst.Physics:Teleport(x, 7, z)
	inst.Transform:SetRotation(dir)

	inst.ring = SpawnPrefab("wagboss_missile_target_fx")
	inst._onremoveringtarget = function(target)
		inst.ring.entity:SetParent(nil)
		inst.ring.Transform:SetPosition(inst.targetpos:Get())
	end

	inst.ring.Transform:SetRotation((id % 3) * 120)

	local theta = dir * DEGREES
	inst.ring:StartTweenFromXZ(x + 3 * math.cos(theta), z - 3 * math.sin(theta))

	inst.t = 0
	if targetorpos:is_a(EntityScript) then
		inst.target = targetorpos
		inst.targetpos = targetorpos:GetPosition()
		inst.ring.entity:SetParent(targetorpos.entity)
		inst.ring:ListenForEvent("onremove", inst._onremoveringtarget, targetorpos)
		inst:ListenForEvent("wagboss_missile_target_detonated", inst._ontargetdetonated, targetorpos)
	else
		inst.target = nil
		inst.targetpos = targetorpos
		inst.ring.Transform:SetPosition(targetorpos.x, 0, targetorpos.z)
	end
	inst.components.updatelooper:AddOnUpdateFn(UpdateFlightPath)
	UpdateFlightPath(inst, 0)

	inst.id:set(id)
	inst.launcher:set(launcher)

	if not TheNet:IsDedicated() then
		inst.components.updatelooper:AddPostUpdateFn(UpdateLaunchOffset)
	end
end

local function Retarget(inst, target)
	if inst.pending or inst.noretarget or target == inst.target then
		return
	end

	if not (inst.retargeting or inst.circling:value()) then
		local x, y, z = inst.Transform:GetWorldPosition()
		if y < 3 then
			inst.t = (1 - inst.tilt:value() / 60) * (CIRCLING_PERIOD / 2)
			inst.reversed = true
		else
			inst.t = inst.tilt:value() / 60 * (CIRCLING_PERIOD / 2)
		end
		inst.retargeting = true
	end

	if inst.target then
		inst.ring:RemoveEventCallback("onremove", inst._onremoveringtarget, inst.target)
		inst:RemoveEventCallback("wagboss_missile_target_detonated", inst._ontargetdetonated, inst.target)
	end
	inst.ring:ListenForEvent("onremove", inst._onremoveringtarget, target)
	inst.ring.entity:SetParent(target.entity)
	inst.ring.Transform:SetPosition(0, 0, 0)
	inst.ring:StartTweenFromXZ(inst.targetpos.x, inst.targetpos.z)

	inst.target = target
	inst.targetpos.x, inst.targetpos.y, inst.targetpos.z = target.Transform:GetWorldPosition()
	inst:ListenForEvent("wagboss_missile_target_detonated", inst._ontargetdetonated, target)
end

local function CancelTargetLock(inst)
	if inst.target then
		inst:RemoveEventCallback("wagboss_missile_target_detonated", inst._ontargetdetonated, inst.target)
		if inst.ring then
			inst.ring:RemoveEventCallback("onremove", inst._onremoveringtarget, inst.target)
			inst._onremoveringtarget(inst.target)
		end
		inst.target = nil
	end
end

local function ShowMissile(inst)
	if not inst.shown:value() then
		inst.shown:set(true)

		inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/missile_tracking_LP", "tracking")
		inst.SoundEmitter:SetParameter("tracking", "distance", 0.3)
		inst.soundtracking = 0.3

		--Dedicated server does not need to spawn the local fx
		if not TheNet:IsDedicated() then
			InitializeVisualMissile(inst)
		end
	end
end

local function OnRemoveEntity(inst)
	if inst.ring then
		inst.ring:Remove()
	end
end

--------------------------------------------------------------------------

local AOE_WORK_ACTIONS =
{
	CHOP = true,
	HAMMER = true,
	MINE = true,
	DIG = true,
}
local AOE_TAGS = { "_combat", "_inventoryitem", "pickable", "NPC_workable", "fire", "heatstar" }
for k, v in pairs(AOE_WORK_ACTIONS) do
	table.insert(AOE_TAGS, k.."_workable")
end
local AOE_NOTAGS = { "FX", "DECOR", "INLIMBO", "flight", "invisible" }
local AOE_RANGE_PADDING = 3

local function TossLaunch(inst, launcher, basespeed, startheight)
	local x0, y0, z0 = launcher.Transform:GetWorldPosition()
	local x1, y1, z1 = inst.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local dsq = dx * dx + dz * dz
	local angle
	if dsq > 0 then
		local dist = math.sqrt(dsq)
		angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
	else
		angle = TWOPI * math.random()
	end
	local sina, cosa = math.sin(angle), math.cos(angle)
	local speed = basespeed + math.random()
	inst.Physics:Teleport(x1, startheight, z1)
	inst.Physics:SetVel(cosa * speed, speed * 5 + math.random() * 2, sina * speed)
end

local function Detonate(inst)
	local x, y, z = inst.Transform:GetWorldPosition()

	SpawnPrefab("missile_explosion_fx").Transform:SetPosition(x, math.max(0, y), z)

	local launcher = inst.launcher:value()
	local commander = launcher and launcher.components.commander or nil

	for i, v in ipairs(TheSim:FindEntities(x, 0, z, AOE_RANGE + AOE_RANGE_PADDING, nil, AOE_NOTAGS, AOE_TAGS)) do
		if v ~= inst and v ~= launcher and
			not (commander and commander:IsSoldier(v)) and
			v:IsValid() and not v:IsInLimbo()
		then
			local range = AOE_RANGE + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, 0, z) < range * range then
				local shouldtoss = true
				if v:HasTag("heatstar") then
					if v.components.timer and v.components.timer:TimerExists("extinguish") then
						v.components.timer:SetTimeLeft("extinguish", 0)
					end
					shouldtoss = false
				elseif v:HasTag("heatrock") then
					if v.components.fueled then
						local pct = v.components.fueled:GetPercent()
						local deltapct = 2 / TUNING.HEATROCK_NUMUSES
						if pct < deltapct * 1.1 then
							local x1, y1, z1 = v.Transform:GetWorldPosition()
							v:Remove()
							v = SpawnPrefab("ash")
							v.Transform:SetPosition(x1, y1, z1)
						else
							v.components.fueled:SetPercent(pct - deltapct)
						end
					elseif v.components.finiteuses then
						local pct = v.components.finiteuses:GetPercent()
						local deltapct = 2 / TUNING.HEATROCK_NUMUSES
						if pct < deltapct * 1.1 then
							local x1, y1, z1 = v.Transform:GetWorldPosition()
							v:Remove()
							v = SpawnPrefab("ash")
							v.Transform:SetPosition(x1, y1, z1)
						else
							v.components.finiteuses:SetPercent(pct - deltapct)
						end
					end
				elseif v.components.heater and v.components.perishable then
					if v.components.perishable:GetPercent() < 0.35 then
						local x1, y1, z1 = v.Transform:GetWorldPosition()
						v:Remove()
						v = SpawnPrefab("ash")
						v.Transform:SetPosition(x1, y1, z1)
					else
						v.components.perishable:ReducePercent(1 / 3)
					end
				else
					local isworkable = false
					if v.components.workable then
						local work_action = v.components.workable:GetWorkAction()
						--V2C: nil action for NPC_workable (e.g. campfires)
						isworkable =
							(	work_action == nil and v:HasTag("NPC_workable")	) or
							(	v.components.workable:CanBeWorked() and
								work_action and
								AOE_WORK_ACTIONS[work_action.id] and
								not (	work_action == ACTIONS.DIG and
										(	v.components.spawner or
											v.components.childspawner
										)
									)
							)
					end
					if isworkable then
						v.components.workable:Destroy(inst)
						if v:IsValid() and v:HasTag("stump") then
							v:Remove()
						end
					elseif v.components.pickable and v.components.pickable:CanBePicked() and not v:HasTag("intense") then
						v.components.pickable:Pick(inst)
					elseif v.components.combat and inst.components.combat:CanTarget(v) then
						inst.components.combat:DoAttack(v)
						shouldtoss = false
					end

					if v.components.burnable and v:IsValid() then
						v.components.burnable:Extinguish()
					end
				end

				if shouldtoss and
					v.components.inventoryitem and
					v.components.locomotor == nil and
					v:IsValid()
				then
					if v.components.mine then
						v.components.mine:Deactivate()
					end
					if not v.components.inventoryitem.nobounce then
						TossLaunch(v, inst, 1.2, 0.1)
					end
				end
			end
		end
	end

	inst:Remove()
end

local function CancelNoRetarget(inst)
	inst.noretarget = nil
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.entity:AddPhysics()
	inst.Physics:SetMass(1)
	inst.Physics:SetSphere(0.5)

	inst:AddTag("CLASSIFIED")
	inst:AddTag("pseudoprojectile")

	inst.tilt = net_smallbyte(inst.GUID, "wagboss_missile.tilt", "tiltdirty")
	inst.circling = net_bool(inst.GUID, "wagboss_missile.circling", "tiltdirty")
	inst.shown = net_bool(inst.GUID, "wagboss_missile.shown", "launchdirty")
	inst.id = net_tinybyte(inst.GUID, "wagboss_missile.id", "launchdirty")
	inst.launcher = net_entity(inst.GUID, "wagboss_missile.launcher", "launchdirty")

	inst.circling:set(true)
	inst.pending = true
	inst:AddComponent("updatelooper")
    
    inst.scrapbook_inspectonseen = true

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("launchdirty", OnLaunchDirty_Client)

		return inst
	end

    inst.scrapbook_bank = "missile_fx"
    inst.scrapbook_build = "missile_fx"
    inst.scrapbook_anim = "missile_loop"
    
	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_MISSILE_DAMAGE)
	inst.components.combat.ignorehitrange = true

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_MISSILE_PLANAR_DAMAGE)

	inst._ontargetdetonated = function(target)
		--Prevent switching targets for a couple seconds if another missile
		--hit successfully the same target.  Often, the first missile would
		--invalidate the target entity, causing other missiles to retarget.
		--Lets not do that if the first hit was successful.
		if inst.noretarget == nil then
			inst.noretarget = inst:DoTaskInTime(2, CancelNoRetarget)
		end
	end

	inst.Launch = Launch
	inst.Retarget = Retarget
	inst.CancelTargetLock = CancelTargetLock
	inst.ShowMissile = ShowMissile
	inst.Detonate = Detonate
	inst.OnEntitySleep = inst.Remove
	inst.OnRemoveEntity = OnRemoveEntity

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local RING_MIN_SCALE = 0.85
local RING_MAX_SCALE = 1.35
local RING_MIN_ALPHA = 0.2
local RING_MAX_ALPHA = 0.5
local PING_TIME = 0.5
local PING_MAX_SCALE = 1.1
local TARGET_TWEEN_TIME = 0.5

local function Ping_OnWallUpdate(ping, dt)
	ping.t = ping.t + dt * TheSim:GetTimeScale()
	if ping.t < PING_TIME then
		local s = easing.outQuad(ping.t, RING_MIN_SCALE, PING_MAX_SCALE - RING_MIN_SCALE, PING_TIME)
		local a = easing.outQuad(ping.t, RING_MAX_ALPHA, -RING_MAX_ALPHA, PING_TIME)
		ping.AnimState:SetScale(s, s)
		ping.AnimState:SetMultColour(1, 1, 1, a)
	else
		ping:Remove()
	end
end

local function Ring_StartPing(ping, dt)
	ping.t = 0
	ping:AddComponent("updatelooper")
	ping.components.updatelooper:AddOnWallUpdateFn(Ping_OnWallUpdate)
	Ping_OnWallUpdate(ping, dt)
end

local function CreateTargetRing()
	local ring = CreateEntity()

	--[[Non-networked entity]]
	--ring.entity:SetCanSleep(false)
	ring.persists = false

	ring.entity:AddTransform()
	ring.entity:AddAnimState()

	ring:AddTag("FX")
	ring:AddTag("NOCLICK")

	ring.AnimState:SetBank("missile_fx")
	ring.AnimState:SetBuild("missile_fx")
	ring.AnimState:PlayAnimation("target_pre")
	ring.AnimState:PushAnimation("target_loop")
	ring.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
	ring.AnimState:SetLayer(LAYER_BACKGROUND)
	ring.AnimState:SetSortOrder(3)
	ring.AnimState:SetScale(RING_MIN_SCALE, RING_MIN_SCALE)
	ring.AnimState:SetMultColour(1, 1, 1, RING_MAX_ALPHA)

	ring.StartPing = Ring_StartPing

	return ring
end

local function Target_OnRemoveEntity(inst)
	if not inst.ring:IsAsleep() then
		local ping = CreateTargetRing()
		ping.Transform:SetPosition(inst.Transform:GetWorldPosition())
		ping.Transform:SetRotation(inst.Transform:GetRotation())
		if inst.ring.AnimState:IsCurrentAnimation("target_loop") then
			ping.AnimState:PlayAnimation("target_loop", true)
		end
		ping.AnimState:SetTime(inst.ring.AnimState:GetCurrentAnimationTime())
		ping:StartPing(0)
		ping.OnEntitySleep = ping.Remove
	end
	inst.ring:Remove()
end

local function Target_OnWallUpdate(inst, dt)
	if inst.ring == nil then
		inst.ring = CreateTargetRing()
		inst.ring.Transform:SetRotation(inst.Transform:GetRotation())
		inst.OnRemoveEntity = Target_OnRemoveEntity
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local a = RING_MAX_ALPHA
	local s = RING_MIN_SCALE
	if inst.t then
		inst.t = inst.t + dt * TheSim:GetTimeScale()
		if inst.t < TARGET_TWEEN_TIME then
			local x0 = inst.x0:value()
			local z0 = inst.z0:value()
			local arc = inst.arc:value() - 1 --[0, 2] -> [-1, 1]
			local dx = x - x0
			local dz = z - z0
			x = easing.inOutQuad(inst.t, x0, dx, TARGET_TWEEN_TIME)
			z = easing.inOutQuad(inst.t, z0, dz, TARGET_TWEEN_TIME)
			if arc ~= 0 and dx ~= 0 and dz ~= 0 then
				local dist = math.sqrt(dx * dx + dz * dz)
				local amp = math.clamp(0.5 * dist, 2, 4) * math.sin(inst.t / TARGET_TWEEN_TIME * PI) / dist * arc
				x = x + dz * amp
				z = z - dx * amp
			end
			s = easing.inQuad(inst.t, RING_MAX_SCALE, s - RING_MAX_SCALE, TARGET_TWEEN_TIME)
			a = easing.inQuad(inst.t, RING_MIN_ALPHA, a - RING_MIN_ALPHA, TARGET_TWEEN_TIME)
		else
			inst.t = nil
			inst.blinkt = 0
			a = 1

			if inst.ring then
				local ping = CreateTargetRing()
				ping.entity:SetParent(inst.ring.entity)
				if inst.ring.AnimState:IsCurrentAnimation("target_loop") then
					ping.AnimState:PlayAnimation("target_loop", true)
				end
				ping.AnimState:SetTime(inst.ring.AnimState:GetCurrentAnimationTime())
				ping:StartPing(dt)
			end
		end
	elseif inst.blinkt then
		inst.blinkt = inst.blinkt + dt * TheSim:GetTimeScale()
		local fr = math.floor(inst.blinkt / FRAMES)
		if fr < 3 then
			a = 1
		elseif fr < 6 then
			a = RING_MIN_ALPHA
		else
			a = 1
			inst.flasht = 0
			inst.blinkt = nil
		end
	elseif inst.flasht then
		inst.flasht = inst.flasht + dt * TheSim:GetTimeScale()
		local len = 0.2
		if inst.flasht < len then
			a = easing.inQuad(inst.flasht, 1, a - 1, len)
		else
			inst.flasht = nil
		end
	end

	inst.ring.Transform:SetPosition(x, 0, z)
	inst.ring.AnimState:SetScale(s, s)
	inst.ring.AnimState:SetMultColour(1, 1, 1, a)
end

local function Target_OnTweenDirty(inst)
	inst.t = 0
	inst.blinkt = nil
	inst.flasht = nil
end

local ARCID = 0 --ranges from [0, 2], for cycling arc directions when tweening

local function Target_StartTweenFromXZ(inst, x, z)
	if inst.x0:value() == x and inst.z0:value() == z then
		inst.x0:set_local(x) --force at least one dirty
	end
	inst.x0:set(x)
	inst.z0:set(z)

	ARCID = (ARCID + 1) % 3
	inst.arc:set(ARCID)

	Target_OnTweenDirty(inst)
end

local function targetfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("CLASSIFIED")

	inst.x0 = net_float(inst.GUID, "wagboss_missile_target_fx.x0", "tweendirty")
	inst.z0 = net_float(inst.GUID, "wagboss_missile_target_fx.z0", "tweendirty")
	inst.arc = net_tinybyte(inst.GUID, "wagboss_missile_target_fx.arc")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddOnWallUpdateFn(Target_OnWallUpdate)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("tweendirty", Target_OnTweenDirty)

		return inst
	end

	inst.StartTweenFromXZ = Target_StartTweenFromXZ

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("wagboss_missile", fn, assets, prefabs),
	Prefab("wagboss_missile_target_fx", targetfn, assets)
