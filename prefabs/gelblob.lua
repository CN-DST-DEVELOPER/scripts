local assets =
{
	Asset("ANIM", "anim/gelblob.zip"),
}

local prefabs =
{
	"gelblob_back_fx",
	"gelblob_attach_fx",
	"gelblob_small_fx",
	"gelblob_item_fx",
}

SetSharedLootTable("gelblob",
{
	{ "nightmarefuel", 1.0 },
	{ "nightmarefuel", 1.0 },
	{ "nightmarefuel", 1.0 },
	{ "nightmarefuel", 1.0 },
	{ "nightmarefuel", 0.8 },
	{ "nightmarefuel", 0.6 },
})

--------------------------------------------------------------------------

local LEFT_PROPS =
{
	"prop_eyes_L1",
	"prop_eyes_L2",
	"prop_horns_L1",
	"prop_teeth_L1",
	"prop_teeth_L2",
	"prop_teeth_L3",
}

local RIGHT_PROPS =
{
	"prop_eyes_R1",
	"prop_eyes_R2",
	"prop_horns_R1",
	"prop_horns_R2",
	"prop_teeth_R1",
	"prop_teeth_R2",
	"prop_teeth_R3",
}

local function SetVariation(inst, leftvars, rightvars)
	if leftvars == nil then
		leftvars, rightvars = 0, 0

		local num = math.random(5, 10)
		local numleft = num / 2
		numleft = math.random(math.floor(numleft), math.ceil(numleft))
		local numright = num - numleft

		local propids = {}
		for i = 1, #LEFT_PROPS do
			propids[i] = i
		end
		for i = 1, numleft do
			local id = table.remove(propids, math.random(#propids))
			leftvars = bit.bor(leftvars, bit.lshift(1, id - 1))
		end

		for i = 1, #RIGHT_PROPS do
			propids[i] = i
		end
		for i = #RIGHT_PROPS + 1, #LEFT_PROPS do
			propids[i] = nil
		end
		for i = 1, numright do
			local id = table.remove(propids, math.random(#propids))
			rightvars = bit.bor(rightvars, bit.lshift(1, id - 1))
		end
	end

	inst.leftvars, inst.rightvars = leftvars, rightvars

	for i, v in ipairs(LEFT_PROPS) do
		if bit.band(leftvars, bit.lshift(1, i - 1)) ~= 0 then
			inst.AnimState:ShowSymbol(v)
		else
			inst.AnimState:HideSymbol(v)
		end
	end

	for i, v in ipairs(RIGHT_PROPS) do
		if bit.band(rightvars, bit.lshift(1, i - 1)) ~= 0 then
			inst.AnimState:ShowSymbol(v)
		else
			inst.AnimState:HideSymbol(v)
		end
	end
end

--------------------------------------------------------------------------

local CHUNK_RETURN_ACCEL = 0.0825

local NUM_SIZES = 3
local LEVELS_PER_SIZE = 3
local HEALTH_SEGS_PER_SIZE = LEVELS_PER_SIZE - 1
local NUM_LEVELS = NUM_SIZES * LEVELS_PER_SIZE
local NUM_HEALTH_SEGS = NUM_SIZES * HEALTH_SEGS_PER_SIZE

local REGISTERED_PROXIMITY_TAGS = rawget(_G, "TheSim") and TheSim:RegisterFindTags({ "locomotor" }, { "INLIMBO", "flight", "invisible", "notarget", "noattack", "ghost", "playerghost", "shadowthrall", "shadow", "shadowcreature", "shadowminion", "shadowchesspiece" }) or {}
local PHYSICS_PADDING = 3
local NEAR_RADIUS = 3

local function OnUpdateProximity(inst, fast)
	if inst.sg and inst.sg:HasStateTag("spawning") then
		for k, v in pairs(inst._targets) do
			v:KillFX()
			inst._targets[k] = nil
		end
		return
	end

	--swap the tables
	local temp = inst._targets
	inst._targets = inst._untargets
	inst._untargets = temp

	--near does not necessarily mean we have contact, just that there is
	--something close enough so we should increase our update frequency.
	local near = false
	local contacted = false
	local uncontacted = false

	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities_Registered(x, y, z, NEAR_RADIUS + PHYSICS_PADDING, REGISTERED_PROXIMITY_TAGS)) do
		local dsq = v:GetDistanceSqToPoint(x, y, z)

		if inst._suspend_radius and
			inst._suspendedplayer == nil and
			inst.size == "_big" and
			v.isplayer and
			v.sg and not v.sg:HasStateTag("suspended") and
			not (v.components.rider and v.components.rider:IsRiding()) and
			not v:HasTag("wereplayer") and
			dsq < inst._suspend_radius * inst._suspend_radius
		then
			v:PushEvent("suspended", inst)
		end

		local rad = v:GetPhysicsRadius(0)
		local fx = inst._untargets[v]
		local range = rad + (fx and inst._uncontact_radius or inst._contact_radius)
		if dsq < range * range then
			if not (v.sg and v.sg:HasStateTag("suspended")) then
				if fx then
					inst._untargets[v] = nil
				else
					fx = SpawnPrefab("gelblob_attach_fx")
					fx:SetupBlob(inst, v)
					contacted = true
				end
				inst._targets[v] = fx
			end
		elseif not near then
			range = rad + NEAR_RADIUS
			near = dsq < range * range
		end
	end

	for k, v in pairs(inst._untargets) do
		v:KillFX()
		inst._untargets[k] = nil
		uncontacted = true
	end

	if fast ~= near then
		inst._proximitytask:Cancel()
		inst._proximitytask = inst:DoPeriodicTask(near and 0.1 or 0.5, OnUpdateProximity, nil, near)
	end

	if contacted or uncontacted then
		inst:OnContactChanged(contacted, uncontacted)
	end
end

local function OnSpawnLanded(inst)
	if inst._proximitytask then
		OnUpdateProximity(inst, nil) --nil will force it to restart the periodic task timer
	end
end

local function OnContactChanged(inst, contacted, uncontacted)
	if contacted then
		inst.sg:HandleEvent("jiggle")
	end
end

local function CollectEquip(item, inst, ret)
	if not (	item.components.equippable:ShouldPreventUnequipping() or
				item.components.equippable:IsRestricted(inst) or
				item:HasTag("nosteal") or
				(item.components.equippable.equipslot == EQUIPSLOTS.HANDS and inst._suspendedplayer:HasTag("stronggrip"))
			)
	then
		table.insert(ret, item)
	end
end

local function StealSuspendedEquip(inst)
	local inventory = inst._suspendedplayer and inst._suspendedplayer:IsValid() and inst._suspendedplayer.components.inventory or nil
	if inventory then
		local ret = {}
		inventory:ForEachEquipment(CollectEquip, inst, ret)
		if #ret > 0 then
			local item = ret[math.random(#ret)]
			inventory:Unequip(item.components.equippable.equipslot)
			inst.components.inventory:Equip(item)
		end
	end
end

local function ReleaseSuspended(inst, explode)
	if inst._suspendedtask then
		inst._suspendedtask:Cancel()
		inst._suspendedtask = nil
	end
	inst._digestcount = nil
	if inst._suspendedplayer then
		local player = inst._suspendedplayer
		inst._suspendedplayer = nil
		if player:IsValid() then
			player:PushEvent("spitout", { spitter = inst, radius = 1, strengthmult = 0.6, rot = math.random() * 360 })
			player:PushEvent("exit_gelblob", inst)
			if explode then
				inst.components.health:SetMaxDamageTakenPerHit(nil)
				inst.components.health:DoDelta(-0.5 * TUNING.GELBLOB_HEALTH)
				inst.components.health:SetMaxDamageTakenPerHit(TUNING.GELBLOB_HEALTH / NUM_SIZES)
				inst.SoundEmitter:PlaySound("rifts4/goop/spit_out")
			end
		end
	end
end

local function IsSuspending(inst, target)
	return target
		and target:IsValid()
		and target.sg
		and target.sg:HasStateTag("suspended")
		and target.sg.statemem.attacker == inst
end

local function DoDigest(inst, target, useimpactsound)
	if not useimpactsound then
		inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_med_dull")
	end
	if IsSuspending(inst, target) then
		local dmg, spdmg = inst.components.combat:CalcDamage(target)
		local noimpactsound = target.components.combat.noimpactsound
		target.components.combat.noimpactsound = not useimpactsound
		target.components.combat:GetAttacked(inst, dmg, nil, nil, spdmg)
		target.components.combat.noimpactsound = noimpactsound
	end
end

local function OnUpdateSuspended2(inst)
	DoDigest(inst, inst._suspendedplayer, true)
	StealSuspendedEquip(inst)
	ReleaseSuspended(inst, true)
end

local function OnUpdateSuspended(inst)
	if inst._digestcount < 3 then
		inst._digestcount = inst._digestcount + 1
		DoDigest(inst, inst._suspendedplayer)
		inst.sg:HandleEvent("jiggle")
	else
		inst._suspendedplayer:PushEvent("abouttospit")
		inst.sg:GoToState("spit")
		inst._suspendedtask:Cancel()
		inst._suspendedtask = inst:DoTaskInTime(38 * FRAMES, OnUpdateSuspended2)
	end
end

local function OnPlayerSuspended(inst, player)
	if inst._suspendedplayer ~= player and
		IsSuspending(inst, player) and
		not inst.components.health:IsDead()
	then
		inst.components.inventory:DropEverything()
		ReleaseSuspended(inst, false)
		inst._digestcount = 0
		inst._suspendedplayer = player
		inst._suspendedtask = inst:DoPeriodicTask(0.5, OnUpdateSuspended, 1)
		inst.sg:HandleEvent("jiggle")
		inst.SoundEmitter:PlaySound("rifts4/goop/absorb")
	end
end

local function OnSuspendedPlayerDied(inst, player)
	if inst._suspendedplayer == player then
		StealSuspendedEquip(inst)
		ReleaseSuspended(inst, true)
	end
end

local function OnDeath(inst)
	ReleaseSuspended(inst, false)
	if inst._proximitytask then
		inst._proximitytask:Cancel()
		inst._proximitytask = nil
	end
	for k, v in pairs(inst._targets) do
		v:KillFX()
		inst._targets[k] = nil
	end
	inst.components.inventory:DropEverything()
	inst.components.lootdropper:DropLoot()
	if inst:IsAsleep() then
		inst:Remove()
	else
		inst:AddTag("NOCLICK")
		inst.persists = false
	end
end

local function DoDespawn(inst)
	if not inst.components.health:IsDead() then
		inst.despawning = true
		inst.components.lootdropper:SetChanceLootTable(nil)
		inst.components.health:Kill()
	end
end

local function OnEntityWake(inst)
	if inst._proximitytask == nil and inst.persists then
		inst._proximitytask = inst:DoPeriodicTask(0.5, OnUpdateProximity, math.random() * 0.1, false)
	end
end

local function OnEntitySleep(inst)
	if inst._proximitytask then
		inst._proximitytask:Cancel()
		inst._proximitytask = nil
	end
	for k, v in pairs(inst._targets) do
		v:Remove()
		inst._targets[k] = nil
	end
end

local function OnRemoveEntity(inst)
	for k, v in pairs(inst._targets) do
		v:KillFX()
		inst._targets[k] = nil
	end
end

local function KeepTargetFn(inst, target)
	return false
end

local function CalcLevel(healthpct)
	local seg = math.clamp(math.ceil(healthpct * NUM_HEALTH_SEGS), 0, NUM_HEALTH_SEGS)
	return seg + math.ceil(seg / HEALTH_SEGS_PER_SIZE)
end

local function OnHealthDelta(inst, data)
	if data and data.amount < 0 then
		local newlevel = CalcLevel(data.newpercent)
		if newlevel < inst.level then
			local sizechanged = false
			if newlevel <= 0 then
				if inst.level > 0 then
					sizechanged = true
				end
			elseif newlevel <= LEVELS_PER_SIZE then
				if inst.level > LEVELS_PER_SIZE then
					sizechanged = true
					ReleaseSuspended(inst, false)
					inst.sg:GoToState("shrink_small")
				end
			elseif newlevel <= LEVELS_PER_SIZE * 2 then
				if inst.level > LEVELS_PER_SIZE * 2 then
					sizechanged = true
					StealSuspendedEquip(inst)
					ReleaseSuspended(inst, false)
					inst.sg:GoToState("shrink_med")
				end
			end

			local x, y, z = inst.Transform:GetWorldPosition()
			local numchunks = inst.level - newlevel + (newlevel == 0 and 1 or 0)
			if inst.despawning then
				numchunks = inst:IsAsleep() and 0 or math.min(3, numchunks)
			end
			local theta = math.random() * TWOPI
			local delta = TWOPI / numchunks
			for i = 1, numchunks do
				local dist = (newlevel == 0 and 1.5 or 3) + math.random() * 3
				local angle = theta + delta * (i + math.random() * 0.75)
				local chunk = SpawnPrefab("gelblob_small_fx")
				chunk.Transform:SetPosition(x, 0, z)
				chunk.components.entitytracker:TrackEntity("mainblob", inst)
				chunk:Toss(dist, angle)
			end

			inst.level = newlevel
		end
	end
end

local function Absorb(inst)
	if not inst.components.health:IsDead() then
		local newlevel = math.min(NUM_LEVELS, inst.level + 1)
		if newlevel > LEVELS_PER_SIZE * 2 then
			if inst.level <= LEVELS_PER_SIZE * 2 then
				inst.sg:GoToState("grow_big")
			end
		elseif newlevel > LEVELS_PER_SIZE then
			if inst.level <= LEVELS_PER_SIZE then
				inst.sg:GoToState("grow_med")
			end
		end
		inst.level = newlevel

		local health_per_level = TUNING.GELBLOB_HEALTH / NUM_LEVELS
		inst.components.health:DoDelta(math.max(health_per_level, newlevel * health_per_level - inst.components.health.currenthealth))

		inst.sg:HandleEvent("jiggle")
	end
end

local function OnSave(inst, data)
	data.level = inst.level < NUM_LEVELS and inst.level or nil
	data.leftvars, data.rightvars = inst.leftvars, inst.rightvars
end

local function OnLoad(inst, data)--, ents)
	inst.level = data.level or NUM_LEVELS

	if data.leftvars and data.rightvars then
		SetVariation(inst, data.leftvars, data.rightvars)
	end

	local size =
		(inst.level <= LEVELS_PER_SIZE and "_small") or
		(inst.level <= LEVELS_PER_SIZE * 2 and "_med") or
		"_big"

	if inst.size ~= size then
		inst.size = size
		if inst.sg:HasStateTag("idle") then
			inst.sg:GoToState("idle")
			inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
		end
	end
end

local function SuspendItem(inst, item)
	ReleaseSuspended(inst, false)
	inst.components.inventory:DropEverything()
	inst.components.inventory:Equip(item)
end

local function OnEquip(inst, data)
	if data then
		if data.eslot == EQUIPSLOTS.HANDS then
			inst.AnimState:ShowSymbol("swap_object")
		elseif data.eslot == EQUIPSLOTS.BODY then
			if data.item and data.item:HasTag("backpack") then
				inst.AnimState:Show("backpack")
			else
				inst.AnimState:Hide("backpack")
			end
		end
	end
end

--Hand objects don't clear override symbol when unequipped
local function OnUnequip(inst, data)
	if data then
		if data.eslot == EQUIPSLOTS.HANDS then
			inst.AnimState:HideSymbol("swap_object")
		elseif data.eslot == EQUIPSLOTS.BODY then
			inst.AnimState:Hide("backpack")
		end
	end
end

local ITEM_SPLASH_DIST = 2
local function OnDropItem(inst, data)
	if data and data.item and data.item:IsValid() and
		data.item.components.inventoryitem and
		not data.item.components.inventoryitem.is_landed
	then
		local fx = SpawnPrefab("gelblob_item_fx")
		fx.entity:SetParent(data.item.entity)
		fx:ListenForEvent("on_landed", function(item) fx:KillFX() end, data.item)
		fx:ListenForEvent("onputininventory", function(item) fx:Remove() end, data.item)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(1)
	inst:SetDeploySmartRadius(1.5)
	inst.DynamicShadow:SetSize(4.5, 2.5)

	inst:AddTag("blocker")
	inst:AddTag("shadow_aligned")
	inst:AddTag("stronggrip")
	inst:AddTag("equipmentmodel")

	inst.AnimState:SetBank("gelblob")
	inst.AnimState:SetBuild("gelblob")
	inst.AnimState:PlayAnimation("idle_big", true)
	inst.AnimState:SetFinalOffset(7)
	inst.AnimState:Hide("BACK")
	inst.AnimState:Hide("backpack")

	inst.highlightchildren = {}

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "idle_big"

	inst.size = "_big"
	inst.level = NUM_LEVELS
	inst.leftvars, inst.rightvars = nil, nil
	inst._contact_radius = 1.2
	inst._uncontact_radius = 1.35
	inst._suspend_radius = 0.5
	inst._suspendedplayer = nil
	inst._suspendedtask = nil
	inst._digestcount = nil
	inst._targets = {}
	inst._untargets = {}

	inst.back = SpawnPrefab("gelblob_back_fx")
	inst.back.entity:SetParent(inst.entity)

	SetVariation(inst, nil, nil)

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.GELBLOB_HEALTH)
	inst.components.health:SetMaxDamageTakenPerHit(TUNING.GELBLOB_HEALTH / NUM_SIZES)
	inst.components.health.nofadeout = true
	inst:ListenForEvent("healthdelta", OnHealthDelta)

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.GELBLOB_DAMAGE)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.GELBLOB_PLANAR_DAMAGE)

	inst:AddComponent("inspectable")

	inst:AddComponent("inventory")
	inst.components.inventory.maxslots = 0
	inst.components.inventory.ignorecombat = true

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("gelblob")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

	inst:SetStateGraph("SGgelblob")
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:ListenForEvent("equip", OnEquip)
	inst:ListenForEvent("unequip", OnUnequip)
	inst:ListenForEvent("dropitem", OnDropItem)
	inst:ListenForEvent("playersuspended", OnPlayerSuspended)
	inst:ListenForEvent("suspendedplayerdied", OnSuspendedPlayerDied)
	inst:ListenForEvent("death", OnDeath)

	inst.OnSpawnLanded = OnSpawnLanded
	inst.Absorb = Absorb
	inst.OnContactChanged = OnContactChanged
	inst.SuspendItem = SuspendItem
	inst.DoDespawn = DoDespawn
	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep
	inst.OnRemoveEntity = OnRemoveEntity
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

local function backfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("gelblob")
	inst.AnimState:SetBuild("gelblob")
	inst.AnimState:PlayAnimation("idle_big", true)
	inst.AnimState:SetFinalOffset(-7)
	inst.AnimState:Hide("FRONT")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function Small_OnContactChanged(inst, contacted, uncontacted)
	if next(inst._targets) then
		if not inst._squished then
			inst._squished = true
			inst.AnimState:PlayAnimation("blob_med_to_squish")
			inst.AnimState:PushAnimation("blob_attach_middle_loop")
		end
	elseif inst._squished then
		inst._squished = false
		inst.AnimState:PlayAnimation("squish_to_blob_med")
		inst.AnimState:PushAnimation("blob_idle_med")
	end
end

local function OnUpdateReturning(inst)
	local mainblob = inst.components.entitytracker:GetEntity("mainblob")
	if mainblob and not mainblob.components.health:IsDead() then
		local x, y, z = inst.Transform:GetWorldPosition()
		local x1, y1, z1 = mainblob.Transform:GetWorldPosition()
		local dx = x1 - x
		local dz = z1 - z
		local dsq = dx * dx + dz * dz
		if dsq < 1 then
			mainblob:Absorb()
			inst._returntask:Cancel()
			inst._returntask = nil
			inst.persists = false
			local mult = 2 / math.sqrt(dsq)
			inst.Physics:SetMotorVel(dx * mult, 0, dz * mult)
			inst.AnimState:PlayAnimation("blob_attach_middle_pst")
			inst:ListenForEvent("animover", inst.Remove)
			inst.OnEntitySleep = inst.Remove
		elseif next(inst._collectors) then
			inst.speed = nil
			inst.Physics:SetMotorVel(0, 0, 0)
			inst.Physics:Stop()
		else
			inst.speed = (inst.speed or -3 * CHUNK_RETURN_ACCEL) + CHUNK_RETURN_ACCEL
			if inst.speed > 0 then
				local mult = inst.speed / math.sqrt(dsq)
				inst.Physics:SetMotorVel(dx * mult, 0, dz * mult)
			end
		end
	elseif inst.components.timer:TimerExists("lifespan") then
		inst.Physics:SetMotorVel(0, 0, 0)
		inst.Physics:Stop()
	else
		inst._returntask:Cancel()
		inst._returntask = nil
		inst.persists = false
		inst.Physics:SetMotorVel(0, 0, 0)
		inst.Physics:Stop()
		inst.DynamicShadow:Enable(false)
		ErodeAway(inst)
		if inst._proximitytask then
			inst._proximitytask:Cancel()
			inst._proximitytask = nil
		end
		for k, v in pairs(inst._targets) do
			v:KillFX()
			inst._targets[k] = nil
		end
	end
end

local function Small_OnEntityWake(inst)
	if not inst.tossing and inst.persists then
		OnEntityWake(inst)
		if inst._returntask == nil then
			inst._returntask = inst:DoPeriodicTask(0.2, OnUpdateReturning)
		end
		if not inst.SoundEmitter:PlayingSound("loop") then
			inst.SoundEmitter:PlaySound("rifts4/goop/minion_blob_wobble_lp", "loop")
		end
	end
end

local function Small_OnEntitySleep(inst)
	OnEntitySleep(inst)
	if inst._returntask then
		inst._returntask:Cancel()
		inst._returntask = nil
	end
	inst.SoundEmitter:KillSound("loop")
	if not inst.persists then
		inst:Remove()
	end
end


local function Small_OnTimerDone(inst, data)
	if data and data.name == "lifespan" then
		if inst:IsAsleep() then
			inst:Remove()
		else
			inst.persists = false
		end
	end
end

local function SetLifespan(inst, lifespan)
	inst.components.timer:StartTimer("lifespan", lifespan)
	inst:ListenForEvent("timerdone", Small_OnTimerDone)
end

local function OnTossLanded(inst)
	inst.tossing = nil
	inst.Physics:SetMotorVel(0, 0, 0)
	inst.Physics:Stop()
	if not inst:IsAsleep() then
		inst.SoundEmitter:PlaySound("rifts4/goop/minion_blob_land")
		Small_OnEntityWake(inst)
	end
end

local function Toss(inst, dist, angle)
	inst.AnimState:PlayAnimation("blob_pre_med")
	inst.AnimState:PushAnimation("blob_idle_med")
	inst.Physics:SetMotorVel(dist * math.cos(angle), 0, -dist * math.sin(angle))
	inst.tossing = inst:DoTaskInTime(16 * FRAMES, OnTossLanded)
	if inst._proximitytask then
		inst._proximitytask:Cancel()
		inst._proximitytask = nil
	end
	if inst._returntask then
		inst._returntask:Cancel()
		inst._returntask = nil
	end
	inst.SoundEmitter:KillSound("loop")
end

local function ReleaseFromBottle(inst)
	inst.AnimState:PlayAnimation("blob_pre_med")
	inst.AnimState:SetFrame(16)
	inst.AnimState:PushAnimation("blob_idle_med")
	if inst._proximitytask then
		inst._proximitytask:Cancel()
		inst._proximitytask = nil
	end
	if inst._returntask then
		inst._returntask:Cancel()
		inst._returntask = nil
	end
	inst.SoundEmitter:KillSound("loop")
	OnTossLanded(inst)
end

local function OnStartLongAction(inst, doer)
	if inst._collectors[doer] == nil then
		inst._collectors[doer] = doer.sg.currentstate.name
		inst:ListenForEvent("onremove", inst._onremovecollector, doer)
		inst:ListenForEvent("newstate", inst._onremovecollector, doer)
	end
end

local function smallfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.DynamicShadow:SetSize(2, 1.5)

	inst.entity:AddPhysics()
	inst.Physics:SetMass(10)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(5)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(COLLISION.WORLD)
	inst.Physics:SetCapsule(0.5, 1)

	inst:AddTag("canbebottled")

	inst.AnimState:SetBank("gelblob")
	inst.AnimState:SetBuild("gelblob")
	inst.AnimState:PlayAnimation("blob_idle_med", true)

	inst:SetPrefabNameOverride("gelblob")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("entitytracker")
	inst:AddComponent("timer")

	inst._contact_radius = 0.4
	inst._uncontact_radius = 1
	inst._targets = {}
	inst._untargets = {}
	inst._squished = false

	inst._collectors = {}
	inst._onremovecollector = function(doer, data)
		if not (data and data.statename == inst._collectors[doer]) then
			inst:RemoveEventCallback("onremove", inst._onremovecollector, doer)
			inst:RemoveEventCallback("newstate", inst._onremovecollector, doer)
			inst._collectors[doer] = nil
		end
	end

	inst:ListenForEvent("startlongaction", OnStartLongAction)

	inst.SetLifespan = SetLifespan
	inst.ReleaseFromBottle = ReleaseFromBottle
	inst.Toss = Toss
	inst.OnContactChanged = Small_OnContactChanged
	inst.OnEntityWake = Small_OnEntityWake
	inst.OnEntitySleep = Small_OnEntitySleep
	inst.OnRemoveEntity = OnRemoveEntity

	return inst
end

--------------------------------------------------------------------------

local function item_KillFX(inst)
	if inst:IsAsleep() then
		inst:Remove()
		return
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	inst.entity:SetParent(nil)
	inst.Transform:SetPosition(x, 0, z)
	inst.AnimState:PlayAnimation("splash_impact")
	inst:ListenForEvent("animover", inst.Remove)
	inst.OnEntitySleep = inst.Remove
end

local function itemfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("gelblob")
	inst.AnimState:SetBuild("gelblob")
	inst.AnimState:PlayAnimation("splash_loop", true)
	inst.AnimState:SetFinalOffset(2)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	inst.KillFX = item_KillFX

	return inst
end

--------------------------------------------------------------------------

local function spawnerfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst:AddTag("gelblobspawningground")
    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")

    TheWorld:PushEvent("ms_registergelblobspawningground", inst)

    return inst
end

--------------------------------------------------------------------------

return Prefab("gelblob", fn, assets, prefabs),
	Prefab("gelblob_back_fx", backfn, assets),
	Prefab("gelblob_small_fx", smallfn, assets),
	Prefab("gelblob_item_fx", itemfn, assets),
    Prefab("gelblobspawningground", spawnerfn)
