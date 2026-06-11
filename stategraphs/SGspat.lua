require("stategraphs/commonstates")

local events=
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true,true),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnAttacked(nil, math.huge), --hit delay only for projectiles

    EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("electrocute")) then
            local weapon = inst.components.combat and inst.components.combat:GetWeapon()
            if weapon then
                if weapon:HasTag("snotbomb") then
                    inst.sg:GoToState("launchprojectile", data.target)
                else
                    inst.sg:GoToState("attack", data.target)
                end
            end
        end
    end),
    CommonHandlers.OnDeath(),
    EventHandler("heardhorn", function(inst, data)
		if data and data.musician and
			not (	inst.components.health:IsDead() or
					inst.sg:HasAnyStateTag("attack", "electrocute")
				)
		then
			inst:ForceFacePoint(data.musician.Transform:GetWorldPosition())
            inst.sg:GoToState("bellow")
        end
    end),
	EventHandler("loseloyalty", function(inst)
		if not inst.components.health:IsDead() and not inst.sg:HasAnyStateTag("attack", "electrocute") then
			inst.sg:GoToState("shake")
		end
	end),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("idle_loop", true)
            inst.sg:SetTimeout(2 + 2*math.random())
        end,

        ontimeout=function(inst)
            local rand = math.random()
            if rand < .3 then
                inst.sg:GoToState("graze")
            elseif rand < .6 then
                inst.sg:GoToState("bellow")
            else
                inst.sg:GoToState("shake")
            end
        end,
    },

	State{
		name = "spawn_shake",
		tags = { "busy", "invisible", "noattack", "temp_invincible", "noelectrocute" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("spawn_shake")
			inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.sg:RemoveStateTag("invisible")
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("temp_invincible")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("bellow", { count = 2 })
				end
			end),
		},
	},

    State{
        name = "shake",
        tags = {"canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("shake")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "bellow",
        tags = {"busy", "canrotate"},

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("bellow")
            inst.SoundEmitter:PlaySound(inst.sounds.grunt)
            inst.sg.statemem.count = data and data.count or nil
        end,

        events=
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.count ~= nil and inst.sg.statemem.count > 1 then
                    inst.sg:GoToState("bellow", {count=inst.sg.statemem.count - 1})
                else
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "matingcall",
        tags = {},
        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("mating_taunt1")
            inst.SoundEmitter:PlaySound(inst.sounds.yell)
        end,
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name="graze",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("graze_loop", true)
            inst.sg:SetTimeout(5+math.random()*5)
        end,

        ontimeout= function(inst)
            inst.sg:GoToState("idle")
        end,

    },

    State{
        name = "alert",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.SoundEmitter:PlaySound(inst.sounds.curious)
            inst.AnimState:PlayAnimation("alert_pre")
            inst.AnimState:PushAnimation("alert_idle", true)
        end,
    },

    State{
        name = "attack",
        tags = {"attack", "busy"},

        onenter = function(inst, target)
            inst.sg.statemem.target = target
            inst.SoundEmitter:PlaySound(inst.sounds.angry)
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("strike")
            inst.AnimState:PushAnimation("strike_pst", false)
        end,


        timeline=
        {
            TimeEvent(5*FRAMES, function(inst)
                inst.components.locomotor:StopMoving()
                inst.components.combat:DoAttack(inst.sg.statemem.target)
            end),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "launchprojectile",
        tags = {"attack", "busy"},

        onenter = function(inst, target)
			inst.sg.statemem.target = target
            inst.components.combat:StartAttack()
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("snot_pre")
            inst.AnimState:PushAnimation("snot", false)
            inst.AnimState:PushAnimation("snot_pst", false)
        end,


        timeline=
        {
            TimeEvent(19*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound(inst.sounds.spit)
            end),
            TimeEvent(27*FRAMES, function(inst)
                inst.components.combat:DoAttack(inst.sg.statemem.target)
            end),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
			inst.SoundEmitter:PlaySound(inst.sounds.death)
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst:DropDeathLoot()
        end,

        events =
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        },
    },
}

CommonStates.AddWalkStates(
    states,
    {
        walktimeline =
        {
            TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),
            TimeEvent(40*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),
        }
    })

CommonStates.AddRunStates(
    states,
    {
        runtimeline =
        {
            TimeEvent(5*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),
        }
    })

CommonStates.AddSimpleState(states, "hit", "hit", nil, nil, nil, { onenter = CommonHandlers.UpdateHitRecovery })
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)

CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states)

CommonStates.AddSleepStates(states,
{
    sleeptimeline =
    {
        TimeEvent(46*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.sleep) end)
    },
})

return StateGraph("spat", states, events, "init")
