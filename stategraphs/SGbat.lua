require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, function(inst)
        local ba = inst:GetBufferedAction()
        if ba and ba.target and ba.target:HasTag("sinkhole") then
            return "flyaway"
        else
            return "action"
        end
    end),
    ActionHandler(ACTIONS.EAT, function(inst)
        local ba = inst:GetBufferedAction()
        if ba and ba.target and ba.target.prefab == "nitre" then
            return "chew_ground"
        else
            return "eat_enter"
        end
    end),
    ActionHandler(ACTIONS.PICKUP, "eat_enter"),
    ActionHandler(ACTIONS.STEAL, "eat_enter")
}

local events=
{
    EventHandler("fly_back", function(inst, data)
        inst.sg:GoToState("flyback")
    end),
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnSleepEx(),
    CommonHandlers.OnWakeEx(),
}

local function DoChewSound(inst)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") -- Always flap.

    if not inst.sg.statemem.chewsounds then
        return
    end

    inst.sg.statemem.chewsounds = inst.sg.statemem.chewsounds - 1
    if inst.sg.statemem.chewsounds <= 0 then
        inst.sg.statemem.chewsounds = nil
        return
    end

    inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/chew")
end

local states =
{
    State{

        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("fly_loop", true)
            else
                inst.AnimState:PlayAnimation("fly_loop", true)
            end
        end,

        timeline =
        {
		    TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "action",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("fly_loop", true)
            inst:PerformBufferedAction()
        end,
        events=
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("idle")
            end),
        }
    },

    State{
        name = "flyaway",
		tags = { "flight", "busy", "noelectrocute" },
        onenter = function(inst)
            inst.Physics:Stop()

            inst.DynamicShadow:Enable(false)
            inst.components.health:SetInvincible(true)

            inst.AnimState:PlayAnimation("fly_away_pre")
            inst.AnimState:PushAnimation("fly_away_loop", true)

            inst.Physics:SetMotorVel(0,10+math.random()*2,0)
        end,

        onupdate = function(inst)
            inst.Physics:SetMotorVel(0,10+math.random()*2,0)
        end,

        timeline = {
            TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(23*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(33*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(41*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(51*FRAMES, function(inst) inst:PerformBufferedAction() end ),
        },

    },

    State{
        name = "flyback",
		tags = { "flight", "busy", "noelectrocute" },
        onenter = function(inst)
            inst.Physics:Stop()

            inst.DynamicShadow:Enable(false)
            inst.components.health:SetInvincible(true)

            inst.AnimState:PlayAnimation("fly_back_loop",true)

            local x,y,z = inst.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x,15,z)
            inst.Physics:SetMotorVel(0,-10+math.random()*2,0)
        end,

        onupdate= function(inst)
            inst.Physics:SetMotorVel(0,-10+math.random()*2,0)
            local pt = Point(inst.Transform:GetWorldPosition())

            if pt.y <= .1 or inst:IsAsleep() then
                pt.y = 0
                inst.Physics:Stop()
                inst.Physics:Teleport(pt.x,pt.y,pt.z)
                inst.DynamicShadow:Enable(true)
                inst.components.health:SetInvincible(false)
                inst.sg:GoToState("idle", "fly_back_pst")
            end
        end,

        timeline = {
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(24*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(34*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(41*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        },

    },

    State{
        name = "taunt",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
        end,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/taunt") end ),
            TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(43*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "eat_enter",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat", false)
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
            TimeEvent(9*FRAMES, function(inst) inst:PerformBufferedAction()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/bite") end ), --take food
            TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)
        },
    },

    State{
        name = "eat_loop",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("eat_loop", true)
            inst.sg:SetTimeout(1+math.random()*2)
        end,

        ontimeout= function(inst)
            inst.lastmeal = GetTime()
            inst:PerformBufferedAction()
            inst.sg:GoToState("idle")
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/chew") end ),
            TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/chew") end ),
        },

        events =
        {
            EventHandler("attacked", function(inst) inst.components.inventory:DropEverything() inst.sg:GoToState("idle") end) --drop food
        },
    },

    State{
        name = "chew_ground",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("chew_pre", false)

            local chews = math.min(data and data.chews or math.random(14, 18), 18)
            for i = 1, chews do
                inst.AnimState:PushAnimation("chew_loop", false)
            end

            inst.AnimState:PushAnimation("chew_pst", false)

            inst.sg.statemem.chewsounds = chews
        end,

        onexit = function(inst)

        end,

        timeline =
        {
            TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end),
            TimeEvent((12 + 9 * 0)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 1)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 2)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 3)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 4)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 5)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 6)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 7)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 8)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 9)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 10)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 11)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 12)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 13)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 14)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 15)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 16)*FRAMES, DoChewSound),
            TimeEvent((12 + 9 * 17)*FRAMES, DoChewSound),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.lastmeal = GetTime()
                inst:PerformBufferedAction()
                inst.sg:GoToState("idle")
            end),
            EventHandler("attacked", function(inst) inst.components.inventory:DropEverything() inst.sg:GoToState("idle") end), --drop food
        },
    },
}

local walkanims =
{
    startwalk = "fly_loop",
    walk = "fly_loop",
    stopwalk = "fly_loop",
}

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {
        TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
    },

	walktimeline =
    {
        TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
	},

    endtimeline =
    {
        TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
    },

}, walkanims, true)


CommonStates.AddSleepExStates(states,
{
    starttimeline =
    {
        TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
    },

    sleeptimeline =
    {
        TimeEvent(23*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/sleep") end),
    },

    endtimeline =
    {
        TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
    },
},
{
    onsleeping = LandFlyingCreature,
    onexitsleeping = RaiseFlyingCreature,
})

CommonStates.AddCombatStates(states,
{
    attacktimeline =
    {

        TimeEvent(8* FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/bite") end),
        TimeEvent(11*FRAMES, function(inst)
            inst.components.combat:DoAttack()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap")
        end),
    },

    hittimeline =
    {
        TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/hurt") end),
        TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
    },

    deathtimeline =
    {
        TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/death") end),
        TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/flap") end ),
        TimeEvent(15*FRAMES, LandFlyingCreature),
    },
})

CommonStates.AddFrozenStates(states, LandFlyingCreature, RaiseFlyingCreature)
CommonStates.AddElectrocuteStates(states)

return StateGraph("bat", states, events, "idle", actionhandlers)
