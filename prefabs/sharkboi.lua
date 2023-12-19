local assets =
{
	Asset("ANIM", "anim/sharkboi_build.zip"),
	Asset("ANIM", "anim/sharkboi_basic.zip"),
	Asset("ANIM", "anim/sharkboi_action.zip"),
	Asset("ANIM", "anim/sharkboi_actions1.zip"),
}

local prefabs =
{
	"sharkboi_icehole_fx",
	"sharkboi_iceimpact_fx",
	"sharkboi_iceplow_fx",
	"sharkboi_icespike",
	"sharkboi_icetrail_fx",
	"sharkboi_icetunnel_fx",
	"sharkboi_swipe_fx",
	"splash_green_large",
	"bootleg",
}

local brain = require("brains/sharkboibrain")

--[[SetSharedLootTable("sharkboi",
{
	{ "bootleg", 1 },
	{ "bootleg", 1 },
	{ "bootleg", 0.5 },
})]]

local MAX_TRADES = 5
local MIN_REWARDS = 1
local MAX_REWARDS = 2

local OFFSCREEN_DESPAWN_DELAY = 60

local FIN_MASS = 99999
local FIN_RADIUS = 0.5

local STANDING_MASS = 1000
local STANDING_RADIUS = 1

local function OnFinModeDirty(inst)
	inst:SetPhysicsRadiusOverride(inst.finmode:value() and FIN_RADIUS or STANDING_RADIUS)
end

local function ChangeRadius(inst, radius)
	inst:SetPhysicsRadiusOverride(radius)
	if inst.sg.mem.isobstaclepassthrough then
		if inst.sg.mem.radius ~= radius then
			inst.sg.mem.radius = radius
			inst.Physics:SetCapsule(radius, 1)
		end
	elseif inst.sg.mem.physicstask == nil then
		if inst.sg.mem.ischaracterpassthrough then
			if inst.sg.mem.radius ~= radius then
				inst.Physics:SetCapsule(STANDING_RADIUS, 1)
				if inst.sg.mem.radius < radius then
					inst.Physics:Teleport(inst.Transform:GetWorldPosition())
				end
				inst.sg.mem.radius = STANDING_RADIUS
			end
		else
			ToggleOffAllObjectCollisions(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			ToggleOnAllObjectCollisionsAt(inst, x, z)
		end
	end
end

local function OnNewState(inst)
	if inst.sg:HasAnyStateTag("fin", "digging", "dizzy", "jumping", "invisible", "sleeping", "waking") and not inst.sg:HasStateTag("cantalk") then
		inst.components.talker:IgnoreAll("busycombat")
	else
		inst.components.talker:StopIgnoringAll("busycombat")
	end

	local dochangemass
	if inst.sg:HasStateTag("digging") then
		if not (inst.sg.lasttags and inst.sg.lasttags["digging"]) then
			inst.Physics:SetMass(0)
			inst.components.talker:ShutUp()
		end
	elseif inst.sg.lasttags and inst.sg.lasttags["digging"] then
		if inst.sg:HasStateTag("fin") then
			inst.Physics:SetMass(FIN_MASS)
		else
			inst.Physics:SetMass(STANDING_MASS)
		end
	else
		dochangemass = true
	end

	if inst.sg:HasStateTag("fin") then
		if not inst.finmode:value() then
			inst.finmode:set(true)
			inst.Transform:SetEightFaced()
			inst.DynamicShadow:Enable(false)
			if dochangemass then
				inst.Physics:SetMass(FIN_MASS)
			end
			ChangeRadius(inst, FIN_RADIUS)
			inst.components.health:SetInvincible(true)
			inst.components.combat:RestartCooldown()
			inst.components.locomotor.runspeed = TUNING.SHARKBOI_FINSPEED
			inst.components.talker:ShutUp()
		end
	elseif inst.finmode:value() then
		inst.finmode:set(false)
		inst.Transform:SetFourFaced()
		if not inst.sg:HasStateTag("invisible") then
			inst.DynamicShadow:Enable(true)
		end
		if dochangemass then
			inst.Physics:SetMass(STANDING_MASS)
		end
		ChangeRadius(inst, STANDING_RADIUS)
		inst.components.health:SetInvincible(false)
		inst.components.locomotor.runspeed = TUNING.SHARKBOI_RUNSPEED
	end
end

local function teleport_override_fn(inst)
    local sharkboimanager = TheWorld.components.sharkboimanager
    if sharkboimanager == nil then
        return nil
    end

    return sharkboimanager:FindWalkableOffsetInArena(inst)
end

local function OnTalk(inst)
	if not inst.sg:HasStateTag("notalksound") then
		if inst.sg:HasStateTag("defeated") then
			inst.SoundEmitter:PlaySound("meta3/sharkboi/stunned_hit")
		else
			inst.SoundEmitter:PlaySound("meta3/sharkboi/talk")
		end
	end
end

--------------------------------------------------------------------------

local function UpdatePlayerTargets(inst)
	local toadd = {}
	local toremove = {}
	local x, y, z = inst.Transform:GetWorldPosition()

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		toremove[k] = true
	end

	local sharkboimanager = TheWorld.components.sharkboimanager
	if sharkboimanager and sharkboimanager:IsPointInArena(inst.Transform:GetWorldPosition()) then
		for i, v in ipairs(AllPlayers) do
			if not (v.components.health:IsDead() or v:HasTag("playerghost")) and
				v.entity:IsVisible() and
				sharkboimanager:IsPointInArena(v.Transform:GetWorldPosition())
			then
				if toremove[v] then
					toremove[v] = nil
				else
					table.insert(toadd, v)
				end
			end
		end
	else
		for i, v in ipairs(FindPlayersInRange(x, y, z, TUNING.SHARKBOI_DEAGGRO_DIST, true)) do
			if toremove[v] then
				toremove[v] = nil
			else
				table.insert(toadd, v)
			end
		end
	end

	for k in pairs(toremove) do
		inst.components.grouptargeter:RemoveTarget(k)
	end
	for i, v in ipairs(toadd) do
		inst.components.grouptargeter:AddTarget(v)
	end
end

local function RetargetFn(inst)
	if not inst:HasTag("hostile") then
		return
	end

	UpdatePlayerTargets(inst)

	local target = inst.components.combat.target
	local inrange = target and inst:IsNear(target, TUNING.SHARKBOI_ATTACK_RANGE + target:GetPhysicsRadius(0))

	if target and target:HasTag("player") then
		local newplayer = inst.components.grouptargeter:TryGetNewTarget()
		return newplayer
			and newplayer:IsNear(inst, inrange and TUNING.SHARKBOI_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.SHARKBOI_KEEP_AGGRO_DIST)
			and newplayer
			or nil,
			true
	end

	local nearplayers = {}
	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		if inst:IsNear(k, inrange and TUNING.SHARKBOI_ATTACK_RANGE + k:GetPhysicsRadius(0) or TUNING.SHARKBOI_AGGRO_DIST) then
			table.insert(nearplayers, k)
		end
	end
	return #nearplayers > 0 and nearplayers[math.random(#nearplayers)] or nil, true
end

local function KeepTargetFn(inst, target)
	if inst:HasTag("hostile") and inst.components.combat:CanTarget(target) then
		local sharkboimanager = TheWorld.components.sharkboimanager
		if sharkboimanager and sharkboimanager:IsPointInArena(inst.Transform:GetWorldPosition()) then
			return sharkboimanager:IsPointInArena(target.Transform:GetWorldPosition())
		end
		return inst:IsNear(target, TUNING.SHARKBOI_DEAGGRO_DIST)
	end
	return false
end

local function StartAggro(inst)
	if not inst:HasTag("hostile") then
        inst:AddTag("hostile")
		inst.components.timer:StopTimer("standing_dive_cd")
		inst.components.timer:StartTimer("standing_dive_cd", TUNING.SHARKBOI_STANDING_DIVE_CD / 2)
		inst.components.timer:StopTimer("torpedo_cd")
		inst.components.timer:StartTimer("torpedo_cd", TUNING.SHARKBOI_TORPEDO_CD / 2)
	end
end

local function StopAggro(inst)
	if inst:HasTag("hostile") then
        inst:RemoveTag("hostile")
		inst.components.timer:StopTimer("standing_dive_cd")
		inst.components.timer:StopTimer("torpedo_cd")
	end
end

local function OnAttacked(inst, data)
	if data.attacker and inst.components.trader == nil then
		local target = inst.components.combat.target
		if not (target and
				target:HasTag("player") and
				target:IsNear(inst, TUNING.SHARKBOI_ATTACK_RANGE + target:GetPhysicsRadius(0))
		) then
			if inst.components.health.currenthealth > inst.components.health.minhealth then
				StartAggro(inst)
			end
			inst.components.combat:SetTarget(data.attacker)
		end
	end
end

local function EndGloat(inst)
	inst.components.talker:StopIgnoringAll("gloat")
end

local function OnKilledOther(inst, data)
	if data and data.victim and data.victim:HasTag("player") then
		if not inst:HasTag("ignoretalking") then
			inst.components.talker:Chatter("SHARKBOI_TALK_GLOAT", math.random(#STRINGS.SHARKBOI_TALK_GLOAT), nil, true)
			inst.components.talker:IgnoreAll("gloat")
			inst:DoTaskInTime(3, EndGloat)
		end
	end
end

--------------------------------------------------------------------------

local function ShouldSleep(inst)
	return false
end

local function ShouldWake(inst)
	return true
end

--------------------------------------------------------------------------

local function AcceptTest(inst, item)
	return inst.pendingreward == nil
		and inst.stock > 0
		and item:HasTag("oceanfish")
		and item.components.weighable
		and item.components.weighable:GetWeight() >= 150
end

local function OnGivenItem(inst, giver, item)
	if item.components.weighable and item.components.weighable:GetWeightPercent() >= TUNING.WEIGHABLE_HEAVY_WEIGHT_PERCENT then
		inst.pendingreward = MAX_REWARDS
	else
		inst.pendingreward = MIN_REWARDS
	end
end

local function OnRefuseItem(inst, giver, item)
	local reason
	if inst.stock <= 0 then
		reason = "EMPTY"
	elseif item then
		reason = item:HasTag("oceanfish") and "TOO_SMALL" or "NOT_OCEANFISH"
	end
	inst:PushEvent("onrefuseitem", { giver = giver, reason = reason })
end

local function MakeTrader(inst)
	if inst.components.trader == nil then
		inst:AddComponent("trader")
		inst.components.trader:SetAcceptTest(AcceptTest)
		inst.components.trader.onaccept = OnGivenItem
		inst.components.trader.onrefuse = OnRefuseItem

		inst.stock = MAX_TRADES

		inst:AddTag("notarget")

		if inst:IsAsleep() and inst.sleeptask == nil then
			inst.sleeptask = inst:DoTaskInTime(OFFSCREEN_DESPAWN_DELAY, inst.Remove)
		end
	end
end

local function GiveReward(inst, target)
	if inst.pendingreward then
		if target and not target:IsValid() then
			target = nil
		end
		inst.stock = inst.stock - 1
		for i = 1, inst.pendingreward do
			LaunchAt(SpawnPrefab("bootleg"), inst, target, 1, 2, 1)
		end
		inst.SoundEmitter:PlaySound("dontstarve/common/dropGeneric")
		inst.pendingreward = nil
	end
end

local function EndTradeTalkTask(inst)
	inst._tradetalktask = nil
	inst.components.talker:StopIgnoringAll("trading")
end

local function SetIsTradingFlag(inst, flag, timeout)
	if inst._tradingtask then
		inst._tradingtask:Cancel()
		inst._tradingtask = nil
	end

	if flag then
		if not inst.trading then
			inst.trading = true
			inst._tradingtask = inst:DoTaskInTime(timeout, SetIsTradingFlag, false)

			--make sure talking is not suppressed when entering trading brain node
			if inst._tradetalktask then
				inst._tradetalktask:Cancel()
				EndTradeTalkTask(inst)
			end
		end
	elseif inst.trading then
		inst.trading = false

		--suppress talking for a few seconds after leaving the trading brain node
		if inst._tradetalktask then
			inst._tradetalktask:Cancel()
		else
			inst.components.talker:IgnoreAll("trading")
		end
		inst._tradetalktask = inst:DoTaskInTime(3, EndTradeTalkTask)
	end
end

--------------------------------------------------------------------------

local function OnSave(inst, data)
	data.aggro = inst:HasTag("hostile") or nil
	data.reward = inst.pendingreward or nil
	if inst.stock and inst.stock < MAX_TRADES then
		data.stock = inst.stock
	end
end

local function OnLoad(inst, data)
	if inst.components.health.currenthealth <= inst.components.health.minhealth then
		MakeTrader(inst)
		if data then
			if data.reward then
				inst.pendingreward = math.clamp(data.reward, MIN_REWARDS, MAX_REWARDS)
			end
			if data.stock and data.stock < MAX_TRADES then
				inst.stock = data.stock
			end
		end
	elseif data and data.aggro then
		StartAggro(inst)
	end
end

local function OnEntitySleep(inst)
	StopAggro(inst)
	if inst.sg:HasAnyStateTag("fin", "digging", "busy") then
		inst.sg:GoToState("idle")
		if inst.components.health.currenthealth <= inst.components.health.minhealth then
			MakeTrader(inst)
		end
	end
	if inst.components.trader and inst.sleeptask == nil then
		inst.sleeptask = inst:DoTaskInTime(OFFSCREEN_DESPAWN_DELAY, inst.Remove)
	end
end

local function OnEntityWake(inst)
	if inst.sleeptask then
		inst.sleeptask:Cancel()
		inst.sleeptask = nil
	end
end

--------------------------------------------------------------------------

local function PushMusic(inst)
	if ThePlayer == nil or not inst:HasTag("hostile") then
		inst._playingmusic = false
	else
		--client safe
		local sharkboimanagerhelper = TheWorld and TheWorld.net and TheWorld.net.components.sharkboimanagerhelper
		if sharkboimanagerhelper and sharkboimanagerhelper:IsPointInArena(inst.Transform:GetWorldPosition()) then
			if sharkboimanagerhelper:IsPointInArena(ThePlayer.Transform:GetWorldPosition()) then
				inst._playingmusic = true
				ThePlayer:PushEvent("triggeredevent", { name = "sharkboi" })
			else
				inst._playingmusic = false
			end
		elseif ThePlayer:IsNear(inst, inst._playingmusic and 40 or 20) then
			inst._playingmusic = true
			ThePlayer:PushEvent("triggeredevent", { name = "sharkboi" })
		elseif inst._playingmusic and not ThePlayer:IsNear(inst, 50) then
			inst._playingmusic = false
		end
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(STANDING_RADIUS)
	MakeGiantCharacterPhysics(inst, STANDING_MASS, inst.physicsradiusoverride)
	inst.DynamicShadow:SetSize(3.5, 1.5)
	inst.Transform:SetFourFaced()

	inst:AddTag("scarytoprey")
	inst:AddTag("scarytooceanprey")
	inst:AddTag("monster")
	inst:AddTag("animal")
	inst:AddTag("largecreature")
	inst:AddTag("shark")
	inst:AddTag("wet")
	inst:AddTag("epic")
	inst:AddTag("noepicmusic") --add this when we have custom music!

	inst.no_wet_prefix = true

	--Sneak these into pristine state for optimization
	inst:AddTag("_named")

	inst.AnimState:SetBank("sharkboi")
	inst.AnimState:SetBuild("sharkboi_build")
	inst.AnimState:PlayAnimation("idle", true)

	inst:AddComponent("talker")
	inst.components.talker.fontsize = 40
	inst.components.talker.font = TALKINGFONT
	inst.components.talker.colour = Vector3(unpack(WET_TEXT_COLOUR))
	inst.components.talker.offset = Vector3(0, -400, 0)
	inst.components.talker.symbol = "sharkboi_cloak"
	inst.components.talker:MakeChatter()

	inst.finmode = net_bool(inst.GUID, "sharkboi.finmode", "finmodedirty")

	inst.entity:SetPristine()

	--Dedicated server does not need to trigger music
	if not TheNet:IsDedicated() then
		inst._playingmusic = false
		inst:DoPeriodicTask(1, PushMusic, 0)
	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("finmodedirty", OnFinModeDirty)

		return inst
	end

	--Remove these tags so that they can be added properly when replicating components below
	inst:RemoveTag("_named")

	inst:AddComponent("named")
	inst.components.named.possiblenames = STRINGS.SHARKBOINAMES
	inst.components.named:PickNewName()

	inst:AddComponent("inspectable")

	inst.components.talker.ontalk = OnTalk

	--[[inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("sharkboi")
	inst.components.lootdropper.min_speed = 1
	inst.components.lootdropper.max_speed = 3
	inst.components.lootdropper.y_speed = 14
	inst.components.lootdropper.y_speed_variance = 4
	inst.components.lootdropper.spawn_loot_inside_prefab = true]]

	inst:AddComponent("sleeper")
	inst.components.sleeper:SetResistance(4)
	inst.components.sleeper:SetSleepTest(ShouldSleep)
	inst.components.sleeper:SetWakeTest(ShouldWake)
	inst.components.sleeper.diminishingreturns = true

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.SHARKBOI_WALKSPEED
	inst.components.locomotor.runspeed = TUNING.SHARKBOI_RUNSPEED

	inst:AddComponent("health")
	inst.components.health:SetMinHealth(1)
	inst.components.health:SetMaxHealth(TUNING.SHARKBOI_HEALTH)
	--inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.SHARKBOI_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.SHARKBOI_ATTACK_PERIOD)
	inst.components.combat.playerdamagepercent = .5
	inst.components.combat:SetRange(TUNING.SHARKBOI_MELEE_RANGE)
	inst.components.combat:SetRetargetFunction(3, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.hiteffectsymbol = "sharkboi_torso"
	inst.components.combat.battlecryenabled = false
	inst.components.combat.forcefacing = false

	inst:AddComponent("timer")
	inst:AddComponent("grouptargeter")

	local teleportedoverride = inst:AddComponent("teleportedoverride")
    teleportedoverride:SetDestPositionFn(teleport_override_fn)

	MakeLargeFreezableCharacter(inst, "sharkboi_torso")
	inst.components.freezable:SetResistance(4)
	inst.components.freezable.diminishingreturns = true

	inst:SetStateGraph("SGsharkboi")
	inst:SetBrain(brain)

	inst:ListenForEvent("newstate", OnNewState)
	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("killed", OnKilledOther)

	inst.trading = false
	inst.StopAggro = StopAggro
	inst.MakeTrader = MakeTrader
	inst.GiveReward = GiveReward
	inst.SetIsTradingFlag = SetIsTradingFlag
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake

	return inst
end

return Prefab("sharkboi", fn, assets, prefabs)
