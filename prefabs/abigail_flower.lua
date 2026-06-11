local assets =
{
    Asset("ANIM", "anim/abigail_flower.zip"),
    Asset("ANIM", "anim/abigail_flower_rework.zip"),

	Asset("INV_IMAGE", "abigail_flower_level0"),
	Asset("INV_IMAGE", "abigail_flower_level2"),
	Asset("INV_IMAGE", "abigail_flower_level3"),

	Asset("SCRIPT", "scripts/prefabs/ghostcommand_defs.lua"),

    Asset("INV_IMAGE", "abigail_flower_old"),		-- deprecated, left in for mods
    Asset("INV_IMAGE", "abigail_flower2"),			-- deprecated, left in for mods
    Asset("INV_IMAGE", "abigail_flower_haunted"),	-- deprecated, left in for mods
    Asset("INV_IMAGE", "abigail_flower_wilted"),	-- deprecated, left in for mods
}

local EMPTY_TABLE = {}

local GHOSTCOMMAND_DEFS = require("prefabs/ghostcommand_defs")
local GetGhostCommandsFor = GHOSTCOMMAND_DEFS.GetGhostCommandsFor
local function updatespells(inst, owner)
	if owner then
		if owner.HUD then owner.HUD:CloseSpellWheel() end
		inst.components.spellbook:SetItems(GetGhostCommandsFor(owner))
	else
		inst.components.spellbook:SetItems(EMPTY_TABLE)
	end
end

local function DoClientUpdateSpells(inst, force)
	local owner = (inst.replica.inventoryitem:IsHeld() and ThePlayer) or nil
	if owner ~= inst._owner then
		if owner then
			updatespells(inst, owner)
		end

		if inst._owner then
			inst:RemoveEventCallback("onactivateskill_client", inst._onskillrefresh_client, inst._owner)
			inst:RemoveEventCallback("ondeactivateskill_client", inst._onskillrefresh_client, inst._owner)
		end
		inst._owner = owner
		if owner then
			inst:ListenForEvent("onactivateskill_client", inst._onskillrefresh_client, owner)
			inst:ListenForEvent("ondeactivateskill_client", inst._onskillrefresh_client, owner)
		end
	elseif force and owner then
		updatespells(inst, owner)
	end
end

local function OnUpdateSpellsDirty(inst)
	inst:DoTaskInTime(0, DoClientUpdateSpells, true)
end

--
local function UpdateGroundAnimation(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
    local players = {}
	if not POPULATING then
		for _, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and v.components.ghostlybond
					and (v.sg == nil or not v.sg:HasStateTag("ghostbuild"))
					and v.entity:IsVisible() and v:HasTag("ghostlyfriend") then
				local dist = v:GetDistanceSqToPoint(x, y, z)
				if dist < TUNING.ABIGAIL_FLOWER_PROX_DIST then
					table.insert(players, {player = v, dist = dist})
				end
			end
		end
	end

	if #players > 1 then
		table.sort(players, function(a, b) return a.dist < b.dist end)
	end

	local level = players[1] ~= nil and players[1].player.components.ghostlybond.bondlevel or 0
	if inst._bond_level ~= level then
		if inst._bond_level == 0 then
			inst.AnimState:PlayAnimation("level"..level.."_pre")
			inst.AnimState:PushAnimation("level"..level.."_loop", true)
			inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/haunted_flower_LP", "floating")
		elseif inst._bond_level > 0 and level == 0 then
			inst.AnimState:PlayAnimation("level"..inst._bond_level.."_pst")
			inst.AnimState:PushAnimation("level0_loop", true)
            inst.SoundEmitter:KillSound("floating")
		else
			inst.AnimState:PlayAnimation("level"..level.."_loop", true)
			inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/haunted_flower_LP", "floating")
		end
	end

	inst._bond_level = level
end


local function OnOwnerUpdated(inst, owner)
    if owner ~= nil and owner.components.container ~= nil then
        -- We've been moved from an equipped backpack into a different container.
        if inst._container ~= nil and
            owner ~= inst._container and
            (inst._container.components.equippable ~= nil and inst._container.components.equippable:IsEquipped())
        then
            inst:RemoveEventCallback("unequipped", inst._onunequipped, inst._container)
        end

        inst._container = owner

        local grandowner = owner.components.inventoryitem ~= nil and owner.components.inventoryitem:GetGrandOwner()

        -- We've been put on an already equipped backpack.
        if owner.components.equippable ~= nil and owner.components.equippable:IsEquipped() and grandowner ~= nil then
            owner = grandowner

            inst:ListenForEvent("unequipped", inst._onunequipped, inst._container)

        -- We've been put on an unnequipped backpack.
        elseif owner.components.equippable ~= nil then
            inst:ListenForEvent("equipped", inst._onequipped, inst._container)

        else
            -- We're in a chest likely
            owner = nil
        end

    -- We've been dropped or put on a regular inventory.
    elseif inst._container ~= nil then
        if inst._container.components.equippable ~= nil and inst._container.components.equippable:IsEquipped() then
            inst:RemoveEventCallback("unequipped", inst._onunequipped, inst._container)
        end

        inst._container = nil
    end

    if owner ~= nil and owner ~= inst._owner then
        if inst._owner ~= nil and not inst._owner:HasTag("backpack") then
			inst:RemoveEventCallback("onactivateskill_server", inst._onskillrefresh_server, inst._owner)
			inst:RemoveEventCallback("ondeactivateskill_server", inst._onskillrefresh_server, inst._owner)
			inst:RemoveEventCallback("ghostlybond_summoncomplete", inst._onsummonstatechanged_server, inst._owner)
			inst:RemoveEventCallback("ghostlybond_recallcomplete", inst._onsummonstatechanged_server, inst._owner)
        end

        inst._owner = owner

		inst._updatespells:push()
		updatespells(inst, inst._owner)

        if not inst._owner:HasTag("backpack") then
            inst:ListenForEvent("onactivateskill_server", inst._onskillrefresh_server, owner)
			inst:ListenForEvent("ondeactivateskill_server", inst._onskillrefresh_server, owner)
			inst:ListenForEvent("ghostlybond_summoncomplete", inst._onsummonstatechanged_server, owner)
			inst:ListenForEvent("ghostlybond_recallcomplete", inst._onsummonstatechanged_server, owner)
        end

    elseif not owner and inst._owner then
        if not inst._owner:HasTag("backpack") then
			inst:RemoveEventCallback("onactivateskill_server", inst._onskillrefresh_server, inst._owner)
			inst:RemoveEventCallback("ondeactivateskill_server", inst._onskillrefresh_server, inst._owner)
			inst:RemoveEventCallback("ghostlybond_summoncomplete", inst._onsummonstatechanged_server, inst._owner)
			inst:RemoveEventCallback("ghostlybond_recallcomplete", inst._onsummonstatechanged_server, inst._owner)
        end

        inst._owner = nil

		inst._updatespells:push()
		updatespells(inst, inst._owner)
    end
end

local function onunequipped(inst, container)
    inst:RemoveEventCallback("unequipped", inst._onunequipped, container)
    inst:OnOwnerUpdated(container)
end

local function onequipped(inst, container, owner)
    inst:RemoveEventCallback("equipped", inst._onequipped, container)
    inst:OnOwnerUpdated(container)
end

local function topocket(inst, owner)
	if inst._ongroundupdatetask ~= nil then
		inst._ongroundupdatetask:Cancel()
		inst._ongroundupdatetask = nil
	end

	inst:OnOwnerUpdated(owner)
end

local function toground(inst)
	inst._bond_level = -1 --to force the animation to update
	UpdateGroundAnimation(inst)
	if inst._ongroundupdatetask == nil then
		inst._ongroundupdatetask = inst:DoPeriodicTask(0.5, UpdateGroundAnimation)
	end

	inst:OnOwnerUpdated()
end

local function OnEntitySleep(inst)
	if inst._ongroundupdatetask ~= nil then
		inst._ongroundupdatetask:Cancel()
		inst._ongroundupdatetask = nil
	end
end

local function OnEntityWake(inst)
	if not inst.inlimbo and inst._ongroundupdatetask == nil then
		inst._ongroundupdatetask = inst:DoPeriodicTask(0.5, UpdateGroundAnimation, math.random()*0.5)
	end
end

local function GetElixirTarget(inst, doer, elixir)
	return (doer ~= nil and doer.components.ghostlybond ~= nil) and doer.components.ghostlybond.ghost or nil
end

local function Server_UpdateSkills(inst, owner)
	inst._updatespells:push()

	updatespells(inst, owner)
end

local function getstatus(inst, viewer)
	local _bondlevel = inst._bond_level
	if inst.components.inventoryitem.owner then
		_bondlevel = viewer ~= nil and viewer.components.ghostlybond ~= nil and viewer.components.ghostlybond.bondlevel
	end
	return _bondlevel == 3 and "LEVEL3"
		or _bondlevel == 2 and "LEVEL2"
		or _bondlevel == 1 and "LEVEL1"
		or nil
end

local function update_skin_overrides(inst)
	local image_name = string.gsub(inst.AnimState:GetBuild(), "abigail_", "abigail_flower_")
	if not inst.clientside_imageoverrides[image_name] then
		inst:SetClientSideInventoryImageOverride("bondlevel0", image_name..".tex", image_name.."_level0.tex")
		inst:SetClientSideInventoryImageOverride("bondlevel2", image_name..".tex", image_name.."_level2.tex")
		inst:SetClientSideInventoryImageOverride("bondlevel3", image_name..".tex", image_name.."_level3.tex")
		inst.clientside_imageoverrides[image_name] = true
	end
end

local function OnSkinIDDirty(inst)
	inst.skin_id = inst.flower_skin_id:value()
	inst:DoTaskInTime(0, update_skin_overrides)
end

local function drawimageoverride(inst)
	local level = inst._bond_level or 0
	local skin_name = (inst:GetSkinName() or "abigail_flower")
	return skin_name .. (level == 1 and "" or ("_level" .. tostring(level)))
end

-- CLIENT-SIDE
local function CLIENT_OnOpenSpellBook(_)
end
local function CLIENT_OnCloseSpellBook(_)
end

local function CLIENT_ReticuleTargetAllowWaterFn()
    local player = ThePlayer
    local ground = TheWorld.Map
    local pos = Vector3()

    for r = 7, 0, -.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
        if ground:IsPassableAtPoint(pos.x, 0, pos.z, true) and not ground:IsGroundTargetBlocked(pos) then
            break
        end
    end
    return pos
end

local SPELLBOOK_RADIUS = 100
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("abigail_flower_rework")
    inst.AnimState:SetBuild("abigail_flower_rework")
    inst.AnimState:PlayAnimation("level0_loop")
    MakeInventoryPhysics(inst)

    inst.scrapbook_deps = {"ghostflower","nightmarefuel"}

    inst.MiniMapEntity:SetIcon("abigail_flower.png")

    MakeInventoryFloatable(inst, "small", 0.15, 0.9)

	inst:AddTag("abigail_flower")
	inst:AddTag("give_dolongaction")
	inst:AddTag("ghostlyelixirable") -- for ghostlyelixirable component

    inst:SetClientSideInventoryImageOverride("bondlevel0", "abigail_flower.tex", "abigail_flower_level0.tex")
    inst:SetClientSideInventoryImageOverride("bondlevel2", "abigail_flower.tex", "abigail_flower_level2.tex")
    inst:SetClientSideInventoryImageOverride("bondlevel3", "abigail_flower.tex", "abigail_flower_level3.tex")

	inst.clientside_imageoverrides = {
		abigail_flower_flower_rework = true
	}

    inst.flower_skin_id = net_hash(inst.GUID, "abi_flower_skin_id", "abiflowerskiniddirty")
	inst:ListenForEvent("abiflowerskiniddirty", OnSkinIDDirty)
	OnSkinIDDirty(inst)

    local spellbook = inst:AddComponent("spellbook")
    spellbook:SetRequiredTag("ghostlyfriend")
    spellbook:SetRadius(SPELLBOOK_RADIUS)
    spellbook:SetFocusRadius(SPELLBOOK_RADIUS)
    spellbook:SetItems(GHOSTCOMMAND_DEFS.GetBaseCommands())
    spellbook:SetOnOpenFn(CLIENT_OnOpenSpellBook)
    spellbook:SetOnCloseFn(CLIENT_OnCloseSpellBook)
    spellbook.opensound = "meta5/wendy/skill_wheel_open"
    spellbook.closesound = "meta5/wendy/skill_wheel_close"

    local aoetargeting = inst:AddComponent("aoetargeting")
    aoetargeting:SetAllowWater(true)
    aoetargeting.reticule.targetfn = CLIENT_ReticuleTargetAllowWaterFn
    aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
    aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
    aoetargeting.reticule.ease = true
    aoetargeting.reticule.mouseenabled = true
    aoetargeting.reticule.twinstickmode = 1
    aoetargeting.reticule.twinstickrange = 15

	inst._updatespells = net_event(inst.GUID, "abigail_flower._updatespells")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst._onskillrefresh_client = function(_) DoClientUpdateSpells(inst, true) end

		inst:ListenForEvent("abigail_flower._updatespells", OnUpdateSpellsDirty)
		OnUpdateSpellsDirty(inst)

		return inst
	end

	inst._onskillrefresh_server = function(owner)
		updatespells(inst, owner)
	end
	inst._onsummonstatechanged_server = function(owner)
		inst._updatespells:push()
		updatespells(inst, owner)
	end

	inst.OnOwnerUpdated = OnOwnerUpdated

	-- Backpack listener callbacks.
    inst._onequipped   = function(container, data) onequipped(inst, container, data.owner) end
    inst._onunequipped = function(container, data) onunequipped(inst, container)           end

    inst:AddComponent("aoespell")

	inst:AddComponent("ghostlyelixirable")
	inst.components.ghostlyelixirable.overrideapplytotargetfn = GetElixirTarget

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("inventoryitem")

    inst:AddComponent("lootdropper")

	inst:AddComponent("summoningitem")

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
	inst.components.burnable.fxdata = {}
    inst.components.burnable:AddBurnFX("campfirefire", Vector3(0, 0, 0))

    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)
	inst:ListenForEvent("spellupdateneeded", Server_UpdateSkills)

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

	inst._ongroundupdatetask = inst:DoPeriodicTask(0.5, UpdateGroundAnimation, math.random()*0.5)
	inst._bond_level = 0

    inst.drawimageoverride = drawimageoverride

    return inst
end


local assets_summonfx =
{
	Asset("ANIM", "anim/abigail_flower_rework.zip"),
    Asset("ANIM", "anim/wendy_channel_flower.zip"),
    Asset("ANIM", "anim/wendy_mount_channel_flower.zip"),
}

local assets_unsummonfx =
{
	Asset("ANIM", "anim/abigail_flower_rework.zip"),
    Asset("ANIM", "anim/wendy_recall_flower.zip"),
    Asset("ANIM", "anim/wendy_mount_recall_flower.zip"),
}

local assets_levelupfx =
{
	Asset("ANIM", "anim/abigail_flower_rework.zip"),
    Asset("ANIM", "anim/abigail_flower_change.zip"),
}

local function MakeSummonFX(anim, build, is_mounted)
    return function()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

		if is_mounted then
	        inst.Transform:SetSixFaced()
		else
	        inst.Transform:SetFourFaced()
		end

        inst.AnimState:SetBank(anim)
		if build ~= nil then
			inst.AnimState:SetBuild(build)
	        inst.AnimState:OverrideSymbol("flower", "abigail_flower_rework", "flower")
		else
	        inst.AnimState:SetBuild("abigail_flower_rework")
		end
        inst.AnimState:PlayAnimation(anim)
		inst.AnimState:SetFinalOffset(1)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false

        --Anim is padded with extra blank frames at the end
        inst:ListenForEvent("animover", inst.Remove)

        return inst
    end
end

return Prefab("abigail_flower", fn, assets),
	Prefab("abigailsummonfx", MakeSummonFX("wendy_channel_flower", "wendy_channel_flower", false), assets_summonfx),
	Prefab("abigailsummonfx_mount", MakeSummonFX("wendy_mount_channel_flower", "wendy_channel_flower", true), assets_summonfx),
	Prefab("abigailunsummonfx", MakeSummonFX("wendy_recall_flower", nil, false), assets_unsummonfx),
	Prefab("abigailunsummonfx_mount", MakeSummonFX("wendy_mount_recall_flower", nil, true), assets_unsummonfx),
	Prefab("abigaillevelupfx", MakeSummonFX("abigail_flower_change", nil, false), assets_levelupfx)
