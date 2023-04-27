require("stategraphs/commonstates")

local actionhandlers =
{
}

local events =
{
    CommonHandlers.OnLocomote(false, true),
}


local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "spawn",
        tags = {"busy", "noattack"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("spawn")
            inst.Physics:SetMotorVelOverride(4, 0, 0)
            inst.SoundEmitter:PlaySound("rifts/lunarthrall/gestalt_vocalization")
        end,

        timeline=
        {
            --TimeEvent(5*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/rabbit/hop") end ),
        },

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "infest",
        tags = {"busy", "noattack"},

        onenter = function(inst)
            inst.AnimState:SetFinalOffset(3)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("infest")
            inst.SoundEmitter:PlaySound("rifts/lunarthrall/gestalt_infest")
            inst.persists = false
        end,

        timeline=
        {
            TimeEvent(25*FRAMES, function(inst)
                if inst.plant_target and inst.plant_target:IsValid() then
                    TheWorld.components.lunarthrall_plantspawner:SpawnPlant(inst.plant_target)
                end
            end ),
        },

        events =
        {
            EventHandler("animover", function(inst) inst:Remove() end),
        },

        onexit = function(inst)
        end,
    },

    
}

local function SpawnTrail(inst)
	if not inst._notrail then
		local trail = SpawnPrefab("gestalt_trail")
		trail.Transform:SetPosition(inst.Transform:GetWorldPosition())
		trail.Transform:SetRotation(inst.Transform:GetRotation())
	end
end

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("rifts/lunarthrall/gestalt_vocalization") end),
    },
    walktimeline =
    {
        TimeEvent(0*FRAMES, SpawnTrail),
    },
    endtimeline =
    {
    },
}
, nil, nil, true)


return StateGraph("lunarthrall_plant_gestalt", states, events, "idle", actionhandlers)
