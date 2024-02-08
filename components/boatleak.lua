local BoatLeak = Class(function(self, inst)
    self.inst = inst

    self.has_leaks = false
	self.leak_build = "boat_leak_build"

	self.isdynamic = false
end)

local function set_repair_state(inst, repair_state)
    if inst.components.boatleak then
        inst.components.boatleak:SetState(repair_state)
    end
end

function BoatLeak:Repair(doer, patch_item)
    if not self.inst:HasTag("boat_leak") then return false end

    local did_repair = false
    if patch_item.components.repairer then
        local current_platform = self.inst:GetCurrentPlatform()
        if current_platform and current_platform.components.repairable then
            current_platform.components.repairable:Repair(doer, patch_item)
            -- consumed in the repair
            did_repair = true
        end
    end

    if not did_repair then
        if patch_item.components.stackable ~= nil then
            patch_item.components.stackable:Get():Remove()
        else
            patch_item:Remove()
        end
    end

    local patch_type = (patch_item.components.boatpatch ~= nil and patch_item.components.boatpatch:GetPatchType())
        or nil
    local repair_state = (patch_type ~= nil and "repaired_"..patch_type) or "repaired"

    self.inst.AnimState:PlayAnimation("leak_small_pst")
    self.inst:DoTaskInTime(0.4, set_repair_state, repair_state)

	return true
end

function BoatLeak:ChangeToRepaired(repair_build_name, sndoverride)
    self.inst:RemoveTag("boat_leak")
    self.inst:AddTag("boat_repaired_patch")

    local AnimState = self.inst.AnimState
    AnimState:SetBuild(repair_build_name)
    AnimState:SetBankAndPlayAnimation("boat_repair", "pre_idle")
    AnimState:SetSortOrder(3)
    AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    AnimState:SetLayer(LAYER_BACKGROUND)

    if not sndoverride then
        self.inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/repair")
    else
        self.inst.SoundEmitter:PlaySound(sndoverride)
    end

    self.inst.SoundEmitter:KillSound("small_leak")
    self.inst.SoundEmitter:KillSound("med_leak")

    self.has_leaks = false

    if self.onrepairedleak ~= nil then
        self.onrepairedleak(self.inst)
    end
end

function BoatLeak:SetState(state, skip_open)
	if state == self.current_state then return end

    local AnimState = self.inst.AnimState

	if state == "small_leak" then
        self.inst:RemoveTag("boat_repaired_patch")
	    self.inst:AddTag("boat_leak")

        AnimState:SetBuild(self.leak_build)
		AnimState:SetBankAndPlayAnimation("boat_leak", "leak_small_pre")
        AnimState:PushAnimation("leak_small_loop", true)
        AnimState:SetSortOrder(0)
        AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
        AnimState:SetLayer(LAYER_WORLD)
        if skip_open then
            AnimState:SetTime(11 * FRAMES)
        end

        self.inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/fountain_small_LP", "small_leak")

        self.has_leaks = true

		if self.onsprungleak ~= nil then
			self.onsprungleak(self.inst, state)
		end
	elseif state == "med_leak" then
        self.inst:RemoveTag("boat_repaired_patch")
	    self.inst:AddTag("boat_leak")

        AnimState:SetBuild(self.leak_build)
		AnimState:SetBankAndPlayAnimation("boat_leak", "leak_med_pre")
        AnimState:PushAnimation("leak_med_loop", true)
        AnimState:SetSortOrder(0)
        AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
        AnimState:SetLayer(LAYER_WORLD)
        if skip_open then
            AnimState:SetTime(11 * FRAMES)
        end

        self.inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/fountain_medium_LP", "med_leak")

        if not self.has_leaks then
            self.has_leaks = true

			if self.onsprungleak ~= nil then
				self.onsprungleak(self.inst, state)
			end
        end
	elseif state == "repaired" then
        self:ChangeToRepaired("boat_repair_build")
	elseif state == "repaired_tape" then
        self:ChangeToRepaired("boat_repair_tape_build")
    elseif state == "repaired_treegrowth" then
        self:ChangeToRepaired("treegrowthsolution","waterlogged2/common/repairgoop")
        self.inst.AnimState:SetBankAndPlayAnimation("treegrowthsolution", "pre_idle")
        self.inst:ListenForEvent("animover", function()
            if self.inst.AnimState:IsCurrentAnimation("pre_idle") then
                self.inst.AnimState:PlayAnimation("idle")
            elseif self.inst.AnimState:IsCurrentAnimation("idle") then
                self.inst:Remove()
            end
        end)
    end

	self.current_state = state
end

function BoatLeak:SetBoat(boat)
    self.boat = boat
end

function BoatLeak:IsFinishedSpawning()
    if self.current_state == "small_leak" then
        return self.inst.AnimState:IsCurrentAnimation("leak_small_loop")
    elseif self.current_state == "med_leak" then
        return self.inst.AnimState:IsCurrentAnimation("leak_med_loop")
    else
        return true
    end
end

-- Note: Currently save and load is only used for dynamic leaks (e.g. caused by cookie cutter). Saving/loading
-- for leaks caused by collision is handled from HullHealth.
function BoatLeak:OnSave(data)
	return (self.current_state ~= nil and self.isdynamic) and { leak_state = self.current_state } or nil
end

function BoatLeak:OnLoad(data)
	if data ~= nil and data.leak_state ~= nil then
		self.isdynamic = true

		self.inst:DoTaskInTime(0, function()
			local boat = self.inst:GetCurrentPlatform()

			if boat ~= nil then
				self:SetBoat(boat)
				self:SetState(data.leak_state)
				table.insert(boat.components.hullhealth.leak_indicators_dynamic, self.inst)
			else
				self.inst:Remove()
			end
		end)
    end
end

return BoatLeak