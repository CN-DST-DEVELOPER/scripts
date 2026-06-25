local assets =
{
    Asset("ANIM", "anim/carnivalgame_golfball.zip"),
	Asset("ANIM", "anim/carnival_streamer.zip"),
}

--[[local function OnOccupied(inst)--, doer, club)
end

local function OnUnoccupied(inst)--, club)
end]]

local function ForceStop(inst)
	inst.AnimState:Pause()
	inst.Physics:Stop()
	inst:RemoveTag("NOCLICK")
end

local GOLFHOLE_TAGS = { "golfhole" }
local GOLFHOLE_RADIUS = 0.24
local GOLFHOLE_RSQ = GOLFHOLE_RADIUS * GOLFHOLE_RADIUS

local function UpdateAnimSpeed(inst, speed)
	local k = math.clamp(Remap(speed, 0, TUNING.GOLF_MAX_SWING_SPEED, 1, 0), 0, 1)
	k = 1 - k * k
	inst.AnimState:SetDeltaTimeMultiplier(k * 4)
end

local function OnExitHole(inst)
	inst._inhole = nil
	inst:Show()
	inst:RemoveEventCallback("animover", inst.Remove)
	inst:RemoveEventCallback("animover", inst.Hide)
	inst.AnimState:PlayAnimation("ball1_loop", true)
end

local function OnEnterHole(inst, hole)
	inst._inhole = true
	if hole.prefab == "carnivalgame_golf_hole" then
		inst.AnimState:Show("FX")
		inst.AnimState:PlayAnimation("ball_in")
		inst:ListenForEvent("animover", inst.Remove)
		inst.persists = false
		hole:PushEvent("ms_ongolfscored", inst)
	elseif hole.prefab == "carnivalgame_golfprop_wormhole" or hole.prefab == "carnivalgame_golfprop_wormhole_limited" then
		inst.AnimState:Hide("FX")
		inst.AnimState:PlayAnimation("ball_in")
		inst:ListenForEvent("animover", inst.Hide)
		hole:PushEvent("ms_golfballentered", inst)
	end
end

local function OnUpdateRolling(inst, dt)
	local x, y, z = inst.Transform:GetWorldPosition()
	local vx, vy, vz = inst.Physics:GetVelocity()
	if y + vy * dt * 1.5 >= 0.05 or vy > 0.1 then -- similar check to inventoryitem:OnUpdate
		inst.AnimState:Hide("ground")
		return
	end

	inst.AnimState:Show("ground")
	local speedsq = vx * vx + vz * vz
	local speed

	local hole = FindEntity(inst, GOLFHOLE_RADIUS, nil, GOLFHOLE_TAGS)
	if hole then
		local x1, y1, z1 = hole.Transform:GetWorldPosition()
		local dx = x1 - x
		local dz = z1 - z
		local dsq = dx * dx + dz * dz
		if dsq < TUNING.GOLFHOLE_SCORE_RANGE_SQ and speedsq < TUNING.GOLFHOLE_MAX_SCORE_SPEED_SQ then
			inst.Physics:Stop()
			inst.Transform:SetPosition(x1, y1, z1)
			inst.AnimState:SetDeltaTimeMultiplier(1)
			if inst.frictiondelay then
				inst.frictiondelay = nil
				inst.Physics:SetFriction(0.06)
			end
			inst._updating = false
			inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateRolling)
			OnEnterHole(inst, hole)
			return
		end

		local toholespd = Remap(dsq / GOLFHOLE_RSQ, 0, 1, TUNING.GOLFHOLE_MAX_ACCEL, TUNING.GOLFHOLE_MIN_ACCEL)
		if speedsq > toholespd * toholespd then
			speed = math.sqrt(speedsq)
			local k = (speed - toholespd) / speed
			vx, vz = k * vx, k * vz
		else
			vx, vz = 0, 0
		end

		local k = toholespd / math.sqrt(dsq)
		vx = vx + dx * k
		vz = vz + dz * k
		inst.Physics:SetVel(vx, vy, vz)
	elseif speedsq < 0.01 and inst.frictiondelay == nil then
		ForceStop(inst)
		inst._updating = false
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateRolling)
		if inst.components.golfpropitem then
			inst.components.golfpropitem:CheckTeleport()
		end
		return
	end

	if inst.frictiondelay then
		if inst.frictiondelay > 0 then
			inst.frictiondelay = inst.frictiondelay - dt
		else
			inst.frictiondelay = nil
			inst.Physics:SetFriction(0.06)
		end
	end

	inst.Transform:SetRotation(math.atan2(-vz, vx) * RADIANS)
	UpdateAnimSpeed(inst, speed or math.sqrt(speedsq))
end

local function OnHit(inst, doer, club, dir, speed)
	if inst._inhole or inst:IsInLimbo() then
		return --shouldn't happen!
	end
	-- Remember our current position as the spot to teleport to if out of bounds (and if actually hit by a club)
	if inst.components.golfpropitem and club then
		local x, y, z = inst.Transform:GetWorldPosition()
		inst.components.golfpropitem:SetTeleportXZ(x, z)
	end
	if doer and doer.components.golfballspinner then
		if inst.frictiondelay == nil then
			inst.Physics:SetFriction(0)
		end
		inst.frictiondelay = FRAMES
	end
	inst:AddTag("NOCLICK")
	if not inst._updating then
		inst._updating = true
		inst.AnimState:Resume()
		inst.Transform:SetRotation(dir)
		local vx, vy, vz = inst.Physics:GetVelocity()
		inst.Physics:SetSphere(0.2) --force wakeup physics in case of tiny velocity
		inst.Physics:SetVel(vx, vy, vz)
		UpdateAnimSpeed(inst, speed)
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateRolling)
	end
end

local function SpitOutAt(inst, x, y, z)
	if inst:IsInLimbo() then
		return --shouldn't happen!
	end
	OnExitHole(inst)

	inst:AddTag("NOCLICK")
	if not inst._updating then
		inst._updating = true
		inst.AnimState:Resume()
		inst.Physics:SetSphere(0.2) --force wakeup physics in case of tiny velocity
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateRolling)
	end

	local speed = 1 + math.random()
	local vspeed = 6 + math.random()
	local theta = math.random() * TWOPI
	inst.Physics:Teleport(x, y + 0.1, z)
	inst.Physics:SetVel(speed * math.cos(theta), vspeed, -speed * math.sin(theta))

	inst.Transform:SetRotation(theta * RADIANS)
	UpdateAnimSpeed(inst, speed)
	if not inst._updating then
		inst._updating = true
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateRolling)
	end
end

local GOLF_SHAPE_TAGS = { "golfshape" }

--not exactly screen pixels, just orientation:
-- X is left-right
-- +Z is down
local function ToScreenXZ(x, z, sintheta, costheta)
	return x * sintheta + z * costheta, x * costheta - z * sintheta
end

--Client & non-dedi server
local function PostUpdateSorter(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local heading = TheCamera.heading
	if inst._lastheading ~= heading then
		inst._lastheading = heading
		local theta = -heading * DEGREES
		inst._sintheta = math.sin(theta)
		inst._costheta = math.cos(theta)
	elseif inst._lastx == x and inst._lasty == y and inst._lastz == z then
		return
	end
	inst._lastx, inst._lasty, inst._lastz = x, y, z

	if TheWorld.ismastersim and not (ThePlayer and ThePlayer:GetDistanceSqToPoint(x, y, z) < 30 * 30) then
		return
	end

	local scrnx, scrnz = ToScreenXZ(x, z, inst._sintheta, inst._costheta)
	local x2, y2, z2, foffs, maxdepth
	--tile range 0.5, ball rad 0.2, shape halfwidth 0.2
	for _, v in ipairs(TheSim:FindEntities(x, y, z, 0.9, GOLF_SHAPE_TAGS)) do
		if v.golfsortfn then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if v.sortoffs then
				x1 = x1 + v.sortoffs.x
				y1 = y1 + v.sortoffs.y
				z1 = z1 + v.sortoffs.z
			end
			local scrnx1, scrnz1 = ToScreenXZ(x1, z1, inst._sintheta, inst._costheta)
			local sort = v:golfsortfn(scrnx, scrnz, scrnx1, scrnz1) or 0
			if sort > 0 then --in front
				if scrnz1 > (maxdepth or -math.huge) then
					maxdepth = scrnz1
					foffs = 1
					x2, y2, z2 = x1, y1, z1
				end
			elseif sort < 0 and foffs ~= 1 and scrnz1 < (maxdepth or math.huge) then
				--behind
				maxdepth = scrnz1
				foffs = -1
				x2, y2, z2 = x1, y1, z1
			end
		end
	end

	if foffs then
		inst.AnimState:SetSortWorldOffset(x2 - x, y2 - y, z2 - z)
		inst.AnimState:SetFinalOffset(foffs)
	else
		inst.AnimState:SetSortWorldOffset(0, 0, 0)
		inst.AnimState:SetFinalOffset(0)
	end
end

local function ClearRecentlyHit(inst, other)
	inst.recentlyhit[other] = nil
end

local function OnCollide(inst, other)
	if other and not inst.recentlyhit[other] and other:IsValid() and inst:IsValid() and inst._updating then
		inst.recentlyhit[other] = true
		inst:DoTaskInTime(0.2, ClearRecentlyHit, other)
		inst.SoundEmitter:PlaySound("summerevent/golf_minigame/ball/obstacle_hit")
	end
end

local function fn()
	local inst = CreateEntity()

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	inst:AddTag("can_offset_sort_pos")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeGolfBallPhysics(inst, 0.2)

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("carnivalgame_golfball")
	inst.AnimState:SetBuild("carnivalgame_golfball")
	inst.AnimState:AddOverrideBuild("carnival_streamer")
	inst.AnimState:PlayAnimation("ball1_loop", true)
	inst.AnimState:Pause()

	--golfable (from golfable component) added to pristine state for optimization
	inst:AddTag("golfable")

	inst:AddComponent("updatelooper")

	if not TheNet:IsDedicated() then
		inst.components.updatelooper:AddPostUpdateFn(PostUpdateSorter)
	end

	inst.entity:SetPristine()

	inst.scrapbook_anim = "ball1_idle"

	if not TheWorld.ismastersim then
		return inst
	end

	inst.recentlyhit = {}
	inst.Physics:SetCollisionCallback(OnCollide)

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("inspectable")

	inst:AddComponent("golfable")
	--inst.components.golfable:SetOnOccupiedFn(OnOccupied)
	--inst.components.golfable:SetOnUnoccupiedFn(OnUnoccupied)
	inst.components.golfable:SetOnHitFn(OnHit)

	inst.SpitOutAt = SpitOutAt
	MakeHauntable(inst)

	return inst
end

return Prefab("carnivalgame_golfball", fn, assets)
