local rift_portal_defs = require("prefabs/rift_portal_defs")
local RIFTPORTAL_CONST = rift_portal_defs.RIFTPORTAL_CONST
rift_portal_defs = nil

--------------------------------------------------------------------------------------------------------------

local HOST_CAN_SPAWN_TEST =
{
    rocky          = function() return TUNING.ROCKYHERD_SPAWNER_DENSITY > 0 end,
    bunnyman       = function() return TUNING.RABBITHOUSE_ENABLED           end,
    spider         = function() return TUNING.SPIDERDEN_ENABLED             end,
    spider_dropper = function() return TUNING.DROPPERWEB_ENABLED            end,
    spider_warrior = function() return TUNING.SPIDERDEN_ENABLED             end,
}

local WEIGHTED_HOSTS_TABLE = {
    rocky          = 0.20,
    bunnyman       = 0.40,
    spider         = 0.20,
    spider_dropper = 0.12,
    spider_warrior = 0.08,
}

local TALK_PERIOD = 5
local JOIN_TARGET_DELAY = 3

--------------------------------------------------------------------------------------------------------------

local function OnPlayerJoined(inst, player)
    if inst.components.shadowparasitemanager ~= nil then
        inst.components.shadowparasitemanager:OnPlayerJoined(player)
    end
end

local function OnPlayerLeft(inst, player)
    if inst.components.shadowparasitemanager ~= nil then
        inst.components.shadowparasitemanager:OnPlayerLeft(player)
    end
end

local function OnRiftAddedToPool(inst, data)
    if inst.components.shadowparasitemanager ~= nil then
        inst.components.shadowparasitemanager:OnRiftAddedToPool()
    end
end

--------------------------------------------------------------------------------------------------------------

local function SpawnFloater(inst, pos)
    if inst.components.shadowparasitemanager ~= nil then
        inst.components.shadowparasitemanager:SpawnFloater(pos)
    end
end

local function DoParasiteGroupTalk(inst)
    if inst.components.shadowparasitemanager ~= nil then
        inst.components.shadowparasitemanager:DoParasiteGroupTalk()
    end
end

--------------------------------------------------------------------------------------------------------------

local ShadowParasiteManager = Class(function(self, inst)
    assert(TheWorld.ismastersim, "Shadow Parasite Manager should not exist on client.")

    self.inst = inst

    self._activeplayers = { --[[ player = true ]] }
    self._targetplayers = { --[[ player = true ]] }
    self._targetuserids = { --[[ userid = true ]] } -- Players who left while being target.

    self._parasites = { --[[ inst = true ]] }
    self._floaters  = { --[[ inst = true ]] }

    self.num_waves = 0

    self._WEIGHTED_HOSTS_TABLE = WEIGHTED_HOSTS_TABLE -- Mods.
    self._HOST_CAN_SPAWN_TEST = HOST_CAN_SPAWN_TEST -- Mods.

    -- Initialization.
    self:ApplyWorldSettings()

    for _, player in ipairs(AllPlayers) do
        self:OnPlayerJoined(player)
    end

    -- Registering events.
    self.inst:ListenForEvent("ms_playerjoined",    OnPlayerJoined   )
    self.inst:ListenForEvent("ms_playerleft",      OnPlayerLeft     )
    self.inst:ListenForEvent("ms_riftaddedtopool", OnRiftAddedToPool)
end)

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:ApplyWorldSettings()
    for prefab, _ in pairs(self._WEIGHTED_HOSTS_TABLE) do
        if self._HOST_CAN_SPAWN_TEST[prefab] ~= nil and not self._HOST_CAN_SPAWN_TEST[prefab]() then
            self._WEIGHTED_HOSTS_TABLE[prefab] = nil
        end
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:OnPlayerJoined(player)
    if self._activeplayers[player] ~= nil then
        return
    end

    self._activeplayers[player] = true

    if self._targetuserids[player.userid] ~= nil then
        self:SpawnParasiteWaveForPlayer(player, true)

        self._targetuserids[player.userid] = nil
    end
end

function ShadowParasiteManager:OnPlayerLeft(player)
    if self._activeplayers[player] == nil then
        return
    end

    if self._targetplayers[player] then
        self._targetuserids[player.userid] = true
    end

    self._activeplayers[player] = nil
    self._targetplayers[player] = nil
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:AddParasiteToHost(host)
    local mask = SpawnPrefab("shadow_thrall_parasitehat")

    host.components.inventory:GiveItem(mask)
    host.components.inventory:Equip(mask)

    return host, mask -- Returning mask for mods.
end

function ShadowParasiteManager:ChoseHostCreature()
    return weighted_random_choice(self._WEIGHTED_HOSTS_TABLE)
end

function ShadowParasiteManager:SpawnHostCreature()
    local choice = self:ChoseHostCreature()

    if choice == nil then
        return
    end

    local host = SpawnPrefab(choice)

    if host ~= nil then
        self:AddParasiteToHost(host)

        if host.components.spawnfader ~= nil then
            host.components.spawnfader:FadeIn()
        end
    end

    return host
end

--------------------------------------------------------------------------------------------------------------

local function IsValidSpawnPoint(pt)
    return not TheWorld.Map:IsPointNearHole(pt) or not IsAnyPlayerInRange(pt.x, 0, pt.z, PLAYER_CAMERA_SEE_DISTANCE)
end

local function SuggestTarget(inst, target)
    if target:IsValid() and not target:HasTag("shadowthrall_parasite_mask") then
        inst.components.combat:SuggestTarget(target)
    end
end

function ShadowParasiteManager:SpawnParasiteWaveForPlayer(player, joining)
    if self:GetShadowRift() == nil then
        return
    end

    local pt = player:GetPosition()

    local num = 5 + math.random(3)
    for i=1, num do
        local offset = FindWalkableOffset(pt, math.random()*TWOPI, PLAYER_CAMERA_SEE_DISTANCE+(math.random()*12), 16, nil, nil, IsValidSpawnPoint)

        if offset ~= nil then
            local host = self:SpawnHostCreature()

            if host ~= nil then
                local np = pt + offset

                host.Transform:SetPosition(np:Get())
                host.SoundEmitter:PlaySound("hallowednights2024/thrall_parasite/appear_taunt_offscreen")

                if joining then
                    host:DoTaskInTime(JOIN_TARGET_DELAY, SuggestTarget, player)
                else
                    SuggestTarget(host, player)
                end
            end
        end
    end
end

function ShadowParasiteManager:OnRiftAddedToPool()
    if POPULATING then
        return -- Rifts added during loading don't count!
    end

    self.num_waves = self.num_waves + 1
end

function ShadowParasiteManager:GetShadowRift()
    local riftspawner = TheWorld.components.riftspawner

    if not riftspawner then
        return
    end

    local rifts = riftspawner:GetRiftsOfAffinity(RIFTPORTAL_CONST.AFFINITY.SHADOW)

    if rifts == nil then
        -- No shadow affinity rifts.
        return
    end

    return rifts[1]
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:DoParasiteGroupTalk()
    local strid = math.random(#STRINGS.SHADOWTHRALL_PARASITE_CHANT)

    for parasite, _ in pairs(self._parasites) do
        parasite:DoTaskInTime(math.random()*1, parasite.SaySpeechLine, strid)
    end
end

function ShadowParasiteManager:StartTalkTask()
    if self._talktask ~= nil then
        self._talktask:Cancel()
    end

    self._talktask = self.inst:DoPeriodicTask(TALK_PERIOD, DoParasiteGroupTalk)
end

function ShadowParasiteManager:StartTrackingParasite(parasite)
    if self._parasites[parasite] ~= nil then
        return
    end

    self._parasites[parasite] = true

    self.inst:ListenForEvent("onremove", function(inst) self:StopTrackingParasite(inst) end, parasite)

    if self._talktask == nil then
        self:StartTalkTask()
    end
end

function ShadowParasiteManager:StopTrackingParasite(parasite)
    self._parasites[parasite] = nil

    if not next(self._parasites) and self._talktask ~= nil then
        self._talktask:Cancel()
        self._talktask = nil
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:OnFloaterRemoved(floater)
    self._floaters[floater] = nil

    if not next(self._floaters) then
        self:SpawnParasiteWaveForAllTargetPlayers()
    end
end

function ShadowParasiteManager:SpawnFloater(pos)
    local offset = FindWalkableOffset(pos, math.random()*TWOPI, 3, 8)

    if offset ~= nil then
        local floater = SpawnPrefab("shadowthrall_parasite")
        floater.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)

        floater.SoundEmitter:PlaySound("hallowednights2024/thrall_parasite/appear_rift")

        self._floaters[floater] = true

        self.inst:ListenForEvent("onremove", function(inst) self:OnFloaterRemoved(inst) end, floater)

        --local fx = SpawnPrefab("shadow_puff") -- FIXME(DiogoW): Was this never positioned?

        return floater
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:SpawnParasiteWaveForAllTargetPlayers()
    for player, _ in pairs(self._targetplayers) do
        self:SpawnParasiteWaveForPlayer(player)

        self._targetplayers[player] = nil
    end
end

function ShadowParasiteManager:BeginParasiteWave()
    local rift = self:GetShadowRift()

    if rift == nil then
        return
    end

    local x, y, z = rift.Transform:GetWorldPosition()
    local pos = Vector3(x, 0, z)

    self.num_waves = self.num_waves - 1

    if IsAnyPlayerInRange(x, 0, z, PLAYER_REVEAL_RADIUS) then
        local total = 6 + math.random(6)

        for i=1, total do
            self.inst:DoTaskInTime(math.random()*5, SpawnFloater, pos)
        end
    else
        self:SpawnParasiteWaveForAllTargetPlayers()
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:OverrideBlobSpawn(player)
    if self:GetShadowRift() == nil then
        return false
    end

    if not next(self._WEIGHTED_HOSTS_TABLE) then
        return false -- All creatures are disabled in world settings...
    end

    if self.num_waves > 0 and math.random() <= TUNING.SHADOWTHRALL_PARASITE_BLOBOVERRIDE then
        self._targetplayers[player] = true

        if not next(self._floaters) then
            self:BeginParasiteWave()
        end

        return true
    end
end

function ShadowParasiteManager:SpawnHostedPlayer(inst)
    local hosted = SpawnPrefab("player_hosted")

    if hosted == nil then
        return
    end

    self:AddParasiteToHost(hosted)

    hosted.skeleton_prefab = inst.skeleton_prefab
    hosted.hosted_userid:set(inst.userid)
    hosted.components.skinner:CopySkinsFromPlayer(inst)

    hosted.Transform:SetPosition(inst.Transform:GetWorldPosition())

    hosted:PushEvent("intro")

    return hosted -- Mods.
end

function ShadowParasiteManager:ReviveHosted(inst)
    inst.shadowthrall_parasite_hosted_death = nil

    if inst.components.follower ~= nil then
        inst.components.follower:StopFollowing()
    end

    if inst.components.combat ~= nil then
        inst.components.combat:DropTarget()
    end

    if inst.components.herdmember ~= nil then
        inst.components.herdmember:Enable(false)
    end

    -- FIXME(DiogoW): Things targetting us don't lose target... so parasites can attack each other in this case.

    local fx = SpawnPrefab("shadowthrall_parasite_fx")

    if fx ~= nil then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx.target = inst
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:OnSave()
    local data = {}

    if self.num_waves > 0 then
        data.num_waves = self.num_waves
    end

    local targetuserids = {}

    for player, _ in pairs(self._targetplayers) do
        targetuserids[player.userid] = true
    end

    for userid, _ in pairs(self._targetuserids) do
        targetuserids[userid] = true
    end

    if next(targetuserids) ~= nil then
        data.targetuserids = targetuserids
    end

    return next(data) ~= nil and data or nil
end

function ShadowParasiteManager:OnLoad(data)
    if data == nil then
        return
    end

    if data.num_waves ~= nil then
        self.num_waves = data.num_waves
    end

    if data.targetuserids ~= nil then
        for userid, _ in pairs(data.targetuserids) do
            self._targetuserids[userid] = true
        end
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("ms_playerjoined",    OnPlayerJoined   )
    self.inst:RemoveEventCallback("ms_playerleft",      OnPlayerLeft     )
    self.inst:RemoveEventCallback("ms_riftaddedtopool", OnRiftAddedToPool)

    if self._talktask ~= nil then
        self._talktask:Cancel()
        self._talktask = nil
    end
end

--------------------------------------------------------------------------------------------------------------

function ShadowParasiteManager:GetDebugString()
    return string.format(
        "Waves: %d   |   Parasites: %d (%d floaters)   |   Targets: %d",
        self.num_waves,
        GetTableSize(self._parasites),
        GetTableSize(self._floaters),
        GetTableSize(self._targetplayers)
    )
end

--------------------------------------------------------------------------------------------------------------

return ShadowParasiteManager
