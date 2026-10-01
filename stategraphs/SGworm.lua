require("stategraphs/commonstates")

local function doattackfn(inst, data)
    if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
        inst.sg:GoToState(inst.sg:HasStateTag("lure") and "attack_pre" or "attack")
    end
end

local function onattackedfn(inst, data)
	if not (inst.components.health:IsDead() or inst.sg:HasStateTag("invisible")) then
		if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
			return
		elseif not inst.sg:HasAnyStateTag("busy", "nohit") then
			inst.sg:GoToState("hit")
		end
    end
end

local function ChangeToLure(inst)
    inst.components.pickable.canbepicked = true
    ChangeToInventoryPhysics(inst)
    inst.components.sanityaura.aura = 0
end

local function ChangeToWorm(inst)
    inst.components.pickable.canbepicked = false
    ChangeToCharacterPhysics(inst)
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_SMALL
end

local function ExtinguishFire(inst)
    if inst.components.burnable == nil then
        return
    end

    inst:AddTag("fireimmune")

    if inst.components.burnable:IsBurning() then
        inst.components.burnable.fastextinguish = true
        inst.components.burnable:Extinguish()
        inst.components.burnable.fastextinguish = false
    end
end

local actionhandlers =
{
    ActionHandler(ACTIONS.PICKUP, "action"),
    ActionHandler(ACTIONS.PICK, "action"),
    ActionHandler(ACTIONS.HARVEST, "action"),
    ActionHandler(ACTIONS.EAT, "eat"),
}

local events =
{
    EventHandler("locomote", function(inst)
        if inst.components.locomotor:WantsToMoveForward() then
            if inst.sg:HasStateTag("idle") then
                inst.sg.statemem.walking = true
                inst.sg:GoToState("walk_start")
            end
        elseif inst.sg:HasStateTag("moving") then
            inst.sg.statemem.walking = true
            inst.sg:GoToState("walk_stop")
        end
    end),
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnFallInVoid(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnSleep(),
    EventHandler("doattack", doattackfn),
    EventHandler("attacked", onattackedfn),
    EventHandler("dolure", function(inst)
        inst.sg:GoToState("lure_enter")
    end),
}

local function kill_loop_sound(inst)
    if inst.loop_sound then
        inst.SoundEmitter:KillSound("custom_loop")
    end
end

local states =
{
    State{
        name = "idle_enter",
		tags = { "idle", "invisible", "dirt", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("mound")
            inst.SoundEmitter:KillAllSounds()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "idle",
		tags = { "idle", "invisible", "dirt", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("mound_idle", true)
            inst.SoundEmitter:KillAllSounds()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "idle_exit",
		tags = { "idle", "invisible", "dirt", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("mound_out")
            inst.SoundEmitter:KillAllSounds()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "action",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("pickup")
            inst.SoundEmitter:KillAllSounds()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/emerge")

            if inst.loop_sound then
                inst.SoundEmitter:PlaySound(inst.loop_sound, "custom_loop")
            end
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, function(inst)
                inst.sg:AddStateTag("nohit")
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/bite")
                inst:PerformBufferedAction()
            end),
			FrameEvent(19, function(inst)
				inst.sg:AddStateTag("noelectrocute")
			end),
            TimeEvent(20 * FRAMES, ExtinguishFire),
            SoundFrameEvent(23, "dontstarve/creatures/worm/retract"),
            FrameEvent(38, kill_loop_sound),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = kill_loop_sound,
    },

    State{
        name = "eat",

        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/emerge")

            if inst.loop_sound then
                inst.SoundEmitter:PlaySound("rifts4/rope_bridge/shake_lp", "custom_loop")
            end
        end,

        timeline =
        {
            FrameEvent(19, kill_loop_sound),
            SoundFrameEvent(20, "dontstarve/creatures/worm/eat"),
            SoundFrameEvent(30, "dontstarve/creatures/worm/eat"),
            SoundFrameEvent(40, "dontstarve/creatures/worm/eat"),
            TimeEvent(60 * FRAMES, function(inst)
                inst.sg:AddStateTag("nohit")
                inst:PerformBufferedAction()
            end),
			FrameEvent(65, function(inst)
				inst.sg:AddStateTag("noelectrocute")
			end),
            TimeEvent(66 * FRAMES, ExtinguishFire),
            SoundFrameEvent(75, "dontstarve/creatures/worm/retract"),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = kill_loop_sound,
    },

    State{
        name = "taunt",
        tags = { "taunting" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/emerge")
            inst.AnimState:PlayAnimation("taunt")

            if inst.loop_sound then
                inst.SoundEmitter:PlaySound(inst.loop_sound, "custom_loop")
            end
        end,

        timeline =
        {
            TimeEvent(20 * FRAMES, function(inst)
                inst.sg:AddStateTag("nohit")
            end),
			FrameEvent(26, function(inst)
				inst.sg:AddStateTag("noelectrocute")
			end),
            TimeEvent(27 * FRAMES, ExtinguishFire),
            SoundFrameEvent(30, "dontstarve/creatures/worm/retract"),
            FrameEvent(49, kill_loop_sound),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = kill_loop_sound,
    },

    State{
        name = "attack_pre",
		tags = { "canrotate", "invisible", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk_pre")
            inst:turnofflight()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("attack")
            end),
        },
    },

    State{
        name = "attack",
        tags = { "attack", "nohit" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
            inst.components.combat:StartAttack()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/emerge")
        end,

        timeline =
        {
            TimeEvent(25 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/bite")
                inst.components.combat:DoAttack()
            end),
			FrameEvent(35, function(inst)
				inst.sg:AddStateTag("noelectrocute")
			end),
            TimeEvent(36 * FRAMES, ExtinguishFire),
            SoundFrameEvent(40, "dontstarve/creatures/worm/retract"),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death")
            RemovePhysicsColliders(inst)
            inst.Physics:Stop()
            inst.components.lootdropper:DropLoot()
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/retract")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/death")
            end),
            FrameEvent(18, function(inst)
                if inst.loop_sound then
                    inst.SoundEmitter:PlaySound(inst.loop_sound, "custom_loop")
                end
            end),
            FrameEvent(32, kill_loop_sound),
            FrameEvent(32, ExtinguishFire),
        },

        onexit = kill_loop_sound,
    },

    State{
        name = "hit",
        tags = { "busy", "hit" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
        end,

        timeline =
        {
            SoundFrameEvent(1, "dontstarve/creatures/worm/hurt"),
            FrameEvent(14, function(inst)
                if inst.loop_sound then
                    inst.SoundEmitter:PlaySound(inst.loop_sound, "custom_loop")
                end
            end),
			FrameEvent(15, function(inst)
				inst.sg:AddStateTag("noelectrocute")
			end),
            TimeEvent(16 * FRAMES, ExtinguishFire),
            SoundFrameEvent(20, "dontstarve/creatures/worm/retract"),
            FrameEvent(36, kill_loop_sound),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = kill_loop_sound,
    },

    State{
        name = "walk_start",
		tags = { "moving", "canrotate", "dirt", "invisible", "noelectrocute" },

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("walk_pre")
            if not inst.SoundEmitter:PlayingSound("walkloop") then
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/move", "walkloop")
            end
        end,

        events =
        {
        EventHandler("animover", function(inst)
                inst.sg.statemem.walking = true
                inst.sg:GoToState("walk")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.walking then
                inst.SoundEmitter:KillSound("walkloop")
            end
        end,
    },

    State{
        name = "walk",
		tags = { "moving", "canrotate", "dirt", "invisible", "noelectrocute" },

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("walk_loop")
            if not inst.SoundEmitter:PlayingSound("walkloop") then
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/move", "walkloop")
            end
        end,

        timeline =
        {
            TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/dirt") end),
            TimeEvent(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/dirt") end),
            TimeEvent(20 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/dirt") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.walking = true
                inst.sg:GoToState("walk")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.walking then
                inst.SoundEmitter:KillSound("walkloop")
            end
        end,
    },

    State{
        name = "walk_stop",
		tags = { "canrotate", "dirt", "invisible", "noelectrocute" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("walk_pst")
            if not inst.SoundEmitter:PlayingSound("walkloop") then
                inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/move", "walkloop")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle_enter")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.walking then
                inst.SoundEmitter:KillSound("walkloop")
            end
        end,
    },

    State{
        name = "lure_enter",
		tags = { "invisible", "lure", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("lure_enter")
            inst.SoundEmitter:KillAllSounds()
            ChangeToLure(inst)
            inst:turnonlight()
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/worm/lure_emerge") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.islure = true
                inst.sg:GoToState("lure", true)
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.islure then
                ChangeToWorm(inst)
            end
        end,
    },

    State{
        name = "lure",
		tags = { "invisible", "lure", "noelectrocute" },

        onenter = function(inst, islure)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_loop", true)
            inst.SoundEmitter:KillAllSounds()
            if not islure then
                ChangeToLure(inst)
            end
            inst.sg:SetTimeout(GetRandomWithVariance(TUNING.WORM_LURE_TIME, TUNING.WORM_LURE_VARIANCE))
        end,

        ontimeout = function(inst)
            inst.sg.statemem.islure = true
            inst.sg:GoToState("lure_exit", true)
        end,

        onexit = function(inst)
            inst.lastluretime = GetTime()
            if not inst.sg.statemem.islure then
                ChangeToWorm(inst)
            end
        end,
    },

    State{
        name = "lure_exit",
		tags = { "invisible", "lure", "noelectrocute" },

        onenter = function(inst, islure)
            inst.AnimState:PlayAnimation("lure_exit")
            inst.SoundEmitter:KillAllSounds()
            if not islure then
                ChangeToLure(inst)
            end
            inst:turnofflight()
        end,

        timeline =
        {
            SoundTimeEvent(FRAMES, "dontstarve/creatures/worm/lure_retract"),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle_enter")
            end),
        },

        onexit = ChangeToWorm,
    },
}

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddVoidFallStates(states, {voiddrop = "hit",})

return StateGraph("worm", states, events, "idle", actionhandlers)
