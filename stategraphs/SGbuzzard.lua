require("stategraphs/commonstates")

local easing = require("easing")

local actionhandlers =
{
    ActionHandler(ACTIONS.EAT, "eat"),
    ActionHandler(ACTIONS.GOHOME, function(inst)
        if inst.components.health and not inst.components.health:IsDead() then
            inst.sg:GoToState("flyaway")
        end
    end),
}

local MUTATEDBUZZARD_SEARCH_RANGE = 10
local MUTATEDBUZZARD_MUST_TAGS = { "buzzard", "gestaltmutant" }
local MUTATEDBUZZARD_NO_TAGS = { "NOCLICK" }
local function TargetAlreadyBeingFlameThrowered(inst, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    local buzzards = TheSim:FindEntities(x, y, z, MUTATEDBUZZARD_SEARCH_RANGE, MUTATEDBUZZARD_MUST_TAGS, MUTATEDBUZZARD_NO_TAGS)

    for k, ent in ipairs(buzzards) do
        if ent.components.combat.target == target and ent.sg.currentstate.name == "flamethrower_pre" then
            return true
        end
    end

    return false
end

local function ChooseAttack(inst, target)
    target = target or inst.components.combat.target
	if target ~= nil and not target:IsValid() then
		target = nil
	end

    -- Take turns flamethrowering one target, otherwise we all go in the same line potentially and that looks ugly.
    if inst.canflamethrower and not inst.components.timer:TimerExists("flamethrower_cd") and not TargetAlreadyBeingFlameThrowered(inst, target) then
		inst.sg:GoToState("flamethrower_pre", target)
    elseif inst:IsNear(target, inst.components.combat:GetHitRange()) then
        inst.sg:GoToState("attack", target)
	end
end

local FINDFIRE_TAGS = {"FX"}
local function IsValidFlameToExtend(inst)
    -- kill_fx_task means its still alive.
    return inst.prefab == "warg_mutated_breath_fx" and inst.tallflame and inst.kill_fx_task ~= nil
end

local function SpawnBreathFX(inst, angle, dist, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	local fx = table.remove(inst.flame_pool)
	if fx == nil then
		fx = SpawnPrefab("warg_mutated_breath_fx")
		fx:SetFXOwner(inst)
	end

	local scale = (0.85 + math.random() * 0.15)

	angle = (inst.Transform:GetRotation() + angle) * DEGREES
	x = x + math.cos(angle) * dist
	z = z - math.sin(angle) * dist
	dist = dist / 20
	angle = math.random() * PI2
	x = x + math.cos(angle) * dist
	z = z - math.sin(angle) * dist

    local potential_flames = TheSim:FindEntities(x, 0, z, .8, FINDFIRE_TAGS)
    for i, flame in ipairs(potential_flames) do
        if IsValidFlameToExtend(flame) then
            flame:ExtendFx()
            return
        end
    end

	fx.Transform:SetPosition(x, 0, z)
    fx:ConfigureDamage(TUNING.MUTATEDBUZZARD_FLAMETHROWER_DAMAGE, TUNING.MUTATEDBUZZARD_FLAMETHROWER_PLANAR_DAMAGE)
	fx:RestartFX(scale, "nofade", targets, true)
end

local function ShouldDistress(inst) -- Mutated don't distress
    return not inst:HasTag("lunar_aligned")
end

local function GetLunarFlamePuffAnim(sz, ht)
	return string.format(ht and "lunarflame_puff_%s_%s" or "lunarflame_puff_%s", sz or "small", ht)
end

local function FlyAwayToSky(inst)
    local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
    local ismutated = inst:HasTag("lunar_aligned")

    if ismutated then
        if mutatedbirdmanager then
            mutatedbirdmanager:FillMigrationTaskAtInst("mutatedbuzzard_gestalt", inst, 1)
        end
        inst:Remove()
    elseif inst.components.homeseeker ~= nil then
        inst.components.homeseeker.home.components.childspawner:GoHome(inst)
    else
        --V2C: Debug spawned?
        inst:Remove()
    end
end

local events =
{
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),

    EventHandler("doattack", function(inst, data)
        if inst.components.health and not inst.components.health:IsDead() and
	    	(	not inst.sg:HasStateTag("busy") or
	    		(inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute"))
	    	)
	    then
            ChooseAttack(inst, data ~= nil and data.target or nil)
        end
    end),

    EventHandler("flyaway", function(inst)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("flyaway")
        end
    end),

	EventHandler("onignite", function(inst)
		if inst.components.health and not (inst.components.health:IsDead() or inst.sg:HasStateTag("electrocute"))
            and ShouldDistress(inst) then
			inst.sg:GoToState("distress_pre")
		end
	end),
	EventHandler("locomote", function(inst)
        if (not inst.sg:HasStateTag("idle") and not inst.sg:HasStateTag("moving")) then return end

        local ismutated = inst:HasTag("lunar_aligned")

        if not inst.components.locomotor:WantsToMoveForward() or inst.components.combat.target then
            if not inst.sg:HasStateTag("idle") then
                inst.sg:GoToState("idle")
            end
        else
            if not inst.sg:HasStateTag("hopping") then
                inst.sg:GoToState("hop")
            end
        end
    end),

    EventHandler("corpse_eat", function(inst, data)
		if data ~= nil and data.corpse ~= nil and not inst.components.health:IsDead() then
			if not inst.sg:HasAnyStateTag("eating_corpse", "busy") then
				inst.sg:GoToState("corpse_eat_pre", data.corpse)
			end
		end
	end),
}

local function IsStuck(inst)
	return inst:HasAnyTag("honey_ammo_afflicted", "gelblob_ammo_afflicted") and TheWorld.Map:IsPassableAtPoint(inst.Transform:GetWorldPosition())
end

local states =
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            if pushanim then
                if type(pushanim) == "string" then
                    inst.AnimState:PlayAnimation(pushanim)
                end
                inst.AnimState:PushAnimation("idle", true)
            else
                inst.AnimState:PlayAnimation("idle", true)
            end
            inst.sg:SetTimeout(3 + math.random()*1)
        end,

        ontimeout = function(inst)
			if inst.bufferedaction and inst.bufferedaction.action == ACTIONS.EAT then
				inst.sg:GoToState("eat")
			else
				local r = math.random()
				if r < .75 then
					inst.sg:GoToState("idle")
				else
                    if inst.components.combat.target then
                        inst.sg:GoToState("taunt")
                    else
					    inst.sg:GoToState("caw")
                    end
				end
			end
        end,
    },

    State{
        name = "taunt",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
        end,

        timeline=
        {
            TimeEvent(FRAMES*0, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.taunt) end)
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "caw",
        tags = {"idle"},
        onenter= function(inst)
            inst.AnimState:PlayAnimation("caw")
        end,

        timeline=
        {
            TimeEvent(FRAMES*0, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.squack) end)
        },

        events=
        {
            EventHandler("animover", function(inst) if math.random() < .5 then inst.sg:GoToState("caw") else inst.sg:GoToState("idle") end end ),
        },
    },

    State{
        name = "distress_pre",
        tags = {"busy"},
        onenter= function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("flap_pre")
        end,
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("distress") end ),
        },
    },

    State{
        name = "distress",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("flap_loop")
        end,

        timeline=
        {
            TimeEvent(FRAMES*0, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.squack) end)
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("distress") end ),
			EventHandler("stop_honey_ammo_afflicted", function(inst)
				if not (inst.components.health:IsDead() or (ShouldDistress(inst) and inst.components.burnable and inst.components.burnable:IsBurning()) or IsStuck(inst)) then
					inst.sg:GoToState("flyaway")
				end
			end),
			EventHandler("stop_gelblob_ammo_afflicted", function(inst)
				if not (inst.components.health:IsDead() or (ShouldDistress(inst) and inst.components.burnable and inst.components.burnable:IsBurning()) or IsStuck(inst)) then
					inst.sg:GoToState("flyaway")
				end
			end),
			EventHandler("onextinguish", function(inst)
				if not (inst.components.health:IsDead() or IsStuck(inst)) then
					inst.sg:GoToState("idle", "flap_pst")
				end
			end),
        },
    },

    State{
        name = "glide",
		tags = { "idle", "flight", "busy", "noelectrocute" },
        onenter= function(inst)
            inst.AnimState:PlayAnimation("glide", true)
			inst.DynamicShadow:Enable(false)
            inst.Physics:SetMotorVelOverride(0,-15,0)
            inst.flapSound = inst:DoPeriodicTask(6*FRAMES,
                function(inst)
                    inst.SoundEmitter:PlaySound(inst.sounds.flap)
                end)
        end,

        onupdate= function(inst)
            inst.Physics:SetMotorVelOverride(0,-15,0)
            local pt = Point(inst.Transform:GetWorldPosition())
            if pt.y <= 0.1 or inst:IsAsleep() then
                inst.Physics:ClearMotorVelOverride()
                pt.y = 0
                inst.Physics:Stop()
                inst.Physics:Teleport(pt.x,pt.y,pt.z)
                inst.AnimState:PlayAnimation("land")
                inst.DynamicShadow:Enable(true)
                if inst.sg.statemem.target then
                    inst.sg:GoToState("kill", {target = inst.sg.statemem.target})
                else
                    inst.sg:GoToState("idle", true)
                end
            end
        end,

        onexit = function(inst)
			inst.DynamicShadow:Enable(true)
            if inst.flapSound then
                inst.flapSound:Cancel()
                inst.flapSound = nil
            end

            if inst:GetPosition().y > 0 then
                local pos = inst:GetPosition()
                pos.y = 0
                inst.Transform:SetPosition(pos:Get())
            end
            inst.components.knownlocations:RememberLocation("landpoint", inst:GetPosition())
        end,
    },

    State{
        name = "kill",
        tags = {"canrotate"},
        onenter = function(inst, data)
            inst.AnimState:PushAnimation("atk", false)
            if data and data.target:HasTag("prey") then
                inst.sg.statemem.target = data.target
            end
        end,

        timeline =
        {
            TimeEvent(15*FRAMES, function(inst)
                if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                    inst:FacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                end
            end),
            TimeEvent(27*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound(inst.sounds.attack)
                local target = inst.sg.statemem.target

                if target ~= nil and
                    target:IsValid() and
                    inst:IsNear(target, TUNING.BUZZARD_ATTACK_RANGE) and
                    inst.components.combat:CanAttack(target) then
                    target.components.health:Kill()
                end
            end)
        },

        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "eat",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("peck")
        end,

        events=
        {
            EventHandler("animover", function(inst)
                if math.random() < .3 then
					inst:PerformBufferedAction()
                end
                inst.sg:GoToState("idle")
                if inst.brain then
                    inst.brain:ForceUpdate()
                end
            end),
        },
    },

    State{
        name = "flyaway",
		tags = { "flight", "busy", "canrotate", "noelectrocute" },
        onenter = function(inst)
			if IsStuck(inst) then
				inst.sg:GoToState("distress_pre")
				return
			end

            inst.components.locomotor:Stop()

            inst.sg:SetTimeout(.1+math.random()*.2)
            inst.sg.statemem.vert = math.random() > .5

            if inst.components.periodicspawner and math.random() <= TUNING.CROW_LEAVINGS_CHANCE then
                inst.components.periodicspawner:TrySpawn()
            end

            inst.AnimState:PlayAnimation(inst.sg.statemem.vert and "takeoff_vertical_pre" or "takeoff_diagonal_pre")

            inst.SoundEmitter:PlaySound(inst.sounds.flyout)
        end,

        ontimeout= function(inst)
            if inst.sg.statemem.vert then
                inst.AnimState:PushAnimation("takeoff_vertical_loop", true)
                inst.Physics:SetMotorVel(-2 + math.random()*4,15+math.random()*5,-2 + math.random()*4)
            else
                inst.AnimState:PushAnimation("takeoff_diagonal_loop", true)
                local x = 8+ math.random()*8
                inst.Physics:SetMotorVel(x,15+math.random()*5,-2 + math.random()*4)
            end
			inst.DynamicShadow:Enable(false)
        end,

        timeline =
        {
            TimeEvent(2, FlyAwayToSky),
        },

		onexit = function(inst)
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "hop",
        tags = {"moving", "canrotate", "hopping"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hop")
            inst.components.locomotor:WalkForward()
            inst.sg:SetTimeout(2*math.random()+.5)
        end,

        onupdate= function(inst)
            if not inst.components.locomotor:WantsToMoveForward() then
                inst.sg:GoToState("idle")
            end
        end,

        timeline=
        {
            TimeEvent(8*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound(inst.sounds.hop)
                inst.Physics:Stop()
            end),
        },

        ontimeout= function(inst)
            inst.sg:GoToState("hop")
        end,
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("atk")
            inst.components.combat:StartAttack()
            inst.sg.statemem.target = target
        end,

        timeline =
        {
            TimeEvent(15*FRAMES, function(inst)
                inst.components.combat:DoAttack(inst.sg.statemem.target)
                inst.SoundEmitter:PlaySound(inst.sounds.attack)
            end),
            TimeEvent(20*FRAMES, function(inst) inst.sg:RemoveStateTag("attack") end),
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
        name = "hit",
        tags = { "hit", "busy" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

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
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("death")
            RemovePhysicsColliders(inst)
            inst:DropDeathLoot()
            inst.SoundEmitter:PlaySound(inst.sounds.death)
        end,

        events =
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        },
    },

    State{
        name = "fall",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("fall_loop", true)
			inst.DynamicShadow:Enable(false)
        end,

        onupdate = function(inst)
            local pt = Vector3(inst.Transform:GetWorldPosition())
            if pt.y <= .2 then
                pt.y = 0
                inst.Physics:Stop()
                inst.Physics:Teleport(pt.x,pt.y,pt.z)
	            inst.DynamicShadow:Enable(true)
                inst.sg:GoToState("stunned")
            end
        end,

		onexit = function(inst)
			inst.DynamicShadow:Enable(true)
		end,
    },

    -- Mutated states

    State{
        name = "flamethrower_pre",
        tags = { "attack", "busy", "flamethrowering" },

        onenter = function(inst, target)
            if IsStuck(inst) then
				inst.sg:GoToState("distress_pre")
				return
			end

            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_flame_pre")
            inst:SwitchToEightFaced()

            RaiseFlyingCreature(inst)
            ChangeToFlyingCharacterPhysics(inst, 15, .25)

            if target and target:IsValid() then
                if inst.components.combat:TargetIs(target) then
                    inst.components.combat:StartAttack()
                end

                inst.sg.statemem.target = target
                inst.sg.statemem.targetpos = target:GetPosition()
            end

            inst.Physics:SetMotorVelOverride(-1, 0, 0)
            inst.components.combat:SetDefaultDamage(TUNING.MUTATEDBUZZARD_FLAMETHROWER_DAMAGE)
        end,

        onupdate = function(inst)
            local target = inst.sg.statemem.target
			if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(inst.sg.statemem.target:GetPosition())
			else
				inst.sg.statemem.target = nil
            end
        end,

        timeline =
        {
            FrameEvent(12, function(inst) inst.Physics:SetMotorVelOverride(-5, 0, 0) end),
            FrameEvent(20, function(inst) inst.Physics:SetMotorVelOverride(-3, 0, 0) end),
        },

        events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.attacking = true
					inst.sg:GoToState("flamethrower_loop")
				end
			end),
		},

        onexit = function(inst)
			if not inst.sg.statemem.attacking then
                LandFlyingCreature(inst)
                ChangeToCharacterPhysics(inst, 15, .25)
				inst.components.combat:SetDefaultDamage(TUNING.MUTATEDBUZZARD_DAMAGE)
				inst.SoundEmitter:KillSound("loop")
			end
		end,
    },

    State{
		name = "flamethrower_loop",
		tags = { "attack", "busy", "flight", "noelectrocute", "flamethrowering" }, -- To dodge electric fence.

		onenter = function(inst, targets)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_flame_loop", true)
            inst.Physics:SetMotorVelOverride(12, 0, 0)
            inst:SwitchToEightFaced()

            inst.sg.statemem.targets = targets or {}

            if inst.SetFlameThrowerOnCd then
                inst:SetFlameThrowerOnCd()
            end

            if not inst.SoundEmitter:PlayingSound("loop") then
				inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/fire_breath_LP", "loop")
			end
		end,

		timeline =
		{
            FrameEvent(4, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(7, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(10, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(13, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(16, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(19, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(22, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(25, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(28, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),

            FrameEvent(30, function(inst)
                inst.sg.statemem.attacking = true
                inst.sg:GoToState("flamethrower_pst", inst.sg.statemem.targets)
            end),
		},

		events =
		{
            --[[
			EventHandler("attacked", function(inst, data)
				if not inst.components.health:IsDead() then
					local dohit
					if data and data.spdamage and data.spdamage.planar then
						if not inst.sg.mem.dostagger then
							inst.sg.mem.dostagger = true
							inst.sg.statemem.staggertime = GetTime() + 0.3
						elseif GetTime() > inst.sg.statemem.staggertime then
							dohit = true
						end
					end
					if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
						return
					elseif dohit then
						inst.sg:GoToState("hit")
					end
				end
				return true
			end),
            ]]
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst:SwitchToFourFaced()
                ChangeToCharacterPhysics(inst, 15, .25)
				inst.components.combat:SetDefaultDamage(TUNING.MUTATEDBUZZARD_DAMAGE)
				inst.SoundEmitter:KillSound("loop")
			elseif not inst.sg.statemem.loop then
				inst.components.combat:SetDefaultDamage(TUNING.MUTATEDBUZZARD_DAMAGE)
			end
		end,
	},

    State{
		name = "flamethrower_pst",
		tags = { "attack", "busy", "flamethrowering" },

		onenter = function(inst, targets)
			inst.sg.statemem.targets = targets or {}

            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_flame_pst")

            ChangeToCharacterPhysics(inst, 15, .25)

            inst:SwitchToEightFaced()
            inst.Physics:SetMotorVelOverride(10, 0, 0)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) SpawnBreathFX(inst, 0, 1.5, inst.sg.statemem.targets) end),
            FrameEvent(4, function(inst) inst.SoundEmitter:KillSound("loop") end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVelOverride(8, 0, 0) end),
            FrameEvent(10, function(inst) inst.Physics:SetMotorVelOverride(4, 0, 0) end),
			FrameEvent(13, function(inst)
                inst.Physics:SetMotorVelOverride(0, 0, 0)
                inst.sg:RemoveStateTag("busy")
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

		onexit = function(inst)
			inst:SwitchToFourFaced()
            inst.Physics:SetMotorVelOverride(0, 0, 0)
			inst.SoundEmitter:KillSound("loop")
		end,
	},

    State{
		name = "corpse_eat_pre",
		tags = { "eating_corpse", "busy", "caninterrupt" },

		onenter = function(inst, corpse)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("corpse_eat_pre")
			inst.SoundEmitter:PlaySound(inst.sounds.attack)

            inst.sg.statemem.corpse = corpse
		end,

		timeline =
		{
			FrameEvent(6, function(inst)

			end),
		},

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("corpse_eat_loop", inst.sg.statemem.corpse)
            end)
        },
	},

    State{
        name = "corpse_eat_loop",
        tags = { "eating_corpse" },

        onenter = function(inst, corpse)
            inst.AnimState:PlayAnimation("corpse_eat_loop")
            inst.SoundEmitter:PlaySound(inst.sounds.spit)

            if not inst.SoundEmitter:PlayingSound("eating_loop") then
                inst.SoundEmitter:PlaySound(inst.sounds.eat, "eating_loop")
            end

            if corpse ~= nil and corpse:IsValid() and inst:IsNear(corpse, inst.components.combat:GetHitRange() + corpse:GetPhysicsRadius(0)) then
                inst.sg.statemem.corpse = corpse

                if not corpse:WillMutate() then
                    local _, sz, ht = GetCombatFxSize(corpse)

                    if corpse.components.burnable and corpse.components.burnable:IsBurning() then
                        -- Hack!
                        corpse._skip_extinguish_fade = true
                        corpse.components.burnable:Extinguish()
                        corpse._skip_extinguish_fade = nil

                        local fx = SpawnPrefab(GetLunarFlamePuffAnim(sz, ht))
                        fx.Transform:SetPosition(corpse.Transform:GetWorldPosition())
                    end

                    corpse:PushEvent("chomped", { eater = inst, amount = 1.5, weapon_sound_modifier = "sharp" })

                    if CanEntityBeNonGestaltMutated(corpse) and corpse.meat_level >= 2 then
                        -- TODO hack? set back to level 1?
                        corpse:StartReviveMutateTimer(.5 + math.random() * .1)
                    end
                end
            end
        end,

        timeline =
        {
            FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.spit) end)
        },

        events =
        {
            EventHandler("animover", function(inst)
                local corpse = inst.sg.statemem.corpse
                if corpse and inst.brain and inst.brain:IsCorpseValid() and inst.brain.corpse == corpse then
                    inst.sg:GoToState("corpse_eat_loop", corpse)
                else
                    inst.sg:GoToState("corpse_eat_pst")
                end
            end),
        },

        onexit = function(inst, new_state)
            if new_state ~= "corpse_eat_loop" then
                inst.SoundEmitter:KillSound("eating_loop")
            end
        end,
    },

    State{
        name = "corpse_eat_pst",
        tags = { "busy", "caninterrupt", },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("corpse_eat_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        }
    },

    --------------------------------------------------------------------------
	--Used by "buzzardcorpse"

    State{
        name = "corpse_fall",
		tags = { "corpse", "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
			inst.DynamicShadow:Enable(false)

            inst.sg.statemem.vert = math.random() < .5
            inst.Transform:SetRotation(math.random(360))

            inst.AnimState:PlayAnimation(inst.sg.statemem.vert and "fall_corpse_spiral" or "fall_corpse", true)

            local rot = inst.Transform:GetRotation() * DEGREES
            if inst.sg.statemem.vert then
                inst.Physics:SetVel(math.random() * 4 - 2, 0, math.random() * 4 - 2)
            else
                inst.Physics:SetVel(10 * math.cos(rot), 0, 10 * -math.sin(rot))
            end
        end,

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y <= .2 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.DynamicShadow:Enable(true)

                --Slide a lil if we were going diagonally
                if not inst.sg.statemem.vert then
                    local rot = inst.Transform:GetRotation() * DEGREES
                    inst.Physics:SetVel(math.random(6, 10) * math.cos(rot), 0, math.random(6, 10) * -math.sin(rot))
                end

                inst.sg:GoToState("corpse_idle", "fall_corpse_to_idle")
                inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/ground_hit")

                --Can't use inventoryitem:TryToSink, not an item!
                if ShouldEntitySink(inst, true) then
                    inst:DoTaskInTime(0, SinkEntity)
                end
            end
        end,

		onexit = function(inst)
			inst.DynamicShadow:Enable(true)
		end,
    },
}

CommonStates.AddCorpseStates(states)
CommonStates.AddSleepStates(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states, nil, nil,
{
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			if inst.components.burnable and inst.components.burnable:IsBurning() and ShouldDistress(inst) then
				inst.sg:GoToState("distress_pre")
			else
				inst.sg:GoToState("flyaway")
			end
		end
	end,
})

CommonStates.AddLunarRiftMutationStates(states, nil, nil,
{ -- fns
    mutate_onenter = function(inst)
        inst.AnimState:OverrideSymbol("lunar_parts", "buzzard_lunar_build", "lunar_parts")
		inst.AnimState:OverrideSymbol("fx_puff_hi", "buzzard_lunar_build", "fx_puff_hi")
		inst.AnimState:OverrideSymbol("fx_puff2", "buzzard_lunar_build", "fx_puff2")
        inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/mutate_pre")
    end,

    mutatepst_onenter = function(inst)
        inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/mutate_hit")
        inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_mutation/mutate_crack")
    end,
},
{
    twitch_lp = "lunarhail_event/creatures/lunar_crow/twitch_LP",
    keep_twitch_lp = true,
    post_mutate_state = "flyaway",
})

CommonStates.AddInitState(states, "idle")

return StateGraph("buzzard", states, events, "init", actionhandlers)
