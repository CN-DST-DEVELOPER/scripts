require("stategraphs/commonstates")

local function IsAlly_Crafted(v, inst)
	if not inst.components.combat:IsAlly(v) then
		return false
	end

	--check if i'm fighting my allies
	local target = inst.components.combat.target
	if target and inst.components.combat:CanBeAlly(target) then
		return false
	end

	--check if they're fighting my allies
	target = v.components.combat and v.components.combat.target
	if target and inst.components.combat:CanBeAlly(target) then
		return false
	end

	return true
end

local SPIN_BLOCKER_TAGS = { "vault_pillar_guard" }
local function IsSpinBlocker_Trial(v, inst) return v.trial ~= nil end --faster than checking "vault_key_trial_guardian" tag

local function ChooseAttack(inst, target)
	if target and target:IsValid() then
		if inst.canspin and not inst.components.timer:TimerExists("spin_cd") and
			FindEntity(inst, 7, inst.trial and IsSpinBlocker_Trial or IsAlly_Crafted, SPIN_BLOCKER_TAGS) == nil
		then
			inst.sg:GoToState("spin_pre")
			return true
		end
		if inst.canquickjump and not inst.components.timer:TimerExists("quickjump_cd") then
			inst.sg:GoToState("attack3", target)
			return true
		end
		inst.sg:GoToState("attack1", target)
		return true
	end
	return false
end

local events =
{
	CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnSink(),
	CommonHandlers.OnFallInVoid(),
	--CommonHandlers.OnFreezeEx(),
	EventHandler("death", function(inst, data)
		if not inst.sg:HasAnyStateTag("dead", "nointerrupt") then
			inst.sg:GoToState("death", data)
		end
	end),
	EventHandler("doattack", function(inst, data)
		if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
			ChooseAttack(inst, data and data.target)
		end
	end),
	EventHandler("ms_pillarguard_quickjump", function(inst, data)
		if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) and
			data and data.target and data.target:IsValid()
		then
			inst.sg:GoToState("attack3", data.target)
		end
	end),
	EventHandler("attacked", function (inst, data)
		if not inst.components.health:IsDead() then
			if not inst.sg:HasAnyStateTag("stunned", "nointerrupt") then
				if inst.components.timer:TimerExists("stunned") then
					inst.sg:GoToState("stun_pre")
					return
				elseif data and data.attacker and data.attacker.sg and data.attacker.sg:HasStateTag("vault_crawler_dropping") then
					inst.components.timer:StartTimer("stunned", TUNING.VAULT_PILLAR_GUARD_MAX_STAGGER_TIME)
					inst.sg:GoToState("stun_pre")
					return
				end
			end
			if not inst.sg:HasStateTag("busy") or inst.sg:HasAnyStateTag("caninterrupt", "frozen") then
				if inst.sg:HasStateTag("stunned") then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_hit")
				elseif not CommonHandlers.HitRecoveryDelay(inst, TUNING.VAULT_PILLAR_GUARD_HIT_RECOVERY) then
					inst.sg:GoToState("hit")
				end
			end
		end
	end),
}

--------------------------------------------------------------------------

local function Shake_Heavy(inst)		ShakeAllCameras(CAMERASHAKE.FULL, 0.8, 0.03, 0.35, inst, 40)	end
local function Shake_Med(inst)			ShakeAllCameras(CAMERASHAKE.FULL, 0.8, 0.028, 0.3, inst, 40)	end
local function Shake_Light(inst)		ShakeAllCameras(CAMERASHAKE.FULL, 0.6, 0.025, 0.25, inst, 30)	end
local function Shake_Lift(inst)			ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.035, 0.15, inst, 30)	end
local function Shake_Activate(inst)		ShakeAllCameras(CAMERASHAKE.FULL, 0.6, 0.025, 0.15, inst, 30)	end
local function Shake_Footstep(inst)		ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.028, 0.3, inst, 40)	end
local function Shake_Smallstep(inst)	ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.025, 0.22, inst, 40)	end
local function Shake_Pound(inst)		ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.8, 0.03, 0.6, inst, 40)	end

local function _PlayFootstep(inst, volume)
	inst.SoundEmitter:PlaySound("rifts7/pillar_guard/footstep", nil, volume)
end

local function DoFootstep(inst)
	_PlayFootstep(inst)
	Shake_Footstep(inst)
end

local function DoSmallstep(inst)
	_PlayFootstep(inst)
	Shake_Smallstep(inst)
end

local function SwitchToNoFaced(inst)
	if not inst.sg.mem.nofaced then
		inst.sg.mem.nofaced = true
		inst.Transform:SetNoFaced()
	end
end

local function SwitchToFourFaced(inst)
	if inst.sg.mem.nofaced then
		inst.sg.mem.nofaced = nil
		inst.Transform:SetFourFaced()
	end
end

local function SetShadowScale(inst, scale)
	inst.DynamicShadow:SetSize(6 * scale, 3.5 * math.min(1, scale))
end

local function TriggerDebris(inst)
	inst:TriggerDebris(true)
end

local function CancelDebris(inst)
	inst:TriggerDebris(false)
end

local function ShouldCombo(inst, target)
	if not (target and target:IsValid()) then
		return false
	elseif target.components.health and target.components.health:IsDead() then
		return false
	end
	local rotation = inst.Transform:GetRotation()
	local angle = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
	return DiffAngle(rotation, angle) < 75
end

--------------------------------------------------------------------------

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }
local AOE_TRIAL_CANT_TAGS = ConcatArrays({ "vault_key_trial_guardian" }, AOE_TARGET_CANT_TAGS)

local function _AOEAttack(inst, dig, dist, radius, arc, heavymult, mult, forcelanded, targets, repeatdelay)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			--min-x for testing points converted to local space
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	local t = repeatdelay and GetTime()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, inst.trial and AOE_TRIAL_CANT_TAGS or AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not (	targets and
					targets[v] and
					not (repeatdelay and type(targets[v]) == "number" and targets[v] < t)
				) and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead()) and
			(	inst.trial or --trial doesn't need ally check; excludes by tag "vault_key_trial_guardian"
				not IsAlly_Crafted(v, inst)
			)
		then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < range * range and
				--convert to local space x, and test against arcx
				(arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
				inst.components.combat:CanTarget(v)
			then
				if dig and v.components.locomotor == nil then
					v.components.health:Kill()
				else
					inst.components.combat:DoAttack(v)
					if mult then
						local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
						v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = strengthmult, forcelanded = forcelanded })
					end
				end
				if targets then
					targets[v] = repeatdelay == nil or t + repeatdelay
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

local WORK_RADIUS_PADDING = 0.5
local COLLAPSIBLE_WORK_ACTIONS =
{
	CHOP = true,
	HAMMER = true,
	MINE = true,
}
local COLLAPSIBLE_TAGS = { "NPC_workable" }
for k, v in pairs(COLLAPSIBLE_WORK_ACTIONS) do
	table.insert(COLLAPSIBLE_TAGS, k.."_workable")
end

local COLLAPSIBLE_WORK_AND_DIG_ACTIONS = shallowcopy(COLLAPSIBLE_WORK_ACTIONS)
local COLLAPSIBLE_DIG_TAGS = shallowcopy(COLLAPSIBLE_TAGS)
COLLAPSIBLE_WORK_AND_DIG_ACTIONS["DIG"] = true
table.insert(COLLAPSIBLE_DIG_TAGS, "pickable")
table.insert(COLLAPSIBLE_DIG_TAGS, "DIG_workable")

local NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" }

local function _AOEWork(inst, dig, dist, radius, arc, targets)
	local actions = dig and COLLAPSIBLE_WORK_AND_DIG_ACTIONS or COLLAPSIBLE_WORK_ACTIONS
	local x, y, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			--min-x for testing points converted to local space
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + WORK_RADIUS_PADDING, nil, NON_COLLAPSIBLE_TAGS, dig and COLLAPSIBLE_DIG_TAGS or COLLAPSIBLE_TAGS)) do
		if not (targets and targets[v]) and v:IsValid() and not v:IsInLimbo() then
			local inrange = true
			if arcx then
				--convert to local space x, and test against arcx
				local x1, y1, z1 = v.Transform:GetWorldPosition()
				inrange = x + cos_theta * (x1 - x) - sin_theta * (z1 - z) > arcx
			end
			if inrange then
				local isworkable = false
				if v.components.workable then
					local work_action = v.components.workable:GetWorkAction()
					--V2C: nil action for NPC_workable (e.g. campfires)
					isworkable =
						(	work_action == nil and v:HasTag("NPC_workable")	) or
						(	v.components.workable:CanBeWorked() and
							work_action and
							actions[work_action.id] and
							not (dig and (v.components.spawner or v.components.childspawner))
						)
				end
				if isworkable then
					v.components.workable:Destroy(inst)
					if dig and v:IsValid() and v:HasTag("stump") then
						v:Remove()
					end
					if targets then
						targets[v] = true
					end
				elseif dig and
					v.components.pickable and
					v.components.pickable:CanBePicked() and
					not v:HasTag("intense") and
					v.prefab ~= "vault_key_pedestal"
				then
					v.components.pickable:Pick(inst)
					if targets then
						targets[v] = true
					end
				end
			end
		end
	end
end

local TOSSITEM_MUST_TAGS = { "_inventoryitem" }
local TOSSITEM_CANT_TAGS = { "locomotor", "INLIMBO" }

local function TossLaunch(inst, launcher, basespeed, startheight, startradius)
	local x0, y0, z0 = launcher.Transform:GetWorldPosition()
	local x1, y1, z1 = inst.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local dsq = dx * dx + dz * dz
	local angle
	if dsq > 0 then
		local dist = math.sqrt(dsq)
		angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
		startradius = math.max(dist, startradius)
	else
		angle = TWOPI * math.random()
	end
	local sina, cosa = math.sin(angle), math.cos(angle)
	local speed = basespeed + math.random()
	inst.Physics:Teleport(x0 + startradius * cosa, startheight, z0 + startradius * sina)
	inst.Physics:SetVel(cosa * speed, speed * 2.5 + math.random(), sina * speed)
end

local function TossItems(inst, dist, radius, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	if dist ~= 0 then
		local theta = inst.Transform:GetRotation() * DEGREES
		x = x + dist * math.cos(theta)
		z = z - dist * math.sin(theta)
	end
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + WORK_RADIUS_PADDING, TOSSITEM_MUST_TAGS, TOSSITEM_CANT_TAGS)) do
		if not (targets and targets[v]) then
			DeactivateInventoryItemBeforeLaunch(v)
			if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
				TossLaunch(v, inst, radius * 0.4, 0.5, radius)
			end
			if targets then
				targets[v] = true
			end
		end
	end
end

local function DoWalkCollide(inst)
	_AOEWork(inst, false, 0, 2.5)
end

local function DoWalkStomp(inst)
	_AOEWork(inst, false, 0, 2.5)
	TossItems(inst, 0, 2.5)
end

local function DoActivateStomp(inst, r)
	_AOEWork(inst, false, 0, r)
	TossItems(inst, 0, r)
end

local function DoPunchAOE(inst)
	_AOEWork(inst, false, 1, 4, 180, inst.sg.statemem.targets)
	_AOEAttack(inst, false, 1, 4, 180, 1, 1.25, true, inst.sg.statemem.targets)
end

local function DoSmashAOE(inst)
	_AOEWork(inst, true, 0, 4, nil, inst.sg.statemem.targets)
	_AOEAttack(inst, true, 0, 4, nil, nil, 1, nil, inst.sg.statemem.targets)
	TossItems(inst, 0, 4, inst.sg.statemem.tosstargets)
end

local function DoSpinAOE(inst)
	_AOEWork(inst, false, 0, 5.6, nil, inst.sg.statemem.targets)
	_AOEAttack(inst, false, 0, 5.6, nil, 0.8, 1, true, inst.sg.statemem.targets, 0.5)
end

--------------------------------------------------------------------------

local function SpawnSwipeFX(inst, reverse)
	--spawn 3 frames early (with 3 leading blank frames) since anim is super short, and tends to get lost with network timing
	inst.sg.statemem.fx = SpawnPrefab("vault_pillar_guard_swipe_fx")
	inst.sg.statemem.fx.entity:SetParent(inst.entity)
	inst.sg.statemem.fx.Transform:SetPosition(1, 0, 0)
	if reverse then
		inst.sg.statemem.fx:Reverse()
	end
end

local function SpawnSmashFx(inst)
	--spawn 3 frames early (with 3 leading blank frames) since anim is super short, and tends to get lost with network timing
	inst.sg.statemem.fx = SpawnPrefab("vault_pillar_guard_smash_fx")
	inst.sg.statemem.fx.entity:SetParent(inst.entity)
end

local function KillSwipeOrSmashFx(inst)
	if inst.sg.statemem.fx then
		if inst.sg.statemem.fx:IsValid() then
			inst.sg.statemem.fx:Remove()
		end
		inst.sg.statemem.fx = nil
	end
end

--------------------------------------------------------------------------

local function SetStunnedDamageMult(inst, stunned)
	if stunned then
		inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.VAULT_PILLAR_GUARD_STAGGER_DAMAGE_MULT, "stunned")
	else
		inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "stunned")
	end
end

local SOCKET_TAGS

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			inst.components.locomotor:Stop()
			local anim = inst.sg.mem.nofaced and "idle_nofaced" or "idle"
			if pushanim then
				inst.AnimState:PushAnimation(anim)
			else
				inst.AnimState:PlayAnimation(anim, true)
			end
			if inst.sg.mem.nofaced then
				inst.sg:SetTimeout(1)
			end
		end,

		ontimeout = SwitchToFourFaced,
		onexit = SwitchToFourFaced,
	},

	State{
		name = "alert",
		tags = { "alert", "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			local anim = "idle"..tostring(math.random(2, 3))
			inst.AnimState:PlayAnimation(anim.."_pre")
			inst.AnimState:PushAnimation(anim.."_loop")
		end,

		events =
		{
			EventHandler("locomote", function(inst)
				if inst.components.locomotor:WantsToMoveForward() then
					inst.sg:GoToState("alert_pst")
				end
				return true
			end),
		},
	},

	State{
		name = "alert_pst",
		tags = { "alert", "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle2_pst")
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.sg.statemem.canlocomote = true
			end),
		},

		events =
		{
			EventHandler("locomote", function(inst)
				return not inst.sg.statemem.canlocomote
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "activate",
		tags = { "busy", "noattack", "temp_invincible", "nofreeze" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("activate")
			inst.DynamicShadow:Enable(false)

			--NOTE: should only be used on spawn, so don't need to account for character passthrough
			inst.Physics:SetMass(0)
			inst.Physics:SetCapsule(1.3, 2)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.8) end),
			FrameEvent(28, function(inst) inst.SoundEmitter:PlaySound("rifts4/worm_boss/rumble") end),
			FrameEvent(50, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract") end),
			FrameEvent(52, function(inst) inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_emerge") end),
			FrameEvent(78, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/hit") end),
			FrameEvent(92, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.6) end),
			FrameEvent(101, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.6) end),
			FrameEvent(137, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.8) end),
			FrameEvent(139, function(inst) inst.SoundEmitter:PlaySound("rifts6/rock_pillar/fall") end),
			FrameEvent(147, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_activate") end),


			FrameEvent(0, TriggerDebris),
			FrameEvent(7, Shake_Activate),
			FrameEvent(28, Shake_Activate),
			FrameEvent(51, Shake_Lift),
			FrameEvent(52, function(inst)
				SetShadowScale(inst, 0.1)
				inst.DynamicShadow:Enable(true)
			end),
			FrameEvent(54, function(inst) SetShadowScale(inst, 0.2) end),
			FrameEvent(56, function(inst) SetShadowScale(inst, 0.3) end),
			FrameEvent(58, function(inst) SetShadowScale(inst, 0.4) end),
			FrameEvent(77, function(inst) SetShadowScale(inst, 0.5) end),
			FrameEvent(78, function(inst) SetShadowScale(inst, 0.8) end),
			FrameEvent(82, function(inst)
				DoActivateStomp(inst, 2)
				inst.Physics:SetCapsule(inst.physicsradiusoverride, 1)
			end),
			FrameEvent(83, Shake_Smallstep),
			FrameEvent(93, Shake_Light),
			FrameEvent(94, function(inst) SetShadowScale(inst, 0.87) end),
			FrameEvent(95, function(inst)
				DoActivateStomp(inst, 3.5)
			end),
			FrameEvent(102, Shake_Light),
			FrameEvent(103, function(inst) SetShadowScale(inst, 1) end),
			FrameEvent(118, Shake_Activate),
			FrameEvent(141, Shake_Activate),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.not_interrupted = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.not_interrupted then
				SwitchToFourFaced(inst)
			end
			CancelDebris(inst)
			SetShadowScale(inst, 1)
			inst.DynamicShadow:Enable(true)
			inst.Physics:SetMass(1000)
			inst.Physics:SetCapsule(inst.physicsradiusoverride, 1)
		end,
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_hit", nil, 0.6) end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/hit", nil, 0.5) end),

			FrameEvent(0, TriggerDebris),
			FrameEvent(12, function(inst)
				if not (inst.sg.statemem.doattack or inst.sg.statemem.quickjump) then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(20, function(inst)
				if inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				elseif inst.sg.statemem.quickjump and inst.sg.statemem.quickjump:IsValid() then
					inst.sg:GoToState("attack3", inst.sg.statemem.quickjump)
					return
				end
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				if inst.sg:HasStateTag("busy") then
					inst.sg.statemem.quickjump = nil
					inst.sg.statemem.doattack = data and data.target
					inst.sg:RemoveStateTag("caninterrupt")
					return true
				end
			end),
			EventHandler("ms_pillarguard_quickjump", function(inst, data)
				if inst.sg:HasStateTag("busy") then
					inst.sg.statemem.doattack = nil
					inst.sg.statemem.quickjump = data and data.target
					inst.sg:RemoveStateTag("caninterrupt")
					return true
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = CancelDebris,
	},

	State{
		name = "death",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_death") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.5) end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_hit", nil, 0.6) end),
			FrameEvent(28, function(inst) inst.SoundEmitter:PlaySound("rifts4/worm_boss/rumble") end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/destroy", nil, 0.8) end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_emerge") end),
			FrameEvent(45, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/hit", nil, 0.8) end),

			FrameEvent(0, TriggerDebris),
			FrameEvent(32, Shake_Heavy),
			FrameEvent(32, function(inst) SetShadowScale(inst, 0.8) end),
			FrameEvent(33, function(inst)
				inst:AddTag("NOCLICK")
				inst.Physics:SetMass(0)
				inst.Physics:SetCapsule(1.25, 1)
				if inst.sg.mem.physicstask then
					inst.sg.mem.physicstask:Cancel()
					inst.sg.mem.physicstask = nil
				end
				inst.sg.mem.ischaracterpassthrough = nil
			end),
			FrameEvent(34, function(inst)
				inst:DropDeathLoot()
				inst.persists = false
			end),
			FrameEvent(49, Shake_Med),
			FrameEvent(49, RemovePhysicsColliders),
			FrameEvent(51, function(inst) SetShadowScale(inst, 0.6) end),
			FrameEvent(64, Shake_Light),
			FrameEvent(64, function(inst) SetShadowScale(inst, 0.4) end),
			FrameEvent(65, function(inst) SetShadowScale(inst, 0.2) end),
			FrameEvent(66, function(inst)
				inst.DynamicShadow:Enable(false)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:Remove()
				end
			end),
		},

		onexit = function(inst)
			--should not reach here
			SwitchToFourFaced(inst)
			CancelDebris(inst)
			SetShadowScale(inst, 1)
			inst.DynamicShadow:Enable(true)
			inst:RemoveTag("NOCLICK")
			inst.Physics:SetMass(1000)
			inst.Physics:SetCapsule(inst.physicsradiusoverride, 1)
			inst.Physics:SetCollisionMask(
				COLLISION.WORLD,
				COLLISION.OBSTACLES,
				COLLISION.CHARACTERS,
				COLLISION.GIANTS
			)
		end,
	},

	--------------------------------------------------------------------------

	State{
		name = "attack1",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_1")
			inst.Physics:SetMotorVelOverride(3.2, 0, 0)
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.5) end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/whoosh") end),

			FrameEvent(1, DoWalkCollide),
			FrameEvent(5, function(inst)
				DoSmallstep(inst)
				DoWalkCollide(inst)
			end),
			FrameEvent(6, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(26, function(inst)
				inst.components.combat:StartAttack()
				SpawnSwipeFX(inst)
			end),
			FrameEvent(29, DoPunchAOE),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					local target = inst.sg.statemem.target
					if ShouldCombo(inst, target) then
						inst.sg:GoToState("attack2", target)
					else
						inst.sg:GoToState("attack1_pst")
					end
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			KillSwipeOrSmashFx(inst)
		end,
	},

	State{
		name = "attack1_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_1_pst")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.6) end),

			FrameEvent(8, DoSmallstep),
			FrameEvent(12, DoSmallstep),
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "attack2",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_2")
			inst.Physics:SetMotorVelOverride(4.3, 0, 0)
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.5) end),
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.4) end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/whoosh") end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.5) end),

			FrameEvent(1, DoWalkCollide),
			FrameEvent(5, DoWalkCollide),
			FrameEvent(9, DoWalkCollide),
			FrameEvent(13, function(inst)
				DoSmallstep(inst)
				DoWalkCollide(inst)
			end),
			FrameEvent(14, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(23, function(inst)
				inst.components.combat:StartAttack()
				SpawnSwipeFX(inst, true)
			end),
			FrameEvent(26, DoPunchAOE),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					local target = inst.sg.statemem.target
					if ShouldCombo(inst, target) then
						inst.sg:GoToState("attack3", target)
					else
						inst.sg:GoToState("attack2_pst")
					end
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			KillSwipeOrSmashFx(inst)
		end,
	},

	State{
		name = "attack2_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_2_pst")
		end,

		timeline =
		{
			FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.3) end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/hit", nil, 0.5) end),

			FrameEvent(8, DoSmallstep),
			FrameEvent(12, DoSmallstep),
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "attack3",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			if inst.AnimState:IsCurrentAnimation("atk_2") then
				inst.AnimState:PlayAnimation("atk_3_pre_a")
			else
				inst.sg:AddStateTag("jumping")
				inst.AnimState:PlayAnimation("atk_3_pre_b")
				inst.Physics:SetMotorVelOverride(2.3, 0, 0)
				inst.sg.statemem.quickjump = true
			end
			inst.AnimState:PushAnimation("atk_3", false)
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.6) end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.4) end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.5) end),
			FrameEvent(26, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/whoosh") end),
			FrameEvent(29, function(inst) inst.SoundEmitter:PlaySound("daywalker/action/attack_slam_whoosh") end), 
			FrameEvent(45, function(inst) inst.SoundEmitter:PlaySound("daywalker/action/attack_slam_down") end),
			FrameEvent(45, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack") end),
			--FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/footstep") end),

			FrameEvent(8, function(inst)
				if not inst.sg:HasStateTag("jumping") then
					Shake_Lift(inst)
				end
			end),
			FrameEvent(13, function(inst)
				if inst.sg:HasStateTag("jumping") then
					Shake_Lift(inst)
				end
			end),
			FrameEvent(17, function(inst)
				if inst.sg:HasStateTag("jumping") then
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
					inst.sg:RemoveStateTag("jumping")
				end
				TriggerDebris(inst)
			end),
			FrameEvent(30, Shake_Lift),
			FrameEvent(30, function(inst)
				local dist = 4
				local x, _, z = inst.Transform:GetWorldPosition()
				local target = inst.sg.statemem.target
				if target and target:IsValid() then
					local x1, _, z1 = target.Transform:GetWorldPosition()
					local dx = x1 - x
					local dz = z1 - z
					if dx ~= 0 or dz ~= 0 then
						local dir = math.atan2(-dz, dx) * RADIANS
						if DiffAngle(dir, inst.Transform:GetRotation()) < 45 then
							inst.Transform:SetRotation(dir)
							dist = math.sqrt(dx * dx + dz * dz)
							dist = math.clamp(dist - 1, 0, 10)
						end
					else
						dist = 0
					end
				end
				if dist ~= 0 then
					if SOCKET_TAGS == nil then
						SOCKET_TAGS = { "vault_crawler_socket" }
					end
					local theta = inst.Transform:GetRotation() * DEGREES
					local cos_theta = math.cos(theta)
					local sin_theta = math.sin(theta)
					local x1 = x + dist * cos_theta
					local z1 = z - dist * sin_theta
					local maxr = 2.6 --my radius 1.6 + socket radius 1
					local seg = maxr / 8
					for delta = 0, maxr, seg do
						local dx2 = delta * cos_theta
						local dz2 = -delta * sin_theta
						local x2 = x1 + dx2
						local z2 = z1 + dz2
						if #TheSim:FindEntities(x1 + dx2, 0, z1 + dz2, maxr, SOCKET_TAGS) == 0 then
							dist = dist + delta
							break
						elseif delta > 0 and delta <= dist and #TheSim:FindEntities(x1 - dx2, 0, z1 - dz2, maxr, SOCKET_TAGS) == 0 then
							dist = dist - delta
							break
						end
					end
				end
				inst.sg:AddStateTag("jumping")
				inst.sg:AddStateTag("nofreeze")
				inst.sg:AddStateTag("nointerrupt")
				ToggleOffAllObjectCollisions(inst)
				inst.Physics:ClearCollidesWith(COLLISION.BOAT_LIMITS) --to get thru vault_crawler_sockets
				inst.components.combat:StartAttack()
				if inst.sg.statemem.quickjump then
					inst.components.timer:StopTimer("quickjump_cd")
					inst.components.timer:StartTimer("quickjump_cd", TUNING.VAULT_PILLAR_GUARD_QUICKJUMP_CD)
				else
					local cd = inst.components.timer:GetTimeLeft("quickjump_cd") or 0
					if cd < TUNING.VAULT_PILLAR_GUARD_ATTACK_PERIOD then
						inst.components.timer:StopTimer("quickjump_cd")
						inst.components.timer:StartTimer("quickjump_cd", TUNING.VAULT_PILLAR_GUARD_ATTACK_PERIOD)
					end
				end
				inst.components.locomotor:Stop()
				inst.Physics:SetMotorVelOverride(dist / ((44 - 30) * FRAMES), 0, 0)
			end),
			FrameEvent(43, SpawnSmashFx), --one frame later on purpose
			FrameEvent(43, DoFootstep),
			FrameEvent(44, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
				inst.sg:RemoveStateTag("nofreeze")
				inst.sg:RemoveStateTag("nointerrupt")
				if inst.components.health:IsDead() then
					Shake_Heavy(inst)
					inst.sg:GoToState("death")
				elseif inst.components.timer:TimerExists("stunned") then
					Shake_Heavy(inst)
					inst.sg:GoToState("stun_pre")
				end
			end),
			FrameEvent(45, function(inst)
				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
				inst.Physics:CollidesWith(COLLISION.BOAT_LIMITS) --see vault_crawler_socket
				_PlayFootstep(inst)
				Shake_Pound(inst)
				inst.sg.statemem.targets = {}
				inst.sg.statemem.tosstargets = {}
				DoSmashAOE(inst)
			end),
			FrameEvent(46, DoSmashAOE),
			FrameEvent(47, DoSmashAOE),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("attack3_pst")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			if inst.sg.mem.isobstaclepassthrough then
				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
				inst.Physics:CollidesWith(COLLISION.BOAT_LIMITS) --see vault_crawler_socket
			end
			CancelDebris(inst)
			KillSwipeOrSmashFx(inst)
		end,
	},

	State{
		name = "attack3_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_3_pst")
		end,

		timeline =
		{
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.6) end),
			--FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),

			FrameEvent(12, DoSmallstep),
			FrameEvent(19, DoSmallstep),
			FrameEvent(20, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "spin_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("spin_pre")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_lariat_pre") end),
			FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/hit", nil, 0.3) end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/hit", nil, 0.6) end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.3) end),
			FrameEvent(11, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.4) end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/hit", nil, 0.5) end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_lariat_spin") end),

			FrameEvent(5, Shake_Med),
			FrameEvent(18, function(inst)
				inst.components.combat:StartAttack()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.spinning = true
					inst.sg:GoToState("spin_loop", { loops = 2 })
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.spinning then
				SwitchToFourFaced(inst)
			end
		end,
	},

	State{
		name = "spin_loop",
		tags = { "attack", "busy" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			if not inst.AnimState:IsCurrentAnimation("spin_loop") then
				inst.AnimState:PlayAnimation("spin_loop", true)
			end
			inst.components.combat:StartAttack()
			inst.components.timer:StopTimer("spin_cd")
			inst.components.timer:StartTimer("spin_cd", TUNING.VAULT_PILLAR_GUARD_SPIN_CD)
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			inst.sg.statemem.targets = data and data.targets or {}
			inst.sg.statemem.loops = data and data.loops or 0
		end,

		onupdate = DoSpinAOE,

		ontimeout = function(inst)
			inst.sg.statemem.spinning = true
			if inst.sg.statemem.loops > 1 then
				inst.sg:GoToState("spin_loop", {
					targets = inst.sg.statemem.targets,
					loops = inst.sg.statemem.loops - 1,
				})
			else
				inst.sg:GoToState("spin_pst")
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.spinning then
				SwitchToFourFaced(inst)
			end
		end,
	},

	State{
		name = "spin_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("spin_pst")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.3) end),
			FrameEvent(20, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),
			FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/hit", nil,0.8) end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/hit", nil, 0.6) end),

			FrameEvent(11, Shake_Lift),
			FrameEvent(19, DoSmallstep),
			FrameEvent(20, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.not_interrupted = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.not_interrupted then
				SwitchToFourFaced(inst)
			end
		end,
	},

	--------------------------------------------------------------------------
	--stun states

	State{
		name = "stun_pre",
		tags = { "stunned", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("stunned_pre")
			inst.components.timer:ResumeTimer("stunned")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.6) end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_stunned") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.5) end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("daywalker/pillar/hit", nil, 0.6) end),
			FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("rifts7/pillar_guard/voice_stunned") end),

			FrameEvent(0, TriggerDebris),
			FrameEvent(21, Shake_Heavy),
			FrameEvent(21, function(inst) SetShadowScale(inst, 1.1) end),
			FrameEvent(22, function(inst) SetShadowScale(inst, 1.2) end),
			FrameEvent(23, function(inst) SetShadowScale(inst, 1.3) end),
			FrameEvent(24, function(inst) SetShadowScale(inst, 1.4) end),
			FrameEvent(25, function(inst) SetShadowScale(inst, 1.5) end),
			FrameEvent(35, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				SetStunnedDamageMult(inst, true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.stunned then
				SwitchToFourFaced(inst)
				SetShadowScale(inst, 1)
				SetStunnedDamageMult(inst, false)
			end
			CancelDebris(inst)
		end,
	},

	State{
		name = "stun_idle",
		tags = { "stunned", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			SetShadowScale(inst, 1.5)
			SetStunnedDamageMult(inst, true)
			inst.AnimState:PlayAnimation("stunned_loop", true)

			if inst.components.timer:TimerExists("stunned") then
				inst.components.timer:ResumeTimer("stunned")
			else
				inst.sg.statemem.stunned = true
				inst.sg:GoToState("stun_pst")
			end

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			--#SFX
			FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.stunned = true
			inst.sg:GoToState("stun_idle")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.stunned then
				SwitchToFourFaced(inst)
				SetShadowScale(inst, 1)
				SetStunnedDamageMult(inst, false)
				inst.components.timer:StopTimer("stunned")
			end
		end,
	},

	State{
		name = "stun_hit",
		tags = { "stunned", "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			SetShadowScale(inst, 1.5)
			SetStunnedDamageMult(inst, true)
			inst.AnimState:PlayAnimation("stunned_hit")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack", nil, 0.4) end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/hit", nil, 0.5) end),

			FrameEvent(0, TriggerDebris),
			FrameEvent(7, function(inst)
				if not inst.components.timer:TimerExists("stunned") then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_pst")
				end
			end),
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.stunned then
				SwitchToFourFaced(inst)
				SetShadowScale(inst, 1)
				SetStunnedDamageMult(inst, false)
				inst.components.timer:StopTimer("stunned")
			end
			CancelDebris(inst)
		end,
	},

	State{
		name = "stun_pst",
		tags = { "stunned", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			SetShadowScale(inst, 1.5)
			SetStunnedDamageMult(inst, true)
			inst.AnimState:PlayAnimation("stunned_pst")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts4/worm_boss/rumble") end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.5) end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.5) end),

			FrameEvent(0, TriggerDebris),
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("stunned")
				SetStunnedDamageMult(inst, false)
				inst.components.timer:StopTimer("stunned")
			end),
			FrameEvent(9, function(inst) SetShadowScale(inst, 1.45) end),
			FrameEvent(10, Shake_Lift),
			FrameEvent(10, function(inst) SetShadowScale(inst, 1.4) end),
			FrameEvent(11, function(inst) SetShadowScale(inst, 1.35) end),
			FrameEvent(12, function(inst) SetShadowScale(inst, 1.3) end),
			FrameEvent(13, function(inst) SetShadowScale(inst, 1.25) end),
			FrameEvent(14, function(inst) SetShadowScale(inst, 1.15) end),
			FrameEvent(15, function(inst) SetShadowScale(inst, 1.05) end),
			FrameEvent(16, function(inst) SetShadowScale(inst, 1) end),
			FrameEvent(30, DoFootstep),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(38, function(inst)
				inst.sg.statemem.not_interrupted = true
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			if not (inst.sg.statemem.stunned or inst.sg.statemem.not_interrupted) then
				SwitchToFourFaced(inst)
			end
			if not inst.sg.statemem.stunned then
				SetShadowScale(inst, 1)
				SetStunnedDamageMult(inst, false)
				inst.components.timer:StopTimer("stunned")
			end
			CancelDebris(inst)
		end,
	},

	--------------------------------------------------------------------------
}

CommonStates.AddWalkStates(states,
{
	walktimeline =
	{
		FrameEvent(2, function(inst)
			DoFootstep(inst)
			DoWalkStomp(inst)
			inst.sg:AddStateTag("footstepped")
		end),
		FrameEvent(6, DoWalkCollide),
		FrameEvent(8, function(inst)
			inst.sg:RemoveStateTag("footstepped")
		end),
		FrameEvent(10, DoWalkCollide),
		FrameEvent(14, DoWalkCollide),
		FrameEvent(18, DoWalkCollide),
		FrameEvent(22, DoWalkCollide),
		FrameEvent(26, DoWalkCollide),
		FrameEvent(30, function(inst)
			DoFootstep(inst)
			DoWalkStomp(inst)
			inst.sg:AddStateTag("footstepped")
		end),
		FrameEvent(34, DoWalkCollide),
		FrameEvent(36, function(inst)
			inst.sg:RemoveStateTag("footstepped")
		end),
		FrameEvent(38, DoWalkCollide),
		FrameEvent(42, DoWalkCollide),
		FrameEvent(46, DoWalkCollide),
		FrameEvent(50, DoWalkCollide),
		FrameEvent(54, DoWalkCollide),
	},
},
nil, nil, nil, --anims, softstop, delaystart
{
	endonenter = function(inst)
		if not inst.sg.lasttags["footstepped"] then
			DoFootstep(inst)
		end
		DoWalkStomp(inst)
	end,
})

CommonStates.AddSinkAndWashAshoreStates(states, { washashore = "hit" })
CommonStates.AddVoidFallStates(states, { voiddrop = "hit" })
--CommonStates.AddFrozenStates(states, SwitchToNoFaced, SwitchToFourFaced)

return StateGraph("vault_pillar_guard", states, events, "idle")
