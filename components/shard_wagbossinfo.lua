--------------------------------------------------------------------------
--[[ Shard_WagbossInfo ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Shard_WagbossInfo should not exist on client")

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _ismastershard = _world.ismastershard

--Network
local _isdefeated = net_bool(inst.GUID, "shard_wagbossinfo._isdefeated", "isdefeateddirty")

--------------------------------------------------------------------------
--[[ Public functions ]]
--------------------------------------------------------------------------

function self:IsWagbossDefeated()
    return _isdefeated:value()
end

--------------------------------------------------------------------------
--[[ Private event listeners ]]
--------------------------------------------------------------------------

local OnWagbossInfoUpdate = _ismastershard and function(src, data)
    _isdefeated:set(data.isdefeated)
end or nil

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

if _ismastershard then
    --Initialize variables
    if TheWorld.components.wagboss_tracker then
        _isdefeated:set(TheWorld.components.wagboss_tracker:IsWagbossDefeated())
    end

    --Register master shard events
    inst:ListenForEvent("master_wagbossinfoupdate", OnWagbossInfoUpdate, _world)
end

end)