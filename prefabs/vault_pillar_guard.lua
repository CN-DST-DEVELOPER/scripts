require("prefabutil")

local assets =
{
	Asset("ANIM", "anim/vault_pillar_guard.zip"),
	Asset("ANIM", "anim/vault_pillar_guard_actions.zip"),
	Asset("ANIM", "anim/vault_pillar_guard_actions2.zip"),
	Asset("ANIM", "anim/vault_pillar_guard_basic.zip"),
}

local assets_dormant =
{
	Asset("ANIM", "anim/vault_pillar_guard.zip"),
}

local assets_constr =
{
	Asset("ANIM", "anim/vault_pillar_guard.zip"),
	Asset("ANIM", "anim/vault_pillar_guard_kit.zip"),
	Asset("MINIMAP_IMAGE", "vault_pillar_guard_dormant"),
}

local assets_plans =
{
	Asset("ANIM", "anim/vault_pillar_guard_kit.zip"),
}

local prefabs =
{
	"vault_pillar_guard_swipe_fx",
	"vault_pillar_guard_smash_fx",

	--loot
	"thulecite",
	"thulecite_pieces",
	"rocks",
	"moonrocknugget",
	"temp_beta_msg", --#TEMP_BETA
	"vault_pillar_guard_piece_1",
	"vault_pillar_guard_piece_2",
	"vault_pillar_guard_piece_3",
	"chesspiece_vault_pillar_guard_sketch",
}

local prefabs_dormant =
{
	"vault_pillar_guard",
	"collapse_big",
}

local prefabs_constr =
{
	"vault_pillar_guard_dormant",
	"collapse_big",
}

local brain = require("brains/vault_pillar_guardbrain")

SetSharedLootTable("vault_pillar_guard",
{
	{ "thulecite",			1 },
	{ "thulecite",			1 },
	{ "thulecite",			0.5 },
	{ "thulecite_pieces",	1 },
	{ "thulecite_pieces",	0.6667 },
	{ "thulecite_pieces",	0.3333 },
	--
	{ "rocks",				1 },
	{ "rocks",				1 },
	{ "rocks",				0.75 },
	{ "rocks",				0.5 },
	--
	{ "moonrocknugget",		1 },
	{ "moonrocknugget",		1 },
	{ "moonrocknugget",		0.5 },
})

local VAULT_GOLEM_PIECE_LOOT = --golem drops core piece according to index in trial
{
	"vault_pillar_guard_piece_1",
	"vault_pillar_guard_piece_2",
	"vault_pillar_guard_piece_3",
	"vault_pillar_guard_piece_3",
}

local VAULT_LOOT_FINAL = --drops for the last guard in the vault key room
{
	"chesspiece_vault_pillar_guard_sketch",
}

--------------------------------------------------------------------------

local function RecycleDebris(fx)
	local inst = fx.owner
	if inst and inst:IsValid() then
		if inst.debrisfx == fx then
			inst.debrisfx = nil
		end
		table.removearrayvalue(inst.highlightchildren, fx)
		table.insert(inst.debrisfxpool, fx)
		fx:RemoveFromScene()
		fx.entity:SetParent(inst.entity)
		fx.Transform:SetPosition(0, 0, 0)
		fx.Transform:SetRotation(0)
	else
		fx:Remove()
	end
end

local function CreateDebris()
	local fx = CreateEntity()

	fx:AddTag("NOCLICK")
	fx:AddTag("decor")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBank("vault_pillar_guard")
	fx.AnimState:SetBuild("vault_pillar_guard_basic") --this build only has debris symbols
	fx.AnimState:SetFinalOffset(1)

	fx:ListenForEvent("animover", RecycleDebris)

	return fx
end

local function DetachDebris(inst, recycle) --recycle nil when triggered via parent "onremove"
	if inst.debrisfx then
		if inst.debrisfx:IsValid() then
			inst.debrisfx:RemoveEventCallback("onremove", DetachDebris, inst)

			local t = inst.debrisfx.AnimState:GetCurrentAnimationTime()
			local len = inst.debrisfx.AnimState:GetCurrentAnimationLength()
			if t == 0 or --state changed b4 even started?
				len - t > 1 or --too much time remaining, long state (activate?) interrupted?
				t + FRAMES * 1.5 >= len --close enough to end
			then
				--just stop the fx immediately
				if recycle then
					RecycleDebris(inst.debrisfx)
				else
					table.removearrayvalue(inst.highlightchildren, inst.debrisfx)
					inst.debrisfx:Remove()
					inst.debrisfx = nil
				end
				return
			end
			--detach finish playing the fx
			inst.debrisfx.entity:SetParent(nil)
			inst.debrisfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.debrisfx.Transform:SetRotation(inst.Transform:GetRotation())
		end
		inst.debrisfx = nil
	end
end

local function DoDebris(inst)
	if inst.debrisanim:value() == inst.AnimState:GetCurrentAnimationHash() and not inst.AnimState:AnimDone() then
		if inst.debrisfxpool and #inst.debrisfxpool > 0 then
			inst.debrisfx = table.remove(inst.debrisfxpool)
			inst.debrisfx:ReturnToScene()
		else
			inst.debrisfx = CreateDebris()
			inst.debrisfx.owner = inst
			inst.debrisfx.entity:SetParent(inst.entity)
		end

		table.insert(inst.highlightchildren, inst.debrisfx)

		if inst.debrisnofaced:value() then
			inst.debrisfx.Transform:SetNoFaced()
		end
		inst.debrisfx.AnimState:PlayAnimation(inst.debrisanim:value())
		inst.debrisfx.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
		inst.debrisfx:ListenForEvent("onremove", DetachDebris, inst)
	end
end

local function PostUpdateDebris_Client(inst)
	inst._deferreddebris = false
	inst.components.updatelooper:RemovePostUpdateFn(PostUpdateDebris_Client)

	DoDebris(inst)
end

local function OnDebrisDirty_Client(inst)
	DetachDebris(inst, true)

	if not inst._deferreddebris then
		inst._deferreddebris = true
		inst.components.updatelooper:AddPostUpdateFn(PostUpdateDebris_Client)
	end
end

local function TriggerDebris(inst, show)
	if show then
		inst.debrisanim:set_local(0)
		inst.debrisanim:set(inst.AnimState:GetCurrentAnimationHash())
		inst.debrisnofaced:set(inst.sg.mem.nofaced or false)
	else
		inst.debrisanim:set(0)
	end

	if not TheNet:IsDedicated() then
		DetachDebris(inst, true)
		DoDebris(inst)
	end
end

local function teleport_override_fn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsPointInVaultRoom(x, y, z) then
		return Vector3(x, y, z)
	end
end

local function OnTeleported(inst)
	inst.components.knownlocations:RememberLocation("spawnpoint", inst:GetPosition())
end

local function IsClosestToTarget(inst, target, x1, z1, mindsq)
	for i = 1, 4 do
		local guard = inst.trial.components.entitytracker:GetEntity("guard"..tostring(i))
		if guard and guard ~= inst and
			guard.components.combat:TargetIs(target) and
			guard:GetDistanceSqToPoint(x1, 0, z1) < mindsq
		then
			return false --someone else closer to me has same target
		end
	end
	return true
end

local CRAFTED_AGGRO_TAGS = { "_combat" }
local CRAFTED_AGGRO_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "player" }
local function Crafted_CanAggro(v, inst)
	return v.components.combat.target
		and v.components.combat.target.isplayer
		and not (v.components.health and v.components.health:IsDead())
		or false
end

local function RetargetFn(inst)
	--NOTE: additional shared targeting logic in vault_key_trial

	local target = inst.components.combat.target
	if target and inst.trial then
		--for vault room, and only if already engaged in combat
		--try to switch target if someone else closer than me has the same target

		local x, y, z = inst.Transform:GetWorldPosition()
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local mindsq = math2d.DistSq(x, z, x1, z1)
		local range = TUNING.VAULT_PILLAR_GUARD_ATTACK_RANGE + target:GetPhysicsRadius(0)
		if mindsq < range * range and not inst.components.combat:InCooldown() then
			return --within melee range, don't change target
		end

		if IsClosestToTarget(inst, target, x1, z1, mindsq) then
			return --i'm closest, don't change target
		end

		mindsq = math.huge
		local mindsq2 = math.huge
		local closest, closest2
		for _, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() then
				local x1, y1, z1 = v.Transform:GetWorldPosition()
				if TheWorld.Map:IsPointInVaultRoom(x1, y1, z1) then
					local dsq = math2d.DistSq(x, z, x1, z1)
					if dsq < mindsq then
						mindsq = dsq
						closest = v
					end
					if dsq < mindsq2 and IsClosestToTarget(inst, v, x1, z1, dsq) then
						mindsq2 = dsq
						closest2 = v
					end
				end
			end
		end
		return closest2 or closest, true
	end

	if not (target or inst.trial) then
		--for crafted, look for nearby player combat to engage in
		return FindEntity(inst, TUNING.VAULT_PILLAR_GUARD_COMBAT_RANGE + 8, Crafted_CanAggro, CRAFTED_AGGRO_TAGS, CRAFTED_AGGRO_CANT_TAGS)
	end
end

local function KeepTargetFn(inst, target)
	if not inst.components.combat:CanTarget(target) then
		return false
	elseif inst.trial then
		return TheWorld.Map:IsPointInVaultRoom(inst.Transform:GetWorldPosition()) == TheWorld.Map:IsPointInVaultRoom(target.Transform:GetWorldPosition())
	end
	return inst:IsNear(target, TUNING.VAULT_PILLAR_GUARD_DEAGGRO_DIST)
end

local function OnAttacked(inst, data)
	if data and data.attacker and data.attacker:IsValid() then
		local x, y, z = inst.Transform:GetWorldPosition()

		if inst.trial then
			if data.attacker:HasTag("vault_key_trial_guardian") then
				return --ignore stray hits from pillar guard and crawler AOE
			end

			if data.attacker:HasTag("shadowcreature") then
				for _, v in ipairs(AllPlayers) do
					if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() then
						local x1, y1, z1 = v.Transform:GetWorldPosition()
						if data.attacker:GetDistanceSqToPoint(x1, y1, z1) < 100 and TheWorld.Map:IsPointInVaultRoom(x1, y1, z1) then
							v:PushEvent("ms_vaultshadowassist")
						end
					end
				end
			end

			if TheWorld.Map:IsPointInVaultRoom(x, y, z) ~= TheWorld.Map:IsPointInVaultRoom(data.attacker.Transform:GetWorldPosition()) then
				return --not in same room?
			end
		end

		local target = inst.components.combat.target
		if target then
			if not data.attacker.isplayer and target.isplayer and inst.components.combat.lastwasattackedbytargettime + 4 >= GetTime() then
				return --non-player should not take aggro off player actively attacking
			elseif target.isplayer or target:HasTag("epic") then
				local range = TUNING.VAULT_PILLAR_GUARD_ATTACK_RANGE + target:GetPhysicsRadius(0)
				if target:GetDistanceSqToPoint(x, y, z) < range * range then
					return --don't switch off priority targets that are within melee range
				end
			end
		end

		inst.components.combat:SetTarget(data.attacker)
	end
	--share target for the room is done in vault_key_trial
end

local function LootSetupFn(lootdropper)
	local inst = lootdropper.inst
	local loot
	if inst.trial then
		for i = 1, 4 do
			local guard = inst.trial.components.entitytracker:GetEntity("guard"..tostring(i))
			if guard == inst then
				loot = { VAULT_GOLEM_PIECE_LOOT[i] }
				if inst._vault_death_loot then
					loot = ConcatArrays(loot, VAULT_LOOT_FINAL)
				end
				break
			end
		end
	end
	lootdropper:SetLoot(loot)
	lootdropper:SetChanceLootTable("vault_pillar_guard")
end

local PHASES =
{
	{
		hp = 1,
		fn = function(inst)
			inst.canspin = false
			inst.canquickjump = false
		end,
	},
	{
		hp = 0.75,
		fn = function(inst)
			inst.canspin = true
			inst.canquickjump = false
		end,
	},
	{
		hp = 0.5,
		fn = function(inst)
			inst.canspin = true
			inst.canquickjump = true

			if not (POPULATING or inst.components.timer:TimerExists("stunned")) then
				inst.components.timer:StartTimer("stunned", TUNING.VAULT_PILLAR_GUARD_MAX_STAGGER_TIME, true)
			end
		end,
	},
	{
		hp = 1 / 3,
		fn = function(inst)
			inst.canspin = true
			inst.canquickjump = true

			if not POPULATING then
				local elapsed = inst.components.timer:GetTimeElapsed("stunned")
				if elapsed then
					if elapsed >= TUNING.VAULT_PILLAR_GUARD_MIN_STAGGER_TIME or inst.components.timer:IsPaused("stunned") then
						inst.components.timer:StopTimer("stunned")
					else
						inst.components.timer:SetTimeLeft("stunned", TUNING.VAULT_PILLAR_GUARD_MIN_STAGGER_TIME - elapsed)
					end
				end
			end
		end,
	},
}

local function PushMusic(inst)
	if ThePlayer then
		ThePlayer:PushEvent("vault_pillar_guard_aggro")
	end
end

local function OnMusicDirty(inst)
	if inst.music:value() then
		if inst._musictask == nil then
			inst._musictask = inst:DoPeriodicTask(1, PushMusic, 0)
		end
	elseif inst._musictask then
		inst._musictask:Cancel()
		inst._musictask = nil
	end
end

local function EnableMusic(inst, enable)
	if inst.music:value() == not enable then
		inst.music:set(enable)

		--Dedicated server does not need to trigger music
		if not TheNet:IsDedicated() then
			OnMusicDirty(inst)
		end
	end
end

local function OnNewTarget(inst, data)
	if data then
		if inst.trial and data.target then
			EnableMusic(inst, true)
		end
		if data.oldtarget == nil then
			if inst.canspin then
				local cd = inst.components.timer:GetTimeLeft("spin_cd") or 0
				inst.components.timer:StopTimer("spin_cd")
				inst.components.timer:StartTimer("spin_cd", math.max(cd, (1 + math.random()) / 4 * TUNING.VAULT_PILLAR_GUARD_SPIN_CD))
			end
			if inst.canquickjump then
				local cd = inst.components.timer:GetTimeLeft("quickjump_cd") or 0
				inst.components.timer:StopTimer("quickjump_cd")
				inst.components.timer:StartTimer("quickjump_cd", math.max(cd, (1 + math.random()) / 8 * TUNING.VAULT_PILLAR_GUARD_QUICKJUMP_CD))
			end
		end
	end
end

local function OnDroppedTarget(inst)--, data)
	EnableMusic(inst, false)
end

local function MakeCrafted(inst)
	inst.crafted = true
	inst.AnimState:Hide("moss")
	inst:RemoveTag("hostile")
	inst:RemoveTag("noepicmusic")
	inst:AddTag("player_aligned")
	inst.components.inspectable:SetNameOverride("vault_pillar_guard_crafted")
	EnableMusic(inst, false)

	inst:RemoveComponent("healthtrigger")
	inst.components.timer:StopTimer("stunned")
	inst.canspin = true
	inst.canquickjump = true
end

local function IsCrafted(inst)
	return inst:HasTag("player_aligned")
end

local function OnSave(inst, data)
	data.crafted = inst.crafted or nil
end

local function OnLoad(inst, data)--, ents)
	if data and data.crafted then
		inst:MakeCrafted()
	end
	if inst.components.healthtrigger then
		local healthpct = inst.components.health:GetPercent()
		for i = #PHASES, 2, -1 do
			local v = PHASES[i]
			if healthpct <= v.hp then
				v.fn(inst)
				break
			end
		end
	end
	if inst.components.timer:TimerExists("stunned") and not inst.components.timer:IsPaused("stunned") then
		inst.sg:GoToState("stun_idle")
	end
end

local function DisplayNameFn(inst)
	return inst:HasTag("player_aligned") and STRINGS.NAMES.VAULT_PILLAR_GUARD_CRAFTED or nil
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst:AddTag("monster")
	inst:AddTag("largecreature")
	inst:AddTag("hostile")
	inst:AddTag("soulless")
	inst:AddTag("mech")
	inst:AddTag("electricdamageimmune")
	inst:AddTag("epic")
	inst:AddTag("noepicmusic")
	inst:AddTag("scarytoprey")
	inst:AddTag("crazy") -- so they can attack shadow creatures
	inst:AddTag("vault_pillar_guard")

	inst.DynamicShadow:SetSize(6, 3.5)

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("vault_pillar_guard")
	inst.AnimState:SetBuild("vault_pillar_guard")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetSymbolLightOverride("fx_blue_part", 0.5)
	inst.AnimState:SetSymbolLightOverride("pg_eye_parts", 0.14)
	inst.AnimState:SetSymbolLightOverride("pg_top", 0.12)
	inst.AnimState:SetSymbolLightOverride("pg_shoulder", 0.09)
	inst.AnimState:SetSymbolLightOverride("pg_chest", 0.08)
	inst.AnimState:SetSymbolLightOverride("pg_pelvis", 0.05)

	inst:SetPhysicsRadiusOverride(1.6)
	MakeGiantCharacterPhysics(inst, 1000, inst.physicsradiusoverride)

	inst.debrisanim = net_hash(inst.GUID, "vault_pillar_guard.debrisanim", "debrisdirty")
	inst.debrisnofaced = net_bool(inst.GUID, "vault_pillar_guard.debrisnofaced")
	inst.music = net_bool(inst.GUID, "vault_pillar_guard.music", "musicdirty")

	if not TheNet:IsDedicated() then
		inst.debrisfxpool = {}
		inst.highlightchildren = {}
	end

	inst.displaynamefn = DisplayNameFn
	inst.IsCrafted = IsCrafted

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("debrisdirty", OnDebrisDirty_Client)
		inst:ListenForEvent("musicdirty", OnMusicDirty)

		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.VAULT_PILLAR_GUARD_SPEED
	inst.components.locomotor.runspeed = TUNING.VAULT_PILLAR_GUARD_SPEED
	inst.components.locomotor.pathcaps = { ignorebridges = true }

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.VAULT_PILLAR_GUARD_HEALTH)
	inst.components.health.nofadeout = true

	inst:AddComponent("drownable")

	inst:AddComponent("damagetypebonus")
	inst:AddComponent("damagetyperesist")

	inst:AddComponent("combat")
	inst.components.combat.playerdamagepercent = 0.5
	inst.components.combat.hiteffectsymbol = "pg_pelvis"
	inst.components.combat.forcefacing = false
	inst.components.combat:SetDefaultDamage(TUNING.VAULT_PILLAR_GUARD_DAMAGE)
	inst.components.combat:SetRange(TUNING.VAULT_PILLAR_GUARD_ATTACK_RANGE)
	inst.components.combat:SetAttackPeriod(TUNING.VAULT_PILLAR_GUARD_ATTACK_PERIOD)
	inst.components.combat:SetRetargetFunction(3, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("healthtrigger")
	for i, v in ipairs(PHASES) do
		inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
	end
	PHASES[1].fn(inst)

	inst:AddComponent("timer")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("vault_pillar_guard")
	inst.components.lootdropper:SetLootSetupFn(LootSetupFn)
	inst.components.lootdropper.min_speed = 2
	inst.components.lootdropper.max_speed = 4
	inst.components.lootdropper.y_speed = 4
	inst.components.lootdropper.y_speed_variance = 3
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst:AddComponent("explosiveresist")

	inst:AddComponent("knownlocations")

	--MakeHugeFreezableCharacter(inst, "pg_pelvis")
	MakeHauntable(inst)

	inst:ListenForEvent("teleported", OnTeleported)
	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("newcombattarget", OnNewTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)

	inst.TriggerDebris = TriggerDebris

	inst:SetStateGraph("SGvault_pillar_guard")
	inst:SetBrain(brain)

	inst.MakeCrafted = MakeCrafted
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

--------------------------------------------------------------------------

local function OnEntityWake_Pathfinding(inst)
	if inst._pfx == nil and inst:GetCurrentPlatform() == nil then
		local _
		inst._pfx, _, inst._pfz = inst.Transform:GetWorldPosition()
		for dx = -1, 1 do
			for dz = -1, 1 do
				TheWorld.Pathfinder:AddWall(inst._pfx + dx, 0, inst._pfz + dz)
			end
		end
	end
end

local function OnRemoveEntity_Pathfinding(inst)
	if inst._pfx then
		for dx = -1, 1 do
			for dz = -1, 1 do
				TheWorld.Pathfinder:RemoveWall(inst._pfx + dx, 0, inst._pfz + dz)
			end
		end
		inst._pfx, inst._pfz = nil, nil
	end
end

local function dormant_ActivatePillarGuard(inst, trial)
	local crafted = inst.crafted
	inst = ReplacePrefab(inst, "vault_pillar_guard")
	if trial then
		local x, y, z = inst.Transform:GetWorldPosition()
		local x1, y1, z1 = trial.Transform:GetWorldPosition()
		if x ~= x1 or z ~= z1 then
			local dx = x1 - x
			local dz = z1 - z
			local len = math.sqrt(dx * dx + dz * dz)
			local home = Vector3(x + dx * 3 / len, 0, z + dz * 3 / len)
			inst.Transform:SetRotation(math.atan2(-dz, dx) * RADIANS)
			inst.components.knownlocations:RememberLocation("spawnpoint", home)
		end
	elseif crafted then
		inst:MakeCrafted()
	end
	inst.sg:GoToState("activate")
	return inst
end

--Also used by vault_pillar_guard_constr
local function dormant_OnHammered(inst, worker)
	local pt = inst:GetPosition()
	inst.components.lootdropper:DropLoot(pt)

	if inst.components.constructionsite then
		inst.components.constructionsite:DropAllMaterials(pt)
	end

	local fx = SpawnPrefab("collapse_big")
	fx.Transform:SetPosition(pt:Get())
	fx:SetMaterial("metal")
	inst:Remove()
end

local function dormant_OnPossessed(inst, data)
    local pulse = data.possesser
    if pulse ~= nil and pulse:HasTag("power_point") then
		pulse:Despawn(inst)
	end
	inst:ActivatePillarGuard()
end

local function dormant_MakeCrafted(inst)
	inst.crafted = true
	inst.AnimState:Hide("moss")

	inst:RemoveTag("nomagic")
	inst:AddTag("structure")

	inst.components.inspectable:SetNameOverride("vault_pillar_guard_dormant_crafted")

	-- dormant_MakeCrafted always runs when proper position is set (OnLoad or on constructionsite being repaired)
	-- if that assumption changes, account for this here.
	if not TheWorld.Map:IsPointInVaultRoom(inst.Transform:GetWorldPosition()) then
		inst:AddTag("security_powerpoint")
		inst.pulse_findrange = 6
		inst:ListenForEvent("possess", dormant_OnPossessed)
	end

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(5)
	inst.components.workable:SetOnFinishCallback(dormant_OnHammered)

	inst:AddComponent("lootdropper")
	inst.components.lootdropper.spawn_loot_inside_prefab = true
end

local function dormant_IsCrafted(inst)
	return inst:HasTag("structure")
end

local function dormant_OnSave(inst, data)
	data.crafted = inst.crafted or nil
end

local function dormant_OnLoad(inst, data)--, ents)
	if data and data.crafted then
		inst:MakeCrafted()
	end
end

local function dormant_DisplayNameFn(inst)
	return inst:HasTag("structure") and STRINGS.NAMES.VAULT_PILLAR_GUARD_CRAFTED or nil
end

local function dormantfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("vault_pillar_guard_dormant.png")

	inst.AnimState:SetBank("vault_pillar_guard")
	inst.AnimState:SetBuild("vault_pillar_guard")
	inst.AnimState:PlayAnimation("pillar_idle")

	inst:SetDeploySmartRadius(1.5)
	inst:SetPhysicsRadiusOverride(1.3)
	MakeObstaclePhysics(inst, inst.physicsradiusoverride)
	inst.Physics:SetDontRemoveOnSleep(true)

	--Not using NOCLICK because we do want to block mouse
	--Not using decor/FX because we do want to block placement
	--Some actions will highlight targets even if not a valid action:
	--  "nomagic" blocks SPELLCAST (e.g. reskin_tool)
	--  "nohighlight" blocks complexprojectile (e.g. bombs)
	inst:AddTag("nomagic")
	inst:AddTag("nohighlight")

	inst.OnEntityWake = OnEntityWake_Pathfinding
	inst.OnRemoveEntity = OnRemoveEntity_Pathfinding

	inst.displaynamefn = dormant_DisplayNameFn
	inst.IsCrafted = dormant_IsCrafted

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst.ActivatePillarGuard = dormant_ActivatePillarGuard
	inst.MakeCrafted = dormant_MakeCrafted
	inst.OnSave = dormant_OnSave
	inst.OnLoad = dormant_OnLoad

	return inst
end

--------------------------------------------------------------------------

local function constr_CalcProgress(inst)
	local materialsin, materialsneeded = 0, 0
	for _, v in ipairs(CONSTRUCTION_PLANS[inst.prefab] or {}) do
		materialsneeded = materialsneeded + v.amount
		materialsin = materialsin + inst.components.constructionsite:GetMaterialCount(v.type)
	end
	return materialsin / materialsneeded
end

local function constr_InstantUpdate(inst)
	local pct = constr_CalcProgress(inst)
	if pct < 1 then
		inst.AnimState:PlayAnimation(
			(pct <= 0.3 and "construction_small") or
			(pct <= 0.6 and "construction_med") or
			"construction_large")
	elseif not inst.AnimState:IsCurrentAnimation("construction_large_to_off") then
		inst.AnimState:PlayAnimation("construction_large")
		inst.AnimState:SetFrame(inst.AnimState:GetCurrentAnimationNumFrames() - 2)
	end
end

local function DoTarpSound(inst)
	inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5)
	inst.SoundEmitter:PlaySound("hookline_2/common/hotspring/tarp")
end

local function constr_OnAnimOver(inst)
	if inst.AnimState:IsCurrentAnimation("construction_small_place") then
		if constr_CalcProgress(inst) > 0.3 then
			inst.AnimState:PlayAnimation("construction_small_to_med")
			DoTarpSound(inst)
		else
			inst.AnimState:PlayAnimation("construction_small")
		end
	elseif inst.AnimState:IsCurrentAnimation("construction_small_to_med") then
		if constr_CalcProgress(inst) > 0.6 then
			inst.AnimState:PlayAnimation("construction_med_to_large")
			DoTarpSound(inst)
		else
			inst.AnimState:PlayAnimation("construction_med")
		end
	elseif inst.AnimState:IsCurrentAnimation("construction_med_to_large") then
		if inst.components.constructionsite:IsComplete() then
			inst.AnimState:PlayAnimation("construction_large_to_off")
			DoTarpSound(inst)
		else
			inst.AnimState:PlayAnimation("construction_large")
		end
	elseif inst.AnimState:IsCurrentAnimation("construction_large_to_off") and inst.components.constructionsite:IsComplete() then
		inst = ReplacePrefab(inst, "vault_pillar_guard_dormant")
		inst:MakeCrafted()
		PreventCharacterCollisionsWithPlacedObjects(inst)
	end
end

local function constr_OnConstructed(inst)--, doer)
	if inst:IsAsleep() then
		constr_InstantUpdate(inst)
	elseif inst.AnimState:IsCurrentAnimation("construction_small") then
		if constr_CalcProgress(inst) > 0.3 then
			inst.AnimState:PlayAnimation("construction_small_to_med")
			DoTarpSound(inst)
		end
	elseif inst.AnimState:IsCurrentAnimation("construction_med") then
		if constr_CalcProgress(inst) > 0.6 then
			inst.AnimState:PlayAnimation("construction_med_to_large")
			DoTarpSound(inst)
		end
	elseif inst.AnimState:IsCurrentAnimation("construction_large") and inst.components.constructionsite:IsComplete() then
		inst.AnimState:PlayAnimation("construction_large_to_off")
		DoTarpSound(inst)
	end
end

local function constr_OnBuilt(inst, data)
	if not inst:IsAsleep() then
		inst.AnimState:PlayAnimation("construction_small_place")
		inst.SoundEmitter:PlaySound("rifts7/pillar_guard/kit_place")
		PreventCharacterCollisionsWithPlacedObjects(inst)
	end
end

local function constr_OnLoad(inst)--, data, ents)
	constr_InstantUpdate(inst)
end

local function constrfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("vault_pillar_guard")
	inst.AnimState:SetBuild("vault_pillar_guard")
	inst.AnimState:PlayAnimation("construction_small")
	inst.AnimState:OverrideSymbol("vault_pillar_cover", "vault_pillar_guard_kit", "vault_pillar_cover")
	inst.AnimState:Hide("moss")

	inst:SetDeploySmartRadius(1.5)
	inst:SetPhysicsRadiusOverride(1.3)
	MakeObstaclePhysics(inst, inst.physicsradiusoverride)
	inst.Physics:SetDontRemoveOnSleep(true)

	inst.MiniMapEntity:SetIcon("vault_pillar_guard_dormant.png")

	inst:AddTag("structure")

	--constructionsite (from constructionsite component) added to pristine state for optimization
	inst:AddTag("constructionsite")

	inst.OnEntityWake = OnEntityWake_Pathfinding
	inst.OnRemoveEntity = OnRemoveEntity_Pathfinding

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("constructionsite")
	inst.components.constructionsite:SetConstructionPrefab("construction_container")
	inst.components.constructionsite:SetOnConstructedFn(constr_OnConstructed)

	inst:AddComponent("inspectable")
	inst:AddComponent("lootdropper")
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(5)
	inst.components.workable:SetOnFinishCallback(dormant_OnHammered) --shared fn

	inst:ListenForEvent("onsink", dormant_OnHammered) --shared fn
	inst:ListenForEvent("onbuilt", constr_OnBuilt)
	inst:ListenForEvent("animover", constr_OnAnimOver)

	inst.OnLoad = constr_OnLoad

	return inst
end

--------------------------------------------------------------------------

return Prefab("vault_pillar_guard", fn, assets, prefabs),
	Prefab("vault_pillar_guard_dormant", dormantfn, assets_dormant, prefabs_dormant),
	Prefab("vault_pillar_guard_constr", constrfn, assets_constr, prefabs_constr),
	MakePlacer("vault_pillar_guard_constr_plans_placer",
		"vault_pillar_guard",			-- bank
		"vault_pillar_guard",			-- build
		"pillar_idle",					-- anim
		false,							-- onground
		false,							-- snap
		true,							-- metersnap
		nil,							-- scale
		nil,							-- fixedcameraoffset
		nil,							-- facing
		function(inst)					-- postinit_fn
			inst.AnimState:Hide("moss")
		end),
	MakeDeployableKitItem("vault_pillar_guard_constr_plans",
		"vault_pillar_guard_constr",	-- prefab_to_deploy
		"vault_pillar_guard_kit",		-- bank
		"vault_pillar_guard_kit",		-- build
		"idle",							-- anim
		assets_plans,					-- assets
		{								-- floatable_data
			size = "med",
			y_offset = 0.2,
			scale = 0.95,
		},
		nil,							-- tags
		nil,							-- burnable
		{								-- deployable_data
			common_postinit = function(inst)
				inst.pickupsound = "rock"
			end,
			custom_candeploy_fn = function(inst, pt, mouseover, deployer, rot)
				--Don't use GetValidRecipe, since validity doesn't apply here.
				--This recipe exists as a DeconstructionRecipe, but is configured with the proper testfn for use here.
				local rec = AllRecipes["vault_pillar_guard_constr"]
				return rec ~= nil
					and TheWorld.Map:CanDeployRecipeAtPoint(pt, rec, rot, deployer)
					and not TheWorld.Map:IsPointInVaultRoom(pt:Get())
			end,
			deploymode = DEPLOYMODE.CUSTOM,
		})
