local assets =
{
	Asset("ANIM", "anim/vault_torch.zip"),
	Asset("ANIM", "anim/smoke_plants.zip"),
}

local assets_flame =
{
	Asset("ANIM", "anim/coldfire_fire.zip"),
}

local prefabs =
{
	"vault_torch_flame",
}

local prefabs_flame =
{
	"firefx_light",
}

local function DoTurnOn(inst)
	inst._task = nil
	if inst.fire == nil then
		inst.fire = SpawnPrefab("vault_torch_flame")
		inst:AddChild(inst.fire)
		--V2C: fire_marker was made for pigtorch_flame, now switched to coldfirefire so + 58.4
		inst.fire.entity:AddFollower():FollowSymbol(inst.GUID, "fire_marker", 0, 40 + 58.4, 0)
		inst.fire.persists = false
		inst.fire.components.firefx:SetLevel((inst:IsBroken() and 1) or (inst:IsStuck() and 3) or 2, true)
		inst.fire.components.firefx:AttachLightTo(inst)
	end
end

local function TurnOn(inst)
	if inst.AnimState:IsCurrentAnimation("idle_on") or inst.AnimState:IsCurrentAnimation("turn_on") then
		return
	elseif inst._task then
		inst._task:Cancel()
	end
	if inst:IsAsleep() or POPULATING then
		inst.AnimState:PlayAnimation("idle_on")
		DoTurnOn(inst)
	elseif inst._animdelay then
		inst._task = inst:DoTaskInTime(inst._animdelay, TurnOn)
	else
		inst.AnimState:PlayAnimation("turn_on")
		inst.AnimState:PushAnimation("idle_on", false)
		inst.SoundEmitter:PlaySound("rifts6/vault_torch/switch_on")
		inst._task = inst:DoTaskInTime(0.2, DoTurnOn)
	end
end

local function BrokenTurnOn(inst)
	if inst._task then
		inst._task:Cancel()
	end
	if inst:IsAsleep() or POPULATING then
		inst.AnimState:PlayAnimation("broken_idle")
		DoTurnOn(inst)
	elseif inst._animdelay then
		inst._task = inst:DoTaskInTime(inst._animdelay, BrokenTurnOn)
	else
		inst.AnimState:PlayAnimation("broken_hit")
		inst.AnimState:PushAnimation("broken_idle", false)
		inst.SoundEmitter:PlaySound("rifts6/vault_torch/switch_on")
		inst._task = inst:DoTaskInTime(0.2, DoTurnOn)
	end
end

local function DoTurnOff(inst)
	inst._task = nil
	if inst.fire then
		local animspeed = 1
		if not (inst.fire.components.firefx and inst.fire.components.firefx:Extinguish(true)) then
			inst.fire.AnimState:SetBuild("smoke_plants")
			inst.fire.AnimState:SetBankAndPlayAnimation("smoke_out", "smoke_single")
			inst.fire.AnimState:ClearBloomEffectHandle()
			local scale = (0.55 + math.random() * 0.3) * (inst:IsBroken() and 0.6 or 1)
			animspeed = 0.8 + math.random() * 0.5
			inst.fire.AnimState:SetScale(math.random() < 0.5 and scale or -scale, scale)
			inst.fire.AnimState:SetDeltaTimeMultiplier(animspeed)
			inst.fire:AddTag("NOCLICK")

			local light = inst.fire.components.firefx and inst.fire.components.firefx.light
			if light then
				light.Light:Enable(false)
			end
		end
		inst.fire:DoTaskInTime(inst.fire.AnimState:GetCurrentAnimationLength() / animspeed + FRAMES, inst.fire.Remove)
		inst.fire = nil
	end
end

local function TurnOff(inst)
	if inst.AnimState:IsCurrentAnimation("idle_off") or inst.AnimState:IsCurrentAnimation("turn_off") then
		return
	elseif inst._task then
		inst._task:Cancel()
	end
	if inst:IsAsleep() or POPULATING then
		inst.AnimState:PlayAnimation("idle_off")
		DoTurnOff(inst)
	elseif inst._animdelay then
		inst._task = inst:DoTaskInTime(inst._animdelay, TurnOff)
	else
		inst.AnimState:PlayAnimation("turn_off")
		inst.AnimState:PushAnimation("idle_off", false)
		inst.SoundEmitter:PlaySound("rifts6/vault_torch/switch_off")
		inst._task = inst:DoTaskInTime(0.2, DoTurnOff)
	end
end

local function BrokenTurnOff(inst)
	if inst._task then
		inst._task:Cancel()
	end
	if inst:IsAsleep() or POPULATING then
		inst.AnimState:PlayAnimation("broken_idle")
		DoTurnOff(inst)
	elseif inst._animdelay then
		inst._task = inst:DoTaskInTime(inst._animdelay, BrokenTurnOff)
	else
		inst.AnimState:PlayAnimation("broken_hit")
		inst.AnimState:PushAnimation("broken_idle", false)
		inst.SoundEmitter:PlaySound("rifts6/vault_torch/switch_off")
		inst._task = inst:DoTaskInTime(0.2, DoTurnOff)
	end
end

local function CheckStuckPlayerAction(inst, action)
	for i, v in ipairs(AllPlayers) do
		--don't check locomotor buffered action
		if v.bufferedaction and v.bufferedaction.action == action and v.bufferedaction.target == inst then
			v.bufferedaction:AddSuccessAction(function()
				v.components.talker:Say(GetActionFailString(v, "PICK", "STUCK"))
			end)
			return
		end
	end
end

local function StuckCantTurnOn(inst)
	if inst._task then
		inst._task:Cancel()
		inst._task = nil
	end
	if not inst:IsAsleep() then
		if inst._animdelay then
			inst._task = inst:DoTaskInTime(inst._animdelay, StuckCantTurnOn)
		else
			inst.AnimState:PlayAnimation("stuck_off")
			inst.AnimState:PushAnimation("stuck_idle_off", false)
			inst.SoundEmitter:PlaySound("rifts6/vault_torch/stuck")
			CheckStuckPlayerAction(inst, ACTIONS.TURNON)
		end
	end
	inst.components.machine:TurnOff()
end

local function StuckCantTurnOff(inst)
	if inst._task then
		inst._task:Cancel()
		inst._task = nil
	end
	if not inst:IsAsleep() then
		if inst._animdelay then
			inst._task = inst:DoTaskInTime(inst._animdelay, StuckCantTurnOff)
		else
			inst.AnimState:PlayAnimation("stuck_on")
			inst.AnimState:PushAnimation("stuck_idle_on", false)
			inst.SoundEmitter:PlaySound("rifts6/vault_torch/stuck")
			CheckStuckPlayerAction(inst, ACTIONS.TURNOFF)
		end
	end
	inst.components.machine:TurnOn()
end

local function MakeStuckOn(inst)
	if inst.fire then
		inst.fire.components.firefx:SetLevel(3, true)
	end
	inst.components.machine.enabled = true
	inst.components.machine.turnonfn = nil
	inst.components.machine.turnofffn = nil
	inst.components.machine.cooldowntime = 0.25
	if not inst.components.machine:IsOn() then
		inst.components.machine:TurnOn()
		inst.components.machine:StopCooldown()
	end
	inst.AnimState:PlayAnimation("stuck_idle_on")
	if inst._task then
		inst._task:Cancel()
	end
	DoTurnOn(inst)

	--For timing, use event instead of .turnofffn
	inst:RemoveEventCallback("machineturnedon", StuckCantTurnOn)
	inst:ListenForEvent("machineturnedoff", StuckCantTurnOff)
end

local function MakeStuckOff(inst)
	inst.components.machine.enabled = true
	inst.components.machine.turnonfn = nil
	inst.components.machine.turnofffn = nil
	inst.components.machine.cooldowntime = 0.25
	if inst.components.machine:IsOn() then
		inst.components.machine:TurnOff()
		inst.components.machine:StopCooldown()
	end
	inst.AnimState:PlayAnimation("stuck_idle_off")
	if inst._task then
		inst._task:Cancel()
	end
	DoTurnOff(inst)

	--For timing, use event instead of .turnofffn
	inst:RemoveEventCallback("machineturnedoff", StuckCantTurnOff)
	inst:ListenForEvent("machineturnedon", StuckCantTurnOn)
end

local function MakeBroken(inst)
	if inst.fire then
		inst.fire.components.firefx:SetLevel(1, true)
	end
	inst.components.machine.enabled = false
	inst.components.machine.turnonfn = BrokenTurnOn
	inst.components.machine.turnofffn = BrokenTurnOff
	inst.components.machine.cooldowntime = 0
	inst.AnimState:PlayAnimation("broken_idle")

	inst:RemoveEventCallback("machineturnedoff", StuckCantTurnOff)
	inst:RemoveEventCallback("machineturnedon", StuckCantTurnOn)
end

local function MakeNormal(inst)
	if inst.fire then
		inst.fire.components.firefx:SetLevel(2, true)
	end
	inst.components.machine.enabled = true
	inst.components.machine.turnonfn = TurnOn
	inst.components.machine.turnofffn = TurnOff
	inst.components.machine.cooldowntime = 0.5
	inst.AnimState:PlayAnimation(inst.components.machine:IsOn() and "idle_on" or "idle_off")

	inst:RemoveEventCallback("machineturnedoff", StuckCantTurnOff)
	inst:RemoveEventCallback("machineturnedon", StuckCantTurnOn)
end

local function IsStuck(inst)
	return inst.components.machine.turnonfn == nil
end

local function IsBroken(inst)
	return not inst.components.machine.enabled
end

local function ToggleOnOff(inst)
	inst._animdelay = 0.2
	if inst.components.machine:IsOn() then
		inst.components.machine:TurnOff()
	else
		inst.components.machine:TurnOn()
	end
	inst._animdelay = nil
end

local function GetStatus(inst, viewer)
	return inst:IsBroken() and "BROKEN" or nil
end

local function OnSave(inst, data)
	return
	{
		stuck = inst:IsStuck() or nil,
		broken = inst:IsBroken() or nil,
	}
end

local function OnLoad(inst, data)--, ents)
	if data then
		if data.stuck then
			if inst.components.machine:IsOn() then
				inst:MakeStuckOn()
			else
				inst:MakeStuckOff()
			end
		elseif data.broken then
			inst:MakeBroken()
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("vault_torch")
	inst.AnimState:SetBuild("vault_torch")
	inst.AnimState:PlayAnimation("idle_off")

	MakeObstaclePhysics(inst, 0.3)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.fire = nil

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("machine")
	inst.components.machine.turnonfn = TurnOn
	inst.components.machine.turnofffn = TurnOff
	inst.components.machine.cooldowntime = 0.5

	inst.MakeStuckOn = MakeStuckOn
	inst.MakeStuckOff = MakeStuckOff
	inst.MakeBroken = MakeBroken
	inst.MakeNormal = MakeNormal
	inst.IsStuck = IsStuck
	inst.IsBroken = IsBroken
	inst.ToggleOnOff = ToggleOnOff
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

--Match vault_chandelier colour
--Also use campfire sounds more mellow with x9 going on
local FLAME_LIGHT_COLOUR = { 180/255, 240/255, 255/255 }
local FLAME_LEVELS =
{
	{ anim = "level1", sound = "rifts6/vault_torch/coldfire_LP", radius = 2, intensity = 0.25, falloff = 0.5, colour = FLAME_LIGHT_COLOUR, soundintensity = 0.06 },
	{ anim = "level2", sound = "rifts6/vault_torch/coldfire_LP", radius = 3, intensity = 0.25, falloff = 0.5, colour = FLAME_LIGHT_COLOUR, soundintensity = 0.08 },
	{ anim = "level3", sound = "rifts6/vault_torch/coldfire_LP", radius = 4, intensity = 0.25, falloff = 0.5, colour = FLAME_LIGHT_COLOUR, soundintensity = 0.1 },
}
FLAME_LIGHT_COLOR = nil

local function flamefn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("coldfire_fire")
	inst.AnimState:SetBuild("coldfire_fire")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetRayTestOnBB(true)
	inst.AnimState:SetFinalOffset(3)

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("firefx")
	inst.components.firefx.levels = FLAME_LEVELS
	inst.components.firefx.usedayparamforsound = true

	return inst
end

return Prefab("vault_torch", fn, assets, prefabs),
	Prefab("vault_torch_flame", flamefn, assets_flame, prefabs_flame)
