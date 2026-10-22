local assets =
{
    Asset("ANIM", "anim/king_cane.zip"),
    Asset("SCRIPT", "scripts/prefabs/staff_common.lua"),
    Asset("INV_IMAGE", "king_cane_redgem"),
    Asset("INV_IMAGE", "king_cane_bluegem"),
    Asset("INV_IMAGE", "king_cane_purplegem"),
    Asset("INV_IMAGE", "king_cane_yellowgem"),
    Asset("INV_IMAGE", "king_cane_orangegem"),
    Asset("INV_IMAGE", "king_cane_greengem"),
}

local prefabs =
{
    "king_cane_fx",
}

local easing = require("easing")

local staff_common = require("prefabs/staff_common")
local stafffns = staff_common.fns

for gem, gemprefabs in pairs(staff_common.prefabs) do
    if gem ~= "opal" then
        for i, prefab in ipairs(gemprefabs) do
            if not table.contains(prefabs, prefab) then
                table.insert(prefabs, prefab)
            end
        end
    end
end

local function UpdateFxLevel(inst, current)
    inst.fx:SetFXLevel(
        current >= TUNING.KING_CANE_CORRUPTION_HIGH and 3 or
        current >= TUNING.KING_CANE_CORRUPTION_MED and 2 or
        current >= TUNING.KING_CANE_CORRUPTION_LOW and 1 or
        0
    )
end

local function SetFxOwner(inst, owner)
    if inst._fxowner ~= nil and inst._fxowner.components.colouradder ~= nil then
        inst._fxowner.components.colouradder:DetachChild(inst.fx)
        inst.fx.components.colouraddersync:SyncColour(0, 0, 0, 0) -- detach child doesnt sync color
    end

    inst._fxowner = owner

    if owner ~= nil then
        local followsym = owner.prefab == "moonbase" and "follow_king_cane" or "swap_object"
        inst.fx.entity:SetParent(owner.entity)
        inst.fx.Follower:FollowSymbol(owner.GUID, followsym, nil, nil, nil, true)
        inst.fx.components.highlightchild:SetOwner(owner)

        if owner.components.colouradder ~= nil then
            owner.components.colouradder:AttachChild(inst.fx)
        end
    else
        inst.fx.entity:SetParent(inst.entity)
        -- For floating.
        inst.fx.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true)
        inst.fx.components.highlightchild:SetOwner(inst)
    end
end

local function fx_OnChangeHighlightOwner(inst, owner) -- inst is the fx here
    -- piggybacking off highlightchild owner networking to change corruptfx and gemfx
    if not TheNet:IsDedicated() then
        -- note: can't check prefab name because this can be called during construction, so checking netvar existence instead
        local followguid = (owner._gem ~= nil and owner or inst).GUID
        inst.corruptfx.Follower:FollowSymbol(followguid, "follow", nil, nil, nil, true)
        inst.gemfx.Follower:FollowSymbol(followguid, "swap_gem", nil, nil, nil, true)
        inst.gemfx.components.highlightchild:SetOwner(owner)
    end
end

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_king_cane", inst.GUID, "king_cane")
    else
        owner.AnimState:OverrideSymbol("swap_object", "king_cane", "swap_king_cane")
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    SetFxOwner(inst, owner)
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    SetFxOwner(inst, nil)
end

local function GetGemId(gemtype)
    return string.sub(gemtype, 0, -4)
end

local function ItemTradeTest(inst, item)
    if item == nil then
        return false
    elseif string.sub(item.prefab, -11, -4) == "precious" then
        return false, "WRONGGEM"
    elseif not stafffns[GetGemId(item.prefab)] or not item:HasTag("gem") then
        return false, "NOTGEM"
    end
    return true
end

local function OnDischarged(inst)
    inst:AddTag("nomagiccast")
    inst._removetag = (inst:HasTag("rangedlighter") and "rangedlighter") or (inst:HasTag("extinguisher") and "extinguisher")
    if inst._removetag then
        inst:RemoveTag(inst._removetag)
    end
end

local function OnCharged(inst)
    inst:RemoveTag("nomagiccast")
    if inst._removetag then
        inst:AddTag(inst._removetag)
        inst._removetag = nil
    end
end

local function OnGemDirty(inst)
    staff_common.cleargemstaff_client(inst)
    local clientfn = stafffns[GetGemId(inst._gem:value()).."_client"]
    if clientfn then
        clientfn(inst)
    end

    local inventoryitem = inst.replica.inventoryitem
	local playercontroller = ThePlayer and ThePlayer.components.playercontroller
	if playercontroller and ThePlayer.replica.inventory and inventoryitem and inventoryitem:IsGrandOwner(ThePlayer) then
        playercontroller:RefreshReticule(inst)
    end
end

local function SetGem(inst, gemtype)
    -- reset hauntable
    inst:RemoveComponent("hauntable")
    MakeHauntableLaunch(inst)

    inst.gem = gemtype
    inst._gem:set(gemtype)
    if not TheNet:IsDedicated() then
        OnGemDirty(inst)
    end
    stafffns[GetGemId(gemtype)](inst, true)

    local iscorrupted = inst.components.corruption:IsCorrupted()

    if inst.components.blinkstaff then
        local blinksound = iscorrupted and "dontstarve/common/staff_blink_corrupted" or "dontstarve/common/staff_blink_kingcane"
        inst.components.blinkstaff:SetSoundFX(blinksound, blinksound)
    end

    inst.castsound = "dontstarve/wilson/use_kingcane"
    inst.castsoundparams = { corrupted = iscorrupted and 0.5 or 0 }
    inst.components.inventoryitem:ChangeImageName("king_cane_"..inst.gem)
    inst.fx:SetGemType(gemtype)
end

local function OnGemGiven(inst, giver, item)
    if inst.gem then
        staff_common.cleargemstaff(inst)

        local x, y, z = (giver or inst).Transform:GetWorldPosition()
        local oldgem = SpawnPrefab(inst.gem)
        if giver and giver.components.inventory then
            giver.components.inventory:GiveItem(oldgem, nil, Vector3(x, y, z))
        else
            oldgem.components.inventoryitem:DoDropPhysics(x, y, z, true)
        end
    end
    SetGem(inst, item.prefab)
    inst.SoundEmitter:PlaySound("dontstarve/common/telebase_gemplace")
end

local function OnCorruptedFn(inst)
    if inst.components.blinkstaff then
        inst.components.blinkstaff:SetSoundFX("dontstarve/common/staff_blink_corrupted", "dontstarve/common/staff_blink_corrupted")
    end
    inst.castsoundparams = { corrupted = 0.5 }
    inst:AddTag("shadow_item")
    inst.dodischarge = true
    inst:AddComponent("shadowdominance")
    inst.components.trader:Disable()
    UpdateFxLevel(inst, TUNING.KING_CANE_CORRUPTION_HIGH)
end

local function OnUncorruptedFn(inst)
    inst.castsoundparams = { corrupted = 0 }
    inst:RemoveTag("shadow_item")
    inst.dodischarge = false
    inst:RemoveComponent("shadowdominance")
    inst.components.trader:Enable()
    inst.components.rechargeable:Discharge(1)
    UpdateFxLevel(inst, 0)
end

local function OnCorruptionCurrentFn(inst, current)
    UpdateFxLevel(inst, current)
    inst:AddOrRemoveTag("shadow_item", current >= TUNING.KING_CANE_CORRUPTION_LOW)
end

local function DoCorruption(inst)
    inst.components.corruption:DoDelta(TUNING.KING_CANE_CORRUPTION[inst.gem])
end

local function DoGemShine(inst)
    inst.fx:DoGemShine()
end

local function GetDappernessFn(inst)
    local corruption = inst.components.corruption:GetCurrent()
    return (corruption >= TUNING.KING_CANE_CORRUPTION_HIGH and TUNING.CRAZINESS_MED)
        or (corruption >= TUNING.KING_CANE_CORRUPTION_MED and TUNING.CRAZINESS_SMALL)
        or (corruption >= TUNING.KING_CANE_CORRUPTION_LOW and TUNING.CRAZINESS_TINY)
        or 0
end

local function GetStatus(inst)--, viewer)
    return (inst.gem == nil and "EMPTY")
end

local function OnSave(inst, data)
    data.gem = inst.gem
end

local function OnPreLoad(inst, data) -- before rechargeable component is added
    if data then
        if data.gem then
            SetGem(inst, data.gem)
        end
    end
end

-----------------

local function OnStopFloating(inst)
    inst.fx.AnimState:SetFrame(0)
end

local SWAP_FLOATING_DATA = { sym_build = "king_cane", bank = "king_cane", anim = "idle" }
local FLOATER_SCALE = { 1.75, 1, 1 }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("king_cane")
    inst.AnimState:SetBuild("king_cane")
    inst.AnimState:PlayAnimation("idle")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")
	--rechargeable (from rechargeable component) added to pristine state for optimization
	inst:AddTag("rechargeable")
	--shadowlevel (from shadowlevel component) added to pristine state for optimization
	inst:AddTag("shadowlevel")
    --trader (from trader component) added to pristine state for optimization
    inst:AddTag("trader")
	inst:AddTag("give_dolongaction")
    inst:AddTag("gemsocket")

    inst:AddComponent("floater")
    inst.components.floater:SetBankSwapOnFloat(true, -32, SWAP_FLOATING_DATA)
    inst.components.floater:SetSize("med")
    inst.components.floater:SetVerticalOffset(0.1)
    inst.components.floater:SetScale(FLOATER_SCALE)
    inst.components.floater.bob_percent = 0 -- coz it looks weird with how each individual symbol bobs seperately.

    inst.projectiledelay = FRAMES -- only ice staff and fire staff need this

    inst._gem = net_string(inst.GUID, "king_cane_fx.gem", "gemdirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("gemdirty", OnGemDirty)
        return inst
    end

    inst.scrapbook_subcat = "tool"
    inst.scrapbook_removedeps = { "cutgrass" }

    -----------------------------------------------------------

    -- Follow symbol FX initialization.
    local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
    inst.AnimState:SetFrame(frame)
    -- one networked fx for frame 3 (needed for floating)
    --  all other frames will be spawned locally client-side by this fx.
    inst.fx = SpawnPrefab("king_cane_fx")
    inst.fx.AnimState:SetFrame(frame)
	SetFxOwner(inst, nil)
    inst:ListenForEvent("floater_stopfloating", OnStopFloating)

    -----------------------------------------------------------

    inst.notlightningteleport = true
    inst.dodischarge = false

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetDappernessFn(GetDappernessFn)
    inst.components.equippable.is_magic_dapperness = true
    inst.components.equippable.walkspeedmult = TUNING.KING_CANE_SPEED_MULT

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.KING_CANE_DAMAGE)

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnDischargedFn(OnDischarged)
    inst.components.rechargeable:SetOnChargedFn(OnCharged)

	inst:AddComponent("shadowlevel")
	inst.components.shadowlevel:SetDefaultLevel(TUNING.KING_CANE_SHADOW_LEVEL)

    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(ItemTradeTest)
    inst.components.trader:SetOnAccept(OnGemGiven)
    inst.components.trader.deleteitemonaccept = true

    inst:AddComponent("tradable") -- for moonbase
    inst:AddComponent("stalkerinspectable")
    ---
    inst:AddComponent("corruption")
    inst.components.corruption:SetOnCurrentFn(OnCorruptionCurrentFn)
    inst.components.corruption:SetOnCorruptedFn(OnCorruptedFn)
    inst.components.corruption:SetOnUncorruptedFn(OnUncorruptedFn)

    inst:ListenForEvent("onspellcast", DoCorruption)
    inst:ListenForEvent("onblink", DoCorruption)
    inst:ListenForEvent("weapononprojectilelaunched", DoCorruption)

    MakeHauntableLaunch(inst)

    inst.DoGemShine = DoGemShine
    inst.SetFxOwner = SetFxOwner -- for moonbase
    inst.OnSave = OnSave
    inst.OnPreLoad = OnPreLoad

    return inst
end

-------------------------

local function fx_OnGemShineDirty(inst)
    local parent = inst.entity:GetParent()
    if parent then
        if parent.isplayer then
            if parent.AnimState:IsCurrentAnimation("staff_pre") then
                inst.gemfx:Shine()
            elseif parent.AnimState:IsCurrentAnimation("atk_pre") or parent.AnimState:IsCurrentAnimation("player_atk_pre")
                or parent.AnimState:IsCurrentAnimation("atk") or parent.AnimState:IsCurrentAnimation("player_atk") then
                inst.gemfx:QuickShine()
            end
        else -- We got here through haunting probably.
            inst.gemfx:QuickShine()
        end
    end
end

local function fx_DoGemShine(inst)
    inst.gemshine:push()
    if not TheNet:IsDedicated() then
        fx_OnGemShineDirty(inst)
    end
end

local function fx_OnGemFxDirty(inst)
    local gemtype = inst.gem:value()
    if gemtype ~= "" then
        inst.gemfx.AnimState:OverrideSymbol("swap_gem", "king_cane", "swap_"..gemtype)
    else
        inst.gemfx.AnimState:ClearOverrideSymbol("swap_gem")
    end
end

local function fx_SetGemType(inst, gemtype)
    if gemtype ~= inst.gem:value() then
        inst.gem:set(gemtype)
        if not TheNet:IsDedicated() then
            fx_OnGemFxDirty(inst)
        end
    end
end

local function CreateCorruptionFX()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("king_cane")
	inst.AnimState:SetBuild("king_cane")
	inst.AnimState:PlayAnimation("corrupt_level1", true)

    inst:Hide()
	inst.persists = false

	return inst
end

local function fx_OnColourChanged(inst, r, g, b, a)
    inst.corruptfx.AnimState:SetAddColour(r, g, b, a)
    inst.gemfx.AnimState:SetAddColour(r, g, b, a)
end

local function fx_OnFXLevelDirty(inst)
    local val = inst.level:value()
    if val == 0 then
        inst.corruptfx:Hide()
    else
        inst.corruptfx:Show()
        inst.corruptfx.AnimState:PlayAnimation("corrupt_level"..tostring(inst.level:value()), true)
    end
end

local function fx_SetFXLevel(inst, level)
    if level ~= inst.level:value() then
        inst.level:set(level)
        if not TheNet:IsDedicated() then
            fx_OnFXLevelDirty(inst)
        end
    end
end

local gem_StopUpdatingLightOverride
local function gem_UpdateLightOverride(inst)
    if inst.AnimState:IsCurrentAnimation("cast_gem") then
        local frame = inst.AnimState:GetCurrentAnimationFrame()
        inst.AnimState:SetLightOverride(
            (frame >= 48 and (1 - easing.inQuad(frame - 48, 0, 1, 58 - 48))) or
            (frame >= 23 and 1) or
            (frame >= 12 and easing.outQuart(frame - 12, 0, 1, 22 - 12)) or
            0
        )
    elseif inst.AnimState:IsCurrentAnimation("quickcast_gem") then
        local frame = inst.AnimState:GetCurrentAnimationFrame()
        inst.AnimState:SetLightOverride(
            (frame >= 13 and (1 - easing.inQuad(frame - 13, 0, 1, 17 - 13))) or
            (frame >= 8 and 1) or
            (frame >= 4 and easing.outQuart(frame - 4, 0, 1, 7 - 4)) or
            0
        )
    else
        inst.AnimState:SetLightOverride(0)
        gem_StopUpdatingLightOverride(inst)
    end
end

local function gem_StartUpdatingLightOverride(inst)
	if not inst.isupdatinglightoverride then
		inst.isupdatinglightoverride = true
        inst.components.updatelooper:AddPostUpdateFn(gem_UpdateLightOverride)
    end
end

gem_StopUpdatingLightOverride = function(inst)
    if inst.isupdatinglightoverride then
        inst.isupdatinglightoverride = nil
        inst.components.updatelooper:RemovePostUpdateFn(gem_UpdateLightOverride)
    end
end

local function gem_Shine(inst)
    inst.AnimState:PlayAnimation("cast_gem")
    inst.AnimState:PushAnimation("idle_gem", true)
    gem_StartUpdatingLightOverride(inst)
end

local function gem_QuickShine(inst)
    inst.AnimState:PlayAnimation("quickcast_gem")
    inst.AnimState:PushAnimation("idle_gem", true)
    gem_StartUpdatingLightOverride(inst)
end

local function CreateGemFX()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("king_cane")
	inst.AnimState:SetBuild("king_cane")
	inst.AnimState:PlayAnimation("idle_gem", true)

	inst:AddComponent("highlightchild")
	inst:AddComponent("updatelooper")

    inst.Shine = gem_Shine
    inst.QuickShine = gem_QuickShine

	return inst
end

local function fx_OnEntityReplicated(inst)
    local owner = inst.entity:GetParent()
    if owner ~= nil then
        fx_OnChangeHighlightOwner(inst, owner)
    end
end

local function fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

	inst.AnimState:SetBank("king_cane")
    inst.AnimState:SetBuild("king_cane")
    inst.AnimState:PlayAnimation("swap_loop1", true)

    inst:AddComponent("highlightchild")
    inst.components.highlightchild:SetOnChangeOwnerFn(fx_OnChangeHighlightOwner)
	inst:AddComponent("colouraddersync")

    inst.gemshine = net_event(inst.GUID, "king_cane_fx.gemshine")
    inst.level = net_tinybyte(inst.GUID, "king_cane_fx.level", "leveldirty")
    inst.level:set(0)
    inst.gem = net_string(inst.GUID, "king_cane_fx.gem", "gemdirty")

    if not TheNet:IsDedicated() then
		inst.corruptfx = CreateCorruptionFX()
		inst.corruptfx.entity:SetParent(inst.entity)
		inst.corruptfx.Follower:FollowSymbol(inst.GUID, "follow", nil, nil, nil, true)

        inst.gemfx = CreateGemFX()
        inst.gemfx.entity:SetParent(inst.entity)
		inst.gemfx.Follower:FollowSymbol(inst.GUID, "swap_gem", nil, nil, nil, true)
		inst.components.colouraddersync:SetColourChangedFn(fx_OnColourChanged)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = fx_OnEntityReplicated
        inst:ListenForEvent("gemdirty", fx_OnGemFxDirty)
        inst:ListenForEvent("leveldirty", fx_OnFXLevelDirty)
        inst:ListenForEvent("king_cane_fx.gemshine", fx_OnGemShineDirty)
        return inst
    end

    inst.DoGemShine = fx_DoGemShine
    inst.SetGemType = fx_SetGemType
    inst.SetFXLevel = fx_SetFXLevel
    inst.persists = false

    return inst
end

return Prefab("king_cane", fn, assets, prefabs),
    Prefab("king_cane_fx", fxfn, assets)
