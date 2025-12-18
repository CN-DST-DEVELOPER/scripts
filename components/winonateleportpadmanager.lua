-- WinonaTeleportPadManager class definition
local WinonaTeleportPadManager = Class(function(self, inst)
    assert(TheWorld.ismastersim, "WinonaTeleportPadManager should not exist on client")
    self.inst = inst

    self.winonateleportpads = {}
    self.inst:ListenForEvent("ms_registerwinonateleportpad", self.OnRegisterWinonaTeleportPad_Bridge)
end)
function WinonaTeleportPadManager:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("ms_registerwinonateleportpad", self.OnRegisterWinonaTeleportPad_Bridge)
    for winonateleportpad, winonateleportpaddata in pairs(self.winonateleportpads) do
        self.inst:RemoveEventCallback("onremove", winonateleportpaddata.onremove, winonateleportpad)
    end
end

---------------------------------------------------------------------

function WinonaTeleportPadManager:GetAllWinonaTeleportPads()
    return self.winonateleportpads
end

---------------------------------------------------------------------

WinonaTeleportPadManager.OnRegisterWinonaTeleportPad_Bridge = function(inst, winonateleportpad)
    local self = inst.components.winonateleportpadmanager
    self:OnRegisterWinonaTeleportPad(winonateleportpad)
end
function WinonaTeleportPadManager:OnRegisterWinonaTeleportPad(winonateleportpad)
    local haseventlisteners = true
    local function onbuilt()
        if haseventlisteners then
            haseventlisteners = nil
            self.inst:RemoveEventCallback("onbuilt", onbuilt, winonateleportpad)
            self.inst:RemoveEventCallback("entitywake", onbuilt, winonateleportpad)
            self.inst:RemoveEventCallback("entitysleep", onbuilt, winonateleportpad)
        end

        local function onremove()
            self.winonateleportpads[winonateleportpad] = nil
        end
        self.winonateleportpads[winonateleportpad] = {
            onremove = onremove,
        }
        self.inst:ListenForEvent("onremove", onremove, winonateleportpad)
    end
    self.inst:ListenForEvent("onbuilt", onbuilt, winonateleportpad)
    self.inst:ListenForEvent("entitywake", onbuilt, winonateleportpad)
    self.inst:ListenForEvent("entitysleep", onbuilt, winonateleportpad)
end

return WinonaTeleportPadManager
