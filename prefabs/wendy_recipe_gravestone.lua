local assets =
{
    Asset("ANIM", "anim/gravestones.zip"),
}

local prefabs =
{
    "gravestone",
    "attune_out_fx",
}

--
local function OnProxyBuilt(inst, data)
    if not data or not data.builder then
        inst:Remove()
        return
    end

    inst.components.writeable:BeginWriting(data.builder)
end

-- Writeable
local function OnWritten(inst, written_text, writer)
end

local WENDY_PLACER_SNAP_DISTANCE = 1.0
local SKELETON_TAGS = {"skeleton","skeleton_standin"}
local function OnWritingEnded(inst)
    if not inst.components.writeable then return end

    local closest_skeleton = FindEntity(inst, WENDY_PLACER_SNAP_DISTANCE, nil, nil, nil, SKELETON_TAGS)
    if closest_skeleton then
        closest_skeleton:Remove()
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    SpawnPrefab("attune_out_fx").Transform:SetPosition(ix, iy, iz)

    local gravestone = SpawnPrefab("gravestone")
    gravestone.Transform:SetPosition(ix, iy, iz)
    gravestone.random_stone_choice = tostring(math.random(4))
    gravestone.AnimState:PlayAnimation("grave"..gravestone.random_stone_choice.."_place")
    gravestone.AnimState:PushAnimation("grave"..gravestone.random_stone_choice)

    gravestone.SoundEmitter:PlaySound("meta5/wendy/tombstone_place")

    if inst.components.writeable:IsWritten() then
        local epitaph = inst.components.writeable:GetText()
        gravestone.setepitaph = epitaph
        gravestone.components.inspectable:SetDescription("'"..epitaph.."'")
    end

    inst:DoTaskInTime(0, inst.Remove)
    --inst:Remove()
end

--
local function wendy_recipe_gravestone_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")

    --Sneak these into pristine state for optimization
    inst:AddTag("_writeable")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --Remove these tags so that they can be added properly when replicating components below
    inst:RemoveTag("_writeable")

    local writeable = inst:AddComponent("writeable")
    writeable:SetDefaultWriteable(false)
    writeable:SetAutomaticDescriptionEnabled(false)
    writeable:SetWriteableDistance(2)
    writeable:SetOnWrittenFn(OnWritten)
    writeable:SetOnWritingEndedFn(OnWritingEnded)

    inst:ListenForEvent("onbuilt", OnProxyBuilt)

    return inst
end

--
local WENDY_PLACER_SNAP_TAGS = {"skeleton","skeleton_standin"}
local function wendy_placer_onupdatetransform(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local skeletons = TheSim:FindEntities(ix, 0, iz, WENDY_PLACER_SNAP_DISTANCE, nil, nil, WENDY_PLACER_SNAP_TAGS)

    if #skeletons == 0 then
        inst._accept_placement = false
    else
        ix, iy, iz = skeletons[1].Transform:GetWorldPosition()
        inst.Transform:SetPosition(ix, 0, iz)

        inst._accept_placement = true
    end
end

local function wendy_placer_override_build_point(inst)
    -- Gamepad defaults to this behavior, but mouse input normally takes
    -- mouse position over placer position, ignoring the placer snapping
    -- to a nearby moon geyser
    return inst:GetPosition()
end

local function wendy_placer_override_testfn(inst)
    local _
    local mouse_blocked = false
    if inst.components.placer.testfn then
        _, mouse_blocked = inst.components.placer.testfn(inst:GetPosition(), inst:GetRotation())
    end

    return inst._accept_placement, mouse_blocked
end

-- NOTES(DiogoW): This used to be TheCamera:GetDownVec()*.5, probably legacy code from DS,
-- since TheCamera:GetDownVec() would always return the values below.
local MOUND_POSITION_OFFSET = { 0.35355339059327, 0, 0.35355339059327 }

local function CreateMoundPlacer()
    local mound = CreateEntity()

    --[[Non-networked entity]]
    mound.entity:SetCanSleep(false)
    mound.persists = false

    mound.entity:AddTransform()
    mound.entity:AddAnimState()

    mound:AddTag("CLASSIFIED")
    mound:AddTag("NOCLICK")
    mound:AddTag("placer")

    mound.AnimState:SetBank("gravestone")
    mound.AnimState:SetBuild("gravestones")
    mound.AnimState:PlayAnimation("gravedirt")

    mound.Transform:SetPosition(unpack(MOUND_POSITION_OFFSET))

    return mound
end

local function wendy_placer_postinit_fn(inst)
    local placer = inst.components.placer
    placer.onupdatetransform = wendy_placer_onupdatetransform
    placer.override_build_point_fn = wendy_placer_override_build_point
    placer.override_testfn = wendy_placer_override_testfn

    inst._accept_placement = false

    inst.AnimState:Hide("flower")

    inst._mound = CreateMoundPlacer()
    inst._mound.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(inst._mound)
end

return Prefab("wendy_recipe_gravestone", wendy_recipe_gravestone_fn, assets, prefabs),
    MakePlacer(
        "wendy_recipe_gravestone_placer", "gravestone", "gravestones", "grave1",
        nil, nil, nil, nil, nil, nil, wendy_placer_postinit_fn
    )