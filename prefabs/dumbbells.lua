local assets =
{
    Asset("ANIM", "anim/dumbbell.zip"),
    Asset("ANIM", "anim/dumbbell_golden.zip"),
    Asset("ANIM", "anim/dumbbell_gem.zip"),

    Asset("ANIM", "anim/swap_dumbbell.zip"),
    Asset("ANIM", "anim/swap_dumbbell_golden.zip"),
    Asset("ANIM", "anim/swap_dumbbell_gem.zip"),
}

local prefabs = 
{
}

local function ReticuleTargetFn()
    local player = ThePlayer
    local ground = TheWorld.Map
    local pos = Vector3()
    --Attack range is 8, leave room for error
    --Min range was chosen to not hit yourself (2 is the hit range)
    for r = 6.5, 3.5, -.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
        if ground:IsPassableAtPoint(pos:Get()) and not ground:IsGroundTargetBlocked(pos) then
            return pos
        end
    end
    return pos
end

local function HasFriendlyLeader(inst, target)
    local target_leader = (target.components.follower ~= nil) and target.components.follower.leader or nil
    
    if target_leader ~= nil then

        if target_leader.components.inventoryitem then
            target_leader = target_leader.components.inventoryitem:GetGrandOwner()
        end

        local PVP_enabled = TheNet:GetPVPEnabled()
        return (target_leader ~= nil 
                and (target_leader:HasTag("player") 
                and not PVP_enabled)) or
                (target.components.domesticatable and target.components.domesticatable:IsDomesticated() 
                and not PVP_enabled) or
                (target.components.saltlicker and target.components.saltlicker.salted
                and not PVP_enabled)
    end

    return false
end

local function CanDamage(inst, target)
    if target.components.minigame_participator ~= nil or target.components.combat == nil then
		return false
	end

    if target:HasTag("player") and not TheNet:GetPVPEnabled() then
        return false
    end

    if target:HasTag("playerghost") and not target:HasTag("INLIMBO") then
        return false
    end

    if target:HasTag("monster") and not TheNet:GetPVPEnabled() and 
       ((target.components.follower and target.components.follower.leader ~= nil and 
         target.components.follower.leader:HasTag("player")) or target.bedazzled) then
        return false
    end

    if HasFriendlyLeader(inst, target) then
        return false
    end

    return true
end

local function ResetPhysics(inst)
	inst.Physics:SetFriction(0.1)
	inst.Physics:SetRestitution(0.5)
	inst.Physics:SetCollisionGroup(COLLISION.ITEMS)
	inst.Physics:ClearCollisionMask()
	inst.Physics:CollidesWith(COLLISION.WORLD)
	inst.Physics:CollidesWith(COLLISION.OBSTACLES)
	inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
end

local function onthrown(inst)
    inst:AddTag("NOCLICK")
    inst.persists = false

    local attacker = inst.components.complexprojectile.attacker
    if attacker then
        inst.components.mightydumbbell:DoAttackWorkout(attacker)
    end
    
    inst.AnimState:PlayAnimation("spin_loop", true)
    inst.SoundEmitter:PlaySound("wolfgang1/dumbbell/throw_twirl", "spin_loop")

    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.GROUND)
    inst.Physics:CollidesWith(COLLISION.OBSTACLES)
    inst.Physics:CollidesWith(COLLISION.ITEMS)
end

local function OnHit(inst, attacker, target)
    local pt = Vector3(inst.Transform:GetWorldPosition())
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 2, nil, {"FX", "NOCLICK", "DECOR", "INLIMBO"})
    for i,ent in ipairs(ents) do
        if CanDamage(inst, ent) then
            ent.components.combat:GetAttacked(attacker, inst.components.weapon.damage)
        end
    end

    SpawnPrefab("round_puff_fx_sm").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst.AnimState:PlayAnimation("land")
    inst.AnimState:PushAnimation("idle", true)

    inst:RemoveTag("NOCLICK")
    inst.persists = true

    inst.SoundEmitter:KillSound("spin_loop")
    inst.SoundEmitter:PlaySound(inst.impact_sound)

    inst.components.finiteuses:Use(inst.attack_consumption)

    if inst.components.finiteuses:GetUses() > 0 then
        ResetPhysics(inst) 
    end
end

local function MakeTossable(inst)
    inst.components.weapon:SetRange(8, 10)

    if inst.components.complexprojectile == nil then
        inst:AddComponent("complexprojectile")
        inst.components.complexprojectile:SetHorizontalSpeed(15)
        inst.components.complexprojectile:SetGravity(-35)
        inst.components.complexprojectile:SetLaunchOffset(Vector3(1, 1, 0))
        inst.components.complexprojectile:SetOnLaunch(onthrown)
        inst.components.complexprojectile:SetOnHit(OnHit)
    end

    inst:RemoveTag("punch")
end

local function RemoveTossable(inst)
    inst.components.weapon:SetRange(nil, nil)

    if inst.components.complexprojectile ~= nil then
        inst:RemoveComponent("complexprojectile")
    end

    inst:AddTag("punch")
end

local function CheckMightiness(inst, data)
    local dumbbell = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if data and dumbbell then
        if data.state == "mighty" then
            MakeTossable(dumbbell)
        else
            RemoveTossable(dumbbell)
        end
    end
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", inst.swap_dumbbell, inst.swap_dumbbell)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    CheckMightiness(owner, {state = owner.components.mightiness:GetState()} )

    inst:ListenForEvent("mightiness_statechange", CheckMightiness, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    
    if inst:HasTag("lifting") then
        owner:PushEvent("stopliftingdumbbell", {instant = true})
    end

    inst:RemoveEventCallback("mightiness_statechange", CheckMightiness, owner)
end

local function OnAttack(inst, attacker, target)
    inst.components.mightydumbbell:DoAttackWorkout(attacker)
end

local function OnPickup(inst, owner)
    if owner then
        if owner:HasTag("mightiness_mighty") then
            MakeTossable(inst)
        else
            RemoveTossable(inst)
        end
    end
end

local function MakeDumbbell(name, consumption, efficiency, damage, attack_consumption, impact_sound)
    local function fn()
        local inst = CreateEntity()
    
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()
    
        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle", true)
        MakeInventoryPhysics(inst)
    
        MakeInventoryFloatable(inst, "small", 0.15, 0.9)

        inst:AddTag("dumbbell")

        inst:AddComponent("reticule")
        inst.components.reticule.targetfn = ReticuleTargetFn
        inst.components.reticule.ease = true

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end
    
        inst:AddComponent("inventoryitem")
        inst:AddComponent("inspectable")
        
        inst:AddComponent("equippable")
        inst.components.equippable:SetOnEquip(onequip)
        inst.components.equippable:SetOnUnequip(onunequip)
        inst.components.equippable.restrictedtag = "strongman"

        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(damage)
        inst.components.weapon:SetOnAttack(OnAttack)
        inst.components.weapon.attackwear = attack_consumption

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetOnFinished(function() 
            if inst.components.inventoryitem:GetGrandOwner() == nil then
                inst.components.inventoryitem.canbepickedup = false
                inst:DoTaskInTime(1, ErodeAway)
            else
                inst:Remove()        
            end
        end)

        MakeHauntableLaunch(inst)
    
        inst:AddComponent("mightydumbbell")
        inst.components.mightydumbbell:SetConsumption(consumption)
        inst.components.mightydumbbell:SetEfficiency(efficiency[1], efficiency[2], efficiency[3])

        inst.swap_dumbbell = "swap_" .. name
        inst.attack_consumption = attack_consumption
        inst.impact_sound = impact_sound

        inst:ListenForEvent("onputininventory", OnPickup)

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

return MakeDumbbell("dumbbell",        TUNING.DUMBBELL_CONSUMPTION,        { TUNING.DUMBBELL_EFFICIENCY_HIGH, TUNING.DUMBBELL_EFFICIENCY_MED,  TUNING.DUMBBELL_EFFICIENCY_LOW  }, TUNING.DUMBBELL_DAMAGE,        TUNING.DUMBBELL_ATTACK_CONSUMPTION,        "wolfgang1/dumbbell/stone_impact"),
       MakeDumbbell("dumbbell_golden", TUNING.DUMBBELL_GOLDEN_CONSUMPTION, { TUNING.DUMBBELL_EFFICIENCY_HIGH, TUNING.DUMBBELL_EFFICIENCY_HIGH, TUNING.DUMBBELL_EFFICIENCY_LOW  }, TUNING.DUMBBELL_GOLDEN_DAMAGE, TUNING.DUMBBELL_GOLDEN_ATTACK_CONSUMPTION, "wolfgang1/dumbbell/gold_impact"),
       MakeDumbbell("dumbbell_gem",    TUNING.DUMBBELL_GEM_CONSUMPTION,    { TUNING.DUMBBELL_EFFICIENCY_HIGH, TUNING.DUMBBELL_EFFICIENCY_HIGH, TUNING.DUMBBELL_EFFICIENCY_HIGH }, TUNING.DUMBBELL_GEM_DAMAGE,    TUNING.DUMBBELL_GEM_ATTACK_CONSUMPTION,    "wolfgang1/dumbbell/gem_impact")