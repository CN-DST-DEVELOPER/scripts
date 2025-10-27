require("stategraphs/commonstates")

local actionhandlers = {
}

local events = {
    CommonHandlers.OnLocomote(false, true),

    EventHandler("spawned", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("spawned")
        end
    end),

    EventHandler("death", function(inst)
        inst.sg:GoToState("death")
    end),

    EventHandler("doattack", function(inst) -- Melee.
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack")
        end
    end),

    EventHandler("doattack_mid", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack_mid")
        end
    end),

    EventHandler("doattack_far", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack_far")
        end
    end),

    EventHandler("attacked", function(inst)
        if not (inst.sg:HasStateTag("busy")) and not inst.components.health:IsDead() and inst.sg:HasStateTag("idle") then
            inst.sg:GoToState("hit")
        end
    end),

    EventHandler("teleport", function(inst, data)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("teleport", data)
        end
    end),
}

local INVALID_ATTACK_STATE_TAGS = {"bedroll", "knockout", "sleeping", "tent", "waking"} -- NOTE: these are stategraph tags!
local function IsValidAttackTarget(inst, target, x, z, rangesq)
    local dsq = target:GetDistanceSqToPoint(x, 0, z)
    return dsq < rangesq
        and not (target.components.health and target.components.health:IsDead())
        and not (target.sg and target.sg:HasAnyStateTag(INVALID_ATTACK_STATE_TAGS))
        and not target:HasAnyTag("brightmare", "brightmareboss")
        and inst.components.combat:CanTarget(target)
        , dsq
end

local function FindAoEChargeAttackTarget(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local rangesq = TUNING.GESTALT_ATTACK_HIT_RANGE_SQ

    local target = inst.components.combat.target
    if target and IsValidAttackTarget(inst, target, x, z, rangesq) then
        return target
    end

    target = nil
    for _, player in pairs(AllPlayers) do
        local isvalid, dsq = IsValidAttackTarget(inst, player, x, z, rangesq)
        if isvalid then
            rangesq = dsq
            target = player
        end
    end
    return target
end

local function DoAoEChargeAttackHitOn(inst, target)
    if target.components.sanity then
        target.components.sanity:DoDelta(TUNING.GESTALT_ATTACK_DAMAGE_SANITY)
    end

    inst.components.combat:DoAttack(target)
    if not (target.components.health and target.components.health:IsDead()) then
        local grogginess = target.components.grogginess
        if grogginess then
            grogginess:AddGrogginess(TUNING.GESTALT_EVOLVED_ATTACK_DAMAGE_GROGGINESS, TUNING.GESTALT_EVOLVED_ATTACK_DAMAGE_KO_TIME)
        end
    end
end

local states = {
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/idle_LP", "idle_lp")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("idle_lp")
        end,
    },

    State{
        name = "spawned",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("emerge2")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/emerge_vocals")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "emerge",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("emerge")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/emerge_vocals")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = {"busy", "noattack"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("mutate")
            
            local owner = inst.components.follower and inst.components.follower.leader or nil
            if owner and owner.components.petleash then
                owner.components.petleash:DetachPet(inst)
            end
            inst.persists = false

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/mutate")

            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,

        events = {
            EventHandler("animover", function(inst)
                inst:Remove()
            end),
        },

        onexit = function(inst)
            inst:Remove()
        end,
    },

    -- Melee attack
    State{
        name = "attack",
        tags = { "busy", "attack", "jumping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("attack")

            inst.components.locomotor:Stop()
            if inst.components.combat.target ~= nil then
                inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end
            inst.components.combat:StartAttack()

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/attack_vocals")
        end,

        timeline = {
            FrameEvent(15, function(inst)
                inst.Physics:SetMotorVelOverride(20, 0, 0)
                inst.sg.statemem.enable_attack = true
            end),
            FrameEvent(25, function(inst)
                inst.sg.statemem.enable_attack = false
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
            end),
        },

        onupdate = function(inst)
            if inst.sg.statemem.enable_attack then
                local target = FindAoEChargeAttackTarget(inst)
                if target ~= nil then
                    DoAoEChargeAttackHitOn(inst, target)
                    inst.sg.statemem.enable_attack = false
                end
            end
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
        end,
    },

    -- Mid range attack
    State{
        name = "attack_mid",
        tags = { "busy", "attack" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("summon")

            inst.components.locomotor:Stop()
            if inst.components.combat.target ~= nil then
                inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/attack_vocals")
        end,

        timeline = {
            FrameEvent(8, function(inst)
                inst:DoAttack_Mid()
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    -- Far range attack
    State{
        name = "attack_far",
        tags = { "busy", "attack" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("explode")

            inst.components.locomotor:Stop()
            if inst.components.combat.target ~= nil then
                inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end
            inst.components.combat:StartAttack()

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/attack_vocals")
        end,

        timeline = {
            FrameEvent(24, function(inst)
                inst:DoAttack_Far()
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "hit" }, -- Intentionally not busy so it can attack back.

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "teleport",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst, data)
            inst.sg.statemem.data = data
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("melt")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/melt")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("teleporting", inst.sg.statemem.data)
            end),
        },
    },

    State{
        name = "teleporting",
        tags = { "busy", "noattack", "hidden", "invisible" },

        onenter = function(inst, data)
            inst.sg.statemem.data = data
            inst.components.locomotor:Stop()
            inst:Hide()

            inst.sg:SetTimeout(TUNING.GESTALT_EVOLVED_TELEPORT_TIME_INVISIBLE)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("emerge", inst.sg.statemem.data)
        end,

        onexit = function(inst)
            inst._should_teleport = nil
            local dest = inst.sg.statemem.data and inst.sg.statemem.data.dest or nil
            if dest then
                inst.Transform:SetPosition(dest:Get())
            end
            inst:Show()
        end
    },
}

CommonStates.AddWalkStates(states,
nil, nil, nil, true,
{
    walkonenter = function(inst)
        inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/walk_LP", "walk_lp")
    end,
    walkonexit = function(inst)
        inst.SoundEmitter:KillSound("walk_lp")
    end,
})


return StateGraph("gestalt_guard_evolved", states, events, "idle", actionhandlers)
