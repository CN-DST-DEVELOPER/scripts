local assets =
{
    Asset("ANIM", "anim/cave_vent_ground.zip"),
}

--[[
idle[num]
open[num]
close[num]
end[num]
]]

local POSITIONS = {
    { -- 1
        {3.5, 0, -6.5},
        {.25, 0, -7.75},
        {-1.75, 0, -6.75},
    },
    { -- 2
        {1.5, 0, -4.25},
        {0, 0, -7.5},
        {-1, 0, -6},
    },
}

local function checkspawn(inst)

    local pos = Vector3(inst.Transform:GetWorldPosition())

    local radius = 8
    local anglemod = 0

    if inst.anglemod then
        anglemod = inst.anglemod
    else
        anglemod = 0 --(math.random()*40 -20) *DEGREES
    end

    local angle = (inst.Transform:GetRotation() * DEGREES) + (PI/2) + anglemod
    local newpos = Vector3(pos.x + math.cos(angle) * radius, 0, pos.z - math.sin(angle) * radius)

    if not TheWorld.Map:IsVisualGroundAtPoint(newpos.x, 0, newpos.z) then
        return false
    end

    for k, poss in pairs(POSITIONS[inst.animnum]) do
        local newfx = SpawnPrefab("cave_vent_ground_fx")
        newfx.Transform:SetPosition(pos.x + poss[1],pos.y + poss[2], pos.z + poss[3])
        newfx.Transform:SetRotation(inst.Transform:GetRotation() + (anglemod/DEGREES))
        newfx.anglemod = anglemod
    end

    --local newfx = SpawnPrefab("cave_vent_ground_fx")
    --newfx.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
    --newfx.Transform:SetRotation(inst.Transform:GetRotation() + (anglemod/DEGREES))
    --newfx.anglemod = anglemod

end

local function OnSave(inst, data)
    data.animnum = inst.animnum
end

local function OnLoad(inst, data)
    if data and data.animnum then
        inst.animnum = data.animnum
    end
end

local NUM_ANIM = 2
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("cave_vent_ground")
    inst.AnimState:SetBank("cave_vent_ground")
    inst.AnimState:PlayAnimation("idle1")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetMultColour(1,0.5,0.5,1)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.Transform:SetRotation(math.random()*360)

    inst.animnum = math.random(NUM_ANIM)
    if inst.animnum ~= 1 then
        inst.AnimState:PlayAnimation("idle"..inst.animnum)
    end

    inst:AddComponent("savedrotation")

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    --inst.persists = false ?

    --inst:DoTaskInTime(3,function() checkspawn(inst) end)
    --inst:ListenForEvent("animover", function() inst:Remove() end)

    return inst
end

return Prefab("cave_vent_ground_fx", fn, assets)