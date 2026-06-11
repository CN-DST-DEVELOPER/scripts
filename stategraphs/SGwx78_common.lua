require("components/dynamicmusic") --need to load global ShouldPlayDangerMusic for dedi server

local SGWX78Common = {}

--------------------------------------------------------
-- WX-78 common states

local WX_SPIN_CANT_TAGS = { "INLIMBO", "NOCLICK", "FX", "decor", "intense", "companion", "flight", "invisible", "notarget", "noattack", "wall" }
local WX_SPIN_ONEOF_TAGS = ConcatArrays({ "CHOP_workable", "MINE_workable", "LunarBuildup", "_combat", --[["pickable",]] }, HARVESTABLE_PLANT_TARGET_TAGS)

local function GetLocalAnalogXY(inst)
	if inst.HUD and inst.components.playercontroller then
		local isenabled, ishudblocking = inst.components.playercontroller:IsEnabled()
		if isenabled or ishudblocking then
			local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
			local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
			local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
			if math.abs(xdir) >= deadzone or math.abs(ydir) >= deadzone then
				return xdir, ydir
			end
		end
	end
end

local function GetLocalAnalogDir(inst)
	local xdir, ydir = GetLocalAnalogXY(inst)
	if xdir then
		local dir = TheCamera:GetRightVec() * xdir - TheCamera:GetDownVec() * ydir
		return dir:Normalize()
	end
end

local function GetWX78ScreechRange(inst)
    local num_modules = inst._screech_modules or 1
    return num_modules * TUNING.WX78_SCREECH_RANGE -- + (num_rangeboosters * TUNING.WX78_SCREECH_RANGEBOOSTER_RANGE)
end
local WX_SCARE_MUST_TAGS = { "_combat", "_health" }
local WX_SCARE_CANT_TAGS = { "INLIMBO", "epic" }
local function DelayedWX78ScreechWake(v)
    if v.components.sleeper then
        v.components.sleeper:WakeUp()
    end
end
local function DoWX78Screech(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local range = GetWX78ScreechRange(inst)
    local ents = TheSim:FindEntities(x, y, z, range, WX_SCARE_MUST_TAGS, WX_SCARE_CANT_TAGS)
    for i, v in ipairs(ents) do
        if v ~= inst and
            v.components.hauntable and
            v.components.hauntable.panicable and
            inst.components.combat:CanTarget(v) and
            not inst.components.combat:IsAlly(v)
        then
            if v.components.sleeper then
                v:DoTaskInTime(math.random(), DelayedWX78ScreechWake)
            end
            v.components.hauntable:Panic(TUNING.WX78_SCREECH_PANIC_TIME)
			if v.brain then
				v.brain:ForceUpdate()
			end
        end
    end
end

local WX_SHIELDING_KEY = "wx_shielding"
local function UpdateWX78ShieldingDefense(inst)
    inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.WX78_SHIELDING_ARMOR, WX_SHIELDING_KEY)
end

local function WX78ShieldOnAttacked(inst, data)
	-- wx78shieldingdamage can be nil if we exited on an attacked event push, so this will still push too.
	if inst.sg.mem.wx78shieldingdamage ~= nil then
		local damage = data and data.damage or TUNING.WX78_SHIELDING_TOTAL_DAMAGE * 0.5 -- Fallback in case of mods.

		inst.sg.mem.wx78shieldingdamage = inst.sg.mem.wx78shieldingdamage + damage
		if inst.sg.mem.wx78shieldingdamage >= TUNING.WX78_SHIELDING_TOTAL_DAMAGE then
			inst.sg.mem.wx78shieldingdamage = 0
    	    inst.sg:GoToState("wx_shield_pst")
		end
	end
end

local TAUNT_PERIOD = 2
local TAUNT_MUST_TAGS = { "_combat" }
local TAUNT_CANT_TAGS = { "INLIMBO", "player", "companion", "epic", "notaunt"}
local TAUNT_ONEOF_TAGS = { "locomotor", "lunarthrall_plant" }
local TAUNT_DIST = 16

local function IsTauntable(inst, target)
    return not (target.components.health ~= nil and target.components.health:IsDead())
        and target.components.combat ~= nil
        and not target.components.combat:TargetIs(inst)
        and target.components.combat:CanTarget(inst)
        and (
			target.components.combat:HasTarget() and
			(   target.components.combat.target:HasTag("player") or
				target.components.combat.target.components.combat:IsAlly(inst) or
				(target.components.combat.target:HasTag("companion") and target.components.combat.target.prefab ~= inst.prefab)
			)
		)
end

local function OnNewCombatTarget(inst, data)
	local oldtarget = data.oldtarget
	local newtarget = data.target
	if oldtarget and oldtarget.sg and oldtarget.sg.mem.wx78shieldingtime then
		inst.components.combat:SetTarget(oldtarget)
	end
end

local function TauntCreatures(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(TheSim:FindEntities(x, y, z, TAUNT_DIST, TAUNT_MUST_TAGS, TAUNT_CANT_TAGS, TAUNT_ONEOF_TAGS)) do
		if IsTauntable(inst, v) then
            v.components.combat:SetTarget(inst)
			-- TODO keep target on wx even when we try to switch targets?
			-- v:ListenForEvent("newcombattarget", OnNewCombatTarget)
        end
    end
end

local function ApplyWX78ShieldingDefense(inst)
	if not inst.sg.mem.wx78shieldingtime then
		inst.sg.mem.wx78shieldingtime = GetTime()
        local mass = inst.Physics:GetMass()
        if mass > 0 then
            inst.sg.mem.wxshieldingrestoremass = mass
            inst.Physics:SetMass(99999)
        end

		inst.sg.mem.wx78shieldtaunttask = inst:DoPeriodicTask(TAUNT_PERIOD, TauntCreatures, 0)

		if inst.components.inventory ~= nil then
			inst.components.inventory.thiefproof = true
		end

        -- This event listener isn't really necessacary anymore. But left just in case.
		inst:ListenForEvent("refreshwxshielddefense", UpdateWX78ShieldingDefense)
		UpdateWX78ShieldingDefense(inst)

        inst.sg.mem.wx78shieldingdamage = 0
        inst:ListenForEvent("attacked", WX78ShieldOnAttacked)
	end
end

local function ClearWX78ShieldingDefense(inst)
	if inst.sg.mem.wx78shieldingtime then
        local dt = GetTime() - inst.sg.mem.wx78shieldingtime
		inst:RemoveEventCallback("refreshwxshielddefense", UpdateWX78ShieldingDefense)
		inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, WX_SHIELDING_KEY)
        inst:RemoveEventCallback("attacked", WX78ShieldOnAttacked)

        if inst.components.wx78_abilitycooldowns
            and (dt >= TUNING.WX78_SHIELDING_MIN_TIME_COOLDOWN or inst.sg.mem.wx78shieldhit) then
            inst.components.wx78_abilitycooldowns:RestartAbilityCooldown("shielding", TUNING.WX78_SHIELDING_COOLDOWN)
        end

        if inst.sg.mem.wxshieldingrestoremass ~= nil then
            inst.Physics:SetMass(inst.sg.mem.wxshieldingrestoremass)
		end
		if inst.sg.mem.wx78shieldtaunttask ~= nil then
			inst.sg.mem.wx78shieldtaunttask:Cancel()
			inst.sg.mem.wx78shieldtaunttask = nil
		end

		if inst.components.inventory ~= nil then
			inst.components.inventory.thiefproof = nil
		end
        inst.sg.mem.wx78shieldingdamage = nil
        inst.sg.mem.wx78shieldingtime = nil
        inst.sg.mem.wx78shieldhit = nil
	end
end

local function IsSkillActivated(wx, skill)
	local skilltreeupdater = wx.components.skilltreeupdater
    if skilltreeupdater == nil and wx.components.follower ~= nil then
        local leader = wx.components.follower:GetLeader()
        skilltreeupdater = leader and leader.components.skilltreeupdater
    end
    return skilltreeupdater and skilltreeupdater:IsActivated(skill)
end

local WX78_SPIN_KEY = "wx78_spin"

SGWX78Common.AddWX78SpinStates = function(states)
    table.insert(states, State{
        name = "wx_spin_start",
		tags = { "prespin", "working", "busy", "jumping" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("chop_pre") --14 frames

            --V2C: HACK so the first loop doesn't skip a frame
            inst.AnimState:PushAnimation(
                IsSkillActivated(inst, "wx78_circuitry_gammabuffs_2") and
                "wx_spin_attack_loop" or
                "wx_spin_attack_loop_slow")

            inst:AddTag("prespin")

			--V2C: this target in start state is just for quickstart, only for player, not follower
			local buffaction = inst:GetBufferedAction()
			inst.sg.statemem.target = buffaction and inst.isplayer and buffaction.action == ACTIONS.ATTACK and buffaction.target or nil
        end,

		onupdate = function(inst)
			local target = inst.sg.statemem.target
			if target then
				if target:IsValid() then
					inst:ForceFacePoint(target.Transform:GetWorldPosition())
				else
					inst.sg.statemem.target = nil
				end
			end

			if inst.components.playercontroller and
				inst.sg:HasStateTag("busy") and
				not inst.components.playercontroller:IsAnyOfControlsPressed(
						CONTROL_ACTION,
						CONTROL_CONTROLLER_ACTION,
						CONTROL_CONTROLLER_ALTACTION,
						CONTROL_ATTACK,
						CONTROL_CONTROLLER_ATTACK,
						CONTROL_PRIMARY,
						CONTROL_SECONDARY
					)
			then
				inst.sg:RemoveStateTag("busy")
			end
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				local target = inst.sg.statemem.target
				if target and target:IsValid() then
					local dsq = inst:GetDistanceSqToInst(target)
					local physrad = target:GetPhysicsRadius(0)
					local minrange = TUNING.WX78_SPIN_RADIUS - 0.5 + physrad
					local maxrange = TUNING.WX78_SPIN_START_RANGE + physrad + 1
					if dsq >= minrange * minrange and dsq < maxrange * maxrange then
						local maxspeed = inst.components.locomotor:GetRunSpeed() * TUNING.WX78_SPIN_RUNSPEED_MULT
						maxrange = maxrange - 1
						inst.sg.statemem.quickstart = Remap(math.min(maxrange, math.sqrt(dsq)), minrange, maxrange, 1, 4)
						inst.sg.statemem.speed = maxspeed * inst.sg.statemem.quickstart
						inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
					end
				end
			end),
			FrameEvent(14, function(inst)
				inst.sg.statemem.spinning = true
				local released = not inst.sg:HasStateTag("busy") or nil
				if inst.sg.statemem.quickstart then
					--convert to world space
					local theta = inst.Transform:GetRotation() * DEGREES
					inst.sg:GoToState("wx_spin", {
						quickstart = inst.sg.statemem.quickstart,
						released = released,
						vx = inst.sg.statemem.speed * math.cos(theta),
						vz = -inst.sg.statemem.speed * math.sin(theta),
					})
				else
					inst.sg:GoToState("wx_spin", released and { released = true })
				end
			end),
		},

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.spinning then
                inst:RemoveTag("prespin")
				inst.Physics:Stop()
				inst.Physics:SetMotorVel(0, 0, 0)
            end
        end,
    })

    table.insert(states, State{
		name = "wx_spin",
		tags = { "busy", "prespin", "spinning", "working", "nopredict", "overridelocomote", "jumping" },

		onenter = function(inst, data)
			local anim =
				IsSkillActivated(inst, "wx78_circuitry_gammabuffs_2") and
				"wx_spin_attack_loop" or
				"wx_spin_attack_loop_slow"

			if not inst.AnimState:IsCurrentAnimation(anim) or inst.AnimState:GetCurrentAnimationFrame() ~= 0 then
				inst.AnimState:PlayAnimation(anim, true)
			end
			inst.sg.statemem.anim = anim
			inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
			inst:AddTag("prespin")

			if inst.components.talker then
				inst.components.talker:ShutUp()
				inst.components.talker:IgnoreAll("spinning")
			end

			inst.sg.statemem.recoilstate = "attack_recoil"

			local buffaction = inst:GetBufferedAction()
            if inst.isplayer then
			    inst.sg.statemem.target = buffaction and buffaction.action == ACTIONS.ATTACK and buffaction.target or nil
            else
			    inst.sg.statemem.target = buffaction and buffaction.target or inst.components.combat.target or nil
            end

			if data then
				if data.released then
					inst.sg:RemoveStateTag("busy")
					inst.sg:RemoveStateTag("nopredict")
				end

				inst.sg.statemem.vx = data.vx
				inst.sg.statemem.vz = data.vz

				if data.quickstart then
					inst.sg.statemem.quickstart = inst.sg.statemem.target and data.quickstart
				else
					inst.sg.statemem.remotedir = data.remotedir
					inst.sg.statemem.theta = data.theta
					inst.sg.statemem.costheta = data.costheta
					inst.sg.statemem.sintheta = data.sintheta
					inst.sg.statemem.numhits = data.numhits
					inst.sg.statemem.target = inst.sg.statemem.target or data.target
				end
			end

			if inst.sg:InNewState() and inst.CalcRecoveredDizzy then
				inst.sg.mem.wx_spin_buildup = inst:CalcRecoveredDizzy()
			end

			inst:ClearBufferedAction()
            if inst.player_classified ~= nil then
			    inst.player_classified.busyremoteoverridelocomote:set(true)
            end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.sg.statemem.targets = {}
				inst.sg.statemem.efficiency = {}
			end),
			FrameEvent(2, function(inst)
				if inst.sg.statemem.quickstart == nil then
					if inst.sg.statemem.updatedonce then
						inst.sg.statemem.targets = nil
						inst.sg.statemem.canrelease = true
					else
						inst.sg.statemem.cleartargetsafterupdate = true
					end
				end
			end),
			FrameEvent(3, function(inst)
				if inst.sg.statemem.updatedonce then
					inst.sg.statemem.targets = nil
					inst.sg.statemem.canrelease = true
				else
					inst.sg.statemem.cleartargetsafterupdate = true
				end
			end),
		},

		onupdate = function(inst, dt)
			--@V2C #HACK for switch >(
			if inst.sg.statemem.cleartargetsafterupdate and inst.sg.statemem.updatedonce then
				inst.sg.statemem.cleartargetsafterupdate = nil
				inst.sg.statemem.targets = nil
				inst.sg.statemem.canrelease = true
			--
			elseif inst.sg.statemem.targets then
				--@V2C #HACK for switch >(
				inst.sg.statemem.updatedonce = true
				--

				local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
				local canchop, canmine
				if item and item.components.tool then
					canchop = item.components.tool:CanDoAction(ACTIONS.CHOP)
					canmine = item.components.tool:CanDoAction(ACTIONS.MINE)
				end
				if not (canchop or canmine) then
					inst.AnimState:PlayAnimation(inst.sg.statemem.anim)
					inst.AnimState:SetFrame(1)
					inst.AnimState:PushAnimation("wx_spin_attack_pst", false)
					inst.sg:GoToState("idle", true)
					return
				end

				local modulecount = inst.GetModuleTypeCount and inst:GetModuleTypeCount("spin") or 0
				local efficiency_decay = modulecount > 1 and TUNING.WX78_SPIN_EFFICIENCY_DECAY_2 or TUNING.WX78_SPIN_EFFICIENCY_DECAY
				local aoe_dim = TUNING.WX78_SPIN_AOE_DIMINISHING
				local moveangle = inst.sg.statemem.vx and math.atan2(-inst.sg.statemem.vz, inst.sg.statemem.vx)
				local minangle = math.huge

				inst.components.combat.ignorehitrange = true

				local pickused = inst.sg.statemem.pickused --cache in case left state
                local harvestedcount = 0
				local didwork, didattack = false, false
				local recoiltarget
				local actiondata = {}
				local x, y, z = inst.Transform:GetWorldPosition()
				for _, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.WX78_SPIN_RADIUS + 3, nil, WX_SPIN_CANT_TAGS, WX_SPIN_ONEOF_TAGS)) do
					if v ~= inst and not inst.sg.statemem.targets[v] and v:IsValid() and v.entity:IsVisible() then
						local x1, y1, z1 = v.Transform:GetWorldPosition()
						local dx = x1 - x
						local dz = z1 - z
						local range = TUNING.WX78_SPIN_RADIUS + v:GetPhysicsRadius(0)
						if dx * dx + dz * dz < range * range then
							local hit

							local hasbuildup = v.components.lunarhailbuildup ~= nil and v.components.lunarhailbuildup:IsBuildupWorkable()
							if hasbuildup and canmine then
								PlayMiningFX(inst, v)
								local eff = inst.sg.statemem.efficiency.MINE
								if eff and inst.components.efficientuser then
									inst.components.efficientuser:AddMultiplier(ACTIONS.MINE, eff, inst, WX78_SPIN_KEY)
								end
								if BufferedAction(inst, v, ACTIONS.REMOVELUNARBUILDUP, item):Do() then
									table.insert(actiondata, { action = ACTIONS.REMOVELUNARBUILDUP, target = v })
									if inst.sg.currentstate.name ~= "wx_spin" then
										break
									end
									inst.sg.statemem.efficiency.MINE = (eff or efficiency_decay) * efficiency_decay
									hit = true
								end
							elseif v.components.workable and v.components.workable:CanBeWorked() then
								local workaction = v.components.workable:GetWorkAction()
								if workaction == ACTIONS.CHOP then
									if canchop then
										local eff = inst.sg.statemem.efficiency.CHOP
										if eff and inst.components.efficientuser then
											inst.components.efficientuser:AddMultiplier(ACTIONS.CHOP, eff, inst, WX78_SPIN_KEY)
										end
										if BufferedAction(inst, v, ACTIONS.CHOP, item):Do() then
											table.insert(actiondata, { action = ACTIONS.CHOP, target = v })
											if inst.sg.currentstate.name ~= "wx_spin" then
												break
											end
											inst.sg.statemem.efficiency.CHOP = (eff or efficiency_decay) * efficiency_decay
											hit = true
										end
									else
										recoiltarget = v
									end
								elseif workaction == ACTIONS.MINE then
									PlayMiningFX(inst, v)
									if canmine then
										local eff = inst.sg.statemem.efficiency.MINE
										if eff and inst.components.efficientuser then
											inst.components.efficientuser:AddMultiplier(ACTIONS.MINE, eff, inst, WX78_SPIN_KEY)
										end
										if BufferedAction(inst, v, ACTIONS.MINE, item):Do() then
											table.insert(actiondata, { action = ACTIONS.MINE, target = v })
											if inst.sg.currentstate.name ~= "wx_spin" then
												break
											end
											inst.sg.statemem.efficiency.MINE = (eff or efficiency_decay) * efficiency_decay
											hit = true
										end
									else
										recoiltarget = v
									end
								end
							end

							if hit then
								didwork = true
							elseif hasbuildup then
								recoiltarget = v
							end

							if recoiltarget then
								inst:ForceFacePoint(x1, y1, z1)
								if hasbuildup then
									v.components.lunarhailbuildup:DoWorkToRemoveBuildup(0, inst)
								else
									v.components.workable:WorkedBy(inst, 0)
								end
								break
							end

							if not hit and
								v.components.combat and
								inst.components.combat:CanTarget(v) and
								not inst.components.combat:IsAlly(v)
							then
								local eff = inst.sg.statemem.efficiency.ATTACK
								if inst.components.efficientuser then
									inst.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, eff, inst, WX78_SPIN_KEY)
								end
								local dim = inst.sg.statemem.dim
								if dim and inst.components.aoediminishingreturns then
									--NOTE: this is not for dmg, but for any unique weapon behaviour that would make sense to scale the same as usage efficiency
									inst.components.aoediminishingreturns.mult:SetModifier(inst, dim, WX78_SPIN_KEY)
								end
								if not didattack then
									inst.components.combat:SetTarget(v)
									inst.components.combat:StartAttack()
								end
								inst.components.combat:DoAttack(v)
								table.insert(actiondata, { action = ACTIONS.ATTACK, target = v })
								if inst.sg.currentstate.name ~= "wx_spin" then
									break
								end
								inst.sg.statemem.efficiency.ATTACK = (eff or efficiency_decay) * efficiency_decay
								inst.sg.statemem.dim = (dim or 1) * aoe_dim
								didattack = didattack or ShouldPlayDangerMusic(inst, v)
								hit = true
							end

							if not hit and
								v.components.pickable and
								v.components.pickable.caninteractwith and
								v.components.pickable:CanBePicked() and
								not v.components.pickable:IsStuck() and
								v:HasAnyTag(HARVESTABLE_PLANT_TARGET_TAGS)
							then
								if v.components.pickable.picksound then
									inst.SoundEmitter:PlaySound(v.components.pickable.picksound)
								end
								local success, loot = v.components.pickable:Pick(TheWorld)
								if loot then
									table.insert(actiondata, { action = ACTIONS.PICK, target = v })
                                    harvestedcount = harvestedcount + 1
									for _, v in ipairs(loot) do
										Launch(v, inst, 1.5)
									end
								end
							end

							if inst.sg.currentstate.name ~= "wx_spin" then
								break
							elseif hit then
								inst.sg.statemem.targets[v] = true
								if moveangle then
									minangle = dx == 0 and dz == 0 and 0 or math.min(minangle, DiffAngleRad(math.atan2(-dz, dx), moveangle))
								end
							end
						end
					end
				end
                if harvestedcount > 0 then
					if not pickused and item:IsValid() then
						if (item.components.fumaroletool and item.components.inventoryitem:GetTemperature() > 0)
							or (item.components.finiteuses and item.components.finiteuses:GetUses() > 0)
						then
							if inst.sg.currentstate.name == "wx_spin" then
								inst.sg.statemem.pickused = true
							end
							if item.components.fumaroletool then
								item.components.fumaroletool:OnUsed(inst)
							elseif item.components.finiteuses then
								item.components.finiteuses:Use(TUNING.WX78_SPIN_PICK_EFFICIENCY)
							end
						end

						if item.components.fumaroletool then
							item.components.fumaroletool:OnUsed(inst)
						end

					end
                    inst:PushEvent("picksomethingfromaoe", {harvestedcount = harvestedcount,})
                end

				inst.components.combat.ignorehitrange = false

				if inst.components.efficientuser then
					inst.components.efficientuser:RemoveMultiplier(ACTIONS.CHOP, inst, WX78_SPIN_KEY)
					inst.components.efficientuser:RemoveMultiplier(ACTIONS.MINE, inst, WX78_SPIN_KEY)
					inst.components.efficientuser:RemoveMultiplier(ACTIONS.ATTACK, inst, WX78_SPIN_KEY)
				end

				if inst.components.aoediminishingreturns then
					inst.components.aoediminishingreturns.mult:RemoveModifier(inst, WX78_SPIN_KEY)
				end

				if (didwork or didattack) then
					inst:PushEvent("wx_performedspinaction", didattack)
				end

				if #actiondata > 0 then
					inst:PushEvent("ms_wx_actiondata", actiondata)
				end

				if recoiltarget and inst.sg.currentstate.name == "wx_spin" then
					inst.sg.statemem.targets = nil
					inst:PushEventImmediate("recoil_off", { target = recoiltarget })
				end

				if inst.sg.currentstate.name ~= "wx_spin" then
					return
				elseif minangle < math.pi and inst.sg.statemem.vx then
					minangle = minangle / math.pi
					minangle = minangle * minangle
					inst.sg.statemem.vx = inst.sg.statemem.vx * minangle
					inst.sg.statemem.vz = inst.sg.statemem.vz * minangle
				end
				if (didwork or didattack) then
					inst.sg.statemem.quickstart = nil
					inst.sg.statemem.didhit = true
				end
			end

			if inst.components.playercontroller then
				if inst.sg:HasStateTag("busy") and
					not inst.components.playercontroller:IsAnyOfControlsPressed(
							CONTROL_ACTION,
							CONTROL_CONTROLLER_ACTION,
							CONTROL_CONTROLLER_ALTACTION,
							CONTROL_ATTACK,
							CONTROL_CONTROLLER_ATTACK,
							CONTROL_PRIMARY,
							CONTROL_SECONDARY
						)
				then
					inst.sg:RemoveStateTag("busy")
					inst.sg:RemoveStateTag("nopredict")
				end

				if not inst.sg:HasStateTag("busy") and inst.sg.statemem.canrelease then
					local frame = inst.AnimState:GetCurrentAnimationFrame()
					inst.AnimState:PlayAnimation(inst.sg.statemem.anim)
					inst.AnimState:SetFrame(frame + 1)
					inst.AnimState:PushAnimation("wx_spin_attack_pst", false)
					inst.sg:GoToState("idle", true)
					return
				end
			end

			inst.sg.mem.wx_spin_buildup = (inst.sg.mem.wx_spin_buildup or 0) + dt

			if inst.StartDizzyFx then
				inst:StartDizzyFx()
			end

			local dizzytime = inst.CalcMaxDizzy and inst:CalcMaxDizzy() or TUNING.WX78_SPIN_TIME_TO_DIZZY
			if inst.sg.mem.wx_spin_buildup > dizzytime then
				if inst.sg.statemem.vx then
					inst.Transform:SetRotation(math.atan2(-inst.sg.statemem.vz, inst.sg.statemem.vx) * RADIANS)
				end
				inst.sg:GoToState("wx_spin_dizzy")
				return
			end

			--for non-players
			if inst.components.playercontroller == nil then
				local target = inst.sg.statemem.target
				if not (target and target:IsValid()) then
					target = inst.components.combat and inst.components.combat.target
					inst.sg.statemem.target = target
				end
				if inst.sg.statemem.canrelease and
					(	(inst.components.locomotor and inst.components.locomotor:WantsToMoveForward()) or
						not (inst.sg.statemem.didhit or inst.components.combat:TargetIs(target))
					)
				then
					local frame = inst.AnimState:GetCurrentAnimationFrame()
					inst.AnimState:PlayAnimation(inst.sg.statemem.anim)
					inst.AnimState:SetFrame(frame + 1)
					inst.AnimState:PushAnimation("wx_spin_attack_pst", false)
					inst.sg:GoToState("idle", true)
					return
				end
			end

			inst.sg.mem.wx_spin_last = GetTime()

			local maxspeed = inst.components.locomotor:GetRunSpeed() * TUNING.WX78_SPIN_RUNSPEED_MULT
			local accel = maxspeed / 15

			local dir = GetLocalAnalogDir(inst)
			local theta = inst.sg.statemem.remotedir and inst.sg.statemem.remotedir * DEGREES
			if dir or theta then
				inst.sg.statemem.target = nil
				inst.sg.statemem.quickstart = nil
			else
				local target = inst.sg.statemem.target
				if target then
					if target:IsValid() then
						local x, y, z = inst.Transform:GetWorldPosition()
						local x1, y1, z1 = target.Transform:GetWorldPosition()
						local dx = x1 - x
						local dz = z1 - z
						local dsq = dx * dx + dz * dz
						if dsq >= 64 then --stop tracking target further than 8 dist
							inst.sg.statemem.target = nil
							inst.sg.statemem.quickstart = nil
						else
							local physrad = target:GetPhysicsRadius(0)
							local range = TUNING.WX78_SPIN_RADIUS - 0.5 + physrad
							if dsq < range * range then --stop moving (don't set theta) when close enough
								inst.sg.statemem.quickstart = nil
							else
								theta = math.atan2(-dz, dx)

								if inst.sg.statemem.quickstart then
									range = TUNING.WX78_SPIN_START_RANGE + physrad
									if dsq > range * range then
										inst.sg.statemem.quickstart = nil
									end
								end
							end
						end
					else
						inst.sg.statemem.target = nil
						inst.sg.statemem.quickstart = nil
					end
				end
			end

			if inst.sg.statemem.quickstart then
				if dir or theta then
					maxspeed = maxspeed * inst.sg.statemem.quickstart
					accel = maxspeed
					if inst.sg.statemem.quickstart > 1 then
						inst.sg.statemem.quickstart = inst.sg.statemem.quickstart / 2
					else
						inst.sg.statemem.quickstart = nil
					end
				else
					inst.sg.statemem.quickstart = nil
				end
			end

			if dir or theta then
				local vx = inst.sg.statemem.vx
				local vz = inst.sg.statemem.vz
				if vx then
					--decay perpendicular velocity fastest
					--decay reverse velocity medium
					--decay same direction velocity the least
					theta = theta or math.atan2(-dir.z, dir.x)
					local diff = DiffAngleRad(theta, math.atan2(-vz, vx))
					local k = Remap(math.sin(diff) + diff / TWOPI, 0, 1.5, 1, 0.9)
					vx = vx * k
					vz = vz * k
				else
					vx, vz = 0, 0
				end
				if dir then
					vx = vx + dir.x * accel
					vz = vz + dir.z * accel
				else
					vx = vx + math.cos(theta) * accel
					vz = vz - math.sin(theta) * accel
				end
				local speed = math.sqrt(vx * vx + vz * vz)
				if speed > maxspeed then
					speed = maxspeed / speed
					inst.sg.statemem.vx = vx * speed
					inst.sg.statemem.vz = vz * speed
				else
					inst.sg.statemem.vx = vx
					inst.sg.statemem.vz = vz
				end
			elseif inst.sg.statemem.vx then
				local speed = math.sqrt(inst.sg.statemem.vx * inst.sg.statemem.vx + inst.sg.statemem.vz * inst.sg.statemem.vz)
				if speed > accel then
					speed = 1 - accel / speed
					inst.sg.statemem.vx = inst.sg.statemem.vx * speed
					inst.sg.statemem.vz = inst.sg.statemem.vz * speed
				else
					inst.sg.statemem.vx = nil
					inst.sg.statemem.vz = nil
					inst.Physics:Stop()
					inst.Physics:SetMotorVel(0, 0, 0)
				end
			end

			if inst.sg.statemem.vx then
				--convert to local space
				theta = inst.Transform:GetRotation() * DEGREES
				if inst.sg.statemem.theta ~= theta then
					inst.sg.statemem.theta = theta
					inst.sg.statemem.costheta = math.cos(theta)
					inst.sg.statemem.sintheta = math.sin(theta)
				end
				local vx = inst.sg.statemem.costheta * inst.sg.statemem.vx - inst.sg.statemem.sintheta * inst.sg.statemem.vz
				local vz = inst.sg.statemem.sintheta * inst.sg.statemem.vx + inst.sg.statemem.costheta * inst.sg.statemem.vz
				inst.Physics:SetMotorVel(vx, 0, vz)
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.spinning = true
			inst.sg:GoToState("wx_spin", {
				remotedir = inst.sg.statemem.remotedir,
				vx = inst.sg.statemem.vx,
				vz = inst.sg.statemem.vz,
				theta = inst.sg.statemem.theta,
				costheta = inst.sg.statemem.costheta,
				sintheta = inst.sg.statemem.sintheta,
				numhits = inst.sg.statemem.numhits,
				target = inst.sg.statemem.target,
			})
		end,

		events =
		{
			EventHandler("feetslipped", function(inst)
				if inst.sg.statemem.vx then
					inst.Transform:SetRotation(math.atan2(-inst.sg.statemem.vz, inst.sg.statemem.vx) * RADIANS)
					inst.sg:GoToState("slip")
				else
					inst.sg:GoToState("slip", 1)
				end
			end),
			EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
			EventHandler("locomote", function(inst, data)
				if data and data.remoteoverridelocomote then
					inst.sg.statemem.remotedir = data.dir
				end
				return true
			end),
			EventHandler("attacked", function(inst, data)
				local t = GetTime()
				local elapsed = t - (inst.sg.statemem.lasthit or 0)
				if elapsed > 0 then
					inst.sg.statemem.lasthit = t
					inst.sg.statemem.numhits = math.max(0, (inst.sg.statemem.numhits or 0) - math.floor(elapsed / 2)) + 1
				end
				if inst.sg.statemem.numhits < 3 then
					inst.sg:AddStateTag("nostunlock")
				else
					inst.sg:RemoveStateTag("nostunlock")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.spinning then
				inst:RemoveTag("prespin")
				if inst.sg.statemem.vx then
					inst.Physics:Stop()
					inst.Physics:SetMotorVel(0, 0, 0)
				end
                if inst.player_classified ~= nil then
				    inst.player_classified.busyremoteoverridelocomote:set(false)
                end
				if inst.components.talker then
					inst.components.talker:StopIgnoringAll("spinning")
				end
			end
			inst.components.combat:SetTarget(nil)
		end,
	})

    table.insert(states, State{
		name = "wx_spin_dizzy",
		tags = { "busy", "dizzy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wx_dizzy_loop")
			inst.AnimState:PushAnimation("wx_dizzy_loop", false)
			inst.AnimState:PushAnimation("wx_dizzy_pst", false)

			if inst.StartDizzyFx then
				inst:StartDizzyFx()
			end

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * 2)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle", true)
		end,
	})
end

SGWX78Common.AddWX78ShieldStates = function(states, events, fns)
    events = events or {}
    fns = fns or {}

    table.insert(states, State{
        name = "wx_shield_pre",
		tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wx_defense_on_pre")
            inst:AddTag("wx_shielding")
			inst:PerformBufferedAction() --does nothing
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.iswxshielding = true
					inst.sg:GoToState("wx_shield_on")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.iswxshielding then
                inst:RemoveTag("wx_shielding")
            end
        end,
    })

    table.insert(states, State{
		name = "wx_shield_on",
		tags = { "busy", "wxshielding", },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wx_defense_on")

			inst:AddTag("wx_shielding")
			ApplyWX78ShieldingDefense(inst)
		end,

		timeline =
		{
			FrameEvent(2, PlayFootstep),
			FrameEvent(4, function(inst)
				inst.sg.statemem.iswxshielding = true
				inst.sg:GoToState("wx_shield_idle", true)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.iswxshielding then
				ClearWX78ShieldingDefense(inst)
				inst:RemoveTag("wx_shielding")
			end
		end,
	})

    table.insert(states, State{
        name = "wx_shield_idle",
		tags = { "idle", "wxshielding", },

		onenter = function(inst, pushanim)
            inst.components.locomotor:Stop()
			if pushanim then
				inst.AnimState:PushAnimation("wx_defense_idle", true)
			else
				inst.AnimState:PlayAnimation("wx_defense_idle", true)
			end

            inst:AddTag("wx_shielding")
            ApplyWX78ShieldingDefense(inst)
        end,

        events = events.idle,

        onexit = function(inst)
            if fns.idle_onexit ~= nil then
                fns.idle_onexit(inst)
            end
            if not inst.sg.statemem.iswxshielding then
                ClearWX78ShieldingDefense(inst)
                inst:RemoveTag("wx_shielding")
            end
        end,
    })

    table.insert(states, State{
        name = "wx_shield_hit",
		tags = { "busy", "pausepredict", "wxshielding", "wxshieldhit", },

        onenter = function(inst)
            inst.sg.mem.wx78shieldhit = true
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("wx_defense_hit")

			inst:AddTag("wx_shielding")
			ApplyWX78ShieldingDefense(inst)

			if inst.components.playercontroller then
				inst.components.playercontroller:RemotePausePrediction(4)
			end
			inst.sg:SetTimeout(4 * FRAMES)
        end,

		ontimeout = function(inst)
			inst.sg.statemem.iswxshielding = true
			inst.sg:GoToState("wx_shield_idle", true)
		end,

        onexit = function(inst)
            if not inst.sg.statemem.iswxshielding then
                ClearWX78ShieldingDefense(inst)
                inst:RemoveTag("wx_shielding")
            end
        end,
    })

    table.insert(states, State{
        name = "wx_shield_pst",

        onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wx_defense_off")

			inst:PerformBufferedAction() --does nothing
			inst.sg:GoToState("idle", true)
        end,
	})
end

SGWX78Common.AddWX78ScreechStates = function(states)
    table.insert(states, State{
        name = "wx_screech_pre",
        tags = { "doing", "busy" },

        onenter = function(inst)
            local timeout = (not IsSkillActivated(inst, "wx78_circuitry_gammabuffs_1"))
                and (TUNING.WX78_SCREECH_TIME + math.random() * TUNING.WX78_SCREECH_TIME_VAR)
                or nil
            inst.sg.statemem.timeout = timeout
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wx_screech_pre")
            inst.AnimState:PushAnimation("wx_screech_pre2", false)
            inst:PerformBufferedAction() -- does nothing
            inst:AddTag("wx_screeching")
        end,

        timeline =
        {
            FrameEvent(2, function(inst)
                inst.SoundEmitter:PlaySound("WX_rework/screech/loop", "wx_screech")
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.screeching = true
                    inst.sg:GoToState("wx_screech_loop", inst.sg.statemem.timeout)
                end
            end)
        },

        onexit = function(inst)
            if not inst.sg.statemem.screeching then
                inst.SoundEmitter:KillSound("wx_screech")
                inst:RemoveTag("wx_screeching")
            end
        end,
    })

    table.insert(states, State{
        name = "wx_screech_loop",
		tags = { "doing" },

        onenter = function(inst, timeout)
            inst:AddTag("wx_screeching")
            inst.sg.statemem.timeout = timeout or nil
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wx_screech_loop", true)
            if not inst.SoundEmitter:PlayingSound("wx_screech") then
                inst.SoundEmitter:PlaySound("WX_rework/screech/loop", "wx_screech")
            end
            -- TheMixer:PushMix("wx_screech") -- TODO
            inst.sg.statemem.scarecd = 0

            if timeout ~= nil then
                inst.sg:SetTimeout(timeout)
            end
        end,

        onupdate = function(inst, dt)
            inst.sg.statemem.scarecd = inst.sg.statemem.scarecd - dt
            if inst.sg.statemem.scarecd <= 0 then
                DoWX78Screech(inst)
                inst.sg.statemem.scarecd = 15 * FRAMES + math.random()
				inst.sg.statemem.shouldcooldown = true
            end
        end,

        ontimeout = function(inst)
			inst.sg:GoToState("wx_screech_pst", true)
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("wx_screech")
            inst:RemoveTag("wx_screeching")
            -- TheMixer:PopMix("wx_screech") -- TODO 

			if inst.sg.statemem.shouldcooldown and inst.components.wx78_abilitycooldowns then
				inst.components.wx78_abilitycooldowns:RestartAbilityCooldown("screech", TUNING.WX78_SCREECH_COOLDOWN)
			end
        end,
    })

    table.insert(states, State{
        name = "wx_screech_pst",

		onenter = function(inst, nonaction)
			inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wx_screech_pst")

			if not nonaction then
				inst:PerformBufferedAction() --does nothing
			end
			inst.sg:GoToState("idle", true)
        end,
    })
end

SGWX78Common.AddWX78BakeState = function(states)
    table.insert(states, State{
        name = "wx_bake",
        tags = { "busy", },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("wx_bake")
        end,

        timeline =
        {
            --#SFX
            FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl1_ding", nil, 0.2) end),
            FrameEvent(41, function(inst) inst.SoundEmitter:PlaySound("WX_rework/module_tray/open") end),
            FrameEvent(47, function(inst) inst.SoundEmitter:PlaySound("moonstorm/characters/wagstaff/thumper/steam", nil, 0.4) end),
            FrameEvent(68, function(inst) inst.SoundEmitter:PlaySound("WX_rework/module_tray/close") end),

            FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/egg/egg_hot_steam_LP", "wx_baking") end),
            FrameEvent(32, function(inst) inst.SoundEmitter:KillSound("wx_baking") end),

            --
            FrameEvent(46, function(inst)
                local x, y, z = inst.Transform:GetWorldPosition()
                local rot = (inst.Transform:GetRotation() + math.random(-20, 20)) * DEGREES
                local speed = 2 + math.random()
                local brick = SpawnPrefab("wx78_foodbrick")
                y = y + ( (inst.components.rider ~= nil and inst.components.rider:IsRiding()) and 2.5 or .25)
                brick.Transform:SetPosition(x, y, z)
                brick.Physics:SetVel(math.cos(rot) * speed, speed * 3, -math.sin(rot) * speed)
            end),
            FrameEvent(70, function(inst)
                inst.sg:RemoveStateTag("busy")
            end)
        },

        events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("wx_baking")
        end,
    })
end

SGWX78Common.AddWX78UseDroneStates = function(states)
	table.insert(states, State{
		name = "wx_start_using_drone",
		tags = { "doing", "busy" },

		onenter = function(inst)
			local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			if not (item and item:HasTag("wx_remotecontroller")) then
				inst:ClearBufferedAction()
				inst.sg:GoToState("idle")
				return
			end
			inst:AddTag("using_drone_remote")
			inst:PushEvent("ms_wx_clearactiondata")
			inst.sg.statemem.item = item
			inst.sg.statemem.buffaction = inst.bufferedaction
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("drone_zap_remote_use_pre")
			if inst.components.playercontroller then
				inst.components.playercontroller:EnableMapControls(false)
			end
			--inst.components.inventory:Hide() --can't do now or action will fail
			inst:PushEvent("ms_closepopups")
			if inst.ShowActions then
				inst:ShowActions(false)
			end
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg.statemem.buffaction = nil
				if inst:PerformBufferedAction() then
					inst.sg.statemem.using_drone = true
					inst.sg:GoToState("wx_using_drone", inst.sg.statemem.item)
				else
					inst.sg.statemem.item = nil
					inst.sg:GoToState("wx_stop_using_drone")
				end
			end),
		},

		events =
		{
			EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
			EventHandler("unequip", function(inst, data)
				if not (data and data.item == inst.sg.statemem.item) then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if inst.bufferedaction == inst.sg.statemem.buffaction then
				inst:ClearBufferedAction()
			end
			if not inst.sg.statemem.using_drone then
				inst:RemoveTag("using_drone_remote")
				if inst.components.playercontroller then
					inst.components.playercontroller:EnableMapControls(true)
				end
				--inst.components.inventory:Show() --didn't hide during this state
				if inst.ShowActions then
					inst:ShowActions(true)
				end

				local item = inst.sg.statemem.item
				if item and item:IsValid() and item.components.useableequippeditem then
					item.components.useableequippeditem:StopUsingItem(inst)
				end
			end
		end,
	})

	table.insert(states, State{
		name = "wx_using_drone",
		tags = { "doing", "overridelocomote", "nodragwalk", "overrideattack" },

		onenter = function(inst, item)
			if inst.AnimState:IsCurrentAnimation("drone_zap_remote_use_pre") then
				inst.AnimState:PushAnimation("drone_zap_remote_use_loop")
			else
				inst.AnimState:PlayAnimation("drone_zap_remote_use_loop", true)
			end

			if inst.components.playercontroller then
				inst.components.playercontroller:SetIsOverrideAttack(true)
				inst.components.playercontroller:EnableMapControls(false)
			end
			inst:AddTag("using_drone_remote")
			inst.sg.statemem.item = item
			inst:PushEvent("ms_closepopups")
			inst.components.inventory:Hide()
			if inst.ShowActions then
				inst:ShowActions(false)
			end
			if inst.SetCameraZoomed then
				inst:SetCameraZoomed(true)
			end
			if inst.SetAerialCamera then
				inst:SetAerialCamera(true)
			end
		end,

		onupdate = function(inst)
			local item = inst.sg.statemem.item
			if not (
				item and item:IsValid() and
				item.components.equippable and item.components.equippable:IsEquipped() and
				item.components.inventoryitem and (
					not item.components.inventoryitem:IsHeld() or
					item.components.inventoryitem:GetGrandOwner() == inst
				)
			) then
				inst.sg:GoToState("item_in")
				return
			elseif not (item.components.useableequippeditem and item.components.useableequippeditem:IsInUse()) then
				inst.sg.statemem.item = nil
				inst.sg:GoToState("wx_stop_using_drone")
				return
			elseif not (item.drone and not item.drone.killed and item.drone:IsValid()) then
				if item.components.useableequippeditem then
					item.components.useableequippeditem:StopUsingItem(inst)
				end
				inst.sg.statemem.item = nil
				inst.sg:GoToState("wx_stop_using_drone")
				return
			elseif inst.components.playercontroller then
				if inst.sg.statemem.canrepeatfire then
					if item.components.finiteuses and
						item.components.finiteuses:GetUses() > 0 and
						inst.components.playercontroller and
						inst.components.playercontroller:IsAnyOfControlsPressed(CONTROL_ATTACK, CONTROL_CONTROLLER_ATTACK)
					then
						item.drone:PushEventImmediate("doattack")
					end
					if not item.drone.sg:HasStateTag("attack") then
						inst.sg.statemem.canrepeatfire = false
					end
				end
			else --non-player logic
				local target = inst.components.combat.target
				if target == nil or
					inst.components.locomotor:WantsToMoveForward() or
					not (item.components.finiteuses and item.components.finiteuses:GetUses() > 0)
				then
					if item.drone.sg:HasStateTag("idle") and GetTime() >= (inst.sg.statemem.busytime or 0) then
						if item.components.useableequippeditem then
							item.components.useableequippeditem:StopUsingItem(inst)
						end
						inst.sg.statemem.item = nil
						inst.sg:GoToState("wx_stop_using_drone")
						return
					elseif item.drone.sg:HasStateTag("moving") then
						item.drone:PushEventImmediate("locomote")
					end
				else
					local x, _, z = item.drone.Transform:GetWorldPosition()
					local x1, _, z1 = target.Transform:GetWorldPosition()
					local dx = x1 - x
					local dz = z1 - z
					local dsq = dx * dx + dz * dz
					if dsq >= 4 then
						local dir = math.atan2(-dz, dx) * RADIANS
						item.drone:PushEventImmediate("locomote", { dir = dir })
						if item.drone.sg:HasStateTag("moving") then
							inst.sg.statemem.busytime = math.max(inst.sg.statemem.busytime or 0, GetTime() + 0.5)
						end
					elseif dsq >= 1 then
						if item.drone.sg:HasStateTag("moving") then
							item.drone:PushEventImmediate("locomote")
						end
					elseif not item.drone.sg:HasStateTag("busy") then
						if inst.sg.statemem.queuedattack then
							inst.sg.statemem.queuedattack = false
							item.drone:PushEventImmediate("doattack")
							if item.drone.sg:HasStateTag("attack") then
								inst.sg.statemem.busytime = math.max(inst.sg.statemem.busytime or 0, GetTime() + 2)
							end
						end
					end
				end
			end
		end,

		events =
		{
			EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
			EventHandler("unequip", function(inst, data)
				if not (data and data.item == inst.sg.statemem.item) then
					inst.sg:GoToState("idle")
				end
			end),
			EventHandler("locomote", function(inst, data)
				--direct movement only, no drag or point destination.
				if inst.components.playercontroller and not inst.components.locomotor:HasDestination() then
					local drone = inst.sg.statemem.item and inst.sg.statemem.item.drone
					if drone and not drone.killed and drone:IsValid() then
						drone:PushEventImmediate("locomote", data)
					end
				end
				return true
			end),
			EventHandler("attackbutton", function(inst)
				local item = inst.sg.statemem.item
				if item and
					item.drone and
					not item.drone.killed and
					item.drone:IsValid() and
					not (item.components.finiteuses and item.components.finiteuses:GetUses() <= 0)
				then
					item.drone:PushEventImmediate("doattack")
					if item.drone.sg:HasStateTag("attack") then
						inst.sg.statemem.canrepeatfire = true
					end
				end
			end),
			EventHandler("ms_wx_clone_use_drone_zap_attack", function(inst, data)
				inst.sg.statemem.queuedattack = data and data.doattack
			end),
		},

		onexit = function(inst)
			if inst.components.playercontroller then
				inst.components.playercontroller:SetIsOverrideAttack(false)
				inst.components.playercontroller:EnableMapControls(true)
			end
			inst:RemoveTag("using_drone_remote")
			inst:PushEvent("ms_wx_clearactiondata")
			inst.components.inventory:Show()
			if inst.ShowActions then
				inst:ShowActions(true)
			end
			if inst.SetCameraZoomed then
				inst:SetCameraZoomed(false)
			end
			if inst.SetAerialCamera then
				inst:SetAerialCamera(false)
			end

			local item = inst.sg.statemem.item
			if item and item:IsValid() and item.components.useableequippeditem then
				item.components.useableequippeditem:StopUsingItem(inst)
			end
		end,
	})

	table.insert(states, State{
		name = "wx_stop_using_drone",
		tags = { "doing", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("drone_zap_remote_use_pst")
			inst.sg:SetTimeout(6 * FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:RemoveStateTag("busy")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	})
end

return SGWX78Common
