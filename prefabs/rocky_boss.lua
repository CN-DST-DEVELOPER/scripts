local assets =
{
	Asset("ANIM", "anim/rocky.zip"),
	Asset("ANIM", "anim/rocky_boss.zip"),
	Asset("ANIM", "anim/rocky_boss_acid_build.zip"),
	Asset("ANIM", "anim/stalker_corrupt_fx_build.zip"),
	Asset("SOUND", "sound/rocklobster.fsb"),
}

local assets_shadow =
{
	Asset("ANIM", "anim/rocky.zip"),
	Asset("ANIM", "anim/rocky_boss.zip"),
	Asset("ANIM", "anim/rocky_boss_shadow_build.zip"),
	Asset("ANIM", "anim/stalker_corrupt_fx_build.zip"),
}

local assets_fx =
{
	Asset("ANIM", "anim/rocky_boss.zip"),
}

local prefabs =
{
	"armor_rocky",
	"rocks",
	"meat",
	"flint",
	"rockycorpse",
	"rocky_snip_fx",
	"rocky_dash_fx",
	"rocky_boss_shadow",
}

local prefabs_shadow =
{
	"atrium_ritual_organ_rocky",
	"horrorfuel",
	"nightmarefuel",
	"rocky_snip_fx",
	"rocky_dash_fx",
	"chesspiece_rockyboss_shadow_sketch",
}

local brain = require("brains/rocky_bossbrain")

SetSharedLootTable("rocky_boss_shadow",
{
	{ "atrium_ritual_organ_rocky",	1.00 },
	{ "horrorfuel",					1.00 },
	{ "horrorfuel",					1.00 },
	{ "horrorfuel",					0.50 },
	{ "nightmarefuel",				1.00 },
	{ "nightmarefuel",				0.67 },
	{ "chesspiece_rockyboss_shadow_sketch",	1.00 },
})

local LOOT = { "armor_rocky", "rocks", "rocks", "meat", "flint", "flint" }
local NITRELOOT = { "armor_rocky", "nitre", "nitre", "nitre", "nitre", "rocks", "rocks", "meat", "flint", "flint" }
local MASS = 200
local RADIUS = 0.65
local BOULDER_RADIUS = 1.2

local function ShouldSleep(inst) return false end
local function ShouldWake(inst) return true end

local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "INLIMBO", "rocky" }
local SHADOW_RETARGET_CANT_TAGS = { "INLIMBO", "rocky", "shadowthrall", "shadowboss", "stalker" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }
local function IsValidTarget(guy, inst)
	return inst.components.combat:CanTarget(guy)
end

local function RetargetFn(inst)
	return inst.components.workable == nil
		and FindEntity(inst, TUNING.ROCKY_TARGETRANGE, IsValidTarget, RETARGET_MUST_TAGS, inst:HasTag("shadowthrall") and SHADOW_RETARGET_CANT_TAGS or RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS)
		or nil
end

local SHADOW_SHARE_TAGS = { "shadowthrall" }
local PARASITE_SHARE_TAGS = { "_combat", "shadowthrall_parasite_hosted" }
local ROCKY_SHARE_TAGS = { "rocky" }
local function ValidShareTarget(v, inst)
	return not v:IsInLimbo()
end
local function OnAttacked(inst, data)
	if data and data.attacker then
		local target = inst.components.combat.target
		if not (target and
				target:HasTag(data.attacker.isplayer and "player" or "character") and
				inst:IsNear(target, inst.components.combat.attackrange + target:GetPhysicsRadius(0)))
		then
			inst.components.combat:SetTarget(data.attacker)
		end

		if not inst:HasTag("shadowthrall") then
			if inst:HasTag("shadowthrall_parasite_hosted") then
				inst.components.combat:ShareTarget(data.attacker, 20, ValidShareTarget, 10, PARASITE_SHARE_TAGS)
			else
				inst.components.combat:ShareTarget(data.attacker, 20, ValidShareTarget, 2, ROCKY_SHARE_TAGS)
			end
		end
	end
end

local function SetNitre(inst)
    inst.AnimState:SetBuild("rocky_boss_acid_build")
    inst.components.lootdropper:SetLoot(NITRELOOT)
end

local function ClearNitre(inst)
    inst.AnimState:SetBuild("rocky_boss")
    inst.components.lootdropper:SetLoot(LOOT)
end

local function OnAcidLevelDelta(inst, data)
    if not data then
        return
    end

    local oldacidic, newacidic = data.oldpercent, data.newpercent
    if newacidic > oldacidic then
        -- Grow nitre.
        if newacidic >= TUNING.ROCKY_ACIDRAIN_NITRE_STARTS_PERCENT then
            if not inst.nitregrowth then
                inst.nitregrowth = true
                inst.components.acidlevel:SetPercent(1) -- Make the extreme pop so when it flips state it has time to go backwards.
                SetNitre(inst)
            end
        end
    elseif newacidic < oldacidic then
        -- Dissolve nitre.
        if newacidic < TUNING.ROCKY_ACIDRAIN_NITRE_STARTS_PERCENT then
            if newacidic == 0 then
                if inst.nitregrowth then
                    inst.nitregrowth = nil
                    inst.components.acidlevel:SetPercent(0) -- Make the extreme pop so when it flips state it has time to go backwards.
                    ClearNitre(inst)
                end
            end
        end
    --else
        -- No change.
    end
end

local function OnStopIsAcidRaining(inst)
    if not inst.nitregrowth then -- Stop bubbling when idle even if slightly acidic.
        ClearNitre(inst)
    end
end

local function OnOverrideAcidRainTick(inst)
    return 0 -- no damage
end

local function OnWork(inst, worker, workleft, numworks)
	if numworks > 0 and worker and
		worker.components.combat and
		not worker.components.explosive --explosives will do work + combat already
	then
		--convert work to attack damage; guard against double depletion on tool.

		local tool = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		local efficientuser
		if tool then
			efficientuser = worker.components.efficientuser
			if efficientuser == nil then
				worker:AddComponent("efficientuser")
			end
			worker.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, 0, inst, "rockyshieldmining")
		end

		inst.components.health:SetAbsorptionAmount(0)
		worker.components.combat:DoAttack(inst, tool)
		if inst.isboulder:value() then
			inst.components.health:SetAbsorptionAmount(TUNING.ROCKY_ABSORB)
		end
		if inst.sg.currentstate.name == "shield" then
			inst.components.health:StartRegen(TUNING.ROCKY_REGEN_AMOUNT, TUNING.ROCKY_REGEN_PERIOD, true)
		end

		if tool then
			if efficientuser then
				efficientuser:RemoveMultiplier(ACTIONS.ATTACK, inst, "rockyshieldmining")
			else
				worker:RemoveComponent("efficientuser")
			end
		end
	end
end

local function OnWorkFinished(inst, worker)
	inst:PushEventImmediate("breakshield")
    if inst.nitregrowth then
        inst.components.lootdropper:SpawnLootPrefab("nitre")
        inst.components.lootdropper:SpawnLootPrefab("nitre")
        inst.components.lootdropper:SpawnLootPrefab("nitre")
        inst.components.lootdropper:SpawnLootPrefab("nitre")
        inst.components.acidlevel:SetPercent(0)
    end
end

local function OnIsBoulderDirty(inst)
	inst:SetPhysicsRadiusOverride((inst.isboulder:value() and BOULDER_RADIUS or RADIUS) * TUNING.ROCKY_BOSS_SCALE)
end

local function SetBoulderState(inst, enable)
	if enable then
		if not inst.isboulder:value() then
			inst:AddTag("nogelblob")
			inst.isboulder:set(true)
			OnIsBoulderDirty(inst)

			inst.components.health:SetAbsorptionAmount(TUNING.ROCKY_ABSORB)

			inst:AddComponent("workable")
			inst.components.workable:SetWorkAction(ACTIONS.MINE)
			inst.components.workable:SetWorkLeft(4)
			inst.components.workable:SetOnWorkCallback(OnWork)
			inst.components.workable:SetOnFinishCallback(OnWorkFinished)

			if inst.sg.mem.physicstask then
				inst.sg.mem.physicstask:Cancel()
				inst.sg.mem.physicstask = nil
			end
			inst.sg.mem.ischaracterpassthrough = nil
			inst.Physics:SetMass(0)
			inst.Physics:SetCollisionMask(
				COLLISION.CHARACTERS,
				COLLISION.GIANTS
			)
			inst.Physics:SetCapsule(BOULDER_RADIUS * TUNING.ROCKY_BOSS_SCALE, 1)
		end
	elseif inst.isboulder:value() then
        inst:RemoveTag("nogelblob")
		inst.isboulder:set(false)
		OnIsBoulderDirty(inst)

		inst.components.health:SetAbsorptionAmount(0)

		inst:RemoveComponent("workable")

		if inst.sg.mem.physicstask then
			inst.sg.mem.physicstask:Cancel()
			inst.sg.mem.physicstask = nil
		end
		inst.sg.mem.ischaracterpassthrough = nil
		inst.Physics:SetMass(MASS)
		inst.Physics:SetCollisionMask(
			COLLISION.WORLD,
			COLLISION.OBSTACLES,
			COLLISION.SMALLOBSTACLES,
			COLLISION.CHARACTERS,
			COLLISION.GIANTS
		)
		inst.Physics:SetCapsule(RADIUS * TUNING.ROCKY_BOSS_SCALE, 1)
	end
end

local function mirage_OnUpdate(fx, dt)
	fx._t = fx._t + dt
	if fx._t < 0.5 then
		local a = Remap(fx._t, 0, 0.5, 1, 0)
		a = a * a * 0.5
		fx.AnimState:SetMultColour(1, 1, 1, a)
		if fx.highlightchildren then
			for i, v in ipairs(fx.highlightchildren) do
				v.AnimState:SetMultColour(1, 1, 1, a)
			end
		end
	elseif fx.owner:IsValid() then
		fx.components.updatelooper:RemoveOnUpdateFn(mirage_OnUpdate)
		fx:RemoveFromScene()
		fx.entity:SetParent(fx.owner.entity)
		fx.Transform:SetPosition(0, 0, 0)

		if fx.owner._miragepool == nil then
			fx.owner._miragepool = { fx }
		else
			table.insert(fx.owner._miragepool, fx)
		end
	else
		fx:Remove()
	end
end

local function CreateFlameLoop()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("rocky")
	inst.AnimState:SetBuild("rocky_boss_shadow_build")
	inst.AnimState:PlayAnimation("flame_fx", true)
	inst.AnimState:SetSymbolLightOverride("fx_red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_flame_red", 1)

	return inst
end

local function GetMirageFx(inst)
	local fx
	if inst._miragepool and #inst._miragepool > 0 then
		fx = table.remove(inst._miragepool)
		fx.entity:SetParent(nil)
		fx:ReturnToScene()
	else
		fx = CreateEntity()

		fx:AddTag("NOCLICK")
		fx:AddTag("FX")
	    fx:AddTag("nointerpolate")
		--[[Non-networked entity]]
		fx.entity:SetCanSleep(TheWorld.ismastersim)
		fx.persists = false

		fx.entity:AddTransform()
		fx.entity:AddAnimState()

		fx.Transform:SetEightFaced()

		local scale = TUNING.ROCKY_BOSS_SCALE
		fx.Transform:SetScale(scale, scale, scale)

		fx.AnimState:SetBank("rocky")
		fx.AnimState:PlayAnimation("atk_dash")
		if inst:HasTag("shadowthrall") then
			fx.AnimState:SetSymbolLightOverride("fx_claw", 1)
			fx.AnimState:SetSymbolLightOverride("red", 1)

			local flame = CreateFlameLoop()
			flame.entity:SetParent(fx.entity)
			flame.Follower:FollowSymbol(fx.GUID, "follow_shoulder_L")

			fx.highlightchildren = { flame }

			flame = CreateFlameLoop()
			flame.entity:SetParent(fx.entity)
			flame.Follower:FollowSymbol(fx.GUID, "follow_shoulder_R")

			fx.highlightchildren[2] = flame
		else
			fx.AnimState:SetSymbolBloom("fx_claw")
		end

		fx:AddComponent("updatelooper")

		fx.owner = inst
	end

	fx.AnimState:SetBuild(inst.AnimState:GetBuild())
	fx.AnimState:Pause()
	fx.AnimState:SetMultColour(1, 1, 1, 0.5)
	if fx.highlightchildren then
		for i, v in ipairs(fx.highlightchildren) do
			v.AnimState:Pause()
			v.AnimState:SetMultColour(1, 1, 1, 0.5)
		end
	end

	fx.components.updatelooper:AddOnUpdateFn(mirage_OnUpdate)
	fx._t = 0

	return fx
end

local function MiragePostUpdate(inst)
	if inst.AnimState:IsCurrentAnimation("atk_dash") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame <= 15 then
			if frame >= 12 and frame ~= inst._mirageframe then
				local pt = inst._miragepos
				local x, y, z = inst.Transform:GetWorldPosition()
				if frame > 12 then
					local fx = GetMirageFx(inst)
					fx.Transform:SetPosition((x + pt.x) / 2, (y + pt.y) / 2, (z + pt.z) / 2)
					fx.Transform:SetRotation(inst.Transform:GetRotation())
					fx.AnimState:SetFrame(frame - 1)

					if fx.highlightchildren then
						for i, v in ipairs(fx.highlightchildren) do
							local otherchild = inst.highlightchildren[i]
							local flameframe = otherchild and otherchild.AnimState:GetCurrentAnimationFrame() or math.random(v.AnimState:GetCurrentAnimationNumFrames())
							v.AnimState:SetFrame(flameframe - 1)
						end
					end
				end
				pt.x, pt.y, pt.z = x, y, z
				inst._mirageframe = frame
			end
			return
		end
	end

	inst._mirageframe = nil
	inst._miragepos = nil
	inst.components.updatelooper:RemovePostUpdateFn(MiragePostUpdate)
end

local function OnStartMirage(inst)
	if inst._mirageframe == nil then
		inst._mirageframe = -1
		inst._miragepos = inst:GetPosition()
		inst.components.updatelooper:AddPostUpdateFn(MiragePostUpdate)
	end
end

local function StartMirage(inst)
	inst.startmirage:push()
	if not TheNet:IsDedicated() then
		OnStartMirage(inst)
	end
end

local function GetDashRange(inst)
	return inst.components.acidinfusible
		and inst.components.acidinfusible:IsInfused()
		and TUNING.ROCKY_BOSS_DASH_RANGE_ACID
		or TUNING.ROCKY_BOSS_DASH_RANGE
end

local function OnNewCombatTarget(inst, data)
    inst.components.timer:PauseTimer("bouldercd")

    if inst._disengagetask then
    	inst._disengagetask:Cancel()
    	inst._disengagetask = nil
	elseif data and data.target and data.oldtarget == nil then
		inst.components.timer:StopTimer("dashcd")
		inst.components.timer:StartTimer("dashcd", TUNING.ROCKY_BOSS_DASH_CD)
	end
end

local function Disengage(inst)
	inst._disengagetask = nil
end

local function OnDroppedTarget(inst)
	if inst._disengagetask == nil then
		inst._disengagetask = inst:DoTaskInTime(10, Disengage)
	end
	if not inst:IsAsleep() then
		inst.components.timer:ResumeTimer("bouldercd")
		inst.components.timer:SetTimeLeft(math.max(10 + math.random() * 10, inst.components.timer:GetTimeLeft("bouldercd") or 0))
	end
end

local function shadow_OnNewCombatTarget(inst, data)
	if inst._disengagetask then
		inst._disengagetask:Cancel()
		inst._disengagetask = nil
	elseif data and data.target and data.oldtarget == nil then
		inst.components.timer:StopTimer("dashcd")
		inst.components.timer:StartTimer("dashcd", TUNING.ROCKY_BOSS_DASH_CD)
	end
end

local function shadow_Disengage(inst)
	inst._disengagetask = nil
	inst.components.combat.battlecryenabled = true
end

local function shadow_OnDroppedTarget(inst)
	if inst._disengagetask == nil then
		inst._disengagetask = inst:DoTaskInTime(10, shadow_Disengage)
	end
end

local function GetStatus(inst)--, viewer)
    return (inst.components.workable ~= nil and "BOULDER") or
        (inst.nitregrowth and "ACID") or
        nil
end

local function OnEntityWake(inst)
    inst.components.timer:ResumeTimer("bouldercd")
end

local function OnEntitySleep(inst)
    inst.components.timer:PauseTimer("bouldercd")
end

local function DisplayNameFn(inst)
	return inst:HasTag("MINE_workable") and STRINGS.NAMES.ROCKY_BOSS_BOULDER or nil
end

local EATER_FOODTYPES = { FOODTYPE.ELEMENTAL }
local PATHCAPS = { ignorecreep = false }

local function commonfn(build, common_postinit, master_postinit)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	local scale = TUNING.ROCKY_BOSS_SCALE
	inst:SetPhysicsRadiusOverride(RADIUS * scale)
	MakeCharacterPhysics(inst, MASS, inst.physicsradiusoverride)

	inst.Transform:SetFourFaced()

	inst:AddTag("cavedweller")
	inst:AddTag("rocky")
	inst:AddTag("character")
	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("largecreature")
	inst:AddTag("electricdamageimmune")

	inst.AnimState:SetBank("rocky")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("idle_loop", true)

	inst.Transform:SetScale(scale, scale, scale)
	inst.DynamicShadow:SetSize(2 * scale, 1.5 * scale)

	inst.startmirage = net_event(inst.GUID, "rocky_boss.startmirage")

	if common_postinit then
		common_postinit(inst)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("rocky_boss.startmirage", OnStartMirage)

		return inst
	end

	inst:AddComponent("combat")
	inst.components.combat.hiteffectsymbol = "hips_art"
	inst.components.combat:SetAttackPeriod(3)
	inst.components.combat:SetRange(TUNING.ROCKY_ATTACK_RANGE * scale, TUNING.ROCKY_HIT_RANGE * scale)
	inst.components.combat:SetHitArc(TUNING.DEFAULT_HIT_ARC)
	inst.components.combat:SetDefaultDamage(TUNING.ROCKY_BOSS_DAMAGE)
	inst.components.combat:SetRetargetFunction(1, RetargetFn)
	--no KeepTargetFn, deaggro handled by ChaseAndAttack params

	inst:AddComponent("timer")
	inst.components.timer:StartTimer("dashcd", TUNING.ROCKY_BOSS_DASH_CD, true)
	if not POPULATING then
		inst.components.timer:StartTimer("bouldercd", 15 + math.random() * 15)
	end

	inst:AddComponent("health")

	inst:AddComponent("inspectable")

	inst:AddComponent("knownlocations")

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetSlowMultiplier(1)
	inst.components.locomotor:SetTriggersCreep(false)
	inst.components.locomotor.pathcaps = PATHCAPS
	inst.components.locomotor.walkspeed = TUNING.ROCKY_WALK_SPEED
	inst.components.locomotor.runspeed = TUNING.ROCKY_WALK_SPEED

	inst:AddComponent("lootdropper")

	inst:SetStateGraph("SGrocky")
	inst.sg.mem.nocorpse = true

	inst:SetBrain(brain)

	inst:ListenForEvent("attacked", OnAttacked)

	inst.StartMirage = StartMirage
	inst.GetDashRange = GetDashRange

	if master_postinit then
		master_postinit(inst)
	end

	return inst
end

--------------------------------------------------------------------------

local function normal_common_postinit(inst)
    inst:AddTag("nightmarecorruptable")
	inst.AnimState:SetSymbolBloom("fx_claw")

	inst.isboulder = net_bool(inst.GUID, "rocky_boss.isboulder", "isboulderdirty")

	inst.displaynamefn = DisplayNameFn

	inst:AddComponent("spawnfader")

	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("isboulderdirty", OnIsBoulderDirty)
	end
end

local function normal_master_postinit(inst)
	inst:AddComponent("acidinfusible")
	inst.components.acidinfusible:SetFXLevel(3)
	inst.components.acidinfusible:SetMultipliers(TUNING.ROCKY_BOSS_ACIDINFUSED_MULTS)

	inst:AddComponent("acidlevel")
	inst:ListenForEvent("acidleveldelta", OnAcidLevelDelta)
	inst.components.acidlevel:SetOnStopIsAcidRainingFn(OnStopIsAcidRaining)
	inst.components.acidlevel:SetOnStopIsRainingFn(OnStopIsAcidRaining)
	inst.components.acidlevel:SetOverrideAcidRainTickFn(OnOverrideAcidRainTick)
	inst:ListenForEvent("gainrainimmunity", OnStopIsAcidRaining)

	inst:AddComponent("eater")
	inst.components.eater:SetDiet(EATER_FOODTYPES, EATER_FOODTYPES)

	inst.components.health:SetMaxHealth(TUNING.ROCKY_BOSS_HEALTH)

	inst.components.inspectable.getstatus = GetStatus

	inst.components.lootdropper:SetLoot(LOOT)

	inst:AddComponent("sleeper")
	inst.components.sleeper:SetResistance(4)
	inst.components.sleeper:SetWakeTest(ShouldWake)
	inst.components.sleeper:SetSleepTest(ShouldSleep)
	inst.components.sleeper.diminishingreturns = true

	inst:AddComponent("herdmember")
	inst.components.herdmember.herdprefab = "rockyherd"

	inst.sg.mem.canstalkercorrupt = true

	MakeHauntable(inst)

	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)

	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake
	inst.SetBoulderState = SetBoulderState
end

local function normalfn() return commonfn("rocky_boss", normal_common_postinit, normal_master_postinit) end

--------------------------------------------------------------------------

local FADE_OUT_BEGIN = 10
local FADE_OUT_END = 18
local FADE_IN_BEGIN = 30
local FADE_IN_END = 42

local function OnUpdateFade(inst, dt)
	local fade = inst.fade:value()

	--fade out
	if fade >= FADE_OUT_BEGIN and fade <= FADE_OUT_END then
		if dt > 0 then
			fade = math.min(FADE_OUT_END, fade + 1)
			inst.fade:set_local(fade)
		end
		local a = (FADE_OUT_END - fade) / (FADE_OUT_END - FADE_OUT_BEGIN)
		inst.AnimState:OverrideMultColour(1, 1, 1, a)
		if inst.highlightchildren then
			for i, v in ipairs(inst.highlightchildren) do
				v.AnimState:OverrideMultColour(1, 1, 1, a)
			end
		end
		if fade == FADE_OUT_END then
			inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateFade)
			inst.updatingfade = false
		end
		return
	end

	--fade in
	if fade >= FADE_IN_BEGIN and fade < FADE_IN_END then
		if dt > 0 then
			fade = fade + 1
			if fade >= FADE_IN_END then
				fade = 0
			end
			inst.fade:set_local(fade)
		end
		if fade ~= 0 then
			local a = (fade - FADE_IN_BEGIN) / (FADE_IN_END - FADE_IN_BEGIN)
			inst.AnimState:OverrideMultColour(1, 1, 1, a)
			if inst.highlightchildren then
				for i, v in ipairs(inst.highlightchildren) do
					v.AnimState:OverrideMultColour(1, 1, 1, a)
				end
			end
			return
		end
	end
	--done (or invalid)
	inst.fade:set_local(0)
	inst.AnimState:OverrideMultColour(1, 1, 1, 1)
	if inst.highlightchildren then
		for i, v in ipairs(inst.highlightchildren) do
			v.AnimState:OverrideMultColour(1, 1, 1, 1)
			v.AnimState:UsePointFiltering(false)
		end
	end
	inst.AnimState:UsePointFiltering(false)
	inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateFade)
	inst.updatingfade = false
end

local function OnFadeDirty(inst)
	local fade = inst.fade:value()
	if fade ~= 0 then
		if not inst.updatingfade then
			inst.updatingfade = true
			inst.components.updatelooper:AddOnUpdateFn(OnUpdateFade)
			inst.AnimState:UsePointFiltering(true)
			if inst.highlightchildren then
				for i, v in ipairs(inst.highlightchildren) do
					v.AnimState:UsePointFiltering(true)
				end
			end
			OnUpdateFade(inst, 0)
		end
	elseif inst.updatingfade then
		OnUpdateFade(inst, 0)
	else
		inst.AnimState:OverrideMultColour(1, 1, 1, 1)
		inst.AnimState:UsePointFiltering(false)
		if inst.highlightchildren then
			for i, v in ipairs(inst.highlightchildren) do
				v.AnimState:OverrideMultColour(1, 1, 1, 1)
				v.AnimState:UsePointFiltering(false)
			end
		end
	end
end

local function StartFadeOut(inst)
	local fade = inst.fade:value()
	if fade >= FADE_OUT_BEGIN and fade <= FADE_OUT_END then
		--was already fading out; sync anyway
		inst.fade:set(fade)
	elseif fade >= FADE_IN_BEGIN and fade < FADE_IN_END then
		--was fading in; convert to fade out
		inst.fade:set((FADE_IN_END - fade) / (FADE_IN_END - FADE_IN_BEGIN) * (FADE_OUT_END - FADE_OUT_BEGIN) + FADE_OUT_BEGIN)
	else
		--start new fade out
		inst.fade:set(FADE_OUT_BEGIN)
	end
	OnFadeDirty(inst) --dedi server needs to update netvar too
end

local function StartFadeIn(inst)
	local fade = inst.fade:value()
	if fade >= FADE_IN_BEGIN and fade < FADE_IN_END then
		--was already fading in; sync anyway
		inst.fade:set(fade)
	elseif fade == FADE_OUT_BEGIN then
		--was just about to start fade out; cancel it
		inst.fade:set(0)
	elseif fade > FADE_OUT_BEGIN and fade <= FADE_OUT_END then
		--was fading out; convert to fade in
		inst.fade:set((FADE_OUT_END - fade) / (FADE_OUT_END - FADE_OUT_BEGIN) * (FADE_IN_END - FADE_IN_BEGIN) + FADE_IN_BEGIN)
	else
		--start new fade in
		inst.fade:set(FADE_IN_BEGIN)
	end
	OnFadeDirty(inst) --dedi server needs to update netvar too
end

local function ResetFade(inst)
	inst.fade:set(0)
	OnFadeDirty(inst) --dedi server needs to update netvar too
end

local function IsFading(inst)
	return inst.fade:value() ~= 0
end

local function shadow_OnHealthDelta(inst, data)
	if data.newpercent < 0.5 then
		inst:RemoveEventCallback("healthdelta", shadow_OnHealthDelta)
		inst.enraged = true
		inst:PushEvent("enraged")
	end
end

local function shadow_OnSave(inst, data)
	data.endenraged = inst.endenraged
end

local function shadow_OnLoad(inst, data)--, ents)
	if data and data.endenraged then
		inst:RemoveEventCallback("healthdelta", shadow_OnHealthDelta)
		inst.enraged = nil
		inst.endenraged = true
	elseif inst.components.health:GetPercent() < 0.5 then
		inst:RemoveEventCallback("healthdelta", shadow_OnHealthDelta)
		inst.enraged = true
	end
end

local function shadow_OnColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.highlightchildren) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function shadow_common_postinit(inst)
	inst:AddTag("shadowthrall")
	inst:AddTag("shadow_aligned")
	inst:AddTag("epic")

	inst.AnimState:SetSymbolLightOverride("fx_claw", 1)
	inst.AnimState:SetSymbolLightOverride("red", 1)

	inst.fade = net_smallbyte(inst.GUID, "rocky_boss_shadow.fade", "fadedirty")

	inst:AddComponent("updatelooper")
	inst:AddComponent("colouraddersync")

	if not TheNet:IsDedicated() then
		local flame = CreateFlameLoop()
		flame.entity:SetParent(inst.entity)
		flame.Follower:FollowSymbol(inst.GUID, "follow_shoulder_L", nil, nil, nil, true)
		local len = flame.AnimState:GetCurrentAnimationNumFrames()
		flame.AnimState:SetFrame(math.random(math.floor(len / 4)))

		inst.highlightchildren = { flame }

		flame = CreateFlameLoop()
		flame.entity:SetParent(inst.entity)
		flame.Follower:FollowSymbol(inst.GUID, "follow_shoulder_R", nil, nil, nil, true)
		len = flame.AnimState:GetCurrentAnimationNumFrames()
		flame.AnimState:SetFrame(math.floor(len / 2) + math.random(math.floor(len / 4)))

		inst.highlightchildren[2] = flame

		inst.components.colouraddersync:SetColourChangedFn(shadow_OnColourChanged)
	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("fadedirty", OnFadeDirty)
	end
end

local function shadow_master_postinit(inst)
	inst.scrapbook_anim = "scrapbook_shadow"
	--force default sound; otherwise it'll use stone_ coz of "rocky" tag
	inst.override_combat_impact_sound = "flesh_"

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.ROCKY_BOSS_SHADOW_PLANAR_DAMAGE)

	inst.components.health:SetMaxHealth(TUNING.ROCKY_BOSS_SHADOW_HEALTH)

	inst.components.lootdropper:SetChanceLootTable("rocky_boss_shadow")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE

	inst:ListenForEvent("newcombattarget", shadow_OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", shadow_OnDroppedTarget)
	inst:ListenForEvent("healthdelta", shadow_OnHealthDelta)

	inst.OnSave = shadow_OnSave
	inst.OnLoad = shadow_OnLoad
	inst.StartFadeIn = StartFadeIn
	inst.StartFadeOut = StartFadeOut
	inst.ResetFade = ResetFade
	inst.IsFading = IsFading
end

local function shadowfn() return commonfn("rocky_boss_shadow_build", shadow_common_postinit, shadow_master_postinit) end

--------------------------------------------------------------------------

local function CreateLineFx(build)
	local inst = CreateEntity()

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("rocky")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("snip_line_fx")
	if build == "rocky_boss_shadow_build" then
		inst.AnimState:SetLightOverride(1)
	else
		inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	end
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetSortOrder(1)
	local scale = 1 / TUNING.ROCKY_BOSS_SCALE --to counter the transform scaling parented bug
	inst.AnimState:SetScale(scale, scale)

	return inst
end

local function _LineIntersectsScreen(x1, y1, x2, y2)
	if math.min(x1, x2) >= 1 or math.max(x1, x2) <= 0 or
		math.min(y1, y2) >= 1 or math.max(y1, y2) <= 0
	then
		return false
	end

	if (x1 > 0 and x1 < 1 and x2 > 0 and x2 < 1) or
		(y1 > 0 and y1 < 1 and y2 > 0 and y2 < 1)
	then
		return true
	end

	return math2d.LineIntersectsLine(x1, y1, x2, y2, 0, 0, 0, 1)
		or math2d.LineIntersectsLine(x1, y1, x2, y2, 0, 1, 1, 1)
		or math2d.LineIntersectsLine(x1, y1, x2, y2, 1, 1, 1, 0)
		or math2d.LineIntersectsLine(x1, y1, x2, y2, 1, 0, 0, 0)
end

local function snip_OnRemoveEntity(inst)
	ClearLineDistortion(inst._fxguid)
end

local function snip_PostUpdate(inst)
	local t = inst.AnimState:GetCurrentAnimationTime()
	if inst._fx == nil then
		inst._fx = CreateLineFx(inst.AnimState:GetBuild())
		inst._fx.entity:SetParent(inst.entity)
		inst._fx.Follower:FollowSymbol(inst.GUID, "follow_height")
		inst._fx.AnimState:SetTime(t)
	end

	local duration = 0.5
	if t < duration then
		local w, h = TheSim:GetScreenSize()
		if w > 0 and h > 0 then
			local x, y, z = inst.Transform:GetWorldPosition()
			local theta = inst.Transform:GetRotation() * DEGREES
			local scale = TUNING.ROCKY_BOSS_SCALE
			local _, yh2 = TheSim:GetScreenPos(inst.AnimState:GetSymbolPosition("follow_height"))
			local _, yh1 = TheSim:GetScreenPos(x, y, z)
			local dyh = yh2 - yh1
			local halflen = 7 * scale --(see * in SGRocky::snip_attack)
			local dx = math.cos(theta) * halflen
			local dz = -math.sin(theta) * halflen
			local p1x, p1y = TheSim:GetScreenPos(x + dx, y, z + dz)
			local p2x, p2y = TheSim:GetScreenPos(x - dx, y, z - dz)
			p1x = p1x / w
			p1y = (p1y + dyh) / h
			p2x = p2x / w
			p2y = (p2y + dyh) / h

			if _LineIntersectsScreen(p1x, p1y, p2x, p2y) then
				local aspect_ratio = w / h
				local displacement = dyh / h 
				local width = displacement * 5.5
				local str = Remap(t, 0, duration, 1, 0)
				str = str * str
				if inst._fxguid == nil then
					inst._fxguid = GetNextVisualEffectGUID()
				end
				if PushLineDistortion(inst._fxguid, p1x, p1y, p2x, p2y, aspect_ratio, width * str, displacement * str) then
					inst.OnRemoveEntity = snip_OnRemoveEntity
					return
				end
			end
		end
	end

	if inst._fxguid then
		ClearLineDistortion(inst._fxguid)
	end
	inst.OnRemoveEntity = nil
	inst.components.updatelooper:RemovePostUpdateFn(snip_PostUpdate)
end

local function snipfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")

	inst.AnimState:SetBank("rocky")
	inst.AnimState:SetBuild("rocky_boss")
	inst.AnimState:PlayAnimation("fxheight")

	local scale = TUNING.ROCKY_BOSS_SCALE
	inst.Transform:SetScale(scale, scale, scale)

	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(snip_PostUpdate)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false
	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

--------------------------------------------------------------------------

local function CreateDashLine(build)
	local inst = CreateEntity()

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("rocky")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("fxheight")

	local scale = TUNING.ROCKY_BOSS_SCALE
	inst.Transform:SetScale(scale, scale, scale)

	inst.fx = CreateLineFx(build)
	inst.fx.AnimState:PlayAnimation("dash_line_fx")
	inst.fx.entity:SetParent(inst.entity)
	inst.fx.Follower:FollowSymbol(inst.GUID, "follow_height")

	return inst
end

local function dash_OnRemoveEntity(inst)
	if inst._fx then
		inst._fx:Remove()
		inst._fx = nil
	end
	if inst._fxguid then
		ClearLineDistortion(inst._fxguid)
		inst._fxguid = nil
	end
end

local function dash_PostUpdate(inst)
	local target = inst.target:value()
	local t = inst.AnimState:GetCurrentAnimationTime()
	local duration = 0.4
	if t < duration and target then
		local w, h = TheSim:GetScreenSize()
		if w > 0 and h > 0 then
			local x1, y1, z1 = target.Transform:GetWorldPosition()
			if inst._fx == nil then
				inst._fx = CreateDashLine(inst.AnimState:GetBuild())
				inst._fx.fx.AnimState:SetTime(t)
				inst._fx.Transform:SetRotation(inst.Transform:GetRotation())
				inst._fx.Transform:SetPosition(x1, y1, z1)
				inst.OnRemoveEntity = dash_OnRemoveEntity
			end

			local str = Remap(t, 0, duration, 1, 0)
			str = str * str
			inst._fx.fx.AnimState:SetMultColour(1, 1, 1, str * 0.25)

			local x, y, z = inst.Transform:GetWorldPosition()
			local _, yh2 = TheSim:GetScreenPos(inst.AnimState:GetSymbolPosition("follow_height"))
			local _, yh1 = TheSim:GetScreenPos(x, y, z)
			local dyh = yh2 - yh1

			local p1x, p1y = TheSim:GetScreenPos(x, y, z)
			local p2x, p2y = TheSim:GetScreenPos(x1, y1, z1)
			p1x = p1x / w
			p1y = (p1y + dyh) / h
			p2x = p2x / w
			p2y = (p2y + dyh) / h

			if _LineIntersectsScreen(p2x, p2y, p1x, p1y) then
				local aspect_ratio = w / h
				local displacement = dyh / h
				local width = displacement * 2.5
				displacement = displacement * 0.5
				if inst._fxguid == nil then
					inst._fxguid = GetNextVisualEffectGUID()
				end
				if PushLineDistortion(inst._fxguid, p1x, p1y, p2x, p2y, aspect_ratio, width * str, displacement * str) then
					inst.OnRemoveEntity = dash_OnRemoveEntity
					return
				end
			end
		end
	end

	if inst._fx then
		inst._fx:Remove()
		inst._fx = nil
	end
	if inst._fxguid then
		ClearLineDistortion(inst._fxguid)
		inst._fxguid = nil
	end
	inst.OnRemoveEntity = nil
	inst.components.updatelooper:RemovePostUpdateFn(dash_PostUpdate)
end

local function dashfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")

	inst.AnimState:SetBank("rocky")
	inst.AnimState:SetBuild("rocky_boss")
	inst.AnimState:PlayAnimation("fxheight")

	local scale = TUNING.ROCKY_BOSS_SCALE
	inst.Transform:SetScale(scale, scale, scale)

	inst.target = net_entity(inst.GUID, "rocky_dash_fx.target")

	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(dash_PostUpdate)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("rocky_boss", normalfn, assets, prefabs),
	Prefab("rocky_snip_fx", snipfn, assets_fx),
	Prefab("rocky_dash_fx", dashfn, assets_fx),
	Prefab("rocky_boss_shadow", shadowfn, assets_shadow, prefabs_shadow)
