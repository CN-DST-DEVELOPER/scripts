local easing = require("easing")

local assets =
{
	Asset("ANIM", "anim/gelblob.zip"),
}

local function ConnectorLerpTo(inst, x, z, scale)
	inst._x = (inst._x or x) * 0.92 + x * 0.08
	inst._z = (inst._z or z) * 0.92 + z * 0.08
	inst.Transform:SetPosition(inst._x, 0, inst._z)

	inst._scale = scale
	inst.AnimState:SetScale(1, scale)
end

local function OnUpdateConnectorKilled(inst)
	if inst._mainblob:IsValid() then
		inst._x1, inst._y1, inst._z1 = inst._mainblob.Transform:GetWorldPosition()
	end
	local dx = inst._x1 - inst._x
	local dz = inst._z1 - inst._z
	local k = inst.AnimState:GetCurrentAnimationTime() / inst._animlen
	k = k * k
	inst.Transform:SetPosition(inst._x + dx * k, inst._y, inst._z + dz * k)
	if inst._scale then
		inst.AnimState:SetScale(1, Lerp(inst._scale, 1, k))
	end
end

local function KillConnector(inst, mainblob)
	if inst:IsAsleep() or mainblob == nil then
		inst:Remove()
		return
	end

	inst._mainblob = mainblob
	inst._x1, inst._y1, inst._z1 = mainblob.Transform:GetWorldPosition()
	inst._x, inst._y, inst._z = inst.Transform:GetWorldPosition()
	inst.entity:SetParent(nil)
	inst.Transform:SetPosition(inst._x, inst._y, inst._z)

	if inst:IsAsleep() then
		inst:Remove()
		return
	end

	inst.AnimState:PlayAnimation("blob_attach_middle_pst")
	inst:ListenForEvent("animover", inst.Remove)
	inst.OnEntitySleep = inst.Remove

	inst._animlen = inst.AnimState:GetCurrentAnimationLength()

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(OnUpdateConnectorKilled)
end

local function Connector_OnRemoveEntity(inst)
	if inst.highlightparent then
		table.removearrayvalue(inst.highlightparent.highlightchildren, inst)
		inst.highlightparent = nil
	end
end

local function CreateConnectorBlob()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:SetCanSleep(TheWorld.ismastersim)

	inst.DynamicShadow:SetSize(2, 1.5)

	inst:AddTag("FX")

	inst.AnimState:SetBank("gelblob")
	inst.AnimState:SetBuild("gelblob")
	inst.AnimState:PlayAnimation("blob_attach_middle_pre")
	inst.AnimState:PushAnimation("blob_attach_middle_loop")

	inst.persists = false

	inst.LerpTo = ConnectorLerpTo
	inst.KillFX = KillConnector
	inst.OnRemoveEntity = Connector_OnRemoveEntity

	return inst
end

local function OnMainBlobLost(inst)
	if inst.highlightparent then
		table.removearrayvalue(inst.highlightparent.highlightchildren, inst)
		inst.highlightparent = nil
	end
	if inst.connector1 then
		inst.connector1:Remove()
		inst.connector1 = nil
	end
	if inst.connector2 then
		inst.connector2:Remove()
		inst.connector2 = nil
	end
	inst:RemoveComponent("updatelooper")
end

local function OnUpdate(inst)
	local blob = inst.mainblob:value()
	if blob == nil then
		--can happen if mainblob goes to sleep on clients; teleported away from it?
		OnMainBlobLost(inst)
		return
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local x1, y1, z1 = inst.mainblob:value().Transform:GetWorldPosition()
	local dx = x - x1
	local dz = z - z1
	local dsq = dx * dx + dz * dz
	if dsq ~= 0 and dsq < 9 then
		local dist = math.sqrt(dsq)
		local scale = easing.outQuad(math.clamp(dist, 1.5, 3) - 1.5, 1, -0.4, 1.5)

		local perplen = 0.3 / dist
		local perpdx = dz * perplen
		local perpdz = dx * perplen
		dx = dx * 0.67
		dz = dz * 0.67

		local xa, za = dx - perpdx, dz + perpdz
		local xb, zb = dx + perpdx, dz - perpdz

		if inst.connector1._x then
			local dista1 = math.sqrt(distsq(xa, za, inst.connector1._x, inst.connector1._z))
			local dista2 = math.sqrt(distsq(xa, za, inst.connector2._x, inst.connector2._z))
			local distb1 = math.sqrt(distsq(xb, zb, inst.connector1._x, inst.connector1._z))
			local distb2 = math.sqrt(distsq(xb, zb, inst.connector2._x, inst.connector2._z))
			if dista1 + distb2 < dista2 + distb1 then
				inst.connector1:LerpTo(xa, za, scale)
				inst.connector2:LerpTo(xb, zb, scale)
			else
				inst.connector1:LerpTo(xb, zb, scale)
				inst.connector2:LerpTo(xa, za, scale)
			end
		else
			inst.connector1:LerpTo(xa, za, scale)
			inst.connector2:LerpTo(xb, zb, scale)
		end
	end
end

local function OnMainBlobDirty(inst)
	if inst.killed:value() then
		return
	end
	local blob = inst.mainblob:value()
	if blob then
		if inst.highlightparent then
			table.removearrayvalue(inst.highlightparent.highlightchildren, inst)
			inst.highlightparent = nil
		end

		if inst.connector1 == nil then
			inst.connector1 = CreateConnectorBlob()
			inst.connector1.entity:SetParent(blob.entity)
		elseif inst.connector1.highlightparent then
			table.removearrayvalue(inst.connector1.highlightchildren, inst.connector1)
			inst.connector1.highlightparent = nil
		end

		if inst.connector2 == nil then
			inst.connector2 = CreateConnectorBlob()
			inst.connector2.entity:SetParent(blob.entity)
		elseif inst.connector2.highlightparent then
			table.removearrayvalue(inst.connector2.highlightchildren, inst.connector2)
			inst.connector2.highlightparent = nil
		end

		if blob.highlightchildren then
			inst.highlightparent = blob
			inst.connector1.highlightparent = blob
			inst.connector2.highlightparent = blob
			table.insert(blob.highlightchildren, inst)
			table.insert(blob.highlightchildren, inst.connector1)
			table.insert(blob.highlightchildren, inst.connector2)
		end

		if inst.components.updatelooper == nil then
			inst:AddComponent("updatelooper")
			inst.components.updatelooper:AddOnUpdateFn(OnUpdate)
		end
	else
		OnMainBlobLost(inst)
	end
end

local function OnKilledDirty(inst)
	if inst.killed:value() then
		if inst.connector1 then
			inst.connector1:KillFX(inst.mainblob:value())
			inst.connector1 = nil
		end
		if inst.connector2 then
			inst.connector2:KillFX(inst.mainblob:value())
			inst.connector2 = nil
		end
		inst:RemoveComponent("updatelooper")
	end
end

--V2C: debuff amount should not stack when stepping into multiple blobs
local ALLTARGETS = {}

local function RegisterTargetLocomotorDebuff(inst, target)
	local tbl = ALLTARGETS[target]
	if tbl then
		tbl[inst] = true
	else
		ALLTARGETS[target] = { [inst] = true }
		target.components.locomotor:SetExternalSpeedMultiplier(inst, "gelblob", TUNING.CAREFUL_SPEED_MOD)
	end
	inst._target = target
end

local function UnregisterTargetLocomotorDebuff(inst)
	local tbl = ALLTARGETS[inst._target]
	if tbl then
		tbl[inst] = nil
		if next(tbl) == nil then
			ALLTARGETS[inst._target] = nil
			if inst._target.components.locomotor and inst._target:IsValid() then
				inst._target.components.locomotor:RemoveExternalSpeedMultiplier(inst, "gelblob")
			end
		end
	end
	inst._target = nil
end

local function OnUpdateTargetUnevenGroundDebuff(inst, target)
	target:PushEvent("unevengrounddetected", { inst = inst, radius = 0.5, period = 0.1 })
end

local function RegisterTargetUnevenGroundDebuff(inst, target)
	if inst.unevengroundtask == nil then
		inst.unevengroundtask = inst:DoPeriodicTask(0.1, OnUpdateTargetUnevenGroundDebuff, 0, target)
	end
end

local function UnregisterTargetUnevenGroundDebuff(inst)
	if inst.unevengroundtask then
		inst.unevengroundtask:Cancel()
		inst.unevengroundtask = nil
	end
end

local function RefreshPlayerDebuff(inst, target)
	if target.components.rider and target.components.rider:IsRiding() or target:HasTag("wereplayer") then
		UnregisterTargetUnevenGroundDebuff(inst)
		RegisterTargetLocomotorDebuff(inst, target)
	else
		UnregisterTargetLocomotorDebuff(inst)
		RegisterTargetUnevenGroundDebuff(inst, target)
	end
end

local function SetupBlob(inst, mainblob, target)
	inst.entity:SetParent(target.entity)
	target:AddTag("gelblobbed")
	if target.isplayer then
		local function _refreshdebuff(target) RefreshPlayerDebuff(inst, target) end
		inst:ListenForEvent("mounted", _refreshdebuff, target)
		inst:ListenForEvent("dismounted", _refreshdebuff, target)
		inst:ListenForEvent("startwereplayer", _refreshdebuff, target)
		inst:ListenForEvent("stopwereplayer", _refreshdebuff, target)
		RefreshPlayerDebuff(inst, target)
	elseif target.components.locomotor then
		RegisterTargetLocomotorDebuff(inst, target)
	end

	inst.mainblob:set(mainblob)
	OnMainBlobDirty(inst)
end

local function KillFX(inst)
	if inst:IsAsleep() then
		inst:Remove()
		return
	end

	inst.killed:set(true)
	OnKilledDirty(inst)

	local x, y, z = inst.Transform:GetWorldPosition()
	local parent = inst.entity:GetParent()
	if parent then
		parent:RemoveTag("gelblobbed")
		inst.entity:SetParent(nil)
	end
	inst.Transform:SetPosition(x, y, z)

	if inst:IsAsleep() then
		inst:Remove()
		return
	end

	inst.AnimState:PlayAnimation("splash")
	inst:ListenForEvent("animover", inst.Remove)
	inst.OnEntitySleep = inst.Remove
end

local function OnRemoveEntity_Client(inst)
	if inst.highlightparent then
		table.removearrayvalue(inst.highlightparent.highlightchildren, inst)
		inst.highlightparent = nil
	end
end

local function OnRemoveEntity_Server(inst)
	OnRemoveEntity_Client(inst)
	local parent = inst.entity:GetParent()
	if parent then
		parent:RemoveTag("gelblobbed")
	end
	if inst.connector1 then
		inst.connector1:Remove()
		inst.connector1 = nil
	end
	if inst.connector2 then
		inst.connector2:Remove()
		inst.connector2 = nil
	end
	UnregisterTargetLocomotorDebuff(inst)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst.DynamicShadow:SetSize(2, 1.5)

	inst:AddTag("FX")

	inst.AnimState:SetBank("gelblob")
	inst.AnimState:SetBuild("gelblob")
	inst.AnimState:PlayAnimation("blob_attach_end_pre")
	inst.AnimState:SetFinalOffset(2)

	inst.mainblob = net_entity(inst.GUID, "gelblob_attach_fx.mainblob", "mainblobdirty")
	inst.killed = net_bool(inst.GUID, "gelblob_attach_fx.killed", "killeddirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("mainblobdirty", OnMainBlobDirty)
		inst:ListenForEvent("killeddirty", OnKilledDirty)

		inst.OnRemoveEntity = OnRemoveEntity_Client

		return inst
	end

	inst.AnimState:PushAnimation("blob_attach_end_loop")

	inst.persists = false

	inst.SetupBlob = SetupBlob
	inst.KillFX = KillFX
	inst.OnRemoveEntity = OnRemoveEntity_Server

	return inst
end

return Prefab("gelblob_attach_fx", fn, assets)
