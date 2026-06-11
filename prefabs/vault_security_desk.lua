local assets =
{
	Asset("ANIM", "anim/archive_security_desk.zip"),
}

local prefabs =
{
	"archive_security_pulse",
}

local function DoTrySpawn(inst)
	inst.components.childspawner:SpawnChild()
end

local function EnableSpawning(inst, enable)
	if enable then
		if inst.task == nil then
			inst.task = inst:DoPeriodicTask(0.2, DoTrySpawn, 0.2 * math.random())
		end
	elseif inst.task then
		inst.task:Cancel()
		inst.task = nil
	end
end

local function OnOccupied(inst)
	if POPULATING then
		inst.AnimState:PlayAnimation("idle", true)
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	elseif not (inst.AnimState:IsCurrentAnimation("appear") or inst.AnimState:IsCurrentAnimation("idle")) then
		inst.AnimState:PlayAnimation("appear")
		inst.AnimState:PushAnimation("idle")
		inst.SoundEmitter:PlaySound("grotto/common/archive_security_desk/appear")
	end
	inst.Light:Enable(true)
	if not inst:IsAsleep() then
		if not inst.SoundEmitter:PlayingSound("loop") then
			inst.SoundEmitter:PlaySound("grotto/common/archive_security_desk/contained_LP", "loop")
		end
		EnableSpawning(inst, true)
	end
end

local function OnVacate(inst)
	if POPULATING then
		inst.AnimState:PlayAnimation("idle_leave")
	elseif not (inst.AnimState:IsCurrentAnimation("idle_leave") or inst.AnimState:IsCurrentAnimation("leave")) then
		inst.AnimState:PlayAnimation("leave")
		inst.AnimState:PushAnimation("idle_leave", false)
		inst.SoundEmitter:PlaySound("grotto/common/archive_security_desk/leave")
	end
	inst.Light:Enable(false)
	inst.SoundEmitter:KillSound("loop")
	EnableSpawning(inst, false)
end

local function CanSpawn(inst)
	if inst.AnimState:IsCurrentAnimation("idle") then
		local x, y, z = inst.Transform:GetWorldPosition()
		for i, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and
				v.entity:IsVisible() and
				v:GetDistanceSqToPoint(x, y, z) < 36 and
				--lets just skip vault room check and assume it passes since the range is so short
				v.components.inventory and
				v.components.leader
			then
				local item = v.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
				if item and item.prefab == "vault_compass"
					and #v.components.leader:GetFollowersByTag("power_point") < TUNING.MAX_SECURITY_PULSE_FOLLOWING then
					return true
				end
			end
		end
	end
	return false
end

local function OverrideSpawnLocation(inst)
	return Vector3(0, 0, 0)
end

local function OnEntityWake(inst)
	if inst.components.childspawner.childreninside > 0 then
		if not inst.SoundEmitter:PlayingSound("loop") then
			inst.SoundEmitter:PlaySound("grotto/common/archive_security_desk/contained_LP", "loop")
		end
		EnableSpawning(inst, true)
	end	
end

local function OnEntitySleep(inst)
	inst.SoundEmitter:KillSound("loop")
	EnableSpawning(inst, false)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddNetwork()

	inst.Light:SetFalloff(0.7)
	inst.Light:SetIntensity(0.5)
	inst.Light:SetRadius(0.5)
	inst.Light:SetColour(237/255, 237/255, 209/255)

	MakeObstaclePhysics(inst, 0.66)

	inst.AnimState:SetBuild("archive_security_desk")
	inst.AnimState:SetBank("archive_security_desk")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetSymbolLightOverride("fx_beam", 1)
	inst.AnimState:SetSymbolLightOverride("fx_archive_circles", 1)
	inst.AnimState:SetSymbolLightOverride("fx_archive_point_loop", 1)

	inst:AddTag("structure")
	inst:AddTag("statue")
	inst:AddTag("security_desk")

	inst:SetPrefabNameOverride("archive_security_desk")

	inst.scrapbook_proxy = "archive_security_desk"

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("childspawner")
	inst.components.childspawner.childname = "archive_security_pulse"
	inst.components.childspawner:SetRegenPeriod(TUNING.ARCHIVE_SECURITY.REGEN_TIME)
	inst.components.childspawner:SetSpawnPeriod(TUNING.ARCHIVE_SECURITY.RELEASE_TIME)
	inst.components.childspawner:SetMaxChildren(1)
	inst.components.childspawner:StartSpawning()
	inst.components.childspawner:SetOccupiedFn(OnOccupied)
	inst.components.childspawner:SetVacateFn(OnVacate)
	inst.components.childspawner.canspawnfn = CanSpawn
	inst.components.childspawner.overridespawnlocation = OverrideSpawnLocation

	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep

	return inst
end

return Prefab("vault_security_desk", fn, assets, prefabs)
