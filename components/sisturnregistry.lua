--------------------------------------------------------------------------
--[[ sisturnregistry class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "sisturnregistry should not exist on client")

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _sisturns = {}
local _is_active = false
local _is_blossom = false

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function UpdateSisturnState()
	if POPULATING then
		if self.init_task == nil then
			self.init_task = self.inst:DoTaskInTime(0, function() UpdateSisturnState() self.init_task = nil end)
		end
		return
	end
	
	local is_active = false
	local is_blossom = false

	for _, v in pairs(_sisturns) do
		if v then			
			if _:getsisturnfeel() == "BLOSSOM" then
				is_blossom = true
			end
			is_active = true
		end
	end

	if is_active ~= _is_active or is_blossom ~= _is_blossom then
		_is_active = is_active
		_is_blossom = is_blossom
		TheWorld:PushEvent("onsisturnstatechanged", {is_active = is_active, is_blossom=is_blossom}) -- Wendy will be listening for this event
	end
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRemoveSisturn(sisturn)
	if _sisturns[sisturn] ~= nil then
		_sisturns[sisturn] = nil
		inst:RemoveEventCallback("onremove", OnRemoveSisturn, sisturn)
		inst:RemoveEventCallback("onburnt", OnRemoveSisturn, sisturn)
	end

    UpdateSisturnState()
end

local function OnUpdateSisturnState(world, data)
	_sisturns[data.inst] = data.is_active == true
    UpdateSisturnState()
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

inst:ListenForEvent("ms_updatesisturnstate", OnUpdateSisturnState)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:Register(sisturn)
	if sisturn ~= nil and _sisturns[sisturn] ~= nil then
		return
	end

	_sisturns[sisturn] = false

    inst:ListenForEvent("onremove", OnRemoveSisturn, sisturn)
    inst:ListenForEvent("onburnt", OnRemoveSisturn, sisturn)
end

function self:IsActive()
	return _is_active
end

function self:IsBlossom()
	return _is_blossom
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
	return "Num: " .. tostring(GetTableSize(_sisturns)) .. ", is_active:" .. tostring(_is_active)..", is_blossom:" .. tostring(_is_blossom)
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
