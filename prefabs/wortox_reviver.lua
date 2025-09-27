local assets = {
    Asset("ANIM", "anim/wortox_reviver.zip"),
    Asset("ANIM", "anim/swap_wortox_reviver.zip"),
    Asset("INV_IMAGE", "wortox_reviver"),
    Asset("INV_IMAGE", "wortox_reviver_unpaired"),
}

local prefabs = {
    "wortox_soul",
    "wortox_teleport_reviver_top",
    "wortox_teleport_reviver_bottom",
    "wortox_reviver_body",
}

local CACHED_WORTOX_REVIVER_RECIPE_COST = nil
local function CacheWortoxReviverRecipeCost(default)
    local recipe = AllRecipes.wortox_reviver

    if recipe == nil or recipe.ingredients == nil then
        return default
    end

    local needed = 0
    for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "wortox_soul" then
            needed = needed + ingredient.amount
        end
    end

    return needed > 0 and needed or default
end

local function TryToAttachWortoxID(inst, owner)
    if owner == nil or owner.is_snapshot_user_session then
        return
    end
    local linkeditem = inst.components.linkeditem
    if linkeditem == nil or linkeditem:GetOwnerUserID() ~= nil then
        return
    end

    if owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wortox_lifebringer_1") then
        linkeditem:LinkToOwnerUserID(owner.userid)
    end
end

local function OnPutInInventory(inst, owner)
    inst:TryToAttachWortoxID(owner)
end

local function OnBuiltFn(inst, builder)
    inst:TryToAttachWortoxID(builder)
end

local function OnInitFromLoad(inst)
    local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or nil
    inst:TryToAttachWortoxID(owner)
end

local function OnLoad(inst, data)
    inst:DoTaskInTime(0, OnInitFromLoad)
end

local function SetAllowConsumption(inst, allow)
    if inst.components.spellcaster then
        inst.components.spellcaster:SetSpellType(not allow and SPELLTYPES.WORTOX_REVIVER_LOCK or nil)
    end
end

local function OnOwnerInstRemovedFn(inst, owner)
    inst:SetAllowConsumption(false)
end

local function OnSkillTreeInitializedFn(inst, owner)
    if owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wortox_lifebringer_3") then
        inst:SetAllowConsumption(true)
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end
local function SpellFn(inst, target, pos, caster)
    -- inst.components.rider ~= nil and inst.components.rider:IsRiding() kick off of mount before calling this state
    if not caster then
        return
    end

    local owner = inst.components.linkeditem and inst.components.linkeditem:GetOwnerInst() or nil
    if not owner then
        -- The owner left in between the time of starting the cast and the cast action perform.
        -- Do a wisecrack since the action was valid at the start.
        caster:PushEvent("wortox_reviver_failteleport")
        return
    end

    local caster_pos = caster:GetPosition()
    if owner == caster then
        -- Free the Souls.
        if caster.components.inventory then
            caster.wortox_ignoresoulcounts = true
            local scaled_count = math.ceil((inst.components.perishable and inst.components.perishable:GetPercent() or 1) * CACHED_WORTOX_REVIVER_RECIPE_COST)
            for i = 1, scaled_count do
                local soul = SpawnPrefab("wortox_soul")
                caster.components.inventory:DropItem(soul, true, true, caster_pos)
            end
            caster.wortox_ignoresoulcounts = nil
        end
        if caster.SoundEmitter then
            caster.SoundEmitter:PlaySound("meta5/wortox/twintailed_heart_release")
        end
        caster.sg:GoToState("wortox_teleport_reviver_selfuse", { item = inst, })
    else
        -- Go to owner.
        local owner_pos = owner:GetPosition()
        if not IsTeleportingPermittedFromPointToPoint(caster_pos.x, caster_pos.y, caster_pos.z, owner_pos.x, owner_pos.y, owner_pos.z) then
            -- No escaping from here.
            caster:PushEvent("wortox_reviver_failteleport")
            return
        end

        local offset
        for radius = 6, 1, -1 do
            offset = FindWalkableOffset(owner_pos, math.random() * TWOPI, radius, 8, true, true, NoHoles, false, true)
            if offset then
                owner_pos = owner_pos + offset
                break
            end
        end
        local platform = TheWorld.Map:GetPlatformAtPoint(owner_pos.x, owner_pos.z)
        local platformoffset
        if platform then
            platformoffset = platform:GetPosition() - owner_pos
        end
        local snapcamera = VecUtil_LengthSq(owner_pos.x - caster_pos.x, owner_pos.z - caster_pos.z) > PLAYER_CAMERA_SEE_DISTANCE_SQ
        caster.sg:GoToState("wortox_teleport_reviver", { dest = owner_pos, platform = platform, platformoffset = platformoffset, snapcamera = snapcamera, item = inst, })
    end
end

local function OnConsume(inst, owner)
    if inst.components.stackable ~= nil and inst.components.stackable:IsStack() then
        inst.components.stackable:Get():Remove()
    else
        inst:Remove()
    end
end

local function DisplayNameFn(inst)
    local ownername = inst.components.linkeditem:GetOwnerName()
    return ownername and subfmt(STRINGS.NAMES.WORTOX_REVIVER_FMT, { name = ownername }) or nil
end

local function OnPerish(inst)
    local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    local soul = SpawnPrefab("wortox_soul")
    if owner then
        if owner.components.inventory then
            owner.wortox_ignoresoulcounts = true
            owner.components.inventory:DropItem(soul, true, true, owner:GetPosition())
            owner.wortox_ignoresoulcounts = nil
        else
            local x, y, z = owner.Transform:GetWorldPosition()
            soul.Transform:SetPosition(x, y, z)
        end
        -- Just remove.
        inst:Remove()
    else
        local x, y, z = inst.Transform:GetWorldPosition()
        soul.Transform:SetPosition(x, y, z)
        -- Fade out.
        inst.persists = false
        if inst.components.inventoryitem then
            inst.components.inventoryitem.canbepickedup = false
        end
        inst.AnimState:PlayAnimation("fallteleport")
        inst:ListenForEvent("animover", inst.Remove)
    end
end

local function OnRemove_Body(wortox_reviver_body)
    wortox_reviver_body.wortox_reviver.wortox_reviver_body = nil
end
local function OnStartBody(inst, owner)
    if inst.wortox_reviver_body ~= nil then
        inst.wortox_reviver_body:Remove()
    end
    inst.wortox_reviver_body = SpawnPrefab("wortox_reviver_body")
    inst.wortox_reviver_body.wortox_reviver = inst
    inst:ListenForEvent("onremove", OnRemove_Body, inst.wortox_reviver_body)
    inst.wortox_reviver_body.entity:SetParent(owner.entity)
    inst.wortox_reviver_body.entity:AddFollower()
    inst.wortox_reviver_body.Follower:FollowSymbol(owner.GUID, "swap_remote", 25, -42, 0)
end
local function OnStopBody(inst, owner)
    if inst.wortox_reviver_body ~= nil then
        inst.wortox_reviver_body:Remove()
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wortox_reviver")
    inst.AnimState:SetBuild("wortox_reviver")
    inst.AnimState:PlayAnimation("idle", true)

    inst:AddTag("reviver")
    inst:AddTag("show_spoilage")
    inst:AddTag("crushitemcast")
    inst.spelltype = "SQUEEZE"
    inst:AddTag(SPELLTYPES.WORTOX_REVIVER_LOCK .. "_spellcaster") -- Network optimization from spellcaster:SetSpellType sneak into pristine state.

    local linkeditem = inst:AddComponent("linkeditem")
    inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
    if CACHED_WORTOX_REVIVER_RECIPE_COST == nil then
        CACHED_WORTOX_REVIVER_RECIPE_COST = CacheWortoxReviverRecipeCost(10)
    end
    inst.swap_build = "swap_wortox_reviver"
    inst.swap_symbol = "swap_wortox_reviver"
    inst.OnStartBody = OnStartBody
    inst.OnStopBody = OnStopBody
    inst.OnConsume = OnConsume
    inst.OnBuiltFn = OnBuiltFn
    inst.OnLoad = OnLoad
    inst.SetAllowConsumption = SetAllowConsumption
    inst.TryToAttachWortoxID = TryToAttachWortoxID
    inst.crushitemcast_sound = "meta5/wortox/ttheart_in_f18"

    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
    inventoryitem:SetSinks(true)

    inst:AddComponent("inspectable")
    inst:AddComponent("tradable")

    local perishable = inst:AddComponent("perishable")
    perishable:SetPerishTime(TUNING.SKILLS.WORTOX.REVIVE_PERISH_TIME)
    perishable:StartPerishing()
    perishable:SetOnPerishFn(OnPerish)

    local spellcaster = inst:AddComponent("spellcaster")
    spellcaster:SetSpellFn(SpellFn)
    spellcaster.canuseontargets = true
    spellcaster.canusefrominventory = true
    spellcaster.canonlyuseonlocomotorspvp = true
    inst:SetAllowConsumption(false)

    MakeHauntableLaunch(inst)

    linkeditem:SetOnOwnerInstRemovedFn(OnOwnerInstRemovedFn)
    linkeditem:SetOnSkillTreeInitializedFn(OnSkillTreeInitializedFn)

    return inst
end

local function bodyfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("wortox_reviver")
    inst.AnimState:SetBuild("wortox_reviver")
    inst.AnimState:PlayAnimation("idle_body", true)
    inst.AnimState:SetFinalOffset(1)

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("wortox_reviver", fn, assets, prefabs),
    Prefab("wortox_reviver_body", bodyfn, assets)
