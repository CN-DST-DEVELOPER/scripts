local assets =
{
	Asset("ANIM", "anim/pillar_vault_deep.zip"),
}

local prefabs =
{
	"vaultrelic_bowl",
	"vaultrelic_vase",
	"vaultrelic_planter",
}

local function CreateBottom()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false
	inst:AddTag("decor")
	inst:AddTag("NOCLICK")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("pillar_vault")
	inst.AnimState:SetBuild("pillar_vault_deep")
	inst.AnimState:PlayAnimation("idle_lower")
	inst.AnimState:SetLayer(LAYER_BELOW_GROUND)

	return inst
end

local function MakeCapped(inst, var)
	inst.broken = nil
	if var == 2 then
		inst.capped = 2
		inst.AnimState:PlayAnimation("idle_upper_capped_2")
	else
		inst.capped = 1
		inst.AnimState:PlayAnimation("idle_upper_capped")
	end
	return inst
end

local function MakeBroken(inst, broken)
	if broken then
		inst.capped = nil
		inst.broken = 1
		inst.AnimState:PlayAnimation("idle_upper_broken")
	elseif inst.broken then
		inst.broken = nil
		inst.AnimState:PlayAnimation("idle_upper")
	end
	return inst
end

local _nextrelic

local function AttachRelic(inst)
	if math.random() < 0.4 then
		if _nextrelic == nil then
			_nextrelic = { "vaultrelic_bowl", "vaultrelic_vase", "vaultrelic_planter" }
			--shuffle
			for i = 1, #_nextrelic - 1 do
				local rnd = math.random(i, #_nextrelic)
				if rnd ~= i then
					local tmp = _nextrelic[i]
					_nextrelic[i] = _nextrelic[rnd]
					_nextrelic[rnd] = tmp
				end
			end
		end
		local rnd = math.random()
		rnd = math.clamp(math.ceil(rnd * rnd * 3), 1, 3)
		rnd = table.remove(_nextrelic, rnd)
		table.insert(_nextrelic, rnd)
		local relic = SpawnPrefab(rnd)
		relic:SetVariation(math.random() < 0.7 and math.random(3) or math.random(4, 6)) --lower chance for broken variations
		relic:AttachToVaultPillar(inst)
	end
	return inst
end

local function OnSave(inst, data)
	data.capped = inst.capped
	data.broken = inst.broken
end

local function OnLoad(inst, data)--, ents)
	if data then
		if data.capped then
			inst:MakeCapped(data.capped)
		elseif data.broken then
			inst:MakeBroken(true)
        elseif data.random then -- Note: this is set by world gen.
            if math.random() < 0.5 then
                inst:MakeBroken(true)
            end
        end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("pillar_vault")
	inst.AnimState:SetBuild("pillar_vault_deep")
	inst.AnimState:PlayAnimation("idle_upper")
	inst.AnimState:SetFinalOffset(-1)

	--Not using NOCLICK because we do want to block mouse
	--Some actions will highlight targets even if not a valid action:
	--  "nomagic" blocks SPELLCAST (e.g. reskin_tool)
	--  "nohighlight" blocks complexprojectile (e.g. bombs)
	inst:AddTag("decor")
	inst:AddTag("nomagic")
	inst:AddTag("nohighlight")

	if not TheNet:IsDedicated() then
		CreateBottom().entity:SetParent(inst.entity)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.MakeCapped = MakeCapped
	inst.MakeBroken = MakeBroken
	inst.AttachRelic = AttachRelic
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("vault_pillar", fn, assets)
