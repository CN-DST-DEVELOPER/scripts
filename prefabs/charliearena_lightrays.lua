local assets=
{
    Asset("ANIM", "anim/charlie_arena_light_ray.zip"),
}

local function MakeLightRay(name)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst.Transform:SetEightFaced()

        inst.AnimState:SetBank("charlie_arena_light_ray")
        inst.AnimState:SetBuild("charlie_arena_light_ray")
        inst.AnimState:PlayAnimation("idle_loop", true)
        inst.AnimState:SetLightOverride(1)

        inst:AddTag("lightrays")
        inst:AddTag("ignorewalkableplatforms")
        inst:AddTag("NOBLOCK")
        inst:AddTag("NOCLICK")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("savedrotation")

        local rays = { 1, 2, 3, 4 }
        for i = 1, #rays do
            inst.AnimState:Hide("lightray"..i)
        end

        for i = 1, math.random(1) do
            local selection = math.random(1, #rays)
            inst.AnimState:Show("lightray"..rays[selection])
            table.remove(rays, selection)
        end

        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeLightRay("charliearena_lightray")
