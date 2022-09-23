local assets =
{
    Asset("ANIM", "anim/book_fx_wicker.zip")
}

local function MakeBookFX(anim, failanim, tint, ismount)
    local OnFail = failanim ~= nil and function(inst)
        inst.AnimState:PlayAnimation(failanim)
        inst.SoundEmitter:PlaySound("wickerbottom_rework/book_spells/fail")
    end or nil

    return function()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        inst.entity:AddSoundEmitter()

        inst:AddTag("FX")

        if ismount then
            inst.Transform:SetSixFaced()
        else
            inst.Transform:SetFourFaced()
        end

        inst.AnimState:SetBank("book_fx_wicker")
        inst.AnimState:SetBuild("book_fx_wicker")
        inst.AnimState:PlayAnimation(anim)
        --inst.AnimState:SetScale(1.5, 1, 1)
        inst.AnimState:SetFinalOffset(3)
        if tint ~= nil then
            inst.AnimState:SetMultColour(unpack(tint))
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false

        if failanim ~= nil then
            inst:ListenForEvent("fail_fx", OnFail)
        end

        --Anim is padded with extra blank frames at the end
        inst:ListenForEvent("animover", inst.Remove)

        return inst
    end
end

return Prefab("book_fx", MakeBookFX("book_fx_wicker", "book_fx_fail_wicker", { 1, 1, 1, .4 }, false), assets),
    Prefab("book_fx_mount", MakeBookFX("book_fx_wicker_mount", "book_fx_fail_wicker_mount", { 1, 1, 1, .4 }, true), assets),
    Prefab("waxwell_book_fx", MakeBookFX("book_fx_wicker", nil, { 0, 0, 0, 1 }, false), assets)
