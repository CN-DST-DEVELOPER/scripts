--------------------------------------------------------------------------
--[[ Shadow Thrall Mimic spawning component definition ]]
--------------------------------------------------------------------------

local itemmimic_data = require("prefabs/itemmimic_data")

return Class(function(self, inst)

assert(TheWorld.ismastersim, "ShadowThrall_Mimics should not exist on client")

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _activeplayers = {}
local _activemimics = {}
local _scheduled_spawn_attempts = {}
local _rift_enabled_modifiers = SourceModifierList(inst, false, SourceModifierList.boolean)

--------------------------------------------------------------------------
--[[ Private event listeners ]]
--------------------------------------------------------------------------

local function on_mimic_removed(mimic)
    _activemimics[mimic] = nil
end

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function do_spawn(mimic_target)
    if mimic_target.components.itemmimic then -- No mimics of mimics.
        return false
    end

    local mx, _, mz = mimic_target.Transform:GetWorldPosition()
    local mpt = Vector3(mx, 0, mz)
    local radius = mimic_target:GetPhysicsRadius(0) * 2 + 0.5 + math.random() -- Times two for radius because the mimic will be a clone of the target.
    local offset = FindWalkableOffset(mpt, TWOPI * math.random(), radius, 8, true, false)
    if offset == nil then
        return false
    end

    local _, mxf = math.modf(mx)
    local _, mzf = math.modf(mz)
    mx = mx + offset.x
    mz = mz + offset.z
    if mxf + mzf < 0.0001 then -- NOTES(JBK): We have a geometrically placed item let us play on that to hide the mimic more.
        mx, mz = math.floor(mx), math.floor(mz)
    end

    local mimic = SpawnPrefab(mimic_target.prefab, mimic_target.skinname, mimic_target.skin_id)
    mimic:SetPersistData(mimic_target:GetPersistData())
    mimic:AddComponent("itemmimic")
    mimic.Transform:SetPosition(mx, 0, mz)
    _activemimics[mimic] = true
    self.inst:ListenForEvent("onremove", on_mimic_removed, mimic)

    local fx = SpawnPrefab("shadow_puff")
    fx.Transform:SetPosition(mx, 0, mz)

    return true
end

local function spawn_mimic_for(mimic_target)
    return do_spawn(mimic_target)
end

local function try_spawn_mimic_nearby(player, reschedule_fn)
    local keep_trying = false
    if GetTableSize(_activemimics) < TUNING.ITEMMIMIC_CAP then
        keep_trying = true
        local px, py, pz = player.Transform:GetWorldPosition()
        local mimicable_entities = shuffleArray(TheSim:FindEntities(
            px, py, pz, 15,
            itemmimic_data.MUST_TAGS, itemmimic_data.CANT_TAGS
        ))
        for _, mimicable_entity in pairs(mimicable_entities) do
            -- Mimics can spawn in the darkness OR if no player is in view range of them
            -- Players might catch a glimpse of that happening... but that's ok!
            if (not mimicable_entity:IsInLight() or mimicable_entity:IsAsleep())
                    and not mimicable_entity.components.itemmimic
                    and spawn_mimic_for(mimicable_entity) then
                keep_trying = false
                break
            end
        end
    end

    if not keep_trying then
        _scheduled_spawn_attempts[player]:Cancel()
        _scheduled_spawn_attempts[player] = nil

        reschedule_fn(player)
    end
end

local function StartSpawnAttemptForPlayer(player)
    if not _scheduled_spawn_attempts[player] then
        _scheduled_spawn_attempts[player] = player:DoPeriodicTask(10*(1 + math.random()), try_spawn_mimic_nearby, nil, StartSpawnAttemptForPlayer)
    end
end

local function TryUpdateScheduledSpawns(iscavenight)
    if not _rift_enabled_modifiers:Get() or not iscavenight then
        for player, task in pairs(_scheduled_spawn_attempts) do
            task:Cancel()
            _scheduled_spawn_attempts[player] = nil
        end
    else
        for _, player in pairs(_activeplayers) do
            StartSpawnAttemptForPlayer(player)
        end
    end
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRiftAddedToPool(_, data)
    if data and data.rift
            and self.inst.components.riftspawner
            and self.inst.components.riftspawner:RiftIsShadowAffinity(data.rift) then
        local first_modifier = _rift_enabled_modifiers:IsEmpty()
        _rift_enabled_modifiers:SetModifier(data.rift, true)
        if first_modifier then
            TryUpdateScheduledSpawns(inst.state.iscavenight)
        end
    end
end

local function OnRiftRemovedFromPool(_, data)
    if data and data.rift then
        _rift_enabled_modifiers:RemoveModifier(data.rift)
        if _rift_enabled_modifiers:IsEmpty() then
            TryUpdateScheduledSpawns(inst.state.iscavenight)
        end
    end
end

local function OnIsNightChanged(_, iscavenight)
    TryUpdateScheduledSpawns(iscavenight)
end

local function OnPlayerJoined(src, player)
    for _, active_player in pairs(_activeplayers) do
        if active_player == player then
            return
        end
    end

    if not next(_activeplayers) then
        inst:WatchWorldState("iscavenight", OnIsNightChanged)
    end
    table.insert(_activeplayers, player)
    if inst.state.iscavenight then
        OnIsNightChanged(inst, inst.state.iscavenight)
    end
end

local function OnPlayerLeft(src, player)
    local removed = table.removearrayvalue(_activeplayers, player)
    if removed ~= nil then
        -- Maybe do extra stuff here if the player was in our list?
        if _scheduled_spawn_attempts[removed] then
            _scheduled_spawn_attempts[removed]:Cancel()
            _scheduled_spawn_attempts[removed] = nil
        end
    end

    if not next(_activeplayers) then
        inst:StopWatchingWorldState("iscavenight", OnIsNightChanged)
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------
for _, player in pairs(AllPlayers) do
    table.insert(_activeplayers, player)
end

inst:ListenForEvent("ms_playerjoined", OnPlayerJoined, inst)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft, inst)
inst:ListenForEvent("ms_riftaddedtopool", OnRiftAddedToPool, inst)
inst:ListenForEvent("ms_riftremovedfrompool", OnRiftRemovedFromPool, inst)

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

-- A public test for whether a target can be mimiced, in case anyone wants to check.
function self.IsTargetMimicable(target)
    return target:HasTags(itemmimic_data.MUST_TAGS)
        and not target:HasOneOfTags(itemmimic_data.CANT_TAGS)
end

function self.SpawnMimicFor(item)
    if self.IsTargetMimicable(item) then
        return spawn_mimic_for(item)
    end
end

function self.IsEnabled()
    return _rift_enabled_modifiers:Get()
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self.GetDebugString()
    local debug_string = "ShadowThrall Mimics: %d/%d"
    debug_string = string.format(debug_string, GetTableSize(_activemimics), TUNING.ITEMMIMIC_CAP)

    if _rift_enabled_modifiers:Get() then
        debug_string = debug_string.."; ENABLED"
    else
        debug_string = debug_string.."; DISABLED"
    end

    return debug_string
end

function self.Debug_PlayerSpawns(player)
    StartSpawnAttemptForPlayer(player)
end

end)
