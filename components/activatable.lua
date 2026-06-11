local function oninactive(self, inactive)
    self.inst:AddOrRemoveTag("inactive", inactive)
end

local function onstandingaction(self, standingaction)
    self.inst:AddOrRemoveTag("standingactivation", standingaction)
end

local function onquickaction(self, quickaction)
    self.inst:AddOrRemoveTag("quickactivation", quickaction)
end

local function onforcerightclickaction(self, forcerightclickaction)
    self.inst:AddOrRemoveTag("activatable_forceright", forcerightclickaction)
end

local function onforcenopickupaction(self, forcenopickupaction)
    self.inst:AddOrRemoveTag("activatable_forcenopickup", forcenopickupaction)
end

local Activatable = Class(function(self, inst, activcb)
    self.inst = inst
    self.OnActivate = activcb
    self.inactive = true
    self.standingaction = false
    self.quickaction = false

    self.forcerightclickaction = false
    self.forcenopickupaction = false
end,
nil,
{
    inactive = oninactive,
    standingaction = onstandingaction,
    quickaction = onquickaction,
    forcerightclickaction = onforcerightclickaction,
    forcenopickupaction = onforcenopickupaction,
})

function Activatable:OnRemoveFromEntity()
    self.inst:RemoveTag("inactive")
    self.inst:RemoveTag("quickactivation")
    self.inst:RemoveTag("standingactivation")
    self.inst:RemoveTag("activatable_forceright")
    self.inst:RemoveTag("activatable_forcenopickup")
end

function Activatable:CanActivate(doer)
    local success, msg = self.inactive, nil

    if self.CanActivateFn then
        success, msg = self.CanActivateFn(self.inst, doer)
    end

    return success, msg
end

function Activatable:DoActivate(doer)
    if not self.OnActivate then
        return nil
    end

    self.inactive = false
    local success, msg = self.OnActivate(self.inst, doer)
    if success then
        self.inst:PushEvent("onactivated", {doer = doer})
    end
    return success, msg
end

function Activatable:GetDebugString()
	return tostring(self.inactive)
end

return Activatable
