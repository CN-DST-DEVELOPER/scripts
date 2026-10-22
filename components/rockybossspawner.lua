-- NOTE: This component also handles respawning a rocky if none exist on boss timer
--------------------------------------------------------------------------
--[[ RockyBossSpawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "RockyBossSpawner should not exist on client")

--------------------------------------------------------------------------
--[[ Private constants ]]
--------------------------------------------------------------------------

local ROCKYBOSS_TIMERNAME = "rockyboss_timetospawn"

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _worldsettingstimer = TheWorld.components.worldsettingstimer
local _herds = {}
local _boss = nil

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function TryBeginningRockyBossSpawns()
    -- this also handles spawning new rockies if non exist
    if not _worldsettingstimer:ActiveTimerExists(ROCKYBOSS_TIMERNAME) and _boss == nil then
        _worldsettingstimer:StartTimer(ROCKYBOSS_TIMERNAME, GetRandomWithVariance(TUNING.ROCKY_BOSS_SPAWNDELAY_BASE, TUNING.ROCKY_BOSS_SPAWNDELAY_RANDOM))
    end
    if _worldsettingstimer:IsPaused(ROCKYBOSS_TIMERNAME) then
        _worldsettingstimer:ResumeTimer(ROCKYBOSS_TIMERNAME)
    end
end

local function TryPauseRockyBossSpawns()
    if #_herds == 0 then
        _worldsettingstimer:PauseTimer(ROCKYBOSS_TIMERNAME)
    end
end

local function OnRemoveRockyBoss(boss)
    _boss = nil
    TryBeginningRockyBossSpawns()
end

local function OnDeathRockyBoss(boss)
    _boss = nil
    TryBeginningRockyBossSpawns()
    inst:RemoveEventCallback("onremove", OnRemoveRockyBoss, boss)
    inst:RemoveEventCallback("death", OnDeathRockyBoss, boss)
end

local function RegisterRockyBoss(boss)
    _boss = boss
    inst:ListenForEvent("onremove", OnRemoveRockyBoss, boss)
    inst:ListenForEvent("death", OnDeathRockyBoss, boss)
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:UpgradeRockyToBoss(rocky)
    local herd = rocky.components.herdmember:GetHerd()
    local rocky_boss = ReplacePrefab(rocky, "rocky_boss")
    if herd then
        herd.components.herd:AddMember(rocky_boss)
    end
    RegisterRockyBoss(rocky_boss)
end

function self:GetRockyBoss()
    return _boss
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRemoveRockyHerd(herd)
    for i, v in ipairs(_herds) do
        if v == herd then
            table.remove(_herds, i)
            return
        end
    end
end

local function OnRegisterRockyHerd(inst, herd)
    for i, v in ipairs(_herds) do
        if v == herd then
            return
        end
    end

    table.insert(_herds, herd)
    inst:ListenForEvent("onremove", OnRemoveRockyHerd, herd)
    if not POPULATING then -- Don't try when in populating period, because existing timers/boss hasnt loaded yet
        TryBeginningRockyBossSpawns()
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function DoRockyRegrowth()
    for area, densities in pairs(TheWorld.generated.densities) do
        if densities["rocky"] ~= nil then
            for i, v in ipairs(TheWorld.topology.ids) do
                if v == area then
                    local points_x, points_y = TheWorld.Map:GetRandomPointsForSite(TheWorld.topology.nodes[i].x, TheWorld.topology.nodes[i].y, TheWorld.topology.nodes[i].poly, 1)
                    local x = points_x[1]
                    local z = points_y[1]
                    if x and z and not IsAnyPlayerInRange(x, 0, z, PLAYER_CAMERA_SEE_DISTANCE) then
                        local pos = Vector3(x, 0, z)
                        for j = 1, 4 do
                            local offset = FindWalkableOffset(pos, math.random() * TWOPI, 3, 6, nil, nil, NoHoles) or Vector3(0, 0, 0)
                            local rocky = SpawnPrefab("rocky")
                            rocky.Transform:SetPosition(x + offset.x, 0, z + offset.z)
                        end

                        return
                    end
                end
            end
        end
    end
end

local function OnRockyBossTimerDone()
    if next(_herds) == nil then
        -- No herds! Let's add one!
        DoRockyRegrowth()
        return
    end

    local weightedherds = {}
    for i, v in ipairs(_herds) do
        weightedherds[v] = v.components.herd.membercount
    end

    local herd = weighted_random_choice(weightedherds)
    while herd do
        weightedherds[herd] = nil

        local members = shuffledKeys(herd.components.herd.members)
        for k, member in ipairs(members) do
            if member.prefab == "rocky" and member:IsAsleep() and member:IsMaxSize() then
                self:UpgradeRockyToBoss(member)
                return
            end
        end

        herd = weighted_random_choice(weightedherds)
    end

    -- Retry again, we didn't spawn rocky boss.
    _worldsettingstimer:StartTimer(ROCKYBOSS_TIMERNAME, GetRandomWithVariance(TUNING.ROCKY_BOSS_SPAWNDELAY_RETRY_BASE, TUNING.ROCKY_BOSS_SPAWNDELAY_RETRY_RANDOM))
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Register events
inst:ListenForEvent("ms_registerrockyherd", OnRegisterRockyHerd)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

function self:OnPostInit()
    _worldsettingstimer:AddTimer(ROCKYBOSS_TIMERNAME, TUNING.ROCKY_BOSS_SPAWNDELAY_BASE + TUNING.ROCKY_BOSS_SPAWNDELAY_RANDOM, TUNING.SPAWN_ROCKY_BOSS, OnRockyBossTimerDone)
    TryBeginningRockyBossSpawns()
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data = {}
    local ents

    if _boss then
        ents = {}
        data.boss = _boss.GUID
        table.insert(ents, _boss.GUID)
    end

    return data, ents
end

function self:LoadPostPass(newents, savedata)
	if savedata.boss ~= nil and newents[savedata.boss] ~= nil then
		_boss = newents[savedata.boss].entity
        RegisterRockyBoss(_boss)
	end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    local time_remaining = _worldsettingstimer:GetTimeLeft(ROCKYBOSS_TIMERNAME) or -1
    return string.format("Rocky exists: %s, Spawning in %.2f (%.2f days)", tostring(_boss ~= nil), time_remaining, time_remaining / TUNING.TOTAL_DAY_TIME)
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)