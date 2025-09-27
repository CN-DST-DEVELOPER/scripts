local assets =
{
	Asset("ANIM", "anim/wagdrone_rolling.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagdrone_common.lua"),
}

local prefabs =
{
	"wagdrone_laserwire_fx",
	"wagdrone_rolling_collide_small_fx",
	"wagdrone_rolling_collide_med_fx",
	"wagdrone_parts",
	"gears",
	"transistor",
	"wagpunk_bits",
}

local brain = require("brains/wagdrone_rollingbrain")
local easing = require("easing")
local WagdroneCommon = require("prefabs/wagdrone_common")

local function OnUpdateFlicker(inst)
	inst.flickerdelay = not inst.flickerdelay
	if inst.flickerdelay then
		return
	end
	--V2C: hack alert: using SetHightlightColour to achieve something like OverrideAddColour
	local r, g, b = inst.AnimState:GetAddColour()
	local c = easing.inOutQuad(math.random(), 0, 0.1, 1)
	inst.AnimState:SetHighlightColour(math.min(1, r + c), math.min(1, g + c), math.min(1, b + c), 0)
end

local function OnFlickerDirty(inst)
	if inst.flicker:value() then
		if inst.components.updatelooper == nil then
			inst:AddComponent("updatelooper")
		end
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateFlicker)
	elseif inst.components.updatelooper then
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateFlicker)
		inst.AnimState:SetHighlightColour() --clear override add colour
	end
end

local function RegisterBeam(inst, other, fx)
	if not inst.flicker:value() then
		inst.flicker:set(true)
		if not TheNet:IsDedicated() then
			OnFlickerDirty(inst)
		end
		inst.AnimState:SetLightOverride(0.1)
		inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/beamlp_a", "beam_LP_a")
		inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/beamlp_b", "beam_LP_b")
	end
	inst.beams[other] = fx
end

local function UnregisterBeam(inst, other)
	inst.beams[other] = nil
	if next(inst.beams) == nil and inst.flicker:value() then
		inst.flicker:set(false)
		if not TheNet:IsDedicated() then
			OnFlickerDirty(inst)
		end
		inst.AnimState:SetLightOverride(0)
		inst.SoundEmitter:KillSound("beam_LP_a")
		inst.SoundEmitter:KillSound("beam_LP_b")
	end
end

local function ConnectBeams(inst)
	inst:DisconnectBeams()

	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, 15, { "wagdrone_rolling" })) do
		if v ~= inst and v.sg:HasStateTag("canconnect") then
			assert(v.beams[inst] == nil)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			local dsq = dx * dx + dz * dz
			if dsq >= 16 then
				local fx = SpawnPrefab("wagdrone_laserwire_fx")
				fx.Transform:SetPosition((x + x1) / 2, 0, (z + z1) / 2)
				fx:SetBeam(math.sqrt(dsq), math.atan2(-dz, dx) * RADIANS)
				RegisterBeam(inst, v, fx)
				RegisterBeam(v, inst, fx)
			end
		end
	end
end

local function DisconnectBeams(inst)
	for other, fx in pairs(inst.beams) do
		assert(other.beams[inst] == fx)
		fx:Remove()
		UnregisterBeam(inst, other)
		UnregisterBeam(other, inst)
	end
end

local function SetBrainEnabled(inst, enable)
	inst:SetBrain(enable and brain or nil)
end

local function OnEntitySleep(inst)
	if inst.sg:HasStateTag("moving") or inst.sg.currentstate.name == "run_stop" then
		inst.sg:GoToState("idle")
	end
end

local function OnSave(inst, data)
	data.on = not inst.sg.mem.turnoff and (inst.sg.mem.turnon or not inst.sg:HasStateTag("off")) or nil
	data.stationary = data.on and not inst.sg.mem.tomobile and (inst.sg.mem.tostationary or inst.sg:HasStateTag("stationary")) or nil
	data.isloot = inst.components.workable ~= nil or nil
	WagdroneCommon.FriendlySave(inst, data)
end

local function OnLoad(inst, data, ents)
	if data then
		if inst.components.health.currenthealth <= inst.components.health.minhealth then
			inst.sg:GoToState(data.stationary and "stationary_broken_idle" or "broken_idle")
		elseif data.stationary then
			inst.sg:GoToState("stationary_idle")
		elseif data.on then
			inst.sg:GoToState("idle")
		end
		if data.isloot then
			WagdroneCommon.ChangeToLoot(inst)
		end
	end
end

local function GetStatus(inst, viewer)
	return (WagdroneCommon.IsFriendly(inst) and "FRIENDLY")
		or (inst.components.workable and "DAMAGED")
		or (inst.sg:HasStateTag("off") and "INACTIVE")
		or nil
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst.DynamicShadow:SetSize(1.05, 0.7)

	--inst.Transform:SetFourFaced() --only use facing model during run states

	inst.AnimState:SetBuild("wagdrone_rolling")
	inst.AnimState:SetBank("wagdrone_rolling")
	inst.AnimState:PlayAnimation("off_idle")
	inst.AnimState:SetSymbolLightOverride("light_yellow_on", 0.5)
	inst.AnimState:SetSymbolBloom("light_yellow_on")
	inst.AnimState:Hide("LIGHT_ON")

	inst:SetPhysicsRadiusOverride(0.4)
	MakeCharacterPhysics(inst, 80, inst.physicsradiusoverride)
	inst.Physics:SetCollisionMask(COLLISION.WORLD)

	inst:AddTag("scarytoprey")
	inst:AddTag("mech")
	inst:AddTag("electricdamageimmune")
	inst:AddTag("soulless")
	inst:AddTag("lunar_aligned")
	inst:AddTag("wagdrone")
	inst:AddTag("wagdrone_rolling")

	inst.flicker = net_bool(inst.GUID, "wagdrone_rolling.flicker", "flickerdirty")

	WagdroneCommon.MakeFriendablePristine(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("flickerdirty", OnFlickerDirty)

		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("locomotor")
	inst.components.locomotor.runspeed = TUNING.WAGDRONE_ROLLING_RUNSPEED
	--V2C: -using directdrive to bypass pathfinding
	--     -hack speed mult to prevent run_start from moving right away (see stategraph)
	inst.components.locomotor.directdrive = true
	inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.WAGDRONE_ROLLING_HEALTH)
	inst.components.health:SetMinHealth(1)
	inst.components.health.canmurder = false
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_ROLLING_DAMAGE)
	inst.components.combat:SetRange(1)

	WagdroneCommon.MakeFriendable(inst)
	WagdroneCommon.MakeHackable(inst)
	WagdroneCommon.PreventTeleportFromArena(inst)

	inst.beams = {}
	inst.ConnectBeams = ConnectBeams
	inst.DisconnectBeams = DisconnectBeams
	inst.SetBrainEnabled = SetBrainEnabled
	inst.OnRemoveEntity = DisconnectBeams
	inst.OnEntitySleep = OnEntitySleep
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnPreLoad = WagdroneCommon.FriendlyPreLoad
	inst.OnLoadPostPass = WagdroneCommon.HackableLoadPostPass

	inst.MakeFriendly = WagdroneCommon.ChangeToFriendly

	inst:SetStateGraph("SGwagdrone_rolling")

	return inst
end

return Prefab("wagdrone_rolling", fn, assets, prefabs)
