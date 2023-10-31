local assets =
{
    Asset("ANIM", "anim/nitre_smoke_fx.zip"),
}

local function OnAnimOver(inst)
	if inst.pool ~= nil and inst.pool.valid then
		inst:RemoveFromScene()
		table.insert(inst.pool.ents, inst)
	else
		inst:Remove()
	end
end

local function sizzle(inst, r)
    inst.SoundEmitter:PlaySound("rifts2/caves/acid_sizzle", nil, 0.5 + r)
end

local function RestartFx(inst)
	local r = math.random() * 0.4 + 0.1
	inst.AnimState:SetScale(r, r)
	inst.AnimState:PlayAnimation("smoke_"..math.random(3))

	inst:DoTaskInTime(0, sizzle, r)
end

local function fn()
	local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

	inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    inst.AnimState:SetBuild("nitre_smoke_fx")
    inst.AnimState:SetBank("nitre_smoke_fx")
	RestartFx(inst)

	inst:ListenForEvent("animover", OnAnimOver)

	inst.RestartFx = RestartFx

    return inst
end

return Prefab("acidraindrop", fn, assets)