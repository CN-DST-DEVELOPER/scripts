local fns

local function DoHeal(inst)
    local healtargets = {}
    local healtargetscount = 0
    local sanitytargets = {}
    local sanitytargetscount = 0
    local x, y, z = inst.Transform:GetWorldPosition()
    local rangesq = TUNING.WORTOX_SOULHEAL_RANGE + (inst.soul_heal_range_modifier or 0)
    rangesq = rangesq * rangesq
    for i, v in ipairs(AllPlayers) do
        if not (v.components.health:IsDead() or v:HasTag("playerghost")) and
            v.entity:IsVisible() and
            v:GetDistanceSqToPoint(x, y, z) < rangesq then
            -- NOTES(JBK): If the target is hurt put them on the list to do heals.
            if v.components.health:IsHurt() and not v:HasTag("health_as_oldage") then -- Wanda tag.
                table.insert(healtargets, v)
                healtargetscount = healtargetscount + 1
            end
            -- NOTES(JBK): If the target is another "soulstealer" give some sanity even when they did not drop the soul but not in overload state.
            if not inst.soul_bursting and v._souloverloadtask == nil and v.components.sanity and v:HasTag("soulstealer") then
                table.insert(sanitytargets, v)
                sanitytargetscount = sanitytargetscount + 1
            end
        end
    end
    if healtargetscount > 0 then
        -- Healing adjustments are absolute from the releaser but can be debuffed by the receiver.
        local loss_per_player = TUNING.WORTOX_SOULHEAL_LOSS_PER_PLAYER
        if inst.soul_heal_player_efficient then
            loss_per_player = loss_per_player * TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_4_LOSS_PER_PLAYER_MULT
        end
        local amt = math.max(TUNING.WORTOX_SOULHEAL_MINIMUM_HEAL, (TUNING.HEALING_MED * (inst.soul_heal_premult or 1) - loss_per_player * (healtargetscount - 1)) * (inst.soul_heal_mult or 1))
        local amt_naughty = amt * TUNING.SKILLS.WORTOX.NAUGHTY_SOULHEAL_RECEIVED_MULT
        for i = 1, healtargetscount do
            local v = healtargets[i]
            local adjusted_amt = v.wortox_inclination == "naughty" and amt_naughty or amt
            v.components.health:DoDelta(adjusted_amt, nil, inst.prefab)
            if v.components.combat then -- Always show fx now that the heals do special targeting to show the player that it stops working when everyone is full.
                local fx = SpawnPrefab("wortox_soul_heal_fx")
                fx.entity:AddFollower():FollowSymbol(v.GUID, v.components.combat.hiteffectsymbol, 0, -50, 0)
                fx:Setup(v)
            end
        end
    end
    if sanitytargetscount > 0 then
        -- Sanity adjustments are relative to who sees it.
        local amt = TUNING.SANITY_TINY * 0.5
        local amt_nice = amt * TUNING.SKILLS.WORTOX.NICE_SANITY_MULT
        local amt_naughty = amt * TUNING.SKILLS.WORTOX.NAUGHTY_SANITY_MULT
        for i = 1, sanitytargetscount do
            local v = sanitytargets[i]
            local adjusted_amt = v.wortox_inclination == "nice" and amt_nice or v.wortox_inclination == "naughty" and amt_naughty or amt
            v.components.sanity:DoDelta(adjusted_amt)
        end
    end
end

local function HasSoul(victim)
	return (	(victim.components.combat ~= nil and victim.components.health ~= nil) or
				victim.components.murderable ~= nil
			)
		and not victim:HasAnyTag(SOULLESS_TARGET_TAGS)
end

local function SoulDamageTest(inst, ent, owner)
    if ent == owner then
        return false
    end

    if owner then
        if owner.components.combat == nil then
            return false
        end
        if owner.components.combat:TargetHasFriendlyLeader(ent) or not owner.components.combat:CanTarget(ent) then
            return false
        end
    end

    if ent.components.health and ent.components.health:IsDead() then
        return false
    end

    if ent:HasTag("saddled") then
        return false
    end

    if ent:HasTag("player") and not TheNet:GetPVPEnabled() then
        return false
    end

    -- FIXME(JBK): Did I miss something? Bug report it!

    return fns.HasSoul(ent)
end

local function GetNumSouls(victim)
    --V2C: assume HasSoul is checked separately
    return (victim:HasTag("dualsoul") and 2)
        or (victim:HasTag("epic") and math.random(7, 8))
        or 1
end

local function SpawnSoulAt(x, y, z, victim, marksource)
    local fx = SpawnPrefab("wortox_soul_spawn")
    if marksource then
        fx._soulsource = victim and victim._soulsource or nil
    end
    fx.Transform:SetPosition(x, y, z)
    fx:Setup(victim)
end

local function SpawnSoulsAt(victim, numsouls)
    local x, y, z = victim.Transform:GetWorldPosition()
    if numsouls == 2 then
        local theta = math.random() * TWOPI
        local radius = .4 + math.random() * .1
        fns.SpawnSoulAt(x + math.cos(theta) * radius, 0, z - math.sin(theta) * radius, victim, true)
        theta = GetRandomWithVariance(theta + PI, PI / 15)
        fns.SpawnSoulAt(x + math.cos(theta) * radius, 0, z - math.sin(theta) * radius, victim, false) -- NOTES(JBK): Only one guarantee.
    else
        fns.SpawnSoulAt(x, y, z, victim, true)
        if numsouls > 1 then
            numsouls = numsouls - 1
            local theta0 = math.random() * TWOPI
            local dtheta = TWOPI / numsouls
            local thetavar = dtheta / 10
            local theta, radius
            for i = 1, numsouls do
                theta = GetRandomWithVariance(theta0 + dtheta * i, thetavar)
                radius = 1.6 + math.random() * .4
                fns.SpawnSoulAt(x + math.cos(theta) * radius, 0, z - math.sin(theta) * radius, victim, false) -- NOTES(JBK): Only one guarantee.
            end
        end
    end
end

local function GiveSouls(inst, num, pos)
    local soul = SpawnPrefab("wortox_soul")
    if soul.components.stackable ~= nil then
        soul.components.stackable:SetStackSize(num)
    end
    inst.components.inventory:GiveItem(soul, nil, pos)
end

fns = {
    DoHeal = DoHeal,
    HasSoul = HasSoul,
    GetNumSouls = GetNumSouls,
    SpawnSoulAt = SpawnSoulAt,
    SpawnSoulsAt = SpawnSoulsAt,
    GiveSouls = GiveSouls,
    SoulDamageTest = SoulDamageTest,
}

return fns
