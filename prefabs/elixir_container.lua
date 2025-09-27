local assets =
{
    Asset("ANIM", "anim/ui_elixir_container_3x3.zip"),
    Asset("ANIM", "anim/elixir_container.zip"),
    Asset("INV_IMAGE", "elixir_container_open"),
}

local prefabs =
{

}

-----------------------------------------------------------------------------------------------

local SOUNDS =
{
    open  = "meta5/wendy/basket_open",
    close = "meta5/wendy/basket_close",
}

-----------------------------------------------------------------------------------------------

local function OnOpen(inst)
    if inst:HasTag("burnt") then
        return
    end

    inst.AnimState:PlayAnimation("open")
    inst.components.inventoryitem:ChangeImageName("elixir_container_open")
    inst.SoundEmitter:PlaySound(inst._sounds.open)
end

local function OnClose(inst)
    if inst:HasTag("burnt") then
        return
    end

    if inst.components.inventoryitem.owner == nil then
        inst.AnimState:PlayAnimation("close")
        inst.AnimState:PushAnimation("closed", false)
    else
        inst.AnimState:PlayAnimation("closed", false)
    end
    inst.components.inventoryitem:ChangeImageName()
    inst.SoundEmitter:PlaySound(inst._sounds.close)
end

local function OnPutInInventory(inst)
    inst.components.container:Close()
    inst.AnimState:PlayAnimation("closed", false)
end

-----------------------------------------------------------------------------------------------

local function OnBurnt(inst)
    inst.components.container:DropEverything()
    DefaultBurntFn(inst)
end

-----------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    if (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) or inst:HasTag("burnt") then
        data.burnt = true
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.burnt and inst.components.burnable ~= nil then
        inst.components.burnable.onburnt(inst)
    end
end

-----------------------------------------------------------------------------------------------

local FLOATABLE_SWAP_DATA = { bank = "elixir_container", anim = "closed" }
local FLOATABLE_SCALE = { 1.35, 1, 1.35 }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("elixir_container.png")

    inst.AnimState:SetBank("elixir_container")
    inst.AnimState:SetBuild("elixir_container")
    inst.AnimState:PlayAnimation("closed")

    MakeInventoryPhysics(inst)

    MakeInventoryFloatable(inst, "small", 0.3, FLOATABLE_SCALE, nil, nil, FLOATABLE_SWAP_DATA)

    inst.entity:SetPristine()

    inst:AddTag("portablestorage")

    if not TheWorld.ismastersim then
        return inst
    end

    inst._sounds = SOUNDS

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("elixir_container")
    inst.components.container.restrictedtag = "elixircontaineruser"
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true
    inst.components.container.droponopen = true

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)

    MakeSmallBurnable(inst)
    MakeMediumPropagator(inst)

    inst.components.burnable:SetOnBurntFn(OnBurnt)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHauntableLaunchAndDropFirstItem(inst)

    return inst
end


return Prefab("elixir_container", fn, assets, prefabs)