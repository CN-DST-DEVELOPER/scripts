
local function onsetchanneler(self)
    if self.channeler ~= nil then
        self.inst:AddTag("channeled")
    else
        self.inst:RemoveTag("channeled")
    end
end

local function onsetenabled(self)
    if self.enabled then
        self.inst:AddTag("channelable")
    else
        self.inst:RemoveTag("channelable")
    end
end

local function onuse_channel_longaction(self)
    if self.use_channel_longaction then
        self.inst:AddTag("use_channel_longaction")
    else
        self.inst:RemoveTag("use_channel_longaction")
    end
end

local function onmultichannelersallowed(self)
    self.inst:AddOrRemoveTag("multichannelable", self.multichannelersallowed)
end

local Channelable = Class(function(self, inst)
    self.inst = inst
    self.enabled = true
    self.channeler = nil

    --self.use_channel_longaction = nil
    --self.multichannelersallowed = nil
    --self.multichannelers = nil

    self.onremovechanneler = function(channeler)
        if self.multichannelersallowed then
            self.multichannelers[channeler] = nil
        else
            self.channeler = nil
        end
    end
end,
nil,
{
    enabled = onsetenabled,
    channeler = onsetchanneler,
    use_channel_longaction = onuse_channel_longaction,
    multichannelersallowed = onmultichannelersallowed,
})

function Channelable:OnRemoveFromEntity()
    if self.multichannelersallowed and next(self.multichannelers) or self.channeler then
        self:StopChanneling(true)
    end
    if self.updating then
        self.updating = nil
        self.inst:StopUpdatingComponent(self)
    end
    self.inst:RemoveTag("channeled")
    self.inst:RemoveTag("channelable")
    self.inst:RemoveTag("use_channel_longaction")
    self.inst:RemoveTag("multichannelable")
end

function Channelable:SetMultipleChannelersAllowed(allowed)
    if self.multichannelersallowed ~= allowed then
        self.multichannelersallowed = allowed
        if allowed then
            if self.channeler then
                self:StopChanneling(true)
            end
            self.multichannelers = {}
        else
            if next(self.multichannelers) then
                self:StopChanneling(true)
            end
            self.multichannelers = nil
        end
    end
end

function Channelable:SetEnabled(enabled)
    self.enabled = enabled
end

function Channelable:GetEnabled()
    return self.enabled
end

function Channelable:SetChannelingFn(startfn, stopfn)
    self.onchannelingfn = startfn
    self.onstopchannelingfn = stopfn
end

function Channelable:IsChanneling(targetchanneler)
    if self.multichannelersallowed then
        if targetchanneler then
			if self.multichannelers[targetchanneler] and targetchanneler.sg and targetchanneler.sg:HasStateTag("channeling") then
                return true
            end
        else
            for channeler, _ in pairs(self.multichannelers) do
                if channeler and channeler.sg and channeler.sg:HasStateTag("channeling") then
                    return true
                end
            end
        end
        return false
    end
    return self.channeler ~= nil
        and self.channeler.sg ~= nil
        and self.channeler.sg:HasStateTag("channeling")
end

function Channelable:StartChanneling(channeler)
    if self.enabled and
        (not self:IsChanneling(channeler) or self.ignore_prechannel) and
        channeler ~= nil and
        channeler.sg ~= nil and
        (channeler.sg:HasStateTag("prechanneling") or self.skip_state_channeling ) then

        if self.multichannelersallowed then
            self.multichannelers[channeler] = true
        else
            self.channeler = channeler
        end
        self.inst:ListenForEvent("onremove", self.onremovechanneler, channeler)
        if not self.skip_state_channeling then
            channeler.sg:GoToState("channeling", self.inst)
        end

        if self.onchannelingfn ~= nil then
            self.onchannelingfn(self.inst, channeler)
        end

        if not self.updating then
            self.updating = true
            self.inst:StartUpdatingComponent(self)
        end

        return true
    end
end

function Channelable:StopChanneling(aborted, targetchanneler)
    if self.multichannelersallowed then
        if targetchanneler then
            self.inst:RemoveEventCallback("onremove", self.onremovechanneler, targetchanneler)
        else
            for channeler, _ in pairs(self.multichannelers) do
                self.inst:RemoveEventCallback("onremove", self.onremovechanneler, channeler)
            end
        end
    else
        if self.channeler then
            self.inst:RemoveEventCallback("onremove", self.onremovechanneler, self.channeler)
        end
    end

	if self.multichannelersallowed then
		if targetchanneler then
			if self:IsChanneling(targetchanneler) then
				targetchanneler.sg.statemem.stopchanneling = true
				if not self.skip_state_stopchanneling then
					targetchanneler.sg:GoToState("stopchanneling")
				end
			end
		else
			for channeler, _ in pairs(self.multichannelers) do
				if self:IsChanneling(channeler) then
					channeler.sg.statemem.stopchanneling = true
					if not self.skip_state_stopchanneling then
						channeler.sg:GoToState("stopchanneling")
					end
				end
			end
		end
	elseif self:IsChanneling() then
        self.channeler.sg.statemem.stopchanneling = true
        if not self.skip_state_stopchanneling then
            self.channeler.sg:GoToState("stopchanneling")
        end
    end

    if self.onstopchannelingfn ~= nil then
        if self.multichannelersallowed then
            if targetchanneler then
                self.onstopchannelingfn(self.inst, aborted, targetchanneler)
                self.multichannelers[targetchanneler] = nil
            else
                for channeler, _ in pairs(self.multichannelers) do
                    self.onstopchannelingfn(self.inst, aborted, channeler)
                    self.multichannelers[channeler] = nil
                end
            end
        else
            self.onstopchannelingfn(self.inst, aborted, self.channeler)
            self.channeler = nil
        end
    end

    if self.updating and (not self.multichannelersallowed or not next(self.multichannelers)) then
        self.updating = nil
        self.inst:StopUpdatingComponent(self)
    end
end

function Channelable:OnUpdate(dt)
    if not self:IsChanneling() then
        self:StopChanneling(true)
    end
end

function Channelable:GetDebugString()
    return self:IsChanneling() and "Channeling" or "Not Channeling"
end

return Channelable
