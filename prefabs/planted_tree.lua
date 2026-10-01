local pinecone_assets =
{
    Asset("ANIM", "anim/pinecone.zip"),
}

local pinecone_prefabs =
{
    "evergreen_short",
}

local acorn_assets =
{
    Asset("ANIM", "anim/acorn.zip"),
}

local acorn_prefabs =
{
    "deciduoustree",
}

local twiggy_nut_assets =
{
    Asset("ANIM", "anim/twiggy_nut.zip"),
}

local twiggy_nut_prefabs =
{
    "twiggy_short",
}

local marblebean_assets =
{
    Asset("ANIM", "anim/marblebean.zip"),
}

local marblebean_prefabs =
{
    "marbleshrub_short",
}

local moonbutterfly_assets =
{
    Asset("ANIM", "anim/baby_moon_tree.zip"),
}

local moonbutterfly_prefabs =
{
    "moon_tree_short",
}

local palmcone_assets =
{
    Asset("ANIM", "anim/palmcone_seed.zip"),
}

local palmcone_prefabs =
{
    "palmconetree_short",
}

local tree_rock_assets =
{
    Asset("ANIM", "anim/tree_rock_seed.zip"),
}

local tree_rock_prefabs =
{
    "tree_rock1_short",
    "tree_rock2_short",
}

local function growtree(inst)
    local grow_prefab = type(inst.growprefab) == "table" and GetRandomItem(inst.growprefab) or inst.growprefab
    local tree = SpawnPrefab(grow_prefab)
    if tree then
        tree.Transform:SetPosition(inst.Transform:GetWorldPosition())
        tree:growfromseed()
        inst:Remove()
    end
end

local function stopgrowing(inst)
    inst.components.timer:StopTimer("grow")
end

local function startgrowing(inst)
    if not inst.components.timer:TimerExists("grow") then
        local basetime = inst.growtimes and inst.growtimes.base or TUNING.PINECONE_GROWTIME.base
        local randomtime = inst.growtimes and inst.growtimes.random or TUNING.PINECONE_GROWTIME.random
        local growtime = GetRandomWithVariance(basetime, randomtime)
        inst.components.timer:StartTimer("grow", growtime)
    end
end

local function ontimerdone(inst, data)
    if data.name == "grow" then
        growtree(inst)
    end
end

local function digup(inst, digger)
    inst.components.lootdropper:DropLoot()
    inst:Remove()
end

local function sapling_fn(build, anim, growprefab, tag, fireproof, overrideloot, override_deploy_smart_radius, grow_times)
    local scrapbook_adddeps = {}

    if type(growprefab) == "table" then
        for k, prefab in pairs(growprefab) do
            table.insert(scrapbook_adddeps, prefab == tag and tag.."_tall" or string.gsub(prefab, "short", "tall"))
        end
    else
        table.insert(scrapbook_adddeps, growprefab == tag and tag.."_tall" or string.gsub(growprefab, "short", "tall"))
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

		inst:SetDeploySmartRadius(override_deploy_smart_radius or DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2)

        inst.AnimState:SetBank(build)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)

        if not fireproof then
            inst:AddTag("plant")
        end

        inst:AddTag(tag)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.scrapbook_anim = anim
        inst.scrapbook_adddeps = scrapbook_adddeps

        inst.growprefab = growprefab
        inst.growtimes = grow_times
        inst.StartGrowing = startgrowing

        inst:AddComponent("timer")
        inst:ListenForEvent("timerdone", ontimerdone)
        startgrowing(inst)

        inst:AddComponent("inspectable")

        inst:AddComponent("lootdropper")
        inst.components.lootdropper:SetLoot(overrideloot or {"twigs"})

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.DIG)
        inst.components.workable:SetOnFinishCallback(digup)
        inst.components.workable:SetWorkLeft(1)

        if not fireproof then
            MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
            inst:ListenForEvent("onignite", stopgrowing)
            inst:ListenForEvent("onextinguish", startgrowing)
            MakeSmallPropagator(inst)

            MakeHauntableIgnite(inst)
        else
            MakeHauntableWork(inst)
        end

        MakeWaxablePlant(inst)

        return inst
    end
    return fn
end

return
    Prefab("pinecone_sapling",      sapling_fn("pinecone", "idle_planted", "evergreen_short", "evergreen"),                                                 pinecone_assets,        pinecone_prefabs      ),
    Prefab("lumpy_sapling",         sapling_fn("pinecone", "idle_planted2", "evergreen_sparse_short", "evergreen_sparse"),                                  pinecone_assets,        pinecone_prefabs      ),
    Prefab("acorn_sapling",         sapling_fn("acorn", "idle_planted", "deciduoustree", "deciduoustree"),                                                  acorn_assets,           acorn_prefabs         ),
    Prefab("twiggy_nut_sapling",    sapling_fn("twiggy_nut", "idle_planted", "twiggy_short", "twiggytree"),                                                 twiggy_nut_assets,      twiggy_nut_prefabs    ),
    Prefab("marblebean_sapling",    sapling_fn("marblebean", "idle_planted", "marbleshrub_short", "marbleshrub", true, {"marblebean"}),                     marblebean_assets,      marblebean_prefabs    ),
    Prefab("moonbutterfly_sapling", sapling_fn("baby_moon_tree", "idle", "moon_tree_short", "moon_tree", nil, nil, DEPLOYSPACING_RADIUS[DEPLOYSPACING.PLACER_DEFAULT] / 2), moonbutterfly_assets, moonbutterfly_prefabs ),
    Prefab("palmcone_sapling",      sapling_fn("palmcone_seed", "idle_planted", "palmconetree_short", "palmconetree"),                                      palmcone_assets,        palmcone_prefabs      ),
    Prefab("tree_rock_sapling",     sapling_fn("tree_rock_seed", "idle_planted", {"tree_rock1_short", "tree_rock2_short"}, "treerock", nil, nil, nil, TUNING.TREE_ROCK.SAPLING_GROW_TIME),                     tree_rock_assets,       tree_rock_prefabs     )