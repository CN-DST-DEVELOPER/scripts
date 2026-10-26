local assets =
{
	Asset("ANIM", "anim/pumpkin_bomb.zip"),
}

local prefabs =
{
	"pumpkin_bomb_explode_fx",
	"reticule",
	"reticuleaoe",
	"reticuleaoeping",
	"pumpkin_seeds",
}

local EXPLOSION_KNOCKBACK_DATA =
{
	forcelanded = false,
	forcepvp = true,
	radius = TUNING.PUMPKIN_BOMB_RANGE,
	strengthmult = 1,
}

local function ConfigureExplosive(inst, attacker, explodetarget) -- explodes immediately
	if TryLuckRoll(inst, TUNING.PUMPKIN_BOMB_SEED_CHANCE, LuckFormulas.LootDropperChance) then
		inst:AddComponent("lootdropper")
		inst.components.lootdropper:SpawnLootPrefab("pumpkin_seeds")
	end
	inst:AddComponent("explosive")
	inst.components.explosive.explosiverange = TUNING.PUMPKIN_BOMB_RANGE
	inst.components.explosive.explosivedamage = TUNING.PUMPKIN_BOMB_DAMAGE
	inst.components.explosive.buildingdamage = TUNING.PUMPKIN_BOMB_BUILDING_DAMAGE
	inst.components.explosive.lightonexplode = false
	if attacker then
		if inst.ispvp then
			inst.components.explosive:SetPvpAttacker(attacker)
		else
			inst.components.explosive:SetAttacker(attacker)
		end
	end
	inst.components.explosive:SetKnockbackData(EXPLOSION_KNOCKBACK_DATA)
	inst.components.explosive:OnBurnt(explodetarget)
end

local function ExplodeOnChew(inst, explodetarget) -- for worm_boss
	ConfigureExplosive(inst, nil, explodetarget)
end

local function OnHit(inst, attacker, target)
	local x, y, z = inst.Transform:GetWorldPosition()

	inst.SoundEmitter:KillSound("toss")

	ConfigureExplosive(inst, attacker, nil)
	--exploding should have removed me

	SpawnPrefab("pumpkin_bomb_explode_fx").Transform:SetPosition(x, y, z)
end

local function OnEquip(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_pumpkin_bomb", inst.GUID, "pumpkin_bomb")
	else
		owner.AnimState:OverrideSymbol("swap_object", "pumpkin_bomb", "swap_pumpkin_bomb")
	end
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end
end

local function onthrown(inst, attacker)
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.ispvp = attacker ~= nil and attacker:IsValid() and attacker:HasAnyTag("player", "possessedbody")

	inst.AnimState:PlayAnimation("spin_loop", true)
	inst.Transform:SetTwoFaced()

	inst.SoundEmitter:PlaySound("rifts/lunarthrall_bomb/throw", "toss")

	inst.Physics:SetMass(1)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(0)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(
		COLLISION.GROUND,
		COLLISION.OBSTACLES,
		COLLISION.ITEMS
	)
	inst.Physics:SetCapsule(.2, .2)
end

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

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst:AddTag("explosive")

	--projectile (from complexprojectile component) added to pristine state for optimization
	inst:AddTag("projectile")
	inst:AddTag("complexprojectile")

	inst.AnimState:SetBank("pumpkin_bomb")
	inst.AnimState:SetBuild("pumpkin_bomb")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetSymbolLightOverride("glow", 1)
	inst.AnimState:SetSymbolBloom("glow")

	inst:AddComponent("reticule")
	inst.components.reticule.twinstickcheckscheme = true
	inst.components.reticule.twinstickmode = 1
	inst.components.reticule.twinstickrange = 8
	inst.components.reticule.targetfn = ReticuleTargetFn
	inst.components.reticule.ease = true

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	MakeInventoryFloatable(inst, "small", 0.1, 0.8)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_weapondamage = TUNING.PUMPKIN_BOMB_DAMAGE

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")
	inst:AddComponent("stackable")

	inst:AddComponent("complexprojectile")
	inst.components.complexprojectile:SetHorizontalSpeed(15)
	inst.components.complexprojectile:SetGravity(-35)
	inst.components.complexprojectile:SetLaunchOffset(Vector3(.25, 1, 0))
	inst.components.complexprojectile:SetOnLaunch(onthrown)
	inst.components.complexprojectile:SetOnHit(OnHit)

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(0)
	inst.components.weapon:SetRange(8, 10)

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnequip)
	inst.components.equippable.equipstack = true

	inst.ExplodeOnChew = ExplodeOnChew -- for worm_boss

	MakeHauntableLaunch(inst)

	return inst
end

--------------------------------------------------------------------------

local function PlayExplodeSound(inst)
	inst.SoundEmitter:PlaySound("rifts/lunarthrall_bomb/explode") -- TODO
end

local function CreatePumpkinChunk()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddPhysics()

	inst.Physics:SetMass(1)
	inst.Physics:SetFriction(.4)
	inst.Physics:SetDamping(0)
	inst.Physics:SetRestitution(.5)
	inst.Physics:SetCollisionMask(COLLISION.WORLD)
	inst.Physics:SetSphere(.5)

	MakeInventoryPhysics(inst)
	inst:AddTag("FX")

	inst.AnimState:SetBank("pumpkin_bomb")
	inst.AnimState:SetBuild("pumpkin_bomb")

	return inst
end


local function CreateSplash() -- cant spawn "splash" because is networked entity
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.AnimState:SetBank("splash")
	inst.AnimState:SetBuild("splash")
	inst.AnimState:PlayAnimation("splash")
	inst.AnimState:SetFinalOffset(1)

	return inst
end

local function fx_TestChunkFloat(inst, parentfx)
	if ShouldEntitySink(inst, true) then
		local splash = CreateSplash()
		splash.Transform:SetPosition(inst.Transform:GetWorldPosition())
		parentfx.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/bird")

    	inst.front_fx = SpawnPrefab("float_fx_front")
		inst.front_fx.entity:SetParent(inst.entity)
    	inst.front_fx.AnimState:PlayAnimation("idle_front_small", true)

    	inst.back_fx = SpawnPrefab("float_fx_back")
		inst.back_fx.entity:SetParent(inst.entity)
    	inst.back_fx.AnimState:PlayAnimation("idle_back_small", true)
	end
end

local function fx_DoErode(inst)
	ErodeAway(inst)
	if inst.front_fx then
		ErodeAway(inst.front_fx)
	end
	if inst.back_fx then
		ErodeAway(inst.back_fx)
	end
end

local function fx_TossChunks(inst)
	local x, _, z = inst.Transform:GetWorldPosition()
	local networkid = inst.Network:GetNetworkID()
	local prng = PRNG_Uniform(math.floor(x + 0.5) * math.floor(z + 0.5) * networkid)
	local chunkcount = prng:RandInt(6, 7)
	local theta0 = prng:Rand() * TWOPI
	local delta = TWOPI / chunkcount
	local radius = 0.5
	local vars = { 1, 2, 3, 4, 5, 6, prng:RandInt(6), prng:RandInt(6) }
	for i = 1, chunkcount do
		local theta = theta0 + (i + prng:Rand() * 0.5) * delta
		local cos_theta = math.cos(theta)
		local sin_theta = math.sin(theta)
		local speed = 3 + prng:Rand() * 1
		local chunk = CreatePumpkinChunk()
		if prng:Rand() < .5 then
			chunk.AnimState:SetScale(-1, 1)
		end
		if not TryTeleportToLaunchPos(chunk, x + cos_theta * radius, 0.5, z - sin_theta * radius) then
			chunk.Physics:Teleport(x, 0.5, z)
		end
		chunk.Physics:SetVel(speed * cos_theta, 4 + prng:Rand() * 3, -speed * sin_theta)
		local var = table.remove(vars, prng:RandInt(#vars))
		chunk.AnimState:PlayAnimation("debris_0"..tostring(var))
		chunk:DoTaskInTime((12 + prng:RandInt(0, 2)) * FRAMES, fx_TestChunkFloat, inst)
		chunk:DoTaskInTime(1.5 + prng:Rand() * .25, fx_DoErode)
	end
end

local function fx_OnEntityWake(inst)
	fx_TossChunks(inst)
	inst.OnEntityWake = nil
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("pumpkin_bomb")
	inst.AnimState:SetBuild("pumpkin_bomb")
	inst.AnimState:PlayAnimation("used")

	inst.OnEntityWake = fx_OnEntityWake

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:DoTaskInTime(0, PlayExplodeSound)

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("pumpkin_bomb", fn, assets, prefabs),
	Prefab("pumpkin_bomb_explode_fx", fxfn, assets)
