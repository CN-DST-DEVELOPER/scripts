local stalagmite_assets =
{
    Asset("ANIM", "anim/rock_stalagmite.zip"),
    Asset("MINIMAP_IMAGE", "stalagmite"), --shared with other numbered prefabs
}

local prefabs =
{
    "rocks",
    "nitre",
    "flint",
    "goldnugget",
    "orangegem",
    "rock_break_fx",
    "fossil_piece",

	--halloween
	"spooked_spider_rock_fx",
}

SetSharedLootTable( 'full_rock',
{
    {'rocks',       1.00},
    {'rocks',       1.00},
    {'rocks',       1.00},
    {'goldnugget',  1.00},
    {'flint',       1.00},
    {'fossil_piece',0.10},
    {'goldnugget',  0.25},
    {'flint',       0.60},
    {'bluegem',     0.05},
    {'redgem',      0.05},
})

SetSharedLootTable( 'med_rock',
{
    {'rocks',       1.00},
    {'rocks',       1.00},
    {'flint',       1.00},
    {'goldnugget',  0.50},
    {'fossil_piece',0.10},
    {'flint',       0.60},
})

SetSharedLootTable( 'low_rock',
{
    {'rocks',       1.00},
    {'flint',       1.00},
    {'goldnugget',  0.50},
    {'fossil_piece',0.10},
    {'flint',       0.30},
})

local function workcallback(inst, worker, workleft)
    if workleft <= 0 then
        local pos = inst:GetPosition()
        SpawnPrefab("rock_break_fx").Transform:SetPosition(pos:Get())
        inst.components.lootdropper:DropLoot(pos)
        inst:Remove()
    else
		local anim =
            (workleft <= TUNING.ROCKS_MINE / 3 and "low") or
            (workleft <= TUNING.ROCKS_MINE * 2 / 3 and "med") or
            "full"

		if --IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) and
			worker.components.spooked and
			not inst.AnimState:IsCurrentAnimation(anim) and
			anim ~= "full"
		then
			--higher chance on initial break
			local spookmult = anim == "med" and TUNING.MINE_SPOOKED_MULT_HIGH or TUNING.MINE_SPOOKED_MULT_LOW
			worker.components.spooked:TryCustomSpook(inst, "spooked_spider_rock_fx", spookmult)
		end

		inst.AnimState:PlayAnimation(anim)
    end
end

local function commonfn(anim)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("stalagmite.png")

    MakeObstaclePhysics(inst, 1)

    inst.AnimState:SetBank("rock_stalagmite")
    inst.AnimState:SetBuild("rock_stalagmite")
    inst.AnimState:PlayAnimation(anim)

    inst:SetPrefabNameOverride("stalagmite")

    inst:AddTag("boulder")

    inst.scrapbook_anim = "full"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    local color = 0.5 + math.random() * 0.5
    inst.AnimState:SetMultColour(color, color, color, 1)

    inst:AddComponent("lootdropper")

    inst:AddComponent("inspectable")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetWorkLeft(TUNING.ROCKS_MINE)

    inst.components.workable:SetOnWorkCallback(workcallback)

    MakeHauntableWork(inst)

    return inst
end

local function fullrock()
    local inst = commonfn("full")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.lootdropper:SetChanceLootTable('full_rock')

    return inst
end

local function medrock()
    local inst = commonfn("med")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.workable:SetWorkLeft(TUNING.ROCKS_MINE_MED)
    inst.components.lootdropper:SetChanceLootTable('med_rock')

    return inst
end

local function lowrock()
    local inst = commonfn("low")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.workable:SetWorkLeft(TUNING.ROCKS_MINE_LOW)
    inst.components.lootdropper:SetChanceLootTable('low_rock')

    return inst
end

return Prefab("stalagmite_full", fullrock, stalagmite_assets, prefabs),
    Prefab("stalagmite_med", medrock, stalagmite_assets, prefabs),
    Prefab("stalagmite_low", lowrock, stalagmite_assets, prefabs),
    Prefab("stalagmite", fullrock, stalagmite_assets, prefabs)
