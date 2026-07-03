require "prefabutil"
local SourceModifierList = require("util/sourcemodifierlist")
local easing = require("easing")

local assets =
{
    Asset("ANIM", "anim/trap_fumarole.zip"),
    Asset("ANIM", "anim/trap_fumarole_ground_fx.zip"),
    Asset("SCRIPT", "scripts/prefabs/trap_fumarole_util.lua"),
    Asset("MINIMAP_IMAGE", "trap_fumarole"),
}

local prefabs =
{
    "fumarole_ember",
    "trap_fumarole_burn_fx",
    "fumarole_cook_fx",
}

local assets_burn_fx =
{
	Asset("ANIM", "anim/trap_fumarole_burn_fx.zip"),
}

local TrapFumaroleUtil = require("prefabs/trap_fumarole_util")

-- AOE_RANGE_PADDING doesn't matter because the trapfumaroleburning component checks only in the initial point, we should fix that.
local REGISTERED_AOE_TAGS
local AOE_RANGE_PADDING = 3
local UPDATE_TIME = 0.5
local UPDATE_TIME_ASLEEP = 2.5
local TILE_SIZE = TrapFumaroleUtil.TILE_SCALE
local DIAG_TILE_SIZE = math.sqrt(2 * TILE_SIZE * TILE_SIZE)
local TEMPERATURE_RANGE_START_HOT = 2

--cx, cz, r: circle coords & radius
--sx, sz, hl: square coords & half length of one side
local function CircleTouchesSquare(cx, cz, r, sx, sz, hl)
	local sx1, sx2 = sx - hl, sx + hl
	local sz1, sz2 = sz - hl, sz + hl
	return cx > sx1 and cx < sx2 and cz > sz1 and cz < sz2
		or distsq(cx, cz, math.clamp(cx, sx1, sx2), math.clamp(cz, sz1, sz2)) < r * r
end

local function OnUpdate(inst)
	if REGISTERED_AOE_TAGS == nil then
		REGISTERED_AOE_TAGS = TheSim:RegisterFindTags(
		    nil,
			{ "FX", "DECOR", "INLIMBO", "flying", "noattack", "notarget", "invisible", "wall", "brightmare", "brightmareboss", "shadowcreature", "trap_fumarole" },
            nil
		)
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local radius = DIAG_TILE_SIZE / 2
	local boxrange = TILE_SIZE / 2
	for i, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, radius + AOE_RANGE_PADDING, REGISTERED_AOE_TAGS)) do
		-- if health, or inventoryitemtemperature, or cookable, or propagator.
        if v ~= inst and
            (v.components.health ~= nil and not v.components.health:IsDead()) or
            (v.components.inventoryitemtemperature ~= nil) or
            (v.components.cookable ~= nil) or
            (v.components.propagator ~= nil and v.components.burnable ~= nil)
        then
            if v.components.trapfumaroleburning == nil and v:IsValid() and not v:IsInLimbo() then
		    	local physrad = v:GetPhysicsRadius(0)
		    	local x1, y1, z1 = v.Transform:GetWorldPosition()
		    	if CircleTouchesSquare(x1, z1, physrad, x, z, boxrange) then
                    v:AddComponent("trapfumaroleburning")
		    	end
		    end
        end
	end

    if not inst:IsAsleep() then
        local chance = inst._temperaturerange == 2 and 0.05
            or inst._temperaturerange == 3 and 0.1

        if math.random() < chance then
            local halfradius = radius / 2
            local emberfx = SpawnPrefab("fumarole_ember")
            emberfx.Transform:SetPosition(x + math.random() * radius - halfradius, 0, z + math.random() * radius - halfradius)
        end
    end
end

local function StartUpdateTask(inst)
	if inst.task == nil then
		inst.task = inst:DoPeriodicTask(0.5, OnUpdate, math.random() * 0.5)
	end
end

local function CheckActiveTrap(inst)
    if inst.settrap and inst._temperaturerange >= TEMPERATURE_RANGE_START_HOT then
        StartUpdateTask(inst)
    else
        if inst.task then
            inst.task:Cancel()
            inst.task = nil
        end
    end
end

local function IsActiveTrap(inst)
    return inst.task ~= nil
end

local function IsItem(inst)
    return not inst.settrap
end

local function GetIdle(inst)
    return "idle_"..inst._temperaturerange
end

local function UpdateTemperatureRange(inst)
	local temp = inst.components.inventoryitem:GetTemperature()

	for i = #TUNING.TRAP_FUMAROLE_TEMPS, 1, -1 do
		if temp > TUNING.TRAP_FUMAROLE_TEMPS[i] then
			return i
		end
	end

	return 1
end

local function CanMouseThrough(inst) -- So that we can drop items on the hot rocks easier.
    return not inst.AnimState:IsCurrentAnimation("item")
        and ThePlayer ~= nil and ThePlayer.replica.inventory ~= nil and ThePlayer.replica.inventory:GetActiveItem() ~= nil, true
end

local function hash_OnUpdate(inst, dt)
    local delta = dt * inst.rate
	if inst.targetalpha > inst.alpha then
		inst.alpha = inst.alpha + delta
		if inst.alpha >= inst.targetalpha then
			inst.alpha = inst.targetalpha
			inst:RemoveComponent("updatelooper")
		end
	else
		inst.alpha = inst.alpha - delta
		if inst.alpha <= inst.targetalpha then
			inst.alpha = inst.targetalpha
			inst:RemoveComponent("updatelooper")
		end
	end
    inst.AnimState:SetMultColour(1, 1, 1, inst.alpha)
    if inst.alpha == 0 then
        inst:Remove()
    end
end

local function hash_SetTargetAlpha(inst, targetalpha)
    inst.targetalpha = targetalpha
    if inst.targetalpha ~= inst.alpha and inst.components.updatelooper == nil then
        inst:AddComponent("updatelooper")
        inst.components.updatelooper:AddOnUpdateFn(hash_OnUpdate)
    end
end

local function CreateHash()
    local inst = CreateEntity()
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("trap_fumarole_ground_fx")
    inst.AnimState:SetBuild("trap_fumarole_ground_fx")
    inst.AnimState:PlayAnimation("ember"..math.random(4).."_ground")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetMultColour(1, 1, 1, 0)

    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")

    inst.rate = .16 + math.random() * 0.16
    inst.targetalpha = 0
    inst.alpha = 0
    inst.SetTargetAlpha = hash_SetTargetAlpha

    return inst
end

local function CreateRock(isplacer)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(not isplacer)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

	inst.AnimState:SetBank("trap_fumarole")
	inst.AnimState:SetBuild("trap_fumarole")
	inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

    inst.CanMouseThrough = CanMouseThrough

	return inst
end

local ROCK_MINDIST_SQ = 0.400 * 0.400
local MAP_WIDTH, MAP_HEIGHT

local function RefreshRocks(inst, isplacer) -- Also used for the placer, keep in mind.
	if inst.highlightchildren == nil then
		inst.highlightchildren = {}
	end
	if inst.rocks == nil then
		inst.rocks = {}
	end
    if MAP_WIDTH == nil then
        MAP_WIDTH, MAP_HEIGHT = TheWorld.Map:GetSize()
        MAP_WIDTH = MAP_WIDTH * 2
        MAP_HEIGHT = MAP_HEIGHT * 2
    end

	local x, _, z = inst.Transform:GetWorldPosition()
    local tx, ty = TrapFumaroleUtil.GetTrapCoordsAtPoint(x, 0, z)
	local prng = PRNG_Uniform(ty * MAP_WIDTH + tx)

	local vars = { 1 }
	for i = 2, 8 do
		table.insert(vars, prng:RandInt(#vars + 1), i)
	end

    local num = prng:RandInt(5, 6)
    local radius = 1.67
    local halfradius = radius * 0.5

    local function GetRockXZ(index)
        local rockx, rockz = prng:Rand() * radius - halfradius, prng:Rand() * radius - halfradius
        local finalx, finalz = x + rockx, z + rockz
        local loop = true
        local tries = 0
        while loop do
            loop = false
            if tries > 25 then -- give up.
                return rockx, rockz
            end
            for k = 1, index - 1 do
                local rx, ry, rz = inst.rocks[k].Transform:GetWorldPosition()
                if distsq(finalx, finalz, rx, rz) < ROCK_MINDIST_SQ then
                    rockx, rockz = prng:Rand() * radius - halfradius, prng:Rand() * radius - halfradius
                    finalx, finalz = x + rockx, z + rockz
                    loop = true
                    break
                end
            end
        end
        return rockx, rockz
    end

    for i = 1, num do
        local rock = inst.rocks[i]
        if rock == nil then
            rock = CreateRock(isplacer)
            rock.entity:SetParent(inst.entity)
            inst.rocks[i] = rock
            table.insert(inst.highlightchildren, rock)
        end
        local rx, rz = GetRockXZ(i)
        rock.Transform:SetPosition(rx, 0, rz)
        rock.Transform:SetRotation(prng:Rand() * 360)

        local rnd = prng:Rand()
		rnd = 1 + math.floor(rnd * rnd * #vars * 0.75)
		rnd = table.remove(vars, rnd)
		table.insert(vars, rnd)
        if rnd == 1 then
			rock.AnimState:ClearOverrideSymbol("fumarole_rock_1")
		else
			rock.AnimState:OverrideSymbol("fumarole_rock_1", "trap_fumarole", "fumarole_rock_"..tostring(rnd))
		end

        local sx, sy = .95 + prng:Rand() * .25, .95 + prng:Rand() * .25
        sx = prng:Rand() < 0.5 and -sx or sx
        rock.AnimState:SetScale(sx, sy)
    end

    for i = num + 1, #inst.rocks do
        inst.rocks[i]:Remove()
        inst.rocks[i] = nil
    end
end

-- We set trap on client for footstep sounds.
local function DoSyncAnim(inst)
    if inst.AnimState:IsCurrentAnimation("item") then
        if not TheWorld.ismastersim then
            TrapFumaroleUtil.UnsetTrap(inst)
        end
        if inst.rocks ~= nil then
            for _, v in ipairs(inst.rocks) do
                v:Remove()
            end
            inst.highlightchildren = nil
            inst.rocks = nil
        end
	elseif inst.AnimState:IsCurrentAnimation("place") then
        if not TheWorld.ismastersim then
            TrapFumaroleUtil.UnsetTrap(inst)
            TrapFumaroleUtil.SetTrap(inst)
        end
        RefreshRocks(inst)
		local t = inst.AnimState:GetCurrentAnimationTime()
		local anim_length = inst.AnimState:GetCurrentAnimationLength() / 2
        if inst.rocks ~= nil then
		    for _, v in ipairs(inst.rocks) do
                v:Hide()
                if v.place_task then
                    v.place_task:Cancel()
                end
                if v.layer_task then
                    v.layer_task:Cancel()
                    v.layer_task = nil
                end
                v.place_task = v:DoTaskInTime(math.max(0, (anim_length * math.random()) - t), function()
                    v.place_task = nil
                    v:Show()
                    v.AnimState:PlayAnimation("place")
                    v.AnimState:SetLayer(LAYER_WORLD)
                    v.AnimState:SetSortOrder(0)
                    v.layer_task = v:DoTaskInTime(14 * FRAMES, function()
                        v.layer_task = nil
                        v.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
                        v.AnimState:SetSortOrder(3)
                    end)
                    v.SoundEmitter:PlaySound("rifts6/trap_fumarole/drop_oneshot")
                end)
		    end
        end
    else
        local temprange
        if inst.AnimState:IsCurrentAnimation("idle_3") then
            temprange = 3
        elseif inst.AnimState:IsCurrentAnimation("idle_2") then
            temprange = 2
        elseif inst.AnimState:IsCurrentAnimation("idle_1") then
            temprange = 1
        end
        if not TheWorld.ismastersim then
            inst._temperaturerange = temprange
            TrapFumaroleUtil.UnsetTrap(inst)
            TrapFumaroleUtil.SetTrap(inst)
        end
        RefreshRocks(inst)
        if temprange ~= nil then
            local anim = "idle_"..temprange
            if inst.rocks ~= nil then
                for _, v in ipairs(inst.rocks) do
                    v.AnimState:PlayAnimation(anim, true)
                    v.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
                    v.AnimState:SetLightOverride(TUNING.TRAP_FUMAROLE_LIGHTOVERRIDES[temprange])
                end
            end
        end
	end
	if inst.postupdating then
		inst.postupdating = nil
		inst.components.updatelooper:RemovePostUpdateFn(DoSyncAnim)
	end
end

local function OnSyncAnim(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(DoSyncAnim)
	end
end

local function PushSyncAnim(inst)
	inst.syncanim:push()
	DoSyncAnim(inst)
end

local function PlayIdle(inst)
    inst.AnimState:PlayAnimation(GetIdle(inst), true)
    PushSyncAnim(inst)
end

local function ClearPlayIdleTask(inst)
    if inst.play_idle_task ~= nil then
        inst.play_idle_task:Cancel()
        inst.play_idle_task = nil
    end
end

local function PlayPlaceAnimation(inst)
    inst.AnimState:PlayAnimation("place")
    PushSyncAnim(inst)

    -- Delay the idle because the client plays the rocks animations a bit delayed.
    ClearPlayIdleTask(inst)
    local anim_length = inst.AnimState:GetCurrentAnimationLength()
    inst.play_idle_task = inst:DoTaskInTime(anim_length * 1.5, PlayIdle)
end

local function OnDeploy(inst, pt, deployer) -- deployable already removes a single stack automatically
    local x, _, z = TrapFumaroleUtil.GetTrapCenterPoint(pt:Get())

    inst.Physics:Stop()
    inst.Physics:Teleport(x, 0, z)

    inst:SetTrap()
    PlayPlaceAnimation(inst)
end

local function OnChangeTemperatureRange(inst, temprange)
    inst.AnimState:PlayAnimation((inst.settrap and "idle_"..temprange) or "item")
    PushSyncAnim(inst)
    CheckActiveTrap(inst)
end

local function OnTemperatureDelta(inst, data)
    local temprange = UpdateTemperatureRange(inst)
    if inst._temperaturerange ~= temprange then
        inst._temperaturerange = temprange
        OnChangeTemperatureRange(inst, temprange)
    end

    local heaterpower = math.clamp(inst.components.inventoryitemtemperature and inst.components.inventoryitemtemperature.externalheaterpower or 0, 0, 1)
    inst.components.inventoryitem:SetTemperatureModifier("fumaroletool_mod", easing.linear(heaterpower, TUNING.TRAP_FUMAROLE_TEMP_MODIFIER, math.abs(TUNING.TRAP_FUMAROLE_TEMP_MODIFIER), 1))
end

local function OnEntityWake(inst) -- For non-dedicated
	if not TheWorld.ismastersim then
        inst.OnEntityWake = nil
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("trap_fumarole.syncanim", OnSyncAnim)
	end
	DoSyncAnim(inst)
end

local function SetTrap(inst)
    if not inst.settrap then
        inst.components.inventoryitem:SetMaxTemperature(TUNING.TRAP_FUMAROLE_MAXTEMP)
        inst:AddTag("mineactive")
        inst:AddTag("canpourwateron")
        if not inst:IsInLimbo() then
            inst.MiniMapEntity:SetEnabled(true)
        end
        if not TheNet:IsDedicated() then
            RefreshRocks(inst)
        end

        inst.components.inventoryitem.nobounce = true

        PlayIdle(inst)

        inst.settrap = true
        CheckActiveTrap(inst)
        TrapFumaroleUtil.SetTrap(inst)
    end
end

local function SetItem(inst)
    inst.MiniMapEntity:SetEnabled(false) -- has to always run because RemoveFromScene/ReturnToScene call SetEnabled
    if inst.settrap then
        inst.components.inventoryitem:SetMaxTemperature(TUNING.TRAP_FUMAROLE_MAXTEMP_HELD)
        ClearPlayIdleTask(inst)
        inst:RemoveTag("mineactive")
        inst:RemoveTag("canpourwateron")
        inst.components.inventoryitem.nobounce = false
        inst.AnimState:PlayAnimation("item")
        PushSyncAnim(inst)
        inst.settrap = nil
        CheckActiveTrap(inst)
        TrapFumaroleUtil.UnsetTrap(inst)
    end
end

local function OnPickup(inst, data)
    local owner = data ~= nil and data.owner or nil
    SetItem(inst)

    if inst.components.inventoryitem:GetTemperature() > TUNING.TRAP_FUMAROLE_TEMPS[2] then
        inst.components.inventoryitem:SetTemperature(TUNING.TRAP_FUMAROLE_TEMPS[2])
        if owner ~= nil and owner.components.health ~= nil then
            owner.components.health:DoFireDamage(TUNING.SMOTHER_DAMAGE, nil, true)
            owner:PushEvent("burnt")
        end
    end
end

local function SetIgnitingEntity(inst, ent)
    inst.ignite_num:SetModifier(ent, 1)
end

local function ClearIgnitingEntity(inst, ent)
    inst.ignite_num:RemoveModifier(ent)
end

local function CanIgniteEntity(inst, ent)
    return inst.ignite_num:HasModifier(ent) or inst.ignite_num:Get() < TUNING.TRAP_FUMAROLE_MAX_IGNITE_ITEMS
end

local function OnHaunt(inst, haunter)
    if not inst.settrap then
        inst.components.hauntable.hauntvalue = TUNING.HAUNT_TINY
        Launch(inst, haunter, TUNING.LAUNCH_SPEED_SMALL)
        return true
    end
    return false
end

local function OnSave(inst, data)
    data.settrap = inst.settrap or nil
end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.settrap ~= nil then
            inst:SetTrap()
        end
    end
end

local function GetStatus(inst)
    return inst._temperaturerange == 3 and "HOT"
        or inst._temperaturerange == 2 and "WARM"
        or nil
end

local function DisplayAdjectiveFn(inst)
	return (inst._temperaturerange and inst._temperaturerange >= 2 and STRINGS.TEMPERATURE_PREFIX.TRAP_FUMAROLE.HOT)
        or nil
end

local function CanStackWithFn(inst, item)
    return inst:HasTag("mineactive") == item:HasTag("mineactive")
end

local function CanDeployFn(inst, pt, mouseover, deployer, rotation)
    return TheWorld.Map:CanDeployFumaroleTrapAtPoint(pt, inst)
end

local DEPLOY_SMART_RADIUS = DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
	inst:SetDeploySmartRadius(DEPLOY_SMART_RADIUS)
    inst:SetPhysicsRadiusOverride(1)

    inst.MiniMapEntity:SetIcon("trap_fumarole.png")
    inst.MiniMapEntity:SetPriority(-1)
    inst.MiniMapEntity:SetEnabled(false)

    inst.AnimState:SetBank("trap_fumarole")
    inst.AnimState:SetBuild("trap_fumarole")
    inst.AnimState:PlayAnimation("item")
    inst.AnimState:Hide("glow")
    inst.AnimState:Hide("rock")
    inst.AnimState:Hide("shadow")

    inst.pickupsound = "rock"

    inst:AddTag("trap")
    inst:AddTag("trap_fumarole")
    --inventoryitemtemperature (from inventoryitem component) added to pristine state for optimization
	inst:AddTag("inventoryitemtemperature")
    -- inst:AddTag("hide_temperature")

    inst.extra_deploy_distance = .9

	inst.syncanim = net_event(inst.GUID, "trap_fumarole.syncanim")
	if not TheNet:IsDedicated() then
		inst.OnEntityWake = OnEntityWake
	end

    MakeInventoryFloatable(inst)

    inst.displayadjectivefn = DisplayAdjectiveFn
    inst._custom_candeploy_fn = CanDeployFn -- for DEPLOYMODE.CUSTOM
    inst.stackable_CanStackWithFn = CanStackWithFn
    inst.CanMouseThrough = CanMouseThrough

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_damage = TUNING.TRAP_FUMAROLE_DAMAGE

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:EnableTemperature(true)
    inst.components.inventoryitem:SetMinTemperature(TUNING.TRAP_FUMAROLE_MINTEMP)
    inst.components.inventoryitem:SetMaxTemperature(TUNING.TRAP_FUMAROLE_MAXTEMP_HELD)
    inst.components.inventoryitem:SetTemperature(TUNING.TRAP_FUMAROLE_MAXTEMP_HELD)
    inst.components.inventoryitem:SetTemperatureModifier("fumaroletool_mod", TUNING.TRAP_FUMAROLE_TEMP_MODIFIER)
    inst.components.inventoryitem:SetSaveMinAndMaxTemperature(true)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = OnDeploy
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetOnHauntFn(OnHaunt)

	inst:ListenForEvent("onputininventory", SetItem)
	inst:ListenForEvent("onpickup", OnPickup)
	inst:ListenForEvent("ondropped", SetItem)
    inst:ListenForEvent("temperaturedelta", OnTemperatureDelta)
	inst:ListenForEvent("floater_startfloating", SetItem)

    --
    inst._temperaturerange = UpdateTemperatureRange(inst)
    inst.ignite_num = SourceModifierList(inst, 0, SourceModifierList.additive)

    inst.SetIgnitingEntity = SetIgnitingEntity
    inst.ClearIgnitingEntity = ClearIgnitingEntity
    inst.CanIgniteEntity = CanIgniteEntity
    --

    inst.SetTrap = SetTrap
    inst.SetItem = SetItem

    inst.inventoryitem_DeactivateBeforeLaunch = SetItem

    inst.IsItem = IsItem
    inst.IsActiveTrap = IsActiveTrap

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

--------------------------------------------------------------------------

local function PlacerOnUpdateTransform(inst)
    local tx, tz = TrapFumaroleUtil.GetTrapCoordsAtPoint(inst.Transform:GetWorldPosition())
    if inst.cached_coords.x ~= tx or inst.cached_coords.z ~= tz then
        inst.cached_coords.x = tx
        inst.cached_coords.z = tz
        inst.components.placer.linked = {} -- clear before we potentially remove rocks
        RefreshRocks(inst, true)
	    for _, v in ipairs(inst.rocks) do
            v.AnimState:PlayAnimation("idle_1")
	    	inst.components.placer:LinkEntity(v)
	    end
    end
end

local function placer_postinit(inst)
    inst.cached_coords = { x = - 1, z = - 1 }
    inst.components.placer.snap_to_half_tile = true
	PlacerOnUpdateTransform(inst)
    inst.components.placer.onupdatetransform = PlacerOnUpdateTransform
end

--------------------------------------------------------------------------

local function fx_SetFxSize(inst, size)
	local anim = "burn_hit_"..size
	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim, true)
	end
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("DECOR")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("trap_fumarole_burn_fx")
	inst.AnimState:SetBuild("trap_fumarole_burn_fx")
	inst.AnimState:PlayAnimation("burn_hit_small", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetFinalOffset(3)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.SetFxSize = fx_SetFxSize
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("trap_fumarole", fn, assets, prefabs),
    MakePlacer("trap_fumarole_placer", nil, nil, nil, nil, nil, nil, nil, nil, nil, placer_postinit),
    Prefab("trap_fumarole_burn_fx", fxfn, assets_burn_fx)