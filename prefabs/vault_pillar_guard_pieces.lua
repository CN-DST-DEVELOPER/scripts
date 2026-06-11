local assets =
{
    Asset("ANIM", "anim/vault_pillar_guard_pieces.zip"),
}

local function MakeGolemPiece(num)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("vault_pillar_guard_pieces")
        inst.AnimState:SetBuild("vault_pillar_guard_pieces")
        inst.AnimState:PlayAnimation(tostring(num))

		MakeInventoryFloatable(inst, "small", 0.12, 1.1)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst.components.inspectable.nameoverride = "vault_pillar_guard_piece"

        inst:AddComponent("inventoryitem")

        inst:AddComponent("tradable")
        inst.components.tradable.goldvalue = TUNING.VAULT_PILLAR_GUARD_PIECE_GOLD_VALUE
		inst.components.tradable.rocktribute = TUNING.VAULT_PILLAR_GUARD_PIECE_ROCK_VALUE

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("vault_pillar_guard_piece_"..tostring(num), fn, assets)
end

local NUM_PIECES = 3

local ret = {}
for i = 1, NUM_PIECES do
    table.insert(ret, MakeGolemPiece(i))
end

return unpack(ret)
-- (OMAR): For searching
 -- vault_pillar_guard_piece_1
 -- vault_pillar_guard_piece_2
 -- vault_pillar_guard_piece_3