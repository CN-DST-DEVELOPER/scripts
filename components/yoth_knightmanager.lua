--------------------------------------------------------------------------
--[[ yoth_knightmanager class definition ]]
--------------------------------------------------------------------------
return Class(function(self, inst)
local _world = TheWorld
assert(_world.ismastersim, "Year of the Horse Knight Manager should not exist on client")

self.inst = inst
self.shrines = {}
self.princesses = {}
self.hats = {} -- Inverted table of self.princesses
self.rescheduletasks = {}

--------------------------------------------------------------------------
--[[ Shrines handling. ]]
--------------------------------------------------------------------------

function self:OnKnightShrineActivated(shrine)
    self.shrines[shrine] = true
end
local function OnKnightShrineActivated_Bridge(world, shrine)
    self:OnKnightShrineActivated(shrine)
end

function self:OnKnightShrineDeactivated(shrine)
    self.shrines[shrine] = nil
end
local function OnKnightShrineDeactivated_Bridge(world, shrine)
    self:OnKnightShrineDeactivated(shrine)
end

self.inst:ListenForEvent("ms_knightshrineactivated", OnKnightShrineActivated_Bridge, _world)
self.inst:ListenForEvent("ms_knightshrinedeactivated", OnKnightShrineDeactivated_Bridge, _world)

function self:IsKnightShrineActive()
    return next(self.shrines) ~= nil and IsSpecialEventActive(SPECIAL_EVENTS.YOTH)
end

function self:GetActiveKnightShrines()
    return self.shrines
end

--------------------------------------------------------------------------
--[[ Princess / Knight summon handling. ]]
--------------------------------------------------------------------------
local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

function self:IsOnCooldown(owner)
    if not owner.isplayer then
        -- This is not on a player so we must find a nearby player to blame.
        -- The inventory item is already off of the player at this point and we have many cases where we do not know who did it.
        -- So we will assume the closest player to the princess is the cause within a range.
        local x, y, z = owner.Transform:GetWorldPosition()
        local toblame = FindPlayersInRangeSortedByDistance(x, y, z, 9, true)
        for _, player in ipairs(toblame) do
            if not player:HasDebuff("yoth_princesscooldown_buff") then
                return false
            end
        end

        return true -- Objects cannot be blamed and are always on cooldown.
    end

    return owner:HasDebuff("yoth_princesscooldown_buff")
end

self.DoWarningSound = function(pos)
    SpawnPrefab("yothknightwarningsound").Transform:SetPosition(pos:Get())
end
self.SetupKnight = function(hat, pet, i, ...)
    pet:SetHorsemanOfTheAporkalypse(YOTH_HORSE_NAMES[i])
end
self.RevealKnight = function(pet)
    local x, y, z = pet.Transform:GetWorldPosition()
    SpawnPrefab("shadow_puff_solid_large").Transform:SetPosition(x, y, z)
    pet:ReturnToScene()
    pet:PushEventImmediate("spawned")
end
function self:SpawnKnights(hat, pos)
    self.DoWarningSound(pos)
    local numpets = #YOTH_HORSE_NAMES
    local maxdelayperpet = 1 / numpets
    for i = 1, numpets do
        local onspawnfn_old = hat.components.petleash.onspawnfn -- Hack hook to set the type before anything else gets the normal callback.
        hat.components.petleash:SetOnSpawnFn(function(hat, pet, ...)
            self.SetupKnight(hat, pet, i, ...)
            if onspawnfn_old then
                return onspawnfn_old(hat, pet, ...)
            end
        end)
        local spawnx, spawnz = pos.x, pos.z
        for r = 3, 1, -1 do
            local offset = FindWalkableOffset(pos, math.random() * TWOPI, r, 8, false, false, NoHoles)
            if offset then
                spawnx, spawnz = spawnx + offset.x, spawnz + offset.z
                break
            end
        end
        local pet = hat.components.petleash:SpawnPetAt(spawnx, 0, spawnz, "knight_yoth")
        hat.components.petleash:SetOnSpawnFn(onspawnfn_old) -- Unhook.

        if pet then
            pet:RemoveFromScene()
            local delayamount = (i - 1) / numpets
            pet:DoTaskInTime(0.75 + delayamount + maxdelayperpet * math.random() * 0.5, self.RevealKnight)
        end
    end
end

local function TryToSpawnKnights_Bridge(owner)
    self.rescheduletasks[owner] = nil
    self:TryToSpawnKnights(owner)
end
function self:RescheduleSpawnKnights(owner, timetocheck)
    if self.rescheduletasks[owner] then
        self.rescheduletasks[owner]:Cancel()
        self.rescheduletasks[owner] = nil
    end
    if not timetocheck then
        timetocheck = 5 + math.random()
    end
    self.rescheduletasks[owner] = owner:DoTaskInTime(timetocheck, TryToSpawnKnights_Bridge)
end

local KNIGHT_MUST_TAGS = {"gilded_knight"}
function self:TryToSpawnKnights(owner)
    local hat = self.princesses[owner]
    if not hat or not hat.components.petleash then
        return false
    end

    self:RescheduleSpawnKnights(owner) -- Always reschedule even when having knights.

    if self:IsOnCooldown(owner) then
        return false
    end

    local pos = owner:GetPosition()
    if TheSim:CountEntities(pos.x, pos.y, pos.z, 32, KNIGHT_MUST_TAGS) > 0 then
        return false
    end

    if owner:GetCurrentPlatform() ~= nil then
        return false
    end

    if hat.components.petleash:GetNumPetsForPrefab("knight_yoth") > 0 then
        return false
    end

    local offset = nil
    for r = 6, 20, 2 do
        offset = FindWalkableOffset(pos, math.random() * TWOPI, r, 12, false, false, NoHoles)
        if offset then
            break
        end
    end
    if offset == nil then
        return false
    end

    self:SpawnKnights(hat, pos + offset)
    return true
end

function self:RegisterPrincess(owner, hat)
    if not self.princesses[owner] then
        self.princesses[owner] = hat
        self.hats[hat] = owner
        if self:IsOnCooldown(owner) then
            local x, y, z = owner.Transform:GetWorldPosition()
            if TheSim:CountEntities(x, y, z, 16, KNIGHT_MUST_TAGS) == 0 then
                owner:PushEvent("yoth_oncooldown") -- for wisecracker
            end
        end
        self:RescheduleSpawnKnights(owner, 0.5 + math.random() * 0.25) -- Put on a small delay task to make it seem less instant.
    end
end
local function RegisterPrincess_Bridge(world, data)
    if data and data.owner and data.hat then
        self:RegisterPrincess(data.owner, data.hat)
    end
end

function self:UnregisterPrincess(owner, hat)
    if self.princesses[owner] == hat then
        owner:PushEvent("yoth_oncooldown_cancel") -- for wisecracker
        self.princesses[owner] = nil
        self.hats[hat] = nil
        if self.rescheduletasks[owner] then
            self.rescheduletasks[owner]:Cancel()
            self.rescheduletasks[owner] = nil
        end
    end
end
local function UnregisterPrincess_Bridge(world, data)
    if data and data.owner and data.hat then
        self:UnregisterPrincess(data.owner, data.hat)
    end
end

self.inst:ListenForEvent("ms_register_yoth_princess", RegisterPrincess_Bridge, _world)
self.inst:ListenForEvent("ms_unregister_yoth_princess", UnregisterPrincess_Bridge, _world)

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    return string.format("")
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
