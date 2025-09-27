require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, "gohome"),
    ActionHandler(ACTIONS.EAT, "eat"),
}

local function PlayCreatureSound(inst, sound, creature)
    local creature = creature or inst.soundgroup or inst.prefab
    inst.SoundEmitter:PlaySound("dontstarve/creatures/" .. creature .. "/" .. sound)
end

local events=
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true,true),
    CommonHandlers.OnSink(),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	EventHandler("newcombattarget", function(inst)
		if not (inst.components.health:IsDead() or inst.sg:HasAnyStateTag("attack", "busy")) then
			inst.sg:GoToState("taunt_newtarget")
		end
	end),
	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not (inst.sg:HasAnyStateTag("attack", "electrocute") or CommonHandlers.HitRecoveryDelay(inst, nil, TUNING.WALRUS_MAX_STUN_LOCKS)) then
				inst.sg:GoToState("hit")
			end
		end
	end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    EventHandler("doattack", function(inst)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("electrocute")) then
            if inst.components.combat.target and inst:IsNear(inst.components.combat.target, TUNING.WALRUS_MELEE_RANGE) then
                inst.sg:GoToState("attack")
            else
                if inst:HasTag("taunt_attack") then
                    inst.sg:GoToState("taunt_attack")
                else
                    inst.sg:GoToState("blowdart")
                end
            end
        end
    end),
}

local states=
{
	State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            PlayCreatureSound(inst, "death")
            inst.AnimState:PlayAnimation("death")
            inst.components.locomotor:StopMoving()
            inst.components.lootdropper:DropLoot(Vector3(inst.Transform:GetWorldPosition()))

            RemovePhysicsColliders(inst)
        end,

    },

    State{
        name = "taunt_newtarget", -- i don't want auto-taunt in combat
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("abandon")
            PlayCreatureSound(inst, "taunt")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "taunt_attack",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.combat:StartAttack() -- reset combat attack timer
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("abandon")
            PlayCreatureSound(inst, "taunt")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "funny_idle",
        tags = {"idle"},

        onenter = function(inst)
            inst.Physics:Stop()
            if inst.prefab == "walrus" then
                if math.random(0, 1) == 0 then
                    inst.AnimState:PlayAnimation("idle_happy")
                else
                    inst.AnimState:PlayAnimation("idle_angry")
                end
            else
                if inst.components.combat.target then
                    if math.random(0, 1) == 0 then
                        inst.AnimState:PlayAnimation("idle_scared")
                    else
                        inst.AnimState:PlayAnimation("idle_angry")
                    end
                else
                    if math.random(0, 1) == 0 then
                        inst.AnimState:PlayAnimation("idle_happy")
                    else
                        inst.AnimState:PlayAnimation("idle_creepy")
                    end
                end
            end
            PlayCreatureSound(inst, "taunt")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "attack",
        tags = {"attack"},

        onenter = function(inst)
            PlayCreatureSound(inst, "attack")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
        end,

        timeline =
        {
            TimeEvent(20*FRAMES, function(inst) inst.components.combat:DoAttack() end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "blowdart",
        tags = {"attack"},

        onenter = function(inst)
            if inst.components.combat.target and inst.components.combat.target:IsValid() then
                inst:FacePoint(inst.components.combat.target:GetPosition())
            end
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk_dart")
        end,

        timeline =
        {
            TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/wilson/blowdart_shoot") end),
            TimeEvent(20*FRAMES, function(inst) inst.components.combat:DoAttack() end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "eat",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("eat")
            inst.Physics:Stop()
        end,

        timeline=
        {
            TimeEvent(10*FRAMES, function(inst)
                inst:PerformBufferedAction()
                inst.sg:RemoveStateTag("busy")
                inst.sg:AddStateTag("idle")
            end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            PlayCreatureSound(inst, "hurt")
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },
}

CommonStates.AddWalkStates(states,
{
    walktimeline = {
        TimeEvent(0*FRAMES, PlayFootstep ),
        TimeEvent(12*FRAMES, PlayFootstep ),
    },
})
CommonStates.AddRunStates(states,
{
    runtimeline = {
        TimeEvent(0*FRAMES, PlayFootstep ),
        TimeEvent(10*FRAMES, PlayFootstep ),
    },
})

CommonStates.AddSleepStates(states,
{
    sleeptimeline =
    {
        TimeEvent(35*FRAMES, function(inst) PlayCreatureSound(inst, "sleep") end ),
    },
})

CommonStates.AddIdle(states, "funny_idle")

CommonStates.AddSimpleActionState(states, "gohome", "pig_take", 15*FRAMES, {"busy"})
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddSinkAndWashAshoreStates(states)

return StateGraph("walrus", states, events, "idle", actionhandlers)

