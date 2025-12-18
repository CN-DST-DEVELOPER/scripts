local assets =
{
	Asset("ANIM", "anim/hermithouse_ornament_shell.zip"),
}

local prefabs =
{
	"hermithouse_ornament_fx",
}

--NOTE: "hermithouse_ornament_fx" is used also by:
--      -hermithouse_laundry
--      -wagstaff_items

local function UnlinkHighlight(inst)
	if inst.highlightparent.highlightchildren then
		table.removearrayvalue(inst.highlightparent.highlightchildren, inst)
	end
end

local function LinkHighlight(inst, parent)
	if parent.highlightchildren == nil then
		parent.highlightchildren = { inst }
	else
		table.insert(parent.highlightchildren, inst)
	end
	inst.highlightparent = parent
	inst.OnRemoveEntity = UnlinkHighlight
end

local function OnEntityReplicated(inst)
	local parent = inst.entity:GetParent()
	if parent then
		LinkHighlight(inst, parent)
	end
end

local function dosound(inst, soundname, loopid)
	if inst.soundpath then
		inst.SoundEmitter:PlaySound(inst.soundpath..soundname, loopid)
	end
end

local function tryplacesound(inst)
	if inst.AnimState:IsCurrentAnimation("place") then
		if inst.soundpath then
			inst.SoundEmitter:PlaySound(inst.soundpath.."place")
		else
			inst.SoundEmitter:PlaySound("hookline_2/characters/hermit/house/decor/stocking_place")
		end
	end
end

local function dowind(inst)
	if inst.AnimState:IsCurrentAnimation("idle_loop") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		inst.AnimState:PlayAnimation("idle_loop")
		inst.AnimState:SetTime(t)
		if inst.soundpath then
			inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() - t, dosound, "wind")
		end
		inst.AnimState:PushAnimation("wind")
		inst.AnimState:PushAnimation("idle_loop")
	end
end

local function AttachToParent(inst, parent)
	inst.entity:SetParent(parent.entity)
	if POPULATING or parent:IsAsleep() or parent:GetTimeAlive() == 0 then
		--inst.AnimState:PlayAnimation("idle_loop", true)
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	else
		inst.AnimState:PlayAnimation("place")
		inst.AnimState:PushAnimation("idle_loop")
		inst:DoTaskInTime(0, tryplacesound)
	end
	dosound(inst, "idle_LP", "loop")
	if not TheNet:IsDedicated() then
		LinkHighlight(inst, parent)
	end
	return inst
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.AnimState:SetBank("hermithouse_ornament_shell")
	inst.AnimState:SetBuild("hermithouse_ornament_shell")
	inst.AnimState:PlayAnimation("idle_loop", true)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst.OnEntityReplicated = OnEntityReplicated

		return inst
	end

	--inst.soundpath = nil --keep this nil on construction since other files use this fx as well

	inst.dowind = dowind
	inst.AttachToParent = AttachToParent

	inst.persists = false

	return inst
end

local function CloneAsFx(inst)
	local skin_build = inst:GetSkinBuild()
	local fx = SpawnPrefab("hermithouse_ornament_fx", skin_build, inst.skin_id)
	if not inst.skin_nosound then
		fx.soundpath = string.format("hookline_2/characters/hermit/house/decor/%s_", skin_build and string.sub(skin_build, 22) or "shell")
	end
	return fx
end

local function OnHermitHouseOrnamentSkinChanged(inst, skin_build)
	local owner = inst.components.inventoryitem.owner
	if owner and owner.RefreshDecor then
		owner:RefreshDecor(inst)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst, 0.1)

	inst:AddTag("hermithouse_ornament")
	inst:AddTag("molebait")
	inst:AddTag("cattoy")

	inst.AnimState:SetBank("hermithouse_ornament_shell")
	inst.AnimState:SetBuild("hermithouse_ornament_shell")
	inst.AnimState:PlayAnimation("grounded")

	MakeInventoryFloatable(inst, "small", 0.1, { 1.3, 1, 1 })

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

	inst:AddComponent("tradable")
	inst.components.tradable.goldvalue = TUNING.GOLD_VALUES.HERMITHOUSE_ORNAMENT

	MakeHauntableLaunch(inst)

	inst.CloneAsFx = CloneAsFx
	inst.OnHermitHouseOrnamentSkinChanged = OnHermitHouseOrnamentSkinChanged

	return inst
end

return Prefab("hermithouse_ornament", fn, assets, prefabs),
	Prefab("hermithouse_ornament_fx", fxfn)
