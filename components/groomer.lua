local function oncanuseaction(self, canuseaction)
    if canuseaction then
        --V2C: Recommended to explicitly add tag to prefab pristine state
        self.inst:AddTag("groomer")
    else
        self.inst:RemoveTag("groomer")
    end
end

local function oncanbedressed(self, canbedressed)
    if canbedressed then
        --Recommended to explicitly add tag to prefab pristine state
        self.inst:AddTag("dressable")
    else
        self.inst:RemoveTag("dressable")
    end
end

local Groomer = Class(function(self, inst)
    self.inst = inst

    self.changers = {}
    self.enabled = true
    self.canuseaction = true
    self.canbeshared = nil
    self.canbedressed = nil
    self.range = 3
    self.changeindelay = 0
    self.onchangeinfn = nil
    self.onopenfn = nil
    self.onclosefn = nil

    self:SetCanBeShared(false)

    self.onclosepopup = function(doer, data)
        if self.onclosepopupfn then
            local skins = self.onclosepopupfn(self.inst, doer, data)
            if skins then
                self.onclosegroomer(doer, skins)
            end
        end
    end
    self.onclosegroomer = function(doer, data)
        if data and not data.cancel then
            self:ActivateChanging(doer, data)
        end
        self:EndChanging(doer)
    end

    self.oncloseallgroomer = function(inst, data)
        for i, v in pairs(self.changers) do
            self:EndChanging(i)
        end
    end

end,
nil,
{
    canuseaction = oncanuseaction,
    canbedressed = oncanbedressed,
})


function Groomer:SetOccupant(occupant)
    self.occupant = occupant
end

--Whether this is included in player action collection or not
function Groomer:SetCanUseAction(canuseaction)
    self.canuseaction = canuseaction
end

function Groomer:SetCanBeDressed(canbedressed)
    self.canbedressed = canbedressed
end

function Groomer:Enable(enable)
    self.enabled = enable ~= false
end

local function OnIgnite(inst)
    local towarn = {}
    for k, v in pairs(inst.components.groomer.changers) do
        if k.sg ~= nil and k.sg.currentstate.name == "openwardrobe" then
            table.insert(towarn, k)
        end
    end

    inst.components.groomer:EndAllChanging()

    for i, v in ipairs(towarn) do
        if v.components.talker ~= nil then
            v.components.talker:Say(GetString(inst, "ANNOUNCE_NOWARDROBEONFIRE"))
        end
    end
end

--Whether multiple people can use the wardrobe at once or not
function Groomer:SetCanBeShared(canbeshared)
    if self.canbeshared ~= (canbeshared == true) then
        self.canbeshared = (canbeshared == true)
        if self.canbeshared then
            self.inst:RemoveEventCallback("onignite", OnIgnite)
        else
            self.inst:ListenForEvent("onignite", OnIgnite)
        end
    end
end

function Groomer:SetRange(range)
    self.range = range
end

function Groomer:SetChangeInDelay(delay)
    self.changeindelay = delay
end

function Groomer:GetOccupant()
    return self.occupantisself and self.inst or self.occupant
end

function Groomer:CanBeginChanging(doer)
    if not self.enabled then
        return false, "INUSE"
    elseif doer.sg == nil or
        (doer.sg:HasStateTag("busy") and doer.sg.currentstate.name ~= "opengift") then
        return false
    elseif self.shareable then
        return true
	elseif self.inst.components.burnable and self.inst.components.burnable:IsBurning() then
        return false, "BURNING"
	elseif not self.canbeshared and next(self.changers) then
		return false, "INUSE"
    elseif self.canbeginchangingfn then
        local success, reason = self.canbeginchangingfn(self.inst, self:GetOccupant(), doer)
        return success, reason
    end
    return true
end

function Groomer:BeginChanging(doer)
    if self.beginchangingfn then
        self.beginchangingfn(self.inst, self:GetOccupant(), doer)
    end

    if not self.changers[doer] then
        local wasclosed = next(self.changers) == nil

        self.changers[doer] = true

        self.inst:ListenForEvent("onremove", self.onclosegroomer, doer)
        self.inst:ListenForEvent("ms_closepopup", self.onclosepopup, doer)
        self.inst:ListenForEvent("unhitched", self.oncloseallgroomer, self.inst)

        if doer.sg.currentstate.name == "opengift" then
            doer.sg.statemem.isopeningwardrobe = true
            doer.sg:GoToState("openwardrobe", { openinggift = true, target = self.canbedressed and self.inst or nil })
        else
            doer.sg:GoToState("openwardrobe", { openinggift = false, target = self.canbedressed and self.inst or nil })
        end

        if wasclosed then
            self.inst:StartUpdatingComponent(self)

            if self.onopenfn ~= nil then
                self.onopenfn(self.inst)
            end
        end
        return true
    end
    return false
end

function Groomer:EndChanging(doer)

    if self.changers[doer] then
        self.changers[doer] = nil
    end

    self.inst:RemoveEventCallback("onremove", self.onclosegroomer, doer)
    self.inst:RemoveEventCallback("ms_closepopup", self.onclosepopup, doer)
    self.inst:RemoveEventCallback("unhitched", self.oncloseallgroomer, self.inst)

    if doer.sg:HasStateTag("inwardrobe") and not doer.sg.statemem.isclosingwardrobe then
        doer.sg.statemem.isclosingwardrobe = true
        doer.AnimState:PlayAnimation("idle_wardrobe1_pst")
        doer.sg:GoToState("idle", true)
    end

    if next(self.changers) == nil then
        self.inst:StopUpdatingComponent(self)
        if self.onclosefn ~= nil then
            self.onclosefn(self.inst)
        end
    end
end

function Groomer:EndAllChanging()
    local toend = {}
    for k, v in pairs(self.changers) do
        table.insert(toend, k)
    end
    for i, v in ipairs(toend) do
        self:EndChanging(v)
    end
end

local function DoChange(self, doer, skins)
    doer.sg.statemem.ischanging = true
    doer.sg:GoToState("dressupwardrobe", function()
        local occupant = self:GetOccupant()
        if occupant then
            if occupant.sg then
                occupant.sg:GoToState("skin_change", function()
                    self:ApplyTargetSkins(occupant, doer, skins)
                end)
            else
                self:ApplyTargetSkins(occupant, doer, skins)
            end
        end
    end)
    if self.changefn then
        self.changefn(self.inst)
    end
    return true
end

function Groomer:ActivateChanging(doer, skins)
    if skins == nil or
        doer.sg.currentstate.name ~= "openwardrobe" or
        self:GetOccupant() == nil or
        (self.canactivatechangingfn and not self.canactivatechangingfn(self.inst, self:GetOccupant(), doer, skins))
    then
        return false
    end

    return DoChange(self, doer, skins)
end

function Groomer:ApplyTargetSkins(target, doer, skins)
    if target and self.applytargetskinsfn then
        self.applytargetskinsfn(self.inst, target, doer, skins)
    end
end

--------------------------------------------------------------------------
--Check for auto-closing conditions
--------------------------------------------------------------------------
function Groomer:OnUpdate(dt)
    if next(self.changers) == nil then
        self.inst:StopUpdatingComponent(self)
    else
        local toend = {}
        for k, v in pairs(self.changers) do
            if not (k:IsNear(self.inst, self.range) and
                    CanEntitySeeTarget(k, self.inst)) then
                table.insert(toend, k)
            end
        end
        for i, v in ipairs(toend) do
            self:EndChanging(v)
        end
    end
end

--------------------------------------------------------------------------

function Groomer:OnRemoveFromEntity()
    self:EndAllChanging()
    self.inst:RemoveEventCallback("onignite", OnIgnite)
    self.inst:RemoveTag("groomer")
    self.inst:RemoveTag("dressable")
end

Groomer.OnRemoveEntity = Groomer.EndAllChanging

return Groomer
