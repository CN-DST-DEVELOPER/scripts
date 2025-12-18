local hotspring_assets =
{
    Asset("ANIM", "anim/crater_pool.zip"),
    Asset("MINIMAP_IMAGE", "hotspring"),
}

local hotspring_prefabs =
{
    "crater_steam_fx1",
    "crater_steam_fx2",
    "crater_steam_fx3",
    "crater_steam_fx4",
    "slow_steam_fx1",
    "slow_steam_fx2",
    "slow_steam_fx3",
    "slow_steam_fx4",
    "slow_steam_fx5",
    "moonglass",
    "bluegem",
    "redgem",
    "bathbomb",
}

local MINED_GLASS_LOOT_TABLE = {"moonglass", "moonglass", "moonglass", "moonglass", "moonglass"}

local function choose_anim_by_level(remaining, low, med, full)
    return (remaining < (TUNING.HOTSPRING_WORK / 3) and low) or (remaining < (TUNING.HOTSPRING_WORK * 2 / 3) and med) or full
end

local function push_special_idle(inst)
    if inst._glassed then
        -- We need to push a size-relevant sparkle, and then also the size-relevant idle.
		inst._glass_sparkle_tick = (inst._glass_sparkle_tick or 0) - 1

		if inst._glass_sparkle_tick < 0 then
			local work_remaining = (inst.components.workable ~= nil and inst.components.workable.workleft) or TUNING.HOTSPRING_WORK
			local sparkle_anim = choose_anim_by_level(work_remaining, "glass_low_sparkle1", "glass_med_sparkle"..math.random(2), "glass_full_sparkle"..math.random(3))
			inst.AnimState:PushAnimation(sparkle_anim, false)

			local idle_anim = choose_anim_by_level(work_remaining, "glass_low", "glass_med", "glass_full")
			inst.AnimState:PushAnimation(idle_anim)

			inst._glass_sparkle_tick = math.random(1, 3)
		end
    elseif inst.components.bathbombable.is_bathbombed then
        local steam_anim_index = math.random(4)
        local x, y, z = inst.Transform:GetWorldPosition()
        SpawnPrefab("crater_steam_fx"..steam_anim_index).Transform:SetPosition(x, y, z)
    else
        local steam_anim_index = math.random(5)
        local x, y, z = inst.Transform:GetWorldPosition()
        SpawnPrefab("slow_steam_fx"..steam_anim_index).Transform:SetPosition(x, y, z)
    end
end

local function StartFx(inst, delay)
	if inst._fx_task ~= nil then
		inst._fx_task:Cancel()
	end
    inst._fx_task = inst:DoPeriodicTask(TUNING.HOTSPRING_IDLE.BASE, push_special_idle, delay or (math.random() * TUNING.HOTSPRING_IDLE.DELAY))
end

local function StopFx(inst)
    if inst._fx_task ~= nil then
        inst._fx_task:Cancel()
        inst._fx_task = nil
    end
end

local function OnBathingPoolTick_PerOccupant(inst, occupant, dt)
    if occupant.components.health then
        occupant.components.health:DoDelta(TUNING.HOTSPRING_HEALTH_PER_SECOND * dt, true, inst.prefab, true)
    end
    if occupant.components.sanity then -- Update sanity rate in case it shifts.
        local rate = TUNING.HOTSPRING_SANITY_PER_SECOND
        if TheWorld.Map:IsInLunacyArea(occupant.Transform:GetWorldPosition()) then
            rate = -rate
        end
        occupant.components.sanity.externalmodifiers:SetModifier(inst, rate)
    end
end

local function OnBathingPoolTick(inst)
    local bathingpool = inst.components.bathingpool
    if bathingpool then
        bathingpool:ForEachOccupant(OnBathingPoolTick_PerOccupant, TUNING.HOTSPRING_TICK_PERIOD)
    end
end

local function OnStartBeingOccupiedBy(inst, ent)
    if not inst.bathingpoolents then
        inst.bathingpoolents = {
            [ent] = true,
        }
        inst.bathingpooltask = inst:DoPeriodicTask(TUNING.HOTSPRING_TICK_PERIOD, OnBathingPoolTick)
    else
        inst.bathingpoolents[ent] = true
    end
    if ent.components.sanity then
        local rate = TUNING.HOTSPRING_SANITY_PER_SECOND
        if TheWorld.Map:IsInLunacyArea(ent.Transform:GetWorldPosition()) then
            rate = -rate
        end
        ent.components.sanity.externalmodifiers:SetModifier(inst, rate)
    end
end

local function OnStopBeingOccupiedBy(inst, ent)
    if inst.bathingpoolents then
        inst.bathingpoolents[ent] = nil
        if ent.components.sanity then
            ent.components.sanity.externalmodifiers:RemoveModifier(inst)
        end
        if next(inst.bathingpoolents) == nil then
            if inst.bathingpooltask then
                inst.bathingpooltask:Cancel()
                inst.bathingpooltask = nil
            end
            inst.bathingpoolents = nil
        end
    end
end

local function EnableBathingPool(inst, enable)
	if not enable then
		inst:RemoveComponent("bathingpool")
	elseif inst.components.bathingpool == nil then
		inst:AddComponent("bathingpool")
		inst.components.bathingpool:SetRadius(1.1)
        inst.components.bathingpool:SetOnStartBeingOccupiedBy(OnStartBeingOccupiedBy)
        inst.components.bathingpool:SetOnStopBeingOccupiedBy(OnStopBeingOccupiedBy)
	end
end

local function SetGlassedLayering(inst, enable)
	if enable then
		inst.AnimState:SetLayer(LAYER_WORLD)
		inst.AnimState:SetSortOrder(0)
	else
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(2)
	end
end

local function Refill(inst, snap)
	if inst.delay_refill_task ~= nil then
		inst.delay_refill_task:Cancel()
		inst.delay_refill_task = nil
	end

    inst._glassed = false
    inst:RemoveTag("moonglass")
    inst.components.watersource.available = true
    inst.components.bathbombable:Reset()
	EnableBathingPool(inst, false)
	SetGlassedLayering(inst, false)

	if not snap then
		inst.AnimState:PlayAnimation("refill", false)
		inst.AnimState:PushAnimation("idle", true)
		StartFx(inst, 30*FRAMES)
	    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/refill")
	else
		inst.AnimState:PlayAnimation("idle", true)
		StartFx(inst)
	end
end

local function delay_refill(inst)
	inst:StopWatchingWorldState("moonphase", delay_refill)
	inst.delay_refill_task = inst:DoTaskInTime(0.25 + math.random(), Refill)
end

local function RemoveGlass(inst)
    inst._glassed = false
    inst:RemoveTag("moonglass")
    inst.components.watersource.available = false
    inst.components.bathbombable:DisableBathBombing()
	EnableBathingPool(inst, false)
	SetGlassedLayering(inst, false)
	inst.AnimState:PlayAnimation("empty")
	StopFx(inst)

	inst:WatchWorldState("moonphase", delay_refill)
end

local function OnGlassedSpringMineFinished(inst, miner)
    inst.components.lootdropper:DropLoot()
    if math.random() < TUNING.HOTSPRING_GEM_DROP_CHANCE then
        inst.components.lootdropper:SpawnLootPrefab((math.random(2) == 1 and "bluegem") or "redgem")
    end
    RemoveGlass(inst)
end

local function OnGlassSpringMined(inst, miner, mines_remaining, num_mines)
    local glass_idle = choose_anim_by_level(mines_remaining, "glass_low", "glass_med", "glass_full")
    inst.AnimState:PlayAnimation(glass_idle)
end

local function EjectOccupant(inst, ent, radius)
	ent:PushEventImmediate("knockback", { knocker = inst, radius = radius, strengthmult = 0.3 })
end

local function TurnToGlassed(inst, is_loading)
    inst._glassed = true
    inst:AddTag("moonglass")
    inst.components.watersource.available = false
	inst.components.bathbombable:DisableBathBombing()
	if inst.components.bathingpool then
		inst.components.bathingpool:ForEachOccupant(EjectOccupant, inst.components.bathingpool:GetRadius())
	end
	EnableBathingPool(inst, false)
	SetGlassedLayering(inst, true)

    inst.Light:Enable(false)

    if is_loading then
        local work_remaining = (inst.components.workable ~= nil and inst.components.workable.workleft) or TUNING.HOTSPRING_WORK
        local glass_idle = choose_anim_by_level(work_remaining, "glass_low", "glass_med", "glass_full")
        inst.AnimState:PlayAnimation(glass_idle)
    else
        inst.AnimState:PlayAnimation("glassify")
        inst.AnimState:PushAnimation("glass_full", false)
	    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/glassify")

        inst.components.workable:SetWorkLeft(TUNING.HOTSPRING_WORK)
    end

    inst.components.workable:SetWorkable(true)
end

--------------------------------------------------------------------------

local function GetHeat(inst)
	if inst.components.bathbombable.is_bathbombed then
		inst.components.heater:SetThermics(true, false)
		return TUNING.HOTSPRING_HEAT.ACTIVE
	elseif inst.components.bathbombable.can_be_bathbombed then
		inst.components.heater:SetThermics(true, false)
		return TUNING.HOTSPRING_HEAT.PASSIVE
	end
	inst.components.heater:SetThermics(false, false)
	return 0
end

--------------------------------------------------------------------------

local function OnFullMoonChanged(inst, isfullmoon)
    if not inst._glassed and inst.components.bathbombable.is_bathbombed then
        if isfullmoon then
            TurnToGlassed(inst)
        end
    end
end

--------------------------------------------------------------------------

local function OnBathBombed(inst)
    if TheWorld.state.isfullmoon then
        TurnToGlassed(inst)
    else
		inst.Light:Enable(true)
		EnableBathingPool(inst, true)
		SetGlassedLayering(inst, false)

		if not POPULATING then
			inst.AnimState:PlayAnimation("bath_bomb", false)
			inst.AnimState:PushAnimation("glow_pre", false)
			inst.AnimState:PushAnimation("glow_loop", true)
		    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/small_splash")
		    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/bathbomb")
		else
			inst.AnimState:PlayAnimation("glow_loop", true)
		end
    end
end

--------------------------------------------------------------------------


local function OnSleep(inst)
	StopFx(inst)
end

local function OnWake(inst)
    if inst._fx_task == nil and (inst.components.bathbombable.is_bathbombed or inst.components.bathbombable.can_be_bathbombed) then
        StartFx(inst)
    end
end

local function GetStatus(inst)
	return inst._glassed and "GLASS"
			or inst._bathbombed and "BOMBED"
			or (not inst.components.bathbombable.is_bathbombed and not inst.components.bathbombable.can_be_bathbombed) and "EMPTY"
			or nil
end

--------------------------------------------------------------------------

local function OnSave(inst, data)
	if inst.delay_refill_task ~= nil then
		data.delay_refill = true
	elseif inst._glassed then
		data.glassed = true
	elseif inst.components.bathbombable.is_bathbombed then
		data.isbathbombed = true
	elseif not inst.components.bathbombable.is_bathbombed and not inst.components.bathbombable.can_be_bathbombed then
		data.empty = true
	end
end

local function OnLoad(inst, data)
    if data ~= nil then
		if data.delay_refill then
			Refill(inst, true)
        elseif data.glassed then
            TurnToGlassed(inst, true)
		elseif data.empty then
			RemoveGlass(inst)
        elseif data.isbathbombed then
            inst.components.bathbombable:OnBathBombed()
        end
    end
end

--------------------------------------------------------------------------

local function hotspring()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	MakePondPhysics(inst, 1)

    inst.AnimState:SetBuild("crater_pool")
    inst.AnimState:SetBank("crater_pool")
    inst.AnimState:PlayAnimation("idle", true)

	inst.AnimState:SetLayer(LAYER_BACKGROUND) -- TODO: these should be enabled but then the player will stand on top of the glass, so the glass needs to be seperated out in order for this to work.
	inst.AnimState:SetSortOrder(2)

    inst.MiniMapEntity:SetIcon("hotspring.png")

    -- From watersource component
    inst:AddTag("watersource")
    inst:AddTag("antlion_sinkhole_blocker")
    inst:AddTag("birdblocker")

    --HASHEATER (from heater component) added to pristine state for optimization
	inst:AddTag("HASHEATER")

    inst.Light:Enable(false)
    inst.Light:SetRadius(TUNING.HOTSPRING_GLOW.RADIUS)
    inst.Light:SetIntensity(TUNING.HOTSPRING_GLOW.INTENSITY)
    inst.Light:SetFalloff(TUNING.HOTSPRING_GLOW.FALLOFF)
    inst.Light:SetColour(0.1, 1.6, 2)

    inst.no_wet_prefix = true

	inst:SetDeploySmartRadius(1.5)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("heater")
    inst.components.heater.heatfn = GetHeat

    -- The hot spring uses full moon changes to trigger calcification.
    inst:WatchWorldState("isfullmoon", OnFullMoonChanged)

    inst:AddComponent("bathbombable")
    inst.components.bathbombable:SetOnBathBombedFn(OnBathBombed)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetOnFinishCallback(OnGlassedSpringMineFinished)
    inst.components.workable:SetOnWorkCallback(OnGlassSpringMined)
    inst.components.workable:SetWorkLeft(TUNING.HOTSPRING_WORK)
    inst.components.workable:SetWorkable(false)
    inst.components.workable.savestate = true

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLoot(MINED_GLASS_LOOT_TABLE)

    inst:AddComponent("watersource")

    inst._bathbombed = false
    inst._glassed = false

    StartFx(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst.OnEntitySleep = OnSleep
    inst.OnEntityWake = OnWake

    return inst
end

return Prefab("hotspring", hotspring, hotspring_assets, hotspring_prefabs)
