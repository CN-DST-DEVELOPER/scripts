require("stategraphs/commonstates")

local easing = require("easing")

local actionhandlers =
{
    --Will this affect regular birds?
    ActionHandler(ACTIONS.EAT, "lunar_eat"),
    ActionHandler(ACTIONS.REMOVELUNARBUILDUP, "peck"), --glide_clearhail
    --ActionHandler(ACTIONS.GOHOME, "flyaway"),
}

local function IsStuck(inst)
	return inst:HasAnyTag("honey_ammo_afflicted", "gelblob_ammo_afflicted") and TheWorld.Map:IsPassableAtPoint(inst.Transform:GetWorldPosition())
end

local function PlayShardFx(inst, target)
    if target ~= nil and target:IsValid() then
        local fx = SpawnPrefab("mining_moonglass_fx")
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
        fx.Transform:SetScale(0.5, 0.5, 0.5)
        --sound?
    end
end

local function FlyAwayToSky(inst)
    --Bright-Beaked Birds persist.
    local birdspawner = TheWorld.components.birdspawner
    --if inst:HasTag("bird_mutant_rift") and birdspawner then
    --    birdspawner:StoreMutatedBird(inst)
    --else
        inst:Remove()
    --end
end

local events =
{
    EventHandler("gotosleep", function(inst)
        if not inst.components.health:IsDead() then
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.sg:GoToState(
                (y > 1 and "fall") or --special bird behaviour
                (inst.sg:HasStateTag("sleeping") and "sleeping") or
                "sleep"
            )
        end
    end),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	EventHandler("attacked", function(inst, data)
        if inst.components.health and not inst.components.health:IsDead() then
			if not IsStuck(inst) and CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("electrocute") then
				inst.sg:GoToState("hit")
			end
        end
    end),
    EventHandler("death", function(inst)
        inst.sg:GoToState("death")
    end),
    EventHandler("flyaway", function(inst)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("flyaway")
        end
    end),
    EventHandler("onignite", function(inst)
		if inst.components.health and not (inst.components.health:IsDead() or inst.sg:HasStateTag("electrocute")) then
            inst.sg:GoToState("distress_pre")
        end
    end),
    EventHandler("trapped", function(inst)
        inst.sg:GoToState("trapped")
    end),
    EventHandler("stunbomb", function(inst)
        inst.sg:GoToState("stunned")
    end),
    EventHandler("glide_attack_at_target", function(inst, data)
        inst.sg:GoToState("glide_attack_in", data.target)
    end),
    EventHandler("glide_clear_at_target", function(inst, data)
        inst.sg:GoToState("glide_clearhail", data.target)
    end),

    EventHandler("locomote", function(inst) --FIXME probably no more locomotion when new behaviour of bird is in
        --NOTE: Locomote behaviour for the mutated bird, it's probably fine to have this event listener for all, but just in case.
        if inst:HasTag("bird_mutant_rift") and not inst.sg:HasAnyStateTag("sleeping", "busy", "flight") then
            local is_moving = inst.sg:HasStateTag("moving")
            local wants_to_move = inst.components.locomotor:WantsToMoveForward()
            if is_moving ~= wants_to_move then
                inst.sg:GoToState(wants_to_move and "hop" or "idle")
            end
        end
    end),
}

local states =
{
    State{
		name = "init",
		onenter = function(inst)
			inst.sg:GoToState(inst.components.locomotor ~= nil and "glide" or POPULATING and "corpse_idle" or "corpse_fall")
		end,
	},

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            if pushanim then
                if type(pushanim) == "string" then
                    inst.AnimState:PlayAnimation(pushanim)
                end
                inst.AnimState:PushAnimation("idle", true)
            elseif not inst.AnimState:IsCurrentAnimation("idle") then
                inst.AnimState:PlayAnimation("idle", true)
            end
            inst.sg:SetTimeout(1 + math.random())
        end,

        ontimeout = function(inst)
            if inst.bufferedaction ~= nil and inst.bufferedaction.action == ACTIONS.EAT then
                inst.sg:GoToState("peck")
            else
                local r = math.random()
                inst.sg:GoToState(
                    (r < .5 and "idle") or
                    (r < .6 and "switch") or
                    (r < .7 and "peck") or
                    (r < .8 and "hop") or
                    (r < .9 and "flyaway") or
                    "caw"
                )
            end
        end,
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
            if inst.sounds.death then
                inst.SoundEmitter:PlaySound(inst.sounds.death)
            end
        end,
    },

    State{
        name = "caw",
        tags = { "idle" },

        onenter = function(inst)
            if not inst.AnimState:IsCurrentAnimation("caw") then
                inst.AnimState:PlayAnimation("caw", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
            inst.SoundEmitter:PlaySound(inst.sounds.chirp)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState(math.random() < .5 and "caw" or "idle")
        end,
    },

    State{
        name = "distress_pre",
        tags = { "busy" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("flap_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("distress")
            end),
        },
    },

    State{
        name = "distress",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("flap_loop")
            inst.SoundEmitter:PlaySound("dontstarve/birds/wingflap_cage")
            inst.SoundEmitter:PlaySound(inst.sounds.chirp)
        end,

        events =
        {
			EventHandler("stop_honey_ammo_afflicted", function(inst)
				if not (inst.components.health:IsDead() or (inst.components.burnable and inst.components.burnable:IsBurning()) or IsStuck(inst)) then
					inst.sg:GoToState("flyaway")
				end
			end),
			EventHandler("stop_gelblob_ammo_afflicted", function(inst)
				if not (inst.components.health:IsDead() or (inst.components.burnable and inst.components.burnable:IsBurning()) or IsStuck(inst)) then
					inst.sg:GoToState("flyaway")
				end
			end),
            EventHandler("onextinguish", function(inst)
				if not (inst.components.health:IsDead() or IsStuck(inst)) then
                    inst.sg:GoToState("idle", "flap_post")
                end
            end),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("distress")
            end),
        },
    },

    State{
        name = "delay_glide",
		tags = { "busy", "notarget", "noelectrocute" },

        onenter = function(inst, delay)
            inst:AddTag("NOCLICK")
			inst:AddTag("NOBLOCK")
            inst:Hide()
            inst.Physics:SetActive(false)
            inst.sg:SetTimeout(delay)
            inst.DynamicShadow:Enable(false)
        end,

        ontimeout = function(inst)
            inst.sg.statemem.gliding = true
            inst.sg:GoToState("glide")
        end,

        onexit = function(inst)
            if not inst.sg.statemem.gliding then
                inst:RemoveTag("NOCLICK")
                inst:RemoveTag("NOBLOCK")
                inst.DynamicShadow:Enable(true)
            end
            inst:Show()
            inst.Physics:SetActive(true)
        end,
    },

    State{
        name = "glide",
		tags = { "idle", "flight", "notarget", "noelectrocute" },

        onenter = function(inst)
			inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            if not inst.AnimState:IsCurrentAnimation("glide") then
                inst.AnimState:PlayAnimation("glide", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

            inst.Physics:SetMotorVel(0, math.random() * 10 - 20, 0)
			inst.DynamicShadow:Enable(false)
        end,

        timeline =
        {
            TimeEvent(1 * FRAMES, function(inst)
                if inst.components.inventoryitem == nil or not inst.components.inventoryitem:IsHeld() then
                    inst.SoundEmitter:PlaySound(inst.sounds.flyin)
                end
            end),
        },

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y < 2 then
                inst.Physics:SetMotorVel(0, 0, 0)
            end
            if y <= 0.1 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.AnimState:PlayAnimation("land")
                inst.DynamicShadow:Enable(true)
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                end
                inst.sg:GoToState("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("glide")
        end,

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "switch",
        tags = { "idle" },

        onenter = function(inst)
            inst.Transform:SetRotation(inst.Transform:GetRotation() + 180)
            inst.AnimState:PlayAnimation("switch")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "peck",

        onenter = function(inst)
            inst.Physics:Stop()
            if not inst.AnimState:IsCurrentAnimation("peck") then
                inst.AnimState:PlayAnimation("peck", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline = {
            FrameEvent(4, function(inst)
                local buffaction = inst:GetBufferedAction()
                if inst:HasTag("bird_mutant_rift") and buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
            end),
			FrameEvent(9, function(inst)
                local buffaction = inst:GetBufferedAction()
                if inst:HasTag("bird_mutant_rift") and buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
            end),
        },

        ontimeout = function(inst)
            if math.random() < .3 then
                inst:PerformBufferedAction()
                inst.sg:GoToState("idle")
            else
                inst.sg:GoToState("peck")
            end
        end,
    },

    State{
        name = "flyaway",
		tags = { "flight", "busy", "notarget", "noelectrocute" },

        onenter = function(inst)
			if IsStuck(inst) then
				inst.sg:GoToState("distress_pre")
				return
			end

            --For Mutated bird
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

            local x, y, z = inst.Transform:GetWorldPosition()
            inst.sg.statemem.noescape = TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z)

			inst:AddTag("NOCLICK")
			inst:AddTag("NOBLOCK")

            if inst.components.floater ~= nil then
                inst:PushEvent("on_no_longer_landed")
            end
            inst.Physics:Stop()
            inst.sg:SetTimeout(.1 + math.random() * .2)
            inst.sg.statemem.vert = math.random() < .5
            if inst.sg.statemem.noescape then
                inst.sg.statemem.vert = true
            end

            inst.SoundEmitter:PlaySound(inst.sounds.takeoff)

            if not inst.sg.statemem.noescape and inst.components.periodicspawner ~= nil and math.random() <= TUNING.BIRD_LEAVINGS_CHANCE then
                inst.components.periodicspawner:TrySpawn()
            end

            inst.AnimState:PlayAnimation(inst.sg.statemem.vert and "takeoff_vertical_pre" or "takeoff_diagonal_pre")
        end,

        ontimeout = function(inst)
            if inst.sg.statemem.vert then
                inst.AnimState:PushAnimation("takeoff_vertical_loop", true)
                local horix, horiz = math.random() * 4 - 2, math.random() * 4 - 2
                if inst.sg.statemem.noescape then
                    horix, horiz = horix * 0.1, horiz * 0.1
                end
                inst.Physics:SetMotorVel(horix, math.random() * 5 + 15, horiz)
            else
                inst.AnimState:PushAnimation("takeoff_diagonal_loop", true)
                inst.Physics:SetMotorVel(math.random() * 8 + 8, math.random() * 5 + 15,math.random() * 4 - 2)
            end
			inst.DynamicShadow:Enable(false)
        end,

        timeline =
        {
			FrameEvent(5, function(inst)
				inst.DynamicShadow:SetSize(.6, .5)
			end),
            TimeEvent(2, function(inst)
                if inst.sg.statemem.noescape then
                    inst.sg:GoToState("fall")
                else
                    FlyAwayToSky(inst)
                end
            end),
        },

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
			inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:SetSize(1, .75)
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "hop",
        tags = { "moving", "canrotate", "hopping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hop")
            inst.Physics:SetMotorVel(5, 0, 0)
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                inst.Physics:Stop()
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                elseif inst.components.inventoryitem ~= nil then
                    inst.components.inventoryitem:TryToSink()
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y > 1 then
                inst.sg:GoToState("fall")
                return
            end
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.components.burnable ~= nil and inst.components.burnable:IsBurning() and "distress_pre" or "flyaway")
            end),
        },
    },

    State{
        name = "fall",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("fall_loop", true)
			inst.DynamicShadow:Enable(false)
        end,

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y <= .2 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.DynamicShadow:Enable(true)
                inst.sg:GoToState("stunned")
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                end
            end
        end,

		onexit = function(inst)
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "trapped",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(1)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("flyaway")
        end,
    },

    State{
        name = "stunned",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(GetRandomWithVariance(6, 2))
            if inst.components.inventoryitem ~= nil then
                inst.components.inventoryitem.canbepickedup = true
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("flyaway")
        end,

        onexit = function(inst)
            if inst.components.inventoryitem ~= nil then
                inst.components.inventoryitem.canbepickedup = false
            end
        end,
    },

    --------------------------------------------------------------------------
	--Used by "birdcorpse"

    State{
        name = "corpse_fall",
		tags = { "busy", "noelectrocute" },

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
                inst.sg:GoToState("corpse_idle")
                inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_crow/body_land")

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

	State{
		name = "corpse_idle",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("corpse")
		end,
	},

	State{
		name = "corpse_mutate_pre",
		tags = { "mutating" },

		onenter = function(inst, mutantprefab)
			inst.AnimState:PlayAnimation("twitch", true)
			inst.sg:SetTimeout(3)
			inst.sg.statemem.mutantprefab = mutantprefab
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("corpse_mutate", inst.sg.statemem.mutantprefab)
		end,

		onexit = function(inst)
			inst.SoundEmitter:KillSound("loop")
		end,
	},

	State{
		name = "corpse_mutate",
		tags = { "mutating" },

		onenter = function(inst, mutantprefab)
			inst.AnimState:OverrideSymbol("lunar_parts", "bird_lunar_build", "lunar_parts")
			inst.AnimState:OverrideSymbol("fx_puff_hi", "bird_lunar_build", "fx_puff_hi")
			inst.AnimState:OverrideSymbol("fx_puff2", "bird_lunar_build", "fx_puff2")

			inst.AnimState:PlayAnimation("mutate_pre")
            inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_crow/mutate_pre")

			inst.sg.statemem.mutantprefab = mutantprefab
		end,

		timeline =
		{
			FrameEvent(0, function(inst)

            end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					local rot = inst.Transform:GetRotation()
					local creature = ReplacePrefab(inst, inst.sg.statemem.mutantprefab)
					creature.Transform:SetRotation(rot)
					creature.AnimState:MakeFacingDirty() --not needed for clients
					creature.sg:GoToState("mutate_pst")
				end
			end),
		},

		onexit = function(inst)
			--Shouldn't reach here!
			inst.AnimState:ClearAllOverrideSymbols()
			inst.AnimState:SetAddColour(0, 0, 0, 0)
			inst.AnimState:SetLightOverride(0)
			inst.SoundEmitter:KillSound("loop")
			inst.components.burnable:SetBurnTime(TUNING.MED_BURNTIME)
			inst.components.burnable.fastextinguish = false
		end,
	},

	--------------------------------------------------------------------------
	--Transitions from corpse_mutate after prefab switch
	State{
		name = "mutate_pst",
		tags = { "busy", "noattack", "temp_invincible", "noelectrocute" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("mutate")
            inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_crow/mutate")
			inst.sg.statemem.flash = 24
		end,

		onupdate = function(inst)
			local c = inst.sg.statemem.flash
			if c >= 0 then
				inst.sg.statemem.flash = c - 1
				c = easing.inOutQuad(math.min(20, c), 0, 1, 20)
				inst.AnimState:SetAddColour(c, c, c, 0)
				inst.AnimState:SetLightOverride(c)
			end
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("caw")
				end
			end),
		},

		onexit = function(inst)
			inst.AnimState:SetAddColour(0, 0, 0, 0)
			inst.AnimState:SetLightOverride(0)
		end,
	},

    State{
        name = "lunar_eat",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            if not inst.AnimState:IsCurrentAnimation("lunar_eat") then
                inst.AnimState:PlayAnimation("lunar_eat", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
		{
            FrameEvent(12, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
            end),
			FrameEvent(26, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
                inst:PerformBufferedAction()
            end),
		},

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    --This will also be how they destroy the hail build up
    --TODO, this is very conceptual!
    State{
        name = "glide_attack_in", --For mutated bird
		tags = { "idle", "flight", "notarget", "noelectrocute" }, --flight and notarget prevent attacks

        onenter = function(inst, target)
		    inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            if not inst.AnimState:IsCurrentAnimation("glide") then
                inst.AnimState:PlayAnimation("glide", true)
            end

            local x, y, z = inst.Transform:GetWorldPosition()

            local dist = math.sqrt(inst:GetDistanceSqToInst(target))

            inst.sg.statemem.target = target
            inst.sg.statemem.velocity = {dist/2, (-y + 4)/2, 0} --math.random() * 10 - 20, 0} --{dist/2, (-y + 5)/2, 0}

            inst:ForceFacePoint(target:GetPosition())
            inst.Physics:SetMotorVel(unpack(inst.sg.statemem.velocity)) --math.random() * 10 - 20 -- -12
			inst.DynamicShadow:Enable(true)
        end,

        timeline =
        {
            FrameEvent(1, function(inst)
                if inst.components.inventoryitem == nil or not inst.components.inventoryitem:IsHeld() then
                    inst.SoundEmitter:PlaySound(inst.sounds.flyin)
                end
            end),
        },

        onupdate = function(inst, dt)
            local target = inst.sg.statemem.target
            local x, y, z = inst.Transform:GetWorldPosition()

            if target and target:IsValid() then
                if y < 2 then
                    inst.sg:GoToState("glide_attack_out", target)
                elseif y > 3 then
                    local tx, ty, tz = inst.sg.statemem.target.Transform:GetWorldPosition()
                    local dx = tx - x
		            local dz = tz - z

                    if dx ~= 0 and dz ~= 0 then
                        local dir = inst.Transform:GetRotation() * DEGREES
                        local dir1 = math.atan2(-dz, dx)
                        local diff = ReduceAngleRad(dir1 - dir)

                        --Allow minor change in direction
			            local maxdiff = 10 * DEGREES --Make degree turning depend on height to ground
			            dir = dir + math.clamp(diff, -maxdiff, maxdiff)

                        --TODO update velocity too
                        --inst.sg.statemem.velocity[1] = 
                        inst.Transform:SetRotation(dir * RADIANS)
                        --inst.Physics:SetMotorVel(unpack(inst.sg.statemem.velocity))
                    end

                    --inst:ForceFacePoint(inst.sg.statemem.target:GetPosition())
                end
            end

            if y <= 0.1 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.AnimState:PlayAnimation("land")
                inst.DynamicShadow:Enable(true)
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                end
                inst.sg:GoToState("idle", true)
            end
        end,

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "glide_attack_out", --For mutated bird
		tags = { "idle", "flight", "noelectrocute" },

        onenter = function(inst, target)
            --Pre animation before switching from glide to takeoff_diagonal_loop?
            if target then
                inst.components.combat:DoAttack(target)
            end
            inst.AnimState:PlayAnimation("takeoff_diagonal_loop", true)
            inst.SoundEmitter:PlaySound(inst.sounds.attack)
            inst.Physics:SetMotorVel(15, math.random() * 5 + math.random() * 4, 0)
        end,

        timeline =
        {
            FrameEvent(6, function(inst)
                inst.sg:AddStateTag("notarget")
            end),
            TimeEvent(2, FlyAwayToSky),
        },

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "glide_clearhail", --For mutated bird
		tags = { "idle", "flight", "notarget", "noelectrocute" },

        onenter = function(inst)
			inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            if not inst.AnimState:IsCurrentAnimation("glide") then
                inst.AnimState:PlayAnimation("glide", true)
            end
            --inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

            local buffaction = inst:GetBufferedAction()

            local x, y, z = inst.Transform:GetWorldPosition()

            local dist = math.sqrt(inst:GetDistanceSqToInst(buffaction.target))

            inst.sg.statemem.target = buffaction.target
            inst.sg.statemem.velocity = {dist, -y + 3, 0}

            inst:ForceFacePoint(buffaction.target:GetPosition())
            inst.Physics:SetMotorVel(unpack(inst.sg.statemem.velocity))
			inst.DynamicShadow:Enable(true)
        end,

        timeline =
        {
            FrameEvent(1, function(inst)
                if inst.components.inventoryitem == nil or not inst.components.inventoryitem:IsHeld() then
                    inst.SoundEmitter:PlaySound(inst.sounds.flyin)
                end
            end),
        },

        onupdate = function(inst, dt)
            local target = inst.sg.statemem.target
            local x, y, z = inst.Transform:GetWorldPosition()

            if target and target:IsValid() then
                if inst:GetDistanceSqToInst(target) < 1 and inst:GetBufferedAction() then
                    inst:PerformBufferedAction()
                    inst.sg:GoToState("glide_attack_out")
                end
            end

            if y <= 0.1 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.AnimState:PlayAnimation("land")
                inst.DynamicShadow:Enable(true)
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                end
                inst.sg:GoToState("idle", true)
            end
        end,

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:Enable(true)
		end,
    },
}

CommonStates.AddSleepStates(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states, nil, nil,
{
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			if inst.components.burnable and inst.components.burnable:IsBurning() then
				inst.sg:GoToState("distress_pre")
			else
				inst.sg:GoToState("flyaway")
			end
		end
	end,
})

return StateGraph("bird", states, events, "init", actionhandlers)