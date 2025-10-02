-- ShardTransactionSteps
-- NOTES(JBK): These are used for a transaction between shards so that the data is safely transferred between shards and save states.
-- The overview of this is the following.
-- 1. Create a data payload.
-- 2. Create a unique ID to be sent to the shard ID.
-- 3. Owning shard sends SHARDTRANSACTIONSTEPS.INITIATE with the unique ID and payload.
-- 4. Receiving shard gets the transaction and applies the payload.
-- 5. Receiving shard sends back SHARDTRANSACTIONSTEPS.ACCEPTED with the unique ID.
-- 6. Receiving shard saves the unique ID as SHARDTRANSACTIONSTEPS.FINALIZED.
-- 7. Owning shard receives this and marks the unique ID as SHARDTRANSACTIONSTEPS.FINALIZED.
-- Transaction IDs must be unique per shard to shard communication using the shard ID as a namespace.

local ShardTransactionSteps = Class(function(self, inst)
    assert(inst.ismastersim, "ShardTransactionSteps should not exist on client!")
    self.inst = inst

    self.transactions = {}

    self.OnShardTransactionSteps_Bridge = function(inst, shardpayload)
        shardpayload.rescheduling = nil
        self:OnShardTransactionSteps(shardpayload)
    end
end)

function ShardTransactionSteps:OnShardTransactionSteps(shardpayload)
    --self:DebugTransaction("OnShardTransactionSteps Before", shardpayload)
    local shouldfinalize = false
    local selfshardid = TheShard:GetShardId()
    local issender = selfshardid == shardpayload.originshardid
    local shardtransactions
    if issender then
        shardtransactions = self:GetShardTransactions(shardpayload.receivershardid)
        shardtransactions[shardpayload.uniqueid] = shardpayload
        if shardpayload.status == SHARDTRANSACTIONSTEPS.INITIATE then
            -- Do step 3.
            --self:DebugTransaction("OnShardTransactionSteps Send to Receiver", shardpayload)
            SendRPCToShard(SHARD_RPC.ShardTransactionSteps, shardpayload.receivershardid, DataDumper(shardpayload, nil, true))
        elseif shardpayload.status == SHARDTRANSACTIONSTEPS.ACCEPTED then
            -- Do step 7.
            shouldfinalize = true
        end
    else
        shardtransactions = self:GetShardTransactions(shardpayload.originshardid)
        if shardpayload.uniqueid >= shardtransactions.uniqueid then
            shardtransactions.uniqueid = shardpayload.uniqueid + 1
        end
        if shardtransactions.finalizedid < shardpayload.uniqueid then
            shardtransactions[shardpayload.uniqueid] = shardpayload
            if shardpayload.status == SHARDTRANSACTIONSTEPS.INITIATE then
                -- Do step 4.
                if not self:HandleTransactionFinalization(shardpayload) then
                    if not shardpayload.rescheduling then
                        -- Reschedule for later something went wrong with it.
                        shardpayload.rescheduling = true
                        self.inst:DoTaskInTime(0, self.OnShardTransactionSteps_Bridge, shardpayload)
                    end
                    return
                end
                -- Do step 5.
                shardpayload.status = SHARDTRANSACTIONSTEPS.ACCEPTED
                --self:DebugTransaction("OnShardTransactionSteps Send to Origin", shardpayload)
                SendRPCToShard(SHARD_RPC.ShardTransactionSteps, shardpayload.originshardid, DataDumper(shardpayload, nil, true))
                -- Do step 6.
                shouldfinalize = true
            end
        else
            -- We got a replay transaction let the sender know this is finished.
            shardpayload.status = SHARDTRANSACTIONSTEPS.ACCEPTED
            --self:DebugTransaction("OnShardTransactionSteps Send to Origin REPLAY", shardpayload)
            SendRPCToShard(SHARD_RPC.ShardTransactionSteps, shardpayload.originshardid, DataDumper(shardpayload, nil, true))
            shouldfinalize = true
        end
    end
    if shouldfinalize then
        shardpayload.status = SHARDTRANSACTIONSTEPS.FINALIZED
        --self:DebugTransaction("OnShardTransactionSteps Finalize", shardpayload)
        if issender then
            local newfinalizedid = shardtransactions.finalizedid
            for id = shardtransactions.finalizedid, shardtransactions.uniqueid do
                local shardpayload = shardtransactions[id]
                if shardpayload then
                    if shardpayload.status >= SHARDTRANSACTIONSTEPS.FINALIZED then
                        newfinalizedid = id
                    else
                        break
                    end
                end
            end
            if newfinalizedid > shardtransactions.finalizedid then
                self:OnPruneShardTransactionSteps(shardpayload.receivershardid, newfinalizedid)
                SendRPCToShard(SHARD_RPC.PruneShardTransactionSteps, shardpayload.receivershardid, newfinalizedid)
            end
        end

        self:ClearFields(shardpayload)
    end
    --self:DebugTransaction("OnShardTransactionSteps After", shardpayload)
end

function ShardTransactionSteps:OnPruneShardTransactionSteps(shardid, newfinalizedid)
    local shardtransactions = self:GetShardTransactions(shardid)
    for id = shardtransactions.finalizedid, newfinalizedid do
        shardtransactions[id] = nil
    end
    shardtransactions.finalizedid = newfinalizedid
    if shardtransactions.finalizedid >= shardtransactions.uniqueid then
        print("A bad transaction count was detected.", TheShard:GetShardId(), shardid, shardtransactions.finalizedid, shardtransactions.uniqueid)
    end
end

function ShardTransactionSteps:OnShardConnected(shardid)
    local selfshardid = TheShard:GetShardId()
    local shardtransactions = self.transactions[shardid]
    if shardtransactions then
        for id = shardtransactions.finalizedid, shardtransactions.uniqueid do
            local shardpayload = shardtransactions[id]
            if shardpayload and shardpayload.originshardid == selfshardid then
                if shardpayload.status == SHARDTRANSACTIONSTEPS.INITIATE then
                    self:OnShardTransactionSteps(shardpayload)
                end
            end
        end
    end
end

function ShardTransactionSteps:HandleTransactionInitialization(shardpayload)
    if shardpayload.transactiontype == SHARDTRANSACTIONTYPES.TRANSFERINVENTORYITEM then
        local item = shardpayload.data.item
        shardpayload.data.item = nil

        local item_record = item:GetSaveRecord()
        item:Remove()

        shardpayload.data.item_record = item_record
    end
end

function ShardTransactionSteps:HandleTransactionFinalization(shardpayload)
    --self:DebugTransaction("HandleTransactionFinalization", shardpayload)
    if shardpayload.transactiontype == SHARDTRANSACTIONTYPES.TRANSFERINVENTORYITEM then
        local item_record, migrationdata = shardpayload.data.item_record, shardpayload.data.migrationdata
        -- This will fail if the portal is not active or the destination is not a point.
        local portal = GetMigrationPortalFromMigrationData(migrationdata)
        if not portal and (migrationdata.dest_x == nil or migrationdata.dest_y == nil or migrationdata.dest_z == nil) then
            return false
        end

        shardpayload.data.item_record, shardpayload.data.migrationdata = nil, nil
        -- FIXME(JBK): rifts6 if the portal is the ocean exit make it a bundle to stuff this prefab into like a broken elastispaced chest.
        if portal and portal.components.itemstore then
            portal.components.itemstore:AddItemRecordAndMigrationData(item_record, migrationdata)
        else
            local creator = { sessionid = migrationdata.sessionid }
            local item = SpawnPrefab(item_record.prefab, item_record.skinname, item_record.skin_id, creator)
            item:SetPersistData(item_record.data)
            local x, y, z = GetMigrationPortalLocation(item, migrationdata, portal)
            if item.Physics then
                item.Physics:Teleport(x, y, z)
            elseif item.Transform then
                item.Transform:SetPosition(x, y, z)
            end
        end
    end

    return true
end

function ShardTransactionSteps:GetShardTransactions(shardid)
    local shardtransactions = self.transactions[shardid]
    if not shardtransactions then
        shardtransactions = {
            uniqueid = 1,
            finalizedid = 0,
        }
        self.transactions[shardid] = shardtransactions
    end
    return shardtransactions
end

function ShardTransactionSteps:ClearFields(shardpayload)
    --self:DebugTransaction("ClearFields", shardpayload)
    shardpayload.transactiontype = nil
    shardpayload.originshardid = nil
    shardpayload.receivershardid = nil
    shardpayload.data = nil
    --Do not clear this field. shardpayload.uniqueid = nil
end

function ShardTransactionSteps:CreateTransaction(shardid, transactiontype, data)
    local selfshardid = TheShard:GetShardId()
    assert(shardid ~= selfshardid, "ShardTransactionSteps:CreateTransaction must send to another shard.")

    local shardtransactions = self:GetShardTransactions(shardid)

    local uniqueid = shardtransactions.uniqueid
    shardtransactions.uniqueid = uniqueid + 1
    local shardpayload = { -- NOTES(JBK): Keep in sync with ClearFields function above.
        transactiontype = transactiontype,
        originshardid = selfshardid,
        receivershardid = shardid,
        data = data,
        uniqueid = uniqueid, -- Unique to shardid.
    }
    shardtransactions[uniqueid] = shardpayload
    
    self:HandleTransactionInitialization(shardpayload)
    shardpayload.status = SHARDTRANSACTIONSTEPS.INITIATE
    --self:DebugTransaction("CreateTransaction", shardpayload)

    if Shard_IsWorldAvailable(shardid) then
        self:OnShardTransactionSteps(shardpayload)
    end
end

function ShardTransactionSteps:OnSave()
    if next(self.transactions) == nil then
        return
    end

    return {
        transactions = self.transactions,
    }
end

function ShardTransactionSteps:OnLoad(data)
    if not data then
        return
    end

    self.transactions = data.transactions or self.transactions
end

function ShardTransactionSteps:DebugTransaction(prefix, shardpayload)
    local reasons = table.invert(SHARDTRANSACTIONSTEPS)
    print(string.format("STS %s Id:%s Origin:%s Receiver:%s Shard:%s Status:%s", prefix, tostring(shardpayload.uniqueid), tostring(shardpayload.originshardid), tostring(shardpayload.receivershardid), tostring(TheShard:GetShardId()), reasons[shardpayload.status] or "?"))
end

return ShardTransactionSteps
