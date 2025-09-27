require("stategraphs/commonstates")

local function getidleanim(inst)

    if not inst.components.timer:TimerExists("flicker_cooldown") and 
        TheWorld.components.sisturnregistry and 
        TheWorld.components.sisturnregistry:IsBlossom() and 
        math.random()<0.2 and
        not inst.components.debuffable:HasDebuff("abigail_murder_buff") then
            
        inst.components.timer:StartTimer("flicker_cooldown", math.random()*20  + 10 )

        return "idle_abigail_flicker"
    end

    return (inst._is_transparent and "abigail_escape_loop")
        or (inst.components.aura.applying and "attack_loop")
        or (inst.is_defensive and math.random() < 0.1 and "idle_custom")
        or "idle"
end

local function startaura(inst)
    if inst.components.health:IsDead() or inst.sg:HasStateTag("dissipate") or inst:HasTag("gestalt") then
        return
    end

    inst.Light:SetColour(255/255, 32/255, 32/255)
    inst.AnimState:SetMultColour(207/255, 92/255, 92/255, 1)

    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/attack_LP", "angry")

    local attack_anim = "attack" .. tostring(inst.attack_level or 1)

    inst.attack_fx = SpawnPrefab("abigail_attack_fx")
    inst:AddChild(inst.attack_fx)
    inst.attack_fx.AnimState:PlayAnimation(attack_anim .. "_pre")
    inst.attack_fx.AnimState:PushAnimation(attack_anim .. "_loop", true)

    if inst:HasDebuff("abigail_murder_buff") then
        inst.attack_fx.AnimState:SetBuild("abigail_attack_fx_shadow_build")

        inst.attack_fx.AnimState:OverrideSymbol("fx_swirl",       "abigail_attack_fx_shadow_build",      "fx_swirl")
        inst.attack_fx.AnimState:OverrideSymbol("fx_aoe_swirl",       "abigail_attack_fx_shadow_build",      "fx_aoe_swirl")
        inst.attack_fx.AnimState:OverrideSymbol("fx_swirl_01",       "abigail_attack_fx_shadow_build",      "fx_swirl_01")
    end

    local skin_build = inst:GetSkinBuild()
    if skin_build then
        inst.attack_fx.AnimState:OverrideItemSkinSymbol("flower", skin_build, "flower", inst.GUID, "abigail_attack_fx")
    end
end

local function stopaura(inst)
    inst.Light:SetColour(180/255, 195/255, 225/255)
    inst.SoundEmitter:KillSound("angry")
    inst.AnimState:SetMultColour(1, 1, 1, 1)

    if inst.attack_fx then
        inst.attack_fx:kill_fx(inst.attack_level or 1)
        inst.attack_fx = nil
    end
end

local function onattack(inst)

    if inst:HasTag("gestalt") and
       inst.components.health ~= nil and
       not inst.components.health:IsDead() and
       not inst.sg:HasStateTag("busy") then
        inst.sg:GoToState("gestalt_attack")
    end
end

local DASHATTACK_MUST_TAGS = {"_combat"}

local function dash_attack_onupdate(inst, dt)
    if inst.sg.mem.aoe_attack_times == nil then
        return
    end

    if inst:HasTag("gestalt") then
        return
    end

    local aura = inst.components.aura
    local combat = inst.components.combat
    local leader = inst._playerlink
    local current_attack_time
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local hittable_entities = TheSim:FindEntities(ix, iy, iz, aura.radius, DASHATTACK_MUST_TAGS, aura.auraexcludetags)    

    for _, hittable_entity in pairs(hittable_entities) do
        if inst.sg.mem.aoe_attack_times == nil then
            return -- Abigail might change state by attacking these, check for aoe_attack_times again.
        end

        if hittable_entity ~= inst and
            combat:IsValidTarget(hittable_entity) and
            not inst.components.combat:IsAlly(hittable_entity) and
            (leader == nil or not leader.components.combat:IsAlly(hittable_entity)) and
            inst:auratest(hittable_entity, true)
        then
            current_attack_time = inst.sg.mem.aoe_attack_times[hittable_entity]

            if not current_attack_time or (current_attack_time - dt <= 0) then
                inst.sg.mem.aoe_attack_times[hittable_entity] = TUNING.WENDYSKILL_DASHATTACK_HITRATE

                inst:PushEvent("onareaattackother", { target = hittable_entity, weapon = nil, stimuli = nil })
                local dmg, spdmg = combat:CalcDamage(hittable_entity, nil, combat.areahitdamagepercent)
                hittable_entity.components.combat:GetAttacked(inst, dmg, nil, nil, spdmg)
            else
                inst.sg.mem.aoe_attack_times[hittable_entity] = current_attack_time - dt
            end
        end
    end
end

---------------------------------------------------------------------------------------------------------------------------------------

local GESTALT_ATTACKAT_RADIUS_PADDING = 2

local GESTALT_DASH_ATTACK_MUST_TAGS = { "_combat", "_health" }

local REGISTERED_GESTALT_DASH_ATTACK_TAGS     = TheSim:RegisterFindTags(GESTALT_DASH_ATTACK_MUST_TAGS, { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "companion", "player", "wall" })
local REGISTERED_GESTALT_DASH_ATTACK_TAGS_PVP = TheSim:RegisterFindTags(GESTALT_DASH_ATTACK_MUST_TAGS, { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" })

local function IsValidTarget(inst, target)
    if inst.sg.statemem.ignoretargets ~= nil and inst.sg.statemem.ignoretargets[target] then
        return false
    end

    local owner_combat = inst._playerlink ~= nil and inst._playerlink.components.combat or nil

    return
        target:IsValid() and
        (target.components.health == nil or not target.components.health:IsDead()) and
        owner_combat ~= nil and
        owner_combat:CanTarget(target) and
        target.components.combat:CanBeAttacked(inst) and
        not owner_combat:IsAlly(target)
end

local function GetGestaltDashTarget(inst)
    if inst._playerlink == nil or inst._playerlink.components.combat == nil then
        return
    end

    local pos = inst:GetPosition()
    local find_tags = TheNet:GetPVPEnabled() and REGISTERED_GESTALT_DASH_ATTACK_TAGS_PVP or REGISTERED_GESTALT_DASH_ATTACK_TAGS

    for i, v in ipairs(TheSim:FindEntities_Registered(pos.x, 0, pos.z, TUNING.ABIGAIL_GESTALT_ATTACKAT_RADIUS + GESTALT_ATTACKAT_RADIUS_PADDING, find_tags)) do
        if IsValidTarget(inst, v) then
            local range = TUNING.ABIGAIL_GESTALT_ATTACKAT_RADIUS + v:GetPhysicsRadius(0)

            local dist = inst:GetDistanceSqToInst(v)

            if dist <= range * range and
                IsWithinAngle(pos, inst.sg.statemem.fowardvector, TUNING.ABIGAIL_GESTALT_ATTACKAT_VALID_ANGLE / RADIANS, v:GetPosition()) 
            then
                return v
            end
        end
    end
end

---------------------------------------------------------------------------------------------------------------------------------------

-- Keep track of the original value and multiply the current value by ABIGAIL_GESTALT_ATTACKAT_DAMAGE_MULT_RATE,
-- while watching for external changes to the value.

local function ApplyGestaltAttackAtDamageMultRate(inst, tabula, key, value)
    if inst.sg.statemem.originalattackvalue == nil then
        inst.sg.statemem.originalattackvalue = {}
        inst.sg.statemem.lastattackvalue = {}
    end

    if inst.sg.statemem.originalattackvalue[key] == nil then
        inst.sg.statemem.originalattackvalue[key] = tabula[key]
    end

    if inst.sg.statemem.lastattackvalue[key] ~= nil and tabula[key] ~= inst.sg.statemem.lastattackvalue[key] then
         -- Something else changed tabula[key], consider that as our originalattackvalue...
        inst.sg.statemem.originalattackvalue[key] = tabula[key]
    end

    tabula[key] = (value or inst.sg.statemem.lastattackvalue[key] or tabula[key]) * TUNING.ABIGAIL_GESTALT_ATTACKAT_DAMAGE_MULT_RATE

    inst.sg.statemem.lastattackvalue[key] = tabula[key]
end

local function RemoveGestaltAttackAtDamageMultRate(inst, tabula, key)
    if inst.sg.statemem.originalattackvalue == nil then
        return
    end

    if inst.sg.statemem.lastattackvalue[key] ~= nil and tabula[key] ~= inst.sg.statemem.lastattackvalue[key] then
        return -- Something else changed tabula[key], don't revert back the value.
    end

    if inst.sg.statemem.originalattackvalue[key] ~= nil then
        tabula[key] = inst.sg.statemem.originalattackvalue[key]
    end
end

---------------------------------------------------------------------------------------------------------------------------------------

local function UpdateFlash(target, data, id, r, g, b)
	if data.flashstep < 4 then
		local value = (data.flashstep > 2 and 4 - data.flashstep or data.flashstep) * 0.05
		if target.components.colouradder == nil then
			target:AddComponent("colouradder")
		end
		target.components.colouradder:PushColour(id, value * r, value * g, value * b, 0)
		data.flashstep = data.flashstep + 1
	else
		target.components.colouradder:PopColour(id)
		data.task:Cancel()
	end
end

local function StartFlash(inst, target, r, g, b)
	local data = { flashstep = 1 }
	local id = inst.prefab.."::"..tostring(inst.GUID)
	data.task = target:DoPeriodicTask(0, UpdateFlash, nil, data, id, r, g, b)
	UpdateFlash(target, data, id, r, g, b)
end

---------------------------------------------------------------------------------------------------------------------------------------

local actionhandlers =
{
    ActionHandler(ACTIONS.HAUNT, "haunt_pre"),
}

local events =
{
    CommonHandlers.OnLocomote(true, true),
    EventHandler("doattack", onattack),
    EventHandler("startaura", startaura),
    EventHandler("stopaura", stopaura),
    EventHandler("attacked", function(inst)        
        if not (inst.components.health:IsDead() or inst.sg:HasStateTag("dissipate")) and not inst.sg:HasStateTag("nointerrupt")  and not inst.sg:HasStateTag("swoop") then
            inst.sg:GoToState("hit")
        end
    end),
    EventHandler("dance", function(inst)
        if not (inst.sg:HasStateTag("dancing") or inst.sg:HasStateTag("busy") or
                inst.components.health:IsDead() or inst.sg:HasStateTag("dissipate")) then
            inst.sg:GoToState("dance")
        end
    end),
    EventHandler("gestalt_mutate", function(inst, data)
        inst.sg:GoToState("abigail_transform_pre", {gestalt=data.gestalt})
    end),

    EventHandler("start_playwithghost", function(inst, data)
        local target = data.target
        if target and target:IsValid() and not inst.sg:HasStateTag("playing")
                and (GetTime() - (inst.sg.mem.lastplaytime or 0)) > TUNING.ABIGAIL_PLAYFUL_DELAY then
            inst.sg.mem.queued_play_target = target
            target:PushEvent("ghostplaywithme", { target = inst })
        end
    end),
}

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            if inst.sg.mem.queued_play_target then
                inst.sg.mem.lastplaytime = GetTime()
                inst.sg:GoToState("play", inst.sg.mem.queued_play_target)
                inst.sg.mem.queued_play_target = nil
            else
                local anim = getidleanim(inst)
                if anim ~= nil then
                    inst.AnimState:PlayAnimation(anim)
                end
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
            EventHandler("startaura", function(inst)
                if not inst:HasTag("gestalt") then
                    inst.sg:GoToState("attack_start")
                end
            end),
        },

    },

    State{
        name = "attack_start",
        tags = { "busy", "canrotate" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("attack_pre")
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
        name = "appear",
        tags = { "busy", "noattack", "nointerrupt" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("appear")
			if inst.components.health then
		        inst.components.health:SetInvincible(true)
			end
            inst:updatehealingbuffs()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if not inst:HasTag("gestalt") then inst.components.aura:Enable(true) end
	        inst.components.health:SetInvincible(false)
			if inst._playerlink then
				inst._playerlink.components.ghostlybond:SummonComplete()
			end
        end,
    },

    State{
        name = "dance",
        tags = {"idle", "dancing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst.AnimState:PushAnimation("dance", true)
        end,
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
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
        name = "dissipate",
        tags = { "busy", "noattack", "nointerrupt", "dissipate", "nocommand" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("dissipate")

	        inst.components.health:SetInvincible(true)
			inst.components.aura:Enable(false)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					if inst._playerlink and inst._playerlink.components.ghostlybond then
						inst.sg:GoToState("dissipated")
					else
						inst:Remove()
					end
                end
            end)
        },

		onexit = function(inst)
	        inst.components.health:SetInvincible(false)
            inst:BecomeDefensive()
		end,
    },

    State{
        name = "dissipated",
        tags = { "busy", "noattack", "nointerrupt", "dissipate", "nocommand" },

        onenter = function(inst)
            inst.Physics:Stop()
			inst.components.aura:Enable(false)
			if inst._playerlink then
				inst._playerlink.components.ghostlybond:RecallComplete()
			end
			if inst.components.health:IsDead() then
				inst.components.health:SetCurrentHealth(1)
			end
            inst:updatehealingbuffs()
        end,
    },

    State{
        name = "ghostlybond_levelup",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("flower_change")

			inst.sg.statemem.level = (data ~= nil and data.level) or nil
        end,

        timeline =
        {
			TimeEvent(14 * FRAMES, function(inst)
                local change_sound = (inst.sg.statemem.level == 3 and "dontstarve/characters/wendy/abigail/level_change/2")
                    or "dontstarve/characters/wendy/abigail/level_change/1"
                inst.SoundEmitter:PlaySound(change_sound)
            end),
			TimeEvent(15 * FRAMES, function(inst)
				local fx = SpawnPrefab("abigaillevelupfx")
				fx.entity:SetParent(inst.entity)

                local skin_build = inst:GetSkinBuild()
                if skin_build ~= nil then
                    fx.AnimState:OverrideItemSkinSymbol("flower", skin_build, "flower", inst.GUID, "abigail_attack_fx" )
                end
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
    },

    State{
        name = "walk_start",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            if inst.AnimState:AnimDone() or inst.AnimState:GetCurrentAnimationLength() == 0 then
                inst.sg:GoToState("walk")
            else
                inst.components.locomotor:WalkForward()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("walk")
                end
            end),
        },
    },

    State{
        name = "walk",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            local anim = getidleanim(inst)
            if anim then
                inst.AnimState:PlayAnimation(anim)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst)
                if math.random() < 0.8 then
                    if inst:HasTag("gestalt") then
                        inst.SoundEmitter:PlaySound("meta5/abigail/gestalt_abigail_idle")
                    else
                        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/howl")
                    end
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("walk")
        end,
    },

    State{
        name = "walk_stop",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
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
        name = "run_start",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            if inst.AnimState:AnimDone() or inst.AnimState:GetCurrentAnimationLength() == 0 then
                inst.sg:GoToState("run")
            else
                inst.components.locomotor:RunForward()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            local anim = getidleanim(inst)
            if anim then
                inst.AnimState:PlayAnimation(anim)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst)
                if math.random() < 0.8 then
                    if inst:HasTag("gestalt") then
                        inst.SoundEmitter:PlaySound("meta5/abigail/gestalt_abigail_idle")
                    else
                        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/howl")
                    end
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
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

    State {
        name = "abigail_attack_start",
        tags = { "busy", "nointerrupt", "swoop" }, --"noattack", 

        onenter = function(inst, target_position)
            inst.Transform:SetEightFaced()

            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("abigail_attack_pre")

            if target_position then
                inst:ForceFacePoint(target_position:Get())
            end

            local ipos = inst:GetPosition()
            local route = (target_position - ipos)
            local _, route_length = route:GetNormalizedAndLength()
            inst.sg.statemem.route_time = route_length / TUNING.WENDYSKILL_DASHATTACK_VELOCITY
        end,

        timeline = {

            FrameEvent(10, function(inst)
                inst.sg.mem.aoe_attack_times = {}

                if not inst:HasTag("gestalt") then
                    inst.Light:SetColour(255/255, 32/255, 32/255)
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/attack_LP", "angry")
                    inst.AnimState:SetMultColour(207/255, 92/255, 92/255, 1)

                    inst.sg.mem.abigail_attack_fx = SpawnPrefab("abigail_attack_fx")
                    inst:AddChild(inst.sg.mem.abigail_attack_fx)

                    local attack_anim = "attack" .. tostring(inst.attack_level or 1)
    
                    inst.sg.mem.abigail_attack_fx.AnimState:PlayAnimation(attack_anim .. "_pre")
                    inst.sg.mem.abigail_attack_fx.AnimState:PushAnimation(attack_anim .. "_loop", true)                    
                end

            end)
        },

        onupdate = dash_attack_onupdate,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.exit_success = true
                inst.sg:GoToState("abigail_attack_loop", inst.sg.statemem.route_time)
            end)
        },

        onexit = function(inst)
            if not inst.sg.statemem.exit_success then
                inst.Transform:SetNoFaced()

                inst.sg.mem.aoe_attack_times = nil
                if not inst:HasTag("gestalt") then 
                    inst.components.aura:Enable(true)
                    inst.Light:SetColour(180/255, 195/255, 225/255)
                    inst.SoundEmitter:KillSound("angry")
                    inst.AnimState:SetMultColour(1, 1, 1, 1)
                end
                if inst.sg.mem.abigail_attack_fx then
                    inst.sg.mem.abigail_attack_fx:Remove()
                end
            end
        end,
    },

    State {
        name = "abigail_attack_loop",
        tags = {"busy", "swoop" },

        onenter = function(inst, loop_time)
            inst:SetTransparentPhysics(true)
            inst.AnimState:PlayAnimation("abigail_attack_loop", true)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:Stop()
            inst.Physics:SetMotorVelOverride(TUNING.WENDYSKILL_DASHATTACK_VELOCITY, 0, 0)
            inst.sg:SetTimeout(loop_time or 1.75)
        end,

        onupdate = dash_attack_onupdate,

        ontimeout = function(inst)
            inst.sg.statemem.exit_success = true
            inst.sg:GoToState("abigail_attack_end")
        end,

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            inst:SetTransparentPhysics(false)

            inst.sg.mem.aoe_attack_times = nil

            inst.Light:SetColour(180/255, 195/255, 225/255)
            inst.SoundEmitter:KillSound("angry")
            inst.AnimState:SetMultColour(1, 1, 1, 1)
            if inst.sg.mem.abigail_attack_fx then
                inst.sg.mem.abigail_attack_fx:Remove()
            end

            if not inst.sg.statemem.exit_success then
                inst.Transform:SetNoFaced()
                if not inst:HasTag("gestalt") then
                    inst.components.aura:Enable(true)
                end
            end
        end,
    },

    State {
        name = "abigail_attack_end",
        tags = { "busy", "nointerrupt", "swoop" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("abigail_attack_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.Transform:SetNoFaced()
            if not inst:HasTag("gestalt") then
                inst.components.aura:Enable(true)
            end
        end,
    },

    State {
        name = "escape",
        tags = { "busy", "noattack", "nointerrupt" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("abigail_escape_pre")

            inst.components.health:SetInvincible(true)

            inst.Transform:SetTwoFaced()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem._finished = true
                inst.sg:GoToState("run_start")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem._finished then
	            inst.components.health:SetInvincible(false)
            end
        end,
    },

    State {
        name = "escape_end",
        tags = { "busy", "noattack", "nointerrupt" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("abigail_escape_pst")

            inst.Transform:SetNoFaced()
        end,

        timeline = {
            FrameEvent(16, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("run_start")
            end),
        },

        onexit = function(inst)
            inst.components.health:SetInvincible(false)
        end,
    },

    State {
        name = "scare",
        tags = { "busy", "nointerrupt"},

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("abigail_scare")
            inst.SoundEmitter:PlaySound("meta5/abigail/jumpscare")
        end,

        timeline =
        {
			SoundFrameEvent(14, "dontstarve/characters/wendy/abigail/level_change/2"),
			FrameEvent(15, function(inst)
				local fx = SpawnPrefab("abigaillevelupfx")
				fx.entity:SetParent(inst.entity)

                local skin_build = inst:GetSkinBuild()
                if skin_build ~= nil then
                    fx.AnimState:OverrideItemSkinSymbol("flower", skin_build, "flower", inst.GUID, "abigail_attack_fx" )
                end

                inst:PushEvent("do_ghost_scare")
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
    },

    State {
        name = "abigail_transform_pre",
        tags = { "busy", "nointerrupt" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("abigail_transform_pre")
            inst.SoundEmitter:PlaySound("meta5/abigail/abigail_gestalt_transform_stinger")

            inst.sg.statemem.isgestalt = data.gestalt
        end,

        onexit = function(inst, data)
            if inst.sg.statemem.isgestalt then
                inst:SetToGestalt()
            else
                inst:SetToNormal()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("abigail_transform")
                end
            end),
        },
    },

    State {
        name = "abigail_transform",
        tags = { "busy", "nointerrupt" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("abigail_transform")
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

    State {
        name = "gestalt_attack",
        tags = { "busy", "nointerrupt"},

        onenter = function(inst, pos)
            inst.components.locomotor:Stop()
            inst.SoundEmitter:PlaySound("meta5/abigail/gestalt_abigail_dashattack_pre")

            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("gestalt_attack_pre")

            if pos ~= nil then
                inst.sg.statemem.final_pos = pos
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(inst.sg.statemem.final_pos ~= nil and "gestalt_loop_homing_attack" or "gestalt_loop_attack", { pos = inst.sg.statemem.final_pos })
                end
            end),
        },
    },

    State {
        name = "gestalt_loop_attack",
        tags = { "busy", "nointerrupt", "swoop"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.Physics:Stop()
            inst:SetTransparentPhysics(true)
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:ClearMotorVelOverride()
            inst.Physics:SetMotorVelOverride(15, 0, 0)

            inst.AnimState:PlayAnimation("gestalt_attack_loop", true)
            inst.sg:SetTimeout(3)

            inst.sg.statemem.oldattackdamage = inst.components.combat.defaultdamage

            local buff = inst:GetDebuff("elixir_buff")
            local phase = (buff ~= nil and buff.prefab == "ghostlyelixir_attack_buff") and "night" or TheWorld.state.phase
            local damage = (TUNING.ABIGAIL_GESTALT_DAMAGE[phase] or TUNING.ABIGAIL_GESTALT_DAMAGE.day)

            inst.components.combat:SetDefaultDamage(damage)

            inst.components.combat:StartAttack()
            inst.sg.statemem.enable_attack = true
        end,

        ontimeout = function(inst)
            inst.sg.statemem.enable_attack = false
        end,

        onupdate = function(inst)

            if inst.components.combat.target and inst.components.combat.target:IsValid() and inst.sg.statemem.enable_attack then
                local x,y,z = inst.components.combat.target.Transform:GetWorldPosition()
                inst:ForceFacePoint(x,y,z)
            end

            if inst.sg.statemem.enable_attack then
                local target = inst.components.combat.target
                if target ~= nil and target:IsValid() and inst:GetDistanceSqToInst(target) <= TUNING.GESTALT_ATTACK_HIT_RANGE_SQ then
                    if inst.components.combat:CanTarget(target) then
                        inst.sg.statemem.enable_attack = false

                        inst.components.combat:DoAttack(target)
                        inst:ApplyDebuff({target=target})

                        if target.components.combat and target.components.combat.hiteffectsymbol then
                        local fx = SpawnPrefab("abigail_gestalt_hit_fx")
                            fx.entity:SetParent(target.entity)
                            target:AddChild(fx)
                            inst.SoundEmitter:PlaySound("meta5/abigail/gestalt_abigail_dashattack_hit")

                            StartFlash(inst, target, 1, 1, 1)
                        end
                    end
                end
            end

            if (inst.sg.statemem.enable_attack == false or inst.components.combat.target == nil or not inst.components.combat.target:IsValid() or inst.components.combat.target.components.health:IsDead() ) 
                and not inst.end_gestalt_attack_task then
                    inst.end_gestalt_attack_task = inst:DoTaskInTime(0.5,function() inst.sg:GoToState("gestalt_pst_attack") end)
            end
        end,

        onexit = function(inst)
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
            inst.sg.statemem.enable_attack = false

            if inst.end_gestalt_attack_task then
                inst.end_gestalt_attack_task:Cancel()
                inst.end_gestalt_attack_task = nil
            end

            if inst.sg.statemem.oldattackdamage then
                inst.components.combat.defaultdamage = inst.sg.statemem.oldattackdamage
            end

            inst:SetTransparentPhysics(false)
        end,
    },

    State {
        name = "gestalt_loop_homing_attack",
        tags = { "busy", "nointerrupt", "swoop"},

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.Physics:Stop()
            inst:SetTransparentPhysics(true)
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:ClearMotorVelOverride()
            inst.Physics:SetMotorVelOverride(TUNING.WENDYSKILL_DASHATTACK_VELOCITY, 0, 0)

            inst.AnimState:PlayAnimation("gestalt_attack_loop", true)
            inst.sg:SetTimeout(8)

            local buff   = inst:GetDebuff("elixir_buff")
            local phase  = (buff ~= nil and buff.prefab == "ghostlyelixir_attack_buff") and "night" or TheWorld.state.phase
            local damage = (TUNING.ABIGAIL_GESTALT_DAMAGE[phase] or TUNING.ABIGAIL_GESTALT_DAMAGE.day)

            ApplyGestaltAttackAtDamageMultRate(inst, inst.components.combat, "defaultdamage", damage)
            ApplyGestaltAttackAtDamageMultRate(inst, inst.components.planardamage, "basedamage")
            ApplyGestaltAttackAtDamageMultRate(inst, inst.components.planardamage.externalbonuses, "_modifier")

            inst.sg.statemem.final_pos = data.pos

            inst:ForceFacePoint(inst.sg.statemem.final_pos)

            local rotation = inst.Transform:GetRotation() -- Keep this after ForceFacePoint!
            inst.sg.statemem.fowardvector = Vector3(math.cos(-rotation / RADIANS), 0, math.sin(-rotation / RADIANS))

            inst.sg.statemem.ignoretargets = {}
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("gestalt_pst_attack")
        end,

        onupdate = function(inst, dt)
            local target_pos = inst.sg.statemem.final_pos
            local current_pos = inst:GetPosition()

            if distsq(target_pos.x, target_pos.z, current_pos.x, current_pos.z) <= 2*2 then
                inst.sg:GoToState("gestalt_pst_attack")

                return -- We've arrived!
            end

            if inst.sg.statemem.current_target == nil or not IsValidTarget(inst, inst.sg.statemem.current_target) then
                inst.sg.statemem.current_target = GetGestaltDashTarget(inst)
            end

            local target = inst.sg.statemem.current_target

            if target == nil then
                inst:ForceFacePoint(inst.sg.statemem.final_pos)

                return -- Try to find a target again next frame...
            end

            inst:ForceFacePoint(target.Transform:GetWorldPosition())

            if inst.components.combat:CanTarget(target) and inst:GetDistanceSqToInst(target) <= TUNING.GESTALT_ATTACK_HIT_RANGE_SQ then
                if target.components.combat ~= nil and target.components.combat.hiteffectsymbol ~= nil then
                    target:SpawnChild("abigail_gestalt_hit_fx")

                    StartFlash(inst, target, 1, 1, 1)

                    inst.SoundEmitter:PlaySound("meta5/abigail/gestalt_abigail_dashattack_hit")
                end
                
                inst.components.combat:DoAttack(target)
                inst.components.combat:RestartCooldown() -- For regular attack cooldown, since we aren't calling combat:StartAttack.

                ApplyGestaltAttackAtDamageMultRate(inst, inst.components.combat, "defaultdamage")
                ApplyGestaltAttackAtDamageMultRate(inst, inst.components.planardamage, "basedamage")
                ApplyGestaltAttackAtDamageMultRate(inst, inst.components.planardamage.externalbonuses, "_modifier")

                inst:ApplyDebuff({target=target})

                inst.sg.statemem.current_target = nil -- Let next frame handle having a new target.
                inst.sg.statemem.ignoretargets[target] = true -- Used by IsValidTarget.
            end
        end,

        onexit = function(inst)
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()

            RemoveGestaltAttackAtDamageMultRate(inst, inst.components.combat, "defaultdamage")
            RemoveGestaltAttackAtDamageMultRate(inst, inst.components.planardamage, "basedamage")
            RemoveGestaltAttackAtDamageMultRate(inst, inst.components.planardamage.externalbonuses, "_modifier")

            inst:SetTransparentPhysics(false)
        end,
    },

    State {
        name = "gestalt_pst_attack",
        tags = { "busy", "nointerrupt", "swoop" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("gestalt_attack_pst")
        end,

        timeline =
        {
            FrameEvent(0,  function(inst) inst.Physics:SetMotorVelOverride(TUNING.WENDYSKILL_DASHATTACK_VELOCITY * .100, 0, 0) end),
            FrameEvent(8,  function(inst) inst.Physics:SetMotorVelOverride(TUNING.WENDYSKILL_DASHATTACK_VELOCITY * .075, 0, 0) end),
            FrameEvent(16, function(inst) inst.Physics:SetMotorVelOverride(TUNING.WENDYSKILL_DASHATTACK_VELOCITY * .050, 0, 0) end),
            FrameEvent(24, function(inst) inst.Physics:SetMotorVelOverride(TUNING.WENDYSKILL_DASHATTACK_VELOCITY * .025, 0, 0) end),

            FrameEvent(32, function(inst)
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()

                inst.SoundEmitter:PlaySound("meta5/abigail/gestalt_abigail_dashattack_pst")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
           
    },

    State {
        name = "haunt_pre",
        tags = { "busy", "doing" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("dissipate")
            inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_haunt", nil, nil, true)
        end,

        timeline =
        {
            FrameEvent(15, function(inst)
                inst:PerformBufferedAction()
            end)
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("haunt")
            end),
        },
    },

    State {
        name = "haunt",
        tags = { "busy", "doing" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("appear")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "play",
		tags = {"busy", "canrotate", "playful"},

        onenter = function(inst, target)
            inst.components.locomotor:StopMoving()

            if target and target:IsValid() then
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            end

            inst.AnimState:PlayAnimation("dance")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end)
        },
    },
}

return StateGraph("abigail", states, events, "appear", actionhandlers)
