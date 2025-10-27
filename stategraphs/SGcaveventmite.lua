require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.EAT, "eat"),
    ActionHandler(ACTIONS.GOHOME, "eat"),
}

local NO_TAGS = { "playerghost", "INLIMBO", "flight", "invisible" }
for k, v in pairs(FUELTYPE) do
    table.insert(NO_TAGS, v.."_fueled")
end
local BLOW_ONEOF_TAGS = { "_health", "canlight", "freezable" }

local function GetHeatRate(inst)
    local wet_multiplier = inst:GetWetMultiplier()
    local coldness = inst.components.freezable and inst.components.freezable.coldness
    local world_temp = GetLocalTemperature(inst)
    return (
        (world_temp < 10 or coldness >= 0.5) and TUNING.CAVE_MITE_BLOW_HEAT_RATE.COLD or
        world_temp > 60 and TUNING.CAVE_MITE_BLOW_HEAT_RATE.HOT or
        TUNING.CAVE_MITE_BLOW_HEAT_RATE.NORMAL
    ) * (1 - wet_multiplier)
end

local function DoBlowUpdate(inst, dt)
    if not inst.sg.statemem.blowing then
        return
    end

    local heatrate = GetHeatRate(inst) * dt
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, TUNING.CAVE_MITE_BLOW_DISTANCE, nil, NO_TAGS, BLOW_ONEOF_TAGS)) do
        if v:IsValid() and not (v.components.health ~= nil and v.components.health:IsDead()) then
            x, y, z = v.Transform:GetWorldPosition()
            local heatfactor = 1 - math.max(0, inst:GetDistanceSqToInst(v) - TUNING.CAVE_MITE_BLOW_DISTANCE_SQ_MIN) / TUNING.CAVE_MITE_BLOW_DISTANCE_SQ
            local heatmult = heatfactor * heatrate
            if v.components.freezable ~= nil then
                if v.components.freezable:IsFrozen() then
                    v.components.freezable:Unfreeze()
                elseif v.components.freezable.coldness > 0 then
                    v.components.freezable:AddColdness(-1 * heatmult)
                end
            end
            if v.components.burnable ~= nil and
                v.components.fueled == nil and
                v.components.health ~= nil then
                v.components.burnable:ExtendBurning()
            end
            if v.components.temperature ~= nil then
                local maxtemp = v.components.temperature:GetMax()
                local curtemp = v.components.temperature:GetCurrent()
                if maxtemp > curtemp then
                    v.components.temperature:DoDelta(heatmult)
                end
            end
        end
    end
end

local FINDMIASMA_TAGS = {"FX"}
local function CheckSpawnMiasma(inst)
    if inst.components.planarentity ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local miasma_exists = FindEntity(inst, 2, function(guy) return guy.prefab == "miasma_cloud" end, FINDMIASMA_TAGS)
        if miasma_exists == nil then
            local cloud = SpawnPrefab("miasma_cloud")
            cloud.Transform:SetPosition(x, y, z)
        end
    end
end

local events =
{
    CommonHandlers.OnHop(),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    CommonHandlers.OnDeath(),

	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("electrocute") then
                if inst.sg:HasStateTag("shield") and not inst.sg:HasStateTag("shield_end") then
                    if not inst.sg:HasStateTag("vent") then
                        inst.sg:GoToState("shield_hit")
                    end
				elseif not inst.sg:HasAnyStateTag("attack", "moving", "shield", "busy") or inst.sg:HasStateTag("caninterrupt") then
					inst.sg:GoToState("hit") -- can still attack
				end
			end
        end
    end),
    EventHandler("doattack", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            if not inst.blowtime or GetTime() - inst.blowtime >= TUNING.CAVE_MITE_BLOW_COOLDOWN then
                inst.sg:GoToState("blow_attack")
            else
                inst.sg:GoToState("attack", data.target)
            end
        end
    end),

    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("busy") then
            local is_moving = inst.sg:HasStateTag("moving")
            local wants_to_move = inst.components.locomotor:WantsToMoveForward()
            if not inst.sg:HasStateTag("attack") and is_moving ~= wants_to_move then
                if wants_to_move then
                    inst.sg:GoToState("premoving")
                else
                    inst.sg:GoToState("idle", "walk_pst")
                end
            end
        end
    end),

    EventHandler("spawn", function(inst)
        if not inst.components.health:IsDead() and
				((inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute")) or not inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("spawn")
        end
    end),

    EventHandler("entershield", function(inst)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("shield_pre") 
        end
    end),
    EventHandler("exitshield", function(inst)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("shield_end")
        end
    end),
}

local states =
{
    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/die")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()

            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,

        timeline =
        {
            FrameEvent(1, function(inst) 
                CheckSpawnMiasma(inst)
                inst.sg.statemem.blowing = true
            end),
            FrameEvent(24, function(inst) inst.sg.statemem.blowing = nil end),
        },

        onupdate = DoBlowUpdate,
    },

    State{
        name = "premoving",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("walk_pre")
        end,

        timeline=
        {
            FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/walk") end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("moving") end),
        },
    },

    State{
        name = "moving",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PushAnimation("walk_loop")
        end,

        timeline=
        {
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/walk") end),
            FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/walk") end),
            FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/walk") end),
            FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/walk") end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("moving") end),
        },
    },

    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, start_anim)
            inst.Physics:Stop()
            if math.random() < 0.3 then
                inst.sg:SetTimeout(math.random()*2 + 4)
            end

            if start_anim then
                inst.AnimState:PlayAnimation(start_anim)
                inst.AnimState:PushAnimation("idle", true)
            else
                inst.AnimState:PlayAnimation("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("taunt")
        end,
    },

    State{
        name = "eat",
        tags = {"busy", "caninterrupt"},

        onenter = function(inst, forced)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat_pre")
            inst.sg.statemem.forced = forced
            inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/eat", "eating")
        end,

        onexit = function(inst, new_state)
            if new_state ~= "eat_loop" then
                inst.SoundEmitter:KillSound("eating")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                local state = (inst:PerformBufferedAction() or inst.sg.statemem.forced) and "eat_loop" or "idle"
                inst.sg:GoToState(state)
            end),
        },
    },

    State{
        name = "eat_loop",
        tags = {"busy", "caninterrupt"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat_loop", true)
            inst.sg:SetTimeout(1+math.random()*1)
        end,

        onexit = function(inst, new_state)
            if new_state ~= "eat_loop" then
                inst.SoundEmitter:KillSound("eating")
            end
        end,

        ontimeout = function(inst)
            inst.SoundEmitter:KillSound("eating")
            inst.sg:GoToState("idle", "eat_pst")
        end,
    },

    State{
        name = "taunt",
        tags = { "busy", "caninterrupt" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
            inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/scream")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            inst.Physics:Stop()
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("atk")
            inst.sg.statemem.target = target
        end,

        timeline =
        {
            FrameEvent(10, function(inst)
                inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/Attack")
            end),
            FrameEvent(20, function(inst)
                inst.sg.statemem.blowing = true
                inst.components.combat:DoAttack(inst.sg.statemem.target)
            end),
            FrameEvent(27, function(inst) inst.sg.statemem.blowing = nil end),
        },

        onupdate = DoBlowUpdate,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "blow_attack",
        tags = { "blowing", "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("blow")
            inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/spew_pre_vo")
        end,

        onupdate = DoBlowUpdate,

        timeline =
        {
            FrameEvent(29, function(inst)
                CheckSpawnMiasma(inst)
                inst.sg.statemem.blowing = true
                inst.blowtime = GetTime()
                inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/spew_1_mite")
            end),
            FrameEvent(49, function(inst)
                inst.sg:AddStateTag("caninterrupt")
            end),
            FrameEvent(70, function(inst)
                inst.sg.statemem.blowing = nil
            end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

    State{
        name = "hit",
        tags = { "busy", "caninterrupt" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/hit")
            inst.Physics:Stop()
        end,

        timeline =
        {
            FrameEvent(10, function(inst)
                inst.sg:RemoveStateTag("busy")
                inst.sg:RemoveStateTag("caninterrupt")
            end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

    State{
        name = "shield_pre",
        tags = { "busy", },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("mite_disappear")
        end,

        onexit = function(inst)
            inst:SetShield(false)
            inst:SetCharacterPhysics()
        end,

        timeline =
        {
            FrameEvent(22, function(inst)
                inst:SetShield(true)
                inst:SetVentPhysics()
                inst.sg:AddStateTag("shield")
                inst.sg:AddStateTag("noelectrocute")
            end),
            FrameEvent(14, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/disappear_vo_f14") end),
            FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/disappear_f22") end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("shield_vent") end),
        },
    },

    State{
        name = "shield",
        tags = { "busy", "shield", "noelectrocute" },

        onenter = function(inst)
            inst:SetShield(true)
            inst:SetVentPhysics()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("mite_vent_idle", false)
            inst.sg:SetTimeout(15 + 5 * math.random())
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("shield_vent")
        end,

        onexit = function(inst)
            inst:SetCharacterPhysics()
            inst:SetShield(false)
        end,
    },

    State{
        name = "shield_vent",
        tags = { "busy", "shield", "noelectrocute", "vent" },

        onenter = function(inst)
            inst:SetShield(true)
            inst:SetVentPhysics()
            CheckSpawnMiasma(inst)
            inst.sg.statemem.blowing = true
            inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/spew_1_mite")
            inst.AnimState:PlayAnimation("mite_vent_active")
            inst.AnimState:PushAnimation("mite_vent_idle", false)
        end,

        onexit = function(inst)
            inst:SetShield(false)
            inst:SetCharacterPhysics()
        end,

        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("shield") end),
        },

        timeline =
        {
            FrameEvent(44, function(inst) inst.sg.statemem.blowing = nil end),
            FrameEvent(77, function(inst) inst.sg:RemoveStateTag("vent") end),
        },

        onupdate = DoBlowUpdate,
    },

    State{
        name = "shield_hit",
        tags = { "busy", "hit", "shield", "noelectrocute", "vent" },

        onenter = function(inst)
            inst:SetShield(true)
            inst:SetVentPhysics()
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("mite_vent_hit")
        end,
        
        onexit = function(inst)
            inst:SetShield(false)
            inst:SetCharacterPhysics()
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("shield_vent") end),
        },
    },

    State{
        name = "shield_end",
        tags = { "busy", "shield", "shield_end", "noelectrocute" },

        onenter = function(inst)
            inst:SetShield(true)
            inst:SetVentPhysics()
            inst.AnimState:PlayAnimation("mite_appear")
        end,

        timeline =
        {
            FrameEvent(17, function(inst)
                inst:SetShield(false)
                inst:SetCharacterPhysics()
                inst.sg:RemoveStateTag("shield")
                inst.sg:RemoveStateTag("noelectrocute")

                if inst.components.timer:TimerExists("shield_cooldown") then
                    inst.components.timer:SetTimeLeft("shield_cooldown", TUNING.CAVE_MITE_SHIELD_COOLDOWN + TUNING.CAVE_MITE_SHIELD_COOLDOWN_VARIANCE * math.random())
                else
                    inst.components.timer:StartTimer("shield_cooldown", TUNING.CAVE_MITE_SHIELD_COOLDOWN + TUNING.CAVE_MITE_SHIELD_COOLDOWN_VARIANCE * math.random())
                end
            end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

    State{
        name = "spawn",
		tags = { "waking", "busy", "noattack", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("vent_pre")
            inst.AnimState:PushAnimation("mite_appear", false)
        end,

        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline=
        {
            FrameEvent(1, function(inst)
                inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/appear_f1")
            end),
            FrameEvent(25, function(inst)
                inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/appear_vo_f25")
                inst.sg:RemoveStateTag("noattack")
            end),
        },
    },
}

CommonStates.AddSleepStates(states,
{
    starttimeline = {
        FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/fallAsleep") end ),
    },
    sleeptimeline =
    {
        FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/sleeping") end ),
    },
    waketimeline = {
        FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts6/creatures/rockspider/wakeUp") end ),
    },
})

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
--CommonStates.AddHopStates(states, true, { pre = "boat_jump_pre", loop = "boat_jump", pst = "boat_jump_pst"})
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("caveventmite", states, events, "idle", actionhandlers)