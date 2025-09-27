--------------------------------------------------------------------------
--[[ WanderingTraderSpawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)
assert(TheWorld.ismastersim, "WanderingTraderSpawner should not exist on client")
self.inst = inst

self.spawnpoints = {}
self.spawnpoints_masters = {}

self.OnRemove_wanderingtrader = function(wanderingtrader, data)
    self.wanderingtrader = nil
end
function self:TrackWanderingTrader(wanderingtrader)
    self.wanderingtrader = wanderingtrader
    wanderingtrader:ListenForEvent("onremove", self.OnRemove_wanderingtrader)
end

function self:SpawnWanderingTrader() -- Use TryToSpawnWanderingTrader externally.
    local wanderingtrader = SpawnPrefab("wanderingtrader")
    self:TrackWanderingTrader(wanderingtrader)
    return wanderingtrader
end

function self:TryToSpawnWanderingTrader()
    if self.wanderingtrader then
        return false
    end

    if not self.spawnpoints[1] and not self.spawnpoints_masters[1] then
        return false
    end

    shuffleArray(self.spawnpoints)
    local spawnpoint = self.spawnpoints[1]
    if not spawnpoint then
        shuffleArray(self.spawnpoints_masters)
        spawnpoint = self.spawnpoints_masters[1]
    end

    self:SpawnWanderingTrader()
    self.wanderingtrader.Transform:SetPosition(spawnpoint.Transform:GetWorldPosition())
end

function self:RemoveWanderingTrader()
    if self.wanderingtrader then
        self.wanderingtrader:Remove()
    end
end


function self:OnSave()
    local data, ents = {}, {}
    if self.wanderingtrader then
        data.wanderingtrader = self.wanderingtrader.GUID
        table.insert(ents, self.wanderingtrader.GUID)
    end
    return data, ents
end

function self:LoadPostPass(newents, savedata)
    if savedata.wanderingtrader then
        if newents[savedata.wanderingtrader] then
            local wanderingtrader = newents[savedata.wanderingtrader].entity
            self:TrackWanderingTrader(wanderingtrader)
        end
    end
end


self.UnregisterSpawnPoint_Master = function(spawnpoint)
    table.removearrayvalue(self.spawnpoints_masters, spawnpoint)
end
self.UnregisterSpawnPoint = function(spawnpoint)
    table.removearrayvalue(self.spawnpoints, spawnpoint)
end

self.OnRegisterSpawnPoint = function(inst, spawnpoint)
    if spawnpoint.master then
        if table.contains(self.spawnpoints_masters, spawnpoint) then
            return
        end
        table.insert(self.spawnpoints_masters, spawnpoint)
        spawnpoint:ListenForEvent("onremove", self.UnregisterSpawnPoint_Master)
    else
        if table.contains(self.spawnpoints, spawnpoint) then
            return
        end
        table.insert(self.spawnpoints, spawnpoint)
        spawnpoint:ListenForEvent("onremove", self.UnregisterSpawnPoint)
    end
end

inst:ListenForEvent("ms_registerspawnpoint", self.OnRegisterSpawnPoint)


self.OnWorldPostInit = function(world)
    if TUNING.WANDERINGTRADER_ENABLED then
        self:TryToSpawnWanderingTrader()
    else
        self:RemoveWanderingTrader()
    end
end

self.inst:DoTaskInTime(0, self.OnWorldPostInit)

end)
