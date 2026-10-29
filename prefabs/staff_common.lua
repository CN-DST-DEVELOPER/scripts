local prefabs =
{
    blue =
    {
        "ice_projectile",
    },
    blue2 =
    {
        "ice_projectile",
    },
    blue3 =
    {
        "ice_projectile",
    },

    red =
    {
        "fire_projectile",
        "cutgrass",
    },

    --purple = nil,

    orange =
    {
        "sand_puff_large_front",
        "sand_puff_large_back",
        "reticule",
    },

    green =
    {
        "splash_ocean",
        "collapse_small",
    },

    yellow =
    {
        "stafflight",
        "reticule",
    },

    opal =
    {
        "staffcoldlight",
        "reticule",
    },
}
local fns = {}

local function NoHoles(pt)
    return not TheWorld.Map:IsGroundTargetBlocked(pt)
end

------- red

local function projectilelaunched_red(inst, attacker, target, proj)
    if attacker:HasTag("controlled_burner") then
        proj:AddTag("controlled_burner")
    end
end

local function onattack_red(inst, attacker, target, skipsanity)
    if not skipsanity and attacker ~= nil then
        if attacker.components.staffsanity then
            attacker.components.staffsanity:DoCastingDelta(-TUNING.SANITY_SUPERTINY)
        elseif attacker.components.sanity ~= nil then
            attacker.components.sanity:DoDelta(-TUNING.SANITY_SUPERTINY)
        end
    end

    attacker.SoundEmitter:PlaySound(inst.skin_sound or "dontstarve/wilson/fireball_explo")

    if not target:IsValid() then
        --target killed or removed in combat damage phase
        return
    elseif target.components.burnable ~= nil and not target.components.burnable:IsBurning() then
        if target.components.freezable ~= nil and target.components.freezable:IsFrozen() then
            target.components.freezable:Unfreeze()
        elseif target.components.fueled == nil
            or (target.components.fueled.fueltype ~= FUELTYPE.BURNABLE and
                target.components.fueled.secondaryfueltype ~= FUELTYPE.BURNABLE) then
            --does not take burnable fuel, so just burn it
            if target.components.burnable.canlight or target.components.combat ~= nil then
                target.components.burnable:Ignite(true, attacker)
            end
        elseif target.components.fueled.accepting then
            --takes burnable fuel, so fuel it
            local fuel = SpawnPrefab("cutgrass")
            if fuel ~= nil then
                if fuel.components.fuel ~= nil and
                    fuel.components.fuel.fueltype == FUELTYPE.BURNABLE then
                    target.components.fueled:TakeFuelItem(fuel)
                else
                    fuel:Remove()
                end
            end
        end
    end

    if target.components.freezable ~= nil then
        target.components.freezable:AddColdness(-1) --Does this break ice staff?
        if target.components.freezable:IsFrozen() then
            target.components.freezable:Unfreeze()
        end
    end

    if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
        target.components.sleeper:WakeUp()
    end

    if target.components.combat ~= nil then
        target.components.combat:SuggestTarget(attacker)
    end

    target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
end

local REDHAUNTTARGET_MUST_TAGS = { "canlight" }
local REDHAUNTTARGET_CANT_TAGS = { "fire", "burnt", "INLIMBO" }
local function onhauntred(inst, haunter)
    if math.random() <= TUNING.HAUNT_CHANCE_RARE then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 6, REDHAUNTTARGET_MUST_TAGS, REDHAUNTTARGET_CANT_TAGS)
        if #ents > 0 then
            for i, v in ipairs(ents) do
                if v:IsValid() and not v:IsInLimbo() then
                    onattack_red(inst, haunter, v, true)
                end
            end
            inst.components.hauntable.hauntvalue = TUNING.HAUNT_LARGE
            if inst.DoGemShine then
                inst:DoGemShine()
            end
            return true
        end
    end
    return false
end

function fns.red(inst, notinit)
    if notinit then
        inst:AddTag("firestaff")
        inst:AddTag("rangedweapon")
        inst:AddTag("rangedlighter")
    end
    if not inst.components.weapon then
        inst:AddComponent("weapon")
    end
    inst.components.weapon:SetDamage(0)
    inst.components.weapon:SetRange(8, 10)
    inst.components.weapon:SetOnAttack(onattack_red)
    inst.components.weapon:SetProjectile("fire_projectile")
    inst.components.weapon:SetOnProjectileLaunched(projectilelaunched_red)

    AddHauntableCustomReaction(inst, onhauntred, true, false, true)
end

------- blue

local function onattack_blue(inst, attacker, target, skipsanity)
    if not skipsanity and attacker ~= nil then
        if attacker.components.staffsanity then
            attacker.components.staffsanity:DoCastingDelta(-TUNING.SANITY_SUPERTINY)
        elseif attacker.components.sanity ~= nil then
            attacker.components.sanity:DoDelta(-TUNING.SANITY_SUPERTINY)
        end
    end

    if inst.skin_sound then
        attacker.SoundEmitter:PlaySound(inst.skin_sound)
    end

    if not target:IsValid() then
        --target killed or removed in combat damage phase
        return
    end

    if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
        target.components.sleeper:WakeUp()
    end

    if target.components.burnable ~= nil then
        if target.components.burnable:IsBurning() then
            target.components.burnable:Extinguish()
        elseif target.components.burnable:IsSmoldering() then
            target.components.burnable:SmotherSmolder()
        end
    end

    if target.components.combat ~= nil then
        target.components.combat:SuggestTarget(attacker)
    end

    if target.sg ~= nil and not target.sg:HasStateTag("frozen") then
        target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
    end

	--V2C: valid check in case any of the previous callbacks or events removed the target
	if target.components.freezable ~= nil and target:IsValid() then
        target.components.freezable:AddColdness(inst.icestaff_coldness or 1)
        target.components.freezable:SpawnShatterFX()
    end
end

local BLUEHAUNTTARGET_MUST_TAGS = { "freezable" }
local BLUEHAUNTTARGET_CANT_TAGS = { "INLIMBO" }
local function onhauntblue(inst, haunter)
    if math.random() <= TUNING.HAUNT_CHANCE_RARE then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 6, BLUEHAUNTTARGET_MUST_TAGS, BLUEHAUNTTARGET_CANT_TAGS)
        if #ents > 0 then
            for i, v in ipairs(ents) do
                if v:IsValid() and not v:IsInLimbo() then
                    onattack_blue(inst, haunter, v, true)
                end
            end
            inst.components.hauntable.hauntvalue = TUNING.HAUNT_LARGE
            if inst.DoGemShine then
                inst:DoGemShine()
            end
            return true
        end
    end
    return false
end

function fns.blue(inst, notinit)
    if notinit then
        inst:AddTag("icestaff")
        inst:AddTag("rangedweapon")
        inst:AddTag("extinguisher")
    end
    if not inst.components.weapon then
        inst:AddComponent("weapon")
    end
    inst.components.weapon:SetDamage(0)
    inst.components.weapon:SetRange(8, 10)
    inst.components.weapon:SetOnAttack(onattack_blue)
    inst.components.weapon:SetProjectile("ice_projectile")

    AddHauntableCustomReaction(inst, onhauntblue, true, false, true)
end

------- purple

-- AddTag("nomagic") can be used to stop something being teleported
-- the component teleportedoverride can be used to control the location of a teleported item

require "prefabs/telebase"

local function getrandomposition(caster, teleportee, target_in_ocean)
	if target_in_ocean then
		local pt = TheWorld.Map:FindRandomPointInOcean(20)
		if pt ~= nil then
			return pt
		end
		local from_pt = teleportee:GetPosition()
		local offset = FindSwimmableOffset(from_pt, math.random() * TWOPI, 90, 16)
						or FindSwimmableOffset(from_pt, math.random() * TWOPI, 60, 16)
						or FindSwimmableOffset(from_pt, math.random() * TWOPI, 30, 16)
						or FindSwimmableOffset(from_pt, math.random() * TWOPI, 15, 16)
		if offset ~= nil then
			return from_pt + offset
		end
		return teleportee:GetPosition()
	else
		local centers = {}
		for i, node in ipairs(TheWorld.topology.nodes) do
			if TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) and node.type ~= NODE_TYPE.SeparatedRoom then
				table.insert(centers, {x = node.x, z = node.y})
			end
		end
		if #centers > 0 then
			local pos = centers[math.random(#centers)]
			return Point(pos.x, 0, pos.z)
		else
			return caster:GetPosition()
		end
	end
end

local function teleport_end(teleportee, locpos, loctarget, staff)
    if loctarget ~= nil and loctarget:IsValid() and loctarget.onteleto ~= nil then
        loctarget:onteleto()
    end

    if teleportee.components.inventory ~= nil and teleportee.components.inventory:IsHeavyLifting() then
        teleportee.components.inventory:DropItem(
            teleportee.components.inventory:Unequip(EQUIPSLOTS.BODY),
            true,
            true
        )
    end

    if staff.notlightningteleport then
        SpawnPrefab("atrium_portal_fx").Transform:SetPosition(teleportee.Transform:GetWorldPosition())
    else
        --#v2c hacky way to prevent lightning from igniting us
        local preventburning = teleportee.components.burnable ~= nil and not teleportee.components.burnable.burning
        if preventburning then
            teleportee.components.burnable.burning = true
        end
        TheWorld:PushEvent("ms_sendlightningstrike", locpos)
        if preventburning then
            teleportee.components.burnable.burning = false
        end
    end

    if teleportee:HasTag("player") then
        teleportee.sg.statemem.teleport_task = nil
        teleportee.sg:GoToState(
            teleportee:HasTag("playerghost") and "appear" or
            staff.notlightningteleport and "idle" or
            "wakeup"
        )
        local castsound = staff.skin_castsound or staff.castsound or "dontstarve/common/staffteleport"
        if staff.castsoundparams then
            teleportee.SoundEmitter:PlaySoundWithParams(castsound, staff.castsoundparams)
        else
            teleportee.SoundEmitter:PlaySound(castsound)
        end
    else
        teleportee:Show()
        if teleportee.DynamicShadow ~= nil then
            teleportee.DynamicShadow:Enable(true)
        end
        if teleportee.components.health ~= nil then
            teleportee.components.health:SetInvincible(false)
        end
        teleportee:PushEvent("teleported")
    end
end

local function teleport_continue(teleportee, locpos, loctarget, staff)
    if teleportee.Physics ~= nil then
        teleportee.Physics:Teleport(locpos.x, 0, locpos.z)
    else
        teleportee.Transform:SetPosition(locpos.x, 0, locpos.z)
    end
    teleportee:PushEvent("teleport_move")

    if teleportee:HasTag("player") then
        teleportee:SnapCamera()
        teleportee:ScreenFade(true, 1)
        teleportee.sg.statemem.teleport_task = teleportee:DoTaskInTime(1, teleport_end, locpos, loctarget, staff)
    else
        teleport_end(teleportee, locpos, loctarget, staff)
    end
end

local function teleport_start(teleportee, staff, caster, loctarget, target_in_ocean, no_teleport)
    local ground = TheWorld

    --V2C: Gotta do this RIGHT AWAY in case anything happens to loctarget or caster
	local locpos
	if not no_teleport then
		locpos = (teleportee.components.teleportedoverride ~= nil and teleportee.components.teleportedoverride:GetDestPosition())
			or (loctarget == nil and getrandomposition(caster, teleportee, target_in_ocean))
			or (loctarget.teletopos ~= nil and loctarget:teletopos())
			or loctarget:GetPosition()

		if teleportee.components.locomotor ~= nil then
			teleportee.components.locomotor:StopMoving()
		end
	end

    if staff.components.rechargeable and staff.dodischarge then
        staff.components.rechargeable:Discharge(TUNING.KING_CANE_PURPLE_COOLDOWN)
    elseif staff.components.finiteuses then
        staff.components.finiteuses:Use(1)
    end

    if not staff.notlightningteleport and ground:HasTag("cave") then
        -- There's a roof over your head, magic lightning can't strike!
        ground:PushEvent("ms_miniquake", { rad = 3, num = 5, duration = 1.5, target = teleportee })
        return
    end

	local is_teleporting_player
	if not no_teleport then
		if teleportee:HasTag("player") then
			is_teleporting_player = true
			teleportee.sg:GoToState("forcetele")
		else
			if teleportee.components.health ~= nil then
				teleportee.components.health:SetInvincible(true)
			end
			if teleportee.DynamicShadow ~= nil then
				teleportee.DynamicShadow:Enable(false)
			end
			teleportee:Hide()
		end
	end

    if staff.notlightningteleport then
        SpawnPrefab("atrium_portal_fx").Transform:SetPosition(teleportee.Transform:GetWorldPosition())
    else
        --#v2c hacky way to prevent lightning from igniting us
        local preventburning = teleportee.components.burnable ~= nil and not teleportee.components.burnable.burning
        if preventburning then
            teleportee.components.burnable.burning = true
        end
        ground:PushEvent("ms_sendlightningstrike", teleportee:GetPosition())
        if preventburning then
            teleportee.components.burnable.burning = false
        end
    end

    if caster ~= nil then
        if caster.components.staffsanity then
            caster.components.staffsanity:DoCastingDelta(-TUNING.SANITY_HUGE)
        elseif caster.components.sanity ~= nil then
            caster.components.sanity:DoDelta(-TUNING.SANITY_HUGE)
        end
    end

    if not staff.notlightningteleport then
        ground:PushEvent("ms_deltamoisture", TUNING.TELESTAFF_MOISTURE)
    end

	if not no_teleport then
		if is_teleporting_player then
			teleportee.sg.statemem.teleport_task = teleportee:DoTaskInTime(3, teleport_continue, locpos, loctarget, staff)
		else
			teleport_continue(teleportee, locpos, loctarget, staff)
		end
	end
end

local function teleport_func(inst, target, pos, caster)
	target = target or caster

    local x, y, z = target.Transform:GetWorldPosition()
	local target_in_ocean = target.components.locomotor ~= nil and target.components.locomotor:IsAquatic()
	local no_teleport = target:HasTag("noteleport") or not IsTeleportLinkingPermittedFromPoint(x, y, z) --targetable by spell, but don't actually teleport
	local loctarget
	if not no_teleport then
		loctarget = (target.components.minigame_participator ~= nil and target.components.minigame_participator:GetMinigame())
				or (target.components.teleportedoverride ~= nil and target.components.teleportedoverride:GetDestTarget())
				or (target.components.hitchable ~= nil and target:HasTag("hitched") and target.components.hitchable.hitched)
				or nil

		if loctarget == nil and not target_in_ocean then
			loctarget = FindNearestActiveTelebase(x, y, z, nil, 1, "purplegem")
		end
	end
	teleport_start(target, inst, caster, loctarget, target_in_ocean, no_teleport)
end

local TELEPORT_MUST_TAGS = { "locomotor" }
local TELEPORT_CANT_TAGS = { "playerghost", "INLIMBO", "noteleport" }

local function onhauntpurple(inst)
    if math.random() <= TUNING.HAUNT_CHANCE_RARE then
        local target = FindEntity(inst, 20, nil, TELEPORT_MUST_TAGS, TELEPORT_CANT_TAGS)
        if target ~= nil then
            teleport_func(inst, target)
            inst.components.hauntable.hauntvalue = TUNING.HAUNT_LARGE
            if inst.DoGemShine then
                inst:DoGemShine()
            end
            return true
        end
    end
    return false
end

function fns.purple(inst, notinit)
    inst.fxcolour = { 104/255, 40/255, 121/255 }

    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(teleport_func)
    inst.components.spellcaster.canuseontargets = true
    inst.components.spellcaster.canusefrominventory = true
    inst.components.spellcaster.canonlyuseonlocomotorspvp = true

    AddHauntableCustomReaction(inst, onhauntpurple, true, false, true)
end

------- orange

local function onblink(staff, pos, caster)
    if caster then
        if caster.components.staffsanity then
            caster.components.staffsanity:DoCastingDelta(-TUNING.SANITY_MED)
        elseif caster.components.sanity ~= nil then
            caster.components.sanity:DoDelta(-TUNING.SANITY_MED)
        end
    end

    if staff.components.rechargeable and staff.dodischarge then
        staff.components.rechargeable:Discharge(TUNING.KING_CANE_ORANGE_COOLDOWN)
    elseif staff.components.finiteuses then
        staff.components.finiteuses:Use(1)
    end
end

local ORANGEHAUNT_MUST_TAGS = { "locomotor" }
local ORANGEHAUNT_CANT_TAGS = { "playerghost", "INLIMBO" }

local function onhauntorange(inst)
    if math.random() <= TUNING.HAUNT_CHANCE_OCCASIONAL then
        local target = FindEntity(inst, 20, nil, ORANGEHAUNT_MUST_TAGS, ORANGEHAUNT_CANT_TAGS)
        if target ~= nil then
            local pos = target:GetPosition()
            local start_angle = math.random() * TWOPI
            local offset = FindWalkableOffset(pos, start_angle, math.random(8, 12), 16, false, true, NoHoles)
            if offset ~= nil then
                pos.x = pos.x + offset.x
                pos.y = 0
                pos.z = pos.z + offset.z
                inst.components.blinkstaff:Blink(pos, target)
                inst.components.hauntable.hauntvalue = TUNING.HAUNT_LARGE
                if inst.DoGemShine then
                    inst:DoGemShine()
                end
                return true
            end
        end
    end
    return false
end

local function blinkstaff_reticuletargetfn()
    return ControllerReticle_Blink_GetPosition(ThePlayer, NoHoles)
end

function fns.orange_client(inst)
    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = blinkstaff_reticuletargetfn
	inst.components.reticule.twinstickcheckscheme = true
	inst.components.reticule.twinstickmode = 1
	inst.components.reticule.twinstickrange = 15
    inst.components.reticule.ease = true
end

function fns.orange(inst, notinit)
    inst.fxcolour = { 1, 145/255, 0 }
    inst.castsound = "dontstarve/common/staffteleport"

    inst:AddComponent("blinkstaff")
    inst.components.blinkstaff:SetFX("sand_puff_large_front", "sand_puff_large_back")
    inst.components.blinkstaff.onblinkfn = onblink

    AddHauntableCustomReaction(inst, onhauntorange, true, false, true)
end

------- green

local DESTSOUNDS =
{
    {   --magic
        soundpath = "dontstarve/common/destroy_magic",
        ing = { "nightmarefuel", "horrorfuel", "livinglog", "shadowheart_infused", "alterguardianhatshard", "moonrockcrater" },
    },
    {   --cloth
        soundpath = "dontstarve/common/destroy_clothing",
        ing = { "silk", "beefalowool" },
    },
    {   --tool
        soundpath = "dontstarve/common/destroy_tool",
        ing = { "twigs" },
    },
    {   --gem
        soundpath = "dontstarve/common/gem_shatter",
        ing = { "redgem", "bluegem", "greengem", "purplegem", "yellowgem", "orangegem", "purebrilliance" },
    },
    {   --wood
        soundpath = "dontstarve/common/destroy_wood",
        ing = { "log", "boards", "driftwood_log", },
    },
    {   --stone
        soundpath = "dontstarve/common/destroy_stone",
        ing = { "rocks", "cutstone", "saltrock", "flint", "marble", "nitre", "thulecite", "thulecite_pieces" },
    },
    {   --straw
        soundpath = "dontstarve/common/destroy_straw",
        ing = { "cutgrass", "cutreeds", "petals", "petals_evil", "rope" },
    },
    {   --metal
        soundpath = "dontstarve/common/destroy_metal",
        ing = { "gears", "wagpunk_bits", "transistor", "trinket_6", "scandata", "security_pulse_cage_full" },
    },
}
local DESTSOUNDSMAP = {}
for i, v in ipairs(DESTSOUNDS) do
    for i2, v2 in ipairs(v.ing) do
        DESTSOUNDSMAP[v2] = v.soundpath
    end
end
DESTSOUNDS = nil

local function CheckSpawnedLoot(loot)
    if loot.components.inventoryitem ~= nil then
        loot.components.inventoryitem:TryToSink()
    else
        local lootx, looty, lootz = loot.Transform:GetWorldPosition()
        if ShouldEntitySink(loot, true) or TheWorld.Map:IsPointNearHole(Vector3(lootx, 0, lootz)) then
            SinkEntity(loot)
        end
    end
end

local function SpawnLootPrefab(inst, lootprefab)
    if lootprefab == nil then
        return
    end

    local loot = SpawnPrefab(lootprefab)
    if loot == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    if loot.Physics ~= nil then
        local angle = math.random() * TWOPI
        loot.Physics:SetVel(2 * math.cos(angle), 10, 2 * math.sin(angle))

        if inst.Physics ~= nil then
            local len = loot:GetPhysicsRadius(0) + inst:GetPhysicsRadius(0)
            x = x + math.cos(angle) * len
            z = z + math.sin(angle) * len
        end

        loot:DoTaskInTime(1, CheckSpawnedLoot)
    end

    loot.Transform:SetPosition(x, y, z)

	loot:PushEvent("on_loot_dropped", {dropper = inst})

    return loot
end

local function destroystructure(staff, target)
    local recipe = AllRecipes[target.prefab]
    if recipe == nil or FunctionOrValue(recipe.no_deconstruction, target) then
        --Action filters should prevent us from reaching here normally
        return
    end

    local ingredient_percent =
        (   (target.components.finiteuses ~= nil and not FunctionOrValue(recipe.decon_ignores_finiteuses, target) and target.components.finiteuses:GetPercent()) or
            (target.components.fueled ~= nil and target.components.inventoryitem ~= nil and target.components.fueled:GetPercent()) or
            (target.components.armor ~= nil and target.components.inventoryitem ~= nil and target.components.armor:GetPercent()) or
            1
        ) / recipe.numtogive

    --V2C: Can't play sounds on the staff, or nobody
    --     but the user and the host will hear them!
    local caster = staff.components.inventoryitem.owner

    -- If the target is a mimic, drop nightmarefuel instead of any of the recipe loot.
    if target.components.itemmimic then
        -- Do not check ShouldItemMimicBeRevealedFor here, ingredients must be earned.
        if caster then
		    caster.SoundEmitter:PlaySound("dontstarve/creatures/monkey/poopsplat")
        end
        target.components.itemmimic:TurnEvil(caster)
    else
        for i, v in ipairs(recipe.ingredients) do
            if caster ~= nil and DESTSOUNDSMAP[v.type] ~= nil then
                caster.SoundEmitter:PlaySound(DESTSOUNDSMAP[v.type])
            end
            if string.sub(v.type, -3) ~= "gem" or string.sub(v.type, -11, -4) == "precious" then
                --V2C: always at least one in case ingredient_percent is 0%
                local amt = v.amount == 0 and 0 or math.max(1, math.ceil(v.amount * ingredient_percent))
                for _ = 1, amt do
                    SpawnLootPrefab(target, v.type)
                end
            end
        end

        if target.components.inventory ~= nil then
            target.components.inventory:DropEverything()
        end

        if target.components.container ~= nil then
            target.components.container:DropEverything(nil, true)
        end

        if target.components.spawner ~= nil and target.components.spawner:IsOccupied() then
            target.components.spawner:ReleaseChild()
        end

        if target.components.occupiable ~= nil and target.components.occupiable:IsOccupied() then
            local item = target.components.occupiable:Harvest()
            if item ~= nil then
                item.Transform:SetPosition(target.Transform:GetWorldPosition())
                item.components.inventoryitem:OnDropped()
            end
        end

        if target.components.trap ~= nil then
            target.components.trap:Harvest()
        end

        if target.components.dryer ~= nil then
            target.components.dryer:DropItem()
        end

        if target.components.harvestable ~= nil then
            target.components.harvestable:Harvest()
        end

        if target.components.stewer ~= nil then
            target.components.stewer:Harvest()
        end

        if target.components.constructionsite ~= nil then
            target.components.constructionsite:DropAllMaterials()
        end

        if target.components.inventoryitemholder ~= nil then
            target.components.inventoryitemholder:TakeItem()
        end

        target:PushEvent("ondeconstructstructure", caster)

        if not target.no_delete_on_deconstruct then
            if target.components.stackable ~= nil then
                --if it's stackable we only want to destroy one of them.
                target.components.stackable:Get():Remove()
            else
                target:Remove()
            end
        end
    end

    if caster ~= nil then
        caster.SoundEmitter:PlaySound("dontstarve/common/staff_dissassemble")

        if caster.components.staffsanity then
            caster.components.staffsanity:DoCastingDelta(-TUNING.SANITY_MEDLARGE)
        elseif caster.components.sanity ~= nil then
            caster.components.sanity:DoDelta(-TUNING.SANITY_MEDLARGE)
        end
    end

    if staff.components.rechargeable and staff.dodischarge then
        staff.components.rechargeable:Discharge(TUNING.KING_CANE_GREEN_COOLDOWN)
    elseif staff.components.finiteuses then
        staff.components.finiteuses:Use(1)
    end
end

local function HasRecipe(guy)
    return guy.prefab ~= nil and AllRecipes[guy.prefab] ~= nil and not FunctionOrValue(AllRecipes[guy.prefab].no_deconstruction, guy)
end

local GREENHAUNT_CANT_TAGS = { "INLIMBO" }
local function onhauntgreen(inst)
    if math.random() <= TUNING.HAUNT_CHANCE_RARE then
        local target = FindEntity(inst, 20, HasRecipe, nil, GREENHAUNT_CANT_TAGS)
        if target ~= nil then
            destroystructure(inst, target)
            SpawnPrefab("collapse_small").Transform:SetPosition(target.Transform:GetWorldPosition())
            inst.components.hauntable.hauntvalue = TUNING.HAUNT_LARGE
            if inst.DoGemShine then
                inst:DoGemShine()
            end
            return true
        end
    end
    return false
end

function fns.green(inst, notinit)
    inst.fxcolour = { 51/255, 153/255, 51/255 }

    inst:AddComponent("spellcaster")
    inst.components.spellcaster.canuseontargets = true
    inst.components.spellcaster.canonlyuseonrecipes = true
    inst.components.spellcaster:SetSpellFn(destroystructure)

    AddHauntableCustomReaction(inst, onhauntgreen, true, false, true)

    if not inst.components.itemmimicconfig then
        inst:AddComponent("itemmimicconfig")
    end
    inst.components.itemmimicconfig:AddActionForceMimicReveal(ACTIONS.CASTSPELL) -- Ingredients must be earned.
end

------- yellow/opal

local function createlight(staff, target, pos)
    local light = SpawnPrefab(staff.prefab == "opalstaff" and "staffcoldlight" or "stafflight")
    light.Transform:SetPosition(pos:Get())

    if staff.components.rechargeable and staff.dodischarge then
        staff.components.rechargeable:Discharge(TUNING.KING_CANE_YELLOW_COOLDOWN)
    elseif staff.components.finiteuses then
        staff.components.finiteuses:Use(1)
    end

    local caster = staff.components.inventoryitem.owner
    if caster ~= nil then
        if caster.components.staffsanity then
            caster.components.staffsanity:DoCastingDelta(-TUNING.SANITY_MEDLARGE)
        elseif caster.components.sanity ~= nil then
            caster.components.sanity:DoDelta(-TUNING.SANITY_MEDLARGE)
        end
    end
end

local function onhauntlight(inst)
    if math.random() <= TUNING.HAUNT_CHANCE_RARE then
        local pos = inst:GetPosition()
        local start_angle = math.random() * TWOPI
        local offset = FindWalkableOffset(pos, start_angle, math.random(3, 12), 60, false, true, NoHoles)
        if offset ~= nil then
            createlight(inst, nil, pos + offset)
            inst.components.hauntable.hauntvalue = TUNING.HAUNT_LARGE
            if inst.DoGemShine then
                inst:DoGemShine()
            end
            return true
        end
    end
    return false
end

local function light_reticuletargetfn()
    return Vector3(ThePlayer.entity:LocalToWorldSpace(5, 0.001, 0)) -- raised this off the ground a touch so it wont have any z-fighting with the ground biome transition tiles.
end

function fns.yellow_client(inst)
    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = light_reticuletargetfn
	inst.components.reticule.twinstickcheckscheme = true
	inst.components.reticule.twinstickmode = 1
	inst.components.reticule.twinstickrange = 15
    inst.components.reticule.ease = true
    inst.components.reticule.ispassableatallpoints = true
end

function fns.yellow(inst, notinit)
    if notinit then
        inst:AddTag("allow_action_on_impassable")
    end

    inst.fxcolour = { 223/255, 208/255, 69/255 }
    inst.castsound = "dontstarve/common/staffteleport"

    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(createlight)
    inst.components.spellcaster.canuseonpoint = true
    inst.components.spellcaster.canuseonpoint_water = true

    AddHauntableCustomReaction(inst, onhauntlight, true, false, true)
end

function fns.opal_client(inst)
    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = light_reticuletargetfn
	inst.components.reticule.twinstickcheckscheme = true
	inst.components.reticule.twinstickmode = 1
	inst.components.reticule.twinstickrange = 15
    inst.components.reticule.ease = true
    inst.components.reticule.ispassableatallpoints = true
end

function fns.opal(inst, notinit)
    if notinit then
        inst:AddTag("allow_action_on_impassable")
    end

    inst.fxcolour = { 64/255, 64/255, 208/255 }
    inst.castsound = "dontstarve/common/staffteleport"

    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(createlight)
    inst.components.spellcaster.canuseonpoint = true
    inst.components.spellcaster.canuseonpoint_water = true

    AddHauntableCustomReaction(inst, onhauntlight, true, false, true)
end

--

local function cleargemstaff_client(inst)
    inst:RemoveComponent("reticule")
end

local function cleargemstaff(inst) -- for king cane
    inst:RemoveTag("rangedweapon")
    inst:RemoveTag("extinguisher")
    inst:RemoveTag("allow_action_on_impassable")
    inst:RemoveTag("icestaff")
    inst:RemoveTag("firestaff")
    inst:RemoveTag("rangedlighter")

    inst.fxcolour = nil
    inst.castsound = nil

    inst:RemoveComponent("blinkstaff")
    inst:RemoveComponent("spellcaster")
    inst:RemoveComponent("weapon")
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.KING_CANE_DAMAGE)
    inst:RemoveComponent("hauntable") -- just remove and readd hauntable, easier because AddHauntableCustomReaction does a wrap :(
    MakeHauntableLaunch(inst)
    inst.components.itemmimicconfig:RemoveActionForceMimicReveal(ACTIONS.CASTSPELL) -- From greenstaff.
end

return
{
    fns = fns,
    prefabs = prefabs,

    cleargemstaff_client = cleargemstaff_client,
    cleargemstaff = cleargemstaff,

    -- for Mods
    DESTSOUNDSMAP = DESTSOUNDSMAP,
}