local assets =
{
    Asset("ANIM", "anim/boat_leak.zip"),
    Asset("ANIM", "anim/boat_leak_build.zip"),
}

local function onsprungleak(inst)
	if inst.components.inspectable == nil then
		inst:AddComponent("inspectable")

        inst:AddComponent("hauntable")
        inst.components.hauntable.cooldown = TUNING.HAUNT_COOLDOWN_SMALL
        inst.components.hauntable.hauntvalue = TUNING.HAUNT_TINY
	end
    inst:RemoveTag("NOCLICK")
	inst:RemoveTag("NOBLOCK")
end

local function onrepairedleak(inst)
	if inst.components.inspectable ~= nil then
		inst:RemoveComponent("inspectable")

        inst:RemoveComponent("hauntable")
	end

    inst:AddTag("NOCLICK")
	inst:AddTag("NOBLOCK")
end

local function checkforleakimmune(inst)
    local boat = inst:GetCurrentPlatform()
    if boat == nil or boat.components.hullhealth.leakproof then
        local x, y, z = inst.Transform:GetWorldPosition()
        print("Warning: A boat leak tried to spawn on land or a leakproof boat at", x, y, z)
        inst:Remove()
    end
end

local function fn()

    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("boat_leak")
    inst.AnimState:SetBuild("boat_leak_build")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.persists = false

    inst:AddComponent("boatleak")
	inst.components.boatleak.onsprungleak = onsprungleak
	inst.components.boatleak.onrepairedleak = onrepairedleak

    inst:AddComponent("lootdropper")

    inst:DoTaskInTime(0, checkforleakimmune) -- NOTES(JBK): This is now just a last resort safeguard checker.

    return inst
end

return Prefab("boat_leak", fn, assets)
