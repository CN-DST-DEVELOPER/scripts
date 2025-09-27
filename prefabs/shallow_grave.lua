local assets =
{
    Asset("ANIM", "anim/shallow_grave.zip"),
}

local prefabs =
{
    "boneshard",
    "collapse_small",
}

SetSharedLootTable('shallow_grave_player',
{
    {'boneshard',   1.00},
    {'boneshard',   1.00},
})

-----------------------------------------------------------------------------------------------

local function Player_GetDescription(inst, viewer)
    if inst.char ~= nil and not viewer:HasTag("playerghost") then
        local mod = GetGenderStrings(inst.char)
        local desc = GetDescription(viewer, inst, mod)
        local name = inst.playername or STRINGS.NAMES[string.upper(inst.char)]

        -- No translations for player killer's name.
        if inst.pkname ~= nil then
            return string.format(desc, name, inst.pkname)
        end

        -- Permanent translations for death cause.
        if inst.cause == "unknown" then
            inst.cause = "shenanigans"

        elseif inst.cause == "moose" then
            inst.cause = math.random() < .5 and "moose1" or "moose2"
        end

        -- Viewer based temp translations for death cause.
        local cause =
            inst.cause == "nil"
            and (
                (viewer == "waxwell" or viewer == "winona") and "charlie" or "darkness"
            )
            or inst.cause

        return string.format(desc, name, STRINGS.NAMES[string.upper(cause)] or STRINGS.NAMES.SHENANIGANS)
    end
end

local function Player_Decay(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    inst:Remove()
    SpawnPrefab("ash").Transform:SetPosition(x, y, z)
    SpawnPrefab("collapse_small").Transform:SetPosition(x, y, z)
end

local function Player_SetSkeletonDescription(inst, char, playername, cause, pkname, userid)
    inst.char = char
    inst.playername = playername
    inst.userid = userid
    inst.pkname = pkname
    inst.cause = pkname == nil and cause:lower() or nil
    inst.components.inspectable.getspecialdescription = Player_GetDescription
end

local function Player_SetSkeletonAvatarData(inst, client_obj)
    inst.components.playeravatardata:SetData(client_obj)
end

-----------------------------------------------------------------------------------------------

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("rock")

    inst:Remove()
end

local function OnSave(inst, data)
    data.anim = inst.animnum
end

local function OnLoad(inst, data)
    if data ~= nil and data.anim ~= nil then
        inst.animnum = data.anim
        inst.AnimState:PlayAnimation("idle"..tostring(inst.animnum))
    end
end

local function Player_OnSave(inst, data)
    OnSave(inst, data)

    data.char = inst.char
    data.playername = inst.playername
    data.userid = inst.userid
    data.pkname = inst.pkname
    data.cause = inst.cause

    if inst.skeletonspawntime ~= nil then
        local time = GetTime()

        if time > inst.skeletonspawntime then
            data.age = time - inst.skeletonspawntime
        end
    end
end

local function Player_OnLoad(inst, data)
    OnLoad(inst, data)

    if not data or not data.char or (not data.cause and not data.pkname) then
        return
    end

    inst.char = data.char
    inst.playername = data.playername -- Backward compatibility for nil playername.
    inst.userid = data.userid
    inst.pkname = data.pkname -- Backward compatibility for nil pkname.
    inst.cause = data.cause

    if inst.components.inspectable ~= nil then
        inst.components.inspectable.getspecialdescription = Player_GetDescription
    end

    if data.age ~= nil and data.age > 0 then
        inst.skeletonspawntime = -data.age
    end

    if data.avatar then
        -- Load legacy data.
        inst.components.playeravatardata:OnLoad(data.avatar)
    end
end

-----------------------------------------------------------------------------------------------

local function common_fn(custom_init)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()

    inst:AddTag("skeleton_standin")

    inst.AnimState:SetBank("shallow_grave")
    inst.AnimState:SetBuild("shallow_grave")

    if custom_init ~= nil then
        custom_init(inst)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.AnimState:PlayAnimation("idle",true)

    inst:AddComponent("inspectable")
    inst.components.inspectable:RecordViews()

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('shallow_grave_player')

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(TUNING.SKELETON_WORK)
    inst.components.workable:SetOnFinishCallback(OnHammered)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

-----------------------------------------------------------------------------------------------

local function fn()
    local inst = common_fn()
    
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

-----------------------------------------------------------------------------------------------

local function player_custominit(inst)
    --inst:AddTag("playerskeleton")

    inst:AddComponent("playeravatardata")
    inst.components.playeravatardata:AddPlayerData(true)
end

local function player_fn()
    local inst = common_fn(player_custominit)

    if not TheWorld.ismastersim then
        return inst
    end

    inst.skeletonspawntime = GetTime()

    inst.Decay = Player_Decay

    inst.SetSkeletonDescription = Player_SetSkeletonDescription
    inst.SetSkeletonAvatarData  = Player_SetSkeletonAvatarData

    inst.components.lootdropper:SetChanceLootTable('skeleton_player')

    inst.components.inspectable:SetNameOverride("skeleton_player")

    TheWorld:PushEvent("ms_skeletonspawn", inst)

    inst.OnSave = Player_OnSave
    inst.OnLoad = Player_OnLoad

    return inst
end

return  Prefab("shallow_grave",             fn,             assets, prefabs),
        Prefab("shallow_grave_player",      player_fn,      assets, prefabs)
