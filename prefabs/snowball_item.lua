local assets =
{
    Asset("ANIM", "anim/snowball.zip"),
}

local prefabs =
{
	"snowman",
    "snowball_shatter_fx",
}

------------------------------------------------------------------------------------------------------

local function OnEquip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "snowball", "swap_object")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_object")
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

------------------------------------------------------------------------------------------------------

local function OnHit(inst, attacker, target)
    if not target:IsValid() then
        return -- Target killed or removed in combat damage phase.
    end

    if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
        target.components.sleeper:WakeUp()
    end

    if target.sg ~= nil and not target.sg:HasStateTag("frozen") then
        target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
    end

    if target ~= nil and target:IsValid() then
        if inst.components.wateryprotection ~= nil then
            inst.components.wateryprotection:SpreadProtection(target)
        end

        SpawnPrefab("splash_snow_fx").Transform:SetPosition(target.Transform:GetWorldPosition())
    end

    inst:Remove()
end

local function OnThrown(inst, data)
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.AnimState:PlayAnimation("spin_loop", true)

    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(.1)
    inst.Physics:SetDamping(0)
    inst.Physics:SetRestitution(.5)
    inst.Physics:SetCollisionGroup(COLLISION.ITEMS)
	inst.Physics:SetCollisionMask(COLLISION.GROUND)
    inst.Physics:SetSphere(.5)
    
    inst.components.inventoryitem.pushlandedevents = false
    inst.components.projectile:DelayVisibility(2*FRAMES)

    inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/firesupressor_shoot")
end

------------------------------------------------------------------------------------------------------

local function OnPerish(inst)
    local owner = inst.components.inventoryitem.owner -- Not grand owner!
    local stacksize = inst.components.stackable ~= nil and inst.components.stackable:StackSize() or 1

    if owner ~= nil then
        if owner.components.moisture ~= nil then
            owner.components.moisture:DoDelta(stacksize * TUNING.SNOWBALL_MELT_MOISTURE)

        elseif owner.components.inventoryitem ~= nil then
            owner.components.inventoryitem:AddMoisture(stacksize * TUNING.SNOWBALL_MELT_MOISTURE_ITEMS)
        end

        inst:Remove()
    else
        local x, y, z = inst.Transform:GetWorldPosition()

        TheWorld.components.farming_manager:AddSoilMoistureAtPoint(x, 0, z, stacksize * TUNING.SNOWBALL_MELT_MOISTURE_GROUND)

        if inst:IsAsleep() then
            inst:Remove()

            return
        end

        inst.persists = false
        inst.components.inventoryitem.canbepickedup = false

        inst:AddTag("NOCLICK")

        --inst.AnimState:PlayAnimation("melt") -- TODO: New anim?
        --inst:ListenForEvent("animover", inst.Remove)
        inst:Remove() -- FIXME: Remove this.
    end
end

------------------------------------------------------------------------------------------------------

local function OnFireMelt(inst)
    inst.components.perishable.frozenfiremult = true
end

local function OnStopFireMelt(inst)
    inst.components.perishable.frozenfiremult = false
end

------------------------------------------------------------------------------------------------------

local function OnUseAsWaterSource(inst)
    if inst.components.stackable ~= nil then
        inst.components.stackable:Get():Remove()
    else
        inst:Remove()
    end
end

------------------------------------------------------------------------------------------------------

local function OnStartPushing(inst, doer)
	local x, y, z = inst.Transform:GetWorldPosition()
	if inst.components.stackable:IsStack() then
		inst.components.stackable:Get():Remove()
		inst.components.pushable:StopPushing()
		inst.components.inventoryitem:DoDropPhysics(x, 0, z, true)
	else
		inst:Remove()
	end

	local snowman = SpawnPrefab("snowman")
	snowman.Transform:SetPosition(x, 0, z)
	snowman:SetSize("small")
	if inst.snowaccum then
		snowman.snowaccum = inst.snowaccum --transfer this back, doesn't matter if it gets lost XD
	end
	if snowman.components.pushable then
		snowman.components.pushable:StartPushing(doer)
		if doer and doer.sg then
			doer.sg:HandleEvent("pushable_targetswap", { old = inst, new = snowman })
		end
	end
end

------------------------------------------------------------------------------------------------------

local function OnDoMeltAction(inst)
    if not inst:IsAsleep() then
        local x, y, z = inst.Transform:GetWorldPosition()
        SpawnPrefab("snowball_shatter_fx").Transform:SetPosition(x, y, z)
    end
    inst:Remove()
end

local function OnPutInInventory(inst)
    inst.components.snowballmelting:StopMelting()
end

local function OnDropped(inst)
    inst.components.snowballmelting:AllowMelting()
end

------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("snowball")
    inst.AnimState:SetBuild("snowball")
	inst.AnimState:PlayAnimation("ground_small")

    inst:AddTag("frozen")
    inst:AddTag("icebox_valid")
    inst:AddTag("extinguisher")
    inst:AddTag("show_spoilage")
	inst:AddTag("pushing_roll") --for START_PUSHING action string => "Roll"

    -- watersource (from watersource component) added to pristine state for optimization.
    inst:AddTag("watersource")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    MakeInventoryFloatable(inst, "small", 0.05, .8)

	inst:AddComponent("snowmandecoratable")
	inst.components.snowmandecoratable:SetSize("small")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("tradable")
    inst:AddComponent("smotherer")
    inst:AddComponent("inspectable")

	inst:AddComponent("pushable")
	inst.components.pushable:SetOnStartPushingFn(OnStartPushing)

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_TWO_DAY)
    inst.components.perishable:StartPerishing()
    inst.components.perishable:SetOnPerishFn(OnPerish)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnStopFireMelt)

    inst:AddComponent("watersource")
    inst.components.watersource.onusefn = OnUseAsWaterSource
    inst.components.watersource.override_fill_uses = TUNING.SNOWBALL_WATERSOURCE_FILL_USES

    inst:AddComponent("wateryprotection")
    inst.components.wateryprotection.extinguishheatpercent = TUNING.SNOWBALL_EXTINGUISH_HEAT_PERCENT
    inst.components.wateryprotection.temperaturereduction = TUNING.SNOWBALL_TEMP_REDUCTION
    inst.components.wateryprotection.witherprotectiontime = TUNING.SNOWBALL_PROTECTION_TIME
    inst.components.wateryprotection.addcoldness = TUNING.SNOWBALL_ADD_COLDNESS
    inst.components.wateryprotection.protection_dist = TUNING.SNOWBALL_EFFECTS_DIST
    inst.components.wateryprotection:AddIgnoreTag("player")

    -------------------------------------------------------

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(0)
    inst.components.weapon:SetRange(8, 10)

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(15)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnThrownFn(OnThrown)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetHitDist(1.5)
    inst.components.projectile:SetRange(30)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable.equipstack = true

    -------------------------------------------------------

    inst:ListenForEvent("firemelt",     OnFireMelt    )
    inst:ListenForEvent("stopfiremelt", OnStopFireMelt)

    MakeHauntableLaunchAndSmash(inst)

    inst:AddComponent("snowballmelting")
    inst.components.snowballmelting:SetOnDoMeltAction(OnDoMeltAction)
    inst.components.snowballmelting:AllowMelting()

    inst:ListenForEvent("onputininventory", OnPutInInventory)
    inst:ListenForEvent("ondropped", OnDropped)

    return inst
end

return Prefab("snowball_item", fn, assets, prefabs)
