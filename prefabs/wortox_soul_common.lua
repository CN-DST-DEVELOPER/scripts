local function DoHeal(inst)
    local healtargets = {}
    local healtargetscount = 0
    local sanitytargets = {}
    local sanitytargetscount = 0
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(AllPlayers) do
        if not (v.components.health:IsDead() or v:HasTag("playerghost")) and
            v.entity:IsVisible() and
            v:GetDistanceSqToPoint(x, y, z) < TUNING.WORTOX_SOULHEAL_RANGE * TUNING.WORTOX_SOULHEAL_RANGE then
            -- NOTES(JBK): If the target is hurt put them on the list to do heals.
            if v.components.health:IsHurt() and not v:HasTag("health_as_oldage") then -- Wanda tag.
                table.insert(healtargets, v)
                healtargetscount = healtargetscount + 1
            end
            -- NOTES(JBK): If the target is another "soulstealer" give some sanity even when they did not drop the soul but not in overload state.
            if v._souloverloadtask == nil and v.components.sanity and v:HasTag("soulstealer") then
                table.insert(sanitytargets, v)
                sanitytargetscount = sanitytargetscount + 1
            end
        end
    end
    if healtargetscount > 0 then
        local amt = math.max(TUNING.WORTOX_SOULHEAL_MINIMUM_HEAL, TUNING.HEALING_MED - TUNING.WORTOX_SOULHEAL_LOSS_PER_PLAYER * (healtargetscount - 1))
        for i = 1, healtargetscount do
            local v = healtargets[i]
            v.components.health:DoDelta(amt, nil, inst.prefab)
            if v.components.combat then -- Always show fx now that the heals do special targeting to show the player that it stops working when everyone is full.
                local fx = SpawnPrefab("wortox_soul_heal_fx")
                fx.entity:AddFollower():FollowSymbol(v.GUID, v.components.combat.hiteffectsymbol, 0, -50, 0)
                fx:Setup(v)
            end
        end
    end
    if sanitytargetscount > 0 then
        local amt = TUNING.SANITY_TINY * 0.5
        for i = 1, sanitytargetscount do
            local v = sanitytargets[i]
            v.components.sanity:DoDelta(amt)
        end
    end
end

local function HasSoul(victim)
    return not (victim:HasTag("veggie") or
                victim:HasTag("structure") or
                victim:HasTag("wall") or
                victim:HasTag("balloon") or
                victim:HasTag("soulless") or
                victim:HasTag("chess") or
                victim:HasTag("shadow") or
                victim:HasTag("shadowcreature") or
                victim:HasTag("shadowminion") or
                victim:HasTag("shadowchesspiece") or
                victim:HasTag("groundspike") or
                victim:HasTag("smashable"))
        and (  (victim.components.combat ~= nil and victim.components.health ~= nil)
            or victim.components.murderable ~= nil )
end

local function GetNumSouls(victim)
    --V2C: assume HasSoul is checked separately
    return (victim:HasTag("dualsoul") and 2)
        or (victim:HasTag("epic") and math.random(7, 8))
        or 1
end

return {
    DoHeal = DoHeal,
    HasSoul = HasSoul,
    GetNumSouls = GetNumSouls,
}
