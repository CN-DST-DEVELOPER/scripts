local function onpickable(self)
    if self.canbepicked and self.caninteractwith then
        self.inst:AddTag("pickable")
    else
        self.inst:RemoveTag("pickable")
    end
end

local function oncyclesleft(self, cyclesleft)
    if cyclesleft == 0 then
        self.inst:AddTag("barren")
    else
        self.inst:RemoveTag("barren")
    end
end

local function onquickpick(self, quickpick)
    if quickpick then
        self.inst:AddTag("quickpick")
    else
        self.inst:RemoveTag("quickpick")
    end
end

local function onjostlepick(self, jostlepick)
    if jostlepick then
        self.inst:AddTag("jostlepick")
    else
        self.inst:RemoveTag("jostlepick")
    end
end

local Pickable = Class(function(self, inst)
    self.inst = inst
    self.canbepicked = nil
    self.regentime = nil
    self.baseregentime = nil
    self.product = nil
    self.onregenfn = nil
    self.onpickedfn = nil
    self.makeemptyfn = nil
    self.makefullfn = nil
    self.cycles_left = nil
    self.max_cycles = nil
    self.transplanted = false
    self.caninteractwith = true
    self.numtoharvest = 1
    self.quickpick = false
    self.jostlepick = false
    self.wildfirestarter = false

    self.droppicked = nil
    self.dropheight = nil

    self.paused = false
    self.pause_time = 0
    self.targettime = nil

    self.protected_cycles = nil
    self.task = nil

    self.useexternaltimer = false
    --self.startregentimer = nil
    --self.stopregentimer = nil
    --self.pauseregentimer = nil
    --self.resumeregentimer = nil
    --self.getregentimertime = nil
    --self.setregentimertime = nil
    --self.regentimerexists = nil

	--self.remove_when_picked = false
end,
nil,
{
    canbepicked = onpickable,
    caninteractwith = onpickable,
    cycles_left = oncyclesleft,
    quickpick = onquickpick,
    jostlepick = onjostlepick,
})

function Pickable:OnRemoveFromEntity()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end

    self.inst:RemoveTag("pickable")
    self.inst:RemoveTag("barren")
    self.inst:RemoveTag("quickpick")
end

local function OnRegen(inst)
    inst.components.pickable:Regen()
end

function Pickable:LongUpdate(dt)
    if not self.paused and self.targettime ~= nil and not self.inst:HasTag("withered") then
        if not self.useexternaltimer then
            if self.task ~= nil then
                self.task:Cancel()
                self.task = nil
            end
            local time = GetTime()
            if self.targettime > time + dt then
                --resechedule
                local time_to_pickable = self.targettime - time - dt
                time_to_pickable = SpringGrowthMod(time_to_pickable)
                self.task = self.inst:DoTaskInTime(time_to_pickable, OnRegen)
                self.targettime = time + time_to_pickable
            else
                --become pickable right away
                self:Regen()
            end
        else
            local time_to_pickable = self.getregentimertime(self.inst) - dt
            time_to_pickable = SpringGrowthMod(time_to_pickable)
            self.setregentimertime(self.inst, time_to_pickable)
        end
    end
end

function Pickable:IsWildfireStarter()
    return self.wildfirestarter == true or self.inst:HasTag("withered")
end

function Pickable:FinishGrowing()
    if not self.useexternaltimer then
        if self.task ~= nil and not (self.canbepicked or self.inst:HasTag("withered")) then
            self.task:Cancel()
            self.task = nil
            self:Regen()
            return true
        end
    else
        if self.regentimerexists(self.inst) and not (self.canbepicked or self.inst:HasTag("withered")) then
            self.stopregentimer(self.inst)
            self:Regen()
            return true
        end
    end
	return false
end

function Pickable:Resume()
    if not self.useexternaltimer then
        if self.paused then
            self.paused = false
            if not (self.canbepicked or self:IsBarren()) then
                if self.pause_time ~= nil then
                    self.pause_time = SpringGrowthMod(self.pause_time)
                    if self.task ~= nil then
                        self.task:Cancel()
                    end
                    self.task = self.inst:DoTaskInTime(self.pause_time, OnRegen)
                    self.targettime = GetTime() + self.pause_time
                else
                    self:MakeEmpty()
                end
            end
        end
    else
        self.paused = false
        if not (self.canbepicked or self:IsBarren()) then
            local pause_time = self.getregentimertime(self.inst)
            if pause_time ~= nil then
                pause_time = SpringGrowthMod(pause_time)
                self.resumeregentimer(self.inst)
                self.setregentimertime(self.inst, pause_time)
            else
                self:MakeEmpty()
            end
        end
    end
end

function Pickable:Pause()
    if not self.useexternaltimer then
        if not self.paused then
            self.paused = true
            self.pause_time = self.targettime ~= nil and math.max(0, self.targettime - GetTime()) or nil

            if self.task ~= nil then
                self.task:Cancel()
                self.task = nil
            end
        end
    else
        self.pauseregentimer(self.inst)
        self.paused = true
    end
end

function Pickable:GetDebugString()
    local time = GetTime()
    local str = ""
    if self.caninteractwith then
        str = str.."caninteractwith "
    end
    if self.paused then
        str = str.."paused "
        if self.pause_time ~= nil then
            str = str..string.format("%2.2f ", self.pause_time)
        end
    end
    if not self.transplanted then
        str = str.."Not transplanted "
    elseif self.max_cycles ~= nil and self.cycles_left ~= nil then
        str = str..string.format("transplated; cycles: %d/%d ", self.cycles_left, self.max_cycles)
    end
    if self.protected_cycles ~= nil and self.protected_cycles > 0 then
        str = str..string.format("protected cycles: %d ", self.protected_cycles)
    end
    if self.targettime ~= nil and self.targettime > time then
        str = str..string.format("Regen in: %.2f ", self.targettime - time)
    end
    return str
end

function Pickable:SetUp(product, regen, number)
    self.canbepicked = true
    self.product = product
    self.baseregentime = regen
    self.regentime = regen
    self.numtoharvest = number or 1
end

-------------------------------------------------------------------------------
--V2C: Sadly, these weren't being used most of the time
--     so for consitency, don't use them anymore -__ -"
--     Keeping them around in case MODs were using them
function Pickable:SetOnPickedFn(fn)
    self.onpickedfn = fn
end

function Pickable:SetOnRegenFn(fn)
    self.onregenfn = fn
end

function Pickable:SetMakeBarrenFn(fn)
    self.makebarrenfn = fn
end

function Pickable:SetMakeEmptyFn(fn)
    self.makeemptyfn = fn
end
-------------------------------------------------------------------------------

function Pickable:CanBeFertilized()
    return self:IsBarren() or self.inst:HasTag("withered")
end

function Pickable:ChangeProduct(newProduct)
    self.product = newProduct
end

function Pickable:Fertilize(fertilizer, doer)
    if self.inst.components.burnable ~= nil then
        self.inst.components.burnable:StopSmoldering()
    end

    local fertilize_cycles = 0
    if fertilizer.components.fertilizer ~= nil then
        if doer ~= nil and
            doer.SoundEmitter ~= nil and
            fertilizer.components.fertilizer.fertilize_sound ~= nil then
            doer.SoundEmitter:PlaySound(fertilizer.components.fertilizer.fertilize_sound)
        end
        fertilize_cycles = fertilizer.components.fertilizer.withered_cycles
    end

    self.cycles_left = self.max_cycles

    if self.inst.components.witherable ~= nil then
        self.protected_cycles = (self.protected_cycles or 0) + fertilize_cycles
        if self.protected_cycles <= 0 then
            self.protected_cycles = nil
        end

        self.inst.components.witherable:Enable(self.protected_cycles == nil)
        if self.inst.components.witherable:IsWithered() then
            self.inst.components.witherable:ForceRejuvenate()
        else
            self:MakeEmpty()
        end
    else
        self:MakeEmpty()
    end

	return true
end

function Pickable:OnSave()
    local data =
    {
        protected_cycles = self.protected_cycles,
        picked = not self.canbepicked and true or nil,
        transplanted = self.transplanted and true or nil,
        paused = self.paused and true or nil,
        caninteractwith = self.caninteractwith and true or nil,
    }

    if self.cycles_left ~= self.max_cycles then
        data.cycles_left = self.cycles_left
        data.max_cycles = self.max_cycles
    end

    if not self.useexternaltimer then
        if self.pause_time ~= nil and self.pause_time > 0 then
            data.pause_time = self.pause_time
        end

        if self.targettime ~= nil then
            local time = GetTime()
            if self.targettime > time then
                data.time = math.floor(self.targettime - time)
            end
        end
    end

    return next(data) ~= nil and data or nil
end

function Pickable:OnLoad(data)
    self.transplanted = data.transplanted or false
    self.cycles_left = data.cycles_left or self.cycles_left
    self.max_cycles = data.max_cycles or self.max_cycles

    if data.picked or data.time ~= nil then
        if self:IsBarren() and self.makebarrenfn ~= nil then
            self.makebarrenfn(self.inst, true)
        elseif self.makeemptyfn ~= nil then
            self.makeemptyfn(self.inst)
        end
        self.canbepicked = false
    else
        if self.makefullfn ~= nil then
            self.makefullfn(self.inst)
        end
        self.canbepicked = true
    end

    if data.caninteractwith then
        self.caninteractwith = data.caninteractwith
    end

    if not self.useexternaltimer then
        if data.paused then
            self.paused = true
            self.pause_time = data.pause_time
            if self.task ~= nil then
                self.task:Cancel()
                self.task = nil
            end
        elseif data.time ~= nil then
            if self.task ~= nil then
                self.task:Cancel()
            end
            self.task = self.inst:DoTaskInTime(data.time, OnRegen)
            self.targettime = GetTime() + data.time
        end
    end

    if data.makealwaysbarren == 1 and self.makebarrenfn ~= nil then
        self:MakeBarren()
    end

    self.protected_cycles = data.protected_cycles ~= nil and data.protected_cycles > 0 and data.protected_cycles or nil
    if self.inst.components.witherable ~= nil then
        self.inst.components.witherable:Enable(self.protected_cycles == nil)
    end
end

function Pickable:IsBarren()
    return self.cycles_left == 0
end

function Pickable:CanBePicked()
    return self.canbepicked
end

function Pickable:Regen()
    self.canbepicked = true
    if self.onregenfn ~= nil then
        self.onregenfn(self.inst)
    end
    if self.makefullfn ~= nil then
        self.makefullfn(self.inst)
    end
    self.targettime = nil
    self.task = nil
end

function Pickable:MakeBarren()
    self.cycles_left = 0

    local wasempty = not self.canbepicked
    self.canbepicked = false

    if not self.useexternaltimer then
        if self.task ~= nil then
            self.task:Cancel()
            self.task = nil
        end
    else
        self.stopregentimer(self.inst)
    end

    if self.makebarrenfn ~= nil then
        self.makebarrenfn(self.inst, wasempty)
    end
end

function Pickable:OnTransplant()
    self.transplanted = true

    if self.ontransplantfn ~= nil then
        self.ontransplantfn(self.inst)
    end
end

function Pickable:MakeEmpty()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end

    if self.makeemptyfn ~= nil then
        self.makeemptyfn(self.inst)
    end

    self.canbepicked = false

    if not self.paused and self.baseregentime ~= nil then
        local time = self.baseregentime
        if self.getregentimefn ~= nil then
            time = self.getregentimefn(self.inst)
        end
        time = SpringGrowthMod(time)

        if not self.useexternaltimer then
            self.task = self.inst:DoTaskInTime(time, OnRegen)
            self.targettime = GetTime() + time
        else
            self.startregentimer(self.inst, time)
        end
    end
end

------------------------
-- *** DEPRECATED ***
--   xxx   NOTES(JBK): Added TheWorld behaviour.
--   xxx   If picker is nil it will not produce items.
--   xxx   If picker is TheWorld it will drop items at the inst. This will NOT fire the regular event picked but will fire pickedbyworld instead to differentiate the type of pick.
--   xxx   If picker is something with an inventory it will harvest normally.
-- ***
------------------------
-- V2C:
-- - nil picker will not produce items FOR REAL now.
-- - ANY picker (not just TheWorld) with no inventory will drop items at the inst. (Previously, this was generating garbage at 0,0,0)
-- - Always fire "picked" event. The "picker" param will tell you what you need to know.
-- - Removed redundant "pickedbyworld" event; do NOT want all prefabs to have to register
--   two different events to handle being picked.

function Pickable:Pick(picker)
    if self.canbepicked and self.caninteractwith then
        if self.transplanted and self.cycles_left ~= nil then
            self.cycles_left = math.max(0, self.cycles_left - 1)
        end

        if self.protected_cycles ~= nil then
            self.protected_cycles = self.protected_cycles - 1
            if self.protected_cycles <= 0 then
                self.protected_cycles = nil
                if self.inst.components.witherable ~= nil then
                    self.inst.components.witherable:Enable(true)
                end
            end
        end

        local loot = nil
		if picker and self.product or self.use_lootdropper_for_product then
			local inventory = picker and picker.components.inventory or nil
            local pt = self.inst:GetPosition()
            if self.droppicked and self.inst.components.lootdropper ~= nil then
                pt.y = pt.y + (self.dropheight or 0)
                if self.use_lootdropper_for_product then
                    self.inst.components.lootdropper:DropLoot(pt)
                else
                    local num = self.numtoharvest or 1
                    for i = 1, num do
                        self.inst.components.lootdropper:SpawnLootPrefab(self.product, pt)
                    end
                end
            else
                if self.use_lootdropper_for_product then
					loot = self.inst.components.lootdropper:GenerateLoot()
					for i, prefab in ipairs(loot) do --convert prefabs to insts
						loot[i] = self.inst.components.lootdropper:SpawnLootPrefab(prefab)
                    end
					if #loot > 0 then
						if inventory then
							picker:PushEvent("picksomething", { object = self.inst, loot = loot })
						end
						for i, item in ipairs(loot) do
							if inventory and item.components.inventoryitem then
								inventory:GiveItem(item, nil, pt)
							else
								item.Transform:SetPosition(pt:Get())
							end
						end
					end
                else
                    loot = SpawnPrefab(self.product)
                    if loot ~= nil then
                        if loot.components.inventoryitem ~= nil then
							loot.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)
                        end
                        if self.numtoharvest > 1 and loot.components.stackable ~= nil then
                            loot.components.stackable:SetStackSize(self.numtoharvest)
                        end
						if inventory then
                            picker:PushEvent("picksomething", { object = self.inst, loot = loot })
						end
						if inventory and loot.components.inventoryitem then
							inventory:GiveItem(loot, nil, pt)
						else
                            loot.Transform:SetPosition(pt:Get())
                        end
                    end
                end
            end
        end

        if self.onpickedfn ~= nil then
            self.onpickedfn(self.inst, picker, loot)
        end

        self.canbepicked = false

        if self.baseregentime ~= nil and not (self.paused or self:IsBarren() or self.inst:HasTag("withered")) then
            self.regentime = SpringGrowthMod(self.baseregentime)

            if not self.useexternaltimer then
                if self.task ~= nil then
                    self.task:Cancel()
                end
                self.task = self.inst:DoTaskInTime(self.regentime, OnRegen)
                self.targettime = GetTime() + self.regentime
            else
                self.stopregentimer(self.inst)
                self.startregentimer(self.inst, self.regentime)
            end
        end

		self.inst:PushEvent("picked", { picker = picker, loot = loot, plant = self.inst })

		if self.remove_when_picked then
			self.inst:Remove()
		end

        return true, EntityScript.is_instance(loot) and {loot} or loot
    end
end

function Pickable:ConsumeCycles(cycles)
    if self.transplanted and self.cycles_left ~= nil then
        self.cycles_left = math.max(0, self.cycles_left - cycles)
    end

    if self.protected_cycles ~= nil then
        self.protected_cycles = math.max(0, self.protected_cycles - cycles)
    end
end

return Pickable
