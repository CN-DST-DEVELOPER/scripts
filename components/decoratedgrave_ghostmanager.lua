--------------------------------------------------------------------------
--[[ Decorated Grave Ghost Manager class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "decoratedgrave_ghostmanager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local SPAWN_DISTANCE = 15.0001
local DESPAWN_DISTANCE = 20.0001
local UPDATE_RATE = 1

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _decorated_graves = {}
local _ghostfriends = {}
local _update_time = UPDATE_RATE

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function ghost_count()
    local count = 0
    for _, ghost in pairs(_decorated_graves) do
        if type(ghost) == "table" and ghost.prefab then
            count = count + 1
        end
    end
    return count
end

local function graves_near(ghostfriend)
    local graves = {}
    local test_x, test_y, test_z = ghostfriend.Transform:GetWorldPosition()
    for grave in pairs(_decorated_graves) do
        if grave:GetDistanceSqToPoint(test_x, test_y, test_z) < (SPAWN_DISTANCE * SPAWN_DISTANCE) then
            table.insert(graves, grave)
        end
    end
    return graves
end

local function stop_updating()
    self.inst:StopUpdatingComponent(self)

    for _, ghost in pairs(_decorated_graves) do
        if type(ghost) == "table" and ghost.prefab then
            ghost._despawn_queued = true
        end
    end
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnDecoratedGraveRemoved(grave)
    if _decorated_graves[grave] ~= nil then
        if type(_decorated_graves[grave]) == "table" and _decorated_graves[grave].prefab then
            _decorated_graves[grave]._despawn_queued = true
        end

        _decorated_graves[grave] = nil
    end

    inst:RemoveEventCallback("onremove", OnDecoratedGraveRemoved, grave)

    -- Want to == nil b/c we're using false as a meaningful value
    if next(_decorated_graves) == nil then
        stop_updating()
    end
end

local function OnPlayerJoined(src, player)
    if not player:HasTag("ghostlyfriend") then
        return
    end

    local currently_tracking = false
    for _, tracked_ghostfriend in pairs(_ghostfriends) do
        currently_tracking = true -- There's at least one currently tracked Wendy somewhere.
        if tracked_ghostfriend == player then
            return
        end
    end
    table.insert(_ghostfriends, player)

    if not currently_tracking then
        self.inst:StartUpdatingComponent(self)
    end
end

local function OnPlayerLeft(src, player)
    for idx, tracked_ghostfriend in pairs(_ghostfriends) do
        if tracked_ghostfriend == player then
            table.remove(_ghostfriends, idx)
            return
        end
    end

    if #_ghostfriends == 0 then
        stop_updating()
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

for _, player in pairs(AllPlayers) do
    OnPlayerJoined(inst, player)
end
inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft)

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:RegisterDecoratedGrave(grave)
    if not grave or _decorated_graves[grave] ~= nil then return end

    -- Want to == nil b/c we're using false as a meaningful value
    if next(_decorated_graves) == nil then
        self.inst:StartUpdatingComponent(self)
    end

    -- False means we're aware of it, but it doesn't have a ghost.
    _decorated_graves[grave] = false

    inst:ListenForEvent("onremove", OnDecoratedGraveRemoved, grave)
end

function self:UnregisterDecoratedGrave(grave)
    if not grave or _decorated_graves[grave] == nil then return end

    OnDecoratedGraveRemoved(grave)
end

function self:OnUpdate(dt)
    _update_time = _update_time - dt
    if _update_time > 0 then
        return
    end

    _update_time = UPDATE_RATE

    for _, ghostfriend in pairs(_ghostfriends) do
        -- Testing here instead of OnJoined because the skills might not be set up yet at that time.
        if ghostfriend.components.skilltreeupdater and ghostfriend.components.skilltreeupdater:IsActivated("wendy_gravestone_1") then
            local graves_near_ghostfriend = graves_near(ghostfriend)
            if #graves_near_ghostfriend > 0 then
                local graves_with_ghosts_count = 0
                for _, grave in pairs(graves_near_ghostfriend) do
                    if type(_decorated_graves[grave]) == "table" and _decorated_graves[grave].prefab then
                        graves_with_ghosts_count = graves_with_ghosts_count + 1
                    end
                end
                if graves_with_ghosts_count < TUNING.WENDYSKILL_GRAVESTONE_GHOSTCOUNT then
                    for _, grave in pairs(graves_near_ghostfriend) do
                        local ghost = _decorated_graves[grave]
                        if not ghost then
                            local new_ghost = SpawnPrefab("graveguard_ghost")
                            new_ghost.Transform:SetPosition(grave.Transform:GetWorldPosition())

                            grave.ghost = new_ghost
                            new_ghost:LinkToHome(grave)

                            _decorated_graves[grave] = new_ghost
                            self.inst:ListenForEvent("onremove", function()
                                if grave and grave:IsValid() then
                                    local time = (new_ghost.components.health:IsDead() and TUNING.WENDYSKILL_GRAVEGHOST_DEADTIME) or 5
                                    _decorated_graves[grave] = self.inst:DoTaskInTime(time, function()
                                        -- Something weird may have happened in the meantime;
                                        -- make sure we're in the same state.
                                        local grave_data = _decorated_graves[grave]
                                        if grave_data and type(grave_data) == "table" and not grave_data.prefab then
                                            _decorated_graves[grave] = false
                                        end
                                    end)
                                end
                            end, new_ghost)

                            break
                        end
                    end
                end
            end
        end
    end

    local gx, gy, gz
    local player, pdsq
    for _, ghost in pairs(_decorated_graves) do
        if type(ghost) == "table" and ghost.prefab then
            gx, gy, gz = ghost.Transform:GetWorldPosition()
            player, pdsq = FindClosestPlayer(gx, gy, gz, true)
            if pdsq == nil or pdsq > (DESPAWN_DISTANCE * DESPAWN_DISTANCE) then
                ghost._despawn_queued = true
            end
        end
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
	return "Grave Count: " .. tostring(GetTableSize(_decorated_graves)) .. "; Ghost Count: " .. tostring(ghost_count())
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)