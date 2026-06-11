local easing = require("easing")

local assets =
{
	Asset("ANIM", "anim/wx78_drone_scout.zip"),
	Asset("ANIM", "anim/wx78_map_marker.zip"),
}

local prefabs =
{
	"wx78_drone_scout_globalicon",
	"wx78_drone_scout_revealableicon",
}

--------------------------------------------------------------------------

local function CreateDecal(skin_build)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("wx78_drone_scout")
	if skin_build ~= 0 then
		inst.AnimState:SetSkin(skin_build, "wx78_drone_scout")
	else
		inst.AnimState:SetBuild("wx78_drone_scout")
	end
	inst.AnimState:PlayAnimation("scan_decal", true)
	inst.AnimState:SetLightOverride(0.15)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetScale(4, 4)

	return inst
end

local function Beam_PostUpdate(inst)
	local x, _, z = inst.Transform:GetWorldPosition()
	inst.decal.Transform:SetPosition(x, 0, z)
end

local function Beam_OnRemoveEntity(inst)
	inst.decal:Remove()
end

local function CreateBeam(skin_build)
	local inst = CreateEntity()

	inst:AddTag("DECOR")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("wx78_drone_scout")
	if skin_build ~= 0 then
		inst.AnimState:SetSkin(skin_build, "wx78_drone_scout")
	else
		inst.AnimState:SetBuild("wx78_drone_scout")
	end
	inst.AnimState:PlayAnimation("scan_projection", true)
	inst.AnimState:SetFinalOffset(-1)
	inst.AnimState:SetLightOverride(0.15)

	inst.decal = CreateDecal(skin_build)

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddPostUpdateFn(Beam_PostUpdate)

	inst.OnRemoveEntity = Beam_OnRemoveEntity

	return inst
end

local function OnScanningDirty(inst)
	if inst.scanning:value() then
		if inst.beam == nil then
			inst.beam = CreateBeam(inst.build:value())
			inst.beam.entity:SetParent(inst.entity)
		end
	elseif inst.beam then
		inst.beam:Remove()
		inst.beam = nil
	end
end

local function SetScanning(inst, scanning)
	inst.scanning:set(scanning)
	if not TheNet:IsDedicated() then
		OnScanningDirty(inst)
	end
end

--------------------------------------------------------------------------

local function CalcDeliveryTime(inst, dest, doer)
	local x, _, z = inst.Transform:GetWorldPosition()
	local dist = math.sqrt(math2d.DistSq(x, z, dest.x, dest.z))
	--[[local a = TUNING.SKILLS.WX78.SCOUTDRONE_SPEED
	local accel_dist = 0.5 * a * 1 * 1
	local accel_and_decel_dist = 2 * accel_dist]]
	local accel_and_decel_dist = TUNING.SKILLS.WX78.SCOUTDRONE_SPEED
	return dist <= accel_and_decel_dist and 2 or 2 + (dist - accel_and_decel_dist) / TUNING.SKILLS.WX78.SCOUTDRONE_SPEED
end

local function OnStartDelivery(inst, dest, doer)
	local _
	inst._x, _, inst._z = inst.Transform:GetWorldPosition()
	if dest.x ~= inst._x or dest.z ~= inst._z then
		inst.Transform:SetRotation(math.atan2(inst._z - dest.z, dest.x - inst._x) * RADIANS)
		--inst.sg:GoToState("run_start", inst.sg.statemem.t)
		SetScanning(inst, true)
	end
	return true
end

local function _calc_k(t, len, dx, dz)
	local k
	if len <= 2 then
		k = easing.inOutQuad(t, 0, 1, len)
	else
		local dist = math.sqrt(dx * dx + dz * dz)
		local accel_and_decel_dist = TUNING.SKILLS.WX78.SCOUTDRONE_SPEED
		local accelpart = accel_and_decel_dist / 2 / dist
		if t <= 1 then
			--1s to accel to max speed
			k = easing.inQuad(t, 0, accelpart, 1)
		elseif t < len - 1 then
			--max speed
			k = easing.linear(t - 1, accelpart, 1 - 2 * accelpart, len - 2)
		else
			--1s to decel to stop
			k = easing.outQuad(t - len + 1, 1 - accelpart, accelpart, 1)
		end
	end
	return k
end

local function OnDeliveryProgress(inst, t, len, origin, dest)
	local dx = dest.x - origin.x
	local dz = dest.z - origin.z
	local k = _calc_k(t, len, dx, dz)
	local k1 = math.min(1, _calc_k(t + FRAMES, len, dx, dz))

	local x, y, z = inst.Transform:GetWorldPosition()
	x = origin.x + k * dx
	z = origin.z + k * dz
	inst.Transform:SetPosition(x, y, z)

	--if not inst:IsAsleep() then
		local vx, vy, vz = inst.Physics:GetMotorVel()
		if k1 > k then
			--assert(FRAMES == 1 / 30)
			local speed = (k1 - k) * math.sqrt(dx * dx + dz * dz) * 30
			inst.Physics:SetMotorVel(speed, vy, 0)
		else
			inst.Physics:SetMotorVel(0, vy, 0)
		end
	--end

	--[[if t + 0.8 > len and inst.sg:HasStateTag("moving") then
		inst.sg:GoToState("run_stop")
	end]]

    local isscanning = inst.scanning:value()
    if IsFlyingPermittedFromPoint(x, y, z) then
        if not isscanning then
            SetScanning(inst, true)
            inst:Show()
			if not (inst.SoundEmitter:PlayingSound("idle") or inst:IsAsleep()) then
                inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/idle", "idle")
            end
        end
        local owner = inst.components.globaltrackingicon.owner
        if owner and owner.player_classified then
            if owner._PostActivateHandshakeState_Server ~= POSTACTIVATEHANDSHAKE.READY then
                return -- Wait until the player client is ready and has received the world size info.
            end
            if math2d.DistSq(x, z, inst._x, inst._z) >= 16 then
                inst._x, inst._z = x, z
                owner.player_classified.MapExplorer:RevealArea(x, 0, z)
				inst.components.maprevealer:RestartPrivateRevealCooldown()
            end
        end
    else
        if isscanning then
            SetScanning(inst, false)
            inst:Hide()
            inst.SoundEmitter:KillSound("idle")
        end
    end
end

local function OnStopDelivery(inst, dest)
	inst._x, inst._z = nil, nil
	--if not inst:IsAsleep() then
		local _, vy, _ = inst.Physics:GetMotorVel()
		inst.Physics:SetMotorVel(0, vy, 0)
	--end
	--[[if inst.sg:HasStateTag("moving") then
		inst.sg:GoToState("run_stop", inst.sg.statemem.t)
	end]]
	SetScanning(inst, false)
end

local function OnBuilt(inst, data)
	local x, y, z = inst.Transform:GetWorldPosition()
	inst.Physics:Teleport(x, 1.5, z)
	inst.sg:GoToState("deploy")

	if data and data.builder and data.builder.components.wx78_dronescouttracker then
		data.builder.components.wx78_dronescouttracker:StartTracking(inst)
	end
end

local function OnTracked(inst, tracker)
	inst.persists = false
	inst.components.globaltrackingicon:StartTracking(tracker)
	inst.components.maprevealer:SetPrivateOwner(tracker)
	if inst.sg:HasStateTag("idle") then
		--respawned, not new built
		inst.components.spawnfader:FadeIn()
	end
end

local function OnUntracked(inst, tracker)
	inst.persists = true
	inst.components.globaltrackingicon:StartTracking(nil)
	inst.components.maprevealer:SetPrivateOwner(inst)
end

local function OnTrackerDespawn(inst, tracker)
	inst.components.spawnfader:FadeOut()
	inst:ListenForEvent("spawnfaderout", inst.Remove)
end

local function OnEntityWake(inst)
	if not inst.SoundEmitter:PlayingSound("idle") then
		inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/idle", "idle")
	end
end

local function OnEntitySleep(inst)
	inst.SoundEmitter:KillSound("idle")
end

local function OnBuildDirty(inst)
	if inst.beam then
		if inst.build:value() == 0 then
			inst.beam.AnimState:SetBuild("wx78_drone_scout")
			inst.beam.decal.AnimState:SetBuild("wx78_drone_scout")
		else
			inst.beam.AnimState:SetSkin(inst.build:value(), "wx78_drone_scout")
			inst.beam.decal.AnimState:SetSkin(inst.build:value(), "wx78_drone_scout")
		end
	end
end

local function OnDroneScoutSkinChanged(inst, skin_build)
	inst.build:set(skin_build or 0)
	OnBuildDirty(inst)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeFlyingCharacterPhysics(inst, 50, 0.4)
	inst.Physics:SetCollisionMask(COLLISION.GROUND)

	inst.AnimState:SetBank("wx78_drone_scout")
	inst.AnimState:SetBuild("wx78_drone_scout")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("flying")
	inst:AddTag("mapscout")
    inst:AddTag("staysthroughvirtualrooms")

	inst.scanning = net_bool(inst.GUID, "wx78_drone_scout.scanning", "scanningdirty")
	inst.build = net_hash(inst.GUID, "wx78_drone_scout.build", "builddirty")

	inst:AddComponent("spawnfader")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("scanningdirty", OnScanningDirty)
		inst:ListenForEvent("builddirty", OnBuildDirty)

		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("mapdeliverable")
	inst.components.mapdeliverable:SetDeliveryTimeFn(CalcDeliveryTime)
	inst.components.mapdeliverable:SetOnStartDeliveryFn(OnStartDelivery)
	inst.components.mapdeliverable:SetOnDeliveryProgressFn(OnDeliveryProgress)
	inst.components.mapdeliverable:SetOnStopDeliveryFn(OnStopDelivery)

	inst:AddComponent("globaltrackingicon")
	inst.components.globaltrackingicon:StartTracking(nil, "wx78_drone_scout")

	inst:AddComponent("maprevealer")
	inst.components.maprevealer:SetPrivateOwner(inst)

	inst:SetStateGraph("SGwx78_drone_scout")

	inst:ListenForEvent("onbuilt", OnBuilt)
	inst:ListenForEvent("ms_dronescout_tracked", OnTracked)
	inst:ListenForEvent("ms_dronescout_untracked", OnUntracked)
	inst:ListenForEvent("ms_dronescout_despawn", OnTrackerDespawn)

	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep
	inst.OnDroneScoutSkinChanged = OnDroneScoutSkinChanged

	return inst
end

local function GetDroneRange(inst, owner)
	local range = TUNING.SKILLS.WX78.SCOUTDRONE_RANGE

	if owner and owner.components.skilltreeupdater ~= nil then
		if owner.components.skilltreeupdater:IsActivated("wx78_extradronerange") then
			range = range + TUNING.SKILLS.WX78.SCOUTDRONE_RANGE_BONUS
		end

		if owner.components.skilltreeupdater:IsActivated("wx78_circuitry_betabuffs_1")
			and owner.GetModuleTypeCount then
			range = range + owner:GetModuleTypeCount("radar") * TUNING.SKILLS.WX78.RADAR_SCOUTDRONERANGE
		end
	end

	return range
end

local globalicon, revealableicon =
	MakeGlobalTrackingIcons("wx78_drone_scout", {
		icondata =
		{
			icon = "wx78_drone_scout",
			priority = 21,
			globalicon = "wx78_drone_scout_global",
			selectedicon = "wx78_drone_scout_selected",
			selectedpriority = MINIMAP_DECORATION_PRIORITY,
			fogrevealer = true,
		},
		global_common_postinit = function(inst)
			inst:SetPrefabNameOverride("wx78_drone_scout")
			inst.GetDroneRange = GetDroneRange
		end,
	})

return Prefab("wx78_drone_scout", fn, assets, prefabs),
	globalicon,
	revealableicon
