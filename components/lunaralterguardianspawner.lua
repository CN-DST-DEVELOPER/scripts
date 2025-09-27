--------------------------------------------------------------------------
--[[ Lunar Alter Guardian Spawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Lunar Alter Guardian Spawner should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local SPAWN_DIST = 10

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _activeguardian = nil

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function GetSpawnPoint(pt)
    if not TheWorld.Map:IsAboveGroundAtPoint(pt:Get()) then
        pt = FindNearbyLand(pt, 1) or pt
    end

    local offset = FindWalkableOffset(pt, math.random() * TWOPI, SPAWN_DIST, 12, true, true, NoHoles)
    if offset then
        offset.x = offset.x + pt.x
        offset.z = offset.z + pt.z
        return offset
    end
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:GetGuardian()
    return _activeguardian
end

function self:HasGuardianOrIsPending()
    return self.guardiancomingpt or _activeguardian ~= nil
end

function self:KickOffSpawn(delay)
    self.inst:DoTaskInTime(delay, function(i)
        _activeguardian = SpawnPrefab("alterguardian_phase1_lunarrift")
        _activeguardian.Physics:Teleport(self.guardiancomingpt:Get())

        _activeguardian:ListenForEvent("onremove", function()
            _activeguardian = nil
        end)

        _activeguardian.sg:GoToState("spawn_lunar")
        self.guardiancomingpt = nil
    end)
end

function self:TrySpawnLunarGuardian(spawner)
    if not spawner or _activeguardian or self.guardiancomingpt then return end

    local pt = spawner:GetPosition()
    local spawn_pt = GetSpawnPoint(pt)
    if spawn_pt then
        self.guardiancomingpt = spawn_pt
		self:KickOffSpawn(spawner.prefab == "wagstaff_npc_wagpunk_arena" and 14 or 4)
    end
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data, ents = {}, {}
    if _activeguardian ~= nil then
        data.activeguid = _activeguardian.GUID
        table.insert(ents, _activeguardian.GUID)
    end
    if self.guardiancomingpt then
        data.guardiancomingpt_x = self.guardiancomingpt.x
        data.guardiancomingpt_z = self.guardiancomingpt.z
    end
    return data, ents
end

function self:OnLoad(data)
    if not data then
        return
    end

    if data.guardiancomingpt_x and data.guardiancomingpt_z then
        self.guardiancomingpt = Vector3(data.guardiancomingpt_x, 0, data.guardiancomingpt_z)
        self:KickOffSpawn(4)
    end
end

function self:LoadPostPass(newents, data)
    if data.activeguid and newents[data.activeguid] then
        _activeguardian = newents[data.activeguid].entity
        _activeguardian:ListenForEvent("onremove", function()
            _activeguardian = nil
        end)
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:_Debug_SpawnGuardian(player)
    self:TrySpawnLunarGuardian((player or ThePlayer).Transform:GetWorldPosition())
end

end)