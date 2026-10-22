return Class(function(self, inst)

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _ismastershard = _world.ismastershard

--------------------------------------------------------------------------
--[[ Public functions ]]
--------------------------------------------------------------------------

function self:IsCharlieDefeated()
    return _world.shard.components.shard_charlieinfo:IsCharlieDefeated()
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

if _ismastershard then function self:OnSave()
    local data = {}

    if self:IsCharlieDefeated() then
        data.isdefeated = true
    end

    return next(data) ~= nil and data or nil
end end

if _ismastershard then function self:LoadPostPass(newents, data)
    if data then
        if data.isdefeated then
            Shard_SyncCharlieDefeated(data.isdefeated)
        end
    end
end end

end)
