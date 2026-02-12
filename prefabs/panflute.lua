local assets = {
    Asset("ANIM", "anim/pan_flute.zip"),
}
local prefabs = {
    "wortox_soul_spawn",
    "wortox_soul_spawn_fx",
}

local function OnPlayed(inst, musician)
    -- Clear temp variables in UseModifier!
    inst.panflute_sleeptime = TUNING.PANFLUTE_SLEEPTIME -- NOTES(JBK): Leaving this here for mods and is a good cache place.

    if musician:HasDebuff("wortox_panflute_buff") then
        musician:RemoveDebuff("wortox_panflute_buff")
        if musician.components.sanity then
            musician.components.sanity:DoDelta(TUNING.SANITY_TINY)
        end
        inst.panflute_shouldfiniteuses_stopuse = true
    end

    local skilltreeupdater = musician.components.skilltreeupdater
    if skilltreeupdater then
        if skilltreeupdater:IsActivated("wortox_panflute_forget") then
            inst.panflute_wortox_forget_debuff = true
        end
    end
end

local HEAR_ONEOF_TAGS = { "sleeper", "player", "tendable_farmplant" }
local function HearPanFlute(inst, musician, instrument)
    if inst ~= musician and
        (TheNet:GetPVPEnabled() or not inst:HasTag("player")) and
        not (inst.components.freezable ~= nil and inst.components.freezable:IsFrozen()) and
        not (inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck()) and
        not (inst.components.fossilizable ~= nil and inst.components.fossilizable:IsFossilized())
        and inst:HasAnyTag(HEAR_ONEOF_TAGS) then
        local mount = inst.components.rider ~= nil and inst.components.rider:GetMount() or nil
        if mount ~= nil then
            mount:PushEvent("ridersleep", { sleepiness = 10, sleeptime = instrument.panflute_sleeptime })
        end
		if inst.components.farmplanttendable ~= nil then
			inst.components.farmplanttendable:TendTo(musician)
        elseif inst.components.sleeper ~= nil then
            inst.components.sleeper:AddSleepiness(10, instrument.panflute_sleeptime)
            if inst.components.sleeper:IsAsleep() then
                if instrument.panflute_wortox_forget_debuff and inst.components.combat then
                    inst:AddDebuff("wortox_forget_debuff", "wortox_forget_debuff", {toforget = musician})
                end
            end
        elseif inst.components.grogginess ~= nil then
            inst.components.grogginess:AddGrogginess(10, instrument.panflute_sleeptime)
        else
            inst:PushEvent("knockedout")
        end
    end
end

local function SummonSoul(musician, x, y, z)
    local soulfx = SpawnPrefab("wortox_soul_spawn_fx")
    soulfx.Transform:SetPosition(x, y, z)
    local soul = SpawnPrefab("wortox_soul_spawn")
    soul._soulsource = musician
    soul.Transform:SetPosition(x, y, z)
    soul:Setup(nil)
end
local function DoSoulSummon(musician)
    local x, y, z = musician.Transform:GetWorldPosition()
    local spawnradius_max = TUNING.WORTOX_SOULSTEALER_RANGE - 0.1 -- Small fudge factor to keep it in range if the player does not move.
    local spawnradius_min = spawnradius_max * 0.5
    local spawnradius_max_sq = spawnradius_max * spawnradius_max
    local spawnradius_min_sq = spawnradius_min * spawnradius_min
    for i = 0, TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_SOULCALLER_SOULCOUNT - 1 do
        -- Doughnut shape distribution.
        local radiusrand = math.random()
        local radiussq = radiusrand * spawnradius_max_sq + (1 - radiusrand) * spawnradius_min_sq
        local radius = math.sqrt(radiussq)
        local angle = math.random() * TWOPI
        local dx, dz = math.cos(angle) * radius, math.sin(angle) * radius
        musician:DoTaskInTime(i * 0.1 + math.random() * 0.05, SummonSoul, x + dx, y, z + dz)
    end
end

local function OnFinishedPlaying(inst, musician)
    local skilltreeupdater = musician.components.skilltreeupdater
    if skilltreeupdater then
        if skilltreeupdater:IsActivated("wortox_panflute_soulcaller") then
            musician:DoTaskInTime(52 * FRAMES, DoSoulSummon) -- NOTES(JBK): Keep FRAMES in sync with SGwilson. [PFSSTS]
        end
    end
end

local function UseModifier(uses, action, doer, target, item)
    item.panflute_wortox_forget_debuff = nil
    if item.panflute_shouldfiniteuses_stopuse then
        item.panflute_shouldfiniteuses_stopuse = nil
        return 0
    end
    return uses
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("flute")

    inst.AnimState:SetBank("pan_flute")
    inst.AnimState:SetBuild("pan_flute")
    inst.AnimState:PlayAnimation("idle")

    --tool (from tool component) added to pristine state for optimization
    inst:AddTag("tool")

    MakeInventoryFloatable(inst, "small", 0.05, 0.8)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("instrument")
    inst.components.instrument:SetRange(TUNING.PANFLUTE_SLEEPRANGE)
    inst.components.instrument:SetOnPlayedFn(OnPlayed)
    inst.components.instrument:SetOnHeardFn(HearPanFlute)
    inst.components.instrument:SetOnFinishedPlayingFn(OnFinishedPlaying)

    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.PLAY)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.PANFLUTE_USES)
    inst.components.finiteuses:SetUses(TUNING.PANFLUTE_USES)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetConsumption(ACTIONS.PLAY, 1)
    inst.components.finiteuses:SetModifyUseConsumption(UseModifier)

    inst:AddComponent("inventoryitem")

    MakeHauntableLaunch(inst)

    inst:ListenForEvent("floater_startfloating", function(inst) inst.AnimState:PlayAnimation("float") end)
    inst:ListenForEvent("floater_stopfloating", function(inst) inst.AnimState:PlayAnimation("idle") end)

    return inst
end

return Prefab("panflute", fn, assets)
