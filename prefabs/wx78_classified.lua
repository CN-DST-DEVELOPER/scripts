--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

local WX78ModuleDefinitionFile = require("wx78_moduledefs")
local GetWX78ModuleByNetID = WX78ModuleDefinitionFile.GetModuleDefinitionFromNetID

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------
local SKILLTREE_DEFS = require("prefabs/skilltree_defs").SKILLTREE_DEFS
local MAX_BODY_COUNT = 0
local MAX_BODY_COUNT_SKILLS = {}
if SKILLTREE_DEFS.wx78 then
    for skill_name, skill in pairs(SKILLTREE_DEFS.wx78) do
        if skill.tags and table.contains(skill.tags, "wx78_maxbody") then
            MAX_BODY_COUNT = MAX_BODY_COUNT + 1
            table.insert(MAX_BODY_COUNT_SKILLS, skill_name)
        end
    end
end



--------------------------------------------------------------------------
--Server interface
--------------------------------------------------------------------------

local function SetValue(inst, name, value)
    assert(value >= 0 and value <= 65535, "Player "..tostring(name).." out of range: "..tostring(value))
    inst[name]:set(math.ceil(value))
end

local function TryToAddBackupBody(inst, body)
    if inst.backupbodies[body] then
        return true
    end

    if inst:GetNumFreeBackupBodies() <= 0 then
        return false
    end

    inst.backupbodies[body] = true
    inst.numactivebodies:set(inst.numactivebodies:value() + 1)
    if inst._parent and inst._parent.HUD then
        inst._parent:PushEvent("refreshcrafting")
    end
    return true
end

local function TryToRemoveBackupBody(inst, body)
    if not inst.backupbodies[body] then
        return false
    end

    inst.backupbodies[body] = nil
    inst.numactivebodies:set(inst.numactivebodies:value() - 1)
    if inst._parent and inst._parent.HUD then
        inst._parent:PushEvent("refreshcrafting")
    end
    return true
end

local function DetachBodiesToMaximumCount(inst, maxbodies)
    local numactivebodies = inst.numactivebodies:value()
    local toremovecount = numactivebodies - maxbodies
    if toremovecount > 0 then
        for body, _ in pairs(inst.backupbodies) do
            if toremovecount <= 0 then
                break
            end
            if inst:TryToRemoveBackupBody(body) then
                local linkeditem = body.components.linkeditem
                if linkeditem then
                    linkeditem:LinkToOwnerUserID(nil)
                end
                toremovecount = toremovecount - 1
            end
        end
        if toremovecount > 0 then
            assert(false, "Failed to remove backup bodies to a forced maximum threshold.")
        end
    end
end

--------------------------------------------------------------------------
--Common interface
--------------------------------------------------------------------------

local function GetOwningPlayer(inst)
    local owner = nil
    if inst._parent then
        if inst._parent.isplayer then
            owner = inst._parent
        elseif inst._parent.components.linkeditem then
            owner = inst._parent.components.linkeditem:GetOwnerInst()
        end
    end
    return owner
end

local function GetOwningWX78_Classified(inst)
    local owner = inst:GetOwningPlayer()
    return owner and owner.wx78_classified or inst
end

local function GetMaxBackupBodies(inst)
    local wx78_classified = inst:GetOwningWX78_Classified()
    local maxbodies = 0
    local owner = wx78_classified:GetOwningPlayer()
    local skilltreeupdater = owner and owner.components.skilltreeupdater or nil
    if skilltreeupdater then
        for _, skill_name in ipairs(MAX_BODY_COUNT_SKILLS) do
            if skilltreeupdater:IsActivated(skill_name) then
                maxbodies = maxbodies + 1
            end
        end
    end
    return maxbodies
end

local function GetNumFreeBackupBodies(inst)
    local wx78_classified = inst:GetOwningWX78_Classified()
    local maxbodies = wx78_classified:GetMaxBackupBodies()
    local numactivebodies = wx78_classified.numactivebodies:value()
    return math.max(maxbodies - numactivebodies, 0)
end

local function GetNumFreeScoutingDrones(inst)
    local wx78_classified = inst:GetOwningWX78_Classified()
    local wx = wx78_classified._parent
    local maxscouts = wx and wx.components.skilltreeupdater and wx.components.skilltreeupdater:IsActivated("wx78_scoutdrone_1") and TUNING.SKILLS.WX78.SCOUTDRONE_MAX_COUNT or 0
    local numdronescouts = wx78_classified.numdronescouts:value()
    return math.max(maxscouts - numdronescouts, 0)
end

local function GetNumFreeShadowDrone_Harvesters(inst)
    local wx78_classified = inst:GetOwningWX78_Classified()
    return wx78_classified.num_free_shadowdrone_harvesters:value()
end

local function GetNumFreeShadowDrone_Debuffers(inst)
    local wx78_classified = inst:GetOwningWX78_Classified()
    return wx78_classified.num_free_shadowdrone_debuffers:value()
end

local function OnPowerOffOverlayDirty(inst)
	if inst._parent and inst._parent.HUD then
		if inst.poweroffoverlay:value() then
			inst._parent.HUD.wxpowerover:PowerOff()
		else
			inst._parent.HUD.wxpowerover:Clear()
		end
	end
end

--------------------------------------------------------------------------
--Client interface
--------------------------------------------------------------------------

local function OnUnsocketShadowSlot(parent, socketposition)
	SendRPCToServer(RPC.UnplugModule, socketposition)
end

local function OnEntityReplicated(inst)
    inst._parent = inst.entity:GetParent()
    if inst._parent == nil then
        print("Unable to initialize classified data for wx78_classified")
    else
		inst:ListenForEvent("socketholder_unsocket", OnUnsocketShadowSlot, inst._parent)

        inst._parent:AttachClassified_wx78(inst)
    end
end

-- WX78 Upgrade Module UI functions ------------------------------------------

local function TryActivateModule(inst, definition, bartype, moduleindex)
    if not inst._activatedmods[bartype][moduleindex] then
        inst._activatedmods[bartype][moduleindex] = true
        if definition.client_activatefn ~= nil then
            definition.client_activatefn(inst, inst._parent)
        end
    end
end

local function TryDeactivateModule(inst, definition, bartype, moduleindex)
    if inst._activatedmods[bartype][moduleindex] then
        inst._activatedmods[bartype][moduleindex] = false
        if definition.client_deactivatefn ~= nil then
            definition.client_deactivatefn(inst, inst._parent)
        end
    end
end

local function UpdateActivatedModules(inst)
    inst.update_activated_modules = nil
    for bartype, modules in pairs(inst.upgrademodulebars) do
        local remaining_charge = inst:GetEnergyLevel()
        for i, module_netvar in ipairs(modules) do
            local module_definition = GetWX78ModuleByNetID(module_netvar:value())
            if module_definition ~= nil then
                remaining_charge = remaining_charge - module_definition.slots
                if remaining_charge < 0 then
                    TryDeactivateModule(inst, module_definition, bartype, i)
                else
                    TryActivateModule(inst, module_definition, bartype, i)
                end
            else
                break
            end
        end
    end
end

local function GetModulesData(inst)
    local moddata = {}

    for bartype, modules in pairs(inst.upgrademodulebars) do
        moddata[bartype] = {}
        for _, module_netvar in ipairs(modules) do
            table.insert(moddata[bartype], module_netvar:value())
        end
    end

    return moddata
end

local function CanUpgradeWithModule(inst, moduleent)
    local module_type = moduleent._type
    local slots_inuse = moduleent._slots or 0

    for _, module_netvar in ipairs(inst.upgrademodulebars[module_type]) do
        local module_definition = GetWX78ModuleByNetID(module_netvar:value())
        if module_definition ~= nil then
            slots_inuse = slots_inuse + module_definition.slots
        end
    end

    return (inst.maxenergylevel:value() - slots_inuse) >= 0
end

local function GetModuleTypeCount(inst, module_name)
    local count = 0
    --
    for bartype, modules in pairs(inst.upgrademodulebars) do
        local remaining_charge = inst:GetEnergyLevel()
        for _, module_netvar in ipairs(modules) do
            local module_definition = GetWX78ModuleByNetID(module_netvar:value())
            if module_definition ~= nil then
                remaining_charge = remaining_charge - module_definition.slots
                if remaining_charge < 0 then
                    break
                elseif module_definition.name == module_name then
                    count = count + 1
                end
            else
                break
            end
        end
    end
    --
    return count
end

local function UnplugModule(inst, moduletype, moduleindex)
    SendRPCToServer(RPC.UnplugModule, moduletype, moduleindex)
end

local function GetMaxEnergy(inst)
    return inst.maxenergylevel:value()
end

local function GetEnergyLevel(inst)
    return inst.overridefullcharge:value() and inst.maxenergylevel:value() or inst.currentenergylevel:value()
end

local function OnEnergyLevelDirty(inst)
    if inst._parent ~= nil then
        local energylevel = inst:GetEnergyLevel()
        local maxenergylevel = inst.maxenergylevel:value()
        local data =
        {
            old_level = inst._oldcurrentenergylevel,
            new_level = energylevel,
            old_max_level = inst._oldmaxenergylevel,
            new_max_level = maxenergylevel,
        }

        -- Delay by a frame to let OnUpgradeModulesListDirty handle things first.
        if inst.update_activated_modules ~= nil then
            inst.update_activated_modules:Cancel()
        end
        inst.update_activated_modules = inst:DoStaticTaskInTime(0, UpdateActivatedModules)

        inst._oldcurrentenergylevel = energylevel
        inst._oldmaxenergylevel = maxenergylevel
        inst._parent:PushEvent("energylevelupdate", data)
    end
end

local function OnPerformedSpinActionDirty(inst)
	if inst._parent then
		inst._parent:PushEvent("wx_performedspinaction", inst.performedspinaction:value())
	end
end

local function OnPerformedSpinAction_Server(parent, isattack)
	local inst = parent.wx78_classified
	if inst then
		inst.performedspinaction:set_local(isattack)
		inst.performedspinaction:set(isattack)
	end
end

local function OnShieldDirty(inst)
    if inst._parent ~= nil then
        local maxshield = inst.maxshield:value()
        local oldpercent = inst._oldshieldpercent
        local percent = inst.currentshield:value() / maxshield

        local data = {
            oldpercent = oldpercent,
            newpercent = percent,
            maxshield = maxshield,
            penetrationthreshold = inst.shieldpenetrationthreshold:value(),
        }
        inst._oldshieldpercent = percent
        inst._parent:PushEvent("wxshielddelta", data)
    else
        inst._oldshieldpercent = 0
    end
end

local function OnCanShieldChargeDirty(inst)
    if inst._parent then
        inst._parent:PushEvent("wx_canshieldcharge", inst.canshieldcharge:value())
    end
end

local function OnUIRobotSparks(inst)
    if inst._parent ~= nil then
        inst._parent:PushEvent("do_robot_spark")
    end
end

local function OnUpgradeModulesListDirty(inst)
    if inst._parent ~= nil then
        local moddata = {}
        local allempty = true
        for moduletype, modules in pairs(inst.upgrademodulebars) do
            moddata[moduletype] = {}
            for i, module_netvar in ipairs(modules) do
                local oldnetid = inst._oldupgrademodulebars[moduletype][i]
                local netid = module_netvar:value()
                table.insert(moddata[moduletype], netid)
                if oldnetid ~= 0 then
                    if oldnetid ~= netid then
                        TryDeactivateModule(inst, GetWX78ModuleByNetID(oldnetid), moduletype, i)
                    end
                end
                if netid ~= 0 then
                    allempty = false
                end
            end
        end

        UpdateActivatedModules(inst)
        inst._oldupgrademodulebars = moddata

        if allempty then
            inst._parent:PushEvent("upgrademoduleowner_popallmodules")
        else
            inst._parent:PushEvent("upgrademodulesdirty", moddata)
        end
    end
end

local function OnInspectUpgradeModuleBarsDirty(inst)
    local owner = ThePlayer
    if owner ~= nil and owner.HUD then
        if inst.inspectupgrademodulebars:value() then
			owner.HUD:ShowUpgradeModuleWidget()
        else
            owner.HUD:CloseUpgradeModuleWidget()
        end
    end
end

local function OnCraftingNetVarDirty(inst)
    if inst._parent ~= nil and inst._parent.HUD then
        inst._parent:PushEvent("refreshcrafting")
    end
end

local function OnFreezeEffectBlockedDirty(inst)
    if inst._parent ~= nil then
        inst._parent:PushEvent("updateiceover")
    end
end

local function OnOverHeatEffectBlockedDirty(inst)
    if inst._parent ~= nil then
        inst._parent:PushEvent("updateheatover")
    end
end

--------------------------------------------------------------------------
local function RegisterNetListeners_mastersim(inst)
	inst:ListenForEvent("wx_performedspinaction", OnPerformedSpinAction_Server, inst._parent)
end
local function RegisterNetListeners_local(inst)
    inst:ListenForEvent("uirobotsparksevent", OnUIRobotSparks)
    inst:ListenForEvent("upgrademoduleenergyupdate", OnEnergyLevelDirty)
    inst:ListenForEvent("upgrademoduleslistdirty", OnUpgradeModulesListDirty)
    inst:ListenForEvent("inspectupgrademodulebarsdirty", OnInspectUpgradeModuleBarsDirty)
    inst:ListenForEvent("numactivebodiesdirty", OnCraftingNetVarDirty)
    inst:ListenForEvent("numdronescoutsdirty", OnCraftingNetVarDirty)
    inst:ListenForEvent("num_free_shadowdrone_harvestersdirty", OnCraftingNetVarDirty)
    inst:ListenForEvent("num_free_shadowdrone_debuffersdirty", OnCraftingNetVarDirty)
	inst:ListenForEvent("performedspinactiondirty", OnPerformedSpinActionDirty)
    inst:ListenForEvent("shielddirty", OnShieldDirty)
    inst:ListenForEvent("canshieldchargedirty", OnCanShieldChargeDirty)
	inst:ListenForEvent("freezeeffectdirty", OnFreezeEffectBlockedDirty)
	inst:ListenForEvent("overheateffectdirty", OnOverHeatEffectBlockedDirty)
end
local function RegisterNetListeners_common(inst)
	inst:ListenForEvent("poweroffoverlaydirty", OnPowerOffOverlayDirty)
end

local function OnInitialDirtyStates(inst)
    if not TheWorld.ismastersim then
        inst._oldupgrademodulebars = GetModulesData(inst)
        OnInspectUpgradeModuleBarsDirty(inst)
        UpdateActivatedModules(inst)
    end
end

local function RegisterNetListeners(inst)
    if TheWorld.ismastersim then
        inst._parent = inst.entity:GetParent()
        RegisterNetListeners_mastersim(inst)
    else
        RegisterNetListeners_local(inst)
    end
    RegisterNetListeners_common(inst)

    OnInitialDirtyStates(inst)
end

local function AddDebugString(wx78_classified, bodystrings, prefix)
    local maxbodies = wx78_classified:GetMaxBackupBodies()
    local bodiesfree = wx78_classified:GetNumFreeBackupBodies()
    table.insert(bodystrings, string.format("%s (%d active, %d free, %d max):", prefix, maxbodies - bodiesfree, bodiesfree, maxbodies))
end
local function GetDebugString(inst)
    local bodystrings = {}
    local wx78_classified = inst:GetOwningWX78_Classified()
    if wx78_classified == inst then
        AddDebugString(inst, bodystrings, "Bodies:")
    else
        AddDebugString(wx78_classified, bodystrings, "Bodies (owner's point of view):")
        AddDebugString(inst, bodystrings, "Bodies (body's point of view):")
    end
    table.insert(bodystrings, (wx78_classified:_GetDebugString()))
    return table.concat(bodystrings, "\n")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform() --So we can follow parent's sleep state
    inst.entity:AddNetwork()
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")

    -- Common interface
    inst.GetOwningPlayer = GetOwningPlayer
    inst.GetOwningWX78_Classified = GetOwningWX78_Classified
    inst.GetMaxBackupBodies = GetMaxBackupBodies
    inst.GetNumFreeBackupBodies = GetNumFreeBackupBodies
    inst.GetNumFreeScoutingDrones = GetNumFreeScoutingDrones
    inst.GetNumFreeShadowDrone_Harvesters = GetNumFreeShadowDrone_Harvesters
    inst.GetNumFreeShadowDrone_Debuffers = GetNumFreeShadowDrone_Debuffers

    inst.uirobotsparksevent = net_event(inst.GUID, "uirobotsparksevent")

    -- Upgrade Module Owner
    inst._oldcurrentenergylevel = 0
    inst._oldmaxenergylevel = 0
    inst.currentenergylevel = net_smallbyte(inst.GUID, "wx78.currentenergylevel", "upgrademoduleenergyupdate")
    inst.maxenergylevel = net_smallbyte(inst.GUID, "wx78.maxenergylevel", "upgrademoduleenergyupdate")
    inst.maxenergylevel:set(TUNING.WX78_INITIAL_MAXCHARGELEVEL)
    inst.overridefullcharge = net_bool(inst.GUID, "wx78.overridefullcharge", "upgrademoduleenergyupdate")

    inst._oldupgrademodulebars = {}
    inst.upgrademodulebars = {}
    inst._activatedmods = {}
    for i, name in pairs(CIRCUIT_BARS_LOOKUP) do
        inst._oldupgrademodulebars[i] = {}
        inst.upgrademodulebars[i] = {}
        inst._activatedmods[i] = {}
        for j = 1, MAX_CIRCUIT_SLOTS do
            inst._activatedmods[i][j] = false
            inst.upgrademodulebars[i][j] = net_smallbyte(inst.GUID, "wx78.upgrademodulebars"..i.."mods"..j, "upgrademoduleslistdirty")
        end
    end
    inst.inspectupgrademodulebars = net_bool(inst.GUID, "inspectupgrademodulebars", "inspectupgrademodulebarsdirty")

	--Spin variables
	inst.performedspinaction = net_bool(inst.GUID, "wx78.performedspinaction", "performedspinactiondirty")

    --Shield variables
    inst._oldshieldpercent = 0
    inst.currentshield = net_ushortint(inst.GUID, "wx78.currentshield", "shielddirty")
    inst.canshieldcharge = net_bool(inst.GUID, "wx78.canshieldcharge", "canshieldchargedirty")
    inst.maxshield = net_ushortint(inst.GUID, "wx78.maxshield", "shielddirty")
    inst.shieldpenetrationthreshold = net_ushortint(inst.GUID, "wx78.shieldpenetrationthreshold", "shielddirty")
    inst.currentshield:set(0)
    inst.maxshield:set(1)
    inst.shieldpenetrationthreshold:set(15)

    -- Bodies
    local numactivebodies_net_enum = GetIdealUnsignedNetVarForCount(MAX_BODY_COUNT)
    inst.numactivebodies = numactivebodies_net_enum(inst.GUID, "wx78.numactivebodies", "numactivebodiesdirty")

    -- Drones
    local numdronescouts_net_enum = GetIdealUnsignedNetVarForCount(TUNING.SKILLS.WX78.SCOUTDRONE_MAX_COUNT)
    inst.numdronescouts = numdronescouts_net_enum(inst.GUID, "wx78.numdronescouts", "numdronescoutsdirty")
    -- Shadow Drones
    local num_free_shadowdrone_harvesters_net_enum = GetIdealUnsignedNetVarForCount(math.max(TUNING.SKILLS.WX78.SHADOWDRONE_HARVESTER_LIMIT, TUNING.SKILLS.WX78.SHADOWDRONE_HARVESTER_LIMIT_BOOSTED))
    inst.num_free_shadowdrone_harvesters = num_free_shadowdrone_harvesters_net_enum(inst.GUID, "wx78.num_free_shadowdrone_harvesters", "num_free_shadowdrone_harvestersdirty")
    local num_free_shadowdrone_debuffers_net_enum = GetIdealUnsignedNetVarForCount(math.max(TUNING.SKILLS.WX78.SHADOWDRONE_DEBUFFER_LIMIT, TUNING.SKILLS.WX78.SHADOWDRONE_DEBUFFER_LIMIT_BOOSTED))
    inst.num_free_shadowdrone_debuffers = num_free_shadowdrone_debuffers_net_enum(inst.GUID, "wx78.num_free_shadowdrone_debuffers", "num_free_shadowdrone_debuffersdirty")

	-- UI
	inst.poweroffoverlay = net_bool(inst.GUID, "hud.wxpowerover", "poweroffoverlaydirty")
    inst.freezeeffectblocked = net_bool(inst.GUID, "wx78.freezeeffectblocked", "freezeeffectdirty")
    inst.overheateffectblocked = net_bool(inst.GUID, "wx78.overheateffectblocked", "overheateffectdirty")

    --Delay net listeners until after initial values are deserialized
    inst:DoStaticTaskInTime(0, RegisterNetListeners)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        --Client interface
        inst.OnEntityReplicated = OnEntityReplicated

        inst.GetModulesData = GetModulesData
        inst.CanUpgradeWithModule = CanUpgradeWithModule
        inst.GetModuleTypeCount = GetModuleTypeCount
        inst.UnplugModule = UnplugModule

        inst.GetMaxEnergy = GetMaxEnergy
        inst.GetEnergyLevel = GetEnergyLevel

        return inst
    end

    --Server interface
    inst.SetValue = SetValue

    inst.backupbodies = {}
    inst.TryToAddBackupBody = TryToAddBackupBody
    inst.TryToRemoveBackupBody = TryToRemoveBackupBody
    inst.DetachBodiesToMaximumCount = DetachBodiesToMaximumCount

    inst._GetDebugString = inst.GetDebugString
    inst.GetDebugString = GetDebugString

    inst.persists = false

    return inst
end

return Prefab("wx78_classified", fn)