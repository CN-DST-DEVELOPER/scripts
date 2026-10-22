local assets =
{
	Asset("ANIM", "anim/mapscroll.zip"),
	Asset("INV_IMAGE", "mapscroll"),
}

local function rifts5_SetKillTime(inst, killtime, prefabname)
	inst.killtime = math.floor(killtime + 0.5)
	inst.boss = prefabname

	local msg = prefabname and STRINGS.TEMP_BETA_MSG.RIFTS5_BASIC_NEW or STRINGS.TEMP_BETA_MSG.RIFTS5_BASIC
	msg = msg.."\n"..subfmt(STRINGS.TEMP_BETA_MSG.RIFTS5_KILLTIME_FMT, { name = STRINGS.NAMES[string.upper(prefabname or "wagboss_robot_possessed")], time = tostring(inst.killtime) })
	inst.components.inspectable:SetDescription(msg)
end

local function rifts8_SetKillTime(inst, killtime, prefabname)
	inst.killtime = math.floor(killtime + 0.5)
	inst.boss = prefabname

	local msg = STRINGS.TEMP_BETA_MSG.RIFTS8_BASIC
	msg = msg.."\n"..subfmt(STRINGS.TEMP_BETA_MSG.RIFTS8_KILLTIME_FMT, { name = STRINGS.NAMES[string.upper(prefabname or "charlie_boss")], time = tostring(inst.killtime) })
	inst.components.inspectable:SetDescription(msg)
end

local function OnSave(inst, data)
	data.ver = inst.ver

	--rifts 5
	data.killtime = inst.killtime
	data.boss = inst.boss
end

local function OnLoad(inst, data)--, ents)
	if data then
		if data.ver == "rifts8" then
			if data.killtime then
				rifts8_SetKillTime(inst, data.killtime, data.boss)
			else
				inst.components.inspectable:SetDescription(STRINGS.TEMP_BETA_MSG.RIFTS8_BASIC)
			end
		elseif data.ver == "rifts7" then
			inst.components.inspectable:SetDescription(subfmt(STRINGS.TEMP_BETA_MSG.RIFTS7_FMT, { name = STRINGS.NAMES.VAULT_PILLAR_GUARD }))
		elseif data.ver == "rifts6" then
			inst.components.inspectable:SetDescription(STRINGS.TEMP_BETA_MSG.RIFTS6_BASIC)
		else --rifts5
			if data.killtime then
				rifts5_SetKillTime(inst, data.killtime, data.boss)
			else
				inst.components.inspectable:SetDescription(STRINGS.TEMP_BETA_MSG.RIFTS5_BASIC_NEW)
			end
		end
	else
		--backward compatible
		inst.components.inspectable:SetDescription(STRINGS.TEMP_BETA_MSG.RIFTS5_BASIC_NEW)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("mapscroll")
	inst.AnimState:SetBuild("mapscroll")
	inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "paper"

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:ChangeImageName("mapscroll")

	inst:AddComponent("inspectable")
	inst.components.inspectable:SetDescription(STRINGS.TEMP_BETA_MSG.RIFTS8_BASIC)

	inst:AddComponent("erasablepaper")

	inst:AddComponent("fuel")
	inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

	MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
	MakeSmallPropagator(inst)

	MakeHauntableLaunch(inst)

	inst.ver = "rifts8"

	inst.SetKillTime = rifts8_SetKillTime
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("temp_beta_msg", fn, assets)
