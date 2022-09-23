require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, "action"),
    ActionHandler(ACTIONS.PICKUP, "action"),
    ActionHandler(ACTIONS.STEAL, "action"),
    ActionHandler(ACTIONS.PICK, "action"),
    ActionHandler(ACTIONS.HARVEST, "action"),
    ActionHandler(ACTIONS.ATTACK, "throw"),
    ActionHandler(ACTIONS.EAT, "eat"),
    ActionHandler(ACTIONS.ROW, "row"),
    ActionHandler(ACTIONS.REPAIR_LEAK, "action"),
    ActionHandler(ACTIONS.ABANDON, "dive"),
}

local events=
{
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnAttacked(1),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnSleep(),
    EventHandler("doattack", function(inst, data)
        if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack")
        end
    end),
    EventHandler("command", function(inst, data)
        if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
          inst.sg:GoToState("taunt")
        end
    end),
    EventHandler("onsink", function(inst, data)
        if (inst.components.health == nil or not inst.components.health:IsDead()) and not inst.sg:HasStateTag("drowning") and (inst.components.drownable ~= nil and inst.components.drownable:ShouldDrown()) then
                SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
                inst:dropInventory()
                inst:Remove()
            end
    end),
}

local states =
{
    State{

        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle_loop", true)
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end
            inst.SoundEmitter:PlaySound("monkeyisland/primemate/idle")
        end,

        timeline =
        {

        },

        events=
        {
            EventHandler("animover", function(inst)

                if inst.components.combat.target and
                    inst.components.combat.target:HasTag("player") then

                    if math.random() < 0.05 then
                        inst.sg:GoToState("taunt")
                        return
                    end
                end

                inst.sg:GoToState("idle")

            end),
        },
    },

    State{

        name = "action",
        tags = {"busy"},
        onenter = function(inst, playanim)
            inst.components.timer:StartTimer("patch_boat_Cooldown",3)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("pig_pickup", true)
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
        end,
        onexit = function(inst)
            inst.SoundEmitter:KillSound("make")
        end,
        events=
        {
            EventHandler("animover", function (inst)
                inst:PerformBufferedAction()
                inst.sg:GoToState("idle")
            end),
        }
    },


    State{

        name = "row",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("row_pre",false)
            inst.AnimState:PushAnimation("row_loop",false)
            inst.AnimState:PushAnimation("row_pst",false)
           -- inst.sg:SetTimeout(4)
        end,

        timeline =
        {

            TimeEvent(8*FRAMES, function(inst)
               inst:PerformBufferedAction()
               inst.SoundEmitter:PlaySound("monkeyisland/primemate/row")
            end),
            TimeEvent(13*FRAMES, function(inst)
               inst.SoundEmitter:PlaySound("monkeyisland/primemate/row")
            end),     
        },

        ontimeout = function(inst)
        
            inst:PerformBufferedAction()
            inst.sg:GoToState("idle")
        end,

        events=
        {
            EventHandler("animqueueover", function (inst)
                inst.sg:GoToState("idle")
            end),
        }
    },

    State{

        name = "eat",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat", true)
            inst.SoundEmitter:PlaySound("monkeyisland/primemate/eat")
        end,

        onexit = function(inst)
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
        name = "taunt",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_angry")
            inst.components.talker:Say(STRINGS["MONKEY_COMMAND"][math.random(1,#STRINGS["MONKEY_COMMAND"])])
            inst.SoundEmitter:PlaySound("monkeyisland/primemate/taunt")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "dive",
        tags = {"busy", "nomorph", },

        onenter = function(inst)
            local platform = inst:GetCurrentPlatform()
            if platform then
                local pt = Vector3(inst.Transform:GetWorldPosition())
                local angle = platform:GetAngleToPoint(pt)
                inst.Transform:SetRotation(angle)
            end

            inst.AnimState:PlayAnimation("dive")
            inst.Physics:Stop()
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
        end,

        timeline =
        {
            TimeEvent(10*FRAMES, function(inst)

                inst.sg.statemem.collisionmask = inst.Physics:GetCollisionMask()
                inst.Physics:SetCollisionMask(COLLISION.GROUND)
                if not TheWorld.ismastersim then
                    inst.Physics:SetLocalCollisionMask(COLLISION.GROUND)
                end

                inst.Physics:SetMotorVelOverride(5,0,0)
            end),

            TimeEvent(30*FRAMES, function(inst)
                
            end),
        },

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            
            inst.Physics:ClearLocalCollisionMask()
            if inst.sg.statemem.collisionmask ~= nil then
                inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
            end   
        end,

        events=
        {
            EventHandler("animover", function(inst)
                if TheWorld.Map:IsVisualGroundAtPoint(inst.Transform:GetWorldPosition()) or inst:GetCurrentPlatform() then
                    inst.sg:GoToState("dive_pst_land")
                else
                    SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())

                    if TheWorld.components.piratespawner then
                        TheWorld.components.piratespawner:StashLoot(inst)
                    end
                    inst:Remove()
                end
            end),
        },
    },

    State{
        name = "dive_pst_land",
        tags = {"busy"},

        onenter = function(inst)
            if inst.components.locomotor then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("dive_pst_land")
            PlayFootstep(inst)
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {

    },

	walktimeline =
    {
        TimeEvent(0, PlayFootstep),
        TimeEvent(12 * FRAMES, PlayFootstep),
	},

    endtimeline =
    {

    },
})


CommonStates.AddSleepStates(states,
{
    starttimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("monkeyisland/powdermonkey/sleep_pre") 
        end),
    },

    sleeptimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("monkeyisland/powdermonkey/sleep_lp", "sleep_lp") 
        end),
    },

    endtimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("monkeyisland/powdermonkey/sleep_pst") 
        end),
    },
},{
    onsleepexit = function(inst)
        inst.SoundEmitter:KillSound("sleep_lp")
    end,
})

CommonStates.AddCombatStates(states,
{
    attacktimeline =
    {
        TimeEvent(9*FRAMES, function(inst)
            inst.components.combat:DoAttack()
            --inst.SoundEmitter:PlaySound("dontstarve/creatures/monkey"..inst.soundtype.."/attack")
        end),
    },

    hittimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("monkeyisland/primemate/hit") 
        end),
    },

    deathtimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("monkeyisland/primemate/death")
        end),
    },
},nil,{attackanimfn= function(inst) 
    if inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS).components.weapon then
        return "atk_object"
    end
    return nil
end})

CommonStates.AddFrozenStates(states)


return StateGraph("primemate", states, events, "idle", actionhandlers)
