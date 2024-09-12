--------------------------------------------------------------------------
--[[ rabbitkingmanager class definition ]]
--------------------------------------------------------------------------
return Class(function(self, inst)
local _world = TheWorld
local _map = _world.Map
assert(_world.ismastersim, "rabbitkingmanager should not exist on client")
self.inst = inst

-- Constants.
self.PERIODIC_TICK_TIME = 1 -- Housecleaning tasks.
self.STATES = {
    PASSIVE = 0,
    AGGRESSIVE = 1,
    LUCKY = 2,
}
self.ANNOUNCE_STRINGS = {
    [self.STATES.PASSIVE] = "ANNOUNCE_RABBITKING_PASSIVE", -- Passive is the default fallback case.
    [self.STATES.AGGRESSIVE] = "ANNOUNCE_RABBITKING_AGGRESSIVE",
    [self.STATES.LUCKY] = "ANNOUNCE_RABBITKING_LUCKY",
}
self.SPAWN_PREFABS = {
    [self.STATES.PASSIVE] = "rabbitking_passive", -- Passive is the default fallback case.
    [self.STATES.AGGRESSIVE] = "rabbitking_aggressive",
    [self.STATES.LUCKY] = "rabbitking_lucky",
}

-- Variables.
self.rabbitkingdata = nil
function self:ResetCounters()
    self.carrots_fed = 0
    self.carrots_fed_max = TUNING.RABBITKING_CARROTS_NEEDED + math.random(TUNING.RABBITKING_CARROTS_NEEDED_VARIANCE)
    self.naughtiness = 0
    self.naughtiness_max = TUNING.RABBITKING_NAUGHTINESS_NEEDED + math.random(TUNING.RABBITKING_NAUGHTINESS_NEEDED_VARIANCE)
end
self:ResetCounters()

-- Management.
self.NoHoles = function(pt)
    return not _world.Map:IsPointNearHole(pt)
end
function self:OnRemove_RabbitKing(rabbitking, data)
    self:UnTrackRabbitKing()
end
local function OnRemove_RabbitKing_Bridge(rabbitking, data)
    self:OnRemove_RabbitKing(rabbitking, data)
end
local function OnRemove_Player_Bridge(player, data)
    local rabbitking = self.rabbitkingdata.rabbitking
    local closestdsq, closestplayer
    for player, _ in pairs(self.rabbitkingdata.old_players) do
        if player:IsValid() then
            local dsq = rabbitking:GetDistanceSqToInst(player)
            if closestdsq == nil or dsq < closestdsq then
                closestdsq = dsq
                closestplayer = player
            end
        end
    end
    if closestplayer then
        self:ChangeRabbitKingLeash(closestplayer)
    else
        self:RemoveRabbitKing()
    end
end
function self:OnAttacked(rabbitking, data)
    local attacker = data ~= nil and data.attacker or nil
    if attacker and attacker:HasTag("player") then
        if rabbitking.rabbitking_kind == "aggressive" then
            self:ChangeRabbitKingLeash(attacker)
        else
            self:BecomeAggressive(rabbitking, attacker)
        end
    end
end
local function OnAttacked_Bridge(rabbitking, data)
    self:OnAttacked(rabbitking, data)
end
function self:LeashToPlayer(player)
    local old_players = self.rabbitkingdata.old_players -- Needed for safe table reference handling to keep this table out of garbage collection.
    if not old_players[player] then
        local function OnRemove_Player_OldPlayers(player, data)
            old_players[player] = nil
        end
        old_players[player] = OnRemove_Player_OldPlayers
        player:ListenForEvent("onremove", OnRemove_Player_OldPlayers)
        player:ListenForEvent("death", OnRemove_Player_OldPlayers)
    end

    self.rabbitkingdata.player = player
    player:ListenForEvent("onremove", OnRemove_Player_Bridge)
    player:ListenForEvent("death", OnRemove_Player_Bridge)

    local rabbitking = self.rabbitkingdata.rabbitking
    if rabbitking.rabbitking_kind == "aggressive" then
        self:TryToTeleportRabbitKingToLeash(rabbitking, player)
        rabbitking.components.combat:SuggestTarget(player)
    end
end
function self:IsValidPointForRabbitKing(x, y, z)
    -- NOTES(JBK): No boats no water just good ground.
    return TheWorld.Map:IsVisualGroundAtPoint(x, y, z)
end
local function BringMinions_Bridge(rabbitking, pt)
    if rabbitking.sg.currentstate.name == "burrowarrive" or rabbitking.sg.currentstate.name == "burrowto" then -- A successful state change.
        rabbitking:BringMinions(pt)
    end
end
function self:TryToTeleportRabbitKingToLeash(rabbitking, player)
    -- The player is on a boat and is not a good place to burrow to so let the Rabbit King leave.
    if not self:IsValidPointForRabbitKing(player.Transform:GetWorldPosition()) then
        self:RemoveRabbitKing(rabbitking)
        return
    end

    -- Chase after the target no escape from the Rabbit King.
    local dsq = rabbitking:GetDistanceSqToInst(player)
    if dsq > TUNING.RABBITKING_TELEPORT_DISTANCE_SQ then
        -- The Rabbit King is too far away from the player it will need to burrow up and seek out.
        local origin = player:GetPosition()
        local pt = self:GetRabbitKingSpawnPoint(origin)
        if pt == nil then
            pt = origin -- We do not want to fail here now.
        end
        if rabbitking:IsAsleep() then
            -- Stategraph is sleeping so we need to teleport it to the point manually and skip stategraph state.
            rabbitking.Physics:Teleport(pt:Get())
            rabbitking:PushEvent("burrowarrive")
        else
            rabbitking:PushEvent("burrowto", {destination = pt,})
        end
        rabbitking:DoTaskInTime(0, BringMinions_Bridge, pt)
    end
end
function self:BecomeAggressive(rabbitking, player)
    rabbitking = ReplacePrefab(rabbitking, "rabbitking_aggressive")
    self:TrackRabbitKingForPlayer(rabbitking, player)
    rabbitking:PushEvent("becameaggressive")
    return rabbitking
end
function self:TryToBecomeAggressive(rabbitking, player)
    if rabbitking.rabbitking_kind ~= "passive" then
        return nil
    end

    local x, y, z = rabbitking.Transform:GetWorldPosition()
    local players = FindPlayersInRangeSqSortedByDistance(x, y, z, TUNING.RABBITKING_MEATCHECK_DISTANCE_SQ, true)
    for _, testplayer in ipairs(players) do
        if HasMeatInInventoryFor(testplayer) then
            return self:BecomeAggressive(rabbitking, player)
        end
    end

    return nil
end
function self:DoHouseCleaning(rabbitking, player)
    rabbitking = self:TryToBecomeAggressive(rabbitking, player) or rabbitking
    if rabbitking.rabbitking_kind == "aggressive" then
        self:TryToTeleportRabbitKingToLeash(rabbitking, player)
    end
end
function self:TrackRabbitKingForPlayer(rabbitking, player)
    self.rabbitkingdata = {
        rabbitking = rabbitking,
        old_players = {}, -- Unsaved temporary table of players who the Rabbit King was leashed to at any time during the session.
        accumulator = 0, -- Unsaved for housecleaning.
    }
    self:LeashToPlayer(player)
    rabbitking:ListenForEvent("onremove", OnRemove_RabbitKing_Bridge)
    rabbitking:ListenForEvent("attacked", OnAttacked_Bridge)
    self.inst:StartUpdatingComponent(self)
    if rabbitking.rabbitking_kind ~= "aggressive" then
        rabbitking.OnEntitySleep = rabbitking.Remove
    end
end
function self:UnTrackRabbitKing()
    if self.rabbitkingdata.rabbitking:IsValid() then
        self.rabbitkingdata.rabbitking:RemoveEventCallback("onremove", OnRemove_RabbitKing_Bridge)
    end
    if self.rabbitkingdata.player:IsValid() then
        self.rabbitkingdata.player:RemoveEventCallback("onremove", OnRemove_Player_Bridge)
        self.rabbitkingdata.player:RemoveEventCallback("death", OnRemove_Player_Bridge)
    end
    for player, callback in pairs(self.rabbitkingdata.old_players) do
        if player:IsValid() then
            player:RemoveEventCallback("onremove", callback)
            player:RemoveEventCallback("death", callback)
        end
    end
    if self.rabbitkingdata.rabbitking.rabbitking_kind ~= "lucky" then
        self.cooldown = TUNING.RABBITKING_COOLDOWN
    end
    self.rabbitkingdata = nil
end
function self:ChangeRabbitKingLeash(player)
    if self.rabbitkingdata.player:IsValid() then
        self.rabbitkingdata.player:RemoveEventCallback("onremove", OnRemove_Player_Bridge)
        self.rabbitkingdata.player:RemoveEventCallback("death", OnRemove_Player_Bridge)
    end
    self:LeashToPlayer(player)
end

function self:GetRabbitKingSpawnPoint(pt)
    for r = TUNING.RABBITKING_SPAWN_DISTANCE, 4, -1 do
        local offset = FindWalkableOffset(pt, math.random() * TWOPI, r, 12, true, true, self.NoHoles)
        if offset ~= nil then
            offset.x = offset.x + pt.x
            offset.z = offset.z + pt.z
            return offset
        end
    end

    return nil
end
local function DoWarningSpeechFor_Bridge(player, rabbitking_kind)
    self:DoWarningSpeechFor(player, rabbitking_kind)
end
function self:OnRabbitKingReturnToScene(rabbitking)
    self.rabbitkingdata.introtask = nil

    rabbitking:ReturnToScene()
    rabbitking:PushEvent("burrowarrive")
    self.rabbitkingdata.player:DoTaskInTime(1 + math.random() * 0.5, DoWarningSpeechFor_Bridge, rabbitking.rabbitking_kind)
end
local function OnRabbitKingReturnToScene_Bridge(rabbitking)
    self:OnRabbitKingReturnToScene(rabbitking)
end
function self:CreateRabbitKingForPlayer_Internal(player, pt, forcedstate_string, params)
    local forcedstate = forcedstate_string and self.STATES[string.upper(forcedstate_string)] or nil
    local rabbitking_prefab = self.SPAWN_PREFABS[forcedstate or self:GetStateByItemCountsForPlayer(player)] or self.SPAWN_PREFABS[self.STATES.PASSIVE]
    local rabbitking = SpawnPrefab(rabbitking_prefab)
    if params == nil or not params.jumpfrominventory and not params.nopresentation then
        rabbitking:RemoveFromScene()
    end
    rabbitking.Transform:SetPosition(pt.x, 0, pt.z)
    if params then
        if params.home then
            if rabbitking.components.knownlocations then
                rabbitking.components.knownlocations:RememberLocation("home", params.home:GetPosition())
            end
            local homeseeker = rabbitking:AddComponent("homeseeker")
            homeseeker:SetHome(params.home)
        end
    end
    return rabbitking
end
function self:ShouldStopActions()
    return self.rabbitkingdata or self.pendingplayerload or self.cooldown
end
function self:GetRabbitKing()
    return self.rabbitkingdata and self.rabbitkingdata.rabbitking or nil
end
function self:GetTargetPlayer()
    return self.rabbitkingdata and self.rabbitkingdata.player or nil
end
function self:CreateRabbitKingForPlayer(player, pt_override, forcedstate_string, params)
    if self:ShouldStopActions() then
        return false, self.cooldown and "ON_COOLDOWN" or "ALREADY_EXISTS"
    end

    local pt = pt_override or self:GetRabbitKingSpawnPoint(player:GetPosition())
    if pt == nil or not self:IsValidPointForRabbitKing(pt:Get()) then
        return false, "NO_VALID_SPAWNPOINT"
    end

    local rabbitking = self:CreateRabbitKingForPlayer_Internal(player, pt, forcedstate_string, params)
    if rabbitking == nil then
        return false, "PREFAB_FAILED_TO_CREATE"
    end

    self:TrackRabbitKingForPlayer(rabbitking, player) -- Creates rabbitkingdata must be first.
    local needsintro = true
    if params then
        if params.jumpfrominventory then
            needsintro = false
            rabbitking:PushEvent("dropkickarrive", params)
        elseif params.nopresentation then
            needsintro = false
            self.rabbitkingdata.player:DoTaskInTime(0.25 + math.random() * 0.25, DoWarningSpeechFor_Bridge, rabbitking.rabbitking_kind)
        end
    end
    if needsintro then
        self.rabbitkingdata.introtask = rabbitking:DoTaskInTime(2 + math.random(), OnRabbitKingReturnToScene_Bridge)
    end
    self:ResetCounters()
    return true
end
function self:RemoveRabbitKing(rabbitking)
    rabbitking = rabbitking or self.rabbitkingdata.rabbitking
    if self.rabbitkingdata and self.rabbitkingdata.introtask ~= nil then
        self.rabbitkingdata.introtask:Cancel()
        self.rabbitkingdata.introtask = nil
        -- Rabbit King has not presented itself yet so silently remove the thing.
        rabbitking:Remove() -- Will call UnTrackRabbitKing.
    elseif rabbitking:IsAsleep() then
        rabbitking:Remove()
    else -- We need presentation if it is not sleeping.
        rabbitking:PushEvent("burrowaway")
    end
end
function self:TryForceRabbitKing_Internal(rabbitking) -- Used from c_spawn or other debug commands.
    if self.pendingplayerload then -- Reschedule if there are pending loads to keep trying until it is done loading.
        self.inst:DoTaskInTime(0, function() self:TryForceRabbitKing_Internal(rabbitking) end)
        return
    end

    local rabbitking_old = self:GetRabbitKing()
    if rabbitking_old then
        if rabbitking_old ~= rabbitking then
            if rabbitking:IsAsleep() then
                rabbitking:Remove()
            else
                rabbitking.sg:GoToState("burrowaway")
            end
        end
        return
    end

    if rabbitking:IsAsleep() then
        rabbitking:Remove()
        return
    end
    local x, y, z = rabbitking.Transform:GetWorldPosition()
    local player = FindClosestPlayer(x, y, z, true)
    if not player then
        rabbitking.sg:GoToState("burrowaway")
        return
    end

    if rabbitking.components.inventoryitem then
        rabbitking.components.inventoryitem.canbepickedup = true
        rabbitking.components.inventoryitem.canbepickedupalive = true
    end
    self:TrackRabbitKingForPlayer(rabbitking, player)
    self:ResetCounters()
    self.cooldown = nil
end

function self:CanFeedCarrot(player)
    if self:ShouldStopActions() then
        return false
    end

    return self.carrots_fed < self.carrots_fed_max
end
function self:AddCarrotFromPlayer(player, receiver)
    if self:ShouldStopActions() then -- This will eat the carrot but it is better than having a bad state.
        return
    end

    self.carrots_fed = self.carrots_fed + 1
    if self.carrots_fed >= self.carrots_fed_max then
        self:CreateRabbitKingForPlayer(player)
    end
    local instwithsoundemitter = receiver.SoundEmitter and receiver or player.SoundEmitter and player or nil
    if instwithsoundemitter then
        self:PlayCarrotSoundFor(instwithsoundemitter)
    end
end
function self:GetCarrotSoundData() -- FIXME(JBK): Sounds.
    if self:ShouldStopActions() then
        return "dontstarve/rabbit/scream", 1, nil
    end

    return "dontstarve/rabbit/scream_short", self.carrots_fed / self.carrots_fed_max, 1.5
end
local function OnSoundCooldown_Carrot(inst)
    inst.rabbitking_sfx_carrot_cooldown = nil
end
function self:PlayCarrotSoundFor(inst)
    local sound, strength, cooldown = self:GetCarrotSoundData()
    if not cooldown or inst.rabbitking_sfx_carrot_cooldown == nil then
        inst.SoundEmitter:PlaySound(sound, nil, strength)
        if cooldown then
            inst.rabbitking_sfx_carrot_cooldown = true
            inst:DoTaskInTime(cooldown, OnSoundCooldown_Carrot)
        end
    end
end


function self:AddNaughtinessFromPlayer(player, naughtiness)
    if self:ShouldStopActions() then -- This will eat the kill event but it is better than having a bad state.
        return
    end

    self.naughtiness = self.naughtiness + naughtiness
    if self.naughtiness >= self.naughtiness_max then
        self:CreateRabbitKingForPlayer(player, nil, "aggressive")
    end
    local instwithsoundemitter = player.SoundEmitter and player or nil
    if instwithsoundemitter then
        self:PlayNaughtinessSoundFor(instwithsoundemitter)
    end
end
function self:GetNaughtinessSoundData() -- FIXME(JBK): Sounds.
    if self:ShouldStopActions() then
        return "dontstarve/rabbit/beardscream", 1, nil
    end

    return "dontstarve/rabbit/beardscream_short", self.naughtiness / self.naughtiness_max, 1.5
end
local function OnSoundCooldown_Naughtiness(inst)
    inst.rabbitking_sfx_naughtiness_cooldown = nil
end
function self:PlayNaughtinessSoundFor(inst)
    local sound, strength, cooldown = self:GetNaughtinessSoundData()
    if not cooldown or inst.rabbitking_sfx_naughtiness_cooldown == nil then
        inst.SoundEmitter:PlaySound(sound, nil, strength)
        if cooldown then
            inst.rabbitking_sfx_naughtiness_cooldown = true
            inst:DoTaskInTime(cooldown, OnSoundCooldown_Naughtiness)
        end
    end
end

function self:DoWarningSpeechFor(player, rabbitking_kind)
    if player.components.talker then
        local str = self.ANNOUNCE_STRINGS[self.STATES[string.upper(rabbitking_kind)]] or self.ANNOUNCE_STRINGS[self.STATES.PASSIVE]
        player.components.talker:Say(GetString(player, str))
    end
end

-- Item counting.
function self:GetStateByItemCountsForPlayer(player)
    if HasMeatInInventoryFor(player) then
        return self.STATES.AGGRESSIVE
    end

    return self.STATES.PASSIVE
end

-- Init.
self.OnPlayerKilledOther = function(player, data)
    local victim = data and data.victim or nil
    if victim == nil then
        return
    end

    if victim:HasAnyTag("rabbit", "manrabbit") then
        local naughtiness = FunctionOrValue(NAUGHTY_VALUE[victim.prefab] or 1, player, data)
        self:AddNaughtinessFromPlayer(player, naughtiness)
    end
end
self.OnPlayerJoined = function(_world, player)
    self.inst:ListenForEvent("killed", self.OnPlayerKilledOther, player)
end
self.OnPlayerLeft = function(_world, player)
    self.inst:RemoveEventCallback("killed", self.OnPlayerKilledOther, player)
end
for _, v in ipairs(AllPlayers) do
    self.OnPlayerJoined(v)
end
self.inst:ListenForEvent("ms_playerjoined", self.OnPlayerJoined)
self.inst:ListenForEvent("ms_playerleft", self.OnPlayerLeft)

-- OnUpdate for house cleaning.
function self:OnUpdate(dt)
    if self.rabbitkingdata then
        local dotick = false
        local accumulator = self.rabbitkingdata.accumulator + dt
        if accumulator > self.PERIODIC_TICK_TIME then
            accumulator = 0
            dotick = true
        end
        self.rabbitkingdata.accumulator = accumulator
        if dotick then
            local rabbitking = self.rabbitkingdata.rabbitking
            if rabbitking.persists then
                local player = self.rabbitkingdata.player
                if player:IsValid() then -- Needed because the burrowaway presentation won't remove the player ref and expects to always have a player ref even if it's invalid until data is purged.
                    self:DoHouseCleaning(rabbitking, player)
                end
            end
        end
    end
    if self.cooldown then
        self.cooldown = self.cooldown - dt
        if self.cooldown < 0 then
            self.cooldown = nil
            self.inst:StopUpdatingComponent(self)
        end
    end
end
function self:LongUpdate(dt)
    self:OnUpdate(dt)
end

-- Save/Load.
function self:SetSaveDataForMetaData(savedata, playermetadata, t)
    local should_save = false

    if playermetadata.next_wave_time ~= nil then
        savedata.next_wave_time = playermetadata.next_wave_time - t
        should_save = true
    end

    if playermetadata.spawn_wave_time ~= nil then
        savedata.spawn_wave_time = playermetadata.spawn_wave_time - t
        savedata.target_prefab_count = playermetadata.target_prefab_count
        should_save = true
    end

    return should_save
end
function self:OnSave()
    local data = {
        carrots_fed_max = self.carrots_fed_max,
        naughtiness_max = self.naughtiness_max,
        cooldown = self.cooldown,
    }
    local ents

    if self.carrots_fed > 0 then
        data.carrots_fed = self.carrots_fed
    end
    if self.naughtiness > 0 then
        data.naughtiness = self.naughtiness
    end

    if self.rabbitkingdata and self.rabbitkingdata.rabbitking.persists then
        data = data or {}
        data.rabbitkingid = self.rabbitkingdata.rabbitking.GUID
        data.playerid = self.rabbitkingdata.player.userid
        if self.rabbitkingdata.rabbitking.components.homeseeker and self.rabbitkingdata.rabbitking.components.homeseeker.home:IsValid() then
            data.homeid = self.rabbitkingdata.rabbitking.components.homeseeker.home.GUID
        end
        ents = ents or {}
        table.insert(ents, data.rabbitkingid)
        if data.homeid then
            table.insert(ents, data.homeid)
        end
    end

    return data, ents
end
function self:OnLoad(data)
    if data == nil then
        return
    end

    self.carrots_fed = data.carrots_fed or self.carrots_fed
    self.carrots_fed_max = data.carrots_fed_max or self.carrots_fed_max
    self.naughtiness = data.naughtiness or self.naughtiness
    self.naughtiness_max = data.naughtiness_max or self.naughtiness_max
    self.cooldown = data.cooldown or self.cooldown
    if self.cooldown then
        self.inst:StartUpdatingComponent(self)
    end
end
function self:LoadPostPass(newents, savedata)
    if savedata.rabbitkingid then
        if newents[savedata.rabbitkingid] then
            local rabbitking = newents[savedata.rabbitkingid].entity
            self.pendingplayerload = true
            local function ClearExpireRabbit()
                if self.checkforplayer_task ~= nil then
                    self.checkforplayer_task:Cancel()
                    self.checkforplayer_task = nil
                end
                self.pendingplayerload = nil
            end
            local function ExpireRabbit(rabbitking)
                self:RemoveRabbitKing(rabbitking)
                self.pendingplayerload = nil
            end
            local function CheckForPlayer(_world, player)
                if player.userid == savedata.playerid then
                    rabbitking:RemoveEventCallback("ms_playerjoined", CheckForPlayer, TheWorld)
                    ClearExpireRabbit()
                    self:TrackRabbitKingForPlayer(rabbitking, player)
                end
            end
            self.checkforplayer_task = rabbitking:DoTaskInTime(5 * 60, ExpireRabbit) -- 5 minutes to let the player rejoin before it goes away.
            rabbitking:ListenForEvent("onremove", ClearExpireRabbit)
            rabbitking:ListenForEvent("ms_playerjoined", CheckForPlayer, TheWorld)
            if savedata.homeid and newents[savedata.homeid] then
                local homeseeker = rabbitking:AddComponent("homeseeker")
                homeseeker:SetHome(newents[savedata.homeid].entity)
            end
        end
    end
end

function self:GetDebugString()
    if not self.rabbitkingdata then
        if self.cooldown then
            return string.format("No Rabbit King, on cooldown: %.1f", self.cooldown)
        end
        return string.format("No Rabbit King, carrots: %d/%d, naughtiness: %d/%d", self.carrots_fed, self.carrots_fed_max, self.naughtiness, self.naughtiness_max)
    end

    return string.format("RabbitKing: %s, Player: %s, HouseCleaning: %.1f", tostring(self.rabbitkingdata.rabbitking), tostring(self.rabbitkingdata.player), tostring(self.PERIODIC_TICK_TIME - self.rabbitkingdata.accumulator))
end

end)
