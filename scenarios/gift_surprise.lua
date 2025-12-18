local SURPRISE_RANGE = 15
local SURPRISE_ONEOF_TAGS = { "winter_tree", "unwrappable" }
local BASE_TIME = 20 * FRAMES
local function SurpriseExclamationMark(inst, doer)
	local x, y, z = inst.Transform:GetWorldPosition()
	local function DoSurprise_Delay(v)
		if v.TransformIntoLeif and v.is_leif then
			local leif = v:TransformIntoLeif()
			if leif then
				leif:AddTag("houndfriend") -- this saves
				if leif.components.combat and doer then
					leif.components.combat:SuggestTarget(doer)
				end
			end
		elseif v.jiggle and v.components.unwrappable then -- Gifts
			v.components.unwrappable:Unwrap(doer)
		end
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, SURPRISE_RANGE, nil, nil, SURPRISE_ONEOF_TAGS)) do
		v:DoTaskInTime(math.random() * BASE_TIME, DoSurprise_Delay)
	end
end

local function OnLoad(inst, scenariorunner)
    inst.giftsurprise_triggerfn = function(inst, data)
        local doer = data and (data.doer or data.owner)
        SurpriseExclamationMark(inst, doer)
        scenariorunner:ClearScenario()
	end
	inst:ListenForEvent("unwrapped", inst.giftsurprise_triggerfn)
    if not inst.jiggle then -- Not a surprise gift, so trigger when we pick it up
	    inst:ListenForEvent("onpickup", inst.giftsurprise_triggerfn)
    end
end

local function OnCreate(inst, scenariorunner)

end

local function OnDestroy(inst, scenariorunner)
    if inst.giftsurprise_triggerfn ~= nil then
        inst:RemoveEventCallback("unwrapped", inst.giftsurprise_triggerfn)
        inst:RemoveEventCallback("onpickup", inst.giftsurprise_triggerfn)
    end
end

return
{
    OnLoad = OnLoad,
	OnCreate = OnCreate,
    OnDestroy = OnDestroy,
}
