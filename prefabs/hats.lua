local BALLOONS = require "prefabs/balloons_common"

local SPIDER_TAGS = {"spider"}

ALL_HAT_PREFAB_NAMES = {}

local function MakeHat(name)
    local fns = {}
    local fname = "hat_"..name
    local symname = name.."hat"
    local prefabname = symname

    --If you want to use generic_perish to do more, it's still
    --commented in all the relevant places below in this file.
    --[[local function generic_perish(inst)
        inst:Remove()
    end]]

    local swap_data = { bank = symname, anim = "anim" }

	-- do not pass this function to equippable:SetOnEquip as it has different a parameter listing
    local function _onequip(inst, owner, symbol_override, headbase_hat_override)

        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner:PushEvent("equipskinneditem", inst:GetSkinName())
            owner.AnimState:OverrideItemSkinSymbol("swap_hat", skin_build, symbol_override or "swap_hat", inst.GUID, fname)
        else
            owner.AnimState:OverrideSymbol("swap_hat", fname, symbol_override or "swap_hat")
        end
        
        owner.AnimState:ClearOverrideSymbol("headbase_hat") --clear out previous overrides
        if headbase_hat_override ~= nil then
            local skin_build = owner.AnimState:GetSkinBuild()
            if skin_build ~= "" then
                owner.AnimState:OverrideSkinSymbol("headbase_hat", skin_build, headbase_hat_override )
            else 
                local build = owner.AnimState:GetBuild()
                owner.AnimState:OverrideSymbol("headbase_hat", build, headbase_hat_override)
            end
        end

        owner.AnimState:Show("HAT")
        owner.AnimState:Show("HAIR_HAT")
        owner.AnimState:Hide("HAIR_NOHAT")
        owner.AnimState:Hide("HAIR")

        if owner:HasTag("player") then
            owner.AnimState:Hide("HEAD")
            owner.AnimState:Show("HEAD_HAT")
        end

        if inst.components.fueled ~= nil then
            inst.components.fueled:StartConsuming()
        end
        
        if inst.skin_equip_sound and owner.SoundEmitter then
            owner.SoundEmitter:PlaySound(inst.skin_equip_sound)
        end
    end

    local function _onunequip(inst, owner)
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner:PushEvent("unequipskinneditem", inst:GetSkinName())
        end

        owner.AnimState:ClearOverrideSymbol("headbase_hat") --it might have been overriden by _onequip
        if owner.components.skinner ~= nil then
            owner.components.skinner.base_change_cb = owner.old_base_change_cb
        end

        owner.AnimState:ClearOverrideSymbol("swap_hat")
        owner.AnimState:Hide("HAT")
        owner.AnimState:Hide("HAIR_HAT")
        owner.AnimState:Show("HAIR_NOHAT")
        owner.AnimState:Show("HAIR")

        if owner:HasTag("player") then
            owner.AnimState:Show("HEAD")
            owner.AnimState:Hide("HEAD_HAT")
        end

        if inst.components.fueled ~= nil then
            inst.components.fueled:StopConsuming()
        end
    end

	fns.simple_onequip =  function(inst, owner, from_ground)
		_onequip(inst, owner)
	end

	fns.simple_onunequip = function(inst, owner, from_ground)
		_onunequip(inst, owner)
	end

    fns.opentop_onequip = function(inst, owner)

        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner:PushEvent("equipskinneditem", inst:GetSkinName())
            owner.AnimState:OverrideItemSkinSymbol("swap_hat", skin_build, "swap_hat", inst.GUID, fname)
        else
            owner.AnimState:OverrideSymbol("swap_hat", fname, "swap_hat")
        end

        owner.AnimState:Show("HAT")
        owner.AnimState:Hide("HAIR_HAT")
        owner.AnimState:Show("HAIR_NOHAT")
        owner.AnimState:Show("HAIR")

        owner.AnimState:Show("HEAD")
        owner.AnimState:Hide("HEAD_HAT")

        if inst.components.fueled ~= nil then
            inst.components.fueled:StartConsuming()
        end

        if inst.skin_equip_sound and owner.SoundEmitter then
            owner.SoundEmitter:PlaySound(inst.skin_equip_sound)
        end
    end

    fns.simple_onequiptomodel = function(inst, owner, from_ground)
        if inst.components.fueled ~= nil then
            inst.components.fueled:StopConsuming()
        end
    end

    local _skinfns = { -- NOTES(JBK): These are useful for skins to have access to them instead of sometimes storing a reference to a hat.
        simple_onequip = fns.simple_onequip,
        simple_onunequip = fns.simple_onunequip,
        opentop_onequip = fns.opentop_onequip,
        simple_onequiptomodel = fns.simple_onequiptomodel,
    }

    local function simple(custom_init)
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(symname)
        inst.AnimState:SetBuild(fname)
        inst.AnimState:PlayAnimation("anim")

        inst:AddTag("hat")

        if custom_init ~= nil then
            custom_init(inst)
        end

        MakeInventoryFloatable(inst)
        inst.components.floater:SetBankSwapOnFloat(false, nil, swap_data) --Hats default animation is not "idle", so even though we don't swap banks, we need to specify the swap_data for re-skinning to reset properly when floating

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst._skinfns = _skinfns

        inst:AddComponent("inventoryitem")

        inst:AddComponent("inspectable")

        inst:AddComponent("tradable")

        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
        inst.components.equippable:SetOnEquip(fns.simple_onequip)
        inst.components.equippable:SetOnUnequip(fns.simple_onunequip)
        inst.components.equippable:SetOnEquipToModel(fns.simple_onequiptomodel)

        MakeHauntableLaunch(inst)

        return inst
    end

    local function straw_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.straw = function()
        local inst = simple(straw_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst:AddComponent("insulator")
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.STRAWHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        return inst
    end

    local function default()
        return simple()
    end

    local function bee_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.bee = function()
        local inst = simple(bee_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.73)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_BEEHAT, TUNING.ARMOR_BEEHAT_ABSORPTION)
        inst.components.armor:SetTags({ "bee" })

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

    local function earmuffs_custom_init(inst)
        inst:AddTag("open_top_hat")

        inst.AnimState:SetRayTestOnBB(true)
    end

    fns.earmuffs = function()
        local inst = simple(earmuffs_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)
        inst.components.floater:SetScale(0.6)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)
        inst.components.equippable:SetOnEquip(fns.opentop_onequip)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.EARMUFF_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        return inst
    end

    fns.winter = function()
        local inst = simple()

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)
        inst.components.floater:SetScale(0.6)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_TINY
        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.WINTERHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        return inst
    end

    local function football_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.football = function()
        local inst = simple(football_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_FOOTBALLHAT, TUNING.ARMOR_FOOTBALLHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

    local function ruinshat_fxanim(inst)
        inst._fx.AnimState:PlayAnimation("hit")
        inst._fx.AnimState:PushAnimation("idle_loop")
    end

    local function ruinshat_oncooldown(inst)
        inst._task = nil
    end

    local function ruinshat_unproc(inst)
        if inst:HasTag("forcefield") then
            inst:RemoveTag("forcefield")
            if inst._fx ~= nil then
                inst._fx:kill_fx()
                inst._fx = nil
            end
            inst:RemoveEventCallback("armordamaged", ruinshat_fxanim)

            inst.components.armor:SetAbsorption(TUNING.ARMOR_RUINSHAT_ABSORPTION)
            inst.components.armor.ontakedamage = nil

            if inst._task ~= nil then
                inst._task:Cancel()
            end
            inst._task = inst:DoTaskInTime(TUNING.ARMOR_RUINSHAT_COOLDOWN, ruinshat_oncooldown)
        end
    end

    local function ruinshat_proc(inst, owner)
        inst:AddTag("forcefield")
        if inst._fx ~= nil then
            inst._fx:kill_fx()
        end
        inst._fx = SpawnPrefab("forcefieldfx")
        inst._fx.entity:SetParent(owner.entity)
        inst._fx.Transform:SetPosition(0, 0.2, 0)
        inst:ListenForEvent("armordamaged", ruinshat_fxanim)

        inst.components.armor:SetAbsorption(TUNING.FULL_ABSORPTION)
        inst.components.armor.ontakedamage = function(inst, damage_amount)
            if owner ~= nil and owner.components.sanity ~= nil then
                owner.components.sanity:DoDelta(-damage_amount * TUNING.ARMOR_RUINSHAT_DMG_AS_SANITY, false)
            end
        end

        if inst._task ~= nil then
            inst._task:Cancel()
        end
        inst._task = inst:DoTaskInTime(TUNING.ARMOR_RUINSHAT_DURATION, ruinshat_unproc)
    end

    local function tryproc(inst, owner, data)
        if inst._task == nil and
            not data.redirected and
            math.random() < TUNING.ARMOR_RUINSHAT_PROC_CHANCE then
            ruinshat_proc(inst, owner)
        end
    end

    local function ruins_onunequip(inst, owner)
        _onunequip(inst, owner)
        inst.ondetach()
    end

    local function ruins_onequip(inst, owner)
        fns.opentop_onequip(inst, owner)
        inst.onattach(owner)
    end

    local function ruins_custom_init(inst)
        inst:AddTag("open_top_hat")
        inst:AddTag("metal")

		--shadowlevel (from shadowlevel component) added to pristine state for optimization
		inst:AddTag("shadowlevel")
    end

    local function ruins_onremove(inst)
        if inst._fx ~= nil then
            inst._fx:kill_fx()
            inst._fx = nil
        end
    end

    fns.ruins = function()
        local inst = simple(ruins_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_RUINSHAT, TUNING.ARMOR_RUINSHAT_ABSORPTION)

        inst.components.equippable:SetOnEquip(ruins_onequip)
        inst.components.equippable:SetOnUnequip(ruins_onunequip)

		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.RUINSHAT_SHADOW_LEVEL)

        MakeHauntableLaunch(inst)

        inst.OnRemoveEntity = ruins_onremove

        inst._fx = nil
        inst._task = nil
        inst._owner = nil
        inst.procfn = function(owner, data) tryproc(inst, owner, data) end
        inst.onattach = function(owner)
            if inst._owner ~= nil then
                inst:RemoveEventCallback("attacked", inst.procfn, inst._owner)
                inst:RemoveEventCallback("onremove", inst.ondetach, inst._owner)
            end
            inst:ListenForEvent("attacked", inst.procfn, owner)
            inst:ListenForEvent("onremove", inst.ondetach, owner)
            inst._owner = owner
            inst._fx = nil
        end
        inst.ondetach = function()
            ruinshat_unproc(inst)
            if inst._owner ~= nil then
                inst:RemoveEventCallback("attacked", inst.procfn, inst._owner)
                inst:RemoveEventCallback("onremove", inst.ondetach, inst._owner)
                inst._owner = nil
                inst._fx = nil
            end
        end

        return inst
    end

    local function feather_equip(inst, owner)
        _onequip(inst, owner)
        local attractor = owner.components.birdattractor
        if attractor then
            attractor.spawnmodifier:SetModifier(inst, TUNING.BIRD_SPAWN_MAXDELTA_FEATHERHAT, "maxbirds")
            attractor.spawnmodifier:SetModifier(inst, TUNING.BIRD_SPAWN_DELAYDELTA_FEATHERHAT.MIN, "mindelay")
            attractor.spawnmodifier:SetModifier(inst, TUNING.BIRD_SPAWN_DELAYDELTA_FEATHERHAT.MAX, "maxdelay")

            local birdspawner = TheWorld.components.birdspawner
            if birdspawner ~= nil then
                birdspawner:ToggleUpdate(true)
            end
        end
    end

    local function feather_unequip(inst, owner)
        _onunequip(inst, owner)

        local attractor = owner.components.birdattractor
        if attractor then
            attractor.spawnmodifier:RemoveModifier(inst)

            local birdspawner = TheWorld.components.birdspawner
            if birdspawner ~= nil then
                birdspawner:ToggleUpdate(true)
            end
        end
    end

    fns.feather = function()
        local inst = simple()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_SMALL
        inst.components.equippable:SetOnEquip(feather_equip)
        inst.components.equippable:SetOnUnequip(feather_unequip)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.FEATHERHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        return inst
    end

    local function beefalo_equip(inst, owner)
        _onequip(inst, owner)
        owner:AddTag("beefalo")
    end

    local function beefalo_unequip(inst, owner)
        _onunequip(inst, owner)
        owner:RemoveTag("beefalo")
    end

    fns.beefalo_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)
        owner:RemoveTag("beefalo")
    end

    local function beefalo_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.beefalo = function()
        local inst = simple(beefalo_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable:SetOnEquip(beefalo_equip)
        inst.components.equippable:SetOnUnequip(beefalo_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.beefalo_onequiptomodel)

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.BEEFALOHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        return inst
    end

    fns.walrus = function()
        local inst = simple()

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.63)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_LARGE

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.WALRUSHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        return inst
    end

    local function miner_turnon(inst)
        local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
        if not inst.components.fueled:IsEmpty() then
            if inst._light == nil or not inst._light:IsValid() then
                inst._light = SpawnPrefab("minerhatlight")
            end
            if owner ~= nil then
                _onequip(inst, owner)
                inst._light.entity:SetParent(owner.entity)
            end
            inst.components.fueled:StartConsuming()
            local soundemitter = owner ~= nil and owner.SoundEmitter or inst.SoundEmitter
            soundemitter:PlaySound("dontstarve/common/minerhatAddFuel")
        elseif owner ~= nil then
            _onequip(inst, owner, "swap_hat_off")
        end
    end

    local function miner_turnoff(inst)
        local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
        if owner ~= nil and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
            _onequip(inst, owner, "swap_hat_off")
        end
        inst.components.fueled:StopConsuming()
        if inst._light ~= nil then
            if inst._light:IsValid() then
                inst._light:Remove()
            end
            inst._light = nil
            local soundemitter = owner ~= nil and owner.SoundEmitter or inst.SoundEmitter
            soundemitter:PlaySound("dontstarve/common/minerhatOut")
        end
    end

    local function miner_unequip(inst, owner)
        _onunequip(inst, owner)
        miner_turnoff(inst)
    end

    fns.miner_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)
        miner_turnoff(inst)
    end

    local function miner_perish(inst)
        local equippable = inst.components.equippable
        if equippable ~= nil and equippable:IsEquipped() then
            local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
            if owner ~= nil then
                local data =
                {
                    prefab = inst.prefab,
                    equipslot = equippable.equipslot,
                }
                miner_turnoff(inst)
                owner:PushEvent("torchranout", data)
                return
            end
        end
        miner_turnoff(inst)
    end

    local function miner_takefuel(inst)
        if inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
            miner_turnon(inst)
        end
    end

    local function miner_custom_init(inst)
        inst.entity:AddSoundEmitter()
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    local function miner_onremove(inst)
        if inst._light ~= nil and inst._light:IsValid() then
            inst._light:Remove()
        end
    end

    fns.miner = function()
        local inst = simple(miner_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.6)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.inventoryitem:SetOnDroppedFn(miner_turnoff)
        inst.components.equippable:SetOnEquip(miner_turnon)
        inst.components.equippable:SetOnUnequip(miner_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.miner_onequiptomodel)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.CAVE
        inst.components.fueled:InitializeFuelLevel(TUNING.MINERHAT_LIGHTTIME)
        inst.components.fueled:SetDepletedFn(miner_perish)
        inst.components.fueled:SetTakeFuelFn(miner_takefuel)
        inst.components.fueled:SetFirstPeriod(TUNING.TURNON_FUELED_CONSUMPTION, TUNING.TURNON_FULL_FUELED_CONSUMPTION)
        inst.components.fueled.accepting = true

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst._light = nil
        inst.OnRemoveEntity = miner_onremove

        return inst
    end

    local function spider_disable(inst)
        if inst.updatetask then
            inst.updatetask:Cancel()
            inst.updatetask = nil
        end
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner and owner.components.leader then
            if not owner:HasTag("spiderwhisperer") then
                if not owner:HasTag("playermonster") then
                    owner:RemoveTag("monster")
                end
                owner:RemoveTag("spiderdisguise")

                for k,v in pairs(owner.components.leader.followers) do
                    if k:HasTag("spider") and k.components.combat then
                        k.components.combat:SuggestTarget(owner)
                    end
                end
                owner.components.leader:RemoveFollowersByTag("spider")
            else
                owner.components.leader:RemoveFollowersByTag("spider", function(follower)
                    if follower and follower.components.follower then
                        if follower.components.follower:GetLoyaltyPercent() > 0 then
                            return false
                        else
                            return true
                        end
                    end
                end)
            end

        end
    end

    local function spider_update(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner and owner.components.leader then
            owner.components.leader:RemoveFollowersByTag("pig")
            local x,y,z = owner.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x,y,z, TUNING.SPIDERHAT_RANGE, SPIDER_TAGS)
            for k,v in pairs(ents) do
                if v.components.follower and not v.components.follower.leader and not owner.components.leader:IsFollower(v) and owner.components.leader.numfollowers < 10 then
                    owner.components.leader:AddFollower(v)
                end
            end
        end
    end

    local function spider_enable(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner and owner.components.leader then
            owner.components.leader:RemoveFollowersByTag("pig")
            owner:AddTag("monster")
            owner:AddTag("spiderdisguise")
        end
        inst.updatetask = inst:DoPeriodicTask(0.5, spider_update, 1)
    end

    local function spider_equip(inst, owner)
        _onequip(inst, owner)
        spider_enable(inst)
    end

    local function spider_unequip(inst, owner)
        _onunequip(inst, owner)
        spider_disable(inst)
    end

    fns.spider_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)
        spider_disable(inst)
    end

    local function spider_perish(inst)
        spider_disable(inst)
        inst:Remove()--generic_perish(inst)
    end

    local function spider_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.spider = function()
        local inst = simple(spider_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)
        inst.components.floater:SetScale(0.62)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.inventoryitem:SetOnDroppedFn(spider_disable)

        inst.components.equippable.dapperness = -TUNING.DAPPERNESS_SMALL
        inst.components.equippable:SetOnEquip(spider_equip)
        inst.components.equippable:SetOnUnequip(spider_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.spider_onequiptomodel)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.SPIDERHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(spider_perish)
        inst.components.fueled.no_sewing = true

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

	local function top_displaynamefn(inst)
		return inst:HasTag("magiciantool") and STRINGS.NAMES.TOPHAT_MAGICIAN or nil
	end

	local function top_onclose(tophatcontainer)
		tophatcontainer.tophat.components.magiciantool:StopUsing()
	end

	local function top_onstartusing(inst, doer)
		if inst.container == nil then
			inst.container = SpawnPrefab("tophat_container")
			inst.container.Network:SetClassifiedTarget(doer)
			inst.container.tophat = inst
			inst.container.components.container_proxy:SetOnCloseFn(top_onclose)
		end
		doer:PushEvent("opencontainer", { container = inst.container.components.container_proxy:GetMaster() })
		inst.container.components.container_proxy:Open(doer)
		if doer.SoundEmitter ~= nil and not doer.SoundEmitter:PlayingSound("magician_tophat_loop") then
			doer.SoundEmitter:PlaySound("maxwell_rework/shadow_magic/storage_void_LP", "magician_tophat_loop")
		end
	end

	local function top_onstopusing(inst, doer)
		if inst.container ~= nil then
			inst.container.components.container_proxy:Close(doer)
			doer:PushEvent("closecontainer", { container = inst.container.components.container_proxy:GetMaster() })
			inst.container:Remove()
			inst.container = nil
		end
		if doer.SoundEmitter ~= nil then
			doer.SoundEmitter:KillSound("magician_tophat_loop")
		end
	end

	local function top_hidefx(inst)
		if inst.fx ~= nil then
			inst.fx:Remove()
			inst.fx = nil
		end
	end

	local function top_showfx_onground(inst)
		if inst.fx == nil then
			inst.fx = SpawnPrefab("tophat_shadow_fx")
		else
			inst.fx.Follower:StopFollowing()
			inst.fx.Transform:SetPosition(0, 0, 0)
		end
		inst.fx.entity:SetParent(inst.entity)
	end

	local function top_showfx_equipped(inst, owner)
		if inst.fx == nil then
			inst.fx = SpawnPrefab("tophat_shadow_fx")
		end
		inst.fx.entity:SetParent(owner.entity)
		inst.fx.Follower:FollowSymbol(owner.GUID, "swap_hat", 0, -100, 0)
	end

	local function top_onequip(inst, owner)
		_onequip(inst, owner)
		top_showfx_equipped(inst, owner)
	end

	local function top_onunequip(inst, owner)
		_onunequip(inst, owner)
		if inst:IsInLimbo() then
			top_hidefx(inst)
		else
			top_showfx_onground(inst)
		end
	end

	local function top_enterlimbo(inst, owner)
		if not inst.components.equippable:IsEquipped() then
			top_hidefx(inst)
		end
	end

	local function top_exitlimbo(inst)
		if not inst.components.equippable:IsEquipped() then
			top_showfx_onground(inst)
		end
	end

	local function top_convert_to_magician(inst)
		if inst.components.magiciantool ~= nil then
			--Already converted
			return
		end

		inst:AddTag("shadow_item")
		inst:AddTag("nocrafting")

		inst.components.inspectable.nameoverride = "TOPHAT_MAGICIAN"

		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.MAGICIAN_TOPHAT_SHADOW_LEVEL)

		inst:AddComponent("magiciantool")
		inst.components.magiciantool:SetOnStartUsingFn(top_onstartusing)
		inst.components.magiciantool:SetOnStopUsingFn(top_onstopusing)

		inst.components.equippable:SetOnEquip(top_onequip)
		inst.components.equippable:SetOnUnequip(top_onunequip)

		inst:ListenForEvent("enterlimbo", top_enterlimbo)
		inst:ListenForEvent("exitlimbo", top_exitlimbo)

		local owner = inst.components.equippable:IsEquipped() and inst.components.inventoryitem.owner or nil
		if owner ~= nil then
			top_showfx_equipped(inst, owner)
		elseif not inst:IsInLimbo() then
			top_showfx_onground(inst)
		end
	end

	local function top_onsave(inst, data)
		if inst.components.magiciantool ~= nil then
			data.magician = true
		end
	end

	local function top_onload(inst, data)
		if data ~= nil and data.magician then
			top_convert_to_magician(inst)
		end
	end

	local function top_onprebuilt(inst, builder, materials, recipe)
		if recipe.name == "tophat_magician" then
			inst:ConvertToMagician()
		end
	end

    local function top_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")

		inst.displaynamefn = top_displaynamefn
    end

    fns.top = function()
        local inst = simple(top_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.TOPHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

		inst.OnSave = top_onsave
		inst.OnLoad = top_onload
		inst.ConvertToMagician = top_convert_to_magician
		inst.onPreBuilt = top_onprebuilt

        return inst
    end


    local function nightcap_custom_init(inst)
        inst:AddTag("good_sleep_aid")
    end

    fns.nightcap = function()
        local inst = simple(nightcap_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        return inst
    end

    local function stopusingbush(inst, data)
        local hat = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or nil
        if hat ~= nil and data.statename ~= "hide" then
            hat.components.useableitem:StopUsingItem()
        end
    end

    local function bush_onequip(inst, owner)
        _onequip(inst, owner)

        inst:ListenForEvent("newstate", stopusingbush, owner)
    end

    local function bush_onunequip(inst, owner)
        _onunequip(inst, owner)

        inst:RemoveEventCallback("newstate", stopusingbush, owner)
    end

    local function bush_onuse(inst)
        local owner = inst.components.inventoryitem.owner
        if owner then
            owner.sg:GoToState("hide")
        end
    end

    local function bush_custom_init(inst)
        inst:AddTag("hide")
    end

    fns.bush = function()
        local inst = simple(bush_custom_init)

        inst.foleysound = "dontstarve/movement/foley/bushhat"

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("useableitem")
        inst.components.useableitem:SetOnUseFn(bush_onuse)

        inst.components.equippable:SetOnEquip(bush_onequip)
        inst.components.equippable:SetOnUnequip(bush_onunequip)

        return inst
    end

    local function flower_custom_init(inst)
        inst:AddTag("open_top_hat")
        inst:AddTag("show_spoilage")
    end

    fns.flower = function()
        local inst = simple(flower_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.68)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_TINY
        inst.components.equippable.flipdapperonmerms = true
        inst.components.equippable:SetOnEquip(fns.opentop_onequip)

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_FAST)
        inst.components.perishable:StartPerishing()
        inst.components.perishable:SetOnPerishFn(inst.Remove)

        inst:AddComponent("forcecompostable")
        inst.components.forcecompostable.green = true

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    local function kelp_custom_init(inst)
        inst:AddTag("show_spoilage")
    end

    fns.kelp = function()
        local inst = simple(kelp_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.68)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = -TUNING.DAPPERNESS_TINY
        inst.components.equippable.flipdapperonmerms = true
        inst.components.equippable:SetOnEquip(fns.opentop_onequip)

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_FAST)
        inst.components.perishable:StartPerishing()
        inst.components.perishable:SetOnPerishFn(inst.Remove)

        inst:AddComponent("forcecompostable")
        inst.components.forcecompostable.green = true

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    local function cookiecutter_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.cookiecutter = function()
        local inst = simple(cookiecutter_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_COOKIECUTTERHAT, TUNING.ARMOR_COOKIECUTTERHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALLMED)

        return inst
    end

    local function slurtle_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    local function slurtle_equip(inst, owner)
        _onequip(inst, owner)

        -- check for the armor_snurtleshell pairing achievement
        if owner:HasTag("player") then
			local equipped_body = owner.components.inventory ~= nil and owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY) or nil
			if equipped_body ~= nil and equipped_body.prefab == "armorsnurtleshell" then
				AwardPlayerAchievement("snail_armour_set", owner)
			end
		end

    end

    fns.slurtle = function()
        local inst = simple(slurtle_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_SLURTLEHAT, TUNING.ARMOR_SLURTLEHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst.components.equippable:SetOnEquip( slurtle_equip )

        return inst
    end

    local function rain_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.rain = function()
        local inst = simple(rain_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.RAINHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_LARGE)

        inst.components.equippable.insulated = true

        return inst
    end

    local function eyebrella_onequip(inst, owner)
        fns.opentop_onequip(inst, owner)

        owner.DynamicShadow:SetSize(2.2, 1.4)
    end

    local function eyebrella_onunequip(inst, owner)
        _onunequip(inst, owner)

        owner.DynamicShadow:SetSize(1.3, 0.6)
    end

    local function eyebrella_perish(inst)
        local equippable = inst.components.equippable
        if equippable ~= nil and equippable:IsEquipped() then
            local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
            if owner ~= nil then
                owner.DynamicShadow:SetSize(1.3, 0.6)
                local data =
                {
                    prefab = inst.prefab,
                    equipslot = equippable.equipslot,
                }
                inst:Remove()--generic_perish(inst)
                owner:PushEvent("umbrellaranout", data)
                return
            end
        end
        inst:Remove()--generic_perish(inst)
    end

    local function eyebrella_custom_init(inst)
        inst:AddTag("open_top_hat")
        inst:AddTag("umbrella")

        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.eyebrella = function()
        local inst = simple(eyebrella_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.95)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.EYEBRELLA_PERISHTIME)
        inst.components.fueled:SetDepletedFn(eyebrella_perish)

        inst.components.equippable:SetOnEquip(eyebrella_onequip)
        inst.components.equippable:SetOnUnequip(eyebrella_onunequip)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_ABSOLUTE)

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE)
        inst.components.insulator:SetSummer()

        inst.components.equippable.insulated = true

        return inst
    end

    local function balloon_onownerattackedfn(inst, data)
        local balloon = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or nil
        if balloon ~= nil and balloon.components.poppable ~= nil then
			balloon.components.poppable:Pop()
        end
    end

    local function balloon_onequip(inst, owner)
        fns.simple_onequip(inst, owner)
		inst:ListenForEvent("attacked", balloon_onownerattackedfn, owner)
    end

    local function balloon_onunequip(inst, owner)
        _onunequip(inst, owner)
		inst:RemoveEventCallback("attacked", balloon_onownerattackedfn, owner)
    end

    local function balloon_custom_init(inst)
        inst.entity:AddSoundEmitter() -- NOTES(JBK): Needed for damage dealing attacks that play sounds on the victim from health combat components.

        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")

		inst:AddTag("cattoy")
	    inst:AddTag("balloon")
		inst:AddTag("noepicmusic")
    end

    fns.balloon = function()
        local inst = simple(balloon_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

		BALLOONS.MakeBalloonMasterInit(inst, BALLOONS.DoPop)

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_TINY
        inst.components.equippable:SetOnEquip(balloon_onequip)
        inst.components.equippable:SetOnUnequip(balloon_onunequip)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.MAGIC
        inst.components.fueled:InitializeFuelLevel(TUNING.PERISH_ONE_DAY)
		inst.components.fueled:SetDepletedFn(BALLOONS.FueledDepletedPop)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst.components.equippable.insulated = true

        return inst
    end

    local function wathgrithr_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.wathgrithr = function()
        local inst = simple(wathgrithr_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_WATHGRITHRHAT, TUNING.ARMOR_WATHGRITHRHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

    local function walter_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    local function walter_onunequip(inst, owner)
        _onunequip(inst, owner)
		if owner._sanity_damage_protection ~= nil then
			owner._sanity_damage_protection:RemoveModifier(inst)
		end
    end

    local function walter_onequip(inst, owner)
        local do_walter_onequip = function()
            if owner.prefab == "walter" then
            	--Note(Peter): please forgive my sins..... walterhats are a mess, and walterhat_nature complicates it
                --When walter wears a walter hat, we use headbase_walter_hat, except for walterhat_nature unless it's one of these listed skins
                if (inst.skinname ~= "walterhat_nature" or (owner.components.skinner ~= nil and
                      (owner.components.skinner.skin_name == "walter_none"
                    or owner.components.skinner.skin_name == "walter_bee"
                    or owner.components.skinner.skin_name == "walter_bee_d"
                    or owner.components.skinner.skin_name == "walter_nature"
                    or owner.components.skinner.skin_name == "walter_ventriloquist")
                )) then
                    --print("headbase_walter_hat", owner.components.skinner.skin_name)
                    _onequip(inst, owner, nil, "headbase_walter_hat" )
                else
                    --print("headbase_hat", owner.components.skinner.skin_name)
                    _onequip(inst, owner )
                end
            else
                _onequip(inst, owner, "swap_hat_large")
            end
        end
        if owner.components.skinner ~= nil then
            owner.old_base_change_cb = owner.components.skinner.base_change_cb
            owner.components.skinner.base_change_cb = function()
                if owner.old_base_change_cb ~= nil then
                    owner.old_base_change_cb()
                end
                do_walter_onequip()
            end
        end
        do_walter_onequip()

		if owner._sanity_damage_protection ~= nil then
			owner._sanity_damage_protection:SetModifier(inst, TUNING.WALTERHAT_SANITY_DAMAGE_PROTECTION)
		end
    end

    fns.walter = function()
        local inst = simple(walter_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst:AddComponent("insulator")
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)

        inst.components.equippable:SetOnEquip(walter_onequip)
        inst.components.equippable:SetOnUnequip(walter_onunequip)
        inst.components.equippable.dapperness = TUNING.DAPPERNESS_SMALL

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.WALTERHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        return inst
    end

    local function ice_custom_init(inst)
        inst:AddTag("show_spoilage")
        inst:AddTag("frozen")
        inst:AddTag("icebox_valid")

        --HASHEATER (from heater component) added to pristine state for optimization
        inst:AddTag("HASHEATER")

        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.ice = function()
        local inst = simple(ice_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.66)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("heater")
        inst.components.heater:SetThermics(false, true)
        inst.components.heater.equippedheat = TUNING.ICEHAT_COOLER

        inst.components.equippable.walkspeedmult = TUNING.ICEHAT_SPEED_MULT
        inst.components.equippable.equippedmoisture = 1
        inst.components.equippable.maxequippedmoisture = 49 -- Meter reading rounds up, so set 1 below

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE)
        inst.components.insulator:SetSummer()

        inst:AddComponent("waterproofer")
        inst.components.waterproofer.effectiveness = 0

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_FASTISH)
        inst.components.perishable:StartPerishing()
        inst.components.perishable:SetOnPerishFn(function(inst)
            local owner = inst.components.inventoryitem.owner
            if owner ~= nil then
                if owner.components.moisture ~= nil then
                    owner.components.moisture:DoDelta(30)
                elseif owner.components.inventoryitem ~= nil then
                    owner.components.inventoryitem:AddMoisture(50)
                end
            end
            inst:Remove()--generic_perish(inst)
        end)

        inst:AddComponent("repairable")
        inst.components.repairable.repairmaterial = MATERIALS.ICE
        inst.components.repairable.announcecanfix = false

        return inst
    end

    fns.catcoon = function()
        local inst = simple()

        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(0.1)
        inst.components.floater:SetScale(0.63)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.CATCOONHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)

        return inst
    end

    local function watermelon_custom_init(inst)
        inst:AddTag("show_spoilage")
        inst:AddTag("icebox_valid")

        --HASHEATER (from heater component) added to pristine state for optimization
        inst:AddTag("HASHEATER")

        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    fns.watermelon = function()
        local inst = simple(watermelon_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("heater")
        inst.components.heater:SetThermics(false, true)
        inst.components.heater.equippedheat = TUNING.WATERMELON_COOLER

        inst.components.equippable.equippedmoisture = 0.5
        inst.components.equippable.maxequippedmoisture = 32 -- Meter reading rounds up, so set 1 below

        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)
        inst.components.insulator:SetSummer()

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_SUPERFAST)
        inst.components.perishable:StartPerishing()
        inst.components.perishable:SetOnPerishFn(--[[generic_perish]]inst.Remove)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst.components.equippable.dapperness = -TUNING.DAPPERNESS_SMALL

        inst.components.floater:SetVerticalOffset(0.1)

        return inst
    end

    local function mole_turnon(owner)
        owner.SoundEmitter:PlaySound("dontstarve_DLC001/common/moggles_on")
    end

    local function mole_turnoff(owner)
        owner.SoundEmitter:PlaySound("dontstarve_DLC001/common/moggles_off")
    end

    local function mole_onequip(inst, owner)
        _onequip(inst, owner)
        mole_turnon(owner)
    end

    local function mole_onunequip(inst, owner)
        _onunequip(inst, owner)
        mole_turnoff(owner)
    end

    local function mole_perish(inst)
        if inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
            local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
            if owner ~= nil then
                mole_turnoff(owner)
            end
        end
        inst:Remove()--generic_perish(inst)
    end

    local function mole_custom_init(inst)
        inst:AddTag("nightvision")
    end

    fns.mole = function()
        local inst = simple(mole_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable:SetOnEquip(mole_onequip)
        inst.components.equippable:SetOnUnequip(mole_onunequip)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.WORMLIGHT
        inst.components.fueled:InitializeFuelLevel(TUNING.MOLEHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(mole_perish)
        inst.components.fueled:SetFirstPeriod(TUNING.TURNON_FUELED_CONSUMPTION, TUNING.TURNON_FULL_FUELED_CONSUMPTION)
        inst.components.fueled.accepting = true

        return inst
    end

    local function mushroom_onequip(inst, owner)
        _onequip(inst, owner)
        owner:AddTag("spoiler")

        inst.components.periodicspawner:Start()

        if owner.components.hunger ~= nil then
            owner.components.hunger.burnratemodifiers:SetModifier(inst, TUNING.MUSHROOMHAT_SLOW_HUNGER)
        end

    end

    local function mushroom_onunequip(inst, owner)
        _onunequip(inst, owner)
        owner:RemoveTag("spoiler")

        inst.components.periodicspawner:Stop()

        if owner.components.hunger ~= nil then
            owner.components.hunger.burnratemodifiers:RemoveModifier(inst)
        end
    end

    fns.mushroom_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)

        owner:RemoveTag("spoiler")
        inst.components.periodicspawner:Stop()
        if owner.components.hunger ~= nil then
            owner.components.hunger.burnratemodifiers:RemoveModifier(inst)
        end
    end

    local function mushroom_displaynamefn(inst)
        return STRINGS.NAMES[string.upper(inst.prefab)]
    end

    local function mushroom_custom_init(inst)
        inst:AddTag("show_spoilage")

        --Use common inspect strings, but unique display names
        inst:SetPrefabNameOverride("mushroomhat")
        inst.displaynamefn = mushroom_displaynamefn

        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")
    end

    local function common_mushroom(spore_prefab)
        local inst = simple(mushroom_custom_init)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable:SetOnEquip(mushroom_onequip)
        inst.components.equippable:SetOnUnequip(mushroom_onunequip)
        inst.components.equippable:SetOnEquipToModel(fns.mushroom_onequiptomodel)

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_FAST)
        inst.components.perishable:StartPerishing()
        inst.components.perishable:SetOnPerishFn(inst.Remove)

        inst:AddComponent("periodicspawner")
        inst.components.periodicspawner:SetPrefab(spore_prefab)
        inst.components.periodicspawner:SetRandomTimes(TUNING.MUSHROOMHAT_SPORE_TIME, 1, true)
        --inst.components.periodicspawner:SetOnSpawnFn(onspawnfn) -- maybe we should add a spawn animation to the hat?

        inst:AddComponent("insulator")
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    fns.red_mushroom = function()
        local inst = common_mushroom("spore_medium")

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.95)

        if not TheWorld.ismastersim then
            return inst
        end

        return inst
    end

    fns.green_mushroom = function()
        local inst = common_mushroom("spore_small")

        inst.components.floater:SetSize("med")

        if not TheWorld.ismastersim then
            return inst
        end

        return inst
    end

    fns.blue_mushroom = function()
        local inst = common_mushroom("spore_tall")

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.7)

        if not TheWorld.ismastersim then
            return inst
        end

        return inst
    end

    local function hive_onunequip(inst, owner)
        _onunequip(inst, owner)

        if owner ~= nil and owner.components.sanity ~= nil then
            owner.components.sanity.neg_aura_absorb = 0
        end
    end

    local function hive_onequip(inst, owner)
        _onequip(inst, owner)

        if owner ~= nil and owner.components.sanity ~= nil then
            owner.components.sanity.neg_aura_absorb = TUNING.ARMOR_HIVEHAT_SANITY_ABSORPTION
        end
    end

    local function hive_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")

        inst:AddTag("regal")
    end

    fns.hive = function()
        local inst = simple(hive_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.8)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_HIVEHAT, TUNING.ARMOR_HIVEHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst.components.equippable:SetOnEquip(hive_onequip)
        inst.components.equippable:SetOnUnequip(hive_onunequip)

        return inst
    end

    local function dragon_countpieces(node, dancers, pieces, count)
        local nodes = {}
        for i = #dancers, 1, -1 do
            local dancer = dancers[i]
            if dancer:IsNear(node, 2) then
                table.remove(dancers, i)
                local piece =
                    (dancer.sg:HasStateTag("dragonhead") and "head") or
                    (dancer.sg:HasStateTag("dragonbody") and "body") or
                    (dancer.sg:HasStateTag("dragontail") and "tail") or
                    nil
                if piece ~= nil then
                    if not pieces[piece] then
                        count = count + 1
                        if count >= 3 then
                            return count
                        end
                        pieces[piece] = true
                    end
                    table.insert(nodes, dancer)
                end
            end
        end
        for i, v in ipairs(nodes) do
            count = dragon_countpieces(v, dancers, pieces, count)
            if count >= 3 then
                return count
            end
        end
        return count
    end

    local function dragon_ondancing(inst)
        local pieces = {}
        local dancers = {}
        for i, v in ipairs(AllPlayers) do
            if v.sg:HasStateTag("dragondance") then
                table.insert(dancers, v)
            end
        end
        inst.components.equippable.dapperness = TUNING.DAPPERNESS_LARGE * dragon_countpieces(inst, dancers, pieces, 0)
    end

    local function dragon_startdancing(inst, doer, data)
        if not (doer.components.rider ~= nil and doer.components.rider:IsRiding()) then
            if inst.dancetask == nil then
                inst.dancetask = inst:DoPeriodicTask(1, dragon_ondancing)
            end
            inst.components.fueled:StartConsuming()
            return {
                anim = inst.prefab == "dragonheadhat" and
                    { "hatdance2_pre", "hatdance2_loop" } or
                    { "hatdance_pre", "hatdance_loop" },
                loop = true,
                fx = false,
                tags = { "nodangle", "dragondance", string.sub(inst.prefab, 1, -4) },
            }
        end
    end

    local function dragon_stopdancing(inst, doer)
        inst.components.fueled:StopConsuming()
        inst.components.equippable.dapperness = 0
        if inst.dancetask ~= nil then
            inst.dancetask:Cancel()
            inst.dancetask = nil
        end
    end

    local function dragon_equip(inst, owner)
        _onequip(inst, owner)
        dragon_stopdancing(inst, owner)
    end

    local function dragon_unequip(inst, owner)
        _onunequip(inst, owner)
        dragon_stopdancing(inst, owner)
        if owner.sg ~= nil and owner.sg:HasStateTag("dragondance") then
            owner.sg:GoToState("idle")
        end
    end

    fns.dragon_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)

        dragon_stopdancing(inst, owner)
        if owner.sg ~= nil and owner.sg:HasStateTag("dragondance") then
            owner.sg:GoToState("idle")
        end
    end

    fns.dragon = function()
        local inst = simple()

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.DRAGONHAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(inst.Remove)

        inst.components.equippable:SetOnEquip(dragon_equip)
        inst.components.equippable:SetOnUnequip(dragon_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.dragon_onequiptomodel)

        inst.OnStartDancing = dragon_startdancing
        inst.OnStopDancing = dragon_stopdancing

        return inst
    end

    local function desert_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")

        inst:AddTag("goggles")
    end

    fns.desert = function()
        local inst = simple(desert_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.GOGGLES_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        inst:AddComponent("insulator")
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)

        return inst
    end

    --NOTE: goggleshat do NOT provide "goggles" tag benefits because you do not
    --      actually wear them over your eyes, and they're just for style -_ -"
    local function goggles_custom_init(inst)
        inst:AddTag("open_top_hat")
    end

    fns.goggles = function()
        local inst = simple(goggles_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.68)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED
        inst.components.equippable:SetOnEquip(fns.opentop_onequip)

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.GOGGLES_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        return inst
    end

    local function moonstorm_equip(inst, owner)
        _onequip(inst, owner)
        owner:AddTag("wagstaff_detector")
    end

    local function moonstorm_unequip(inst, owner)
        _onunequip(inst, owner)
        owner:RemoveTag("wagstaff_detector")
    end

    local function moonstorm_custom_init(inst)
        inst:AddTag("waterproofer")
        inst:AddTag("goggles")
        inst:AddTag("moonsparkchargeable")
    end

    fns.moonstorm_goggles = function()
        local inst = simple(moonstorm_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.MOONSTORM_GOGGLES_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        inst.components.equippable:SetOnEquip(moonstorm_equip)
        inst.components.equippable:SetOnUnequip(moonstorm_unequip)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

    local function eyemask_custom_init(inst)
        -- To play an eat sound when it's on the ground and fed.
        inst.entity:AddSoundEmitter()

        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")

		inst:AddTag("handfed")
		inst:AddTag("fedbyall")

		-- for eater
		inst:AddTag("eatsrawmeat")
		inst:AddTag("strongstomach")
    end

	local function eyemask_oneatfn(inst, food)
		local health = math.abs(food.components.edible:GetHealth(inst)) * inst.components.eater.healthabsorption
		local hunger = math.abs(food.components.edible:GetHunger(inst)) * inst.components.eater.hungerabsorption
		inst.components.armor:Repair(health + hunger)

		if not inst.inlimbo then
			inst.AnimState:PlayAnimation("eat")
			inst.AnimState:PushAnimation("anim", true)

			inst.SoundEmitter:PlaySound("terraria1/eyemask/eat")
		end
	end

    fns.eyemask = function()
        local inst = simple(eyemask_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

		inst:AddComponent("eater")
        --inst.components.eater:SetDiet({ FOODGROUP.OMNI }, { FOODGROUP.OMNI }) -- FOODGROUP.OMNI  is default
		inst.components.eater:SetOnEatFn(eyemask_oneatfn)
		inst.components.eater:SetAbsorptionModifiers(4.0, 1.75, 0)
		inst.components.eater:SetCanEatRawMeat(true)
		inst.components.eater:SetStrongStomach(true)
		inst.components.eater:SetCanEatHorrible(true)

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_FOOTBALLHAT, TUNING.ARMOR_FOOTBALLHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

    --------------------- ANTLION HAT

    local function antlion_onequip(inst, owner)
        fns.simple_onequip(inst, owner)

		if inst.components.autoterraformer ~= nil and owner.components.locomotor ~= nil then
            inst.components.autoterraformer:StartTerraforming()
        end

        if inst.components.container ~= nil then
            inst.components.container:Open(owner)
        end
    end

    local function antlion_onunequip(inst, owner)
        _onunequip(inst, owner)

        if inst.components.autoterraformer ~= nil then
            inst.components.autoterraformer:StopTerraforming()
        end

        if inst.components.container ~= nil then
            inst.components.container:Close()
        end
    end

    local function antlion_onfinishterraforming(inst, x, y, z)
        local turf_smoke = SpawnPrefab("turf_smoke_fx")
        turf_smoke.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(x, y, z))
    end

    local function antlion_onfinished(inst)
        inst.components.container:DropEverything(inst:GetPosition())
        inst:Remove()
    end

    local function antlion_custom_init(inst)
        inst:AddTag("turfhat")

		--waterproofer (from waterproofer component) added to pristine state for optimization
		inst:AddTag("waterproofer")

		--shadowlevel (from shadowlevel component) added to pristine state for optimization
		inst:AddTag("shadowlevel")
    end

    fns.antlion = function()
        local inst = simple(antlion_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable:SetOnEquip(antlion_onequip)
        inst.components.equippable:SetOnUnequip(antlion_onunequip)

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetOnFinished(antlion_onfinished)
        inst.components.finiteuses:SetMaxUses(TUNING.ANTLIONHAT_USES)
        inst.components.finiteuses:SetUses(TUNING.ANTLIONHAT_USES)

        inst:AddComponent("container")
        inst.components.container:WidgetSetup("antlionhat")

        inst:AddComponent("autoterraformer")
        inst.components.autoterraformer.onfinishterraformingfn = antlion_onfinishterraforming

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.ANTLIONHAT_SHADOW_LEVEL)

        return inst
    end

    --------------------- POLLY ROGERS


    local function update_polly_hat_art(inst)
        inst.AnimState:PlayAnimation(inst.defaultanim)
        local deadpolly = not inst.components.spawner.child or inst.components.spawner.child.components.health:IsDead()
        if deadpolly then
            inst.components.inventoryitem:ChangeImageName("polly_rogershat2")
            inst.AnimState:PlayAnimation("anim_dead")
        else
            inst.components.inventoryitem:ChangeImageName("polly_rogershat")
            inst.AnimState:PlayAnimation("anim")
        end
        if inst.components.equippable:IsEquipped() then
            local skin_build = inst:GetSkinBuild()
            local symbol = deadpolly and "swap_hat2" or "swap_hat"
            local owner = inst.components.inventoryitem.owner
            if skin_build ~= nil then
                owner.AnimState:OverrideItemSkinSymbol("swap_hat", skin_build, symbol, inst.GUID, fname)
            else
                owner.AnimState:OverrideSymbol("swap_hat", fname, symbol)
            end
        end
    end

    local function pollyremoved(inst)
        inst:RemoveEventCallback("onremove", pollyremoved, inst.polly)
        inst.polly = nil
    end

    local function polly_rogers_custom_init(inst)

    end

    local function test_polly_spawn(inst)
        if not inst.polly and not inst.components.spawner:IsSpawnPending() then
            inst.components.spawner:ReleaseChild()
        end
    end

    local function polly_rogers_go_away(inst)
        if inst.pollytask then
            inst.pollytask:Cancel()
            inst.pollytask = nil
        end

        if inst.polly then
            inst.polly.flyaway = true
            inst.polly:PushEvent("flyaway")
        end
    end

    local function polly_rogers_ondeplete(inst, data)
        polly_rogers_go_away(inst)
        inst:Remove()
    end

    local function polly_rogers_equip(inst,owner)
        _onequip(inst, owner)
        inst.pollytask = inst:DoTaskInTime(0,function()
            inst.worn = true
            test_polly_spawn(inst)

            inst.polly = inst.components.spawner.child
            if inst.polly then
                inst.polly.components.follower:SetLeader(owner)
                inst.polly.flyaway = nil
            end
            update_polly_hat_art(inst)
        end)
    end

    local function polly_rogers_unequip(inst,owner)
        _onunequip(inst, owner)
        inst.worn = nil

        polly_rogers_go_away(inst)
        --update_polly_hat_art(inst)
    end

    fns.polly_rogers_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)

        inst.worn = nil
        polly_rogers_go_away(inst)
    end

    local function getpollyspawnlocation(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or inst
        local pos = Vector3(owner.Transform:GetWorldPosition())
        local offset = nil
        local count = 0
        while offset == nil and count < 12 do
            offset = FindWalkableOffset(pos, math.random()*2*PI, math.random() * 5, 12, false, false, nil, false, true)
            count = count + 1
        end

        if offset then
            pos.x = pos.x + offset.x
            pos.z = pos.z + offset.z
        end
        return pos.x, 15, pos.z
    end


    local function polly_rogers_onoccupied(inst,child)
        inst.polly = nil
        child.components.follower:StopFollowing()
    end

    local function polly_rogers_onvacate(inst, child)

        if not inst.worn then
            inst.components.spawner:GoHome(child)
            return
        end
               
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
        if owner then
            child.sg:GoToState("glide")
            child.Transform:SetRotation(math.random() * 180)
            child.components.locomotor:StopMoving()
            child.hat = inst
            inst:ListenForEvent("onremove", pollyremoved, inst.polly)
        end
    end


    local function updatepolly(spawner,polly)
        update_polly_hat_art(spawner)
    end

    fns.polly_rogers = function()
        local inst = simple(polly_rogers_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        inst.defaultanim = "anim"

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.POLLY_ROGERS_HAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(polly_rogers_ondeplete)

        inst.components.equippable:SetOnEquip(polly_rogers_equip)
        inst.components.equippable:SetOnUnequip(polly_rogers_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.polly_rogers_onequiptomodel)

        inst:AddComponent("spawner")
        inst.components.spawner:Configure("polly_rogers", TUNING.POLLY_ROGERS_SPAWN_TIME)
        inst.components.spawner.onvacate = polly_rogers_onvacate
        inst.components.spawner.onoccupied = polly_rogers_onoccupied
        inst.components.spawner.overridespawnlocation = getpollyspawnlocation
        inst.components.spawner:CancelSpawning()
        inst.components.spawner.onkilledfn = updatepolly
        inst.components.spawner.onspawnedfn = updatepolly

        inst:DoTaskInTime(0,function() update_polly_hat_art(inst) end)

        return inst
    end

    ------------------ MASKS
    fns.mask = function()
        local inst = simple()

        inst.components.floater:SetSize("med")

        inst.defaultanim = "anim"

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fuel")
        inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

        MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
        MakeSmallPropagator(inst)

        return inst
    end

    ---------------------- MONEY SMALL
    local function monkey_small_custom_init(inst)

    end


    local function monkey_small_equip(inst,owner)
        _onequip(inst, owner)
        owner:AddTag("master_crewman")
    end

    local function monkey_small_unequip(inst,owner)
        _onunequip(inst, owner)
        owner:RemoveTag("master_crewman")
    end

    fns.monkey_small = function()
        local inst = simple(monkey_small_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.MONKEY_MEDIUM_HAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)

        inst.components.equippable:SetOnEquip(monkey_small_equip)
        inst.components.equippable:SetOnUnequip(monkey_small_unequip)

        return inst
    end

    ---------------------- MONEY MEDIUM
    local function monkey_medium_custom_init(inst)

    end

    local function monkey_medium_equip(inst,owner)
        _onequip(inst, owner)
        owner:AddTag("boat_health_buffer")
    end

    local function monkey_medium_unequip(inst,owner)
        _onunequip(inst, owner)
        owner:RemoveTag("boat_health_buffer")
    end

    fns.monkey_medium_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)
        owner:RemoveTag("boat_health_buffer")
    end

    fns.monkey_medium = function()
        local inst = simple(monkey_medium_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("fueled")
        inst.components.fueled.fueltype = FUELTYPE.USAGE
        inst.components.fueled:InitializeFuelLevel(TUNING.MONKEY_MEDIUM_HAT_PERISHTIME)
        inst.components.fueled:SetDepletedFn(--[[generic_perish]]inst.Remove)        

        inst.components.equippable:SetOnEquip(monkey_medium_equip)
        inst.components.equippable:SetOnUnequip(monkey_medium_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.monkey_medium_onequiptomodel)

        return inst
    end

    local function skeleton_onequip(inst, owner)
        _onequip(inst, owner)
        if owner.components.sanity ~= nil then
            owner.components.sanity:SetInducedInsanity(inst, true)
        end
    end

    local function skeleton_onunequip(inst, owner)
        _onunequip(inst, owner)
        if owner.components.sanity ~= nil then
            owner.components.sanity:SetInducedInsanity(inst, false)
        end
    end

    local function skeleton_custom_init(inst)
        --waterproofer (from waterproofer component) added to pristine state for optimization
        inst:AddTag("waterproofer")

		--shadowlevel (from shadowlevel component) added to pristine state for optimization
		inst:AddTag("shadowlevel")

		--shadowdominance (from shadowdominance component) added to pristine state for optimization
        inst:AddTag("shadowdominance")
    end

    local function skeleton()
        local inst = simple(skeleton_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.68)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = TUNING.CRAZINESS_MED
        inst.components.equippable.is_magic_dapperness = true
        inst.components.equippable:SetOnEquip(skeleton_onequip)
        inst.components.equippable:SetOnUnequip(skeleton_onunequip)

		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.SKELETONHAT_SHADOW_LEVEL)

		inst:AddComponent("shadowdominance")

        inst:AddComponent("armor")
        inst.components.armor:InitCondition(TUNING.ARMOR_SKELETONHAT, TUNING.ARMOR_SKELETONHAT_ABSORPTION)

        inst:AddComponent("waterproofer")
        inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

        return inst
    end

    local function merm_disable(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner then
			if owner.mermhat_wasmonster then
                owner:AddTag("monster")
                owner.mermhat_wasmonster = nil
			end
			if owner.mermhat_notamerm then
                owner:RemoveTag("merm")
	            owner:RemoveTag("mermdisguise")
				if owner.components.leader then
					owner.components.leader:RemoveFollowersByTag("merm")
				end
                owner.mermhat_notamerm = nil
			end
		end
    end

    local function merm_enable(inst)
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
        if owner then
			if owner.components.leader then
	            owner.components.leader:RemoveFollowersByTag("pig")
            end

			if not owner:HasTag("merm") then
				owner.mermhat_notamerm = true
	            owner:AddTag("merm")
	            owner:AddTag("mermdisguise")
			end
			if owner:HasTag("monster") then
				owner.mermhat_wasmonster = true
	            owner:RemoveTag("monster")
			end
        end
    end

    local function merm_equip(inst, owner)
        fns.opentop_onequip(inst, owner)
        merm_enable(inst)
    end

    local function merm_unequip(inst, owner)
        _onunequip(inst, owner)
        merm_disable(inst)
    end

    fns.merm_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)
        merm_disable(inst)
    end

    local function merm_custom_init(inst)
        inst:AddTag("open_top_hat")
        inst:AddTag("show_spoilage")
    end

    fns.merm = function()
        local inst = simple(merm_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.68)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = -TUNING.DAPPERNESS_TINY
        inst.components.equippable:SetOnEquip(merm_equip)
        inst.components.equippable:SetOnUnequip(merm_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.merm_onequiptomodel)

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_SLOW)
        inst.components.perishable:StartPerishing()
        inst.components.perishable:SetOnPerishFn(inst.Remove)

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    local function batnose_equip(inst, owner)
        _onequip(inst, owner)

        inst.components.perishable:StartPerishing()

        owner:PushEvent("learncookbookstats", inst.prefab)
        owner:AddDebuff("hungerregenbuff", "hungerregenbuff")
    end

    local function batnose_unequip(inst, owner)
        _onunequip(inst, owner)

        inst.components.perishable:StopPerishing()

        owner:RemoveDebuff("hungerregenbuff")

        if owner.components.foodmemory ~= nil then
            owner.components.foodmemory:RememberFood("hungerregenbuff")
        end
    end

    fns.batnose_onequiptomodel = function(inst, owner, from_ground)
        fns.simple_onequiptomodel(inst, owner, from_ground)

        inst.components.perishable:StopPerishing()

        owner:RemoveDebuff("hungerregenbuff")

        if owner.components.foodmemory ~= nil then
            owner.components.foodmemory:RememberFood("hungerregenbuff")
        end
    end

    fns.batnose = function()
        local inst = simple()

        inst.components.floater:SetSize("med")

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = -TUNING.DAPPERNESS_TINY
        inst.components.equippable.flipdapperonmerms = true
        inst.components.equippable:SetOnEquip(batnose_equip)
        inst.components.equippable:SetOnUnequip(batnose_unequip)
        inst.components.equippable:SetOnEquipToModel(fns.batnose_onequiptomodel)
        inst.components.equippable.restrictedtag = "usesvegetarianequipment"
        inst.components.equippable.refuse_on_restrict = true

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.BATNOSEHAT_PERISHTIME)
        inst.components.perishable:SetOnPerishFn(inst.Remove)

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    local function stopusingplantregistry(inst, data)
        local hat = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) or nil
        if hat ~= nil and data.statename ~= "plantregistry_open" then
            hat.components.useableitem:StopUsingItem()
        end
    end

    local function plantregistry_onequip(inst, owner)
        _onequip(inst, owner)
        inst:ListenForEvent("newstate", stopusingplantregistry, owner)
    end

    local function plantregistry_onunequip(inst, owner)
        _onunequip(inst, owner)
        inst:RemoveEventCallback("newstate", stopusingplantregistry, owner)
    end

    local function plantregistry_onuse(inst)
        local owner = inst.components.inventoryitem.owner
        if owner then
            if not CanEntitySeeTarget(owner, inst) then return false end
            owner.sg:GoToState("plantregistry_open")
            owner:ShowPopUp(POPUPS.PLANTREGISTRY, true)
        end
    end

    local function plantregistry_custom_init(inst)
        inst:AddTag("plantinspector")
    end

    fns.plantregistry = function()
        local inst = simple(plantregistry_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.65)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable:SetOnEquip(plantregistry_onequip)
        inst.components.equippable:SetOnUnequip(plantregistry_onunequip)

        inst:AddComponent("insulator")
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)

        inst:AddComponent("useableitem")
        inst.components.useableitem:SetOnUseFn(plantregistry_onuse)

        return inst
    end

    local function nutrients_onequip(inst, owner)
        plantregistry_onequip(inst, owner) --calls onequip
    end

    local function nutrients_onunequip(inst, owner)
        plantregistry_onunequip(inst, owner) --calls onunequip
    end

    local function nutrients_custom_init(inst)
        plantregistry_custom_init(inst)
        inst:AddTag("detailedplanthappiness")
        inst:AddTag("nutrientsvision")

		--shadowlevel (from shadowlevel component) added to pristine state for optimization
		inst:AddTag("shadowlevel")
    end

    fns.nutrientsgoggles = function()
        local inst = simple(nutrients_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.72)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable:SetOnEquip(nutrients_onequip)
        inst.components.equippable:SetOnUnequip(nutrients_onunequip)

        inst:AddComponent("insulator")
        inst.components.insulator:SetSummer()
        inst.components.insulator:SetInsulation(TUNING.INSULATION_SMALL)

        inst:AddComponent("useableitem")
        inst.components.useableitem:SetOnUseFn(plantregistry_onuse)

		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.NUTRIENTSGOGGLESHAT_SHADOW_LEVEL)

        return inst
    end

    local function alterguardian_custom_init(inst)
        inst:AddTag("open_top_hat")

        inst:AddTag("gestaltprotection")
    end

    local function alterguardianhat_IsRed(inst) return inst.prefab == MUSHTREE_SPORE_RED end
    local function alterguardianhat_IsGreen(inst) return inst.prefab == MUSHTREE_SPORE_GREEN end
    local function alterguardianhat_IsBlue(inst) return inst.prefab == MUSHTREE_SPORE_BLUE end
    local alterguardianhat_colourtint = { 0.4, 0.3, 0.25, 0.2, 0.15, 0.1 }
    local alterguardianhat_multtint = { 0.7, 0.6, 0.55, 0.5, 0.45, 0.4 }

    local function alterguardianhat_animstatemult(animstate, r, g, b)
        animstate:SetMultColour(
            alterguardianhat_multtint[1+g+b],
            alterguardianhat_multtint[r+1+b],
            alterguardianhat_multtint[r+g+1],
            1
        )
    end
    local function alterguardianhat_updatelight(inst)
        local num_sources = #inst.components.container:FindItems(function(item)
            return item:HasTag("spore")
        end)

        local r = #inst.components.container:FindItems(alterguardianhat_IsRed)
        local g = #inst.components.container:FindItems(alterguardianhat_IsGreen)
        local b = #inst.components.container:FindItems(alterguardianhat_IsBlue)

        if inst._light ~= nil and inst._light:IsValid() then
            if r > 0 or g > 0 or b > 0 then
                inst._light.Light:SetColour(
                    alterguardianhat_colourtint[1+g+b] + r/11,
                    alterguardianhat_colourtint[r+1+b] + g/11,
                    alterguardianhat_colourtint[r+g+1] + b/11
                )
            else
                -- If no spores are inserted, match the colour of the miner hat light.
                inst._light.Light:SetColour(180 / 255, 195 / 255, 150 / 255)
            end
        end

        alterguardianhat_animstatemult(inst.AnimState, r, g, b)

        if inst._front and inst._front:IsValid() then
            alterguardianhat_animstatemult(inst._front.AnimState, r, g, b)
        end

        if inst._back and inst._back:IsValid() then
            alterguardianhat_animstatemult(inst._back.AnimState, r, g, b)
        end
    end

	local function alterguardian_activate(inst, owner)
		if inst._is_active then
			return
		end
		inst._is_active = true

		if inst._task ~= nil then
			inst._task:Cancel()
			inst._task = nil
		end

		_onunequip(inst, owner) -- hide the swap_hat

		if inst._front == nil then
			inst._front = SpawnPrefab("alterguardian_hat_equipped")
			inst._front:OnActivated(owner, true)
		end
		if inst._back == nil then
			inst._back = SpawnPrefab("alterguardian_hat_equipped")
			inst._back:OnActivated(owner, false)
		end

        local skin_build = inst:GetSkinBuild()
        if skin_build then
            inst._front:SetSkin(skin_build, inst.GUID)
            inst._back:SetSkin(skin_build, inst.GUID)
        end

        if inst._light == nil then
            inst._light = SpawnPrefab("alterguardianhatlight")
	        inst._light.entity:SetParent(owner.entity)
        end
        alterguardianhat_updatelight(inst)
	end

	local function alterguardian_deactivate(inst, owner)
		if not inst._is_active then
			return
		end
		inst._is_active = false

        if inst._light ~= nil then
            inst._light:Remove()
            inst._light = nil
		end

		if inst._front ~= nil then
			inst._front:OnDeactivated()
			inst._front = nil
			inst._task = inst:DoTaskInTime(8*FRAMES, function()
                fns.opentop_onequip(inst, owner)
                inst._task = nil
            end)
		else
			fns.opentop_onequip(inst, owner)
		end

		if inst._back ~= nil then
			inst._back:OnDeactivated()
			inst._back = nil
		end
	end

	local function alterguardian_onsanitydelta(inst, owner)
		local sanity = owner.components.sanity ~= nil and owner.components.sanity:GetPercentWithPenalty() or 0
		if sanity > TUNING.SANITY_BECOME_ENLIGHTENED_THRESH then
			alterguardian_activate(inst, owner)
		else
			alterguardian_deactivate(inst, owner)
		end
	end

	local function alterguardian_spawngestalt_fn(inst, owner, data)
		if not inst._is_active then
			return
		end

		if owner ~= nil and (owner.components.health == nil or not owner.components.health:IsDead()) then
		    local target = data.target
			if target and target ~= owner and target:IsValid() and (target.components.health == nil or not target.components.health:IsDead() and not target:HasTag("structure") and not target:HasTag("wall")) then

                -- In combat, this is when we're just launching a projectile, so don't spawn a gestalt yet
                if data.weapon ~= nil and data.projectile == nil
                        and (data.weapon.components.projectile ~= nil
                            or data.weapon.components.complexprojectile ~= nil
                            or data.weapon.components.weapon:CanRangedAttack()) then
                    return
                end

				local x, y, z = target.Transform:GetWorldPosition()

				local gestalt = SpawnPrefab("alterguardianhat_projectile")
				local r = GetRandomMinMax(3, 5)
				local delta_angle = GetRandomMinMax(-90, 90)
				local angle = (owner:GetAngleToPoint(x, y, z) + delta_angle) * DEGREES
				gestalt.Transform:SetPosition(x + r * math.cos(angle), y, z + r * -math.sin(angle))
				gestalt:ForceFacePoint(x, y, z)
				gestalt:SetTargetPosition(Vector3(x, y, z))
				gestalt.components.follower:SetLeader(owner)

				if owner.components.sanity ~= nil then
					owner.components.sanity:DoDelta(-1, true) -- using overtime so it doesnt make the sanity sfx every time you attack
				end
			end
		end
	end

    local function alterguardian_onequip(inst, owner)
        fns.opentop_onequip(inst, owner)

		inst.alterguardian_spawngestalt_fn = function(_owner, _data) alterguardian_spawngestalt_fn(inst, _owner, _data) end
		inst:ListenForEvent("onattackother", inst.alterguardian_spawngestalt_fn, owner)

		inst._onsanitydelta = function() alterguardian_onsanitydelta(inst, owner) end
		inst:ListenForEvent("sanitydelta", inst._onsanitydelta, owner)

		local sanity = owner.components.sanity ~= nil and owner.components.sanity:GetPercent() or 0
		if sanity > TUNING.SANITY_BECOME_ENLIGHTENED_THRESH then
			alterguardian_activate(inst, owner)
		end

        if inst.components.container ~= nil and inst.keep_closed ~= owner.userid then
            inst.components.container:Open(owner)
        end
    end

    local function alterguardian_onunequip(inst, owner)
		inst._is_active = false

		inst:RemoveEventCallback("sanitydelta", inst._onsanitydelta, owner)
		inst:RemoveEventCallback("onattackother", inst.alterguardian_spawngestalt_fn, owner)

        if inst._light ~= nil then
            inst._light:Remove()
            inst._light = nil
		end

        _onunequip(inst, owner)
		if inst._front ~= nil then
			inst._front:Remove()
			inst._front = nil
		end
		if inst._back ~= nil then
			inst._back:Remove()
			inst._back = nil
		end

        if inst.components.container ~= nil then
			inst.keep_closed = inst.components.container.opencount == 0 and owner.userid or nil
            inst.components.container:Close()
        end
    end

    local function alterguardianhat_onremove(inst)
        if inst._front ~= nil and inst._front:IsValid() then
            inst._front:Remove()
        end
        if inst._back ~= nil and inst._back:IsValid() then
            inst._back:Remove()
        end
    end

    fns.alterguardian = function()
        local inst = simple(alterguardian_custom_init)

        inst.components.floater:SetSize("med")
        inst.components.floater:SetScale(0.68)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.components.equippable.dapperness = -TUNING.CRAZINESS_SMALL
        inst.components.equippable:SetOnEquip(alterguardian_onequip)
        inst.components.equippable:SetOnUnequip(alterguardian_onunequip)
	    inst.components.equippable.is_magic_dapperness = true

        inst:AddComponent("container")
        inst.components.container:WidgetSetup("alterguardianhat")
        inst.components.container.acceptsstacks = false

        inst:AddComponent("preserver")
        inst.components.preserver:SetPerishRateMultiplier(0)

        MakeHauntableLaunchAndPerish(inst)

        inst:ListenForEvent("itemget", alterguardianhat_updatelight)
        inst:ListenForEvent("itemlose", alterguardianhat_updatelight)
        inst:ListenForEvent("onremove", alterguardianhat_onremove)

        return inst
    end

	local function dreadstone_getsetbonusequip(inst, owner)
		local body = owner.components.inventory ~= nil and owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY) or nil
		return body ~= nil and body.prefab == "armordreadstone" and body or nil
	end

	local function dreadstone_doregen(inst, owner)
		if owner.components.sanity ~= nil and owner.components.sanity:IsInsanityMode() then
			local setbonus = dreadstone_getsetbonusequip(inst, owner) ~= nil and TUNING.ARMOR_DREADSTONE_REGEN_SETBONUS or 1
			local rate = 1 / Lerp(1 / TUNING.ARMOR_DREADSTONE_REGEN_MAXRATE, 1 / TUNING.ARMOR_DREADSTONE_REGEN_MINRATE, owner.components.sanity:GetPercent())
			inst.components.armor:Repair(inst.components.armor.maxcondition * rate * setbonus)
		end
		if not inst.components.armor:IsDamaged() then
			inst.regentask:Cancel()
			inst.regentask = nil
		end
	end

	local function dreadstone_startregen(inst, owner)
		if inst.regentask == nil then
			inst.regentask = inst:DoPeriodicTask(TUNING.ARMOR_DREADSTONE_REGEN_PERIOD, dreadstone_doregen, nil, owner)
		end
	end

	local function dreadstone_stopregen(inst)
		if inst.regentask ~= nil then
			inst.regentask:Cancel()
			inst.regentask = nil
		end
	end

	local function dreadstone_onequip(inst, owner)
		_onequip(inst, owner)

		if owner.components.sanity ~= nil and inst.components.armor:IsDamaged() then
			dreadstone_startregen(inst, owner)
		else
			dreadstone_stopregen(inst)
		end
	end

	local function dreadstone_onunequip(inst, owner)
		_onunequip(inst, owner)
		dreadstone_stopregen(inst)
	end

	local function dreadstone_ontakedamage(inst, amount)
		if inst.regentask == nil and inst.components.equippable:IsEquipped() then
			local owner = inst.components.inventoryitem.owner
			if owner ~= nil and owner.components.sanity ~= nil then
				dreadstone_startregen(inst, owner)
			end
		end
	end

	local function dreadstone_calcdapperness(inst, owner)
		local insanity = owner.components.sanity ~= nil and owner.components.sanity:IsInsanityMode()
		local other = dreadstone_getsetbonusequip(inst, owner)
		if other ~= nil then
			return (insanity and (inst.regentask ~= nil or other.regentask ~= nil) and TUNING.CRAZINESS_MED or TUNING.CRAZINESS_SMALL) * 0.5
		end
		return insanity and inst.regentask ~= nil and TUNING.CRAZINESS_MED or TUNING.CRAZINESS_SMALL
	end

	local function dreadstone_custom_init(inst)
		inst:AddTag("dreadstone")
		inst:AddTag("shadow_item")

		--waterproofer (from waterproofer component) added to pristine state for optimization
		inst:AddTag("waterproofer")

		--shadowlevel (from shadowlevel component) added to pristine state for optimization
		inst:AddTag("shadowlevel")
	end

	fns.dreadstone = function()
		local inst = simple(dreadstone_custom_init)

		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("armor")
		inst.components.armor:InitCondition(TUNING.ARMOR_DREADSTONEHAT, TUNING.ARMOR_DREADSTONEHAT_ABSORPTION)
		inst.components.armor.ontakedamage = dreadstone_ontakedamage

		inst.components.equippable.dapperfn = dreadstone_calcdapperness
		inst.components.equippable.is_magic_dapperness = true
		inst.components.equippable:SetOnEquip(dreadstone_onequip)
		inst.components.equippable:SetOnUnequip(dreadstone_onunequip)

		inst:AddComponent("planardefense")
		inst.components.planardefense:SetBaseDefense(TUNING.ARMOR_DREADSTONEHAT_PLANAR_DEF)

		inst:AddComponent("waterproofer")
		inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)

		inst:AddComponent("damagetyperesist")
		inst.components.damagetyperesist:AddResist("shadow_aligned", inst, TUNING.ARMOR_DREADSTONEHAT_SHADOW_RESIST)

		inst:AddComponent("shadowlevel")
		inst.components.shadowlevel:SetDefaultLevel(TUNING.DREADSTONEHAT_SHADOW_LEVEL)

		MakeHauntableLaunch(inst)

		return inst
	end

	local function lunarplant_getsetbonusequip(inst, owner)
		if owner.components.inventory ~= nil then
			local body = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
			local weapon = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			return body ~= nil and body.prefab == "armor_lunarplant" and body or nil,
				weapon ~= nil and weapon.lunarplantweapon and weapon or nil
		end
	end

	local function lunarplant_onequip(inst, owner)
		_onequip(inst, owner)
		local body, weapon = lunarplant_getsetbonusequip(inst, owner)
		if body ~= nil then
			inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
			body.components.damagetyperesist:AddResist("lunar_aligned", body, TUNING.ARMOR_LUNARPLANT_SETBONUS_LUNAR_RESIST, "setbonus")
			if weapon ~= nil then
				if weapon.base_damage ~= nil then
					weapon.components.weapon:SetDamage(weapon.base_damage * TUNING.WEAPONS_LUNARPLANT_SETBONUS_DAMAGE_MULT)
					weapon.components.planardamage:AddBonus(weapon, TUNING.WEAPONS_LUNARPLANT_SETBONUS_PLANAR_DAMAGE, "setbonus")
				end
				if weapon.max_bounces ~= nil then
					weapon.max_bounces = TUNING.STAFF_LUNARPLANT_SETBONUS_BOUNCES
				end
			end
		end

		if inst.fx == nil then
			inst.fx = {}
			for i = 1, 3 do
				local fx = SpawnPrefab("lunarplanthat_fx")
				if i > 1 then
					fx.AnimState:PlayAnimation("idle"..tostring(i), true)
				end
				table.insert(inst.fx, fx)
			end
		end
		local frame = math.random(inst.fx[1].AnimState:GetCurrentAnimationNumFrames()) - 1
		for i, v in ipairs(inst.fx) do
			v.entity:SetParent(owner.entity)
			v.Follower:FollowSymbol(owner.GUID, "swap_hat", nil, nil, nil, true, nil, i - 1)
			v.AnimState:SetFrame(frame)
			v.components.highlightchild:SetOwner(owner)
		end
		owner.AnimState:SetSymbolLightOverride("swap_hat", .1)
	end

	local function lunarplant_onunequip(inst, owner)
		_onunequip(inst, owner)
		local body, weapon = lunarplant_getsetbonusequip(inst, owner)
		if body ~= nil then
			body.components.damagetyperesist:RemoveResist("lunar_aligned", body, "setbonus")
		end
		inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "setbonus")
		if weapon ~= nil then
			if weapon.base_damage ~= nil then
				weapon.components.weapon:SetDamage(weapon.base_damage)
				weapon.components.planardamage:RemoveBonus(weapon, "setbonus")
			end
			if weapon.max_bounces ~= nil then
				weapon.max_bounces = TUNING.STAFF_LUNARPLANT_BOUNCES
			end
		end

		if inst.fx ~= nil then
			for i, v in ipairs(inst.fx) do
				v:Remove()
			end
			inst.fx = nil
		end
		owner.AnimState:SetSymbolLightOverride("swap_hat", 0)
	end

	local function lunarplant_custom_init(inst)
		inst:AddTag("lunarplant")
		inst:AddTag("gestaltprotection")
		inst:AddTag("goggles")

		--waterproofer (from waterproofer component) added to pristine state for optimization
		inst:AddTag("waterproofer")
	end

	fns.lunarplant = function()
		local inst = simple(lunarplant_custom_init)

		inst.components.floater:SetSize("med")
		inst.components.floater:SetVerticalOffset(0.25)
		inst.components.floater:SetScale(.75)

		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("armor")
		inst.components.armor:InitCondition(TUNING.ARMOR_LUNARPLANT_HAT, TUNING.ARMOR_LUNARPLANT_HAT_ABSORPTION)

		inst.components.equippable:SetOnEquip(lunarplant_onequip)
		inst.components.equippable:SetOnUnequip(lunarplant_onunequip)

		inst:AddComponent("planardefense")
		inst.components.planardefense:SetBaseDefense(TUNING.ARMOR_LUNARPLANT_HAT_PLANAR_DEF)

		inst:AddComponent("waterproofer")
		inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALLMED)

		inst:AddComponent("damagetyperesist")
		inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.ARMOR_LUNARPLANT_LUNAR_RESIST)

		MakeHauntableLaunch(inst)

		return inst
	end

    local fn = nil
    local assets = { Asset("ANIM", "anim/"..fname..".zip") }
    local prefabs = nil

    if name == "bee" then
        fn = fns.bee
    elseif name == "straw" then
        fn = fns.straw
    elseif name == "top" then
        fn = fns.top
		prefabs =
		{
			"tophat_container",
			"tophat_shadow_fx",
			"tophat_swirl_fx",
			"tophat_using_shadow_fx",
		}
    elseif name == "feather" then
        fn = fns.feather
    elseif name == "football" then
        fn = fns.football
    elseif name == "flower" then
        fn = fns.flower
    elseif name == "spider" then
        fn = fns.spider
    elseif name == "miner" then
        fn = fns.miner
        prefabs = { "minerhatlight" }
    elseif name == "earmuffs" then
        fn = fns.earmuffs
    elseif name == "winter" then
        fn = fns.winter
    elseif name == "beefalo" then
        fn = fns.beefalo
    elseif name == "bush" then
        fn = fns.bush
    elseif name == "walrus" then
        fn = fns.walrus
    elseif name == "slurtle" then
        fn = fns.slurtle
    elseif name == "ruins" then
        fn = fns.ruins
        prefabs = { "forcefieldfx" }
    elseif name == "mole" then
        fn = fns.mole
    elseif name == "wathgrithr" then
        fn = fns.wathgrithr
    elseif name == "walter" then
        fn = fns.walter
    elseif name == "ice" then
        fn = fns.ice
    elseif name == "rain" then
        fn = fns.rain
    elseif name == "catcoon" then
        fn = fns.catcoon
    elseif name == "watermelon" then
        fn = fns.watermelon
    elseif name == "eyebrella" then
        fn = fns.eyebrella
    elseif name == "red_mushroom" then
        fn = fns.red_mushroom
    elseif name == "green_mushroom" then
        fn = fns.green_mushroom
    elseif name == "blue_mushroom" then
        fn = fns.blue_mushroom
    elseif name == "hive" then
        fn = fns.hive
    elseif name == "dragonhead" then
        fn = fns.dragon
    elseif name == "dragonbody" then
        fn = fns.dragon
    elseif name == "dragontail" then
        fn = fns.dragon
    elseif name == "desert" then
        fn = fns.desert
    elseif name == "goggles" then
        fn = fns.goggles
    elseif name == "moonstorm_goggles" then
        fn = fns.moonstorm_goggles
    elseif name == "skeleton" then
        fn = skeleton
    elseif name == "kelp" then
        fn = fns.kelp
    elseif name == "merm" then
        fn = fns.merm
    elseif name == "cookiecutter" then
        fn = fns.cookiecutter
    elseif name == "batnose" then
        fn = fns.batnose
        prefabs = {"hungerregenbuff"}
    elseif name == "nutrientsgoggles" then
        fn = fns.nutrientsgoggles
    elseif name == "plantregistry" then
        fn = fns.plantregistry
	elseif name == "balloon" then
		fn = fns.balloon
        prefabs = { "balloon_pop_head" }
		table.insert(assets, Asset("SCRIPT", "scripts/prefabs/balloons_common.lua"))
	elseif name == "alterguardian" then
        prefabs = {
            "alterguardian_hat_equipped",
            "alterguardianhatlight",
            "alterguardianhat_projectile",
            "alterguardianhatshard",
        }
        table.insert(assets, Asset("ANIM", "anim/ui_alterguardianhat_1x6.zip"))
        fn = fns.alterguardian
    elseif name == "monkey_medium" then
        fn = fns.monkey_medium
    elseif name == "monkey_small" then
        fn = fns.monkey_small
    elseif name == "polly_rogers" then
        prefabs = {"polly_rogers",}
        table.insert(assets, Asset("INV_IMAGE", "polly_rogershat2"))
        fn = fns.polly_rogers
	elseif name == "eyemask" then
        fn = fns.eyemask
    elseif name == "antlion" then
        prefabs = {
            "turf_smoke_fx",
        }
        table.insert(assets, Asset("ANIM", "anim/ui_antlionhat_1x1.zip"))
        fn = fns.antlion
    elseif name == "mask_doll" then
        fn = fns.mask  
    elseif name == "mask_dollbroken" then
        fn = fns.mask
    elseif name == "mask_dollrepaired" then
        fn = fns.mask
    elseif name == "mask_blacksmith" then
        fn = fns.mask
    elseif name == "mask_mirror" then
        fn = fns.mask
    elseif name == "mask_queen" then
        fn = fns.mask
    elseif name == "mask_king" then
        fn = fns.mask
    elseif name == "mask_tree" then
        fn = fns.mask
    elseif name == "mask_fool" then
        fn = fns.mask        
    elseif name == "nightcap" then
        fn = fns.nightcap
    elseif name == "dreadstone" then
    	fn = fns.dreadstone
    elseif name == "lunarplant" then
    	prefabs = { "lunarplanthat_fx" }
    	fn = fns.lunarplant
    end

    table.insert(ALL_HAT_PREFAB_NAMES, prefabname)

    return Prefab(prefabname, fn or default, assets, prefabs)
end

local function minerhatlightfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.Light:SetFalloff(0.4)
    inst.Light:SetIntensity(.7)
    inst.Light:SetRadius(2.5)
    inst.Light:SetColour(180 / 255, 195 / 255, 150 / 255)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

local function alterguardianhatlightfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(.8)
    inst.Light:SetRadius(4)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

local function lunarplanthatfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("lunarplanthat")
	inst.AnimState:SetBuild("hat_lunarplant")
	inst.AnimState:PlayAnimation("idle1", true)
	inst.AnimState:SetSymbolBloom("glow01")
	inst.AnimState:SetSymbolBloom("float_top")
	inst.AnimState:SetSymbolLightOverride("glow01", .5)
	inst.AnimState:SetSymbolLightOverride("float_top", .5)
	inst.AnimState:SetSymbolMultColour("float_top", 1, 1, 1, .6)
	inst.AnimState:SetLightOverride(.1)

	inst:AddComponent("highlightchild")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

local function tophatcontainerfn()
	local inst = CreateEntity()

	inst.entity:AddNetwork()

	inst:AddTag("CLASSIFIED")
	inst:Hide()

	inst:AddComponent("container_proxy")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.components.container_proxy:SetMaster(TheWorld:GetPocketDimensionContainer("shadow"))

	inst.persists = false

	return inst
end

return  MakeHat("straw"),
        MakeHat("top"),
        MakeHat("beefalo"),
        MakeHat("feather"),
        MakeHat("bee"),
        MakeHat("miner"),
        MakeHat("spider"),
        MakeHat("football"),
        MakeHat("earmuffs"),
        MakeHat("winter"),
        MakeHat("bush"),
        MakeHat("flower"),
        MakeHat("walrus"),
        MakeHat("slurtle"),
        MakeHat("ruins"),
        MakeHat("mole"),
        MakeHat("wathgrithr"),
        MakeHat("walter"),
        MakeHat("ice"),
        MakeHat("rain"),
        MakeHat("catcoon"),
        MakeHat("watermelon"),
        MakeHat("eyebrella"),
        MakeHat("red_mushroom"),
        MakeHat("green_mushroom"),
        MakeHat("blue_mushroom"),
        MakeHat("hive"),
        MakeHat("dragonhead"),
        MakeHat("dragonbody"),
        MakeHat("dragontail"),
        MakeHat("desert"),
        MakeHat("goggles"),
        MakeHat("moonstorm_goggles"),
        MakeHat("skeleton"),
        MakeHat("kelp"),
        MakeHat("merm"),
        MakeHat("cookiecutter"),
        MakeHat("batnose"),
        MakeHat("nutrientsgoggles"),
        MakeHat("plantregistry"),
        MakeHat("balloon"),
        MakeHat("alterguardian"),
        MakeHat("eyemask"),
        MakeHat("antlion"),

        MakeHat("mask_doll"),
        MakeHat("mask_dollbroken"),
        MakeHat("mask_dollrepaired"),
        MakeHat("mask_blacksmith"),
        MakeHat("mask_mirror"),
        MakeHat("mask_queen"),
        MakeHat("mask_king"),
        MakeHat("mask_tree"),
        MakeHat("mask_fool"),

        MakeHat("monkey_medium"),
        MakeHat("monkey_small"),
        MakeHat("polly_rogers"),

        MakeHat("nightcap"),

		MakeHat("dreadstone"),
		MakeHat("lunarplant"),

        Prefab("minerhatlight", minerhatlightfn),
        Prefab("alterguardianhatlight", alterguardianhatlightfn),
        Prefab("lunarplanthat_fx", lunarplanthatfxfn, { Asset("ANIM", "anim/hat_lunarplant.zip") }),

		Prefab("tophat_container", tophatcontainerfn)
