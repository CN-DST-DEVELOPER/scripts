local brain = require("brains/wanderingtraderbrain")

local assets = {
    Asset("ANIM", "anim/wanderingtrader.zip"),
}

local prefabs = {}

local FORGETABLE_RECIPES = {} -- Recipes that do not have a limit flag will be forgot on rerolling.

local WARES = {
    STARTER = { -- NOTES(JBK): This is what is given to the shopkeep at the start of a new world in addition to a roll.
        {
            ["gears"] = {recipe = "wanderingtradershop_gears", min = 1, max = 1, limit = 1,},
        },
    },
    ALWAYS = { -- Make sure there is at least one trade that has min = 1 in this table.
        {
            ["flint"] = {recipe = "wanderingtradershop_flint", min = 1, max = 2, limit = 4,},
        }, -- This keeps code complexity down by having all of the formats the same table structure.
    },
    RANDOM_UNCOMMONS = {
        {
            ["gears"] = {recipe = "wanderingtradershop_gears", min = 1, max = 1, limit = 1,},
        },
        {
            ["pigskin"] = {recipe = "wanderingtradershop_pigskin", min = 1, max = 2,},
        },
        {
            ["livinglog"] = {recipe = "wanderingtradershop_livinglog", min = 1, max = 1,},
        },
    },
    RANDOM_RARES = {
        {
            ["redgem"] = {recipe = "wanderingtradershop_redgem", min = 1, max = 1,},
        },
        {
            ["bluegem"] = {recipe = "wanderingtradershop_bluegem", min = 1, max = 1,},
        },
    },
    SEASONAL = {
        [SEASONS.AUTUMN] = {
            ["cutgrass"] = {recipe = "wanderingtradershop_cutgrass", min = 1, max = 3, limit = 8,},
            ["twigs"] = {recipe = "wanderingtradershop_twigs", min = 1, max = 3, limit = 8,},
            ["cutreeds"] = {recipe = "wanderingtradershop_cutreeds", min = 0, max = 1, limit = 6,},
        },
        [SEASONS.WINTER] = {
            ["cutgrass"] = {recipe = "wanderingtradershop_cutgrass", min = 0, max = 1, limit = 4,},
            ["twigs"] = {recipe = "wanderingtradershop_twigs", min = 0, max = 1, limit = 4,},
        },
        [SEASONS.SPRING] = {
            ["cutgrass"] = {recipe = "wanderingtradershop_cutgrass", min = 2, max = 5, limit = 16,},
            ["twigs"] = {recipe = "wanderingtradershop_twigs", min = 2, max = 5, limit = 16,},
            ["cutreeds"] = {recipe = "wanderingtradershop_cutreeds", min = 2, max = 3, limit = 12,},
        },
        [SEASONS.SUMMER] = {
            ["cutgrass"] = {recipe = "wanderingtradershop_cutgrass", min = 0, max = 1, limit = 4,},
            ["twigs"] = {recipe = "wanderingtradershop_twigs", min = 0, max = 1, limit = 4,},
        },
    },
    SPECIAL = {
        ["islunarhailing"] = {
            ["moonglass"] = {recipe = "wanderingtradershop_moonglass", min = 2, max = 4, limit = 8,},
        },
    }
}

for _, warebucket in pairs(WARES) do
    for _, prefabdata in pairs(warebucket) do
        for prefab, waredata in pairs(prefabdata) do
            if not table.contains(prefabs, prefab) then
                table.insert(prefabs, prefab)
            end
            if not waredata.limit then
                FORGETABLE_RECIPES[waredata.recipe] = true
            end
        end
    end
end

local function DoChatter(inst, name, index, cooldown)
    inst.sg.mem.canchattertimestamp = GetTime() + cooldown
    inst.components.talker:Chatter(name, index, nil, nil, CHATPRIORITIES.NOCHAT)
end
local function CanChatter(inst)
    return inst.sg.mem.canchattertimestamp == nil or (inst.sg.mem.canchattertimestamp < GetTime())
end
local function TryChatter(inst, name, index, cooldown)
    if inst:CanChatter() then
        inst:DoChatter(name, index, cooldown)
    end
end

local function OnTurnOn(inst)
    inst.components.worldroutefollower:SetPaused(true, "trading")
    inst.components.timer:PauseTimer("refreshwares")
    inst.sg.mem.trading = true
end
local function OnTurnOff(inst)
    inst.components.worldroutefollower:SetPaused(false, "trading")
    inst.components.timer:ResumeTimer("refreshwares")
    inst.sg.mem.trading = nil
end
local function OnActivate(inst)
	local no_stock = not inst:HasStock()
	if no_stock then
		inst:EnablePrototyper(false)
	end
    inst.sg.mem.didtrade = true
    inst:PushEvent("dotrade", {no_stock = no_stock, })
end

local function ClearArrivedWait(inst)
    inst.components.worldroutefollower:SetPaused(false, "arrivedwait")
end
local function OnArrivedFn(inst)
    inst.components.worldroutefollower:SetPaused(true, "arrivedwait")
    inst:DoTaskInTime(GetRandomWithVariance(TUNING.WANDERINGTRADER_WANDERING_PERIOD, TUNING.WANDERINGTRADER_WANDERING_PERIOD_VARIANCE), ClearArrivedWait)
end

local function HasStock(inst)
	return #inst.components.craftingstation:GetRecipes() > 0
end

local function EnablePrototyper(inst, enabled)
	if not enabled then
		inst:RemoveComponent("prototyper")
	elseif inst.components.prototyper == nil then
		local prototyper = inst:AddComponent("prototyper")
		prototyper.onturnon = OnTurnOn
		prototyper.onturnoff = OnTurnOff
		prototyper.onactivate = OnActivate
		prototyper.trees = TUNING.PROTOTYPER_TREES.WANDERINGTRADERSHOP
	end
end

local function AddWares(inst, wares)
    local craftingstation = inst.components.craftingstation
    for item, recipedata in pairs(wares) do
        local oldlimit = craftingstation:GetRecipeCraftingLimit(recipedata.recipe) or 0
        local caplimit = recipedata.limit or 255 -- NOTES(JBK): Netvar limit for SetRecipeCraftingLimit.
        local newlimit = math.min(oldlimit + math.random(recipedata.min, recipedata.max), caplimit)
        if newlimit > 0 and newlimit > oldlimit then
            craftingstation:LearnItem(item, recipedata.recipe)
            craftingstation:SetRecipeCraftingLimit(recipedata.recipe, newlimit)
        end
    end
end

local function RerollWares(inst)
    local craftingstation = inst.components.craftingstation
    for recipe, _ in pairs(inst.FORGETABLE_RECIPES) do
        craftingstation:ForgetRecipe(recipe)
    end
    inst:AddWares(inst.WARES.ALWAYS[1])
    if math.random() < TUNING.WANDERINGTRADER_SHOP_RANDOM_UNCOMMON_ODDS then
        inst:AddWares(inst.WARES.RANDOM_UNCOMMONS[math.random(#inst.WARES.RANDOM_UNCOMMONS)])
    end
    if math.random() < TUNING.WANDERINGTRADER_SHOP_RANDOM_RARE_ODDS then
        inst:AddWares(inst.WARES.RANDOM_RARES[math.random(#inst.WARES.RANDOM_RARES)])
    end
    local seasonalwares = inst.WARES.SEASONAL[TheWorld.state.season]
    if seasonalwares then
        inst:AddWares(seasonalwares)
    end
	inst:EnablePrototyper(inst:HasTag("revealed"))
end

local function OnTimerDone(inst, data)
    if data then
        if data.name == "refreshwares" then
            local x, y, z = inst.Transform:GetWorldPosition()
            if IsAnyPlayerInRangeSq(x, y, z, PLAYER_CAMERA_SEE_DISTANCE_SQ, true) then
                -- A nearby alive player is too close let us reschedule the timer.
                inst.components.timer:StartTimer("refreshwares", 5)
            else
                inst:RerollWares()
                inst.components.timer:StartTimer("refreshwares", TUNING.WANDERINGTRADER_SHOP_REFRESH_INTERVAL)
            end
        end
    end
end

local function NoHolesNoInvisibleTiles(pt)
    local tile = TheWorld.Map:GetTileAtPoint(pt:Get())
    if GROUND_INVISIBLETILES[tile] then
        return false
    end
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function IsValidPointForRoute(x, y, z)
    local tile = TheWorld.Map:GetTileAtPoint(x, y, z)
    if GROUND_INVISIBLETILES[tile] then
        return false
    end
    return TheWorld.Map:IsLandTileAtPoint(x, y, z)
end

local function DestPositionFn(inst)
    -- We were teleported so we should arrive somewhere on the route if it exists instead.
    local worldroutefollower = inst.components.worldroutefollower
    local route = worldroutefollower:GetRoute()
    if route then
        local routeindex = math.random(#route)
        worldroutefollower:SetRouteIndex(routeindex)
        if worldroutefollower:TryToTeleportToDestination() then
            return inst:GetPosition()
        end
    end

    return nil -- Default telestaff location.
end

local function GetRandomPointForNode(node)
    local points_x, points_z = TheWorld.Map:GetRandomPointsForSite(node.x, node.y, node.poly, 30)
    for i, x in ipairs(points_x) do
        local z = points_z[i]
        if IsValidPointForRoute(x, 0, z) then
            return Vector3(x, 0, z)
        end
    end
    if IsValidPointForRoute(node.x, 0, node.y) then -- This should be a guarantee.
        return Vector3(node.x, 0, node.y)
    end
    if IsValidPointForRoute(node.cent[1], 0, node.cent[2]) then -- Just in case.
        return Vector3(node.cent[1], 0, node.cent[2])
    end
    return nil -- Some assumption has failed miserably.
end

local function FindShortestPath(nodes, start_index, end_index, totalpath)
    -- This algorithm is a bfs and it will return the route from end to start so let us reverse the nodes internally to make it return the route from start to end.
    start_index, end_index = end_index, start_index
    if not start_index or not end_index then
        return false
    end
    local came_from = {
        [start_index] = start_index,
    }
    local to_visit_queue = {start_index}
    local validpts = {}
    local queue_index = 1
    local queue_max = 1
    while queue_index <= queue_max do
        local visiting_index = to_visit_queue[queue_index]
        queue_index = queue_index + 1
        if visiting_index == end_index then
            local current = end_index -- Reverse the nodes.
            while current ~= start_index do
                table.insert(totalpath, validpts[current])
                current = came_from[current]
            end
            return true
        end
        for _, v in ipairs(nodes[visiting_index].neighbours) do
            if not came_from[v] then
                local pt = GetRandomPointForNode(nodes[v])
                if pt then
                    validpts[v] = pt
                    table.insert(to_visit_queue, v)
                    came_from[v] = visiting_index
                    queue_max = queue_max + 1
                end
            end
        end
    end
    return false
end
local function GetRequiredNodes(inst, prefabstofind)
    local nodes = TheWorld.topology.nodes
    local requirednodes = {}
    for _, v in pairs(Ents) do
        if prefabstofind[v.prefab] then
            local x, y, z = v.Transform:GetWorldPosition()
            for i, node in ipairs(nodes) do
                if TheSim:WorldPointInPoly(x, z, node.poly) then
                    if IsValidPointForRoute(x, y, z) and not table.contains(node.tags, "not_mainland") then
                        table.insert(requirednodes, i)
                    end
                    break
                end
            end
        end
    end
    return requirednodes
end
local function TryToCreateRouteFromTopology(inst, route)
    local nodes = TheWorld.topology.nodes
    local requirednodes = inst:GetRequiredNodes({
        ["multiplayer_portal"] = true,
        ["pigking"] = true,
        ["charlie_stage_post"] = true,
        ["oasislake"] = true,
        ["moonbase"] = true,
        ["junk_pile_big"] = true,
        ["critterlab"] = true,
        ["beequeenhive"] = true,
    })
    local totalrequirednodes = #requirednodes
    shuffleArray(requirednodes) -- Randomize up the route some node paths are better done this way.
    local start_index = requirednodes[1]
    for i = 1, totalrequirednodes do
        local end_index
        if i == totalrequirednodes then
            end_index = requirednodes[1]
        else
            end_index = requirednodes[i + 1]
        end
        if FindShortestPath(nodes, start_index, end_index, route) then
            start_index = end_index
        end
    end
    if route[1] then
        TheWorld.components.worldroutes:SetRoute("wanderingtrader", route)
    end
end
local function CreateRouteFromRandomWalk(inst, route) -- This cannot fail.
    local start_pt = Vector3(TheWorld.components.playerspawner:GetAnySpawnPoint())
    -- From start_pt, we will make a circle with a random offset from each segment.
    local circle_radius = 70
    local circle_points = 8 -- Chord length 50 and some.
    local random_radius_max = 20 -- Less than half chord for no overlap.
    local random_radius_min = 5
    local random_radius_iter = -5
    local pt = Vector3(0, 0, 0)
    for i = 0, 7 do
        local theta = (PI2 * i) / circle_points
        local circle_x = math.cos(theta) * circle_radius
        local circle_z = math.sin(theta) * circle_radius
        pt.x = start_pt.x + circle_x
        pt.z = start_pt.z + circle_z
        if IsValidPointForRoute(pt.x, 0, pt.z) then
            for radius = random_radius_max, random_radius_min, random_radius_iter do
                local offset = FindWalkableOffset(pt, TWOPI * math.random(), random_radius_max, 8, false, false, NoHolesNoInvisibleTiles)
                if offset and IsValidPointForRoute(pt.x + offset.x, 0, pt.z + offset.z) then
                    pt.x = pt.x + offset.x
                    pt.z = pt.z + offset.z
                    break
                end
            end
            table.insert(route, Vector3(pt.x, 0, pt.z))
        end
    end
    if not route[1] then
        table.insert(route, Vector3(start_pt.x, 0, start_pt.z))
    end
    TheWorld.components.worldroutes:SetRoute("wanderingtrader", route)
end

local function CreateWorldRoute(inst, route)
    if not route[1] then
        inst:TryToCreateRouteFromTopology(route)
    end
    if not route[1] then
        inst:CreateRouteFromRandomWalk(route)
    end
end
local function TryToCreateWorldRoute(inst)
    if not TheWorld.components.worldroutes then
        return false
    end

    if inst.components.worldroutefollower:FollowRoute("wanderingtrader") then
        return true
    end

    local route = {}
    inst:CreateWorldRoute(route)
    if route[1] then
        return inst.components.worldroutefollower:FollowRoute("wanderingtrader")
    end

    return false
end

local function Initialize(inst)
    inst.inittask = nil
    inst:AddWares(inst.WARES.STARTER[1])
    inst:RerollWares()
    inst:TryToCreateWorldRoute()
end

local function OnSave(inst, data)
    data.islunarhailing = inst.islunarhailing
end
local function OnLoad(inst, data)
    if inst.inittask ~= nil then
        inst.inittask:Cancel()
        inst.inittask = nil
    end
    inst.islunarhailing = data.islunarhailing
end
local function OnLoadPostPass(inst)--newents, savedata)
    inst:TryToCreateWorldRoute()
end

local function ImmediatelyTeleport(inst)
    inst.components.worldroutefollower:TeleportToDestination()
end
local function TeleportDelay(inst) -- NOTES(JBK): Needs a delay so that OnEntityWake does not get called before OnEntitySleep from this teleport.
	inst.HiddenActionFn = nil
    inst:DoTaskInTime(0, ImmediatelyTeleport)
end

local function PreTeleportFn(inst, destx, desty, destz)
    if not inst:IsAsleep() then
		inst.HiddenActionFn = TeleportDelay
        inst.sg:GoToState("teleport")
        return true -- We handle teleporting.
    end
    return false -- Let callee handle teleporting.
end

local function PostTeleportFn(inst)
	inst.HiddenActionFn = nil
	inst:PushEvent("arrive")
end

local function GoToHiding(inst)
	inst.HiddenActionFn = nil
    inst.sg:GoToState("hiding")
    inst:RemoveFromScene()
end
local function OnWanderingTraderHide(inst) -- This stomps over all stategraphs with a RemoveFromScene so we call it on the entity events.
    inst.components.worldroutefollower:SetPaused(true, "hiding")
    if inst:IsAsleep() then
        GoToHiding(inst)
    else
		inst.HiddenActionFn = GoToHiding
        inst.sg:GoToState("hide")
    end
end
local function OnWanderingTraderShow(inst) -- This stomps over all stategraphs with a RemoveFromScene so we call it on the entity events.
    inst:ReturnToScene()
    inst.sg:GoToState("arrive")
    inst.components.worldroutefollower:SetPaused(false, "hiding")
end

local function SetIsLunarHailing(inst, active)
    if inst.islunarhailing ~= active then
        inst.islunarhailing = active
        if inst.islunarhailing then
            inst:AddWares(inst.WARES.SPECIAL["islunarhailing"])
        end
    end
end
local function OnWorldInit(inst)
    inst:WatchWorldState("islunarhailing", inst.SetIsLunarHailing)
    inst:SetIsLunarHailing(TheWorld.state.islunarhailing)
end

local function DisplayNameFn(inst)
	return inst:HasTag("revealed") and STRINGS.NAMES.WANDERINGTRADER_REVEALED or nil
end

local function GetStatus(inst)--, viewer)
	return inst.sg:HasStateTag("revealed") and "revealed" or nil
end

local function SetRevealed(inst, revealed)
	if revealed then
		inst:AddTag("revealed")
		inst:EnablePrototyper(inst:HasStock())
	else
		inst:RemoveTag("revealed")
		inst:EnablePrototyper(false)
	end
end

local function OnEntitySleep(inst)
	if inst.HiddenActionFn then
		inst:HiddenActionFn()
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 100, 0.5)

    inst.DynamicShadow:SetSize(1, .75)
    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("wanderingtrader")
    inst.AnimState:SetBuild("wanderingtrader")
    inst.AnimState:PlayAnimation("idle")

    local talker = inst:AddComponent("talker")
    talker.fontsize = 35
    talker.font = TALKINGFONT
    talker.offset = Vector3(0, -600, 0)
    talker.name_colour = Vector3(130/255, 109/255, 57/255)
    talker.chaticon = "npcchatflair_wanderingtrader"
    talker:MakeChatter()

	inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.WARES = WARES
    inst.FORGETABLE_RECIPES = FORGETABLE_RECIPES

    inst.DoChatter = DoChatter
    inst.CanChatter = CanChatter
    inst.TryChatter = TryChatter

    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

	inst.HiddenActionFn = nil
	inst.OnEntitySleep = OnEntitySleep

	inst.HasStock = HasStock
    inst.RerollWares = RerollWares
    inst.AddWares = AddWares
    inst.GetRequiredNodes = GetRequiredNodes
    inst.TryToCreateWorldRoute = TryToCreateWorldRoute
    inst.CreateWorldRoute = CreateWorldRoute
    inst.TryToCreateRouteFromTopology = TryToCreateRouteFromTopology
    inst.CreateRouteFromRandomWalk = CreateRouteFromRandomWalk
	inst.EnablePrototyper = EnablePrototyper

    inst.OnWanderingTraderHide = OnWanderingTraderHide
    inst.OnWanderingTraderShow = OnWanderingTraderShow

    inst.SetIsLunarHailing = SetIsLunarHailing

	inst.SetRevealed = SetRevealed

    inst:AddComponent("craftingstation")

    inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

    local locomotor = inst:AddComponent("locomotor")
    locomotor.walkspeed = 1.5
    locomotor.runspeed = 4

    local stuckdetection = inst:AddComponent("stuckdetection")
    stuckdetection:SetTimeToStuck(5)

    local worldroutefollower = inst:AddComponent("worldroutefollower")
    worldroutefollower:SetOnArrivedFn(OnArrivedFn)
    worldroutefollower:SetVirtualWalkingSpeedMult(TUNING.WANDERINGTRADER_VIRTUALWALKING_SPEEDMULT)
    worldroutefollower:SetIsValidPointForRouteFn(IsValidPointForRoute)
    worldroutefollower:SetPreTeleportFn(PreTeleportFn)
    worldroutefollower:SetPostTeleportFn(PostTeleportFn)

    local teleportedoverride = inst:AddComponent("teleportedoverride")
    teleportedoverride:SetDestPositionFn(DestPositionFn)

    local timer = inst:AddComponent("timer")
    timer:StartTimer("refreshwares", TUNING.WANDERINGTRADER_SHOP_REFRESH_INTERVAL)
    inst:ListenForEvent("timerdone", OnTimerDone)

    inst:SetBrain(brain)
    inst:SetStateGraph("SGwanderingtrader")

    inst:ListenForEvent("wanderingtrader_hide", inst.OnWanderingTraderHide)
    inst:ListenForEvent("wanderingtrader_show", inst.OnWanderingTraderShow)
    TheWorld:PushEvent("wanderingtrader_created", {wanderingtrader = inst,})

    inst.inittask = inst:DoTaskInTime(0, Initialize)
    inst:DoTaskInTime(0, OnWorldInit)

    return inst
end

return Prefab("wanderingtrader", fn, assets, prefabs)
