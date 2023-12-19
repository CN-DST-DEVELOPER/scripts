local fns

local EMBERS_ONEOFTAGS = { "animal", "character", "largecreature", "monster", "smallcreature" }

local function HasEmbers(victim)
    return
        victim.components.burnable and
        victim.components.burnable:IsBurning() and
        not victim:HasTag("noember") and
        victim:HasOneOfTags(EMBERS_ONEOFTAGS)
end

local function GetNumEmbers(victim)
    --V2C: assume HasEmbers is checked separately
    return 
        (victim:HasTag("epic") and math.random(7, 8)) or
        (victim:HasTag("largecreature") and 3) or
        1
end

local function SpawnEmberAt(x, y, z, victim, marksource)
    local fx = SpawnPrefab("willow_ember")

    if marksource then
        fx._embersource = victim and victim._embersource or nil
    end

    fx.Transform:SetPosition(x, y, z)
end

local function SpawnEmbersAt(victim, numembers)
    local x, y, z = victim.Transform:GetWorldPosition()

    if numembers == 2 then
        local theta = math.random() * 2 * PI
        local radius = .4 + math.random() * .1
        fns.SpawnEmberAt(x + math.cos(theta) * radius, 0, z - math.sin(theta) * radius, victim, true)
        theta = GetRandomWithVariance(theta + PI, PI / 15)
        fns.SpawnEmberAt(x + math.cos(theta) * radius, 0, z - math.sin(theta) * radius, victim, false) -- NOTES(JBK): Only one guarantee.

    else
        fns.SpawnEmberAt(x, y, z, victim, true)

        if numembers > 1 then
            numembers = numembers - 1
            local theta0 = math.random() * 2 * PI
            local dtheta = 2 * PI / numembers
            local thetavar = dtheta / 10
            local theta, radius

            for i = 1, numembers do
                theta = GetRandomWithVariance(theta0 + dtheta * i, thetavar)
                radius = 1.6 + math.random() * .4
                fns.SpawnEmberAt(x + math.cos(theta) * radius, 0, z - math.sin(theta) * radius, victim, false) -- NOTES(JBK): Only one guarantee.
            end
        end
    end
end

local function GiveEmbers(inst, num, pos)
    local ember = SpawnPrefab("willow_ember")

    if ember.components.stackable ~= nil then
        ember.components.stackable:SetStackSize(num)
    end

    inst.components.inventory:GiveItem(ember, nil, pos)
end

local CREATURES_MUST = { "_combat" }
local CREATURES_CAN  = { "monster", "smallcreature", "largecreature", "animal", "bigbernie", "character" }
local CREATURES_CANT = { "FX", "INLIMBO", "DECOR", "playerghost", "NOCLICK", "ghost"}

-- Is also called from the client-side.
local function GetBurstTargets(player)
    local x, y, z = player.Transform:GetWorldPosition()

    local ents = TheSim:FindEntities(x, 0, z, TUNING.FIRE_BURST_RANGE, CREATURES_MUST, CREATURES_CANT, CREATURES_CAN)


    --filter out not burnables, things burning
    for i=#ents, 1, -1 do
        if not ents[i]:HasTag("canlight") and not ents[i]:HasTag("nolight") and not ents[i]:HasTag("fire")  then
            table.remove(ents,i)
        end
    end
    
    -- filter out things that are allies or followers of allies, but not burnable bernie
    for i=#ents, 1, -1 do
        local should_remove = false

        -- remove alies
        if player.replica.combat:IsAlly(ents[i]) or player.replica.combat:TargetHasFriendlyLeader(ents[i]) then
            should_remove = true     
        end
        -- remove companions
        if ents[i]:HasTag("companion") then
            should_remove = true
        end

        -- bring back a friendly burnable burnie
        if ents[i]:HasTag("bigbernie") and ents[i]:HasTag("canlight") and player.replica.combat:IsAlly(ents[i]) then
             should_remove = false
        end
        
        if should_remove then
            table.remove(ents,i)
        end
    end

    return ents
end

fns = {
    HasEmbers = HasEmbers,
    GetNumEmbers = GetNumEmbers,
    SpawnEmberAt = SpawnEmberAt,
    SpawnEmbersAt = SpawnEmbersAt,
    GiveEmbers = GiveEmbers,
    GetBurstTargets = GetBurstTargets,
}

return fns
