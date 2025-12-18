local cooking = require("cooking")
local RiftConfirmScreen = require("screens/redux/riftconfirmscreen")

local params = {}
local containers = { MAXITEMSLOTS = 0 }

containers.params = params

function containers.widgetsetup(container, prefab, data)
    local t = data or params[prefab or container.inst.prefab]
    if t ~= nil then
        for k, v in pairs(t) do
            container[k] = v
        end
        container:SetNumSlots(container.widget.slotpos ~= nil and #container.widget.slotpos or 0)
    end
end

--------------------------------------------------------------------------
--[[ backpack ]]
--------------------------------------------------------------------------

params.backpack =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_backpack_2x4",
        animbuild = "ui_backpack_2x4",
        --pos = Vector3(-5, -70, 0),
        pos = Vector3(-5, -80, 0),        
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
}

for y = 0, 3 do
    table.insert(params.backpack.widget.slotpos, Vector3(-162, -75 * y + 114, 0))
    table.insert(params.backpack.widget.slotpos, Vector3(-162 + 75, -75 * y + 114, 0))
end

params.icepack = params.backpack

--------------------------------------------------------------------------
--[[ spicepack ]]
--------------------------------------------------------------------------

params.spicepack =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_icepack_2x3",
        animbuild = "ui_icepack_2x3",
        pos = Vector3(-5, -70, 0),
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
}

for y = 0, 2 do
    table.insert(params.spicepack.widget.slotpos, Vector3(-162, -75 * y + 75, 0))
    table.insert(params.spicepack.widget.slotpos, Vector3(-162 + 75, -75 * y + 75, 0))
end

--------------------------------------------------------------------------
--[[ chester ]]
--------------------------------------------------------------------------

params.chester =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(params.chester.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
    end
end

--------------------------------------------------------------------------
--[[ shadowchester ]]
--------------------------------------------------------------------------

--Deprecated; keep definition for dragonflychest, minotaurchest, mods,
--and also for legacy save data
params.shadowchester =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chester_shadow_3x4",
        animbuild = "ui_chester_shadow_3x4",
        pos = Vector3(0, 220, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 2.5, -0.5, -1 do
    for x = 0, 2 do
        table.insert(params.shadowchester.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75, 0))
    end
end

params.shadow_container = deepcopy(params.shadowchester)
params.shadow_container.widget.animbank = "ui_portal_shadow_3x4"
params.shadow_container.widget.animbuild = "ui_portal_shadow_3x4"
params.shadow_container.widget.animloop = true

function params.shadow_container.itemtestfn(container, item, slot)
    return not item:HasTag("irreplaceable")
end

--------------------------------------------------------------------------
--[[ rabbitkinghorn ]]
--------------------------------------------------------------------------
params.rabbitkinghorn_container = deepcopy(params.shadow_container)
params.rabbitkinghorn_container.widget.animbank = "ui_portal_rabbitkinghorn_3x4"
params.rabbitkinghorn_container.widget.animbuild = "ui_portal_rabbitkinghorn_3x4"
params.rabbitkinghorn_container.widget.animloop = nil

--------------------------------------------------------------------------
--[[ hutch ]]
--------------------------------------------------------------------------

params.hutch = params.chester


--------------------------------------------------------------------------
--[[ Woby ]]
--------------------------------------------------------------------------

params.wobysmall =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_woby_3x3",
        animbuild = "ui_woby_3x3",
		pos = Vector3(0, 330, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

--V2C: y pos used to be 200, moved to 330 to match woby_rack_container so that it scales
--     together in controller inventory screen. Shift all y-coords to account for this.
--     Art was also shifted accordingly.  0.6 is the base scale (in inventorybar).
local yshift = (330 - 200) / 0.6
for y = 2, 0, -1 do
    for x = 0, 2 do
		table.insert(params.wobysmall.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75 - yshift, 0))
    end
end
yshift = nil

params.wobybig = params.wobysmall

--------------------------------------------------------------------------
--[[ woby_rack_container ]]
--------------------------------------------------------------------------

params.woby_rack_container =
{
	widget =
	{
		slotpos = {},
		slotbg = {},
		animbank = "ui_meatrack_3x1",
		animbuild = "ui_meatrack_3x1",
		pos = Vector3(0, 330, 0),
		side_align_tip = 160,
	},
	acceptsstacks = false,
	type = "top_rack",
	openlimit = 1,
}

local dryer_slotbg = { image = "inv_slot_morsel.tex" }
for x = 0, 2 do
	table.insert(params.woby_rack_container.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 0, 0))
	table.insert(params.woby_rack_container.widget.slotbg, dryer_slotbg)
end
dryer_slotbg = nil

function params.woby_rack_container.itemtestfn(container, item, slot)
	return item:HasTag("dryable")
		or (TheWorld.ismastersim and (
				item:GetTimeAlive() == 0 or --items perishing replaced by spoiled_food/fish
				container.inst:GetTimeAlive() == 0 or --transferring items during woby transform
				(	item.dryingrack_lastinfo and --failing to move items; return to slot
					item.dryingrack_lastinfo.container == container and
					item.dryingrack_lastinfo.slot == slot
				)
			))
end

--------------------------------------------------------------------------
--[[ meatrack ]]
--------------------------------------------------------------------------

params.meatrack =
{
	widget =
	{
		slotpos = {},
		slotbg = {},
		animbank = "ui_meatrack_multi_3x1",
		animbuild = "ui_meatrack_multi_3x1",
		pos = Vector3(0, 200, 0),
		side_align_tip = 160,
	},
	acceptsstacks = false,
	type = "chest",
}

local dryer_slotbg = { image = "inv_slot_morsel.tex" }
for x = 0, 2 do
	table.insert(params.meatrack.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 0, 0))
	table.insert(params.meatrack.widget.slotbg, dryer_slotbg)
end

function params.meatrack.itemtestfn(container, item, slot)
	return item:HasTag("dryable")
		or (TheWorld.ismastersim and (
				item:GetTimeAlive() == 0 or --items perishing replaced by spoiled_food/fish
				--container.inst:GetTimeAlive() == 0 or --woby specific; see above
				(	item.dryingrack_lastinfo and --failing to move items; return to slot
					item.dryingrack_lastinfo.container == container and
					item.dryingrack_lastinfo.slot == slot
				)
			))
end

params.meatrack_hermit =
{
	widget =
	{
		slotpos = { Vector3(-2, 18, 0) },
		slotbg = { dryer_slotbg },
		animbank = "ui_hermitcrab_meatrack_1x1",
		animbuild = "ui_hermitcrab_meatrack_1x1",
		pos = Vector3(0, 160, 0),
		side_align_tip = 100,
	},
	acceptsstacks = false,
	type = "chest",
	itemtestfn = params.meatrack.itemtestfn,
}

params.meatrack_hermit_multi =
{
	widget =
	{
		slotpos = {},
		slotbg = {},
		animbank = "ui_hermitcrab_3x3",
		animbuild = "ui_hermitcrab_3x3",
		pos = Vector3(0, 200, 0),
		side_align_tip = 160,
	},
	acceptsstacks = false,
	type = "chest",
	itemtestfn = params.meatrack.itemtestfn,
}

dryer_slotbg = { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" }
for y = 2, 0, -1 do
	for x = 0, 2 do
		table.insert(params.meatrack_hermit_multi.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
		table.insert(params.meatrack_hermit_multi.widget.slotbg, dryer_slotbg)
	end
end

dryer_slotbg = nil

--------------------------------------------------------------------------
--[[ sewingmachine ]]
--------------------------------------------------------------------------

params.yotb_sewingmachine =
{

    widget =
    {
        slotpos =
        {
            Vector3(-(64 + 12), 0, 0),
            Vector3(0, 0, 0),
            Vector3(64 + 12, 0, 0),
        },

        slotbg =
        {
            { image = "yotb_sewing_slot.tex", atlas = "images/hud2.xml" },
            { image = "yotb_sewing_slot.tex", atlas = "images/hud2.xml" },
            { image = "yotb_sewing_slot.tex", atlas = "images/hud2.xml" },
        },

        animbank = "ui_chest_3x1",
        animbuild = "ui_chest_3x1",
        pos = Vector3(0, 200, 0),
        side_align_tip = 100,

        buttoninfo =
        {
            text = STRINGS.ACTIONS.YOTB_SEW,
            position = Vector3(0, -65, 0),
        }
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.yotb_sewingmachine.itemtestfn(container, item, slot)
    return item:HasTag("yotb_pattern_fragment")
end

function params.yotb_sewingmachine.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.YOTB_SEW):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.YOTB_SEW.code, inst, ACTIONS.YOTB_SEW.mod_name)
    end
end

function params.yotb_sewingmachine.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and inst.replica.container:IsFull()
end



--------------------------------------------------------------------------
--[[ cookpot ]]
--------------------------------------------------------------------------

params.cookpot =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 32 + 8 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(0, -(64 + 32 + 8 + 4), 0),
        },
        animbank = "ui_cookpot_1x4",
        animbuild = "ui_cookpot_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
        buttoninfo =
        {
            text = STRINGS.ACTIONS.COOK,
            position = Vector3(0, -165, 0),
        }
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.cookpot.itemtestfn(container, item, slot)
    return cooking.IsCookingIngredient(item.prefab) and not container.inst:HasTag("burnt")
end

function params.cookpot.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.COOK):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.COOK.code, inst, ACTIONS.COOK.mod_name)
    end
end

function params.cookpot.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and inst.replica.container:IsFull()
end

params.archive_cookpot = params.cookpot
params.portablecookpot = params.cookpot

--------------------------------------------------------------------------
--[[ portablespicer]]
--------------------------------------------------------------------------

params.portablespicer =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "cook_slot_food.tex" },
            { image = "cook_slot_spice.tex" },
        },
        animbank = "ui_cookpot_1x2",
        animbuild = "ui_cookpot_1x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
        buttoninfo =
        {
            text = STRINGS.ACTIONS.SPICE,
            position = Vector3(0, -93, 0),
        },
    },
    acceptsstacks = false,
    usespecificslotsforitems = true,
    type = "cooker",
}

function params.portablespicer.itemtestfn(container, item, slot)
    return item.prefab ~= "wetgoop"
        and (   (slot == 1 and item:HasTag("preparedfood") and not item:HasTag("spicedfood")) or
                (slot == 2 and item:HasTag("spice")) or
                (slot == nil and (item:HasTag("spice") or (item:HasTag("preparedfood") and not item:HasTag("spicedfood"))))
            )
        and not container.inst:HasTag("burnt")
end

function params.portablespicer.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.COOK):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.COOK.code, inst, ACTIONS.COOK.mod_name)
    end
end

function params.portablespicer.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and inst.replica.container:IsFull()
end

--------------------------------------------------------------------------
--[[ bundle_container ]]
--------------------------------------------------------------------------

params.bundle_container =
{
    widget =
    {
        slotpos =
        {
            Vector3(-37.5, 32 + 4, 0),
            Vector3(37.5, 32 + 4, 0),
            Vector3(-37.5, -(32 + 4), 0),
            Vector3(37.5, -(32 + 4), 0),
        },
        animbank = "ui_bundle_2x2",
        animbuild = "ui_bundle_2x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 120,
        buttoninfo =
        {
            text = STRINGS.ACTIONS.WRAPBUNDLE,
            position = Vector3(0, -100, 0),
        }
    },
    type = "cooker",
}

function params.bundle_container.itemtestfn(container, item, slot)
    return not (item:HasTag("irreplaceable") or item:HasTag("_container") or item:HasTag("bundle") or item:HasTag("nobundling"))
end

function params.bundle_container.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.WRAPBUNDLE):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.WRAPBUNDLE.code, inst, ACTIONS.WRAPBUNDLE.mod_name)
    end
end

function params.bundle_container.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and not inst.replica.container:IsEmpty() and not inst.replica.container:IsReadOnlyContainer()
end

--------------------------------------------------------------------------
--[[ construction_container ]]
--------------------------------------------------------------------------

params.construction_container =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_construction_4x1",
        animbuild = "ui_construction_4x1",
        pos = Vector3(300, 0, 0),
        top_align_tip = 50,
        buttoninfo =
        {
            text = STRINGS.ACTIONS.APPLYCONSTRUCTION.GENERIC,
            position = Vector3(0, -94, 0),
		},
		--V2C: -override the default widget sound, which is heard only by the client
		--     -most containers disable the client sfx via skipopensnd/skipclosesnd,
		--      and play it in world space through the prefab instead.
		opensound = "dontstarve/wilson/chest_open",
		closesound = "dontstarve/wilson/chest_close",
		--
    },
    usespecificslotsforitems = true,
    type = "cooker",
}

for x = -1.5, 1.5, 1 do
    table.insert(params.construction_container.widget.slotpos, Vector3(x * 110, 8, 0))
end

function params.construction_container.itemtestfn(container, item, slot)

    local doer = container.inst.entity:GetParent()
    return doer ~= nil
        and doer.components.constructionbuilderuidata ~= nil
        and doer.components.constructionbuilderuidata:GetIngredientForSlot(slot) == item.prefab
end

function params.construction_container.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.APPLYCONSTRUCTION):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.APPLYCONSTRUCTION.code, inst, ACTIONS.APPLYCONSTRUCTION.mod_name)
    end
end

function params.construction_container.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and not inst.replica.container:IsEmpty()
end

params.construction_repair_container = deepcopy(params.construction_container)
params.construction_repair_container.widget.buttoninfo.text = STRINGS.ACTIONS.APPLYCONSTRUCTION.REPAIR

params.construction_rebuild_container = deepcopy(params.construction_container)
params.construction_rebuild_container.widget.buttoninfo.text = STRINGS.ACTIONS.APPLYCONSTRUCTION.REBUILD

--------------------------------------------------------------------------
--[[ enable_shadow_rift_construction_container ]]
--------------------------------------------------------------------------

params.enable_shadow_rift_construction_container = deepcopy(params.construction_container)

params.enable_shadow_rift_construction_container.widget.slotpos = {Vector3(0, 8, 0)}
params.enable_shadow_rift_construction_container.widget.side_align_tip = 120
params.enable_shadow_rift_construction_container.widget.animbank = "ui_bundle_2x2"
params.enable_shadow_rift_construction_container.widget.animbuild = "ui_bundle_2x2"
params.enable_shadow_rift_construction_container.widget.buttoninfo.text = STRINGS.ACTIONS.APPLYCONSTRUCTION.OFFER

---------------------------------------
-- construction_container_1x1


params.construction_container_1x1 = deepcopy(params.construction_container)

params.construction_container_1x1.widget.slotpos = {Vector3(0, 8, 0)}
params.construction_container_1x1.widget.pos.x = 150
params.construction_container_1x1.widget.side_align_tip = 40
params.construction_container_1x1.widget.animbank = "ui_construction_1x1"
params.construction_container_1x1.widget.animbuild = "ui_construction_1x1"

---------------------------------------

local function IsConstructionSiteComplete(inst, doer)
    local container = inst.replica.container

    if container ~= nil and not container:IsEmpty() then
        local constructionsite = doer.components.constructionbuilderuidata ~= nil and doer.components.constructionbuilderuidata:GetConstructionSite() or nil
        
        if constructionsite ~= nil then
            local ingredients = constructionsite:GetIngredients()

            if ingredients ~= nil then
                for i, v in ipairs(ingredients) do
                    local complete, new_count = container:Has(v.type, v.amount)
                    local old_count = constructionsite:GetSlotCount(i)
                    if not (new_count +  old_count >= v.amount) then
                        return false
                    end
                end
            else
                return false
            end

            return true
        end
    end

    return false
end

local function EnableRiftsPopUpGoBack()
    TheFrontEnd:PopScreen()
end

local function EnableRiftsDoAct(inst, doer)
	if inst.components.container ~= nil then
		BufferedAction(doer, inst, ACTIONS.APPLYCONSTRUCTION):Do()
	elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
		SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.APPLYCONSTRUCTION.code, inst, ACTIONS.APPLYCONSTRUCTION.mod_name)
	end
end

function params.enable_shadow_rift_construction_container.widget.buttoninfo.fn(inst, doer)
	if not params.enable_shadow_rift_construction_container.widget.overrideactionfn(inst, doer) then
		-- No UI no dialogue.
		EnableRiftsDoAct(inst, doer)
	end
end

function params.enable_shadow_rift_construction_container.widget.overrideactionfn(inst, doer)
	if doer ~= nil and doer.HUD ~= nil and IsConstructionSiteComplete(inst, doer) then
		-- We have UI do dialogue.
		local function EnableRiftsPopUpConfirm()
			EnableRiftsDoAct(inst, doer)
			TheFrontEnd:PopScreen()
		end

		local str = inst.POPUP_STRINGS
		local confirmation = RiftConfirmScreen(str.TITLE, str.BODY,
		{
			{ text = str.OK,     cb = EnableRiftsPopUpConfirm },
			{ text = str.CANCEL, cb = EnableRiftsPopUpGoBack  },
		})

		TheFrontEnd:PushScreen(confirmation)
		return true
	end
	return false
end

--lunar is same as shadow, just different strings specified in prefab
params.enable_lunar_rift_construction_container = params.enable_shadow_rift_construction_container

--------------------------------------------------------------------------
--[[ mushroom_light ]]
--------------------------------------------------------------------------

params.mushroom_light =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 32 + 8 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(0, -(64 + 32 + 8 + 4), 0),
        },
        animbank = "ui_lamp_1x4",
        animbuild = "ui_lamp_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.mushroom_light.itemtestfn(container, item, slot)
    return (item:HasTag("lightbattery") or item:HasTag("lightcontainer")) and not container.inst:HasTag("burnt")
end

--------------------------------------------------------------------------
--[[ mushroom_light2 ]]
--------------------------------------------------------------------------

params.mushroom_light2 = deepcopy(params.mushroom_light)

function params.mushroom_light2.itemtestfn(container, item, slot)
    return (item:HasTag("lightbattery") or item:HasTag("spore") or item:HasTag("lightcontainer")) and not container.inst:HasTag("burnt")
end

--------------------------------------------------------------------------
--[[ yots_lantern_post ]]
--------------------------------------------------------------------------

local LIGHT_TAGS = { "lightbattery", "spore", "lightcontainer" }
params.yots_lantern_post = {
    widget =
    {
        slotpos =
        {
             Vector3(-2, 18, 0),
        },
        animbank = "ui_chest_1x1",
        animbuild = "ui_chest_1x1",
        pos = Vector3(0, 160, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "chest",
}

function params.yots_lantern_post.itemtestfn(container, item, slot)
    return item:HasAnyTag(LIGHT_TAGS) and not container.inst:HasTag("burnt")
end

--------------------------------------------------------------------------
--[[ hermitcrab_lightpost ]]
--------------------------------------------------------------------------

params.hermitcrab_lightpost = deepcopy(params.yots_lantern_post)
params.hermitcrab_lightpost.widget.animbank = "ui_hermitcrab_1x1"
params.hermitcrab_lightpost.widget.animbuild = "ui_hermitcrab_1x1"
params.hermitcrab_lightpost.itemtestfn = params.yots_lantern_post.itemtestfn

function params.hermitcrab_lightpost.widget.bganim_visualfn(bganim, container, doer)
    local r, g, b, a = container.AnimState:GetSymbolMultColour("coral")
    bganim:GetAnimState():SetSymbolMultColour("coral", r, g, b, a)
end

--------------------------------------------------------------------------
--[[ hermithouse2 ]]
--------------------------------------------------------------------------

params.hermithouse2 =
{
	widget =
	{
		slotpos =
		{
			Vector3(-37.5, 32 + 4, 0),
			Vector3(37.5, 32 + 4, 0),
			Vector3(-37.5, -(32 + 4), 0),
			Vector3(37.5, -(32 + 4), 0),
		},
		slotbg = {},
		animbank = "ui_hermitcrab_2x2",
		animbuild = "ui_hermitcrab_2x2",
		pos = Vector3(200, 0, 0),
		side_align_tip = 120,
	},
	acceptsstacks = false,
	type = "cooker",
}

local hermithouse2_slotbg = { image = "inv_slot_hermithouse.tex", atlas = "images/hud2.xml" }
for i = 1, 4 do
	params.hermithouse2.widget.slotbg[i] = hermithouse2_slotbg
end
hermithouse2_slotbg = nil

function params.hermithouse2.itemtestfn(container, item, slot)
    return item:HasTag("hermithouse_ornament")
end

--------------------------------------------------------------------------
--[[ winter_tree ]]
--------------------------------------------------------------------------

params.winter_tree =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_backpack_2x4",
        animbuild = "ui_backpack_2x4",
        pos = Vector3(275, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

for y = 0, 3 do
    table.insert(params.winter_tree.widget.slotpos, Vector3(-162, -75 * y + 114, 0))
    table.insert(params.winter_tree.widget.slotpos, Vector3(-162 + 75, -75 * y + 114, 0))
end

function params.winter_tree.itemtestfn(container, item, slot)
	return item:HasAnyTag("winter_ornament", "hermithouse_ornament") and not container.inst:HasTag("burnt")
end

params.winter_twiggytree = params.winter_tree
params.winter_deciduoustree = params.winter_tree
params.winter_palmconetree = params.winter_tree

--------------------------------------------------------------------------
--[[ sisturn ]]
--------------------------------------------------------------------------

params.sisturn =
{
    widget =
    {
        slotpos =
        {
            Vector3(-37.5, 32 + 4, 0),
            Vector3(37.5, 32 + 4, 0),
            Vector3(-37.5, -(32 + 4), 0),
            Vector3(37.5, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },
        },
        animbank = "ui_chest_2x2",
        animbuild = "ui_chest_2x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 120,
    },
    acceptsstacks = false,
    type = "cooker",
    openlimit = 1,
}

function params.sisturn.itemtestfn(container, item, slot)
    local owner
    if TheWorld.ismastersim then
        owner = container.inst.components.container:GetOpeners()[1]
    elseif ThePlayer and container:IsOpenedBy(ThePlayer) then
        owner = ThePlayer
    end

    --NOTE: can have no owner when loading
    if not owner or (owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wendy_sisturn_3")) then
        return item.prefab == "petals" or item.prefab == "moon_tree_blossom" or item.prefab == "petals_evil"
    end

    return item.prefab == "petals" 
end

--------------------------------------------------------------------------
--[[ offering pot ]]
--------------------------------------------------------------------------

params.offering_pot =
{
    widget =
    {
        slotpos =
        {
            Vector3(-37.5, 32 + 4, 0),
            Vector3(37.5, 32 + 4, 0),
            Vector3(-37.5, -(32 + 4), 0),
            Vector3(37.5, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
        },
        animbank = "ui_chest_2x2",
        animbuild = "ui_chest_2x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 120,
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.offering_pot.itemtestfn(container, item, slot)
    return not container.inst:HasTag("burnt") and item.prefab == "kelp"
end

--------------------------------------------------------------------------
--[[ offering pot II ]]
--------------------------------------------------------------------------

params.offering_pot_upgraded =
{
    widget =
    {
        slotpos =
        {            
            Vector3(-75, 32 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(75, 32 + 4, 0),
            Vector3(-75, -(32 + 4), 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(75, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_kelp.tex", atlas = "images/hud2.xml" },
        },
        animbank = "ui_chest_3x2",
        animbuild = "ui_chest_3x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 120,
    },
    acceptsstacks = false,
    type = "cooker",
}

params.offering_pot_upgraded.itemtestfn = params.offering_pot.itemtestfn

--------------------------------------------------------------------------
--[[ merm_toolshed ]]
--------------------------------------------------------------------------

params.merm_toolshed =
{
    widget =
    {
        slotpos =
        {
            Vector3(0,   32 + 4,  0),
            Vector3(0, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "inv_slot_twigs.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_rocks.tex", atlas = "images/hud2.xml" },
        },
        animbank = "ui_chest_1x2",
        animbuild = "ui_chest_1x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
        opensound = "meta4/mermery/open",
        closesound = "meta4/mermery/close",
    },
    usespecificslotsforitems = true,
    type = "cooker",
}

function params.merm_toolshed.itemtestfn(container, item, slot)
    return
        not container.inst:HasTag("burnt") and (
            (slot == 1 and item.prefab == "twigs") or
            (slot == 2 and item.prefab == "rocks") or
            (slot == nil and (item.prefab == "twigs" or item.prefab == "rocks"))
        )
end

params.merm_toolshed_upgraded = deepcopy(params.merm_toolshed)

--------------------------------------------------------------------------
--[[ merm_armory ]]
--------------------------------------------------------------------------

params.merm_armory = deepcopy(params.merm_toolshed)

params.merm_armory.widget.slotbg =
{
    { image = "inv_slot_log.tex",       atlas = "images/hud2.xml" },
    { image = "inv_slot_cutgrass.tex" , atlas = "images/hud2.xml"},
}

function params.merm_armory.itemtestfn(container, item, slot)
    return
        not container.inst:HasTag("burnt") and (
            (slot == 1 and item.prefab == "log") or
            (slot == 2 and item.prefab == "cutgrass") or
            (slot == nil and (item.prefab == "log" or item.prefab == "cutgrass"))
        )
end

params.merm_armory_upgraded = deepcopy(params.merm_armory)

--------------------------------------------------------------------------
--[[ livingtree_halloween ]]
--------------------------------------------------------------------------

params.livingtree_halloween =
{
    widget =
    {
        slotpos =
        {
            Vector3(-(64 + 12), 0, 0),
            Vector3(0, 0, 0),
            Vector3(64 + 12, 0, 0),
        },
        animbank = "ui_chest_3x1",
        animbuild = "ui_chest_3x1",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.livingtree_halloween.itemtestfn(container, item, slot)
    return item:HasTag("halloween_ornament") and not container.inst:HasTag("burnt")
end

--------------------------------------------------------------------------
--[[ icebox ]]
--------------------------------------------------------------------------

params.icebox =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(params.icebox.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
    end
end

function params.icebox.itemtestfn(container, item, slot)
    if item:HasTag("icebox_valid") then
        return true
    end

    --Perishable
    if not (item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled")) then
        return false
    end

	if item:HasTag("smallcreature") then
		return false
	end

    --Edible
    for k, v in pairs(FOODTYPE) do
        if item:HasTag("edible_"..v) then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------
--[[ saltbox ]]
--------------------------------------------------------------------------

params.saltbox = deepcopy(params.icebox)

function params.saltbox.itemtestfn(container, item, slot)
	return ((item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled"))
		and item:HasTag("cookable")
		and not item:HasTag("deployable")
		and not item:HasTag("smallcreature")
		and item.replica.health == nil)
		or item:HasTag("saltbox_valid")
end

--------------------------------------------------------------------------
--[[ krampus_sack ]]
--------------------------------------------------------------------------

params.krampus_sack =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_krampusbag_2x8",
        animbuild = "ui_krampusbag_2x8",
        --pos = Vector3(-5, -120, 0),
        pos = Vector3(-5, -130, 0),
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
}

for y = 0, 6 do
    table.insert(params.krampus_sack.widget.slotpos, Vector3(-162, -75 * y + 240, 0))
    table.insert(params.krampus_sack.widget.slotpos, Vector3(-162 + 75, -75 * y + 240, 0))
end

--------------------------------------------------------------------------
--[[ piggyback ]]
--------------------------------------------------------------------------

params.piggyback =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_piggyback_2x6",
        animbuild = "ui_piggyback_2x6",
--        pos = Vector3(-5, -50, 0),
        pos = Vector3(-5, -90, 0),
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
}

for y = 0, 5 do
    table.insert(params.piggyback.widget.slotpos, Vector3(-162, -75 * y + 170, 0))
    table.insert(params.piggyback.widget.slotpos, Vector3(-162 + 75, -75 * y + 170, 0))
end

--------------------------------------------------------------------------
--[[ teleportato ]]
--------------------------------------------------------------------------

params.teleportato_base =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 32 + 8 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(0, -(64 + 32 + 8 + 4), 0),
        },
        animbank = "ui_cookpot_1x4",
        animbuild = "ui_cookpot_1x4",
        pos = Vector3(0, 0, 0),
        side_align_tip = 100,
        buttoninfo =
        {
            text = STRINGS.ACTIONS.ACTIVATE.GENERIC,
            position = Vector3(0, -165, 0),
        },
    },
    type = "cooker",
}

function params.teleportato_base.itemtestfn(container, item, slot)
    return not item:HasTag("nonpotatable")
end

function params.teleportato_base.widget.buttoninfo.fn(inst, doer)
    --see teleportato.lua, not supported in multiplayer yet
    --CheckNextLevelSure(inst, doer)
end

--------------------------------------------------------------------------
--[[ balatro machine ]]
--------------------------------------------------------------------------

params.balatro_machine =
{
    widget =
    {
        slotpos =
        {
           -- Vector3(0, 64 + 32 + 8 + 4 + 80, 0),
           -- Vector3(0, 64 + 32 + 8 + 4, 0),
           -- Vector3(0, 32 + 4, 0),
           -- Vector3(0, -(32 + 4), 0),
           -- Vector3(0, -(64 + 32 + 8 + 4), 0),

            Vector3(0, 0, 0),
            Vector3(68, 0, 0),
            Vector3(68+68, 0, 0),
            Vector3(68+68+68, 0, 0),
            Vector3(68+68+68+68, 0, 0),

        },
        slotbg =
        {
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },
            { image = "sisturn_slot_petals.tex" },            
        },        
        animbank = "ui_cookpot_1x4",
        animbuild = "ui_cookpot_1x4",
        pos = Vector3(100, 0, 0),
        buttoninfo =
        {
            text = STRINGS.ACTIONS.ACTIVATE.GENERIC,
            position = Vector3(68+68, -68, 0),
        },        
    },
    acceptsstacks = false,
    type = "cooker",
    openlimit = 1,
}

function params.balatro_machine.itemtestfn(container, item, slot)
    return not container.inst:HasTag("burnt") --and item.prefab == "kelp"
end

function params.balatro_machine.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.ACTIVATE_CONTAINER):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.ACTIVATE_CONTAINER.code, inst, ACTIONS.ACTIVATE_CONTAINER.mod_name)
    end
end
--[[
function params.balatro_machine.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and inst.replica.container:IsFull()
end
]]


--------------------------------------------------------------------------
--[[ treasurechest ]]
--------------------------------------------------------------------------

params.treasurechest =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        animbank_upgraded = "ui_chest_upgraded_3x3",
        animbuild_upgraded = "ui_chest_upgraded_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(params.treasurechest.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
    end
end

params.pandoraschest = params.treasurechest
params.chest_mimic = params.pandoraschest
params.skullchest = params.treasurechest
params.terrariumchest = params.treasurechest

params.quagmire_safe = deepcopy(params.treasurechest)
params.quagmire_safe.widget.animbank = "quagmire_ui_chest_3x3"
params.quagmire_safe.widget.animbuild = "quagmire_ui_chest_3x3"

params.boat_ancient_container = deepcopy(params.treasurechest)
params.boat_ancient_container.widget.animbank = "ui_boat_ancient_4x4"
params.boat_ancient_container.widget.animbuild = "ui_boat_ancient_4x4"
params.boat_ancient_container.widget.slotpos = {}

for y = 3, 0, -1 do
    for x = 0, 3 do
        table.insert(params.boat_ancient_container.widget.slotpos, Vector3(80 * x - 80 * 2.5 + 80, 80 * y - 80 * 2.5 + 80, 0))
    end
end

--------------------------------------------------------------------------
--[[ dragonflychest ]]
--------------------------------------------------------------------------

params.minotaurchest = params.shadowchester
params.dragonflychest = deepcopy(params.shadowchester)
params.dragonflychest.widget.animbank_upgraded = "ui_chester_upgraded_3x4"
params.dragonflychest.widget.animbuild_upgraded = "ui_chester_upgraded_3x4"

--------------------------------------------------------------------------
--[[ antlionhat ]]
--------------------------------------------------------------------------

params.antlionhat =
{
    widget =
    {
        slotpos = {
            Vector3(0, 2, 0),
        },
        slotbg =
        {
            { image = "turf_slot.tex", atlas = "images/hud2.xml" },
        },
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        pos = Vector3(106, 40, 0),
    },
    type = "hand_inv",
    excludefromcrafting = true,
}

function params.antlionhat.itemtestfn(container, item, slot)
    return item:HasTag("groundtile") and item.tile
end

--------------------------------------------------------------------------
--[[ fish_box ]]
--------------------------------------------------------------------------

params.fish_box =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_fish_box_5x4",
        animbuild = "ui_fish_box_5x4",
        pos = Vector3(0, 220, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 2.5, -0.5, -1 do
    for x = -1, 3 do
        table.insert(params.fish_box.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75, 0))
    end
end

function params.fish_box.itemtestfn(container, item, slot)
    return item:HasTag("smalloceancreature")
end


--------------------------------------------------------------------------
--[[ ocean fishing rod ]]
--------------------------------------------------------------------------

params.oceanfishingrod =
{
    widget =
    {
        slotpos =
        {
            Vector3(0,   32 + 4,  0),
            Vector3(0, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "fishing_slot_bobber.tex" },
            { image = "fishing_slot_lure.tex" },
        },
        animbank = "ui_cookpot_1x2",
        animbuild = "ui_cookpot_1x2",
        pos = Vector3(0, 60, 0),
    },
    acceptsstacks = false,
    usespecificslotsforitems = true,
    type = "hand_inv",
    excludefromcrafting = true,
}

function params.oceanfishingrod.itemtestfn(container, item, slot)
	return (slot == nil and (item:HasTag("oceanfishing_bobber") or item:HasTag("oceanfishing_lure")))
		or (slot == 1 and item:HasTag("oceanfishing_bobber"))
		or (slot == 2 and item:HasTag("oceanfishing_lure"))
end


--------------------------------------------------------------------------
--[[ beard ]]
--------------------------------------------------------------------------

params.beard_sack_1 =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 0, 0),
        },
        slotbg =
        {
            { image = "inv_slot_morsel.tex" },
        },
        animbank = "ui_beard_1x1",
        animbuild = "ui_beard_1x1",
        pos = Vector3(-82, 89, 0),
        bottom_align_tip = -100,
    },
    type = "side_inv_behind",
    acceptsstacks = true,
    lowpriorityselection = true,
   -- excludefromcrafting = false,
}

function params.beard_sack_1.itemtestfn(container, item, slot)
    --Edible
    for k, v in pairs(FOODGROUP.OMNI.types) do
        if item:HasTag("edible_"..v) then
            return true
        end
    end
      
end

params.beard_sack_2 =
{
    widget =
    {
        slotpos =
        {
            Vector3(-(64 + 12)/2, 0, 0),
            Vector3( (64 + 12)/2, 0, 0),
        },
        slotbg =
        {
            { image = "inv_slot_morsel.tex" },
            { image = "inv_slot_morsel.tex" },
        },
        animbank = "ui_beard_2x1",
        animbuild = "ui_beard_2x1",
        pos = Vector3(-82, 89, 0),
        bottom_align_tip = -100,
    },
    type = "side_inv_behind",
    acceptsstacks = true,
    lowpriorityselection = true,
   -- excludefromcrafting = false,
}

function params.beard_sack_2.itemtestfn(container, item, slot)
    --Edible
    for k, v in pairs(FOODGROUP.OMNI.types) do
        if item:HasTag("edible_"..v) then
            return true
        end
    end
end

params.beard_sack_3 =
{
    widget =
    {
        slotpos =
        {
            Vector3(-(64 + 12), 0, 0),
            Vector3(0, 0, 0),
            Vector3(64 + 12, 0, 0),
        },
        slotbg =
        {
            { image = "inv_slot_morsel.tex" },
            { image = "inv_slot_morsel.tex" },
            { image = "inv_slot_morsel.tex" },
        },
        animbank = "ui_beard_3x1",
        animbuild = "ui_beard_3x1",
        pos = Vector3(-82, 89, 0),
        bottom_align_tip = -100,
    },
    type = "side_inv_behind",
    acceptsstacks = true,
    lowpriorityselection = true,
   -- excludefromcrafting = false,
}

function params.beard_sack_3.itemtestfn(container, item, slot)
    --Edible
    for k, v in pairs(FOODGROUP.OMNI.types) do
        if item:HasTag("edible_"..v) then
            return true
        end
    end
end

--------------------------------------------------------------------------
--[[ slingshot ]]
--[[ slingshotex ]]
--[[ slingshot2 ]]
--[[ slingshot2ex ]]
--------------------------------------------------------------------------

params.slingshot =
{
    widget =
    {
        slotpos =
        {
            Vector3(0,   32 + 4,  0),
        },
        slotbg =
        {
            { image = "slingshot_ammo_slot.tex" },
        },
        animbank = "ui_cookpot_1x2",
        animbuild = "ui_cookpot_1x2",
        pos = Vector3(0, 15, 0),
    },
    type = "hand_inv",
    excludefromcrafting = true,
}

params.slingshotex = deepcopy(params.slingshot)
params.slingshotex.widget.animbank = "ui_slingshot_wagpunk_0"
params.slingshotex.widget.animbuild = "ui_slingshot_wagpunk_0"

params.slingshot999ex = deepcopy(params.slingshotex)
params.slingshot999ex.widget.animbank = "ui_slingshot_wagpunk"
params.slingshot999ex.widget.animbuild = "ui_slingshot_wagpunk"

params.slingshot2 =
{
	widget =
	{
		slotpos =
		{
			--reversed so bottom is slot 1
			Vector3(0, 32 + 4, 0),
			Vector3(0, 64 + 32 + 8 + 4, 0),
		},
		slotbg =
		{
			{ image = "slingshot_ammo_slot.tex" },
			{ image = "slingshot_ammo_slot.tex" },
		},
		animbank = "ui_slingshot_bone",
		animbuild = "ui_slingshot_bone",
		pos = Vector3(0, 15, 0),
	},
	type = "hand_inv",
	excludefromcrafting = true,
}

params.slingshot2ex = deepcopy(params.slingshot2)
params.slingshot2ex.widget.animbank = "ui_slingshot_gems"
params.slingshot2ex.widget.animbuild = "ui_slingshot_gems"
params.slingshot2ex.widget.slotpos[2].y = 64 + 32 + 8 + 4 + 32

function params.slingshot.itemtestfn(container, item, slot)
	if item.REQUIRED_SKILL then
		local owner
		if TheWorld.ismastersim then
			owner = container.inst.components.container:GetOpeners()[1]
		elseif ThePlayer and container:IsOpenedBy(ThePlayer) then
			owner = ThePlayer
		end
		--NOTE: can have no owner when loading, or when replacing slingshots when swapping frames
		if owner and not (owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated(item.REQUIRED_SKILL)) then
			return false
		end
	end
	return item:HasTag("slingshotammo")
end

params.slingshotex.itemtestfn = params.slingshot.itemtestfn
params.slingshot999ex.itemtestfn = params.slingshot.itemtestfn
params.slingshot2.itemtestfn = params.slingshot.itemtestfn
params.slingshot2ex.itemtestfn = params.slingshot.itemtestfn

--------------------------------------------------------------------------
--[[ slingshotmodscontainer ]]
--------------------------------------------------------------------------

params.slingshotmodscontainer =
{
	widget =
	{
		slotpos =
		{
			Vector3(220, 125, 0),	--band
			Vector3(20, -60, 0),	--frame
			Vector3(220, -150, 0),	--handle
		},
		slotbg =
		{
			{ image = "inv_slot_sketchy.tex", atlas = "images/hud2.xml" },
			{ image = "inv_slot_sketchy.tex", atlas = "images/hud2.xml" },
			{ image = "inv_slot_sketchy.tex", atlas = "images/hud2.xml" },
		},
		slotscale = 1.6,
		slothighlightscale = 1.75,
		animbank = "ui_slingshotmods",
		animbuild = "ui_slingshotmods",
		pos = Vector3(200, 0, 0),
		side_align_tip = 100,
		--V2C: -override the default widget sound, which is heard only by the client
		--     -most containers disable the client sfx via skipopensnd/skipclosesnd,
		--      and play it in world space through the prefab instead.
		opensound = "meta5/walter/slingshot_UI_open_close",
		closesound = "meta5/walter/slingshot_UI_open_close",
		--
	},
	usespecificslotsforitems = true,
	acceptsstacks = false,
	type = "cooker",
	openlimit = 1,
}

function params.slingshotmodscontainer.itemtestfn(container, item, slot)
	if item.REQUIRED_SKILL then
		local owner
		if TheWorld.ismastersim then
			owner = container.inst.components.container:GetOpeners()[1]
		elseif ThePlayer and container:IsOpenedBy(ThePlayer) then
			owner = ThePlayer
		end
		--NOTE: can have no owner when loading
		if owner and not (owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated(item.REQUIRED_SKILL)) then
			return false
		end
	end

	if slot == 1 then
		return item:HasTag("slingshot_band")
	elseif slot == 2 then
		return item:HasTag("slingshot_frame")
	elseif slot == 3 then
		return item:HasTag("slingshot_handle")
	elseif slot == nil then
		return item:HasAnyTag("slingshot_band", "slingshot_frame", "slingshot_handle")
	end
	return false
end

--------------------------------------------------------------------------
--[[ tacklecontainer ]]
--------------------------------------------------------------------------

params.tacklecontainer =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_tacklecontainer_3x2",
        animbuild = "ui_tacklecontainer_3x2",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 1, 0, -1 do
    for x = 0, 2 do
        table.insert(params.tacklecontainer.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 120, 0))
    end
end

function params.tacklecontainer.itemtestfn(container, item, slot)
	return item:HasTag("oceanfishing_bobber") or item:HasTag("oceanfishing_lure")
end


--------------------------------------------------------------------------
--[[ supertacklecontainer ]]
--------------------------------------------------------------------------

params.supertacklecontainer =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_tacklecontainer_3x5",
        animbuild = "ui_tacklecontainer_3x5",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 1, -3, -1 do
    for x = 0, 2 do
        table.insert(params.supertacklecontainer.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 45, 0))
    end
end

params.supertacklecontainer.itemtestfn = params.tacklecontainer.itemtestfn

--------------------------------------------------------------------------
--[[ sunkenchest ]]
--------------------------------------------------------------------------
-- Sunken Chest is an actual container though it can not be opened it often reaches capacity from it's old container data (3x3) we have moved to 3x5 now
-- We can deepcopy supertacklecontainer and set itemtestfn but I am making a entirely new definition to ensure it is not potentially messed with

params.sunkenchest =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_tacklecontainer_3x5",
        animbuild = "ui_tacklecontainer_3x5",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 1, -3, -1 do
    for x = 0, 2 do
        table.insert(params.sunkenchest.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 45, 0))
    end
end

--------------------------------------------------------------------------
--[[ sacred_chest ]]
--------------------------------------------------------------------------

params.sacred_chest =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chest_3x2",
        animbuild = "ui_chest_3x2",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 1, 0, -1 do
    for x = 0, 2 do
        table.insert(params.sacred_chest.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 120, 0))
    end
end

--------------------------------------------------------------------------
--[[ seedpouch ]]
--------------------------------------------------------------------------

params.seedpouch =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_krampusbag_2x8",
        animbuild = "ui_krampusbag_2x8",
        pos = Vector3(-5, -130, 0),
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
}

for y = 0, 6 do
    table.insert(params.seedpouch.widget.slotpos, Vector3(-162, -75 * y + 240, 0))
    table.insert(params.seedpouch.widget.slotpos, Vector3(-162 + 75, -75 * y + 240, 0))
end

function params.seedpouch.itemtestfn(container, item, slot)
    return item.prefab == "seeds" or string.match(item.prefab, "_seeds") or item:HasTag("treeseed")
end

params.seedpouch.priorityfn = params.seedpouch.itemtestfn

--------------------------------------------------------------------------
--[[ candybag ]]
--------------------------------------------------------------------------

params.candybag =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_krampusbag_2x8",
        animbuild = "ui_krampusbag_2x8",
        pos = Vector3(-5, -130, 0),
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
}

for y = 0, 6 do
    table.insert(params.candybag.widget.slotpos, Vector3(-162, -75 * y + 240, 0))
    table.insert(params.candybag.widget.slotpos, Vector3(-162 + 75, -75 * y + 240, 0))
end

function params.candybag.itemtestfn(container, item, slot)
    return item:HasTag("halloweencandy") or item:HasTag("halloween_ornament") or string.sub(item.prefab, 1, 8) == "trinket_"
end

params.candybag.priorityfn = params.candybag.itemtestfn

--------------------------------------------------------------------------
--[[ alterguardianhatshard ]]
--------------------------------------------------------------------------

params.alterguardianhatshard =
{
    widget =
    {
        slotpos = {
            Vector3(-2, 18, 0),
        },
        slotbg =
        {
            { image = "spore_slot.tex", atlas = "images/hud2.xml" },
        },
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        pos = Vector3(0, 160, 0),
    },
    acceptsstacks = false,
    type = "chest",
}

function params.alterguardianhatshard.itemtestfn(container, item, slot)
    return item:HasTag("spore")
end

--------------------------------------------------------------------------
--[[ alterguardianhat ]]
--------------------------------------------------------------------------

params.alterguardianhat =
{
    widget =
    {
        slotpos = {},
        slotbg = {},
        animbank = "ui_alterguardianhat_1x6",
        animbuild = "ui_alterguardianhat_1x6",
        pos = Vector3(106, 150, 0),
    },
    acceptsstacks = false,
    type = "hand_inv",
    excludefromcrafting = true,
}

local AGHAT_SLOTSTART = 95
local AGHAT_SLOTDIFF = 72
local SLOT_BG = { image = "spore_slot.tex", atlas = "images/hud2.xml" }
for i = 0, 4 do
    local sp = Vector3(0, AGHAT_SLOTSTART - (i*AGHAT_SLOTDIFF), 0)
    table.insert(params.alterguardianhat.widget.slotpos, sp)
    table.insert(params.alterguardianhat.widget.slotbg, SLOT_BG)
end

local ALTERGUARDIANHAT_ITEMS = {"spore", "lunarseed"}
function params.alterguardianhat.itemtestfn(container, item, slot)
    return item:HasAnyTag(ALTERGUARDIANHAT_ITEMS)
end

--------------------------------------------------------------------------
--[[ pocketwatch ]]
--------------------------------------------------------------------------

params.pocketwatch =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_tacklecontainer_3x2",
        animbuild = "ui_tacklecontainer_3x2",
        pos = Vector3(-850, 100, 0),
        side_align_tip = 100,
    },
    type = "hand_inv",
    excludefromcrafting = true,
}

for y = 1, 0, -1 do
    for x = 0, 2 do
        table.insert(params.pocketwatch.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 120, 0))
    end
end

function params.pocketwatch.itemtestfn(container, item, slot)
	return item:HasTag("pocketwatchpart")
end

--------------------------------------------------------------------------
--[[ ocean_trawler ]]
--------------------------------------------------------------------------

params.ocean_trawler =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 100, 0),
            Vector3(0, 20, 0),
            Vector3(0, -60, 0),
            Vector3(0, -140, 0),
        },
        animbank = "ui_cookpot_1x4",
        animbuild = "ui_cookpot_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.ocean_trawler.itemtestfn(container, item, slot)
    return item:HasTag("cookable") or item:HasTag("oceanfish")
end

--------------------------------------------------------------------------
--[[ bookstation ]]
--------------------------------------------------------------------------

params.bookstation =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_bookstation_4x5",
        animbuild = "ui_bookstation_4x5",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 0, 4 do
    table.insert(params.bookstation.widget.slotpos, Vector3(-114      , (-77 * y) + 37 - (y * 2), 0))
    table.insert(params.bookstation.widget.slotpos, Vector3(-114 + 75 , (-77 * y) + 37 - (y * 2), 0))
    table.insert(params.bookstation.widget.slotpos, Vector3(-114 + 150, (-77 * y) + 37 - (y * 2), 0))
    table.insert(params.bookstation.widget.slotpos, Vector3(-114 + 225, (-77 * y) + 37 - (y * 2), 0))
end

function params.bookstation.itemtestfn(container, item, slot)
    return item:HasTag("bookcabinet_item")
end

--------------------------------------------------------------------------
--[[ beargerfur_sack ]]
--------------------------------------------------------------------------

params.beargerfur_sack =
{
    widget =
    {
        slotpos = {},
        slotbg  = {},
        animbank  = "ui_icepack_2x3",
        animbuild = "ui_icepack_2x3",
        pos = Vector3(75, 195, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 0, 2 do
    for x = 0, 1 do
        table.insert(params.beargerfur_sack.widget.slotpos, Vector3(-163 + (75 * x),   -75 * y + 73,   0))
        table.insert(params.beargerfur_sack.widget.slotbg, { image = "preparedfood_slot.tex", atlas = "images/hud2.xml" })
    end
end

function params.beargerfur_sack.itemtestfn(container, item, slot)
    -- Prepared food.
    return item:HasTag("beargerfur_sack_valid") or item:HasTag("preparedfood")
end

--------------------------------------------------------------------------
--[[ houndstooth_blowpipe ]]
--------------------------------------------------------------------------

params.houndstooth_blowpipe = deepcopy(params.slingshot)

params.houndstooth_blowpipe.widget.slotbg = {{ image = "houndstooth_ammo_slot.tex", atlas = "images/hud2.xml" }}

function params.houndstooth_blowpipe.itemtestfn(container, item, slot)
	return item:HasTag("blowpipeammo")
end

--------------------------------------------------------------------------
--[[ battlesong_container ]]
--------------------------------------------------------------------------

params.battlesong_container =
{
    widget =
    {
        slotpos = {},
        slotbg  = {},
        animbank  = "ui_backpack_2x4",
        animbuild = "ui_backpack_2x4",
        pos = Vector3(75, 195, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

local battlesong_container_bg = { image = "battlesong_slot.tex", atlas = "images/hud2.xml" }

for y = 0, 3 do
    table.insert(params.battlesong_container.widget.slotpos, Vector3(-162     , -75 * y + 114, 0))
    table.insert(params.battlesong_container.widget.slotpos, Vector3(-162 + 75, -75 * y + 114, 0))

    table.insert(params.battlesong_container.widget.slotbg, battlesong_container_bg)
    table.insert(params.battlesong_container.widget.slotbg, battlesong_container_bg)
end

function params.battlesong_container.itemtestfn(container, item, slot)
    -- Battlesongs.
    return item:HasTag("battlesong")
end

--------------------------------------------------------------------------
--[[ wortox_souljar ]]
--------------------------------------------------------------------------

params.wortox_souljar =
{
    widget =
    {
        slotpos = {
            Vector3(-2, 18, 0),
        },
        slotbg  = {
            {image = "soul_slot.tex", atlas = "images/hud2.xml"},
        },
        animbank  = "ui_wortox_souljar_1x1",
        animbuild = "ui_wortox_souljar_1x1",
        pos = Vector3(0, 195, 0),
        side_align_tip = 160,
        opensound = "meta5/wortox/souljar_lid_pop",
        closesound = "meta5/wortox/souljar_close_pop",
    },
    type = "chest",
}

function params.wortox_souljar.itemtestfn(container, item, slot)
    return item:HasTag("soul") and not item:HasTag("nosouljar")
end

--------------------------------------------------------------------------
--[[ wendy_elixir_container ]]
--------------------------------------------------------------------------

params.elixir_container =
{
    widget =
    {
        slotpos = {},
        slotbg  = {},
        animbank  = "ui_elixir_container_3x3",
        animbuild = "ui_elixir_container_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

local elixir_container_bg = { image = "elixir_slot.tex", atlas = "images/hud2.xml" }

for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(params.elixir_container.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
        table.insert(params.elixir_container.widget.slotbg, elixir_container_bg)
    end
end

function params.elixir_container.itemtestfn(container, item, slot)
    return item:HasTag("ghostlyelixir") or item:HasTag("ghostflower")
end

--------------------------------------------------------------------------
--[[ dragonflyfurnace ]]
--------------------------------------------------------------------------

params.dragonflyfurnace =
{
    widget =
    {
        slotpos =
        {
            Vector3(-37.5,   32 + 4,  0),
            Vector3( 37.5,   32 + 4,  0),
            Vector3(-37.5, -(32 + 4), 0),
            Vector3( 37.5, -(32 + 4), 0),
        },
        slotbg =
        {
            { image = "inv_slot_dragonflyfurnace.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_dragonflyfurnace.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_dragonflyfurnace.tex", atlas = "images/hud2.xml" },
            { image = "inv_slot_dragonflyfurnace.tex", atlas = "images/hud2.xml" },
        },
        animbank = "ui_dragonflyfurnace_2x2",
        animbuild = "ui_dragonflyfurnace_2x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 120,
        buttoninfo =
        {
            text = STRINGS.ACTIONS.INCINERATE,
            position = Vector3(0, -100, 0),
        }
    },
    type = "cooker",
}

function params.dragonflyfurnace.itemtestfn(container, item, slot)
    return not item:HasTag("irreplaceable")
end

function params.dragonflyfurnace.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.INCINERATE):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.INCINERATE.code, inst, ACTIONS.INCINERATE.mod_name)
    end
end

function params.dragonflyfurnace.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and not inst.replica.container:IsEmpty()
end

--------------------------------------------------------------------------
--[[ slingshotammo_container ]]
--------------------------------------------------------------------------

params.slingshotammo_container =
{
    widget =
    {
        slotpos = {},
        slotbg  = {},
        animbank  = "ui_slingshotammo_container_3x2",
        animbuild = "ui_slingshotammo_container_3x2",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

local slingshotammo_container_bg = { image = "slingshot_ammo_slot.tex" }

for y = 1, 0, -1 do
    for x = 0, 2 do
        table.insert(params.slingshotammo_container.widget.slotpos, Vector3(90 * x - 90, 80 * y - 42.5, 0))
        table.insert(params.slingshotammo_container.widget.slotbg, slingshotammo_container_bg)
    end
end

function params.slingshotammo_container.itemtestfn(container, item, slot)
    return item:HasTag("slingshotammo")
end

--------------------------------------------------------------------------
--[[ quagmire_pot ]]
--------------------------------------------------------------------------

params.quagmire_pot =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 32 + 8 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(0, -(64 + 32 + 8 + 4), 0),
        },
        animbank = "quagmire_ui_pot_1x4",
        animbuild = "quagmire_ui_pot_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.quagmire_pot.itemtestfn(container, item, slot)
    return item:HasTag("quagmire_stewable")
        and item.prefab ~= "quagmire_sap"
        and ((item.components.inventoryitem ~= nil and not item.components.inventoryitem:IsHeld()) or
            not (item.prefab == "spoiled_food" or item:HasTag("preparedfood") or item:HasTag("overcooked") or container.inst:HasTag("takeonly")))
end

--------------------------------------------------------------------------
--[[ quagmire_pot_small ]]
--------------------------------------------------------------------------

params.quagmire_pot_small =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 8, 0),
            Vector3(0, 0, 0),
            Vector3(0, -(64 + 8), 0),
        },
        animbank = "quagmire_ui_pot_1x3",
        animbuild = "quagmire_ui_pot_1x3",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

params.quagmire_pot_small.itemtestfn = params.quagmire_pot.itemtestfn

--------------------------------------------------------------------------
--[[ quagmire_casseroledish ]]
--------------------------------------------------------------------------

params.quagmire_casseroledish = params.quagmire_pot

--------------------------------------------------------------------------
--[[ quagmire_casseroledish_small ]]
--------------------------------------------------------------------------

params.quagmire_casseroledish_small = params.quagmire_pot_small

--------------------------------------------------------------------------
--[[ quagmire_grill ]]
--------------------------------------------------------------------------

params.quagmire_grill = params.quagmire_pot

--------------------------------------------------------------------------
--[[ quagmire_grill_small ]]
--------------------------------------------------------------------------

params.quagmire_grill_small = params.quagmire_pot_small

--------------------------------------------------------------------------
--[[ quagmire_pot_syrup ]]
--------------------------------------------------------------------------

params.quagmire_pot_syrup =
{
    widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 8, 0),
            Vector3(0, 0, 0),
            Vector3(0, -(64 + 8), 0),
        },
        animbank = "quagmire_ui_pot_1x3",
        animbuild = "quagmire_ui_pot_1x3",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
    },
    acceptsstacks = false,
    type = "cooker",
}

function params.quagmire_pot_syrup.itemtestfn(container, item, slot)
    return item:HasTag("quagmire_stewable")
        and ((item.components.inventoryitem ~= nil and not item.components.inventoryitem:IsHeld()) or
            (item.prefab == "quagmire_sap" and not container.inst:HasTag("takeonly")))
end

--------------------------------------------------------------------------
--[[ quagmire_backpack_small ]]
--------------------------------------------------------------------------

params.quagmire_backpack_small =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(-50, -450, 0),
        side_align_tip = 100,
    },
    type = "backpack",
}

for x = 0, 3 do
    table.insert(params.quagmire_backpack_small.widget.slotpos, Vector3(-x * 75 - 75*.5, 120, 0))
end

--------------------------------------------------------------------------
--[[ quagmire_backpack ]]
--------------------------------------------------------------------------

params.quagmire_backpack =
{
    widget =
    {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(-50, -450, 0),
        side_align_tip = 100,
    },
    type = "backpack",
}

for x = 0, 7 do
    table.insert(params.quagmire_backpack.widget.slotpos, Vector3(-x * 75 - 75*.5, 120, 0))
end

--------------------------------------------------------------------------

for k, v in pairs(params) do
    containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end

--------------------------------------------------------------------------

return containers
