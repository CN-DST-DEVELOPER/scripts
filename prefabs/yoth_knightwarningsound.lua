local function CreateSoundFxAt(x, z)
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()

	inst.Transform:SetPosition(x, 0, z)
	inst.SoundEmitter:PlaySound("yoth_2026/fanfare/announce")

	inst:Remove()
end

-- PLAYER_CAMERA_SEE_DISTANCE is range knights spawn at, plus ten for padding.
local RANGE = PLAYER_CAMERA_SEE_DISTANCE + 20
local RANGE_SQ = RANGE * RANGE
local function PlayWarningSound(inst)
	local player = ThePlayer
	if player ~= nil then
		local x, y, z = inst.Transform:GetWorldPosition()
		local px, py, pz = player.Transform:GetWorldPosition()
		local dx, dz = x - px, z - pz
		local dist = dx * dx + dz * dz
		if dist <= RANGE_SQ then
			dist = math.sqrt(dist)
			if dist > 15 then
				dist = 15 / dist
				x = px + dx * dist
				z = pz + dz * dist
			end
			CreateSoundFxAt(x, z)
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst.entity:SetCanSleep(false)

	inst:AddTag("FX")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		--Delay one frame so that we are positioned properly before starting the effect
		--or in case we are about to be removed
		inst:DoTaskInTime(0, PlayWarningSound)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false
	inst:DoTaskInTime(1, inst.Remove)

	return inst
end

return Prefab("yothknightwarningsound", fn)