
local RuinsRespawner = require "prefabs/ruinsrespawner"

local assets =
{
    Asset("ANIM", "anim/chessmonster_ruins.zip"),
	Asset("MINIMAP_IMAGE", "chessjunk"),
    Asset("SCRIPT", "scripts/prefabs/ruinsrespawner.lua"),
}

local prefabs =
{
	"bishop_nightmare",
	"rook_nightmare",
	"knight_nightmare",
    "gears",
    "redgem",
    "greengem",
    "yellowgem",
    "purplegem",
    "orangegem",
    "collapse_small",
    "maxwell_smoke",
    "chessjunk_ruinsrespawner_inst",

    -- Year of the Clockwork Knight
    "redpouch_yoth",
}

SetSharedLootTable("chess_junk",
{
    {'trinket_6',      1.00},
    {'trinket_6',      0.55},
    {'trinket_1',      0.25},
    {'gears',          0.25},
    {'redgem',         0.25},
    {"greengem" ,      0.05},
    {"yellowgem",      0.05},
    {"purplegem",      0.05},
    {"orangegem",      0.05},
    {"thulecite",      0.01},
})

local MAXHITS = 6

local function SpawnScionAtXZ(x, z, friendly, style, player, repairerid, repairerchar)
	SpawnPrefab("maxwell_smoke").Transform:SetPosition(x, 0, z)

    local scion = SpawnPrefab(
        (style == 1 and (math.random() < .5 and "bishop_nightmare" or "knight_nightmare")) or
        (style == 2 and (math.random() < .3 and "rook_nightmare" or "knight_nightmare")) or
        (math.random() < .3 and "rook_nightmare" or "bishop_nightmare")
    )

    if scion ~= nil then
		scion.Transform:SetPosition(x, 0, z)
		--V2C: player could be nil on load, or invalid
        --     either cuz of something that happened during the TaskInTime
        --     or as a result of the lightning strike

		if friendly then
			if scion.TryBefriendChess and not scion:TryBefriendChess(player) then
				for i, v in ipairs(FindPlayersInRangeSortedByDistance(x, 0, z, 20, true)) do
					if scion:TryBefriendChess(v) then
						break
					end
				end
			end
			if not (scion.components.follower and scion.components.follower:GetLeader()) and
				repairerid and scion.components.followermemory
			then
				scion.components.followermemory:RememberLeaderDetails(repairerid, repairerchar)
			end
		elseif scion.components.combat:CanTarget(player) then
			scion.components.combat:SetTarget(player)
        end
    end
end

local function OnPlayerRepaired(inst, player)
    inst.components.lootdropper:AddChanceLoot("gears", .1)
    inst.components.lootdropper:DropLoot()

	local x, _, z = inst.Transform:GetWorldPosition()
	inst:Remove()
	SpawnScionAtXZ(x, z, true, inst.style, player, inst.repairerid, inst.repairerchar)
end

local function OnRepaired(inst, doer)
    if inst.components.workable.workleft < MAXHITS then
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_repair")
        inst.AnimState:PlayAnimation("hit"..inst.style)
		inst.AnimState:PushAnimation("idle"..inst.style, false)
    else
		inst.AnimState:PlayAnimation("hit"..inst.style, true)
        inst.SoundEmitter:PlaySound("dontstarve/common/chesspile_ressurect")
        inst:DoTaskInTime(.7, OnPlayerRepaired, doer)
        inst.repaired = true
		if doer and doer.userid then
			inst.repairerid = doer.userid
			inst.repairerchar = doer.prefab
		end
    end
end

local function OnHammered(inst, worker)
    inst.components.lootdropper:DropLoot()

	local x, y, z = inst.Transform:GetWorldPosition()
	inst:Remove()

	if TryLuckRoll(worker, TUNING.CHESSJUNK_SPAWNSCION_CHANCE, LuckFormulas.ChessJunkSpawnClockwork) then
		TheWorld:PushEvent("ms_sendlightningstrike", Vector3(x, 0, z))
		SpawnScionAtXZ(x, z, false, inst.style, worker)
    else
        local fx = SpawnPrefab("collapse_small")
		fx.Transform:SetPosition(x, y, z)
        fx:SetMaterial("metal")
    end
end

local function OnHit(inst, worker, workLeft)
    inst.AnimState:PlayAnimation("hit"..inst.style)
	inst.AnimState:PushAnimation("idle"..inst.style, false)
    inst.SoundEmitter:PlaySound("dontstarve/common/lightningrod")
end

local function OnSave(inst, data)
	if inst.repaired then
		data.repaired = true
		data.repairerid = inst.repairerid
		data.repairerchar = inst.repairerchar
	end
end

local function OnLoad(inst, data)
    if data ~= nil and data.repaired then
        inst.components.workable:SetWorkLeft(MAXHITS)
        OnRepaired(inst)
		inst.repairerid = data.repairerid
		inst.repairerchar = data.repairerchar
    end
end

local function YOTH_OnLootPrefabSpawned(inst, data)
    local loot = data ~= nil and data.loot
    if loot then
        if loot.prefab == "redpouch_yoth" and loot.components.unwrappable then
            local items = { SpawnPrefab("lucky_goldnugget") }

            loot.components.unwrappable:WrapItems(items)

            for k, item in pairs(items) do
                item:Remove()
            end
            items = nil
        end
    end
end

local function BasePile(style)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1.2)

    inst:AddTag("chess")
    inst:AddTag("mech")

    inst.MiniMapEntity:SetIcon("chessjunk.png")

    inst.style = style

    inst.AnimState:SetBank("chessmonster_ruins")
    inst.AnimState:SetBuild("chessmonster_ruins")
    inst.AnimState:PlayAnimation("idle"..inst.style)

    inst.scrapbook_proxy = "chessjunk"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_deps = { "bishop_nightmare", "rook_nightmare", "knight_nightmare" }
    inst.scrapbook_anim = "idle1"
    inst.scrapbook_speechname = "chessjunk1"

    inst:AddComponent("inspectable")

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("chess_junk")
    if IsSpecialEventActive(SPECIAL_EVENTS.YOTH) and (style == 1 or style == 2) then
        inst.components.lootdropper:AddChanceLoot("redpouch_yoth", style == 1 and 0.66 or 1.0)
        inst:ListenForEvent("loot_prefab_spawned", YOTH_OnLootPrefabSpawned)
    end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(MAXHITS/2)
    inst.components.workable:SetMaxWork(MAXHITS)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    inst:AddComponent("repairable")
    inst.components.repairable.repairmaterial = MATERIALS.GEARS
    inst.components.repairable.onrepaired = OnRepaired

    MakeHauntableWork(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

local function Junk(style)
    return function()
        return BasePile(style)
    end
end

local function RandomJunkFn()
    local inst = BasePile(math.random(3))
    inst:SetPrefabName("chessjunk"..inst.style)
	return inst
end

local function onruinsrespawn(inst, respawner)
	if not respawner:IsAsleep() then
		inst.AnimState:PlayAnimation("hit"..tostring(inst.style))
		inst.AnimState:PushAnimation("idle"..tostring(inst.style), false)

		local fx = SpawnPrefab("small_puff")
		fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
		fx.Transform:SetScale(1.5, 1.5, 1.5)
	end
end

return Prefab("chessjunk", RandomJunkFn, assets, prefabs),
	Prefab("chessjunk1", Junk(1), assets, prefabs),
    Prefab("chessjunk2", Junk(2), assets, prefabs),
    Prefab("chessjunk3", Junk(3), assets, prefabs),
    RuinsRespawner.Inst("chessjunk", onruinsrespawn), RuinsRespawner.WorldGen("chessjunk", onruinsrespawn)
