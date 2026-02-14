local easing = require("easing")

local assets =
{
    Asset("ANIM", "anim/floatinglantern.zip"),
    Asset("SOUND", "sound/yoth_2026.fsb"),
}

local prefabs =
{
	"globalmapicon",
    "floatinglanternfire",
    "floatinglantern_shadow",
}

local SHADOW_ANIMS =
{
    ["idle_ground"] = true,
    ["inflate"] = true,
    ["fall_pst"] = true,
    ["place"] = true,
}

local FIRE_OFFSET = Vector3(0, -10, 0)
local CENTER_CAMERA_FADE_MIN_DIST_SQ = 150 * 150
local CENTER_CAMERA_FADE_DIST_SQ = 350 * 350
local CENTER_CAMERA_MINFADE = 0.1

local function OnEnableCameraFadeDirty(inst)
	if inst.enablecamerafade:value() then
		if inst.components.camerafade then
			inst.components.camerafade:Enable(true)
		else
			inst:AddComponent("camerafade")
			inst.components.camerafade:SetUp(10, 5)
			inst.components.camerafade:SetUpCenterFade("glow", CENTER_CAMERA_FADE_MIN_DIST_SQ, CENTER_CAMERA_FADE_DIST_SQ, CENTER_CAMERA_MINFADE)
			inst.components.camerafade:SetLerpToHeight(4)
		end
	elseif inst.components.camerafade then
		inst.components.camerafade:Enable(false, inst:HasTag("INLIMBO"))
	end
end

local function EnableCameraFade(inst, enable)
	if inst.enablecamerafade:value() ~= enable then
		inst.enablecamerafade:set(enable)
		if not TheNet:IsDedicated() then
			OnEnableCameraFadeDirty(inst)
		end
	end
end

local function PlaySyncedAnimation(inst, name, loop)
    inst.AnimState:PlayAnimation(name, loop or nil)
    if inst.shadow ~= nil then
        if SHADOW_ANIMS[name] then
            inst.shadow:Show()
            inst.shadow.AnimState:PlayAnimation(name.."_shadow", loop or nil)
        else
            inst.shadow:Hide()
        end
    end
end

local function PushSyncedAnimation(inst, name, loop)
    inst.AnimState:PushAnimation(name, loop or nil)
    if inst.shadow ~= nil then
        if SHADOW_ANIMS[name] then
            inst.shadow:Show()
            inst.shadow.AnimState:PushAnimation(name.."_shadow", loop or nil)
        else
            inst.shadow:Hide()
        end
    end
end

local WIND_ANGLE_VARIANCE = 15
-- level 1 = full
-- level 4 = empty
local lantern_levels = TUNING.FLOATINGLANTERN_LEVELS

local function DeactivateClickLantern(inst)
    if not inst.noclickon then
        inst.noclickon = true
        inst:AddTag("NOCLICK")
		EnableCameraFade(inst, true)
    end
end

local function DeactivateLantern(inst)
    if not inst.deactivated then
        inst.deactivated = true
        RemovePhysicsColliders(inst)
        inst.Physics:CollidesWith(COLLISION.ITEMS)
	    inst.components.inventoryitem.canbepickedup = false
    end
end

local function DeactivateFloater(inst)
    if not inst.deactivated_floater then
        inst.deactivated_floater = true
        inst.components.inventoryitem:SetLanded(false, false)
    end
end

local function OnUpdateMotorVel(inst, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    if y >= 8 then
        DeactivateClickLantern(inst)
    elseif y >= 1 then
        DeactivateLantern(inst)
    elseif y >= 0.1 then
        DeactivateFloater(inst)
    end

    inst.lantern_vel = inst.lantern_vel + (inst.wind_vel * dt * .5)
    if inst.lantern_vel:Length() > 1 then
        inst.lantern_vel = inst.lantern_vel:GetNormalized()
    end

    local theta = math.atan2(inst.lantern_vel.z, inst.lantern_vel.x)
    local target_height = lantern_levels[inst.lantern_level]
    local xvel, yvel, zvel = math.cos(theta), target_height - y, -math.sin(theta)
    local time = GetTime() - inst.start_flyoff_time

    local throttlenoise = 0.5 * perlin(0, 0, time * 0.05)
    local hthrottle = 1 + throttlenoise
    if time < 4 then -- Small optimization.
        local easein = easing.inQuad(math.clamp(time - 1, 0, 3), 0, 1, 3)
        hthrottle = easein + throttlenoise
        yvel = yvel * easein + easing.inQuad(math.min(time, 3), 1, yvel - 1, 3)
    end
    yvel = yvel + (math.sin(time * 0.3) * 2) --+ easing.inQuad(math.min(time, 3), 1, yvel - 1, 3)
    inst.Physics:SetMotorVel(xvel * hthrottle, yvel, zvel * hthrottle)
end

local function DoDirectionChange(inst, data)
    if data then
        local angle = ReduceAngle(GetRandomWithVariance(data.angle, WIND_ANGLE_VARIANCE))
        local theta = angle * DEGREES
        inst.wind_vel = Vector3(math.cos(theta), 0, math.sin(theta))
    end
end

local function flyoff(inst, isload)
	if not inst.components.fueled:IsEmpty() then
	    inst.Physics:ClearCollisionMask()
        inst.components.fueled:StartConsuming()
        inst.components.burnable:Ignite()
        inst.components.burnable:SetFXLevel(inst.components.fueled:GetCurrentSection(), inst.components.fueled:GetSectionPercent())

        if isload then
            inst:PlaySyncedAnimation("idle_air", true)
            inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

            for i, v in ipairs(inst.components.burnable.fxchildren) do
                v.AnimState:SetFrame(math.random(v.AnimState:GetCurrentAnimationNumFrames()) - 1)
            end

            DeactivateClickLantern(inst)
        else
            inst.SoundEmitter:PlaySound("yoth_2026/floatinglantern/inflate")
            inst:PlaySyncedAnimation("inflate")
            inst:PushSyncedAnimation("idle_air", true)
        end
        --
        inst.lantern_vel = Vector3(0, 0, 0)
        inst.flying = true
        inst.start_flyoff_time = isload and (-4 + math.random() * -8) or GetTime()
        inst.components.updatelooper:AddOnUpdateFn(OnUpdateMotorVel)

        inst._do_direction_change = function(world, data)
            DoDirectionChange(inst, data)
        end
        inst:ListenForEvent("windchange", inst._do_direction_change, TheWorld)
        DoDirectionChange(inst, { angle = TheWorld.components.worldwind and TheWorld.components.worldwind:GetWindAngle() or math.random(360) })

        --
        inst.globalicon = SpawnPrefab("globalmapicon")
        inst.globalicon:TrackEntity(inst)
        inst.globalicon.MiniMapEntity:SetPriority(21)
	end

    inst.flyawaytask = nil
end

local function AddNOCLICK(inst)
    inst:AddTag("NOCLICK")
end

local function DoErodeAway(inst)
    ErodeAway(inst)
    if inst.shadow ~= nil then
        ErodeAway(inst.shadow)
    end
end

local function OnAnimOverFall(inst)
    if inst.AnimState:AnimDone() then
        inst:RemoveTag("NOCLICK")
        inst:DoTaskInTime(3, AddNOCLICK)
        inst:DoTaskInTime(4, DoErodeAway)
    end
end

local function OnUpdateFalling(inst, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    if y <= 1 then
        inst.Physics:SetMotorVel(0, 0, 0)
        inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateFalling)
        if ShouldEntitySink(inst, true) then
            SinkEntity(inst)
        else
            inst:PlaySyncedAnimation("fall_pst")
            inst.SoundEmitter:PlaySound("yoth_2026/floatinglantern/land")
            inst:ListenForEvent("animover", OnAnimOverFall)
        end
    else
        inst.Physics:SetMotorVel(0, -3, 0)
    end
end

local function StopFlying(inst)
    if inst.flying then
        inst.flying = nil
        if inst:IsAsleep() then
            inst:Remove()
        else
            inst:RemoveEventCallback("windchange", inst._do_direction_change, TheWorld)
            inst:ListenForEvent("entitysleep", inst.Remove)
            inst.persists = false

            inst:PlaySyncedAnimation("fall_pre")
            inst:PushSyncedAnimation("fall_loop", true)

            inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateMotorVel)
            inst.components.updatelooper:AddOnUpdateFn(OnUpdateFalling)

            if inst.globalicon ~= nil then
                inst.globalicon:Remove()
                inst.globalicon = nil
            end
			EnableCameraFade(inst, false)
            --
            inst.lantern_vel = nil
            inst.start_flyoff_time = nil
        end
    end
end

local function StartFlying(inst, isload)
    if not inst.components.fueled:IsEmpty() then
        if isload then
            if inst.flyawaytask then
                inst.flyawaytask:Cancel()
            end
            flyoff(inst, true)
        elseif inst.flyawaytask == nil then
            inst.flyawaytask = inst:DoTaskInTime(0.2, flyoff)
        end
    end
end

local function OnAnimOverDropped(inst)
    if inst.AnimState:IsCurrentAnimation("idle_ground")
        or inst.AnimState:IsCurrentAnimation("place") then
        StartFlying(inst)
        inst:RemoveEventCallback("animover", OnAnimOverDropped)
    end
end

local function OnDropped(inst, init)
    if POPULATING or init then
        inst:PlaySyncedAnimation("idle_ground")
    else
        inst.SoundEmitter:PlaySound("yoth_2026/floatinglantern/place")
        inst:PlaySyncedAnimation("place")
        inst:PushSyncedAnimation("idle_ground")
    end

    inst:ListenForEvent("animover", OnAnimOverDropped)
end

local function OnPickup(inst)
    inst.components.fueled:StopConsuming()
    inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateMotorVel)
	if inst.flyawaytask ~= nil then
		inst.flyawaytask:Cancel()
		inst.flyawaytask = nil
	end
	EnableCameraFade(inst, false)
end

local function UpdateLanternLevelArt(inst)
    inst.AnimState:OverrideSymbol("swap_lantern", "floatinglantern", "lantern_level"..tostring(inst.lantern_level))
end

local function UpdateLanternLevel(inst)
    UpdateLanternLevelArt(inst)
    if inst.lantern_level == #lantern_levels then -- last state is empty
        StopFlying(inst)
    end
end

-- Well it's not really helium, it's hot air. :^)
local function SetHeliumLevel(inst, level)
	inst.lantern_level = Clamp(level, 1, #lantern_levels)

    if inst.lantern_level >= 3 then -- lowest level and empty state.
        if inst.globalicon ~= nil then
            inst.globalicon:Remove()
            inst.globalicon = nil
        end
    end

	-- play animation
	if not POPULATING and not inst:IsInLimbo() then
        inst.SoundEmitter:PlaySound("yoth_2026/floatinglantern/deflate")
        inst:PlaySyncedAnimation("deflate")
        inst:PushSyncedAnimation("idle_air", true)

        local anim_time = inst.AnimState:GetCurrentAnimationLength() - 5 * FRAMES
        inst:DoTaskInTime(anim_time, UpdateLanternLevel)
	else
        UpdateLanternLevel(inst)
	end
end

local function onfuelsectionchange(newsection, oldsection, inst)
    if newsection <= 0 then
        inst.components.burnable:Extinguish()
        inst.persists = false
    end

	SetHeliumLevel(inst, #lantern_levels - newsection)
end

local function updatefuelrate(inst)
    local no_rain_immunity = inst.components.rainimmunity == nil
	inst.components.fueled.rate = 1
        + (TheWorld.state.israining and no_rain_immunity and TUNING.FLOATINGLANTERN_RAIN_RATE * TheWorld.state.precipitationrate or 0)
        + (TheWorld.state.islunarhailing and no_rain_immunity and TUNING.FLOATINGLANTERN_LUNARHAIL_RATE * TheWorld.state.lunarhailrate or 0)
        + (not TheWorld.Map:IsInMapBounds(inst.Transform:GetWorldPosition()) and TUNING.FLOATINGLANTERN_OUT_OF_BOUNDS_RATE or 0)
end

local function onupdatefueled(inst)
    updatefuelrate(inst)
    inst.components.burnable:SetFXLevel(inst.components.fueled:GetCurrentSection(), inst.components.fueled:GetSectionPercent())
end

local function OnIgnite(inst)
    inst.AnimState:Show("glow")
end

local function OnExtinguish(inst)
    inst.AnimState:Hide("glow")
end

local function GetStatus(inst)
    -- HELD state is handled in inspectable already.
	return inst.components.fueled:IsEmpty() and "DEFLATED"
		or nil
end

-- No need to save lantern level. Fueled callbacks run on load
local function OnSave(inst, data)
    data.flying = inst.flying
end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.flying then
            StartFlying(inst, true)
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst, 1, 1)
    inst.Physics:SetDontRemoveOnSleep(true)

    MakeInventoryFloatable(inst, "med", 0.075)

    inst.MiniMapEntity:SetIcon("floatinglantern.png")
	inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)

    inst.AnimState:SetBank("floatinglantern")
    inst.AnimState:SetBuild("floatinglantern")
    inst.AnimState:PlayAnimation("idle_ground", true)
    inst.AnimState:OverrideSymbol("swap_lantern", "floatinglantern", "lantern_level1")

    inst:AddTag("cattoyairborne")
    inst:AddTag("hide_percentage")

	inst.enablecamerafade = net_bool(inst.GUID, "floatinglantern.enablecamerafade", "enablecamerafadedirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst:ListenForEvent("enablecamerafadedirty", OnEnableCameraFadeDirty)

        return inst
    end
    inst.use_physics_radius_for_extra_drop_dist = true
    ---
	inst.shadow = SpawnPrefab("floatinglantern_shadow")
	inst.shadow.entity:SetParent(inst.entity)
	inst.highlightchildren = { inst.shadow }

    inst.PlaySyncedAnimation = PlaySyncedAnimation
    inst.PushSyncedAnimation = PushSyncedAnimation
    ---

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetOnDroppedFn(OnDropped)
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPickup)
    inst.components.inventoryitem.nobounce = true

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.MAGIC
    inst.components.fueled:InitializeFuelLevel(TUNING.FLOATINGLANTERN_DURATION)
	inst.components.fueled:SetSections(#lantern_levels - 1)
    inst.components.fueled:SetSectionCallback(onfuelsectionchange)
    inst.components.fueled:SetUpdateFn(onupdatefueled)

    inst:AddComponent("updatelooper")

    inst:AddComponent("burnable")
    inst.components.burnable:AddBurnFX("floatinglanternfire", FIRE_OFFSET, "flames_wide", true, nil, true)
    inst:ListenForEvent("onignite", OnIgnite)
    inst:ListenForEvent("onextinguish", OnExtinguish)

	inst.lantern_level = 1

	OnDropped(inst, true)

    MakeHauntableLaunch(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

--

local function client_on_front_replicated(inst)
    local parent = inst.entity:GetParent()
    if parent ~= nil and parent.prefab == "floatinglantern" then
        parent.highlightchildren = parent.highlightchildren or {}
        table.insert(parent.highlightchildren, inst)
    end
end

local function fn_shadow()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("floatinglantern")
    inst.AnimState:SetBuild("floatinglantern")
    inst.AnimState:PlayAnimation("idle_ground_shadow", true)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        -- To hook up highlightchildren on clients.
        inst.OnEntityReplicated = client_on_front_replicated

        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("floatinglantern", fn, assets, prefabs),
    Prefab("floatinglantern_shadow", fn_shadow, assets)