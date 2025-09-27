require("prefabutil")

local assets =
{
	Asset("ANIM", "anim/rope_bridge.zip"),
	Asset("MINIMAP_IMAGE", "rope_bridge.png"),
}

local assets_kit =
{
	Asset("ANIM", "anim/rope_bridge.zip"),
}

local prefabs =
{
	"rope_bridge_fx",
	"gridplacer",
    "dock_damage",
}

--------------------------------------------------------------------------

local function Rope_KillFX(inst)
	if not inst.killed then
		inst.killed = true
		if inst:IsAsleep() then
			inst:Remove()
		else
			local x, y, z = inst.Transform:GetWorldPosition()
			inst.entity:SetParent(nil)
			inst.Transform:SetPosition(x, y, z)
			inst.AnimState:PlayAnimation("rope_break_"..tostring(inst.variation))
			inst:ListenForEvent("animover", inst.Remove)
			inst.OnEntitySleep = inst.Remove
		end
	end
end

local function CreateRope()
	local inst = CreateEntity()

	inst:AddTag("NOCLICK")
	inst:AddTag("decor")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("rope_bridge")
	inst.AnimState:SetBuild("rope_bridge")

	inst.KillFX = Rope_KillFX

	return inst
end

local ROPE1_OFFSET = Vector3(-0.1, 0, 2.6)
local ROPE2_OFFSET = Vector3(0.1, 0, -2.6)

--------------------------------------------------------------------------

local ROPE1_BITS = 48	--110000
local ROPE2_BITS = 12	--001100
local HIGH_BITS = 60	--111100
local LOW_BITS = 3		--000011

local ANIM_ID =
{
	["place"] = 0,
	["idle"] = 1,
	["shake"] = 2,
	["break"] = 3,
}

local function OnAnimData(inst)
	if TheNet:IsDedicated() then
		return
	elseif inst.rope1 == nil then
		inst.rope1 = CreateRope()
		inst.rope1.entity:SetParent(inst.entity)
		inst.rope1.Transform:SetPosition(ROPE1_OFFSET:Get())

		inst.rope2 = CreateRope()
		inst.rope2.entity:SetParent(inst.entity)
		inst.rope2.Transform:SetPosition(ROPE2_OFFSET:Get())
	elseif inst.rope1.killed then
		return
	end

	inst.rope1.variation = bit.rshift(inst.animdata:value(), 4) + 1
	inst.rope2.variation = bit.band(bit.rshift(inst.animdata:value(), 2), LOW_BITS) + 1

	local animid = bit.band(inst.animdata:value(), LOW_BITS)
	if animid == ANIM_ID["place"] then
		inst.rope1.AnimState:PlayAnimation("rope_place_"..tostring(inst.rope1.variation))
		inst.rope2.AnimState:PlayAnimation("rope_place_"..tostring(inst.rope2.variation))
		inst.rope1.AnimState:PushAnimation("rope_support_"..tostring(inst.rope1.variation), false)
		inst.rope2.AnimState:PushAnimation("rope_support_"..tostring(inst.rope2.variation), false)
	elseif animid == ANIM_ID["idle"] then
		inst.rope1.AnimState:PlayAnimation("rope_support_"..tostring(inst.rope1.variation))
		inst.rope2.AnimState:PlayAnimation("rope_support_"..tostring(inst.rope2.variation))
	elseif animid == ANIM_ID["shake"] then
		inst.rope1.AnimState:PlayAnimation("rope_shake_"..tostring(inst.rope1.variation), true)
		inst.rope2.AnimState:PlayAnimation("rope_shake_"..tostring(inst.rope2.variation), true)
	elseif animid == ANIM_ID["break"] then
		inst.rope1:KillFX()
		inst.rope2:KillFX()
	end
end

local function GetAnimDataForState(inst, state)
	return bit.bor(bit.band(inst.animdata:value(), HIGH_BITS), ANIM_ID[state])
end

local function DoPlaceSound(inst)
	inst.soundtask = nil
	inst.SoundEmitter:PlaySound("rifts4/rope_bridge/place")
end

local function CancelSounds(inst)
	if inst.soundtask then
		inst.soundtask:Cancel()
		inst.soundtask = nil
	end
	inst.SoundEmitter:KillSound("shake_lp")
end

local function SkipPre(inst)
	if not inst.killed then
		CancelSounds(inst)
		inst.AnimState:PlayAnimation("bridge_idle")
		inst.animdata:set(GetAnimDataForState(inst, "idle"))
		OnAnimData(inst)
	end
end

local function ShakeIt(inst)
	if not inst.killed then
		CancelSounds(inst)
		if not inst:IsAsleep() then
			inst.SoundEmitter:PlaySound("rifts4/rope_bridge/shake_lp", "shake_lp")
		end
		inst.AnimState:PlayAnimation("bridge_shake", true)
		inst.animdata:set(GetAnimDataForState(inst, "shake"))
		OnAnimData(inst)
	end
end

local function KillFX(inst)
	if not inst.killed then
		inst.killed = true
		if inst:IsAsleep() then
			inst:Remove()
		else
			CancelSounds(inst)
			inst.SoundEmitter:PlaySound("rifts4/rope_bridge/break")
			inst.AnimState:PlayAnimation("break_"..tostring(math.random(3)))
			inst.AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
			inst.AnimState:SetLayer(LAYER_BELOW_GROUND)
			inst.AnimState:SetSortOrder(0)
			inst.animdata:set(GetAnimDataForState(inst, "break"))
			OnAnimData(inst)
			inst.OnEntitySleep = inst.Remove
		end
	end
end

local function OnEntitySleep(inst)
	inst.SoundEmitter:KillSound("shake_lp")
end

local function OnEntityWake(inst)
	if inst.AnimState:IsCurrentAnimation("bridge_shake") then
		inst.SoundEmitter:PlaySound("rifts4/rope_bridge/shake_lp", "shake_lp")
	end
end

local function OnAnimOver(inst)
	if inst.killed then
		inst:Remove()
	elseif inst.AnimState:IsCurrentAnimation("bridge_place") then
		inst.AnimState:PlayAnimation("bridge_idle")
		inst.animdata:set_local(GetAnimDataForState(inst, "idle"))
	end
end

local function CreateMinimapIcon()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddMiniMapEntity()

	inst.MiniMapEntity:SetIcon("rope_bridge.png")

	inst:AddTag("CLASSIFIED")

	return inst
end

local function OnIconOffset(inst)
	if inst.iconoffset:value() <= 0 then
		if inst.icon then
			inst.icon:Remove()
			inst.icon = nil
		end
	else
		if inst.icon == nil then
			inst.icon = CreateMinimapIcon()
			inst.icon.entity:SetParent(inst.entity)
		end
		if inst.iconoffset:value() > 1 then
			inst.icon.Transform:SetPosition(2, 0, 0)
		end
	end
end

local function SetIconOffset(inst, offset)
	offset = offset and (offset == 0 and 1 or 2) or 0
	if offset ~= inst.iconoffset:value() then
		inst.iconoffset:set(offset)
		OnIconOffset(inst) --dedicated server needs this too, minimap icons need to be cached on servers
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.Transform:SetEightFaced()

	inst:AddTag("FX")

	inst.AnimState:SetBank("rope_bridge")
	inst.AnimState:SetBuild("rope_bridge")
	inst.AnimState:PlayAnimation("bridge_place")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(1)

	inst.iconoffset = net_tinybyte(inst.GUID, "rope_bridge_fx.iconffset", "iconoffsetdirty")
	inst.animdata = net_smallbyte(inst.GUID, "rope_bridge_fx.animdata", "animdatadirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("animdatadirty", OnAnimData)
		inst:ListenForEvent("iconoffsetdirty", OnIconOffset)

		return inst
	end

	inst.soundtask = inst:DoTaskInTime(0, DoPlaceSound)
	inst:ListenForEvent("animover", OnAnimOver)

	local rope1 = math.random(0, 3)
	local rope2 = math.random(0, 2)
	if rope2 >= rope1 then
		rope2 = rope2 + 1
	end
	inst.animdata:set(bit.bor(bit.lshift(rope1, 4), bit.lshift(rope2, 2)))
	OnAnimData(inst)

	inst.persists = false

	inst.SetIconOffset = SetIconOffset
	inst.SkipPre = SkipPre
	inst.ShakeIt = ShakeIt
	inst.KillFX = KillFX
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake

	return inst
end

--------------------------------------------------------------------------
--NOTE: these are used below by the placer as well
local function IsValidTileForRopeBridgeAtPoint_Wrapper(_map, x, y, z)
    return _map:IsValidTileForRopeBridgeAtPoint(x, y, z)
end
local function CanDeployRopeBridgeAtPoint_Wrapper(_map, x, y, z)
    return _map:CanDeployRopeBridgeAtPoint(x, y, z)
end
local RopeBridge_Options = {
    maxlength = TUNING.ROPEBRIDGE_LENGTH_TILES,
    isvalidtileforbridgeatpointfn = IsValidTileForRopeBridgeAtPoint_Wrapper,
    candeploybridgeatpointfn = CanDeployRopeBridgeAtPoint_Wrapper,
    deployskipfirstlandtile = true,
    requiredworldcomponent = "ropebridgemanager",
}
--

local function CLIENT_CanDeploy(inst, pt, mouseover, deployer, rotation)
	if TheWorld.net and TheWorld.net.components.quaker and TheWorld.net.components.quaker:IsQuaking() then
		return false
	end
    local valid, spots = Bridge_DeployCheck_Helper(deployer, pt, RopeBridge_Options)
	if not valid then
		return false
	end
	local stackable = inst.replica.stackable
	if stackable and stackable:StackSize() >= #spots then
		return true
	end
	local inventory = deployer and deployer.replica.inventory or nil
	if inventory and inventory:Has(inst.prefab, #spots) then
		return true
	end
	return false
end

local function OnDeploy(inst, pt, deployer)
    local valid, spots = Bridge_DeployCheck_Helper(deployer, pt, RopeBridge_Options)
    if valid then
        local ropebridgemanager = TheWorld.components.ropebridgemanager
        if ropebridgemanager then
            local stacksize = inst.components.stackable:StackSize()
            if stacksize >= #spots then
                inst.components.stackable:Get(#spots):Remove()
            elseif deployer and deployer.components.inventory and deployer.components.inventory:Has(inst.prefab, #spots) then
                inst:Remove()
                deployer.components.inventory:ConsumeByName(inst.prefab, #spots - stacksize)
            else
                return
            end

            --[[if deployer ~= nil and deployer.SoundEmitter ~= nil then
                deployer.SoundEmitter:PlaySoundWithParams("turnoftides/common/together/boat/damage", { intensity = 0.8 })
            end]]

            local spawndata = {
                base_time = 0.5,
                random_time = 0.0,
                direction = spots.direction,
            }
			local halfspots = #spots / 2
			local centeridx = math.ceil(halfspots)
			local centeroffset = centeridx ~= halfspots and 0 or 0.5
            for i, spot in ipairs(spots) do
                spawndata.base_time = 0.25 * i
				spawndata.icon_offset = i == centeridx and centeroffset or nil
                ropebridgemanager:QueueCreateRopeBridgeAtPoint(spot.x, spot.y, spot.z, spawndata)
            end
        end
    end
end

local function kitfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("rope_bridge")
	inst.AnimState:SetBuild("rope_bridge")
	inst.AnimState:PlayAnimation("rope_bridge_kit")

	MakeInventoryFloatable(inst, "med", nil, { 1.2, 1, 1 })

	inst:AddTag("deploykititem")
	inst:AddTag("usedeployspacingasoffset")

	inst._custom_candeploy_fn = CLIENT_CanDeploy -- for DEPLOYMODE.CUSTOM

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("inventoryitem")

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

	inst:AddComponent("deployable")
	inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
	inst.components.deployable.ondeploy = OnDeploy
    inst.components.deployable.keep_in_inventory_on_deploy = true

	inst:AddComponent("fuel")
	inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

	MakeSmallBurnable(inst)
	MakeSmallPropagator(inst)
	MakeHauntableLaunch(inst)

	return inst
end

--------------------------------------------------------------------------

local function SetPieceTint(piece, isvalid)
	if piece._validtint ~= isvalid then
		piece._validtint = isvalid
		if isvalid then
			piece.AnimState:SetAddColour(0.25, 0.75, 0.25, 0)
			piece.AnimState:SetMultColour(1, 1, 1, 1)
			piece.AnimState:Show("ROPES")
			piece.rope1:Show()
			piece.rope2:Show()
		else
			piece.AnimState:SetAddColour(0.75, 0.25, 0.25, 0)
			piece.AnimState:SetMultColour(1, 1, 1, 0.3)
			piece.AnimState:Hide("ROPES")
			piece.rope1:Hide()
			piece.rope2:Hide()
		end
	end
end

local function CreatePlacerRope()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("NOCLICK")
	inst:AddTag("placer")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("rope_bridge")
	inst.AnimState:SetBuild("rope_bridge")
	inst.AnimState:PlayAnimation("rope_support_"..tostring(math.random(4)))
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetAddColour(0.25, 0.75, 0.25, 0)

	return inst
end

local function CreatePlacerBridgePiece()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("NOCLICK")
	inst:AddTag("placer")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("rope_bridge")
	inst.AnimState:SetBuild("rope_bridge")
	inst.AnimState:PlayAnimation("bridge_idle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(1)
	inst.AnimState:SetLightOverride(1)

	inst.rope1 = CreatePlacerRope()
	inst.rope1.entity:SetParent(inst.entity)
	inst.rope1.Transform:SetPosition(ROPE1_OFFSET:Get())

	inst.rope2 = CreatePlacerRope()
	inst.rope2.entity:SetParent(inst.entity)
	inst.rope2.Transform:SetPosition(ROPE2_OFFSET:Get())

	return inst
end

local TILE_SIZE = 4

local function placer_onupdatetransform(inst)
	--snap to tile center with slight offset back toward the quadrant we were in,
	--since bridge search will need that to determine direction to extend bridge.
	local x, y, z = inst.Transform:GetWorldPosition()
	local tx, ty, tz = TheWorld.Map:GetTileCenterPoint(x, y, z)
	local dx = math.abs(tx - x)
	local dz = math.abs(tz - z)
	inst.pos.x = dx <= 0 and tx or tx + TILE_SIZE * (x > tx and 1 or -1) * (dx >= dz and 0.1 or 0.09)
	inst.pos.z = dz <= 0 and tz or tz + TILE_SIZE * (z > tz and 1 or -1) * (dz >= dx and 0.1 or 0.09)

	inst.Transform:SetPosition(inst.pos:Get())

	local valid, spots
	if TheWorld.net and TheWorld.net.components.quaker and TheWorld.net.components.quaker:IsQuaking() then
		valid = false
	else
		valid, spots = Bridge_DeployCheck_Helper(ThePlayer, inst.pos, RopeBridge_Options)
	end
	if valid then
		local numkits = 0
		if inst.components.placer.invobject then
			local stackable = inst.components.placer.invobject.replica.stackable
			if stackable and stackable:StackSize() >= #spots then
				numkits = #spots
			else
				local inventory = inst.components.placer.builder and inst.components.placer.builder.replica.inventory or nil
				if inventory then
					local _, count = inventory:Has(inst.components.placer.invobject.prefab, #spots)
					numkits = math.min(count, #spots)
				end
			end
		end

		local isvalid = numkits >= #spots
		local rot =
			(spots.direction.x > 0 and 0) or
			(spots.direction.x < 0 and 180) or
			(spots.direction.z > 0 and -90) or
			90

		for i, v in ipairs(spots) do
			local piece = inst.pieces[i]
			if piece then
				piece:Show()
			else
				piece = CreatePlacerBridgePiece()
				piece.entity:SetParent(inst.entity)

				--V2C: do not use this, as it controls visibility, and we need
				--     to control that ourselves for unused pieces in the pool
				--inst.components.placer:LinkEntity(piece)

				inst.pieces[i] = piece
			end
			piece.Transform:SetRotation(rot)
			piece.Transform:SetPosition(inst.entity:WorldToLocalSpace(v:Get()))
			SetPieceTint(piece, i <= numkits)
		end
		for i = #spots + 1, #inst.pieces do
			inst.pieces[i]:Hide()
		end
		inst.numvisiblepieces = #spots
	else
		for i, v in ipairs(inst.pieces) do
			v:Hide()
		end
		inst.numvisiblepieces = 0
	end
end

local function placer_oncanbuild(inst, mouseblocked)
	if mouseblocked then
		inst:Hide()
		inst.components.placer:ToggleHideInvIcon(false)
	else
		inst:Show()
		inst.components.placer:ToggleHideInvIcon(true)
	end
end

local function placer_oncannotbuild(inst, mouseblocked)
	if mouseblocked or inst.numvisiblepieces <= 0 then
		inst:Hide()
		inst.components.placer:ToggleHideInvIcon(false)
	else
		inst:Show()
		inst.components.placer:ToggleHideInvIcon(true)
	end
end

local function placer_postinit(inst)
	inst.pos = Vector3()
	inst.pieces = {}
	inst.numvisiblepieces = 0
	inst.components.placer.onupdatetransform = placer_onupdatetransform
	inst.components.placer.oncanbuild = placer_oncanbuild
	inst.components.placer.oncannotbuild = placer_oncannotbuild
end

return Prefab("rope_bridge_fx", fn, assets),
	Prefab("rope_bridge_kit", kitfn, assets_kit, prefabs),
	MakePlacer("rope_bridge_kit_placer", nil, nil, nil, true, nil, nil, nil, nil, "eight", placer_postinit)
