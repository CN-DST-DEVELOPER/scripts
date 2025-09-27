local function onenabled(self, enabled)
    -- Recommended to explicitly add tag to prefab pristine state
    self.inst:AddOrRemoveTag("moonstormstaticcapturable", enabled)
end

local MoonstormStaticCapturable = Class(function(self, inst)
    self.inst = inst
    self.enabled = true
    self.targeters = {}
    self.ontargetedfn = nil
    self.onuntargetedfn = nil
    self.oncaughtfn = nil

    self._onremovetargeter = function(obj) self:OnUntargeted(obj) end
end,
nil,
{
    enabled = onenabled,
})

function MoonstormStaticCapturable:OnRemoveFromEntity()
    self.inst:RemoveTag("moonstormstaticcapturable")
end

function MoonstormStaticCapturable:SetEnabled(enabled)
    self.enabled = enabled
end

function MoonstormStaticCapturable:IsEnabled()
    return self.enabled
end

function MoonstormStaticCapturable:SetOnCaughtFn(fn)
    self.oncaughtfn = fn
end

function MoonstormStaticCapturable:SetOnTargetedFn(fn)
    self.ontargetedfn = fn
end

function MoonstormStaticCapturable:SetOnUntargetedFn(fn)
    self.onuntargetedfn = fn
end

function MoonstormStaticCapturable:IsTargeted()
    return next(self.targeters) ~= nil
end

--called by moonstormstaticcatcher component
function MoonstormStaticCapturable:OnTargeted(obj)
    if self.targeters[obj] == nil then
        local wastargeted = self:IsTargeted()
        self.targeters[obj] = true
        self.inst:ListenForEvent("onremove", self._onremovetargeter, obj)
        if not wastargeted then
            if self.ontargetedfn then
                self.ontargetedfn(self.inst)
            end
            self.inst:PushEvent("moonstormstaticcapturable_targeted")
        end
    end
end

--called by moonstormstaticcatcher component
function MoonstormStaticCapturable:OnUntargeted(obj)
    if self.targeters[obj] then
        self.targeters[obj] = nil
        self.inst:RemoveEventCallback("onremove", self._onremovetargeter, obj)
        if not self:IsTargeted() then
            if self.onuntargetedfn then
                self.onuntargetedfn(self.inst)
            end
            self.inst:PushEvent("moonstormstaticcapturable_untargeted")
        end
    end
end

--called by moonstormstaticcatcher component
function MoonstormStaticCapturable:OnCaught(obj, doer)
    if doer then
        doer:PushEvent("moonstormstatic_caught", self.inst)
    end

    if self.oncaughtfn then
        self.oncaughtfn(self.inst, obj, doer)
    end
end

return MoonstormStaticCapturable
