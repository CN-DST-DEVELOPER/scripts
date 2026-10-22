--------------------------------------------------------------------------
--[[ Shard_CharlieInfo ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Shard_CharlieInfo should not exist on client")

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld
local _ismastershard = _world.ismastershard

--Network
local _isdefeated = net_bool(inst.GUID, "shard_charlieinfo._isdefeated", "ischarliedefeateddirty")

function self:IsCharlieDefeated()
    return _isdefeated:value()
end
--------------------------------------------------------------------------
--[[ Private event listeners ]]
--------------------------------------------------------------------------

local function UpdateClientAccomplishment()
    SendRPCToClient(CLIENT_RPC.UpdateAccomplishment, nil, "charlie_defeated")
end

local OnCharlieDefeated = _ismastershard and function(src, data)
    _isdefeated:set(data.isdefeated)
    if data.isdefeated then
        UpdateClientAccomplishment()
    end
end or nil

local OnCharlieDefeatedDirty = not _ismastershard and function()
    local isdefeated = _isdefeated:value()
    _world:PushEvent("secondary_charlieinfoupdate", { isdefeated = isdefeated })
    if isdefeated then
        UpdateClientAccomplishment()
    end
end or nil

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

if _ismastershard then
    --Register master shard events
    inst:ListenForEvent("master_charlieinfoupdate", OnCharlieDefeated, _world)
else
    --Register network variable sync events
    inst:ListenForEvent("ischarliedefeateddirty", OnCharlieDefeatedDirty)
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
