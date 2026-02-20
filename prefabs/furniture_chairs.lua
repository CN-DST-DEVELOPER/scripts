local prefabs =
{
	"collapse_small",
}

local function _PlayAnimation(inst, anim, loop)
	inst.AnimState:PlayAnimation(anim, loop)
	if inst.back then
		inst.back.AnimState:PlayAnimation(anim, loop)
	end
end

local function _PushAnimation(inst, anim, loop)
	inst.AnimState:PushAnimation(anim, loop)
	if inst.back then
		inst.back.AnimState:PushAnimation(anim, loop)
	end
end

local function _AnimSetTime(inst, t)
	inst.AnimState:SetTime(t)
	if inst.back then
		inst.back.AnimState:SetTime(t)
	end
end

local function OnHit(inst, worker, workleft, numworks)
	if not inst:HasTag("burnt") then
		_PlayAnimation(inst, "hit")
		_PushAnimation(inst, "idle", false)
		inst.components.sittable:EjectOccupier()
	end
end

local function OnHammered(inst, worker)
	local collapse_fx = SpawnPrefab("collapse_small")
	collapse_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
	collapse_fx:SetMaterial(inst._burnable and "wood" or "stone")

	inst.components.lootdropper:DropLoot()

	inst:Remove()
end

local function OnBuilt(inst, data)
	_PlayAnimation(inst, "place")
	_PushAnimation(inst, "idle", false)

	inst.SoundEmitter:PlaySound("dontstarve/common/repair_stonefurniture")

	local builder = (data and data.builder) or nil
	TheWorld:PushEvent("CHEVO_makechair", {target = inst, doer = builder})
end

local function CancelSitterAnimOver(inst)
	if inst._onsitteranimover then
		inst:RemoveEventCallback("animover", inst._onsitteranimover, inst._onsitteranimover_sitter)
		inst._onsitteranimover = nil
		inst._onsitteranimover_sitter = nil
	end
end

local ROCKING_ANIMS = { "rocking", "rocking_smile", "rocking_hat" }
local function IsSitterRockingPre(inst, sitter)
	for i, v in ipairs(ROCKING_ANIMS) do
		if sitter.AnimState:IsCurrentAnimation(v.."_pre") then
			return true
		end
	end

	return false
end

local function IsSitterRockingLoop(inst, sitter)
	for i, v in ipairs(ROCKING_ANIMS) do
		if sitter.AnimState:IsCurrentAnimation(v.."_loop") then
			return true
		end
	end

	return false
end

local function OnSyncChairRocking(inst, sitter)
	--sittable is removed when burnt
	if inst.components.sittable and inst.components.sittable:IsOccupiedBy(sitter) then
		if IsSitterRockingPre(inst, sitter) then
			_PlayAnimation(inst, "rocking_pre")
			local t = sitter.AnimState:GetCurrentAnimationTime()
			local len = inst.AnimState:GetCurrentAnimationLength()
			if t < len then
				_AnimSetTime(inst, t)
				_PushAnimation(inst, "rocking_loop")
			else
				_PlayAnimation(inst, "rocking_loop", true)
				_AnimSetTime(inst, t - len)
			end
			CancelSitterAnimOver(inst)
		elseif IsSitterRockingLoop(inst, sitter) then
			_PlayAnimation(inst, "rocking_loop", true)
			_AnimSetTime(inst, sitter.AnimState:GetCurrentAnimationTime())
			CancelSitterAnimOver(inst)
		elseif sitter.AnimState:IsCurrentAnimation("sit_off") then
			CancelSitterAnimOver(inst)
		elseif sitter.AnimState:IsCurrentAnimation("sit_jump_off") then
			_PlayAnimation(inst, "rocking_pst")
			_PushAnimation(inst, "idle", false)
			CancelSitterAnimOver(inst)
		else
			if sitter.AnimState:IsCurrentAnimation("sit_loop_pre") then
				_PlayAnimation(inst, "rocking_pst")
				_PushAnimation(inst, "idle", false)
			elseif inst.AnimState:IsCurrentAnimation("rocking_pre") or
				inst.AnimState:IsCurrentAnimation("rocking_loop") or
				sitter.AnimState:IsCurrentAnimation("sit_item_out") or
				sitter.AnimState:IsCurrentAnimation("sit_item_hat") then
				_PlayAnimation(inst, "idle")
			end
			if sitter ~= inst._onsitteranimover_sitter then
				CancelSitterAnimOver(inst)
				inst._onsitteranimover = function(sitter) OnSyncChairRocking(inst, sitter) end
				inst._onsitteranimover_sitter = sitter
				inst:ListenForEvent("animover", inst._onsitteranimover, sitter)
			end
		end
	end
end

local function OnBecomeSittable(inst)
	--reset rocking chair anim
	if inst.AnimState:IsCurrentAnimation("rocking_loop") then
		_PlayAnimation(inst, "rocking_pst")
		_PushAnimation(inst, "idle", false)
	elseif inst.AnimState:IsCurrentAnimation("rocking_pre") then
		_PlayAnimation(inst, "idle")
	end
	CancelSitterAnimOver(inst)
end

local function OnChairBurnt(inst)
	DefaultBurntStructureFn(inst)

	if inst.back ~= nil then
		inst.back.AnimState:PlayAnimation("burnt")
	end

	CancelSitterAnimOver(inst)
	inst:RemoveEventCallback("ms_sync_chair_rocking", OnSyncChairRocking)
	inst:RemoveComponent("sittable")
end

local function GetStatus(inst)
	return (inst:HasTag("burnt") and "BURNT") or
		(inst.components.sittable:IsOccupied() and "OCCUPIED") or
		nil
end

local function OnSave(inst, data)
	local burnable = inst.components.burnable
	if (burnable and burnable:IsBurning()) or inst:HasTag("burnt") then
		data.burnt = true
	end
end

local function OnLoad(inst, data)
	if data then
		if data.burnt then
			inst.components.burnable.onburnt(inst)
		end
	end
end

local function AddChair(ret, name, bank, build, facings, hasback, deploy_smart_radius, burnable, inspection_override, kitdata)
	local assets =
	{
		Asset("ANIM", "anim/"..build..".zip"),
	}
	if bank ~= build then
		table.insert(assets, Asset("ANIM", "anim/"..bank..".zip"))
	end

	local _prefabs = shallowcopy(prefabs)

	local placername = name.."_placer"
	local isrocking = string.sub(name, -8) == "_rocking"

	if hasback then
		local function OnBackReplicated(inst)
			local parent = inst.entity:GetParent()
			if parent ~= nil and (parent.prefab == inst.prefab:sub(1, -6)) then
				parent.highlightchildren = { inst }
			end
		end

		local function backfn()
			local inst = CreateEntity()

			inst.entity:AddTransform()
			inst.entity:AddAnimState()
			inst.entity:AddNetwork()

			if facings == 0 then
				inst.Transform:SetNoFaced()
			elseif facings == 8 then
				inst.Transform:SetEightFaced()
			else
				inst.Transform:SetFourFaced()
			end

			inst:AddTag("FX")

			inst.AnimState:SetBank(bank)
			inst.AnimState:SetBuild(build)
			inst.AnimState:PlayAnimation("idle")
			inst.AnimState:SetFinalOffset(3)
			inst.AnimState:Hide("parts")

			inst.entity:SetPristine()

			if not TheWorld.ismastersim then
				inst.OnEntityReplicated = OnBackReplicated

				return inst
			end

			inst.persists = false

			return inst
		end

		table.insert(ret, Prefab(name.."_back", backfn, assets))
		table.insert(_prefabs, name.."_back")
	end

	if kitdata then
		local tags = {}
		local burnable_data = kitdata.fuelvalue ~= nil and { fuelvalue = kitdata.fuelvalue } or nil
		local deployable_data =
		{
			deployspacing = kitdata.deployspacing or DEPLOYSPACING.DEFAULT,
			common_postinit = function(inst)
				inst.overridedeployplacername = placername
			end,
		}
		table.insert(ret, MakeDeployableKitItem(name.."_item", name, bank, build, "kit", assets, kitdata.floatable_data, tags, burnable_data, deployable_data))
		table.insert(_prefabs, name.."_item")
	end

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		inst:SetDeploySmartRadius(deploy_smart_radius) --recipe min_spacing/2

		MakeObstaclePhysics(inst, 0.25)

		if facings == 0 then
			inst.Transform:SetNoFaced()
		elseif facings == 8 then
			inst.Transform:SetEightFaced()
		else
			inst.Transform:SetFourFaced()
		end

		inst:AddTag("structure")
		if isrocking then
			inst:AddTag("limited_chair")
			inst:AddTag("rocking_chair")
			if name == "yoth_chair_rocking" then
				inst:AddTag("yeehaw")
			end
		else
			inst:AddTag("faced_chair")
			inst:AddTag("rotatableobject")
		end

		inst.AnimState:SetBank(bank)
		inst.AnimState:SetBuild(build)
		inst.AnimState:PlayAnimation("idle")
		inst.AnimState:SetFinalOffset(-1)
		inst.AnimState:Hide("back_over")

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst._burnable = burnable

		if hasback then
			inst.back = SpawnPrefab(name.."_back")
			inst.back.entity:SetParent(inst.entity)
			inst.highlightchildren = { inst.back }
		end

		inst.scrapbook_facing  = FACING_DOWN

		inst:AddComponent("inspectable")
        inst.components.inspectable.nameoverride = inspection_override
        inst.components.inspectable.getstatus = GetStatus

		inst:AddComponent("lootdropper")

		inst:AddComponent("sittable")

		inst:AddComponent("savedrotation")
		inst.components.savedrotation.dodelayedpostpassapply = true

		inst:AddComponent("workable")
		inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
		inst.components.workable:SetWorkLeft(1)
		inst.components.workable:SetOnWorkCallback(OnHit)
		inst.components.workable:SetOnFinishCallback(OnHammered)

		inst:ListenForEvent("onbuilt", OnBuilt)

		if isrocking then
			inst:ListenForEvent("ms_sync_chair_rocking", OnSyncChairRocking)
			inst:ListenForEvent("becomesittable", OnBecomeSittable)
		end

		MakeHauntableWork(inst)

		if burnable then
			MakeSmallBurnable(inst, nil, nil, true)
			inst.components.burnable:SetOnBurntFn(OnChairBurnt)
			MakeSmallPropagator(inst)
		end

		inst.OnLoad = OnLoad
		inst.OnSave = OnSave

		return inst
	end

	table.insert(ret, Prefab(name, fn, assets, _prefabs))
	table.insert(ret, MakePlacer(placername, bank, build, "idle", nil, nil, nil, nil, 15, "four"))
end

local ret = {}

--NOTE: -"back" is the back of the chair, not a layer.
--      -in up-facing it would be layered in front.
--      -for rocking chairs, this is used for the front layer arm of the chair.
--
--       ret,	name,					bank,					build,			  facings,	back,	dep_r,	burn,	inspection_override,	kit data
AddChair(ret,	"wood_chair",			"wood_chair",			"wood_chair_chair",		4,	true,	0.875,	true,	"WOOD_CHAIR",			nil	)
AddChair(ret,	"wood_stool",			"wood_stool",			"wood_stool",			0,	false,	0.875,	true,	"WOOD_CHAIR",			nil	)
AddChair(ret,	"stone_chair",			"wood_chair",			"stone_chair",			4,	true,	0.875,	false,	"STONE_CHAIR",			nil	)
AddChair(ret,	"stone_stool",			"wood_stool",			"stone_chair_stool",	4,	false,	0.875,	false,	"STONE_CHAIR", 			nil	)
AddChair(ret,	"hermit_chair_rocking",	"hermit_chair_rocking",	"hermit_chair_rocking",	0,	true,	1,		true,	"WOOD_CHAIR",			nil	)
AddChair(ret,	"yoth_chair_rocking",	"yoth_chair_rocking",	"yoth_chair_rocking",	0,	true,	1,		true,	"WOOD_CHAIR",			{ deployspacing = DEPLOYSPACING.DEFAULT, fuelvalue = TUNING.LARGE_FUEL, floatable_data = {}, }	)

return unpack(ret)
