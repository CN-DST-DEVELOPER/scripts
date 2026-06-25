local function OnDeath(inst)
    if inst.components.socketholder then
        local items = inst.components.socketholder:UnsocketEverything()
        for _, item in ipairs(items) do
            Launch2(item, inst, 1, 1, 0.2, 0, 4)
        end
    end
end

local SocketHolder = Class(function(self, inst)
    self.inst = inst
	self.ismastersim = TheWorld.ismastersim

    self.socketed = {} -- Netvars.
    self.socketquality = {} -- Netvars.
    self.socketnames = {} -- Netvars.
    --self.maxsockets = nil

    -- Server only.
    if self.ismastersim then
        self.socketmetadata = {} -- Unsaved data that is extracted from the socketable before serializing it off.
        self.socketdata = {
            --[integer position] = [ConvertItemToSaveData output for inst],
        }

        self.dropondeath = true
        self.inst:ListenForEvent("death", OnDeath)
    end
end)


-- Common interface

function SocketHolder:SetMaxSockets(maxsockets)
    assert(self.maxsockets == nil, "SetMaxSockets can only be called once due to netvar use!")
    self.maxsockets = maxsockets
    -- Intentionally split so the more frequently changed netvars are lumped together at the top.
    for i = 1, self.maxsockets do
        self.socketed[i] = net_bool(self.inst.GUID, "socketholder.socketed" .. i, "onsocketeddirty" .. i)
    end
    local socketquality_net_enum = GetIdealUnsignedNetVarForCount(SOCKETQUALITY_MAXVALUE)
    for i = 1, self.maxsockets do
        self.socketquality[i] = socketquality_net_enum(self.inst.GUID, "socketholder.socketquality" .. i)
    end
    for i = 1, self.maxsockets do
        self.socketnames[i] = net_hash(self.inst.GUID, "socketholder.socketname" .. i)
    end
end

function SocketHolder:SetSocketPositionName(socketposition, socketname)
    local oldval = self.socketnames[socketposition]:value()
    if self.ismastersim then
        local hashed = socketname and hash(socketname) or 0
        if hashed ~= oldval and oldval ~= 0 then
            local item = self:UnsocketPosition(socketposition)
            if item then
                local x, y, z = self.inst.Transform:GetWorldPosition()
                if item.components.inventoryitem then
                    item.components.inventoryitem:DoDropPhysics(x, y, z, true)
                else
                    item.Transform:SetPosition(x, y, z)
                end
            end
        end
    end
    self.socketnames[socketposition]:set(socketname)
end

-- GetAllX

function SocketHolder:GetAllSocketPositions(socketname)
    local positions
    local hashed = socketname and hash(socketname) or nil
    for socketposition, netvar in ipairs(self.socketnames) do
        local netvarvalue = netvar:value()
        local issocketed_fromload = self.isloading and self.socketed[socketposition]:value() and self.socketmetadata[socketposition] and (self.socketmetadata[socketposition].socketname == socketname)
        if issocketed_fromload or (netvarvalue ~= 0 and (hashed == nil or netvarvalue == hashed)) then
            if not positions then
                positions = {socketposition}
            else
                table.insert(positions, socketposition)
            end
        end
    end
    return positions
end

local function Filter_KeepFull(self, position)
    return self.socketed[position]:value()
end

local function Filter_KeepEmpty(self, position)
    return not self.socketed[position]:value()
end

local function Filter_KeepQuality(self, position, quality)
    local socketquality = self.socketquality[position]:value()
    return socketquality == quality
end

local function Filter_Positions(self, positions, filterfn, ...)
    if positions then
        local lastpos = #positions
        local writepos = 1
        for i = 1, lastpos do
            local position = positions[i]
            if filterfn(self, position, ...) then
                positions[writepos] = position
                writepos = writepos + 1
            end
        end
        for i = writepos, lastpos do
            positions[i] = nil
        end
    end
end

function SocketHolder:GetAllEmptySocketPositions(socketname)
    local positions = self:GetAllSocketPositions(socketname)
    Filter_Positions(self, positions, Filter_KeepEmpty)
    return positions
end

function SocketHolder:GetAllFullSocketPositions(socketname)
    local positions = self:GetAllSocketPositions(socketname)
    Filter_Positions(self, positions, Filter_KeepFull)
    return positions
end

-- GetFirstX

function SocketHolder:GetFirstEmptySocketPosition(socketname)
    local positions = self:GetAllEmptySocketPositions(socketname)
    if not positions then
        return nil
    end

    return positions[1]
end

function SocketHolder:GetFirstFullSocketPosition(socketname)
    local positions = self:GetAllFullSocketPositions(socketname)
    if not positions then
        return nil
    end

    return positions[1]
end

-- Getters for socket information.

function SocketHolder:GetHighestQualitySocketedPositions(socketname)
    local positions = self:GetAllSocketPositions(socketname)
    if positions then
        Filter_Positions(self, positions, Filter_KeepFull)
        local highestquality
        for i = 1, #positions do
            local position = positions[i]
            local socketquality = self.socketquality[position]:value()
            if highestquality == nil or socketquality > highestquality then
                highestquality = socketquality
            end
        end
        Filter_Positions(self, positions, Filter_KeepQuality, highestquality)
    end
    return positions
end

function SocketHolder:GetQualityForPosition(position)
    local quality = self.socketquality[position]
    if not quality then
        return SOCKETQUALITY.NONE
    end
    return quality:value()
end

function SocketHolder:GetHighestQualitySocketed(socketname)
    local socketpositions = self:GetHighestQualitySocketedPositions(socketname)
    if not socketpositions then
        return SOCKETQUALITY.NONE
    end

    local socketquality = self:GetQualityForPosition(socketpositions[1])
    return socketquality
end

function SocketHolder:IsSocketNameForPosition(socketname, position)
    local curval = self.socketnames[position]:value()
    local hashed = hash(socketname)
    return hashed == curval and curval ~= 0
end

-- Socketing

function SocketHolder:CanTryToSocket(item, doer)
    local socketable = item.components.socketable
    if not socketable then
        return false--, "NOTASOCKETABLE"
    end

    local socketname = socketable:GetSocketName()
    local socketposition = self:GetFirstEmptySocketPosition(socketname)
    if not socketposition then
        return false--, "NOSOCKETSAVAILABLE"
    end

    if self.shouldallowsocketablefn_CLIENT then
        local permitted, reason = self.shouldallowsocketablefn_CLIENT(self.inst, item, doer)
        if not permitted then
            return false, reason
        end
    end

    return true, nil, socketposition
end

function SocketHolder:SetShouldAllowSocketableFn_CLIENT(fn)
    self.shouldallowsocketablefn_CLIENT = fn
end

function SocketHolder:TryToUnsocket(socketposition)
	if not self.ismastersim or self.socketdata[socketposition] then
		self.inst:PushEventImmediate("socketholder_unsocket", socketposition)
	end
end


-- Server interface

function SocketHolder:EnableDropOnDeath()
    if not self.dropondeath then
        self.dropondeath = true
        self.inst:ListenForEvent("death", OnDeath)
    end
end

function SocketHolder:DisableDropOnDeath()
    if self.dropondeath then
        self.dropondeath = false
        self.inst:RemoveEventCallback("death", OnDeath)
    end
end

function SocketHolder:SetShouldAllowSocketableFn_SERVER(fn)
    self.shouldallowsocketablefn_SERVER = fn
end

function SocketHolder:SetOnGetSocketableFn(fn)
    self.ongetsocketablefn = fn
end

function SocketHolder:SetOnRemoveSocketableFn(fn)
    self.onremovesocketablefn = fn
end

local function ConvertSaveDataToItem(savedata)
    local creator = savedata.origin and TheWorld.meta.session_identifier ~= savedata.origin and { sessionid = savedata.origin } or nil
    local itemdata = savedata.itemdata
    local item = SpawnPrefab(itemdata.prefab, itemdata.skinname, itemdata.skin_id, creator)
    if item and item:IsValid() then
        item:SetPersistData(itemdata.data)
    else
        item = nil
    end
    return item
end

local function ConvertItemToSaveData(item)
    local itemdata = item:GetSaveRecord()
    local savedata = {
        origin = TheWorld.meta.session_identifier,
        itemdata = itemdata,
    }
    item:Remove()
    return savedata
end


function SocketHolder:DoSocket(item_or_savedata, doer, socketposition)
    -- First convert item_or_savedata to an item if needed.
    local item
    if EntityScript.is_instance(item_or_savedata) then
        item = item_or_savedata
        local stackable = item.components.stackable
        if stackable and stackable:IsStack() then
            item = stackable:Get()
        elseif item.components.inventoryitem then
            item.components.inventoryitem:RemoveFromOwner(true)
        end
    else
        item = ConvertSaveDataToItem(item_or_savedata)
    end
    if not item then
        return false
    end
    
    self.socketmetadata[socketposition] = {
        socketname = item.components.socketable:GetSocketName(),
    }
    self.socketed[socketposition]:set(true)
    self.socketquality[socketposition]:set(item.components.socketable:GetSocketQuality())

    -- Apply the function callback for getting a new item socketed.
    if self.ongetsocketablefn then
        self.ongetsocketablefn(self.inst, item, doer) -- doer can be nil!
    end
    self.inst:PushEvent("onsocketeditem", {item = item, doer = doer,}) -- doer can be nil!

    -- Resave out and delete the item.
    local savedata = ConvertItemToSaveData(item)
    self.socketdata[socketposition] = savedata
    return true
end

function SocketHolder:TryToSocket(item, doer)
    local permitted, reason, socketposition = self:CanTryToSocket(item, doer)
    if not permitted then
        return false, reason
    end

    if self.shouldallowsocketablefn_SERVER then
        local permitted, reason = self.shouldallowsocketablefn_SERVER(self.inst, item, doer)
        if not permitted then
            return false, reason
        end
    end

    return self:DoSocket(item, doer, socketposition)
end


function SocketHolder:UnsocketPosition(socketposition)
    local item
    local savedata = self.socketdata[socketposition]
    self.socketmetadata[socketposition] = nil
    self.socketdata[socketposition] = nil
    self.socketed[socketposition]:set(false)
    self.socketquality[socketposition]:set(SOCKETQUALITY.NONE)
    if savedata then
        item = ConvertSaveDataToItem(savedata)
        if item then
            if self.onremovesocketablefn then
                self.onremovesocketablefn(self.inst, item)
            end
            self.inst:PushEvent("onunsocketeditem", {item = item,})
        end
    end
    return item
end

function SocketHolder:UnsocketEverything()
    local items = {}
    local socketpositions = self:GetAllFullSocketPositions()
    if socketpositions then
        for _, socketposition in ipairs(socketpositions) do
            local item = self:UnsocketPosition(socketposition)
            if item then
                table.insert(items, item)
            end
        end
    end
    return items
end

function SocketHolder:VerifySockets()
    local socketpositions = self:GetAllFullSocketPositions()
    if socketpositions then
        local items
        for _, socketposition in ipairs(socketpositions) do
            local socketname = self.socketmetadata[socketposition].socketname
            if not self:IsSocketNameForPosition(socketname, socketposition) then
                local item = self:UnsocketPosition(socketposition)
                if item then
                    if not items then
                        items = {}
                    end
                    table.insert(items, item)
                end
            end
        end
        if items then
            for _, item in ipairs(items) do
                Launch2(item, self.inst, 1, 1, 0.2, 0, 4)
            end
        end
    end
end

---------------------------------------------------------------------------------

function SocketHolder:OnSave()
    return self.socketdata
end

function SocketHolder:DoLoadingOfSockets(data)
    if data then
        self.isloading = true
        for socketposition, socketdata in pairs(data) do
            self:DoSocket(socketdata, nil, socketposition)
        end
        self.isloading = nil
    end
end

function SocketHolder:OnLoad(data, newents)
    if self.inst.isplayer then -- The player instance does not do LoadPostPass.
        self:DoLoadingOfSockets(data)
        if self.inst._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
            self:VerifySockets()
        else
            self.inst:ListenForEvent("ms_skilltreeinitialized", function()
                self:VerifySockets()
            end)
        end
    end
end

function SocketHolder:LoadPostPass(newents, data)
    if not self.inst.isplayer then -- For everything that is not a player this is needed post so entity state pristine is set.
        self:DoLoadingOfSockets(data)
    end
end

function SocketHolder:GetDebugString()
    local pips = {}
    for i = 1, self.maxsockets do
        local named = self.socketnames[i]:value() ~= 0
		local name = self.socketmetadata and self.socketmetadata[i] and self.socketmetadata[i].socketname or "n/a"
        local socketed = self.socketed[i]:value()
        local quality = self.socketquality[i]:value()
        table.insert(pips, string.format("[%d: Named:%d{%s} Socketed:%d Quality:%d]", i, named and 1 or 0, name, socketed and 1 or 0, quality))
    end
    return table.concat(pips, " ")
end

return SocketHolder
