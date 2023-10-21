local MIN_DIST_FROM_LAST_POSITION_SQ = 300 * 300
local MAX_DIST_FROM_AN_PLAYER = 250

local MAX_NUM_HINTS = 10
local NUM_MACHINES_PER_SPAWN = 3

local NOTE_OFFSET_RADIUS = 2

local IS_CLEAR_CENTERPOINT_AREA_RADIUS = 10
local IS_CLEAR_AREA_RADIUS = 5

local LOCATION_CANT_TAGS = { "INLIMBO", "NOBLOCK", "FX" }

--------------------------------------------------------------------------------------------

local function NodeCanHaveMachine(node)
    return
        not table.contains(node.tags, "not_mainland") and
        TheWorld.Map:IsLandTileAtPoint(node.cent[1], 0, node.cent[2])
end

local function IsPositionClearCenterPoint(pos)
    local valid = TheSim:CountEntities(pos.x, 0, pos.z, IS_CLEAR_CENTERPOINT_AREA_RADIUS, nil, LOCATION_CANT_TAGS) <= 0

    return valid and not IsAnyPlayerInRange(pos.x, 0, pos.z, PLAYER_CAMERA_SEE_DISTANCE)
end

local function IsPositionClearNote(pos)
    return TheSim:CountEntities(pos.x, 0, pos.z, NOTE_OFFSET_RADIUS, nil, LOCATION_CANT_TAGS) <= 0
end

local function IsPositionClear(pos)
    return TheSim:CountEntities(pos.x, 0, pos.z, IS_CLEAR_AREA_RADIUS, nil, LOCATION_CANT_TAGS) <= 0
end

--------------------------------------------------------------------------------------------

local function OnMachineDestroyed(world, GUID)
    world.components.wagpunk_manager:RemoveMachine(GUID)
end

local function OnMachineAdded(world, GUID)
    world.components.wagpunk_manager:AddMachine(GUID)
end

local function OnPlayerJoined(world, player)
    world.components.wagpunk_manager:AddPlayer(player)
end

local function OnPlayerLeft(world, player)
    world.components.wagpunk_manager:RemovePlayer(player)
end

--------------------------------------------------------------------------------------------

local WagpunkManager = Class(function(self, inst)
    assert(TheWorld.ismastersim, "Wagpunk Manager should not exist on the client!")

    self.inst = inst

    self._enabled = nil
    self._updating = false

    self.machineGUIDS = {}
    self._activeplayers = {}

    self.hintcount = 0
    self.nexthinttime = nil
    self.nextspawntime = nil

    self._currentnodeindex = nil

    self.inst:ListenForEvent("wagstaff_machine_destroyed", OnMachineDestroyed)
    self.inst:ListenForEvent("wagstaff_machine_added",     OnMachineAdded)

    self.inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
    self.inst:ListenForEvent("ms_playerleft",   OnPlayerLeft)
end)

function WagpunkManager:RemoveMachine(GUID)
    if self.machineGUIDS[GUID] then
        self.machineGUIDS[GUID] = nil
    end

    if self._enabled and not next(self.machineGUIDS) then
        self:StartSpawnMachinesTimer()
    end
end

function WagpunkManager:AddMachine(GUID)
    self.machineGUIDS[GUID] = true
end

function WagpunkManager:AddPlayer(player)
    if not table.contains(self._activeplayers, player) then
        table.insert(self._activeplayers, player)
    end
end

function WagpunkManager:RemovePlayer(player)
    table.removearrayvalue(self._activeplayers, player)
end

function WagpunkManager:MachineCount()
    return GetTableSize(self.machineGUIDS)
end

--------------------------------------------------------------------------------------------

function WagpunkManager:Enable()
    self._enabled = true

    if self.nexthinttime ~= nil then
        -- Save-load path.
        if self.hintcount <= MAX_NUM_HINTS then
            self:StartHintTimer(self.nexthinttime)
        end

    else
        self:StartSpawnMachinesTimer(self.nextspawntime)
    end
end

function WagpunkManager:Disable()
    self._enabled = false

    self.hintcount = 0
    self.nexthinttime = nil
    self.nextspawntime = nil
end

--------------------------------------------------------------------------------------------

function WagpunkManager:StartSpawnMachinesTimer(timeoverride)
    self.nextspawntime = timeoverride or (TUNING.WAGSTAFF_SPAWN_MACHINE_TIME + (math.random() * TUNING.WAGSTAFF_SPAWN_MACHINE_TIME_VARIATION))

    self.nexthinttime = nil

    if not self._updating then
        self._updating = true
        self.inst:StartUpdatingComponent(self)
    end
end

function WagpunkManager:StartHintTimer(timeoverride)
    self.nexthinttime = timeoverride or Lerp(TUNING.WAGSTAFF_MACHINE_HINT_TIME.min, TUNING.WAGSTAFF_MACHINE_HINT_TIME.max, self.hintcount/MAX_NUM_HINTS)

    self.nextspawntime = nil

    if not self._updating then
        self._updating = true
        self.inst:StartUpdatingComponent(self)
    end
end

function WagpunkManager:FindSpotForMachines()
    local nodes = {}

    for index, node in ipairs(TheWorld.topology.nodes) do
        if index ~= self._currentnodeindex and NodeCanHaveMachine(node) then
            table.insert(nodes, index)
        end
    end

    local current_node = TheWorld.topology.nodes[self._currentnodeindex]
    local current_x, current_z = current_node and current_node.cent[1], current_node and current_node.cent[2]

    while #nodes > 0 do
        local rand = math.random(#nodes)
        local index = nodes[rand]

        table.remove(nodes, rand)

        local new_node = TheWorld.topology.nodes[index]
        local new_x, new_z = new_node.cent[1], new_node.cent[2]
        local new_pos = Vector3(new_x, 0, new_z)

        if IsAnyPlayerInRange(new_x, 0, new_z, MAX_DIST_FROM_AN_PLAYER) and
            (current_node == nil or VecUtil_LengthSq(new_x - current_x, new_z - current_z) > MIN_DIST_FROM_LAST_POSITION_SQ)
        then
            local offset = FindWalkableOffset(new_pos, math.random()*TWOPI, math.random()*10, 16, nil, nil, IsPositionClearCenterPoint)

            if offset ~= nil then
                self._currentnodeindex = index
                return new_pos + offset
            end
        end
    end
end

function WagpunkManager:FindMachineSpawnPoint(center_pos)
    local offset = FindWalkableOffset(center_pos, math.random()*TWOPI, IS_CLEAR_AREA_RADIUS, 16, nil, nil, IsPositionClear)

    if offset ~= nil then
        return center_pos + offset
    end
end

function WagpunkManager:SpawnWagstaff(pos, machinepos)
    local wagstaff = SpawnPrefab("wagstaff_npc")

    wagstaff.hunt_stage = "hunt"
    wagstaff.hunt_count = 0
    wagstaff.Transform:SetPosition(pos:Get())
    wagstaff:erode(1, true)

    wagstaff.components.timer:StartTimer("expiretime", TUNING.WAGSTAFF_NPC_EXPIRE_TIME)
    wagstaff.components.timer:StartTimer("wagstaff_movetime", 10 + (math.random()*5))

    wagstaff.components.knownlocations:RememberLocation("machine", machinepos)

    return wagstaff -- Mods.
end

local WAGSTAFF_MAY = { "wagstaff_npc", "wagstaff_machine" }

function WagpunkManager:TryHinting(debug)
    local player = #self._activeplayers > 0 and self._activeplayers[math.random(#self._activeplayers)] or nil

    if player == nil then
        self:StartHintTimer()

        return
    end

    if not (self.hintcount <= MAX_NUM_HINTS and next(self.machineGUIDS)) then
        -- Don't restart the timer.
        return
    end

    local pos
    local machinepos

    local playerpos = player:GetPosition()

    local is_valid_pos = TheSim:CountEntities(playerpos.x, playerpos.y, playerpos.z, 50, nil, nil, WAGSTAFF_MAY) <= 0

    local machine = Ents[next(self.machineGUIDS)]

    if is_valid_pos and machine ~= nil and machine:IsValid() then
        machinepos = machine:GetPosition()

        local angle = ((player:GetAngleToPoint(machinepos:Get()) - 180) + ( (math.random() * 60) -30 )) * DEGREES
        local offset = FindWalkableOffset(playerpos, angle, 15, 16, true)

        if offset ~= nil then
            pos = playerpos + offset
        end

    elseif debug then
        print(string.format("Machine: %s  ||  Is position valid: %s", tostring(machine), tostring(is_valid_pos)))
    end


    if pos ~= nil and machinepos ~= nil then
        self:SpawnWagstaff(pos, machinepos)

        self.hintcount = self.hintcount + 1
        self:StartHintTimer()
    else
        self.nexthinttime = 30

        if debug then
            print(string.format("Is position valid: %s  ||  Is machine position valid: %s", tostring(pos ~= nil), tostring(machinepos ~= nil)))
        end
    end
end

function WagpunkManager:SpawnNote(machinepos)
    local offset = FindWalkableOffset(machinepos, math.random()*TWOPI, NOTE_OFFSET_RADIUS, 16, nil, nil, IsPositionClearNote)

    if offset ~= nil then
        local notes = SpawnPrefab("wagstaff_mutations_note")

        if notes ~= nil then
            local pos = machinepos + offset
            notes.Transform:SetPosition(pos:Get())
        end
    end
end

function WagpunkManager:MutationsNoteExist(machinepos)
    return TheSim:FindFirstEntityWithTag("mutationsnote") ~= nil
end

function WagpunkManager:SpawnMachines(force)
    if force or next(self.machineGUIDS) == nil then
        local pos = self:FindSpotForMachines()

        if pos == nil then
            self:StartSpawnMachinesTimer()
            return
        end

        if not self:MutationsNoteExist() then
            self:SpawnNote(pos)
        end

        --local ids = PickSome(NUM_MACHINES_PER_SPAWN, { 1, 2, 3, 4, 5 } ) -- NOTE(DiogoW): For later!

        for i=1, NUM_MACHINES_PER_SPAWN do
            local machinepos = self:FindMachineSpawnPoint(pos)

            if machinepos ~= nil then
                local machine = SpawnPrefab("wagstaff_machinery")
                
                if machine ~= nil then
                    machine.Transform:SetPosition(machinepos:Get())
                    machine:SetDebrisType(i)
                    --machine:SetDebrisType(ids[i]) -- NOTE(DiogoW): For later!

                    self:AddMachine(machine.GUID)
                end
            end
        end

        self.hintcount = 0
        self.nextspawntime = nil
        self:StartHintTimer()
    end
end

--------------------------------------------------------------------------------------------

function WagpunkManager:OnSave()
    local data = {
       nextspawntime = self.nextspawntime,
       nexthinttime = self.nexthinttime,
       hintcount = self.hintcount > 0 and self.hintcount or nil,
       currentnodeindex = self._currentnodeindex,
    }

    return data
end

function WagpunkManager:OnLoad(data)
    if not data then return end

    self.nextspawntime = data.nextspawntime or self.nextspawntime
    self.nexthinttime  = data.nexthinttime  or self.nexthinttime
    self.hintcount     = data.hintcount     or self.hintcount

    self._currentnodeindex = data.currentnodeindex or self._currentnodeindex
end

--------------------------------------------------------------------------------------------

function WagpunkManager:OnUpdate(dt)
    -- Checking self._updating due to LongUpdate.
    if self._updating and (self.nexthinttime == nil and self.nextspawntime == nil) then
        self._updating = false
        self.inst:StopUpdatingComponent(self)

        return
    end

    if self.nextspawntime ~= nil then
        self.nextspawntime = self.nextspawntime - dt

        if self.nextspawntime <= 0 then
            self.nextspawntime = nil
            self:SpawnMachines()
        end
    end

    if self.nexthinttime ~= nil then
        self.nexthinttime = self.nexthinttime - dt

        if self.nexthinttime <= 0 then
            self.nexthinttime = nil
            self:TryHinting()
        end
    end
end

WagpunkManager.LongUpdate = WagpunkManager.OnUpdate

--------------------------------------------------------------------------------------------

function WagpunkManager:OnRemoveFromEntity()
    assert(false)
end

--------------------------------------------------------------------------------------------

-- TheWorld.components.wagpunk_manager:GetDebugString()
-- TheWorld.components.wagpunk_manager:DebugForceSpawnMachine()
-- TheWorld.components.wagpunk_manager:DebugForceHint()

-- TheWorld.components.wagpunk_manager:DebugForceHint() c_gonext("wagstaff_machinery") ThePlayer:DoTaskInTime(1.5, function() c_removeall("wagstaff_machinery") c_removeall("wagstaff_mutations_note") end)

function WagpunkManager:GetDebugString()
    return string.format(
        "State: %s || Updating: %s || Next Spawn: %s || Next Hint: %s || Hint Count: %d/%d || Num Machines: %d/%d",
        self._enabled  and "ON" or "OFF",
        self._updating and "ON" or "OFF",
        self.nextspawntime ~= nil and string.format("%.2f", self.nextspawntime) or "???",
        self.nexthinttime ~= nil  and string.format("%.2f", self.nexthinttime)  or "???",
        self.hintcount,
        MAX_NUM_HINTS,
        self:MachineCount(),
        NUM_MACHINES_PER_SPAWN
    )
end

function WagpunkManager:DebugForceSpawnMachine()
    self:SpawnMachines(true)
end

function WagpunkManager:DebugForceHint()
    if next(self.machineGUIDS) == nil then
        self:SpawnMachines(true)
    end

    self.hintcount = math.min(MAX_NUM_HINTS, self.hintcount)

    self:TryHinting(true)
end

--------------------------------------------------------------------------------------------


return WagpunkManager
