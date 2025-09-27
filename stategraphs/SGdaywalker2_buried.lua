require("stategraphs/commonstates")

local events =
{
	CommonHandlers.OnElectrocute(),
}

local function GetLevelAnim(inst, anim)
	return anim..(inst.sg.mem.level == 2 and "_small" or "_full")
end

local function PlayAnimation(inst, anim, loop)
	anim = GetLevelAnim(inst, anim)
	inst.AnimState:PlayAnimation(anim, loop)
	if inst.junkfx then
		for i, v in ipairs(inst.junkfx) do
			v.AnimState:PlayAnimation(anim, loop)
		end
	end
end

local function PushAnimation(inst, anim, loop)
	anim = GetLevelAnim(inst, anim)
	inst.AnimState:PushAnimation(anim, loop)
	if inst.junkfx then
		for i, v in ipairs(inst.junkfx) do
			v.AnimState:PushAnimation(anim, loop)
		end
	end
end

local states =
{
	State{
		name = "transition",
	},

	State{
		name = "idle",

		onenter = function(inst)
			PlayAnimation(inst, "buried_hold", true)
			local numloops = math.random(5)
			if numloops > 3 then
				--give extra chance for 2-3 loops instead of 1
				numloops = numloops - 2
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * numloops)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("struggle")
		end,
	},

	State{
		name = "struggle",

		onenter = function(inst)
			PlayAnimation(inst, "buried")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/buried_stagger")

			local t = GetTime()
			if (inst.sg.mem.lasttalk or 0) + 4 < t then
				inst.sg.mem.lasttalk = t
				local strtbl = inst:IsNearPlayer(12, true) and "DAYWALKER2_BURIED_NEAR" or "DAYWALKER2_BURIED_FAR"
				inst.components.talker:Chatter(strtbl, math.random(#STRINGS[strtbl]), nil, nil, CHATPRIORITIES.HIGH)
			end
		end,

		timeline =
		{
			FrameEvent(26, function(inst)
				local junk = inst.components.entitytracker:GetEntity("junk")
				if junk then
					junk:PushEvent("shake")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "tryemerge",
		tags = { "noelectrocute" },

		onenter = function(inst)
			PlayAnimation(inst, "buried_stagger")
			PushAnimation(inst, "buried_stagger_loop")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/buried_stagger")
			inst.components.talker:Chatter("DAYWALKER2_BURIED_NEAR", 3, nil, nil, CHATPRIORITIES.HIGH)
		end,
	},

	State{
		name = "cancelemerge",

		onenter = function(inst)
			PlayAnimation(inst, "buried_stagger_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},
}

local function TryElectrocuteShakeJunk(inst)
	local junk = inst.components.entitytracker:GetEntity("junk")
	if junk then
		junk:PushEvent("shake")
	end
end

local function TryElectrocuteShakeJunk2(inst)
	if inst.sg.mem.level == 2 then
		TryElectrocuteShakeJunk(inst)
	end
end

CommonStates.AddElectrocuteStates(states,
{	--timeline
	loop =
	{
		FrameEvent(0, TryElectrocuteShakeJunk2),
		FrameEvent(8, TryElectrocuteShakeJunk2),
		FrameEvent(16, TryElectrocuteShakeJunk2),
		FrameEvent(24, TryElectrocuteShakeJunk2),
		FrameEvent(32, TryElectrocuteShakeJunk2),
	},
	pst =
	{
		FrameEvent(0, function(inst)
			if inst.sg.mem.level ~= 2 then
				TryElectrocuteShakeJunk(inst)
			end
		end),
	},
},
{	--anims
	loop = function(inst)
		local anim = inst.sg.mem.level == 2 and "buried_stagger_loop_small" or "buried_full_shock_loop"
		if inst.junkfx then
			for i, v in ipairs(inst.junkfx) do
				v.AnimState:PlayAnimation(anim, true)
			end
		end
		return anim
	end,
	pst = function(inst)
		local anim = inst.sg.mem.level == 2 and "buried_stagger_pst_small" or "buried_full_shock_pst"
		if inst.junkfx then
			for i, v in ipairs(inst.junkfx) do
				v.AnimState:PlayAnimation(anim)
			end
		end
		return anim
	end,
})

return StateGraph("daywalker2_buried", states, events, "idle")
