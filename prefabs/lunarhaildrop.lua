local assets =
{
    Asset("ANIM", "anim/lunarhaildrop.zip"),
}

local function PlayPstAnim(inst, anim)
	inst.AnimState:PlayAnimation(anim)
end

local function OnAnimOver(inst)
	if inst.AnimState:IsCurrentAnimation("anim") then
		if inst.delay == nil then
			inst.AnimState:PlayAnimation("anim_pst")
		else
			inst.Transform:SetRotation(90 - TheCamera.headingtarget)
			inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
			inst.AnimState:SetLayer(LAYER_BACKGROUND)
			inst.AnimState:SetSortOrder(3)
			inst.AnimState:PlayAnimation("ground"..tostring(math.random(2)))
		end
	elseif inst.AnimState:IsCurrentAnimation("ground1") then
		inst:DoTaskInTime(inst.delay, PlayPstAnim, "ground1_pst")
	elseif inst.AnimState:IsCurrentAnimation("ground2") then
		inst:DoTaskInTime(inst.delay, PlayPstAnim, "ground2_pst")
	else
		inst:Remove()
	end
end

local function fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBuild("lunarhaildrop")
    inst.AnimState:SetBank("lunarhaildrop")
    inst.AnimState:PlayAnimation("anim")
	if math.random() < 0.5 then
		inst.AnimState:SetScale(-1, 1)
	end

	inst:ListenForEvent("animover", OnAnimOver)

    return inst
end

return Prefab("lunarhaildrop", fn, assets)