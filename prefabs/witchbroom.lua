local assets =
{
    Asset("ANIM", "anim/witchbroom.zip"),
    Asset("ANIM", "anim/witchbroom_living_build.zip"),
    Asset("INV_IMAGE", "witchbroom_living"),
}

local prefabs =
{
    "witchbroom_fx",
}

local function OnEquip(inst, owner)
    local build = inst.living and "witchbroom_living_build" or "witchbroom"
    owner.AnimState:OverrideSymbol("swap_object", build, "swap_witchbroom")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    if inst._fx ~= nil then
    	inst._fx:Remove()
    end
    if inst.living then
        inst._fx = SpawnPrefab("witchbroom_fx")
        inst._fx.entity:SetParent(owner.entity)
    end

    if inst._onlocomote then -- living one sets this
        if inst._owner ~= nil then
            inst:RemoveEventCallback("locomote", inst._onlocomote, inst._owner)
        end
        inst._owner = owner
        inst:ListenForEvent("locomote", inst._onlocomote, owner)
    end
end

local function OnUnequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    if inst._fx ~= nil then
        inst._fx:Remove()
        inst._fx = nil
    end
    if inst._owner ~= nil then
        inst:RemoveEventCallback("locomote", inst._onlocomote, inst._owner)
        inst._owner = nil
        if inst._consumingtask then
            inst._consumingtask:Cancel()
            inst._consumingtask = nil
        end
    end
end

local function OnEquipToModel(inst)
    if inst._fx ~= nil then
        inst._fx:Remove()
        inst._fx = nil
    end
end

local function OnConsumeFueled(inst) -- not real fuel, fake fuel
    inst.components.finiteuses:Use(TUNING.WITCHBROOM_LOCOMOTE_WEAR)
end

local function OnSmashed(inst)
    inst.components.finiteuses:Use(TUNING.WITCHBROOM_WEAPON_ATTACKWEAR)
    inst.SoundEmitter:PlaySound(inst.components.sweeper.sweepsound)
end

local FLOATER_LIVING_SWAP_DATA = { sym_build = "witchbroom_living_build", sym_name = "swap_witchbroom" }
local function SetLiving(inst)
    inst.living = true
    inst:AddTag("flyingbroom")
    inst.AnimState:SetBuild("witchbroom_living_build")
    inst.components.inventoryitem:ChangeImageName("witchbroom_living")
    inst.components.equippable.walkspeedmult = TUNING.WITCHBROOM_LIVING_SPEED_MULT
    inst.components.floater:SetSwapData(FLOATER_LIVING_SWAP_DATA)

    inst._onlocomote = function(owner)
        if owner.components.locomotor:WantsToMoveForward() then
            if not inst._consumingtask then
                inst._consumingtask = inst:DoPeriodicTask(1, OnConsumeFueled, 1)
            end
        elseif inst._consumingtask then
            inst._consumingtask:Cancel()
            inst._consumingtask = nil
        end
    end
end

local function MakeLiving(inst)
    SetLiving(inst)
    inst.SoundEmitter:PlaySound("dontstarve/halloween_2018/living_tree/grow_1")
    inst.components.finiteuses:Repair(TUNING.WITCHBROOM_USES)

    local owner = inst.components.inventoryitem.owner
    if owner and inst.components.equippable:IsEquipped() then
        owner.AnimState:OverrideSymbol("swap_object", "witchbroom_living_build", "swap_witchbroom")
        if inst._fx == nil then
            inst._fx = SpawnPrefab("witchbroom_fx")
            inst._fx.entity:SetParent(owner.entity)
        end
        if inst._onlocomote then
            if inst._owner ~= nil then
                inst:RemoveEventCallback("locomote", inst._onlocomote, inst._owner)
            end
            inst._owner = owner
            inst:ListenForEvent("locomote", inst._onlocomote, owner)
        end
    end
end

local function GetStatus(inst)
    return (inst.living and "LIVING") or nil
end

local function OnSave(inst, data)
    data.living = inst.living
end

local function OnLoad(inst, data)
    if data and data.living then
        SetLiving(inst)
    end
end

local function DisplayNameFn(inst)
    return inst:HasTag("flyingbroom") and STRINGS.NAMES.WITCHBROOM_LIVING or nil
end

-------------------------

local FLOATER_SCALE = { 1.25, 0.5, 1.25 }
local FLOATER_SWAP_DATA = { sym_build = "witchbroom", sym_name = "swap_witchbroom" }
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("witchbroom")
    inst.AnimState:SetBuild("witchbroom")
    inst.AnimState:PlayAnimation("idle")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")
    inst:AddTag("propweapon")
    inst:AddTag("propweapon_nopvp")

    MakeInventoryFloatable(inst, "med", 0.05, FLOATER_SCALE, true, -15, FLOATER_SWAP_DATA)

    inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_subcat = "tool"

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnEquipToModel(OnEquipToModel)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.WITCHBROOM_USES)
    inst.components.finiteuses:SetUses(TUNING.WITCHBROOM_USES)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetConsumption(ACTIONS.SWEEP, 1)

    inst:AddComponent("weapon") -- the stategraph takes control and doesn't talk with the combat component, so the damage set here doesn't really work
    inst.components.weapon:SetDamage(1)

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

    inst:AddComponent("sweeper")
    inst.components.sweeper:SetSweepSound("yotr_2023/common/pillow_hit_petals")

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

    inst:ListenForEvent("propsmashed", OnSmashed)

    inst.MakeLiving = MakeLiving
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

---------

local fxassets =
{
    Asset("ANIM", "anim/witchbroom_trail.zip"),
}

local function trail_OnAnimOver(inst)
    if inst.owner and inst.owner:IsValid() and inst.owner.trail_pool then
        inst:RemoveFromScene()
        table.insert(inst.owner.trail_pool, inst)
    else
        inst:Remove()
    end
end

local function CreateTrailFx()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.AnimState:SetBank("witchbroom_trail")
    inst.AnimState:SetBuild("witchbroom_trail")
    inst.RestartFx = function()
        inst.AnimState:PlayAnimation("witchbroom_trail"..math.random(3))
        if math.random() < .5 then
            inst.AnimState:SetScale(-1, 1)
        end
    end
    inst:RestartFx()

	inst:ListenForEvent("animover", trail_OnAnimOver)

    return inst
end

local function GetPooledTrailFx(inst)
	local fx = table.remove(inst.trail_pool)
	if fx ~= nil then
		fx:ReturnToScene()
        fx:RestartFx()
	else
		fx = CreateTrailFx()
		fx.owner = inst
	end
	return fx
end

local function fx_DoTrail(inst)
    local owner = inst.entity:GetParent()
    if not owner then
        return
    end

	local moving
	if owner.sg then
		moving = owner.sg:HasStateTag("moving")
	else
		moving = owner:HasTag("moving")
	end

    if moving then
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = GetPooledTrailFx(inst)
        fx.Transform:SetPosition(x, y, z)
    end
end

local function fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    if not TheNet:IsDedicated() then
        inst.trail_pool = {}
        inst.trail_task = inst:DoPeriodicTask(FRAMES*5, fx_DoTrail)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("witchbroom", fn, assets, prefabs),
    Prefab("witchbroom_fx", fxfn, fxassets)
