local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

    return inst
end

return Prefab("wagdrone_spot_marker", fn)