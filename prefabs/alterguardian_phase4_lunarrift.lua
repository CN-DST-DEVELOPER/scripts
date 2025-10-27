local assets =
{
	Asset("ANIM", "anim/wagboss_lunar.zip"),
	Asset("ANIM", "anim/wagboss_lunar_actions.zip"),
	Asset("ANIM", "anim/wagboss_lunar_spawn.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagboss_util.lua"),

	--finale
	Asset("ANIM", "anim/wagboss_robot.zip"),
	Asset("ANIM", "anim/wagboss_lunar_blast.zip"),
	Asset("ANIM", "anim/static_ball_contained.zip"),
}

local assets_slamfx =
{
	Asset("ANIM", "anim/bomb_lunarplant.zip"),
	Asset("ANIM", "anim/sleepcloud.zip"),
	Asset("ANIM", "anim/wagboss_robot.zip"),
}

local assets_erruptfx =
{
	Asset("ANIM", "anim/wagboss_lunar_blast.zip"),
}

local prefabs =
{
	"alterguardian_phase4_lunarrift_slam_fx",
	"alterguardian_phase4_lunarrift_erupt_fx",
	"alterguardian_lunar_fissures",
	"alterguardian_lunar_supernova_burn_fx",

	"wagstaff_npc_finale_fx",
	"wagstaff_item_1",
	"wagstaff_item_2",

	--loot
	"lunar_seed",
	"purebrilliance",
	"gears",
	"temp_beta_msg", --#TEMP_BETA
    "chesspiece_wagboss_lunar_sketch",
}

SetSharedLootTable("alterguardian_phase4_lunarrift",
{
	{ "lunar_seed",			1.0 },
	{ "lunar_seed",			1.0 },
	{ "lunar_seed",			1.0 },
	{ "lunar_seed",			1.0 },
	{ "lunar_seed",			1.0 },

	{ "purebrilliance",		1.0 },
	{ "purebrilliance",		1.0 },
	{ "purebrilliance",		1.0 },
	{ "purebrilliance",		1.0 },
	{ "purebrilliance",		1.0 },
	{ "purebrilliance",		0.7 },
	{ "purebrilliance",		0.3 },

	{ "trinket_6",			1.0 },
	{ "trinket_6",			1.0 },
	{ "trinket_6",			0.7 },
	{ "gears",				1.0 },
	{ "gears",				0.5 },

	{"chesspiece_wagboss_lunar_sketch", 1.0},
})

local WAGSTAFF_LOOT =
{
	"wagstaff_item_1",
	"wagstaff_item_2",
}

local brain = require("brains/alterguardian_phase4_lunarriftbrain")

local TRANSPARENCY = 0.2
local LIGHTOVERRIDE = 0.5

--------------------------------------------------------------------------

local function CreateDashFx()
	local fx = CreateEntity()

	fx:AddTag("DECOR")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBank("wagboss_lunar_blast")
	fx.AnimState:SetBuild("wagboss_lunar_blast")
	fx.AnimState:PlayAnimation("dash_wave", true)
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(3)
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY * 2)
	fx.AnimState:SetLightOverride(LIGHTOVERRIDE)

	return fx
end

local function OnShowDashFx(inst)
	if inst.showdashfx:value() then
		if inst.dashfx == nil then
			inst.dashfx = CreateDashFx()
			inst.dashfx.entity:SetParent(inst.entity)
		end
	elseif inst.dashfx then
		inst.dashfx:Remove()
		inst.dashfx = nil
	end
end

local function StartDashFx(inst)
	if not inst.showdashfx:value() then
		inst.showdashfx:set(true)
		if not TheNet:IsDedicated() then
			OnShowDashFx(inst)
		end
	end
end

local function StopDashFx(inst)
	if inst.showdashfx:value() then
		inst.showdashfx:set(false)
		if not TheNet:IsDedicated() then
			OnShowDashFx(inst)
		end
	end
end

--------------------------------------------------------------------------

local ENTER_DOMAIN_RANGE = 24
local ENTER_DOMAIN_RANGE_SQ = ENTER_DOMAIN_RANGE * ENTER_DOMAIN_RANGE
local EXIT_DOMAIN_RANGE_SQ = 32 * 32

local function DomainExpansionUpdate(inst)
	local indomain = inst._playersindomain
	local x, _, z = inst.Transform:GetWorldPosition()
	local map = TheWorld.Map
	if map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z) then
		for i, v in ipairs(AllPlayers) do
			if v.components.sanity == nil then
				indomain = nil
			elseif map:IsPointInWagPunkArena(v.Transform:GetWorldPosition()) then
				if indomain[v] == nil then
					v.components.sanity:EnableLunacy(true, inst)
				end
				indomain[v] = false --pending enter or stay in domain
			elseif indomain[v] then
				v.components.sanity:EnableLunacy(false, inst)
				indomain[v] = nil
			end
		end
	else
		for i, v in ipairs(AllPlayers) do
			if v.components.sanity == nil then
				indomain[v] = nil
			elseif indomain[v] then
				if v:GetDistanceSqToPoint(x, 0, z) < EXIT_DOMAIN_RANGE_SQ then
					indomain[v] = false --pending stay in domain
				else
					v.components.sanity:EnableLunacy(false, inst)
					indomain[v] = nil
				end
			elseif v:GetDistanceSqToPoint(x, 0, z) < ENTER_DOMAIN_RANGE_SQ then
				v.components.sanity:EnableLunacy(true, inst)
				indomain[v] = false --pending enter domain
			end
		end
	end
	for k, v in pairs(indomain) do
		if v then
			if k:IsValid() and k.components.sanity then
				k.components.sanity:EnableLunacy(false, inst)
			end
			indomain[k] = nil
		else
			indomain[k] = true
		end
	end
end

local function StartDomainExpansion(inst)
	if inst._domainexpansiontask == nil then
		inst._domainexpansiontask = inst:DoPeriodicTask(0.5, DomainExpansionUpdate)
		if inst._playersindomain == nil then
			inst._playersindomain = {}
		end
		DomainExpansionUpdate(inst)
	end
end

local function StopDomainExpansion(inst, istempstop)
	if inst._domainexpansiontask then
		inst._domainexpansiontask:Cancel()
		inst._domainexpansiontask = nil
		for k in pairs(inst._playersindomain) do
			if k:IsValid() and k.components.sanity then
				k.components.sanity:EnableLunacy(false, inst)
			end
			inst._playersindomain[k] = nil
		end
	end
	if not istempstop then
		inst._playersindomain = nil
	end
end

--------------------------------------------------------------------------

local function teleport_override_fn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsPointInWagPunkArena(x, y, z) then
		return Vector3(x, y, z)
	end
end

--------------------------------------------------------------------------
--Client follow symbol functions

local function OnRemoveHighlightChild(child)
	table.removearrayvalue(child.highlightparent.highlightchildren, child)
end

local function AddCrownFlameFx(inst, crown, idx)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_lunar")

	fx.AnimState:PlayAnimation("flame_loop", true)
	fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)
	fx.Follower:FollowSymbol(crown.GUID, "lb_flame_loop_follow_"..tostring(idx), nil, nil, nil, true)

	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	fx.AnimState:SetLightOverride(LIGHTOVERRIDE)

	fx.entity:SetParent(crown.entity)

	table.insert(crown.flames, fx)
	table.insert(inst.followfx, fx)
	table.insert(inst.highlightchildren, fx)
	fx.highlightparent = inst
	fx.OnRemoveEntity = OnRemoveHighlightChild

	return fx
end

local function AddCrownLayer(inst, layer, numflames)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_lunar")
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	fx.AnimState:SetLightOverride(LIGHTOVERRIDE)

	local baseanim = "crown_"..layer
	fx.AnimState:PlayAnimation(baseanim.."_loop")

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, baseanim.."_follow", nil, nil, nil, true, true)

	fx.flames = {}
	for i = 1, numflames do
		AddCrownFlameFx(inst, fx, i)
	end

	return fx
end

local function AddCrownFx(inst)
	local fr = AddCrownLayer(inst, "fr", 2)
	local bk = AddCrownLayer(inst, "bk", 3)
	fr:ListenForEvent("animover", function()
		fr.AnimState:PlayAnimation("crown_fr_loop")
		bk.AnimState:PlayAnimation("crown_bk_loop")
		local t = bk.flames[#bk.flames].AnimState:GetCurrentAnimationTime()
		for i, v in ipairs(fr.flames) do
			local t1 = v.AnimState:GetCurrentAnimationTime()
			v.AnimState:SetTime(t)
			t = t1
		end
		for i, v in pairs(bk.flames) do
			local t1 = v.AnimState:GetCurrentAnimationTime()
			v.AnimState:SetTime(t)
			t = t1
		end
	end)
end

local function AddFollowFx(inst, anim, symbol, frame, alpha, usefacings)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	if usefacings then
		fx.Transform:SetFourFaced()
	end

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_lunar")

	if frame then
		--V2C: -not bothering with AnimState:SetPercent's weird math under the hood.
		--     -it's safe enough to use Pause(), just be mindful of that conflicting with RemoveFromScene/ReturnToScene.
		fx.AnimState:PlayAnimation(anim)
		fx.AnimState:SetFrame(frame - 1)
		fx.AnimState:Pause()
		fx.Follower:FollowSymbol(inst.GUID, symbol, nil, nil, nil, true, nil, frame - 1)
	else
		fx.AnimState:PlayAnimation(anim, true)
		fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)
		fx.Follower:FollowSymbol(inst.GUID, symbol, nil, nil, nil, true)
	end

	if alpha then
		fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		fx.AnimState:SetMultColour(1, 1, 1, alpha)
		fx.AnimState:SetLightOverride(LIGHTOVERRIDE)
	else
		fx.AnimState:SetLightOverride(0.06)
	end

	fx.entity:SetParent(inst.entity)

	table.insert(inst.followfx, fx)
	table.insert(inst.highlightchildren, fx)
	fx.highlightparent = inst
	fx.OnRemoveEntity = OnRemoveHighlightChild

	return fx
end

local function OnAddColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.followfx) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function SwapAnim(fx, from, to)
	if fx.AnimState:IsCurrentAnimation(from) then
		local t = fx.AnimState:GetCurrentAnimationTime()
		fx.AnimState:PlayAnimation(to)
		fx.AnimState:SetTime(t)
	end
end

local function OnFacings(inst)
	local facings = inst.facings:value()
	local fxfr = inst.followfx[1]
	local fxbk = inst.followfx[2]
	if facings == 1 then
		fxfr.Transform:SetEightFaced()
		fxbk.Transform:SetEightFaced()
	elseif facings == 3 then
		fxfr.Transform:SetSixFaced()
		fxbk.Transform:SetSixFaced()
	else
		fxfr.Transform:SetFourFaced()
		fxbk.Transform:SetFourFaced()
	end
	if facings >= 2 then
		SwapAnim(fxfr, "float_fr_loop", "float_fr_loop_nofaced")
		SwapAnim(fxbk, "float_bk_loop", "float_bk_loop_nofaced")
	else
		SwapAnim(fxfr, "float_fr_loop_nofaced", "float_fr_loop")
		SwapAnim(fxbk, "float_bk_loop_nofaced", "float_bk_loop")
	end
end

local function SwitchToEightFaced(inst)
	if inst.facings:value() ~= 1 then
		inst.facings:set(1)
		if inst.followfx then
			OnFacings(inst)
		end
		inst.Transform:SetEightFaced()
	end
end

local function SwitchToFourFaced(inst)
	local old = inst.facings:value()
	if old ~= 0 then
		inst.facings:set(0)
		if inst.followfx then
			OnFacings(inst)
		end
		if old ~= 2 then --2 is already FourFaced
			inst.Transform:SetFourFaced()
		end
	end
end

local function SwitchToNoFaced(inst)
	--no-faced anim, flips should match FourFaced model.
	local old = inst.facings:value()
	if old ~= 2 then
		inst.facings:set(2)
		if inst.followfx then
			OnFacings(inst)
		end
		if old ~= 0 then --0 is already FourFaced
			inst.Transform:SetFourFaced()
		end
	end
end

local function SwitchToTwoFaced(inst)
	--no-faced but flippable. Works best with no-faced anim & SixFaced model.
	if inst.facings:value() ~= 3 then
		inst.facings:set(3)
		if inst.followfx then
			OnFacings(inst)
		end
		inst.Transform:SetSixFaced()
	end
end

local function InitCheckSpawnBuild(inst)
	inst.inittask = nil
	if inst.sg.mem.hasspawnbuild and inst.sg.currentstate.name ~= "spawn" then
		inst.sg.mem.hasspawnbuild = nil
		--More optimal to clear this config if we're not using "spawn" state again.
		inst.AnimState:Show("robot_front")
		inst.AnimState:Show("robot_back")
		inst.AnimState:ClearOverrideSymbol("splat_liquid")
		inst.AnimState:SetFinalOffset(-1)

		inst.SoundEmitter:PlaySound("rifts5/lunar_boss/idle_b_LP", "idleb")

		inst:StartDomainExpansion()
		inst:SetMusicLevel(3)
	end
end

--------------------------------------------------------------------------

local PHASES =
{
	{
		hp = 1,
		fn = function(inst)
			inst.dashcombo = 1
			inst.dashcount = 0
			inst.dashrnd = false
			inst.dashcenter = false
			inst.slamcombo = nil
			inst.slamcount = nil
			inst.slamrnd = false
			inst.cansupernova = false
		end,
	},
	{
		hp = 0.95,
		fn = function(inst)
			inst.dashcombo = 2
			inst.dashcount = inst.dashcount or 0
			inst.dashrnd = false
			inst.dashcenter = false
			inst.slamcombo = 1
			inst.slamcount = inst.slamcount or 0
			inst.slamrnd = false
			inst.cansupernova = false
		end,
	},
	{
		hp = 0.75,
		fn = function(inst)
			inst.dashcombo = 2
			inst.dashcount = inst.dashcount or 0
			inst.dashrnd = true
			inst.dashcenter = false
			inst.slamcombo = 1
			inst.slamcount = inst.slamcount or 0
			inst.slamrnd = false
			inst.cansupernova = false
		end,
	},
	{
		hp = 0.65,
		fn = function(inst)
			inst.dashcombo = 2
			inst.dashcount = inst.dashcount or 0
			inst.dashrnd = true
			inst.dashcenter = true
			inst.slamcombo = 2
			inst.slamcount = inst.slamcount or 0
			inst.slamrnd = true
			inst.cansupernova = true
		end,
	},
}

local DEESCALATE_TIME = 30

local function CalcThreatLevel(dps)
	local numthreatlevels = #TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_PERIOD
	return math.clamp(math.floor(Remap(dps, 150, 375, 1, numthreatlevels)), 1, numthreatlevels)
end

local function SetThreatLevel(inst, level)
	if inst._threattask then
		inst._threattask:Cancel()
	end
	inst._threattask = level > 1 and inst:DoTaskInTime(DEESCALATE_TIME, SetThreatLevel, level - 1) or nil

	if level ~= inst.threatlevel then
		if inst.threatlevel then
			print(inst, "threat level "..(level > inst.threatlevel and "raised" or "lowered").." to "..tostring(level))
		end
		inst.threatlevel = level
		inst.components.combat:SetAttackPeriod(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_PERIOD[level])
	end
end

local function OnDpsUpdate(inst, dps)
	local threatlevel = CalcThreatLevel(dps)
	if threatlevel >= inst.threatlevel then
		SetThreatLevel(inst, threatlevel)
	end
end

--------------------------------------------------------------------------

local function UpdatePlayerTargets(inst)
	assert(next(inst._temptbl1) == nil and next(inst._temptbl2) == nil)
	local toadd = inst._temptbl1
	local toremove = inst._temptbl2
	local x, y, z = inst.Transform:GetWorldPosition()

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		toremove[k] = true
	end

	local map = TheWorld.Map
	if map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) then
		for i, v in ipairs(AllPlayers) do
			if not (v.components.health:IsDead() or v:HasTag("playerghost")) and
				v.entity:IsVisible() and
				map:IsPointInWagPunkArena(v.Transform:GetWorldPosition())
			then
				if toremove[v] then
					toremove[v] = nil
				else
					table.insert(toadd, v)
				end
			end
		end
	else
		for i, v in ipairs(FindPlayersInRange(x, y, z, TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_DEAGGRO_DIST, true)) do
			if toremove[v] then
				toremove[v] = nil
			else
				table.insert(toadd, v)
			end
		end
	end

	for k in pairs(toremove) do
		inst.components.grouptargeter:RemoveTarget(k)
		toremove[k] = nil
	end
	for i = 1, #toadd do
		inst.components.grouptargeter:AddTarget(toadd[i])
		toadd[i] = nil
	end
	--assert(next(toadd) == nil and next(toremove) == nil)
end

local function RetargetFn(inst)
	UpdatePlayerTargets(inst)

	local x, y, z = inst.Transform:GetWorldPosition()
	local map = TheWorld.Map
	local inarena = map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z)
	local target = inst.components.combat.target
	local inrange
	if target then
		local range = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_RANGE + target:GetPhysicsRadius(0)
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local dsq = distsq(x1, z1, x, z)
		local arenacheck = not inarena or map:IsPointInWagPunkArena(x1, y1, z1)
		inrange = arenacheck and dsq < range * range

		if target.isplayer then
			if inst:IsSlamNext() and (inrange or (arenacheck and dsq < TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_KEEP_AGGRO_DIST * TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_KEEP_AGGRO_DIST)) then
				return --don't switch player targets when we're about to slam
			end
			--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
			local newplayer = inst.components.grouptargeter:TryGetNewTarget()
			if newplayer then
				range = inrange and TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_KEEP_AGGRO_DIST
				if newplayer:GetDistanceSqToPoint(x, y, z) < range * range then
					return newplayer, true
				end
			end
			return
		end
	end

	--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
	assert(next(inst._temptbl1) == nil)
	local nearplayers = inst._temptbl1
	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		local range = inrange and TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_RANGE + k:GetPhysicsRadius(0) or inst.aggrodist
		if k:GetDistanceSqToPoint(x, y, z) < range * range then
			table.insert(nearplayers, k)
		end
	end
	if #nearplayers > 0 then
		local newplayer = nearplayers[math.random(#nearplayers)]
		for k in pairs(nearplayers) do
			nearplayers[k] = nil
		end
		--assert(next(nearplayers) == nil)
		return newplayer, true
	end
	--assert(next(nearplayers) == nil)
end

local function KeepTargetFn(inst, target)
	if not inst.components.combat:CanTarget(target) then
		return false
	end
	local x, y, z = inst.Transform:GetWorldPosition()
	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local map = TheWorld.Map
	if map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) then
		return map:IsPointInWagPunkArena(x1, y1, z1)
	end
	return distsq(x, z, x1, z1) < TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_DEAGGRO_DIST * TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_DEAGGRO_DIST
end

local function OnAttacked(inst, data)
	if data and data.attacker and data.attacker:IsValid() then
		local x, y, z = inst.Transform:GetWorldPosition()
		local target = inst.components.combat.target
		if target and target.isplayer then
			local range =
				inst:IsSlamNext() and
				TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_KEEP_AGGRO_DIST or
				TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_RANGE + target:GetPhysicsRadius(0)
			if target:GetDistanceSqToPoint(x, y, z) < range * range then
				return --don't switch targets
			end
		end
		local map = TheWorld.Map
		if not map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) or map:IsPointInWagPunkArena(data.attacker.Transform:GetWorldPosition()) then
			inst.components.combat:SetTarget(data.attacker)
		end
	end
end

local function ResetCombo(inst)
	inst.dashcount = inst.dashcount and 0 or nil
	inst.slamcount = inst.slamcount and 0 or nil
end

local function IsSlamNext(inst)
	return inst.dashcombo and inst.dashcount >= inst.dashcombo
		and inst.slamcombo and inst.slamcount < inst.slamcombo
end

local function SetEngaged(inst, engaged, delay)
	if delay then
		if inst._engagetask == nil or inst._engagetask ~= engaged then
			if inst._engagetask then
				inst._engagetask:Cancel()
			end
			inst._engagetask = inst:DoTaskInTime(delay, SetEngaged, engaged)
			inst._engagetask.engaged = engaged
		end
	else
		if inst._engagetask then
			inst._engagetask:Cancel()
			inst._engagetask = nil
		end
		if inst.engaged ~= engaged then
			inst.engaged = engaged
			ResetCombo(inst)

			if engaged then
				inst.aggrodist = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_AGGRO_DIST
			else
				inst:PushEvent("resetboss")
				inst.components.health:SetPercent(1)
				PHASES[1].fn(inst)
				inst.aggrodist = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_SHORT_AGGRO_DIST
			end
		end
	end
end

local function OnNewTarget(inst, data)
	if data and data.target then
		SetEngaged(inst, true)
	end
end

local function OnDroppedTarget(inst)--, data)
	SetEngaged(inst, false, 10)
end

local function OnSave(inst, data)
	data.engaged = inst.engaged or nil
end

local function OnLoad(inst, data)--, ents)
	if inst.inittask then
		inst.inittask:Cancel()
		InitCheckSpawnBuild(inst)
		inst.aggrodist = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_SHORT_AGGRO_DIST
	end
	local healthpct = inst.components.health:GetPercent()
	for i = #PHASES, 2, -1 do
		local v = PHASES[i]
		if healthpct <= v.hp then
			v.fn(inst)
			break
		end
	end
	if data and data.engaged and not inst.engaged then
		SetEngaged(inst, true)
		SetEngaged(inst, false, 10)
	end
	if not inst.components.health:IsDead() then
		inst:SetMusicLevel(3)
	end
end

local function OnEntitySleep(inst)
	inst:StopDomainExpansion(true)
	if inst.sg:HasAnyStateTag("jumping", "attack") then
		inst.sg:GoToState("idle")
	end
end

local function OnEntityWake(inst)
	if inst._playersindomain then
		inst:StartDomainExpansion()
	end
end

local function PushSupernovaMix(inst, enable)
	if enable then
		if not inst._supernovamix then
			inst._supernovamix = true
			TheMixer:PushMix("supernova_charging")
		end
	elseif inst._supernovamix then
		inst._supernovamix = nil
		TheMixer:PopMix("supernova_charging")
	end
end

local function OnRemoveEntity_Client(inst)
	PushSupernovaMix(inst, false)
end

local function OnRemoveEntity(inst)
	OnRemoveEntity_Client(inst)
	inst:StopDomainExpansion()
	if inst.persists and TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(inst.Transform:GetWorldPosition()) then
		TheWorld:PushEvent("ms_wagboss_alter_defeated", inst)
	end
end

local function LootSetupFn(lootdropper)
	lootdropper:SetLoot(lootdropper.inst.sg.statemem.wagstaff and WAGSTAFF_LOOT or nil)
	lootdropper:SetChanceLootTable("alterguardian_phase4_lunarrift")
end

local function CalcSanityAura(inst, observer)
	local map = TheWorld.Map
	inst._sanityaura_inarena = map:IsPointInWagPunkArenaAndBarrierIsUp(inst.Transform:GetWorldPosition())
	if inst._sanityaura_inarena then
		return map:IsPointInWagPunkArena(observer.Transform:GetWorldPosition()) and TUNING.SANITYAURA_HUGE or 0
	end
	return inst.components.combat:HasTarget() and TUNING.SANITYAURA_HUGE or TUNING.SANITYAURA_LARGE
end

local function SanityAuraFalloff(inst, observer, distsq)
	return not inst._sanityaura_inarena and distsq > ENTER_DOMAIN_RANGE_SQ and math.huge or nil
end

--------------------------------------------------------------------------

local function PushMusic(inst)
	if ThePlayer == nil then
		inst._playingmusic = false
		PushSupernovaMix(inst, false)
	else
		local map = TheWorld.Map
		local x, _, z = inst.Transform:GetWorldPosition()
		if map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z) then
			if map:IsPointInWagPunkArena(ThePlayer.Transform:GetWorldPosition()) then
				inst._playingmusic = true
				ThePlayer:PushEvent("triggeredevent", { name = "wagboss", level = inst.music:value() })
			else
				inst._playingmusic = false
			end
		else
			local dsq = ThePlayer:GetDistanceSqToPoint(x, 0, z)
			if dsq < (inst._playingmusic and EXIT_DOMAIN_RANGE_SQ or ENTER_DOMAIN_RANGE_SQ) then
				inst._playingmusic = true
				ThePlayer:PushEvent("triggeredevent", { name = "wagboss", level = inst.music:value() })
			elseif inst._playingmusic and dsq >= 40 * 40 then
				inst._playingmusic = false
			end
		end
		PushSupernovaMix(inst, inst._playingmusic and inst:HasTag("supernova"))
	end
end

local function OnMusicDirty(inst)
	if inst.music:value() > 0 then
		if inst._musictask == nil then
			inst._musictask = inst:DoPeriodicTask(1, PushMusic)
		end
		PushMusic(inst)
	elseif inst._musictask then
		inst._musictask:Cancel()
		inst._musictask = nil
		inst._playingmusic = false
	end
end

local function SetMusicLevel(inst, level, forced)
	if forced then
		inst.music:set_local(7) --force dirty
	end
	if level ~= inst.music:value() then
		inst.music:set(level)

		--Dedicated server does not need to trigger music
		if not TheNet:IsDedicated() then
			OnMusicDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function OnCameraFocusDirty(inst)
	if inst.camerafocus:value() then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 6, 22, 4)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function EnableCameraFocus(inst, enable)
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			OnCameraFocusDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local SCRAPBOOK_SYMBOLCOLOURS = {
	{"lb_glow", 1, 1, 1, 0.375},
	--{"lb_flame_loop", 1, 1, 1, 0.75},
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("wagboss_lunar")
	inst.AnimState:SetBuild("wagboss_lunar")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	inst.AnimState:UsePointFiltering(true)
	inst.AnimState:Hide("robot_front")
	inst.AnimState:Hide("robot_back")
	inst.AnimState:OverrideSymbol("splat_liquid", "wagboss_lunar_spawn", "splat_liquid")
	inst.AnimState:SetFinalOffset(-2)
	inst.AnimState:SetLightOverride(LIGHTOVERRIDE)

	MakeGiantCharacterPhysics(inst, 1000, 2)
	inst.Physics:SetCollisionMask(COLLISION.WORLD)

	inst:AddTag("brightmareboss")
	inst:AddTag("epic")
	inst:AddTag("hostile")
	inst:AddTag("largecreature")
	inst:AddTag("monster")
	inst:AddTag("noepicmusic")
	inst:AddTag("scarytoprey")
	inst:AddTag("soulless")
	inst:AddTag("lunar_aligned")

	--rainimmunity (from rainimmunity component) added to pristine state for optimization
	inst:AddTag("rainimmunity")

	inst:AddComponent("colouraddersync")

	inst.showdashfx = net_bool(inst.GUID, "alterguardian_phase4_lunarrift.showdashfx", "showdashfxdirty")
	inst.facings = net_tinybyte(inst.GUID, "alterguardian_phase4_lunarrift.facings", "facingsdirty")
	inst.music = net_tinybyte(inst.GUID, "alterguardian_phase4_lunarrift.music", "musicdirty")
	inst.camerafocus = net_bool(inst.GUID, "alterguardian_phase4_lunarrift.camerafocus", "camerafocusdirty")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.followfx = {}
		inst.highlightchildren = {}

		--NOTE: float_fr/bk MUST be first! See OnFacings()
		--body wires and floating bits (solid)
		AddFollowFx(inst, "float_fr_loop", "lb_float_fr_follow", nil, nil, true)
		AddFollowFx(inst, "float_bk_loop", "lb_float_bk_follow", nil, nil, true)
		AddFollowFx(inst, "wire_loop", "lb_wire_follow", nil, nil, false)

		--leg wires (solid)
		for i = 1, 2 do
			AddFollowFx(inst, "leg_wire", "lb_leg_wire_follow", i, nil, false)
		end
		AddFollowFx(inst, "leg_wire", "lb_leg_wire_follow", 22, nil, false)
		local tail = AddFollowFx(inst, "tail_wire", "lb_tail_wire_follow", nil, nil, false)
		tail.AnimState:SetSymbolBloom("lb_leg_alpha_ol")
		tail.AnimState:SetSymbolMultColour("lb_leg_alpha_ol", 1, 1, 1, TRANSPARENCY)
		tail.AnimState:SetSymbolLightOverride("lb_leg_alpha_ol", LIGHTOVERRIDE)
		for i = 1, 2 do
			AddFollowFx(inst, "feet_wire", "lb_feet_wire_follow", i, nil, false)
		end

		--body transparent parts
		for i = 1, 4 do
			AddFollowFx(inst, "body_loop", "lb_head_loop_follow_"..tostring(i), nil, TRANSPARENCY, false)
		end
		for i = 1, 3 do
			AddFollowFx(inst, "flame_loop", "lb_flame_loop_follow_"..tostring(i), nil, TRANSPARENCY, false)
		end

		--crown
		AddCrownFx(inst)

		inst.components.colouraddersync:SetColourChangedFn(OnAddColourChanged)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("facingsdirty", OnFacings)
		inst:ListenForEvent("showdashfxdirty", OnShowDashFx)
		inst:ListenForEvent("musicdirty", OnMusicDirty)
		inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)

		inst.OnRemoveEntity = OnRemoveEntity_Client

		return inst
	end

	inst.scrapbook_anim = "scrapbook"
	inst.scrapbook_symbolcolours = SCRAPBOOK_SYMBOLCOLOURS

	inst:AddComponent("inspectable")

	inst:AddComponent("rainimmunity")
	inst.components.rainimmunity:AddSource(inst)

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_HEALTH)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_DAMAGE)
	--inst.components.combat:SetAttackPeriod(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_PERIOD[1])
	inst.components.combat:SetRange(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_ATTACK_RANGE)
	inst.components.combat:SetRetargetFunction(1, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.playerdamagepercent = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_PLAYERDAMAGEPERCENT
	inst.components.combat.hiteffectsymbol = "lb_head_loop_follow_4"
	inst.components.combat.battlecryenabled = false

	inst:AddComponent("healthtrigger")
	for i, v in ipairs(PHASES) do
		inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
	end
	PHASES[1].fn(inst)

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_PLANAR_DAMAGE)

	inst:AddComponent("explosiveresist")

	inst:AddComponent("epicscare")
	inst.components.epicscare:SetRange(ENTER_DOMAIN_RANGE)

	inst:AddComponent("dpstracker")
	inst.components.dpstracker:SetOnDpsUpdateFn(OnDpsUpdate)

	inst:AddComponent("timer")
	inst:AddComponent("grouptargeter")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aurafn = CalcSanityAura
	inst.components.sanityaura.fallofffn = SanityAuraFalloff
	inst.components.sanityaura.max_distsq = 40 * 40

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_WALKSPEED
	inst.components.locomotor.pathcaps = { ignorewalls = true }

	inst:AddComponent("colouradder")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetLootSetupFn(LootSetupFn)
	inst.components.lootdropper.min_speed = 1
	inst.components.lootdropper.max_speed = 3
	inst.components.lootdropper.y_speed = 14
	inst.components.lootdropper.y_speed_variance = 4
	inst.components.lootdropper.spawn_loot_inside_prefab = true

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("newcombattarget", OnNewTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)

	--inst.threatlevel = 1
	SetThreatLevel(inst, 1)

	inst._engagetask = nil
	inst.engaged = false
	inst.aggrodist = TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_AGGRO_DIST

	inst:SetStateGraph("SGalterguardian_phase4_lunarrift")
	inst:SetBrain(brain)

	inst._temptbl1 = {}
	inst._temptbl2 = {}
	inst._domainexpansiontask = nil
	inst._playersindomain = nil

	inst.sg.mem.hasspawnbuild = true
	inst.inittask = inst:DoTaskInTime(0, InitCheckSpawnBuild)

	inst.SwitchToEightFaced = SwitchToEightFaced
	inst.SwitchToFourFaced = SwitchToFourFaced
	inst.SwitchToNoFaced = SwitchToNoFaced
	inst.SwitchToTwoFaced = SwitchToTwoFaced
	inst.StartDashFx = StartDashFx
	inst.StopDashFx = StopDashFx
	inst.StartDomainExpansion = StartDomainExpansion
	inst.StopDomainExpansion = StopDomainExpansion
	inst.ResetCombo = ResetCombo
	inst.IsSlamNext = IsSlamNext
	inst.SetMusicLevel = SetMusicLevel
	inst.EnableCameraFocus = EnableCameraFocus
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake
	inst.OnRemoveEntity = OnRemoveEntity

	return inst
end

--------------------------------------------------------------------------

local function slamfx_CreateGroundFx()
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBank("wagboss_robot")
	fx.AnimState:SetBuild("wagboss_robot")
	fx.AnimState:PlayAnimation("atk_ground_projection")
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(3)
	fx.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	fx.AnimState:SetLightOverride(LIGHTOVERRIDE)

	--robot stomp radius 3.3
	--our slam radius 5
	local scale = 5 / 3.3
	fx.AnimState:SetScale(scale, scale)

	return fx
end

local function slamfx_PostUpdate_Client(inst)
	inst.ring.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
	inst.components.updatelooper:RemovePostUpdateFn(slamfx_PostUpdate_Client)
end

local function slamfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("bomb_lunarplant")
	inst.AnimState:SetBuild("bomb_lunarplant")
	inst.AnimState:PlayAnimation("used")
	inst.AnimState:Hide("bomb")
	inst.AnimState:OverrideSymbol("sleepcloud_pre", "sleepcloud", "sleepcloud_pre")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	inst.AnimState:SetAddColour(1, 1, 1, 0)
	inst.AnimState:UsePointFiltering(true)
	inst.AnimState:SetScale(2, 2)
	inst.AnimState:SetLightOverride(LIGHTOVERRIDE)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	if not TheNet:IsDedicated() then
		inst.ring = slamfx_CreateGroundFx()
		inst.ring.entity:SetParent(inst.entity)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(slamfx_PostUpdate_Client)

		return inst
	end

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function eruptfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("wagboss_lunar_blast")
	inst.AnimState:SetBuild("wagboss_lunar_blast")
	inst.AnimState:PlayAnimation("blast_01")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY * 2)
	inst.AnimState:SetLightOverride(LIGHTOVERRIDE)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	if math.random() < 0.5 then
		inst.AnimState:PlayAnimation("blast_02")
	end

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("alterguardian_phase4_lunarrift", fn, assets, prefabs),
	Prefab("alterguardian_phase4_lunarrift_slam_fx", slamfxfn, assets_slamfx),
	Prefab("alterguardian_phase4_lunarrift_erupt_fx", eruptfxfn, assets_erruptfx)
