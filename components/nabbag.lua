local Nabbag = Class(function(self, inst)
    self.inst = inst

    -- Recommended to explicitly add tag to prefab pristine state
    self.inst:AddTag("nabbag")
end)

function Nabbag:OnRemoveFromEntity()
    self.inst:RemoveTag("nabbag")
end

local NABBAG_CANTTAGS = {"INLIMBO", "FX", "_container", "heavy", "smolder"}
function Nabbag:ReplicateNetFromAct(act)
    if self.replicatingnet then
        return
    end
    self.replicatingnet = true

    -- Replicate this success to all entities in a forward cone.
    local oldtarget = act.target
    local wholearcangle_degrees = TUNING.SKILLS.WORTOX.NABBAG_CONEANGLE
    local max_dist = TUNING.SKILLS.WORTOX.NABBAG_MAX_RADIUS
    local circle_dist = TUNING.SKILLS.WORTOX.NABBAG_CIRCLE_RADIUS
    local x, y, z = act.doer.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, max_dist, nil, NABBAG_CANTTAGS)
    for _, ent in ipairs(ents) do
        if ent:IsValid() and act.doer:IsEntityInFrontConeSlice(ent, wholearcangle_degrees, max_dist, circle_dist) then
            if ent:IsActionValid(ACTIONS.NET, act.rmb) then
                act.target = ent
                ACTIONS.NET.fn(act)
                act.invobject:OnUsedAsItem(ACTIONS.NET, act.doer, act.target)
                if not act.invobject:IsValid() then -- We used it up!
                    break
                end
            end
        end
    end
    act.target = oldtarget

    self.replicatingnet = nil
end

local NABBAG_MUSTTAGS = {"_inventoryitem"}
local NABBAG_CANTTAGS = {"INLIMBO", "FX", "_container", "heavy", "fire"}
function Nabbag:DoNabFromAct(act)
    local success, reason
    if act.target:HasAnyTag(NABBAG_CANTTAGS) then
        success, reason = false, nil
    else
        success, reason = ACTIONS.PICKUP.fn(act)
    end
    if success then
        local finiteuses = act.invobject.components.finiteuses -- Do not use finiteuses use for one use of this action.
        -- Temporarily override how picking up too many items is handled to stack up stackables.
        local stackables = {}
        local HandleLeftoversFn_original = act.doer.components.inventory.HandleLeftoversFn
        local doer_pos = act.doer:GetPosition()
        act.doer.components.inventory.HandleLeftoversFn = function(doer, item)
            local leftovers
            if item.components.stackable then
                local stackname
                if item.skinname then
                    stackname = string.format("%s!%s", item.prefab, item.skinname)
                else
                    stackname = item.prefab
                end
                local active_item = act.doer.components.inventory:GetActiveItem() -- Active item may change at any point in the loop.
                if active_item and active_item.components.stackable and not active_item.components.stackable:IsFull() then
                    local stackname_active_item
                    if active_item.skinname then
                        stackname_active_item = string.format("%s!%s", active_item.prefab, active_item.skinname)
                    else
                        stackname_active_item = active_item.prefab
                    end
                    if not stackables[stackname_active_item] then
                        stackables[stackname_active_item] = active_item
                    end
                end
                local stackitem = stackables[stackname]
                if stackitem and not stackitem.components.stackable:IsFull() then
                    leftovers = stackitem.components.stackable:Put(item)
                    if stackitem.components.stackable:IsFull() then
                        stackables[stackname] = leftovers
                    end
                else
                    stackables[stackname] = item
                end
            end
            if item:IsValid() then
                doer.components.inventory:DropItem(item, true, true)
            end
            if leftovers and leftovers:IsValid() then
                doer.components.inventory:DropItem(leftovers, true, true)
            end
        end

        -- Replicate this success to all entities in a forward cone.
        local oldtarget = act.target
        local wholearcangle_degrees = TUNING.SKILLS.WORTOX.NABBAG_CONEANGLE
        local max_dist = TUNING.SKILLS.WORTOX.NABBAG_MAX_RADIUS
        local circle_dist = TUNING.SKILLS.WORTOX.NABBAG_CIRCLE_RADIUS
        local max_uses_per_nab = 0
        if finiteuses then
            max_uses_per_nab = finiteuses.total * TUNING.SKILLS.WORTOX.NABBAG_MAX_USES_PER_NAB_PERCENT
        end
        local max_items_per_nab = TUNING.SKILLS.WORTOX.NABBAG_MAX_ITEMS_PER_NAB - 1 -- - 1 for the first item picked up above.
        local x, y, z = act.doer.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, max_dist, NABBAG_MUSTTAGS, NABBAG_CANTTAGS)
        for _, ent in ipairs(ents) do
            if ent:IsValid() and act.doer:IsEntityInFrontConeSlice(ent, wholearcangle_degrees, max_dist, circle_dist) and ent.replica.inventoryitem and ent.replica.inventoryitem:CanBePickedUp(act.doer) then
                act.target = ent
                ACTIONS.PICKUP.fn(act)
                if finiteuses then
                    if max_uses_per_nab > 0 then
                        max_uses_per_nab = max_uses_per_nab - 1
                        finiteuses:Use(1)
                        if not act.invobject:IsValid() then -- We used it up!
                            break
                        end
                    end
                end
                if max_items_per_nab > 1 then
                    max_items_per_nab = max_items_per_nab - 1
                else
                    break -- Stop picking up more.
                end
            end
        end
        act.target = oldtarget
        act.doer.components.inventory.HandleLeftoversFn = HandleLeftoversFn_original
    end
    return success, reason
end

return Nabbag
