local assets =
{
    Asset("ANIM", "anim/queen_torch.zip"),
    Asset("SOUND", "sound/common.fsb"),
}

local prefabs =
{
    "torchfire",
	"queen_torch_fx"
}

------------------------
-- GLOBAL
local TORCHES = nil -- this actually stores the lights so its client friendly, not the torch itself

function FindClosestQueenTorchAtXZ(x, z)
	if not TORCHES then
		return nil
	end
	local mindsq = TUNING.QUEEN_TORCH_RADIUS_SQ
	local torch = nil

	for i, v in ipairs(TORCHES) do
		local dsq = v:GetDistanceSqToPoint(x, 0, z)
		if dsq <= mindsq then
			mindsq = dsq
			torch = v
		end
	end

	return torch
end

function FindClosestQueenTorch(inst)
	if not TORCHES then
		return nil
	end
    local x, y, z = inst.Transform:GetWorldPosition()
    return FindClosestQueenTorchAtXZ(x, z)
end

------------------------

local function applyskillbrightness(inst, value)
    if inst._light then
		inst._light.Light:SetRadius(5 * value)
    end
end

local function getskillbrightnesseffectmodifier(skilltreeupdater)
	return (skilltreeupdater:IsActivated("wilson_torch_6") and 12/6)
		or (skilltreeupdater:IsActivated("wilson_torch_5") and 10/6)
		or (skilltreeupdater:IsActivated("wilson_torch_4") and 8/6)
		or 1
end

local function RefreshAttunedSkills(inst, owner)
	local skilltreeupdater = owner and owner.components.skilltreeupdater or nil
	if skilltreeupdater then
		applyskillbrightness(inst, getskillbrightnesseffectmodifier(skilltreeupdater))
	else
		applyskillbrightness(inst, 1)
	end
end

local function WatchSkillRefresh(inst, owner)
	if inst._owner then
		inst:RemoveEventCallback("onactivateskill_server", inst._onskillrefresh, inst._owner)
		inst:RemoveEventCallback("ondeactivateskill_server", inst._onskillrefresh, inst._owner)
	end
	inst._owner = owner
	if owner then
		inst:ListenForEvent("onactivateskill_server", inst._onskillrefresh, owner)
		inst:ListenForEvent("ondeactivateskill_server", inst._onskillrefresh, owner)
	end
end

local function onequip(inst, owner)
    inst.components.burnable:Ignite()

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_queen_torch", inst.GUID, "queen_torch")
    else
        owner.AnimState:OverrideSymbol("swap_object", "queen_torch", "swap_queen_torch")
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

	if inst._fx ~= nil then
		inst._fx:Remove()
	end
    inst._fx = SpawnPrefab("queen_torch_fx", skin_build, inst.skin_id)
	inst._fx:AttachToOwner(owner)

    if inst._light == nil then
		inst._light = SpawnPrefab("queen_torchlight")
    end
	inst._light.entity:SetParent(owner.entity)

	WatchSkillRefresh(inst, owner)
	RefreshAttunedSkills(inst, owner)
end

local function onunequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end

    if inst._light ~= nil then
		inst._light:Remove()
		inst._light = nil
    end

    if inst._fx ~= nil then
        inst._fx:Remove()
        inst._fx = nil
    end

    inst.components.burnable:Extinguish()
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

	WatchSkillRefresh(inst, nil)
	RefreshAttunedSkills(inst, nil)
end

local function onequiptomodel(inst, owner, from_ground)

end

local function IgniteTossed(inst)
	inst.components.burnable:Ignite()

	if inst._light == nil then
		inst._light = SpawnPrefab("queen_torchlight")
	end
	inst._light.entity:SetParent(inst.entity)

    if inst.thrower then
		applyskillbrightness(inst, inst.thrower.brightnessmod or 1)
    end
end

local function OnThrown(inst, thrower)
	inst.thrower = thrower and thrower.components.skilltreeupdater and {
		brightnessmod = getskillbrightnesseffectmodifier(thrower.components.skilltreeupdater),
	} or nil
	inst.AnimState:PlayAnimation("spin_loop", true)
	inst.SoundEmitter:PlaySound("wilson_rework/torch/torch_spin", "spin_loop")
	IgniteTossed(inst)
	inst.components.inventoryitem.canbepickedup = false
end

local function OnHit(inst)
	inst.AnimState:PlayAnimation("idle", true)
	inst.SoundEmitter:KillSound("spin_loop")
	inst.SoundEmitter:PlaySound("wilson_rework/torch/stick_ground")
	inst.components.inventoryitem.canbepickedup = true
end

local LAUNCH_OFFSET = Vector3(0.25, 1, 0)
local DEFLECT_LAUNCH_OFFSET = Vector3(0, 0.5, 0)

local function OnDeflect(inst, attacker, deflector)
	inst.components.complexprojectile:Cancel()
	local pt = inst:GetPosition()
	local theta = deflector:GetAngleToPoint(pt) * DEGREES
	pt.x = pt.x + 3 * math.cos(theta)
	pt.z = pt.z - 3 * math.sin(theta)
	pt.y = 0
	inst.components.complexprojectile:SetHorizontalSpeed(5)
	inst.components.complexprojectile:SetLaunchOffset(DEFLECT_LAUNCH_OFFSET)
	inst.components.complexprojectile.usehigharc = false
	inst.components.complexprojectile:Launch(pt)
	inst.components.complexprojectile:SetHorizontalSpeed(15)
	inst.components.complexprojectile:SetLaunchOffset(LAUNCH_OFFSET)
	inst.components.complexprojectile.usehigharc = true
end

local function RemoveThrower(inst)
    if inst.thrower then
		if inst._owner == nil then
			applyskillbrightness(inst, 1)
		end
		inst.thrower = nil
    end
end

local function OnPutInInventory(inst, owner)
    RemoveThrower(inst)
	inst.thrower = owner and owner.components.skilltreeupdater and {
		brightnessmod = getskillbrightnesseffectmodifier(owner.components.skilltreeupdater),
	} or nil
	inst.AnimState:PlayAnimation("idle", true)

	if inst._light ~= nil then
		inst._light:Remove()
		inst._light = nil
	end

	inst.components.burnable:Extinguish()
end

local function OnDropped(inst)
	IgniteTossed(inst)
end

local function OnSave(inst, data)
	if inst.components.burnable:IsBurning() and not inst.components.inventoryitem:IsHeld() then
		if inst.thrower ~= nil then
			data.thrower = inst.thrower
		else
			data.lit = true
		end
	end
end

local function OnLoad(inst, data)
	if data ~= nil and (data.lit or data.thrower ~= nil) and not inst.components.inventoryitem:IsHeld() then
		inst.AnimState:PlayAnimation("idle", true)
		inst.thrower = data.thrower
		IgniteTossed(inst)
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("queen_torch.png")
	inst.MiniMapEntity:SetPriority(6)

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("queen_torch")
    inst.AnimState:SetBuild("queen_torch")
    inst.AnimState:PlayAnimation("idle", true)

    --waterproofer (from waterproofer component) added to pristine state for optimization
    inst:AddTag("waterproofer")
    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")
	--projectile (from complexprojectile component) added to pristine state for optimization
	inst:AddTag("projectile")
	inst:AddTag("complexprojectile")
	--Only get TOSS action via PointSpecialActions
    inst:AddTag("special_action_toss")
	inst:AddTag("keep_equip_toss")
	inst:AddTag("torch")
	inst:AddTag("gestaltflame")

	MakeInventoryFloatable(inst, "med", nil, 0.68)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.TORCH_DAMAGE)

    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
	inst.components.inventoryitem:SetOnPickupFn(RemoveThrower)
	inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable:SetOnEquipToModel(onequiptomodel)

	inst:AddComponent("complexprojectile")
	inst.components.complexprojectile:SetHorizontalSpeed(15)
	inst.components.complexprojectile:SetGravity(-35)
	inst.components.complexprojectile:SetLaunchOffset(LAUNCH_OFFSET)
	inst.components.complexprojectile:SetOnLaunch(OnThrown)
	inst.components.complexprojectile:SetOnHit(OnHit)
	inst.components.complexprojectile:SetOnDeflect(OnDeflect)
	inst.components.complexprojectile:SetKeepOnDeflect(true)
	inst.components.complexprojectile.ismeleeweapon = true

    inst:AddComponent("burnable")
    inst.components.burnable.canlight = false
    inst.components.burnable.fxprefab = nil
	-- inst.components.burnable:SetOnExtinguishFn(OnExtinguish)

	inst:AddComponent("stalkerinspectable")

    MakeHauntableLaunch(inst)

	inst._onskillrefresh = function(owner) RefreshAttunedSkills(inst, owner) end

	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	IgniteTossed(inst)

    return inst
end

--------------------------------------------------------------------------

local function FxAttachToOwner(inst, owner)
	inst.entity:SetParent(owner.entity)
	inst.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true)
	inst.components.highlightchild:SetOwner(owner)
	if owner.components.colouradder ~= nil then
		owner.components.colouradder:AttachChild(inst)
	end
end

local function fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

	inst.AnimState:SetBank("queen_torch")
    inst.AnimState:SetBuild("queen_torch")
    inst.AnimState:PlayAnimation("swap_loop1", true)

    inst:AddComponent("highlightchild")
	inst:AddComponent("colouraddersync")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.AttachToOwner = FxAttachToOwner
    inst.persists = false

    return inst
end

local function OnLightWake(inst)
    if not inst.SoundEmitter:PlayingSound("loop") then
        inst.SoundEmitter:PlaySound("dontstarve/common/queentorch_LP", "loop")
    end
end

local function OnLightSleep(inst)
    inst.SoundEmitter:KillSound("loop")
end

local function OnLightRemoveEntity(inst)
	table.removearrayvalue(TORCHES, inst)
	if next(TORCHES) == nil then
		TORCHES = nil
	end
end

local function torchlightfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

	inst.Light:SetIntensity(.6)
	inst.Light:SetRadius(6)
	inst.Light:SetFalloff(.8)
    inst.Light:SetColour(128 / 255, 162 / 255, 255 / 255)
	--
	if TORCHES == nil then
		TORCHES = {}
	end
	table.insert(TORCHES, inst)
	inst.OnRemoveEntity = OnLightRemoveEntity
	--

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst.OnEntityWake = OnLightWake
    inst.OnEntitySleep = OnLightSleep

    return inst
end

return Prefab("queen_torch", fn, assets, prefabs),
	Prefab("queen_torch_fx", fxfn, assets),
    Prefab("queen_torchlight", torchlightfn)
