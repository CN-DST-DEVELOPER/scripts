local function OnFadeDirty(inst)
    local self = inst.components.spawnfader
    if not self.updating then
        self.fadeval = self._fade:value() / 7
        self.updating = true
        self.inst:StartUpdatingComponent(self)
        self:OnUpdate(FRAMES)
    end
end

local function OnDeath(inst)
    inst.components.spawnfader:Cancel()
end

local SpawnFader = Class(function(self, inst)
    self.inst = inst

    self._fade = net_tinybyte(inst.GUID, "spawnfader._fade", "fadedirty")
    self._fadeout = net_bool(inst.GUID, "spawnfader._fadeout")
    self.fadeval = 0
    self.updating = false

    if not TheWorld.ismastersim then
        inst:ListenForEvent("fadedirty", OnFadeDirty)
        inst:ListenForEvent("death", OnDeath)
    end
end)

function SpawnFader:OnRemoveFromEntity()
    if not TheWorld.ismastersim then
        self.inst:RemoveEventCallback("fadedirty", OnFadeDirty)
        self.inst:RemoveEventCallback("death", OnDeath)
    end
end

function SpawnFader:FadeIn()
    if TheWorld.ismastersim then
        self._fade:set(7)
        self._fadeout:set(false)
    else
        self._fade:set_local(7)
        self._fadeout:set_local(false)
    end
    self.fadeval = 1
    if not self.updating then
        self.updating = true
        self.inst:StartUpdatingComponent(self)
        self.inst:AddTag("NOCLICK")
        self:OnUpdate(FRAMES)
    end
end

function SpawnFader:FadeOut()
    if TheWorld.ismastersim then
        self._fade:set(7)
        self._fadeout:set(true)
    else
        self._fade:set_local(7)
        self._fadeout:set_local(true)
    end
    self.fadeval = 1
    if not self.updating then
        self.updating = true
        self.inst:StartUpdatingComponent(self)
        self.inst:AddTag("NOCLICK")
        self:OnUpdate(FRAMES)
    end
end

function SpawnFader:Cancel()
    if self.updating then
        self.fadeval = 0
        self:OnUpdate(FRAMES)
    end
end

function SpawnFader:OnUpdate(dt)
    self.fadeval = math.max(0, self.fadeval - dt)
    local fadingout = self._fadeout:value()
    local k
    if fadingout then
        k = 1 - self.fadeval
        k = 1 - k * k
    else
        k = 1 - self.fadeval * self.fadeval
    end

    self.inst.AnimState:OverrideMultColour(1, 1, 1, k)

    if self.inst.highlightchildren ~= nil then
        for _, child in ipairs(self.inst.highlightchildren) do
            child.AnimState:OverrideMultColour(1, 1, 1, k)
        end
    end

    if self.fadeval <= 0 then
        self.updating = false
        self.inst:StopUpdatingComponent(self)
        if fadingout then
            self.inst:PushEvent("spawnfaderout")
        else
            self.inst:PushEvent("spawnfaderin")
        end
    end

    if TheWorld.ismastersim then
        self._fade:set_local(math.floor(7 * self.fadeval + .5))
        if not self.updating then
            self.inst:RemoveTag("NOCLICK")
        end
    end
end

return SpawnFader
