require("datagrid")

local BLOCKERS
local function InitializeBlockersGrid()
    if BLOCKERS == nil then
        BLOCKERS = DataGrid(TheWorld.Map:GetSize())
    end
end

local function OnUpdateSleepStatus(inst)
    if inst.OnEntityWake then
        inst.OnEntityWake = nil
        inst.OnEntitySleep = nil
    end

    InitializeBlockersGrid()
    local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(inst.Transform:GetWorldPosition())
    BLOCKERS:SetDataAtPoint(tx, ty, true)
end

local function OnRemove(inst)
    local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(inst.Transform:GetWorldPosition())
    BLOCKERS:SetDataAtPoint(tx, ty, nil)
end

-- Global
function IsVaultTileInvalid(tx, ty)
    return BLOCKERS and BLOCKERS:GetDataAtPoint(tx, ty)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
    inst.entity:AddNetwork()

    -- Don't use CLASSIFIED because vaultroom uses FindEntities
    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")

    inst.OnEntityWake = OnUpdateSleepStatus
    inst.OnEntitySleep = OnUpdateSleepStatus
    inst.OnRemoveEntity = OnRemove

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	return inst
end

return Prefab("vault_invalidtile", fn)