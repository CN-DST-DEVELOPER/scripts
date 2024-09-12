local assets =
{
    Asset("ANIM", "anim/saddle_shadow_tracks.zip"),
}

-------------------------------------------------------------------------------------------------------------------

local NUM_FOOTPRINTS = 4
local NUM_ART_VARIATIONS = 4
local NUM_OFFSET_VARIATIONS = 3

-------------------------------------------------------------------------------------------------------------------

local function OnUpdate(inst, dt)
    local current_frame = inst.AnimState:GetCurrentAnimationFrame()

    if current_frame >= 2 and current_frame <= 36 then
        return -- Skipping useless updates.
    end

    inst.AnimState:SetSymbolMultColour("footprint_1", 1, 1, 1, Remap(current_frame, 36, 50, 1, 0))
    inst.AnimState:SetSymbolMultColour("footprint_2", 1, 1, 1, Remap(current_frame, 46, 60, 1, 0))
    inst.AnimState:SetSymbolMultColour("footprint_3", 1, 1, 1, Remap(current_frame, 56, 70, 1, 0))
    inst.AnimState:SetSymbolMultColour("footprint_4", 1, 1, 1, Remap(current_frame, 66, 80, 1, 0))
end

local function OnAnimOver(inst)
    if inst.owner ~= nil and inst.owner.footprint_pool ~= nil then
        inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)

        inst:RemoveFromScene()

        table.insert(inst.owner.footprint_pool, inst)
    else
        inst:Remove()
    end
end

local function SetFXOwner(inst, owner)
    inst.owner = owner
end

local function RestartFX(inst)
    inst.AnimState:PlayAnimation("ground")
    inst.components.updatelooper:AddOnUpdateFn(OnUpdate)

    inst:ReturnToScene()

    for i=1, NUM_FOOTPRINTS do
        if inst.current_offsets[i] ~= nil then
            inst.AnimState:Hide("footprint"..i.."_offset"..inst.current_offsets[i])
        end

        inst.current_offsets[i] = math.random(NUM_OFFSET_VARIATIONS)
        inst.AnimState:Show("footprint"..i.."_offset"..inst.current_offsets[i])

        inst.AnimState:OverrideSymbol("footprint_"..i, "saddle_shadow_tracks", "swap_footprint"..math.random(NUM_ART_VARIATIONS))
    end
end

-------------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("saddle_shadow_tracks")
    inst.AnimState:SetBuild("saddle_shadow_tracks")
    inst.AnimState:PlayAnimation("ground")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(2)

    inst.current_offsets = {}

    inst.SetFXOwner = SetFXOwner
    inst.RestartFX = RestartFX
    inst.OnAnimOver = OnAnimOver

    for i=1, NUM_FOOTPRINTS do
        for j=1, NUM_OFFSET_VARIATIONS do
            inst.AnimState:Hide("footprint"..i.."_offset"..j)
        end
    end

    inst:AddComponent("updatelooper")

    inst:ListenForEvent("animover", inst.OnAnimOver)

    return inst
end

return Prefab("saddle_shadow_footprint", fn, assets)