--------------------------------------------------------------------------------------------------------

local lantern_posts_defs = require("prefabs/lantern_posts_defs")
local LANTERN_DEFS = lantern_posts_defs.lantern_posts
lantern_posts_defs = nil

--------------------------------------------------------------------------------------------------------

local POST_ONEOF_TAGS = { "lantern_post", "lightpostpartner" }
local POST_NOT_TAGS = { "burnt", "abandoned" }

local function IsSamePostType(postname, partner)
    local lightpostpartner = partner.components.lightpostpartner
    local next_id = lightpostpartner and lightpostpartner:GetNextAvailableShackleID()
    return postname == partner.prefab or
        (
            lightpostpartner and lightpostpartner.post_type == postname and (next_id ~= nil or not lightpostpartner:IsMultiShackled())
        )
end

local LIGHT_RADIUS = 3
local LIGHT_COLOUR = Vector3(200 / 255, 100 / 255, 100 / 255)

--------------------------------------------------------------------------

local TOTAL_DAY_TIME = TUNING.TOTAL_DAY_TIME
local function GetWorldTime()
    return TheWorld.components.worldstate:GetWorldAge() * TOTAL_DAY_TIME
end
-- for light and light chain

local function Light_OnUpdateFlicker(inst, starttime)
    local time = starttime ~= nil and (GetTime() - starttime) * 15 or 0
    local flicker = (math.sin(time) + math.sin(time + 2) + math.sin(time + 0.7777)) * .5 -- range = [-1 , 1]
    flicker = (1 + flicker) * .5 -- range = 0:1
    inst.Light:SetRadius(LIGHT_RADIUS + .1 * flicker)
    flicker = flicker * 2 / 255
    inst.Light:SetColour(LIGHT_COLOUR.x + flicker, LIGHT_COLOUR.y + flicker, LIGHT_COLOUR.z + flicker)
end

--------------------------------------------------------------------------

local function is_fulllighter(item)
    return item:HasTag("fulllighter")
end

local function is_battery_type(item)
    return item:HasAnyTag("lightbattery", "spore", "lightcontainer")
end

local function IsLightOn(inst)
    if inst.components.container then
        return inst.components.container:FindItem(is_battery_type) ~= nil
    end

    -- TODO check lightpostpartner
    return true -- Hermit house case.
end

--------------------------------------------------------------------------

local function LanternPost_UpdateLightState(inst)
    if inst:HasTag("burnt") then
        return
    end

    local has_fulllighter = inst.components.container:FindItem(is_fulllighter) ~= nil
    local perishrate = has_fulllighter and 0 or TUNING.PERISH_MUSHROOM_LIGHT_MULT
    inst.components.preserver:SetPerishRateMultiplier(perishrate)

    if IsLightOn(inst) then
        inst:LightsOn()
    else
        inst:LightsOff()
    end
end

local function LanternPost_RemoveNeighbourLights(inst)
    if inst.neighbour_lights then
		for light in pairs(inst.neighbour_lights) do
            -- For the chain to know where to break off of, let's set the partner to nil.
            for i, partner in ipairs(light.partners) do
                if partner:value() == inst then
                    partner:set(nil)
                    break
                end
            end
			light:Remove()
		end
	end
end

local function LightChain_EnableLight(inst, enable)
    inst.Light:Enable(enable)
    inst.enable_lights:set(enable)
    if not TheNet:IsDedicated() then
        inst:EnableLightsDirty()
    end
end

local function MakeLanternPost(data)
    local prefabname = data.name

    local lightchainprefab = data.overridelightchainprefabname or prefabname.."_light_chain"

    local bank = data.bank or data.name
    local build = data.build or data.name
    local anim = data.anim or "idle"

    local assets =
    {
        Asset("SCRIPT", "scripts/prefabs/lantern_posts_defs.lua"),
        Asset("ANIM", "anim/"..build..".zip"),
        Asset("ANIM", "anim/reticuledash.zip"),
    }

    local prefabs =
    {
        lightchainprefab,
    }

    if data.assets ~= nil then
        for k, v in ipairs(data.assets) do
            table.insert(assets, v)
        end
    end

    local minimap_icon = data.minimap or data.name..".png"

    local function LightsOn(inst)
        inst.AnimState:Show("light_on")

        if not inst.Light:IsEnabled() then
            inst.Light:Enable(true)

            if inst.neighbour_lights then
                for light, partner in pairs(inst.neighbour_lights) do
                    LightChain_EnableLight(light, true)
                end
            end
        end
    end

    local function LightsOff(inst)
        inst.AnimState:Hide("light_on")

        if inst.Light:IsEnabled() then
            inst.Light:Enable(false)

            if inst.neighbour_lights then
                for light, partner in pairs(inst.neighbour_lights) do
                    if not IsLightOn(partner) then
                        LightChain_EnableLight(light, false)
                    end
                end
            end
        end
    end

    local function SpawnLightChain(inst, partner)
        -- OMAR FIXME, AUDIO_WINTER_2025
		--inst.SoundEmitter:PlaySound("meta2/pillar/scaffold_place")

        local x, y, z = inst.Transform:GetWorldPosition()
		local px, py, pz = partner.Transform:GetWorldPosition()
		local xdiff = px - x
		local zdiff = pz - z

        local light_chain = SpawnPrefab(lightchainprefab)
        light_chain.Transform:SetPosition(x + (xdiff / 2), 0, z + (zdiff / 2))
        light_chain:SetPartners(inst, partner)

        local lightpostpartner = partner.components.lightpostpartner
        if lightpostpartner and lightpostpartner:IsMultiShackled() then
            lightpostpartner:ShacklePartnerToNextID(inst)
        end
	end

    local PARTNER_COUNT = data.partner_count or 2
    local CHAIN_DIST = data.chain_dist or 8
    local function FindPostPartners(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local posts = TheSim:FindEntities(x, y, z, CHAIN_DIST, nil, POST_NOT_TAGS, POST_ONEOF_TAGS)
        local num_partners = 0

        for i, post in ipairs(posts) do
            if post ~= inst and IsSamePostType(inst.prefab, post) then
                num_partners = num_partners + 1
                SpawnLightChain(inst, post)
                if num_partners >= PARTNER_COUNT then
                    break
                end
            end
        end
    end

    local function OnWorked(inst, worker, workleft, numworks)
        if inst:HasTag("abandoned") then
            inst.AnimState:PlayAnimation("broken_hit")
            inst.AnimState:PushAnimation("broken")
        else
            inst.AnimState:PlayAnimation("hit")
            inst.AnimState:PushAnimation("idle")
        end
    end

    local function OnWorkFinished(inst, worker)
        if inst.components.container ~= nil then
            inst.components.container:DropEverything()
        end

        inst.components.lootdropper:DropLoot()

        local fx = SpawnPrefab("collapse_big")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial(data.material or "wood")

        inst:Remove()
    end

    local function OnBuilt(inst)
        inst.AnimState:PlayAnimation("place")
        inst.AnimState:PushAnimation("idle")

        -- OMAR FIXME, AUDIO_WINTER_2025
        inst.SoundEmitter:PlaySound(data.sounds ~= nil and data.sounds.place or "dontstarve/common/together/town_portal/craft")

        inst:FindPostPartners()

        if data.spawn_with_light_bulb then
       	    local light = SpawnPrefab("lightbulb")
       	    inst.components.container:GiveItem(light)
        end
    end

    local function OnSave(inst, savedata)
        if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
            savedata.burnt = true
        end

        if data.OnSave then
            data.OnSave(inst, savedata)
        end
    end

    local function OnLoad(inst, savedata)
        if savedata ~= nil then
            if savedata.burnt then
                inst.components.burnable.onburnt(inst)
            end

            if data.OnLoad then
                data.OnLoad(inst, savedata)
            end
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddLight()
        inst.entity:AddNetwork()

        inst.MiniMapEntity:SetIcon(minimap_icon)

        MakeObstaclePhysics(inst, .25)
        inst.Physics:CollidesWith(COLLISION.OBSTACLES) -- for ocean to block boats

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)
        inst.AnimState:Hide("light_on")

        inst.Light:SetIntensity(.85)
        inst.Light:SetFalloff(.7)
        inst.Light:EnableClientModulation(true)
        inst.Light:Enable(false)

        inst:DoPeriodicTask(.1, Light_OnUpdateFlicker, nil, GetTime())
        Light_OnUpdateFlicker(inst)

        inst:AddTag("structure")
        inst:AddTag("lantern_post")
        inst:AddTag("lamp")

        inst.sounds = data.sounds

        if data.kit_data then
            inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2) --match kit item
        end

        MakeSnowCoveredPristine(inst)

        if data.common_postinit then
            data.common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("workable")
	    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	    inst.components.workable:SetWorkLeft(3)
	    inst.components.workable:SetOnWorkCallback(OnWorked)
	    inst.components.workable:SetOnFinishCallback(OnWorkFinished)

        inst:AddComponent("lootdropper")

        inst:AddComponent("container")
        inst.components.container:WidgetSetup(prefabname)

        inst:AddComponent("preserver")
	    inst.components.preserver:SetPerishRateMultiplier(TUNING.PERISH_MUSHROOM_LIGHT_MULT)

        inst:ListenForEvent("onbuilt", OnBuilt)
        inst:ListenForEvent("itemget", LanternPost_UpdateLightState)
        inst:ListenForEvent("itemlose", LanternPost_UpdateLightState)

        inst.RemoveNeighbourLights = LanternPost_RemoveNeighbourLights
        inst:ListenForEvent("onremove", LanternPost_RemoveNeighbourLights)
        inst:ListenForEvent("onburnt", LanternPost_RemoveNeighbourLights)

        inst.FindPostPartners = FindPostPartners
        inst.LightsOn = LightsOn
        inst.LightsOff = LightsOff

        if data.master_postinit then
            data.master_postinit(inst)
        end

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        if not data.no_burn then
            MakeSmallBurnable(inst, nil, nil, true)
            MakeSmallPropagator(inst)
        end

        MakeHauntableWork(inst)
        MakeSnowCovered(inst)

        return inst
    end

    return Prefab(prefabname, fn, assets, prefabs)
end

--

local MAX_LANTERNS = 5

-- We max out at 5 lanterns but we want to space them out correctly with more than 11 of the regular chain link
local MAGIC_LANTERN_NUM_OFFSET = 1 / 3 --1 / 3 --1 / 3
local MAGIC_LANTERN_DENOMINATOR = 4.334 -- 4 + MAGIC_LANTERN_NUM_OFFSET

--[[
- 1 / 2
6

6 / 9
3.67 (or 3 + 2 / 3)
]]

local MAX_SWAY = 2

local BASE_SWAY_TIME_SCALE = .3
local BASE_SWAY_DIST_SCALE = .35

local VAR_SWAY_TIME_SCALE = .08
local VAR_SWAY_DIST_SCALE = .06

local function GetDeltaTime(inst)
	local current_time = GetTime()
	local dt = current_time - inst.t
	inst.t = current_time
	return dt
end

local function GetSwayTimeScale()
    return BASE_SWAY_TIME_SCALE + math.random() * VAR_SWAY_TIME_SCALE
end

local function GetSwayDistScale(inst)
    if inst.sway_dist_scale == nil then
        inst.sway_dist_scale = BASE_SWAY_DIST_SCALE + math.random() * VAR_SWAY_DIST_SCALE
    end
    return inst.sway_dist_scale
end

local function GetSwayOffset(inst, sway, drop, cos_theta, sin_theta)
    local radius = drop * sway
    return radius * cos_theta, -drop, -radius * sin_theta
end

local function GetChainLinkPosition(inst, partner)
    local lightpostpartner = partner.components.lightpostpartner
    if lightpostpartner and lightpostpartner:IsMultiShackled() then
        local shackle_id = lightpostpartner:GetShackleIdForPartner(inst)
        if shackle_id then
            return partner.AnimState:GetSymbolPosition("swap_shackle"..shackle_id)
        end
    end
    --
    return partner.AnimState:GetSymbolPosition("swap_shackle")
end

local SpawnChain, RemoveChain --forward declare

local function LightChain_OnSkinDirty(inst)
	if inst.chains then
		RemoveChain(inst, true)
		-- respawn
		SpawnChain(inst)
	end
end

local function LightChain_OnUpdateSkin_Client(inst)
	if inst.chains then
		inst.clientskindirty = true
	end
end

local function LightChain_OnPostUpdate(inst)
	if inst.clientskindirty then
		inst.clientskindirty = nil
		LightChain_OnSkinDirty(inst)
	end

    -- TODO faster when high up
	local dt = GetDeltaTime(inst) * TheSim:GetTimeScale() * GetSwayTimeScale()

    inst.sway_pos = inst.sway_pos + dt
	if inst.sway_pos > MAX_SWAY then
        inst.sway_pos = 0
	end

    local partner1 = inst.partners[1]:value()
    local partner2 = inst.partners[2]:value()
    if partner1 and partner2 and inst.chains then
        local x1, y1, z1 = GetChainLinkPosition(partner2, partner1)
        local x2, y2, z2 = GetChainLinkPosition(partner1, partner2)

        local xdiff = x1 - x2
		local ydiff = y1 - y2
		local zdiff = z1 - z2

        -- TODO take into account worldwind in some way?
        local theta = math.atan2(z2 - z1, xdiff) - HALFPI
        local sin = math.sin
        local cos_theta = math.cos(theta)
        local sin_theta = sin(theta)
        local sway_sin = sin(PI * inst.sway_pos) * GetSwayDistScale(inst)
        local space_out_lanterns = math.floor(#inst.chains.chain_link / 2) >= MAX_LANTERNS + 1
        for i, link in pairs(inst.chains) do
            local do_magic_spacing = i == "lantern_link" and space_out_lanterns
            local denominator = (do_magic_spacing and MAGIC_LANTERN_DENOMINATOR or #link) + 1
            for k, v in ipairs(link) do
                local progress = do_magic_spacing and ((k - MAGIC_LANTERN_NUM_OFFSET) / denominator) or k / denominator
                local drop = sin(PI * progress)
                local sx, sy, sz = GetSwayOffset(inst, sway_sin, drop, cos_theta, sin_theta)
                v.Transform:SetPosition(x1 - (xdiff * progress) + sx, y1 - (ydiff * progress) + sy, z1 - (zdiff * progress) + sz)
            end
        end
    end
end

local NUM_VARIATIONS = 2
local function GetNextVariation(inst, prng)
    if inst.overridenextvariationfn ~= nil then
        return inst.overridenextvariationfn(inst, prng)
    end

    if inst.variation == nil then
        inst.variation = prng:RandInt(inst.num_variations)
    else
        inst.variation = inst.variation + 1
        if inst.variation > inst.num_variations then
            inst.variation = 1
        end
    end
    return inst.variation
end

local ANIM_SCALE = 150
--local function SpawnChain(inst, nohide) --forward declared
SpawnChain = function(inst, nohide)
	inst.clientskindirty = nil

    local partner1 = inst.partners[1]:value()
    local partner2 = inst.partners[2]:value()
    if not partner1 or not partner2 then
        return
    end
    --
    local x, _, z = inst.Transform:GetWorldPosition()
	local prng = PRNG_Uniform(math.floor(x + 0.5) * math.floor(z + 0.5))
    local show_light = inst.enable_lights:value()

    local function ShowOrHideLight(link)
        if show_light then
            link.AnimState:Show("light_on")
        else
            link.AnimState:Hide("light_on")
        end
    end
    --
    local chains = { chain_link = {}, lantern_link = {}, }

    local chain_len = math.ceil(math.sqrt(partner1:GetDistanceSqToInst(partner2)) * ANIM_SCALE / inst.link_length)
    if chain_len % 2 == 0 then
        chain_len = chain_len + 1
    end

    local link_halfway = math.ceil(chain_len / 2)
    for i = 1, chain_len do
		local skin_parent1 = i <= link_halfway and partner1 or partner2 --1st priority
		local skin_parent2 = i <= link_halfway and partner2 or partner1 --2nd priority
		local link = inst:CreateChainLink(skin_parent1, skin_parent2, GetNextVariation(inst, prng))
        ShowOrHideLight(link)
        table.insert(chains.chain_link, link)

        local rnd = prng:Rand()
        if rnd < 0.5 then
            link.AnimState:SetScale(-1, 1)
        end
    end

    if inst.has_lantern_link then
        local lantern_len = math.min(5, math.floor(chain_len / 2))
        local lantern_halfway = math.ceil(lantern_len / 2)
        for i = 1, lantern_len do
			local skin_parent1 = i <= lantern_halfway and partner1 or partner2 --1st priority
			local skin_parent2 = i <= lantern_halfway and partner2 or partner1 --2nd priority
			local lantern = inst:CreateLantern(skin_parent1, skin_parent2)
            ShowOrHideLight(lantern)
            table.insert(chains.lantern_link, lantern)
        end
    end

    inst.chains = chains
end

--local function RemoveChain(inst, instant) --forward declared
RemoveChain = function(inst, instant)
    if inst.chains then
        local partner1, partner2 = inst.partners[1]:value(), inst.partners[2]:value()
        local function PlayBreakAnimation(v, is_lantern)
			if v.PlayVariationSound then
				v:PlayVariationSound("broke")
			end
            v.AnimState:PlayAnimation(is_lantern and "break" or "break_"..v.variation)
        end
        if instant or inst:IsAsleep() then
            for i, link in pairs(inst.chains) do
                for k, v in ipairs(link) do
                    v:Remove()
                end
            end
        else
            for i, link in pairs(inst.chains) do
                local is_lantern_link = i == "lantern_link"
                local chain_len = #link
                for k, v in ipairs(link) do
                    local t = partner1 ~= nil and (chain_len - k) or k
                    v:DoTaskInTime(((t+1)/chain_len)*0.2, PlayBreakAnimation, is_lantern_link)
                end
            end
        end

        inst.chains = nil
        inst.variation = nil
    end
end

local function LightChain_OnNear(inst)
	if not inst.chains then
		SpawnChain(inst, true)
	end
end

local function LightChain_OnFar(inst)
	if inst.chains then
        RemoveChain(inst, true)
	end
end

local function LightChain_SetPartners(inst, partner1, partner2)
    if inst._partner1_onremove ~= nil then
        inst:RemoveEventCallback("onremove", inst._partner1_onremove, inst.parents[1]:value())
    end

    if inst._partner2_onremove ~= nil then
        inst:RemoveEventCallback("onremove", inst._partner2_onremove, inst.parents[2]:value())
    end

    inst.partners[1]:set(partner1)
    inst.partners[2]:set(partner2)

	if not TheNet:IsDedicated() then
		inst:OnPartnerDirty()
	end

	inst.components.entitytracker:TrackEntity("partner1", partner1)
	inst.components.entitytracker:TrackEntity("partner2", partner2)

    partner1.neighbour_lights = partner1.neighbour_lights or {}
	partner1.neighbour_lights[inst] = partner2

    partner2.neighbour_lights = partner2.neighbour_lights or {}
	partner2.neighbour_lights[inst] = partner1

    LightChain_EnableLight(inst, partner1.Light:IsEnabled() or partner2.Light:IsEnabled())

    inst._partner1_onremove = function() partner2.neighbour_lights[inst] = nil end
    inst._partner2_onremove = function() partner1.neighbour_lights[inst] = nil end
    inst:ListenForEvent("onremove", inst._partner1_onremove, partner1)
    inst:ListenForEvent("onremove", inst._partner2_onremove, partner2)
end

local NEAR_DIST_SQ = 39 * 39
local FAR_DIST_SQ = 41 * 41
local function LightChain_OnUpdateFn(inst, dt)
    local dist = ThePlayer and inst:GetDistanceSqToInst(ThePlayer) or math.huge

    if dist < NEAR_DIST_SQ and not inst.near then
        LightChain_OnNear(inst)
        inst.near = true
    elseif dist > FAR_DIST_SQ and inst.near then
        LightChain_OnFar(inst)
        inst.near = false
    end
end

local function LightChain_OnEntitySleep(inst)
	if inst._updating then
		inst._updating = nil
		inst.t = nil
        inst.sway_pos = nil
		inst.components.updatelooper:RemoveOnUpdateFn(LightChain_OnUpdateFn)
		inst.components.updatelooper:RemovePostUpdateFn(LightChain_OnPostUpdate)
		if inst.near then
			LightChain_OnFar(inst)
			inst.near = false
		end
	end
end

local function LightChain_OnEntityWake(inst)
	if not inst._updating then
		inst._updating = true
		inst.t = GetTime()
        inst.sway_pos = math.random() * MAX_SWAY
		inst.components.updatelooper:AddOnUpdateFn(LightChain_OnUpdateFn)
		inst.components.updatelooper:AddPostUpdateFn(LightChain_OnPostUpdate)
		LightChain_OnUpdateFn(inst, 0)
		LightChain_OnPostUpdate(inst)
	end
end

local function LightChain_OnEntityWake_Client(inst)
    if not TheNet:IsDedicated() then
        inst:OnPartnerDirty()
    end
end

local function LightChainLink_OnAnimOver(inst)
    if (inst.variation and inst.AnimState:IsCurrentAnimation("break_"..inst.variation))
        or inst.AnimState:IsCurrentAnimation("break") then
        inst:Remove()
    end
end

local function LightChain_OnRemoveEntity_Client(inst)
	RemoveChain(inst)
end

local function LightChain_EnableLightsDirty(inst, force)
    local show_light = force or inst.enable_lights:value() --LightChain_ShouldShowLight(inst)

    if inst.chains then
        for i, link in pairs(inst.chains) do
            for k, v in ipairs(link) do
                if show_light then
                    v.AnimState:Show("light_on")
                else
                    v.AnimState:Hide("light_on")
                end
            end
        end
    end
end

local function LightChain_OnPartnerDirty(inst)
	local partner1, partner2 = inst.partners[1]:value(), inst.partners[2]:value()
	if partner1 and partner2 then
		if not inst.chains and not inst.sleepstatepending then
			SpawnChain(inst)
		end
	elseif inst.chains then
		RemoveChain(inst)
	end
end

local function LightChain_OnLoadPostPass(inst)
	local partner1 = inst.components.entitytracker:GetEntity("partner1")
	local partner2 = inst.components.entitytracker:GetEntity("partner2")
	if partner1 and partner2 and not (partner1:HasTag("burnt") or partner2:HasTag("burnt")) then
		inst:SetPartners(partner1, partner2)
	else
		inst:Remove()
	end
end

local NUM_PARTNERS = 2
local function MakeLanternLightChain(data)
    local bank = data.bank or data.name
    local build = data.build or data.name

    local prefabname = data.overridelightchainprefabname or (data.name.."_light_chain")

    local has_skins = PREFAB_SKINS[data.name] ~= nil

	local function GetChainBuild(skin_parent1, skin_parent2)
		if skin_parent1.prefab == data.name then
			local skin_build = skin_parent1.AnimState:GetSkinBuild()
			if skin_build and skin_build ~= "" then
				return skin_build, true
			end
		elseif skin_parent2.prefab == data.name then
			local skin_build = skin_parent2.AnimState:GetSkinBuild()
			if skin_build and skin_build ~= "" then
				return skin_build, true
			end
		end
        return build, false
    end

    local function PlayVariationSound(inst, sound)
		local variation_sounds = inst.variation and data.sounds and data.sounds.variation_sounds and data.sounds.variation_sounds[inst.variation]
        if variation_sounds and variation_sounds[sound] then
            inst.SoundEmitter:PlaySound(variation_sounds[sound])
        end
    end

	local function CreateChainLink(chain, skin_parent1, skin_parent2, variation)
		local chain_build, is_skin = GetChainBuild(skin_parent1, skin_parent2)
    	local inst = CreateEntity()

    	inst:AddTag("FX")
    	inst:AddTag("NOCLICK")
    	--[[Non-networked entity]]
    	inst.entity:SetCanSleep(false)
    	inst.persists = false

    	inst.entity:AddTransform()
    	inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()

    	inst.AnimState:SetBank(bank)
        if is_skin then
    	    inst.AnimState:SetSkin(chain_build, build)
        else
            inst.AnimState:SetBuild(chain_build)
        end
    	inst.variation = variation
    	inst.AnimState:PlayAnimation("link_"..inst.variation, true)

        inst.PlayVariationSound = PlayVariationSound

        inst:ListenForEvent("animover", LightChainLink_OnAnimOver)

    	--inst:Hide()

    	return inst
    end

	local function CreateLantern(chain, skin_parent1, skin_parent2)
		local chain_build, is_skin = GetChainBuild(skin_parent1, skin_parent2)
    	local inst = CreateEntity()

    	inst:AddTag("FX")
    	inst:AddTag("NOCLICK")
    	--[[Non-networked entity]]
    	inst.entity:SetCanSleep(false)
    	inst.persists = false

    	inst.entity:AddTransform()
    	inst.entity:AddAnimState()

    	inst.AnimState:SetBank(bank)
        if is_skin then
    	    inst.AnimState:SetSkin(chain_build, build)
        else
            inst.AnimState:SetBuild(chain_build)
        end
    	inst.AnimState:PlayAnimation("lantern", true)

    	inst.AnimState:Hide("light_on")

    	inst:ListenForEvent("animover", LightChainLink_OnAnimOver)

    	--inst:Hide()

    	return inst
    end

    local function lightchainfn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddLight()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

        inst.Light:SetIntensity(.85)
        inst.Light:SetFalloff(.7)
        inst.Light:EnableClientModulation(true)

        inst:DoPeriodicTask(.1, Light_OnUpdateFlicker, nil, GetTime())
        Light_OnUpdateFlicker(inst)

        inst.partners = {}
        for i = 1, NUM_PARTNERS do
            inst.partners[i] = net_entity(inst.GUID, "lantern_light_chain.partner"..i, "partnerdirty")
        end
        inst.enable_lights = net_bool(inst.GUID, "lantern_light_chain.enable_lights", "enablelightsdirty")
        inst.enable_lights:set(false)

        if has_skins then
			inst.update_skin = net_event(inst.GUID, "lantern_light_chain.update_skin")
        end

        inst.link_length = data.link_length
        inst.has_lantern_link = data.has_lantern_link
        inst.num_variations = data.num_variations or NUM_VARIATIONS
        inst.overridenextvariationfn = data.overridenextvariationfn or nil
        inst.sounds = data.sounds

        inst.CreateChainLink = CreateChainLink
        inst.CreateLantern = CreateLantern

        inst.entity:SetPristine()

        local notmastersim = not TheWorld.ismastersim
        if notmastersim or not TheNet:IsDedicated() then
            inst:AddComponent("updatelooper")
 		    if notmastersim then
		    	inst.t = GetTime()
                inst.sway_pos = math.random() * MAX_SWAY
		    	inst.components.updatelooper:AddOnUpdateFn(LightChain_OnUpdateFn)
		    	inst.components.updatelooper:AddPostUpdateFn(LightChain_OnPostUpdate)

                inst.OnEntityWake = LightChain_OnEntityWake_Client
		    else
		    	inst.OnEntitySleep = LightChain_OnEntitySleep
		    	inst.OnEntityWake = LightChain_OnEntityWake
		    end

		    inst.near = nil

		    inst.EnableLightsDirty = LightChain_EnableLightsDirty
		    inst.OnRemoveEntity = LightChain_OnRemoveEntity_Client
			inst.OnPartnerDirty = LightChain_OnPartnerDirty
			inst.OnSkinDirty = LightChain_OnSkinDirty
        end

        if notmastersim then
			if has_skins then
				inst:ListenForEvent("lantern_light_chain.update_skin", LightChain_OnUpdateSkin_Client)
			end
			inst:ListenForEvent("partnerdirty", LightChain_OnPartnerDirty)
            inst:ListenForEvent("enablelightsdirty", LightChain_EnableLightsDirty)
            return inst
        end

        inst:AddComponent("entitytracker")
        inst.OnLoadPostPass = LightChain_OnLoadPostPass
        inst.SetPartners = LightChain_SetPartners

        return inst
    end

    return Prefab(prefabname, lightchainfn)
end

local function MakeLanternPostKitItem(data)
    local build = data.build or data.name
    local bank = data.bank or data.name
    local anim = data.kit_anim or "kit"
    local kit_assets =
    {
        Asset("ANIM", "anim/"..build..".zip")
    }

    return MakeDeployableKitItem(data.name.."_item", data.name, bank, build, anim, kit_assets, data.kit_data.floater_data, data.kit_data.tags, data.kit_data.burnable_data, data.kit_data.deployable_data)
end

local NUM_ANIM_LINES = 13
local function MakeLanternPostPlacer(data)
    local build = data.build or data.name
    local bank = data.bank or data.name
    local anim = data.anim or "idle"

    local PARTNER_COUNT = data.partner_count or 2
    local CHAIN_DIST = data.chain_dist or 8
    local function Placer_OnUpdateTransform(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local posts = TheSim:FindEntities(x, y, z, CHAIN_DIST, nil, POST_NOT_TAGS, POST_ONEOF_TAGS)
        local num_partners = 0

        for _, post in ipairs(posts) do
            if post ~= inst and IsSamePostType(data.name, post) then
                num_partners = num_partners + 1

                local tx, ty, tz = post.Transform:GetWorldPosition()
                local line = inst.lines[num_partners]
                line.Transform:SetRotation(inst:GetAngleToPoint(tx, ty, tz))
                line:Show()

                local CHUNK = 0.73
                local dist = post:GetDistanceSqToInst(inst)
                local target_num = math.floor(math.sqrt(dist) / CHUNK) + 1

                for i = 1, NUM_ANIM_LINES do
			    	if i > target_num then
			    		line.AnimState:Hide("target"..i)
			    	else
			    		line.AnimState:Show("target"..i)
			    	end
			    end

                if num_partners >= PARTNER_COUNT then
                    break
                end
            end
        end

        for i = num_partners + 1, #inst.lines do
            inst.lines[i]:Hide()
        end
    end

    local function placer_postinit_fn(inst)
        inst.AnimState:Hide("light_on") -- yots_lantern_post
        inst.AnimState:Hide("light_on1") -- hermitcrab_lightpost
        inst.AnimState:Hide("light_on2")
        inst.AnimState:Hide("light_on3")
    	inst.components.placer.onupdatetransform = Placer_OnUpdateTransform

        local function MakeHelperLine()
	    	local helper = CreateEntity()

	        --[[Non-networked entity]]
	        helper.entity:SetCanSleep(false)
	        helper.persists = false

	        helper.entity:AddTransform()
	        helper.entity:AddAnimState()

	        helper:AddTag("CLASSIFIED")
	        helper:AddTag("NOCLICK")
	        helper:AddTag("placer")

	        helper.AnimState:SetBank("reticuledash")
	        helper.AnimState:SetBuild("reticuledash")
	        helper.AnimState:PlayAnimation("idle")
	        helper.AnimState:SetLightOverride(1)
	    	helper.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

	        helper.entity:SetParent(inst.entity)

	        helper:Hide()

	        return helper
	    end

        inst.lines = {}
        for i = 1, PARTNER_COUNT do
            inst.lines[i] = MakeHelperLine()
        end
    end

    return MakePlacer(data.name.."_item_placer", bank, build, anim, nil, nil, nil, nil, nil, nil, placer_postinit_fn)
end

--------------------------------------------------------------------------------------------------------

local lantern_prefabs = {}

for _, data in ipairs(LANTERN_DEFS) do
    if not data.data_only then --allow mods to skip our prefab constructor.
        table.insert(lantern_prefabs, MakeLanternPost(data))
        table.insert(lantern_prefabs, MakeLanternLightChain(data))
        --
        if data.kit_data then
            table.insert(lantern_prefabs, MakeLanternPostKitItem(data))
        end
        table.insert(lantern_prefabs, MakeLanternPostPlacer(data))
    end
end

return unpack(lantern_prefabs)