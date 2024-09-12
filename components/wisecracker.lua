local Wisecracker = Class(function(self, inst)
    self.inst = inst
    self.time_in_lightstate = 0
    self.inlight = true
    self.foodbuffname = nil
    self.foodbuffpriority = nil

    inst:ListenForEvent("oneat",
        function(inst, data)
            if data.food ~= nil and data.food.components.edible ~= nil then
                if data.food.prefab == "spoiled_food" then
                    inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "SPOILED"))
                elseif data.food.components.edible:GetHealth(inst) < 0 and
                    data.food.components.edible:GetSanity(inst) <= 0 and
                    not (inst.components.eater ~= nil and (
                            inst.components.eater.strongstomach and
                            data.food:HasTag("monstermeat") or
                            inst.components.eater.healthabsorption == 0
                        )) and not (inst.components.foodaffinity and inst.components.foodaffinity:HasPrefabAffinity(data.food)) then

                    inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "PAINFUL"))

                elseif data.food.components.perishable ~= nil then
                    if data.food.components.perishable:IsFresh() then
                        local ismasterchef = inst:HasTag("masterchef")
                        if ismasterchef and data.food.prefab == "wetgoop" then
                            inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "PAINFUL"))
                        else
                            local count = inst.components.foodmemory ~= nil and inst.components.foodmemory:GetMemoryCount(data.food.prefab) or 0
                            if count > 0 then
                                inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "SAME_OLD_"..tostring(math.min(5, count))))
                            elseif ismasterchef then
                                inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT",
                                    (data.food:HasTag("masterfood") and "TASTY") or
                                    (data.food:HasTag("preparedfood") and "PREPARED") or
                                    (data.food.components.cookable ~= nil and "RAW") or
                                    (data.food.components.perishable.perishtime == TUNING.PERISH_PRESERVED and "DRIED") or
                                    "COOKED"
                                ))
                            end
                        end
                    elseif data.food.components.edible.degrades_with_spoilage then
                        if data.food.components.perishable:IsStale() then
                            inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "STALE"))
                        elseif data.food.components.perishable:IsSpoiled() then
                            inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "SPOILED"))
                        end
                    end
                else
                    local count = inst.components.foodmemory ~= nil and inst.components.foodmemory:GetMemoryCount(data.food.prefab) or 0
                    if count > 0 then
                        inst.components.talker:Say(GetString(inst, "ANNOUNCE_EAT", "SAME_OLD_"..tostring(math.min(5, count))))
                    end
                end
            end
        end)

    inst:StartUpdatingComponent(self)

    -- if not TheWorld:HasTag("cave") or not data.newdusk then
    --     inst:WatchWorldState("startdusk", function()
    --         inst.components.talker:Say(GetString(inst, "ANNOUNCE_DUSK"))
    --     end)
    -- end

    inst:ListenForEvent("itemranout", function(inst, data)
        inst.components.talker:Say(GetString(inst, data.announce))
    end)

    inst:ListenForEvent("accomplishment", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_ACCOMPLISHMENT"))
    end)

    inst:ListenForEvent("accomplishment_done", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_ACCOMPLISHMENT_DONE"))
    end)

    inst:ListenForEvent("attacked", function(inst, data)
        if data.weapon and data.weapon.prefab == "boomerang" then
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_BOOMERANG"))
        end
    end)

    inst:ListenForEvent("snared", function(inst, data)
        inst.components.talker:Say(GetString(inst, data ~= nil and data.announce or "ANNOUNCE_SNARED"))
    end)

    inst:ListenForEvent("repelled", function(inst, data)
        if data ~= nil and data.repeller ~= nil and data.repeller.entity:IsVisible() then
            local t = GetTime()
            if t >= (self._repeltime or 0) then
                self._repeltime = t + 5
                inst.components.talker:Say(GetString(inst, "ANNOUNCE_REPELLED"))
            end
        end
    end)

    inst:ListenForEvent("insufficientfertilizer", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_INSUFFICIENTFERTILIZER"))
    end)

    inst:ListenForEvent("heargrue", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_CHARLIE"))
    end)

    inst:ListenForEvent("attackedbygrue", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_CHARLIE_ATTACK"))
    end)

    inst:ListenForEvent("resistedgrue", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_CHARLIE_MISSED"))
    end)

    inst:ListenForEvent("thorns", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_THORNS"))
    end)

    inst:ListenForEvent("burnt", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_BURNT"))
    end)

    inst:ListenForEvent("hungerdelta",
        function(inst, data)
            if data.newpercent <= TUNING.HUNGRY_THRESH and data.oldpercent > TUNING.HUNGRY_THRESH then
                inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNGRY"))
            end
        end)

    inst:ListenForEvent("ghostdelta",
        function(inst, data)
            if data.newpercent <= TUNING.GHOST_THRESH and data.oldpercent > TUNING.GHOST_THRESH then
                inst.components.talker:Say(GetString(inst, "ANNOUNCE_GHOSTDRAIN"))
            end
        end)

    inst:ListenForEvent("startfreezing",
        function(inst, data)
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_COLD"))
        end)

    inst:ListenForEvent("startoverheating",
        function(inst, data)
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_HOT"))
        end)

    inst:ListenForEvent("inventoryfull", function(it, data)
        if inst.components.inventory:IsFull() then
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_INV_FULL"))
        end
    end)

    inst:ListenForEvent("coveredinbees", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_BEES"))
    end)

    inst:ListenForEvent("wormholespit", function(inst, data)
        if inst._failed_doneteleporting then
            inst._failed_doneteleporting = nil
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_WORMHOLE_SAMESPOT"))
        else
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_WORMHOLE"))
        end
    end)

    inst:ListenForEvent("townportalteleport", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_TOWNPORTALTELEPORT"))
    end)

    inst:ListenForEvent("huntlosttrail", function(inst, data)
        inst.components.talker:Say(GetString(inst, data.washedaway and "ANNOUNCE_HUNT_LOST_TRAIL_SPRING" or "ANNOUNCE_HUNT_LOST_TRAIL"))
    end)

    inst:ListenForEvent("huntbeastnearby", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNT_BEAST_NEARBY"))
    end)

	inst:ListenForEvent("huntstartfork", function(inst)
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNT_START_FORK"))
	end)

	inst:ListenForEvent("huntsuccessfulfork", function(inst)
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNT_SUCCESSFUL_FORK"))
	end)

	inst:ListenForEvent("huntwrongfork", function(inst)
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNT_WRONG_FORK"))
	end)

	inst:ListenForEvent("huntavoidfork", function(inst) -- TODO(JBK): Add this for other hunt mechanics.
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNT_AVOID_FORK"))
	end)

    inst:ListenForEvent("lightningdamageavoided", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_LIGHTNING_DAMAGE_AVOIDED"))
    end)

    inst:ListenForEvent("mountwounded", function(inst, data)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_MOUNT_LOWHEALTH"))
    end)

    inst:ListenForEvent("pickdiseasing", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_PICK_DISEASE_WARNING"))
    end)

    inst:ListenForEvent("onpresink", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_BOAT_SINK"))
    end)

    inst:ListenForEvent("onprefallinvoid", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_PREFALLINVOID"))
    end)

    inst:ListenForEvent("on_standing_on_new_leak", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_BOAT_LEAK"))
    end)

    inst:ListenForEvent("digdiseasing", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_DIG_DISEASE_WARNING"))
    end)

    inst:ListenForEvent("encumberedwalking", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_ENCUMBERED"))
    end)

    inst:ListenForEvent("hungrybuild", function(inst)
        inst.components.talker:Say(GetString(inst, "ANNOUNCE_HUNGRY_FASTBUILD"))
    end)

	inst:ListenForEvent("tooltooweak", function(inst, data)
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_TOOL_TOOWEAK"))
	end)

    if inst:HasTag("soulstealer") then
        inst:ListenForEvent("soulempty", function(inst)
            inst.components.talker:Say(GetString(inst, "ANNOUNCE_SOUL_EMPTY"))
        end)

        local soultoofew_time = 0
        inst:ListenForEvent("soultoofew", function(inst)
            local t = GetTime()
            if t > soultoofew_time then
                soultoofew_time = t + 30
                inst.components.talker:Say(GetString(inst, "ANNOUNCE_SOUL_FEW"))
            end
        end)

        local soultoomany_time = 0
        inst:ListenForEvent("soultoomany", function(inst)
            local t = GetTime()
            if t > soultoomany_time then
                soultoomany_time = t + 30
                inst.components.talker:Say(GetString(inst, "ANNOUNCE_SOUL_MANY"))
            end
        end)
    end

	inst:ListenForEvent("on_halloweenmoonpotion_failed", function(inst)
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_MOONPOTION_FAILED"))
	end)

    local function OnFoodBuff(inst, data)
        if data ~= nil and
            data.buff ~= nil and
            (   self.foodbuffname == nil or
                self.foodbuffpriority == nil or
                (data.priority ~= nil and data.priority > self.foodbuffpriority)
            ) then
            self.foodbuffname = data.buff
            self.foodbuffpriority = data.priority
        end
    end
    inst:ListenForEvent("foodbuffattached", OnFoodBuff)
    inst:ListenForEvent("foodbuffdetached", OnFoodBuff)

	local function dochaironfire(inst, chair)
		if chair ~= nil and chair:IsValid() and
			chair.components.sittable ~= nil and
			chair.components.sittable:IsOccupiedBy(inst) and
			chair.components.burnable ~= nil and
			chair.components.burnable:IsBurning()
		then
			inst.components.talker:Say(GetString(inst, "ANNOUNCE_CHAIR_ON_FIRE"))
		end
	end
	inst:ListenForEvent("sittableonfire", function(inst, chair)
		inst:DoTaskInTime(0.5, dochaironfire, chair)
	end)

    inst:ListenForEvent("otterboaterosion_begin", function(inst, reason)
        local announce_string = (reason ~= nil and reason == "deepwater" and "ANNOUNCE_OTTERBOAT_OUTOFSHALLOWS")
            or "ANNOUNCE_OTTERBOAT_DENBROKEN" -- "dengone"
        inst.components.talker:Say(GetString(inst, announce_string))
    end)

    local function OnFishBuff(_, data)
        if data ~= nil and data.buff ~= nil and
                (   self.fishbuffname == nil or
                    self.fishbuffpriority == nil or
                    (data.priority ~= nil and data.priority > self.fishbuffpriority)
                ) then
            self.fishbuffname = data.buff
            self.fishbuffpriority = data.priority
        end
    end
    inst:ListenForEvent("fishbuffattached", OnFishBuff)
    inst:ListenForEvent("fishbuffdetached", OnFishBuff)

	local exitgelblobtask
	local function doexitgelblob(inst)
		exitgelblobtask = nil
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_EXIT_GELBLOB"))
	end
	inst:ListenForEvent("exit_gelblob", function(inst, gelblob)
		if exitgelblobtask then
			exitgelblobtask:Cancel()
		end
		exitgelblobtask = inst:DoTaskInTime(1.6, doexitgelblob)
	end)

	local last_shadowthrall_stealth_bite = -999
	local shadowthrall_stealth_bite_task
	local function dobitbyshadowthrallstealth(inst)
		shadowthrall_stealth_bite_task = nil
		inst.components.talker:Say(GetString(inst, "ANNOUNCE_SHADOWTHRALL_STEALTH"))
	end
	inst:ListenForEvent("bit_by_shadowthrall_stealth", function(inst, thrall)
		if shadowthrall_stealth_bite_task == nil then
			local t = GetTime()
			if last_shadowthrall_stealth_bite + 10 < t then
				last_shadowthrall_stealth_bite = t
				shadowthrall_stealth_bite_task = inst:DoTaskInTime(2 + math.random(), dobitbyshadowthrallstealth)
			end
		end
	end)

    if TheNet:GetServerGameMode() == "quagmire" then
        event_server_data("quagmire", "components/wisecracker").AddQuagmireEventListeners(inst)
    end
end)

function Wisecracker:OnUpdate(dt)
    local nightvision = CanEntitySeeInDark(self.inst)
    local is_talker_busy = false

    if nightvision or self.inst:IsInLight() then
        if not self.inlight and (nightvision or self.inst.LightWatcher:GetTimeInLight() >= 0.5) then
            self.inlight = true
            if self.inst.components.talker ~= nil and not self.inst:HasTag("playerghost") then
                self.inst.components.talker:Say(GetString(self.inst, "ANNOUNCE_ENTER_LIGHT"))
                is_talker_busy = true
            end
        end
    elseif self.inlight and self.inst.LightWatcher:GetTimeInDark() >= 0.5 then
        self.inlight = false
        if self.inst.components.talker ~= nil then
            self.inst.components.talker:Say(GetString(self.inst, "ANNOUNCE_ENTER_DARK"))
            is_talker_busy = true
        end
    end

    if self.foodbuffname ~= nil then
        if not is_talker_busy then
            self.inst.components.talker:Say(GetString(self.inst, self.foodbuffname))
        end
        self.foodbuffname = nil
        self.foodbuffpriority = nil
    elseif self.fishbuffname ~= nil then
        if not is_talker_busy then
            self.inst.components.talker:Say(GetString(self.inst, self.fishbuffname))
        end
        self.fishbuffname = nil
        self.fishbuffpriority = nil
    end
end

return Wisecracker
