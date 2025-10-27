local assets = {
    Asset("ANIM", "anim/whirlbigportal.zip"),
    Asset("SOUND", "sound/rifts6.fsb"),
}

local prefabs = {
    "wave_med",
}

--------------------------------------------------------------------------

local function AddAnimLayer(inst, layer, height)
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBuild("whirlbigportal")
	fx.AnimState:SetBank("whirlbigportal")
	fx.AnimState:PlayAnimation("closed")
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_WHIRLPORTAL)
	fx.AnimState:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)
	fx.AnimState:Hide("edge")
	fx.AnimState:Hide(layer == "deep" and "mid" or "deep")

	fx.entity:SetParent(inst.entity)
	fx.Transform:SetPosition(0, height, 0)

	return fx
end

local function DoSyncPlayAnim(inst, anim, loop)
	for _, v in ipairs(inst.animlayers) do
		v.AnimState:PlayAnimation(anim, loop)
	end
end

local function DoSyncPushAnim(inst, anim, loop)
	for _, v in ipairs(inst.animlayers) do
		v.AnimState:PushAnimation(anim, loop)
	end
end

local function DoSyncAnimTime(inst, t)
	for _, v in ipairs(inst.animlayers) do
		v.AnimState:SetTime(t)
	end
end

local function CheckToggleWaveBlocker(inst)
    if TheWorld.components.wavemanager then
        -- Register wave manager blocker. Assume that 'closed' and 'open_pst' is the only time it is invisible.
        if not inst:IsAsleep() 
            and not inst.AnimState:IsCurrentAnimation("closed") 
            and not inst.AnimState:IsCurrentAnimation("open_pst") 
            and inst:IsValid() then
            TheWorld.components.wavemanager:RegisterBlocker(inst, TUNING.OCEANWHIRLBIGPORTAL_RADIUS)
        else
            TheWorld.components.wavemanager:UnregisterBlocker(inst)
        end
    end
end

local function PostUpdate_Client(inst)
	if inst.AnimState:IsCurrentAnimation("closed") then
		DoSyncPlayAnim(inst, "closed")
	elseif inst.AnimState:IsCurrentAnimation("open_pst") then
		DoSyncPlayAnim(inst, "open_pst")
		DoSyncAnimTime(inst, inst.AnimState:GetCurrentAnimationTime())
		DoSyncPushAnim(inst, "closed", false)
	elseif inst.AnimState:IsCurrentAnimation("open_loop") then
		DoSyncPlayAnim(inst, "open_loop", true)
		DoSyncAnimTime(inst, inst.AnimState:GetCurrentAnimationTime())
	elseif inst.AnimState:IsCurrentAnimation("open_pre") then
		DoSyncPlayAnim(inst, "open_pre")
		DoSyncAnimTime(inst, inst.AnimState:GetCurrentAnimationTime())
		DoSyncPushAnim(inst, "open_loop")
	else
		assert(false)
	end
    CheckToggleWaveBlocker(inst)
	inst.postupdating = nil
	inst.components.updatelooper:RemovePostUpdateFn(PostUpdate_Client)
end

--client
local function OnSyncAnims(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(PostUpdate_Client)
	end
end

local function OnRemove_Client(inst)
    TheWorld.components.wavemanager:UnregisterBlocker(inst)
end

--server
local function SyncAnims(inst, anim, loop)
	if inst.animlayers then
		DoSyncPlayAnim(inst, anim, loop)
		if anim == "open_pst" then
			DoSyncPushAnim(inst, "closed", false)
		end
	end
    CheckToggleWaveBlocker(inst)
	inst.syncanims:push()
end

--------------------------------------------------------------------------

local function OnRemoveEntity(inst)
    inst.SoundEmitter:KillSound("wave")
end

local function OpenWhirlportal_finalize(inst)
    inst:RemoveEventCallback("animover", inst.OpenWhirlportal_finalize)
    inst.openingwhirlportal = nil
    inst.SoundEmitter:PlaySound("rifts6/whirlpool/whirlpool_LP", "wave")
    inst.SoundEmitter:SetParameter("wave", "size", 0.5)
    inst.AnimState:PlayAnimation("open_loop", true)
	SyncAnims(inst, "open_loop", true)
    inst.components.oceanwhirlportalphysics:SetEnabled(true)
end

local function OpenWhirlportal(inst)
    if not inst:IsAsleep() then
        if not inst.openingwhirlportal then
            inst.SoundEmitter:PlaySound("rifts6/whirlpool/whirlpool_pre")
            inst.AnimState:PlayAnimation("open_pre")
			SyncAnims(inst, "open_pre")
            inst:ListenForEvent("animover", inst.OpenWhirlportal_finalize)
            inst.openingwhirlportal = true
        end
    else
        inst:OpenWhirlportal_finalize()
    end
end

local function CloseWhirlportal(inst)
    if inst.openingwhirlportal then
        inst:RemoveEventCallback("animover", inst.OpenWhirlportal_finalize)
        inst.openingwhirlportal = nil
    end
    inst.SoundEmitter:KillSound("wave")
    inst.SoundEmitter:PlaySound("rifts6/whirlpool/whirlpool_pst")
	if inst:IsAsleep() then
		inst.AnimState:PlayAnimation("closed")
		SyncAnims(inst, "closed")
	else
		inst.AnimState:PlayAnimation("open_pst")
		inst.AnimState:PushAnimation("closed", false)
		SyncAnims(inst, "open_pst")
	end
    inst.components.oceanwhirlportalphysics:SetEnabled(false)
end

local function SplashWhirlportal(inst, data)
    local doer = data and data.doer or nil
    if doer then
        local x, y, z = doer.Transform:GetWorldPosition()
        local fx_prefabs = GetSinkEntityFXPrefabs(doer, x, y, z)
        if fx_prefabs then
            for _, fx_prefab in pairs(fx_prefabs) do
                local fx = SpawnPrefab(fx_prefab)
                fx.Transform:SetPosition(x, y, z)
            end
        end
    end
end

local function OnFocalCooldownEnd(inst, ent)
    inst.focalcooldowns[ent] = nil
end

local function OnEntityTouchingFocalFn(inst, ent)
    if inst.focalcooldowns[ent] then
        return
    end
    if inst.components.wateryprotection then
        inst.components.wateryprotection:ApplyProtectionToEntity(ent)
    end
    if ent:IsValid() then -- In case applying water protection deletes it.
        if not inst.components.worldmigrator:Activate(ent) then
            if ent:HasTag("boat") and ent.components.health then
                if not ent.components.health:IsDead() then
                    ent.components.health:SetPercent(math.max(ent.components.health:GetPercent() - TUNING.OCEANWHIRLBIGPORTAL_BOAT_PERCENT_DAMAGE_PER_TICK), 0)
                    if ent.components.health:IsDead() then
                        ent:InstantlyBreakBoat()
                    else
                        if ent.sounds and ent.sounds.damage then
                            ent.SoundEmitter:PlaySoundWithParams(ent.sounds.damage, {intensity = 1})
                        end
                    end
                end
            else
                inst.components.oceanwhirlportalphysics:ForgetEntity(ent)
                SinkEntity(ent)
            end
        else
            inst.focalcooldowns[ent] = inst:DoTaskInTime(3, inst.OnFocalCooldownEnd, ent)
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

    inst.AnimState:SetBuild("whirlbigportal")
    inst.AnimState:SetBank("whirlbigportal")
    inst.AnimState:PlayAnimation("closed")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_WHIRLPORTAL)
    inst.AnimState:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)
	inst.AnimState:Hide("mid")
	inst.AnimState:Hide("deep")

    inst.MiniMapEntity:SetIcon("oceanwhirlbigportal.png")
    inst.MiniMapEntity:SetPriority(-2)

    inst:AddTag("birdblocker")
    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("oceanwhirlportal")
    inst:AddTag("oceanwhirlbigportal") -- for messagebottlemanager.lua
    inst:AddTag("NOCLICK")

    inst:SetDeployExtraSpacing(TUNING.OCEANWHIRLBIGPORTAL_RADIUS)

    inst.highlightoverride = {0.1, 0.1, 0.3}
    inst.scrapbook_inspectonseen = true

	inst.syncanims = net_event(inst.GUID, "oceanwhirlbigportal.syncanims")

	if not TheNet:IsDedicated() then
		inst.animlayers =
		{
			AddAnimLayer(inst, "mid", -1),
			AddAnimLayer(inst, "deep", -2),
		}

        if TheWorld.components.wavemanager then
            -- Client
            inst:ListenForEvent("onremove", OnRemove_Client)
            -- Server + Not Dedicated
            inst:ListenForEvent("entitywake", CheckToggleWaveBlocker)
            inst:ListenForEvent("entitysleep", CheckToggleWaveBlocker)
        end
	end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("oceanwhirlbigportal.syncanims", OnSyncAnims)

        return inst
    end

    inst.scrapbook_anim = "open_loop"
    --inst.scrapbook_scale = 1.5
    --inst.scrapbook_animoffsetx = 30
    --inst.scrapbook_animoffsety = -10
    --inst.scrapbook_animoffsetbgx = 80
    --inst.scrapbook_animoffsetbgy = 40

    inst.focalcooldowns = {}
    inst.OnFocalCooldownEnd = OnFocalCooldownEnd

    local wateryprotection = inst:AddComponent("wateryprotection")
    wateryprotection.extinguishheatpercent = TUNING.OCEANWHIRLPORTAL_EXTINGUISH_HEAT_PERCENT
    wateryprotection.temperaturereduction = TUNING.OCEANWHIRLPORTAL_TEMP_REDUCTION
    wateryprotection.witherprotectiontime = TUNING.OCEANWHIRLPORTAL_PROTECTION_TIME
    wateryprotection.addcoldness = TUNING.OCEANWHIRLPORTAL_ADD_COLDNESS
    wateryprotection.addwetness = TUNING.OCEANWHIRLPORTAL_ADD_WETNESS
    wateryprotection.applywetnesstoitems = true

    local oceanwhirlportalphysics = inst:AddComponent("oceanwhirlportalphysics")
    oceanwhirlportalphysics:SetFocalRadius(TUNING.OCEANWHIRLBIGPORTAL_FOCALRADIUS)
    oceanwhirlportalphysics:SetRadius(TUNING.OCEANWHIRLBIGPORTAL_RADIUS)
    oceanwhirlportalphysics:SetPullStrength(TUNING.OCEANWHIRLBIGPORTAL_PULLSTRENGTH)
    oceanwhirlportalphysics:SetRadialStrength(TUNING.OCEANWHIRLBIGPORTAL_RADIALSTRENGTH)
    oceanwhirlportalphysics:SetOnEntityTouchingFocalFn(OnEntityTouchingFocalFn)

    inst.OnRemoveEntity = OnRemoveEntity

    local worldmigrator = inst:AddComponent("worldmigrator")
    worldmigrator.shard_name = "Caves" -- SERVER_LEVEL_SHARDS
    worldmigrator:SetID("oceanwhirlbigportal")
    worldmigrator:SetHideActions(true)
    inst.OpenWhirlportal = OpenWhirlportal
    inst.OpenWhirlportal_finalize = OpenWhirlportal_finalize
    inst.CloseWhirlportal = CloseWhirlportal
    inst.SplashWhirlportal = SplashWhirlportal
    inst:ListenForEvent("migration_available", inst.OpenWhirlportal)
    inst:ListenForEvent("migration_unavailable", inst.CloseWhirlportal)
    inst:ListenForEvent("migration_full", inst.CloseWhirlportal)
    inst:ListenForEvent("migration_activate", inst.SplashWhirlportal)

    return inst
end

------------------------------------------------------------------------------------

local assets_exit = {
    Asset("ANIM", "anim/bigwaterfall.zip"),
    Asset("ANIM", "anim/moonglass_bigwaterfall_steam.zip"),
    Asset("ANIM", "anim/flotsam_pickable.zip"),
}

local function makewaterfall(proxy)
    if not proxy then
        return nil
    end

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]

    local parent = proxy.entity:GetParent()
    if parent ~= nil then
        inst.entity:SetParent(parent.entity)
    end

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.AnimState:SetBuild("bigwaterfall")
    inst.AnimState:SetBank("bigwaterfall")
    inst.AnimState:PlayAnimation("idle", true)

    proxy:ListenForEvent("onremove", function() inst:Remove() end)

    return inst
end
local function makebigmist(proxy)
    if not proxy then
        return nil
    end

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    --[[Non-networked entity]]

    local parent = proxy.entity:GetParent()
    if parent ~= nil then
        inst.entity:SetParent(parent.entity)
    end

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.Transform:SetFromProxy(proxy.GUID)
    inst.Follower:SetOffset(0, 5, 0)

    inst.AnimState:SetBuild("moonglass_bigwaterfall_steam")
    inst.AnimState:SetBank("moonglass_bigwaterfall_steam")
    inst.AnimState:PlayAnimation("steam_small"..math.random(1,2), true)
    inst.AnimState:SetLightOverride(0.5)
    inst.AnimState:SetFinalOffset(2)

    proxy:ListenForEvent("onremove", function() inst:Remove() end)

    return inst
end
local function makeflotsam_pool(proxy)
    if not proxy then
        return nil
    end

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]

    local parent = proxy.entity:GetParent()
    if parent ~= nil then
        inst.entity:SetParent(parent.entity)
    end

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.AnimState:SetBuild("flotsam_pickable")
    inst.AnimState:SetBank("flotsam_pickable")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:PlayAnimation("puddle", true)

    proxy:ListenForEvent("onremove", function() inst:Remove() end)

    return inst
end

local function initclientfx(inst)
    makewaterfall(inst)
    makebigmist(inst)
    makeflotsam_pool(inst)
    TheWorld:PushEvent("ms_registergrottopool", {pool = inst, small = false}) -- Register into the waterfall sound system.
end



local function GiveLoot(inst, picker, item)
    if picker.components.inventory and picker.components.inventory:IsOpenedBy(picker) then
        picker.components.inventory:GiveItem(item, nil, inst:GetPosition())
    else
        inst.components.lootdropper:FlingItem(item)
    end
end

local FLOTSAM_SIZES = {
    [1] = "empty",
    [2] = "small",
    [3] = "big",
}
local function GetAnimIndex(inst)
    local numberofitems = inst.components.itemstore:GetNumberOfItems()
    local animindex = 1
    if numberofitems >= TUNING.OCEANWHILRBIGPORTALEXIT_ITEMS_TO_MAKE_BIG then
        animindex = 3
    elseif numberofitems > 0 then
        animindex = 2
    end
    return animindex
end
local function GetAnim(inst)
    local animindex = GetAnimIndex(inst)
    local anim = FLOTSAM_SIZES[animindex]
    return anim
end
local function onpickedfn(inst, picker, loot)
    local items = inst.components.itemstore:GetFirstItems(TUNING.OCEANWHILRBIGPORTALEXIT_LOOT_PER_PICK)
    if items[1] then
        local anim = GetAnim(inst)
        if anim ~= FLOTSAM_SIZES[1] and inst.AnimState:IsCurrentAnimation(anim .. "_idle") then
            inst.AnimState:PlayAnimation(anim .. "_jiggle", false)
            inst.AnimState:PushAnimation(anim .. "_idle", true)
        end
        for _, item in ipairs(items) do
            inst:GiveLoot(picker, item)
        end
    end
end
local function OnItemStoreChangedCount(inst)
    local anim = GetAnim(inst)
    inst.components.pickable.caninteractwith = anim ~= FLOTSAM_SIZES[1]
    inst.AnimState:PlayAnimation(anim .. "_idle", true)
end
local function fn_exit()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("oceanwhirlbigportalexit.png")

    inst.AnimState:SetBuild("flotsam_pickable")
    inst.AnimState:SetBank("flotsam_pickable")
    inst.AnimState:SetFinalOffset(1)
    inst.AnimState:PlayAnimation(FLOTSAM_SIZES[1] .. "_idle", true)

    inst:AddTag("pickable_rummage_str")

    if not TheNet:IsDedicated() then
        inst:DoTaskInTime(0, initclientfx)
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "big_idle"

    local worldmigrator = inst:AddComponent("worldmigrator")
    worldmigrator.shard_name = "Master" -- SERVER_LEVEL_SHARDS
    worldmigrator:SetID("oceanwhirlbigportal")
    worldmigrator:SetEnabled(false) -- Always closed, one way.

    inst:AddComponent("inspectable")

    local pickable = inst:AddComponent("pickable")
    pickable.picksound = "dontstarve/wilson/pickup_reeds"
    pickable.onpickedfn = onpickedfn
    pickable.caninteractwith = false
    pickable.donotsavecaninteractwithstate = true
    pickable:SetUp(nil, 0)

    inst:AddComponent("lootdropper")
    inst.GiveLoot = GiveLoot

    inst:AddComponent("itemstore")
    inst:ListenForEvent("itemstore_changedcount", OnItemStoreChangedCount)

    return inst
end

return Prefab("oceanwhirlbigportal", fn, assets, prefabs),
    Prefab("oceanwhirlbigportalexit", fn_exit, assets_exit)

-- NOTES(JBK): Search terms: "oceanwhirlbigpool", "whirlbigpool",
