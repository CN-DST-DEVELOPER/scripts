require "prefabutil"

local prefabs =
{
    "collapse_small",
    "sisturn_moon_petal_fx",
}

local assets =
{
    Asset("ANIM", "anim/sisturn.zip"),
	Asset("ANIM", "anim/ui_chest_2x2.zip"),
}

local FLOWER_LAYERS =
{
	"flower1_roof",
	"flower2_roof",
	"flower1",
	"flower2",
}

-- Skill tree reactions
local function ConfigureSkillTreeUpgrades(inst, builder)
	local skilltreeupdater = (builder and builder.components.skilltreeupdater) or nil

	local petal_preserve = (skilltreeupdater and skilltreeupdater:IsActivated("wendy_sisturn_1")) or nil
	local sanityaura_size = (skilltreeupdater and skilltreeupdater:IsActivated("wendy_sisturn_2") and TUNING.SANITYAURA_MED) or nil

	local dirty = (inst._petal_preserve ~= petal_preserve) or (inst._sanityaura_size ~= sanityaura_size)

	inst._petal_preserve = petal_preserve
	inst._sanityaura_size = sanityaura_size

	return dirty
end


local function ApplySkillModifiers(inst)
	inst.components.preserver:SetPerishRateMultiplier(inst._petal_preserve and TUNING.WENDY_SISTURN_PETAL_PRESRVE or 1) 

	if inst.components.sanityaura ~= nil then
		inst.components.sanityaura.aura = inst._sanityaura_size or TUNING.SANITYAURA_SMALL
	end
end

--
local function IsFullOfFlowers(inst)
	return inst.components.container ~= nil and inst.components.container:IsFull()
end

local function onhammered(inst)
    inst.components.lootdropper:DropLoot()
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker, workleft)
    if workleft > 0 and not inst:HasTag("burnt") then
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/hit")
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle")

		if inst.components.container ~= nil then
			inst.components.container:DropEverything()
		end
    end
end

local function on_built(inst, data)
    inst.AnimState:PlayAnimation("place")
    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/hit")

	if not data.builder then return end
	inst._builder_id = data.builder.userid
	if ConfigureSkillTreeUpgrades(inst, data.builder) then
		ApplySkillModifiers(inst)
	end
end

local function getsisturnfeel(inst)
	local evil = inst.components.container:FindItems(
	function(item)
	if item.prefab == "petals_evil" then 
			return true 
		end 
	end)


	local blossom = inst.components.container:FindItems(
	function(item)
		if item.prefab == "moon_tree_blossom" then 
				return true 
		end 
	end)	

	if #evil > 3 then
		return "EVIL"
	elseif #blossom > 3 then
		return "BLOSSOM"
	else
		return "NORMAL"
	end
end

local function update_sanityaura(inst)
	if IsFullOfFlowers(inst) then
		if not inst.components.sanityaura then
			inst:AddComponent("sanityaura")
		end
		if getsisturnfeel(inst) == "EVIL" then
			inst.components.sanityaura.aura = (inst._sanityaura_size or TUNING.SANITYAURA_SMALL) *-1			
		else			
			inst.components.sanityaura.aura = inst._sanityaura_size or TUNING.SANITYAURA_SMALL			
		end

	elseif inst.components.sanityaura ~= nil then
		inst:RemoveComponent("sanityaura")
	end
end

local function update_idle_anim(inst)
    if inst:HasTag("burnt") then
		return
	end

	if IsFullOfFlowers(inst) then
		inst.AnimState:PlayAnimation("on_pre")
		inst.AnimState:PushAnimation("on", true)
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/sisturn/LP","sisturn_on")
	else
		inst.AnimState:PlayAnimation("on_pst")
		inst.AnimState:PushAnimation("idle", false)
        inst.SoundEmitter:KillSound("sisturn_on")
	end
end

local function update_abigail_status(inst)
   local is_full = IsFullOfFlowers(inst)
   local blossoms = getsisturnfeel(inst) == "BLOSSOM"
   if is_full and blossoms then
   		TheWorld:PushEvent("moon_blossom_sisturn",{status=true})

   		if not inst.lune_fx then
   			inst.lune_fx = SpawnPrefab("sisturn_moon_petal_fx")
   			inst:AddChild(inst.lune_fx)
   		else
   			inst.lune_fx.done = nil
   			if inst.lune_fx.AnimState:IsCurrentAnimation("lunar_fx_pst") then
   				inst.lune_fx.SoundEmitter:KillSound("loop")
   				inst.lune_fx.SoundEmitter:PlaySound("meta5/wendy/sisturn_moonblossom_LP","loop")
   				inst.lune_fx.AnimState:PlayAnimation("lunar_fx_pre")
    			inst.lune_fx.AnimState:PushAnimation("lunar_fx_loop")
   			end
   		end   
   else
   		TheWorld:PushEvent("moon_blossom_sisturn",{status=nil})
   		if inst.lune_fx then
   			inst.lune_fx.done = true   			
   		end
   end
end

local function remove_decor(inst, data)
    if data ~= nil and data.slot ~= nil and FLOWER_LAYERS[data.slot] then
		inst.AnimState:Hide(FLOWER_LAYERS[data.slot])
		inst.SoundEmitter:PlaySound("meta5/wendy/sisturn_petals_add_remove")
    end
	update_sanityaura(inst)
	update_idle_anim(inst)
	update_abigail_status(inst)

	TheWorld:PushEvent("ms_updatesisturnstate", {inst = inst, is_active = IsFullOfFlowers(inst)})
end

local function UpdateFlowerDecor(inst)
    if not inst:HasTag("burnt") then
        for slot, layer in ipairs(FLOWER_LAYERS) do
            local item = inst.components.container.slots[slot]
            if item then
                local symbolname
                if item.prefab == "petals_evil" then
                    symbolname = "flowers_evil"
                elseif item.prefab == "moon_tree_blossom" then
                    symbolname = "flowers_lunar"
                end
                if symbolname then
                    local skin_build = inst:GetSkinBuild()
                    if not skin_build then
                        inst.AnimState:OverrideSymbol("flowers_0" .. slot, "sisturn", symbolname)
                    else
                        inst.AnimState:OverrideSkinSymbol("flowers_0" .. slot, skin_build, symbolname)
                    end
                else
                    inst.AnimState:ClearOverrideSymbol("flowers_0" .. slot)
                end
            end
        end
    end
end

local function add_decor(inst, data)
    if data ~= nil and data.slot ~= nil and FLOWER_LAYERS[data.slot] and not inst:HasTag("burnt") then
        inst.AnimState:Show(FLOWER_LAYERS[data.slot])
        inst.SoundEmitter:PlaySound("meta5/wendy/sisturn_petals_add_remove")
        inst:UpdateFlowerDecor()
    end


	update_sanityaura(inst)
	update_idle_anim(inst)
	update_abigail_status(inst)

	local is_full = IsFullOfFlowers(inst)
	TheWorld:PushEvent("ms_updatesisturnstate", {inst = inst, is_active = is_full})

	local doer = (is_full and inst.components.container ~= nil and inst.components.container.currentuser) or nil
	if doer ~= nil and doer.components.talker ~= nil and doer:HasTag("ghostlyfriend") then

		if getsisturnfeel(inst) == "EVIL" then
			doer.components.talker:Say(GetString(doer, "ANNOUNCE_SISTURN_FULL_EVIL"), nil, nil, true)
		elseif getsisturnfeel(inst) == "BLOSSOM" then
			doer.components.talker:Say(GetString(doer, "ANNOUNCE_SISTURN_FULL_BLOSSOM"), nil, nil, true)
		else
			doer.components.talker:Say(GetString(doer, "ANNOUNCE_SISTURN_FULL"), nil, nil, true)
		end
	end
end

local function getstatus(inst)
	local container = inst.components.container
	local num_decor = (container ~= nil and container:NumItems()) or 0
	local num_slots = (container ~= nil and container.numslots) or 1
	return num_decor >= num_slots and  getsisturnfeel(inst) == "EVIL" and "LOTS_OF_FLOWERS_EVIL"
			or num_decor >= num_slots and  getsisturnfeel(inst) == "BLOSSOM" and "LOTS_OF_FLOWERS_BLOSSOM"
			or num_decor >= num_slots and "LOTS_OF_FLOWERS"	
			or num_decor > 0 and "SOME_FLOWERS"
			or nil
end

local function OnSave(inst, data)
	if inst:HasTag("burnt") or (inst.components.burnable and inst.components.burnable:IsBurning()) then
		data.burnt = true
	end

	data.preserve_rate = inst._preserve_rate
	data.sanityaura_size = inst._sanityaura_size
	data.builder_id = inst._builder_id
	data.petal_preserve = inst._petal_preserve
end

local function OnLoad(inst, data)
	if data then
		if data.burnt and inst.components.burnable then
			inst.components.burnable.onburnt(inst)
		else
			inst._builder_id = data.builder_id
			inst._preserve_rate = data.preserve_rate
			inst._sanityaura_size = data.sanityaura_size
			inst._petal_preserve = data.petal_preserve

			ApplySkillModifiers(inst)
		end
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1) --recipe min_spacing/2
    MakeObstaclePhysics(inst, .5)

    inst:AddTag("structure")

    inst.AnimState:SetBank("sisturn")
    inst.AnimState:SetBuild("sisturn")
    inst.AnimState:PlayAnimation("idle")
	for _, layer_name in ipairs(FLOWER_LAYERS) do
		inst.AnimState:Hide(layer_name)
	end

	inst.MiniMapEntity:SetIcon("sisturn.png")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	--
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("sisturn")

	--
    inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = getstatus

	--
    inst:AddComponent("lootdropper")

    --

	inst:AddComponent("preserver")

	--
    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(4)
    workable:SetOnFinishCallback(onhammered)
    workable:SetOnWorkCallback(onhit)

	--
    MakeSmallBurnable(inst, nil, nil, true)
    MakeSmallPropagator(inst)

	--
    MakeHauntableWork(inst)
    MakeSnowCovered(inst)

	--
    inst.UpdateFlowerDecor = UpdateFlowerDecor
    inst:ListenForEvent("itemget", add_decor)
    inst:ListenForEvent("itemlose", remove_decor)
    inst:ListenForEvent("onbuilt", on_built)

	inst.getsisturnfeel = getsisturnfeel

	--
	if not TheWorld.components.sisturnregistry then
		TheWorld:AddComponent("sisturnregistry")
	end
	TheWorld.components.sisturnregistry:Register(inst)

	--
	inst:ListenForEvent("wendy_sisturnskillchanged", function(_, user)
		if user.userid == inst._builder_id and not inst:HasTag("burnt")
				and ConfigureSkillTreeUpgrades(inst, user) then
			ApplySkillModifiers(inst)
		end
	end, TheWorld)

	--
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	--
    return inst
end

local function fxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddFollower()
    inst.entity:AddSoundEmitter()

    inst:AddTag("FX")

    inst.AnimState:SetBank("sisturn")
    inst.AnimState:SetBuild("sisturn")
    inst.AnimState:PlayAnimation("lunar_fx_pre")
    inst.AnimState:PushAnimation("lunar_fx_loop")

    inst.SoundEmitter:PlaySound("meta5/wendy/sisturn_moonblossom_LP","loop")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:ListenForEvent("animover", function() 
		if inst.done and inst.AnimState:IsCurrentAnimation("lunar_fx_pst") then
			
    		if inst.parent then
    			inst.parent.lune_fx = nil
    		end
    		inst:Remove()
    	elseif inst.AnimState:IsCurrentAnimation("lunar_fx_loop") then
    		if inst.done then
    			inst.AnimState:PlayAnimation("lunar_fx_pst")
    			inst.SoundEmitter:KillSound("loop")
				inst.SoundEmitter:PlaySound("meta5/wendy/sisturn_moonblossom_pst")
    		else
    			inst.AnimState:PlayAnimation("lunar_fx_loop")
    		end
    	end

	end)
    
    inst.persists = false

    return inst
end

return Prefab("sisturn", fn, assets, prefabs),
	   Prefab("sisturn_moon_petal_fx", fxfn, assets, prefabs),
       MakePlacer("sisturn_placer", "sisturn", "sisturn", "placer")
