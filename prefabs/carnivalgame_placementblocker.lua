local function fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

	inst:AddTag("NOCLICK")
	inst:AddTag("DECOR")
	inst:AddTag("carnivalgame_part")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.persists = false

	return inst
end

local function fn_golfgame()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    --inst:AddTag("DECOR") NOTES(JBK): Intentionally not a decor so they block other things that do not filter out carnivalgame_part.
	inst:AddTag("carnivalgame_part")
    inst:AddTag("birdblocker")

    inst:AddTag("childdeployblocker") -- Permit this to be parented and also block.

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end


return Prefab("carnivalgame_placementblocker", fn),
    Prefab("carnivalgame_placementblocker_golfgame", fn_golfgame)
