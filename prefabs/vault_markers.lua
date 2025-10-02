local assets =
{
	Asset("SCRIPT", "scripts/prefabs/vaultroom_defs.lua"),
}

local prefabs =
{
	"abysspillar_minion",
	"abysspillar_trial",
	"ancient_husk",
	"archive_lockbox_dispencer",
	"lightsout_trial",
	"mask_ancient_architecthat",
	"mask_ancient_handmaidhat",
	"mask_ancient_masonhat",
	"playbill_the_vault",
	"temp_beta_msg", --#TEMP_BETA
	"vault_chandelier",
	"vault_chandelier_broken",
	"vault_chandelier_decor",
	"vault_ground_pattern_fx",
	"vault_pillar",
	"vault_rune",
	"vault_statue",
	"vault_stool",
	"vault_switch_base",
	"vault_table_round",
    "vaultcollision_lobby",
    "vaultcollision_vault",
}

local function UpdateNetvars(inst)
    if inst.updatenetvarstask ~= nil then -- Let this function repeat entry safe.
        inst.updatenetvarstask:Cancel()
        inst.updatenetvarstask = nil
    end

    local _world = TheWorld
    local vault_floor_helper = _world.net and _world.net.components.vault_floor_helper
    if not vault_floor_helper then
        inst.updatenetvarstask = inst:DoTaskInTime(0, UpdateNetvars) -- Reschedule.
        return
    end

    vault_floor_helper:TryToSetMarker(inst) -- May remove inst if it is in conflict.
end

local function OnAdd(inst)
	inst.inittask = nil
    if not TheWorld.ismastersim then
        print("Any vault marker entity should not exist on clients!", inst)
        inst:Remove()
		return
    end
    if inst.prefab == "vaultmarker_vault_center" then
        UpdateNetvars(inst)
    end
	TheWorld:PushEvent("ms_register_vault_marker", inst)
end

local function OnLoad(inst)
	if inst.inittask then
		inst.inittask:Cancel()
		OnAdd(inst)
	end
end

local function OnRemove(inst)
    TheWorld:PushEvent("ms_unregister_vault_marker", inst)
end

local function fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]

    inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

	inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
	inst.OnLoad = OnLoad
	inst:ListenForEvent("onremove", OnRemove)

    return inst
end

local function centerfn()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

	inst:AddComponent("vaultroom")

	inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
	inst.OnLoad = OnLoad
	inst:ListenForEvent("onremove", OnRemove)

    inst:DoTaskInTime(0, UpdateNetvars)

	return inst
end

return Prefab("vaultmarker_lobby_center", fn),
Prefab("vaultmarker_lobby_to_vault", fn),
Prefab("vaultmarker_lobby_to_archive", fn),
Prefab("vaultmarker_vault_center", centerfn, assets, prefabs),
Prefab("vaultmarker_vault_north", fn),
Prefab("vaultmarker_vault_east", fn),
Prefab("vaultmarker_vault_south", fn),
Prefab("vaultmarker_vault_west", fn)
