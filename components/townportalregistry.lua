--------------------------------------------------------------------------
--[[ TownPortalRegistry class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "TownPortalRegistry should not exist on client")
local map = TheWorld.Map

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _townportals = {}
local _activetownportal = nil
local linkedportals = {}


--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------
local function OnTownPortalActivated(inst, townportal)
    local x2, y2, z2 = townportal.Transform:GetWorldPosition()
	if _activetownportal == nil and IsTeleportLinkingPermittedFromPoint(x2, y2, z2) then
		_activetownportal = townportal
        linkedportals[_activetownportal] = true
		for i, v in ipairs(_townportals) do
			if v ~= townportal then
                local posent = v.components.inventoryitem and v.components.inventoryitem:GetGrandOwner() or v
                local x1, y1, z1 = posent.Transform:GetWorldPosition()
                if IsTeleportingPermittedFromPointToPoint(x1, y1, z1, x2, y2, z2) then
                    if not linkedportals[v] then
                        linkedportals[v] = true
                        v:PushEvent("linktownportals", townportal)
                    end
                end
			end
		end
	end
end

local function OnTownPortalDeactivated(inst, portal)
	if _activetownportal ~= nil and _activetownportal == portal then
		_activetownportal = nil
		for i, v in ipairs(_townportals) do
            if linkedportals[v] then
                linkedportals[v] = nil
                v:PushEvent("linktownportals")
            end
		end
    else
        portal:PushEvent("linktownportals", _activetownportal)
	end
end

local function OnRemoveTownPortal(townportal)
    linkedportals[townportal] = nil
    for i, v in ipairs(_townportals) do
        if v == townportal then
            table.remove(_townportals, i)
            inst:RemoveEventCallback("onremove", OnRemoveTownPortal, townportal)
            break
        end
    end

    if townportal == _activetownportal then
	    OnTownPortalDeactivated(TheWorld, townportal)
	end
end

local function OnRegisterTownPortal(inst, townportal)
    for i, v in ipairs(_townportals) do
        if v == townportal then
            return
        end
    end

    table.insert(_townportals, townportal)
    inst:ListenForEvent("onremove", OnRemoveTownPortal, townportal)
    local posent = townportal.components.inventoryitem and townportal.components.inventoryitem:GetGrandOwner() or townportal
    if _activetownportal ~= nil then
        local x1, y1, z1 = posent.Transform:GetWorldPosition()
        local x2, y2, z2 = _activetownportal.Transform:GetWorldPosition()
        if IsTeleportingPermittedFromPointToPoint(x1, y1, z1, x2, y2, z2) then
            townportal:PushEvent("linktownportals", _activetownportal)
            linkedportals[townportal] = true
        end
	end
end

local function RecheckPortals(isactive)
    if _activetownportal then
        if map:IsPointInWagPunkArena(_activetownportal.Transform:GetWorldPosition()) then
            linkedportals[_activetownportal] = nil
            _activetownportal:PushEvent("linktownportals")
        end
    end
    if _activetownportal then
        for i, v in ipairs(_townportals) do
            local posent = v.components.inventoryitem and v.components.inventoryitem:GetGrandOwner() or v
            if isactive and map:IsPointInWagPunkArena(posent.Transform:GetWorldPosition()) then
                if linkedportals[v] then
                    linkedportals[v] = nil
                    v:PushEvent("linktownportals")
                    if v.components.channelable then
                        v.components.channelable:SetEnabled(false)
                    end
                end
            elseif v ~= _activetownportal and not linkedportals[v] then
                linkedportals[v] = true
                v:PushEvent("linktownportals", _activetownportal)
                if v.components.channelable then
                    v.components.channelable:SetEnabled(true)
                end
            end
        end
    else
        for i, v in ipairs(_townportals) do
            local posent = v.components.inventoryitem and v.components.inventoryitem:GetGrandOwner() or v
            if map:IsPointInWagPunkArena(posent.Transform:GetWorldPosition()) then
                if v.components.channelable then
                    v.components.channelable:SetEnabled(not isactive)
                end
            end
        end
    end
end
local function OnBarrierIsActive(inst, isactive)
    RecheckPortals(isactive)
end

local function DoRecheckBarrier(inst)
    inst.recheckbarriertask = nil
    if map:IsWagPunkArenaBarrierUp() then
        RecheckPortals(true)
    end
end

local function OnPlayerEnteredOrLeftBarrier(inst, player)
    if inst.recheckbarriertask then
        return
    end
    inst.recheckbarriertask = inst:DoTaskInTime(0, DoRecheckBarrier)
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Register events
inst:ListenForEvent("ms_registertownportal", OnRegisterTownPortal)
inst:ListenForEvent("townportalactivated", OnTownPortalActivated)
inst:ListenForEvent("townportaldeactivated", OnTownPortalDeactivated)
inst:ListenForEvent("ms_wagpunk_barrier_isactive", OnBarrierIsActive)
inst:ListenForEvent("ms_wagpunk_barrier_playerentered", OnPlayerEnteredOrLeftBarrier)
inst:ListenForEvent("ms_wagpunk_barrier_playerleft", OnPlayerEnteredOrLeftBarrier)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

local function IsATownPortalActive()
	return _activetownportal ~= nil
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
	local s = "Town Portals: " .. tostring(#_townportals)
	if _activetownportal ~= nil then
		s = s .. ", Town Portal Activated!"
	end
	return s
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
