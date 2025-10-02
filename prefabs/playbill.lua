local thedoll_assets =
{
    Asset("ANIM", "anim/playbill.zip"),
    Asset("INV_IMAGE", "playbill"),
}

local thedoll_prefabs = {
    "marionette_appear_fx",
    "marionette_disappear_fx",
}

local thepall_assets =
{
	Asset("ANIM", "anim/playbill.zip"),
    Asset("ANIM", "anim/playbill_void.zip"),
    Asset("INV_IMAGE", "playbill_void"),
}

local thepall_prefabs = {
    "marionette_appear_fx",
    "marionette_disappear_fx",
}

local thevault_assets =
{
	Asset("ANIM", "anim/playbill.zip"),
    Asset("ANIM", "anim/playbill_ancient.zip"),
    Asset("INV_IMAGE", "playbill_ancient"),
}

local thevault_prefabs = {
    "marionette_appear_fx",
    "marionette_disappear_fx",
}

local function makeplay(name, _assets, prefabs, data)
    local build = data and data.build or "playbill"
    local lectern_book_build = data and data.lectern_book_build or nil
    local noburn = data and data.noburn or nil

	local assets = { Asset("SCRIPT", "scripts/play_"..name..".lua") }
	for _, v in ipairs(_assets) do
		table.insert(assets, v)
	end

    local play = require("play_"..name)

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
		inst.entity:AddFollower()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("playbill")
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("idle")

        MakeInventoryFloatable(inst, "med", 0.15, 0.6)

        --if name == "the_doll" then
        --    inst.scrapbook_specialinfo = "PLAYBILL_THEDOLL"
        --end

        inst:AddTag("playbill")

		--furnituredecor (from furnituredecor component) added to pristine state for optimization
		inst:AddTag("furnituredecor")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:ChangeImageName(build)

		inst:AddComponent("furnituredecor")

        inst:AddComponent("inspectable")
        inst:AddComponent("tradable")

        inst:AddComponent("playbill")
        inst.components.playbill.book_build = lectern_book_build
        inst.components.playbill.costumes = play.costumes
        inst.components.playbill.scripts = play.scripts
        inst.components.playbill.starting_act = play.starting_act
        inst.components.playbill.current_act = play.starting_act

        if noburn then
            MakeHauntableLaunch(inst)
        else
            inst:AddComponent("fuel")
            inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

            MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
            MakeSmallPropagator(inst)

            MakeHauntableLaunchAndIgnite(inst)
        end

        return inst
    end

    return Prefab("playbill_"..name, fn, assets, prefabs)
end

return makeplay("the_doll", thedoll_assets, thedoll_prefabs),
        makeplay("the_veil", thepall_assets, thepall_prefabs, { build = "playbill_void", lectern_book_build = "charlie_lectern_void" }),
        makeplay("the_vault", thevault_assets, thevault_prefabs, { build = "playbill_ancient", lectern_book_build = "charlie_lectern_ancient", noburn = true})