--------------------------------------------------------------------------------------------------------

local hermitcrabtea_defs = require("prefabs/hermitcrabtea_defs")
local TEA_DEFS = hermitcrabtea_defs.teas
local BUFF_DEFS = hermitcrabtea_defs.buffs
hermitcrabtea_defs = nil

--------------------------------------------------------------------------------------------------------

local function OnFinishTea(inst)
	--V2C: GetParent() for when feeding others (see ACTIONS.FEEDPLAYER.fn)
	local owner = inst.components.inventoryitem:GetGrandOwner() or inst.entity:GetParent()
	local x, y, z = (owner or inst).Transform:GetWorldPosition()

    inst:Remove()
	local refund = SpawnPrefab("messagebottleempty")
	if owner then
		local range = TUNING.RETURN_ITEM_TO_FEEDER_RANGE
		local feeder = owner.sg and owner.sg.statemem.feeder
		if feeder and feeder:IsValid() and
			feeder.components.inventory and feeder.components.inventory.isopen and
			feeder:GetDistanceSqToPoint(x, y, z) < range * range
		then
			feeder.components.inventory:GiveItem(refund, nil, Vector3(x, y, z))
		elseif owner.components.inventory and owner.components.inventory.isopen then
			owner.components.inventory:GiveItem(refund, nil, Vector3(x, y, z))
		elseif owner.components.container then
			owner.components.container:GiveItem(refund, nil, Vector3(x, y, z))
		else
			refund.components.inventoryitem:DoDropPhysics(x, y, z, true)
		end
	else
		refund.Transform:SetPosition(x, y, z)
	end
end

local function HandleEdibleRemove(inst, eatwholestack)
    if eatwholestack then -- Usual behaviour if the whole stack is being eaten.
        inst.components.finiteuses:SetUses(0)
    else
        inst.components.finiteuses:Use(1)
    end
end

local function GetWholeStackEatMultiplier(inst)
    return inst.components.finiteuses:GetUses()
end

local THRESHOLDS = 25 / 100
local function OnPercentChanged(inst, data)
    inst.AnimState:PlayAnimation("idle"..math.clamp(math.ceil(data.percent / THRESHOLDS), 1, 4))
end

local function MakeTea(data)
    local prefabname = "hermitcrabtea_"..data.name

    local overridesym_build = data.build or "hermitcrab_tea"
    local overridesym = "tea_bottle_"..data.name

    local assets =
    {
        Asset("SCRIPT", "scripts/prefabs/hermitcrabtea_defs.lua"),
        Asset("ANIM", "anim/hermitcrab_tea.zip"),
    }

    local prefabs =
    {
        "messagebottleempty",
    }

    local sanityvalue = data.sanityvalue or 0
    local healthvalue = data.healthvalue or TUNING.HEALING_TINY
    local hungervalue = data.hungervalue or 0

    local temperaturedelta = data.temperaturedelta or 0
    local temperatureduration = data.temperatureduration or 0

    local nochill = data.nochill or nil

    local foodtype = data.foodtype or FOODTYPE.GOODIES

    local function OnEaten(inst, eater)
        if data.buff ~= nil then
            eater:AddDebuff(data.buff, data.buff)
        end
    end

    local SCRAPBOOK_OVERRIDEDATA = {
		{ "tea_bottle", overridesym_build, overridesym },
	}

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("hermitcrab_tea")
        inst.AnimState:SetBuild("hermitcrab_tea")
        inst.AnimState:PlayAnimation("idle4")
        inst.AnimState:OverrideSymbol("tea_bottle", overridesym_build, overridesym)

        inst:AddTag("cattoy")
        inst:AddTag("fooddrink")
        inst:AddTag("pre-preparedfood")

        MakeInventoryFloatable(inst, nil, .3)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.scrapbook_overridedata = SCRAPBOOK_OVERRIDEDATA

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetOnFinished(OnFinishTea)
        inst.components.finiteuses:SetMaxUses(TUNING.HERMITCRABTEA_USES)
        inst.components.finiteuses:SetUses(TUNING.HERMITCRABTEA_USES)
        inst:ListenForEvent("percentusedchange", OnPercentChanged)

        inst:AddComponent("edible")
        inst.components.edible:SetOnEatenFn(OnEaten)
        inst.components.edible:SetHandleRemoveFn(HandleEdibleRemove)
        inst.components.edible:SetOverrideStackMultiplierFn(GetWholeStackEatMultiplier)
        inst.components.edible.sanityvalue = sanityvalue
        inst.components.edible.healthvalue = healthvalue
        inst.components.edible.hungervalue = hungervalue
        inst.components.edible.foodtype = foodtype
        inst.components.edible.temperaturedelta = temperaturedelta
        inst.components.edible.temperatureduration = temperatureduration
        inst.components.edible.nochill = nochill

        inst:AddComponent("tradable")
        --inst:AddComponent("perishable")

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    return Prefab(prefabname, fn, assets, prefabs)
end

--------------------------------------------------------------------------------------------------------

local BUFF_TIMER = "buffover"

local function Buff_OnTimerDone(inst, data)
    if data.name == BUFF_TIMER then
        inst.components.debuff:Stop()
    end
end

local function MakeTeaBuff(data)
    local duration = data ~= nil and data.duration
    local prefabname = "hermitcrabtea_"..data.name.."_buff"

    local assets =
    {
        Asset("SCRIPT", "scripts/prefabs/hermitcrabtea_defs.lua"),
        --Asset("ANIM", "anim/hermitcrabtea.zip"),
    }

    local prefabs =
    {

    }

    local function OnAttached(inst, target)
        inst.entity:SetParent(target.entity)
        inst.Transform:SetPosition(0, 0, 0) --in case of loading
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)

        if data.onattachedfn ~= nil then
            data.onattachedfn(inst, target)
        end
    end

    local function OnExtended(inst, target)
        inst.components.timer:StopTimer(BUFF_TIMER)
        inst.components.timer:StartTimer(BUFF_TIMER, duration)

        if data.onextendedfn ~= nil then
            data.onextendedfn(inst, target)
        end
    end

    local function OnDetached(inst, target)
        if data.ondetachedfn ~= nil then
            data.ondetachedfn(inst, target)
        end

        inst:Remove()
    end

    local function debuff_fn()
        local inst = CreateEntity()

        if not TheWorld.ismastersim then
            --Not meant for client!
            inst:DoTaskInTime(0, inst.Remove)

            return inst
        end

        inst.entity:AddTransform()

        --[[Non-networked entity]]
        --inst.entity:SetCanSleep(false)
        inst.entity:Hide()
        inst.persists = false

        inst:AddTag("CLASSIFIED")

        inst:AddComponent("debuff")
        inst.components.debuff:SetAttachedFn(OnAttached)
        inst.components.debuff:SetDetachedFn(OnDetached)
        inst.components.debuff:SetExtendedFn(OnExtended)
        inst.components.debuff.keepondespawn = true

        inst:AddComponent("timer")
        inst.components.timer:StartTimer(BUFF_TIMER, duration)
        inst:ListenForEvent("timerdone", Buff_OnTimerDone)

        return inst
    end

    return Prefab(prefabname, debuff_fn, assets, prefabs)
end

--------------------------------------------------------------------------------------------------------

local tea_prefabs = {}

for _, data in ipairs(TEA_DEFS) do
    if not data.data_only then --allow mods to skip our prefab constructor.
        table.insert(tea_prefabs, MakeTea(data))
    end
end

for _, data in ipairs(BUFF_DEFS) do
    if not data.data_only then --allow mods to skip our prefab constructor.
        table.insert(tea_prefabs, MakeTeaBuff(data))
    end
end

return unpack(tea_prefabs)