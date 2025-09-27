local assets =
{
    Asset("ANIM", "anim/charlie_heckler2.zip"),    
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddFollower()

    inst.Transform:SetSixFaced()

    inst.AnimState:SetBank("charlie_heckler2")
    inst.AnimState:SetBuild("charlie_heckler2")
    inst.AnimState:PlayAnimation("idle")

    inst:AddComponent("talker")
    inst.components.talker.fontsize = 30
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.colour = Vector3(163/255, 212/255, 158/255)
    inst.components.talker.offset = Vector3(0, -80, 0)
    inst.components.talker:MakeChatter()

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stageactor")

    inst:AddComponent("inspectable")

    inst:AddComponent("named")

    inst:SetStateGraph("SGcharlie_heckler")

    inst.persists = false

    return inst
end

return Prefab("charlie_heckler", fn, assets)