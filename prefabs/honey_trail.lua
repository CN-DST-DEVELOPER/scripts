local HONEYTRAILSLOWDOWN_MUST_TAGS = { "locomotor" }
local HONEYTRAILSLOWDOWN_CANT_TAGS = { "flying", "playerghost", "INLIMBO", "honey_ammo_afflicted", "vigorbuff" }
local HONEYTRAILSLOWDOWN_CANT_TAGS_SHROUDEN = { "flying", "playerghost", "INLIMBO", "gelblobbed" }

local function OnUpdateServer(inst, x, y, z, rad, server_exclude_tags)
	local ents =
		inst.registered_tags and
		TheSim:FindEntities_Registered(x, y, z, rad, inst.registered_tags) or
		TheSim:FindEntities(x, y, z, rad, HONEYTRAILSLOWDOWN_MUST_TAGS, server_exclude_tags)

    for _, v in ipairs(ents) do
        if v.components.locomotor and (inst.filterfn == nil or inst.filterfn(v, inst)) then
            v.components.locomotor:PushTempGroundSpeedMultiplier(TUNING.BEEQUEEN_HONEYTRAIL_SPEED_PENALTY, WORLD_TILES.MUD)
        end
    end
end

local CLIENT_EXCLUDE_TAGS = { "playerghost", "honey_ammo_afflicted", "vigorbuff" }
local CLIENT_EXCLUDE_TAGS_SHROUDEN = { "playerghost", "gelblobbed" }

local function OnUpdateClient(inst, x, y, z, rad, client_exclude_tags)
    local player = ThePlayer
    if player ~= nil and
        player.components.locomotor ~= nil and
		not player:HasAnyTag(client_exclude_tags) and
        player:GetDistanceSqToPoint(x, 0, z) < rad * rad then
        player.components.locomotor:PushTempGroundSpeedMultiplier(TUNING.BEEQUEEN_HONEYTRAIL_SPEED_PENALTY, WORLD_TILES.MUD)
    end
end

local function OnIsFadingDirty(inst)
    if inst._isfading:value() then
        inst.task:Cancel()
    end
end

local function OnStartFade(inst)
    inst.AnimState:PlayAnimation(inst.trailname.."_pst")
    inst._isfading:set(true)
    inst.task:Cancel()
end

local function OnAnimOver(inst)
    if inst.AnimState:IsCurrentAnimation(inst.trailname.."_pre") then
        inst.AnimState:PlayAnimation(inst.trailname)
        inst:DoTaskInTime(inst.duration, OnStartFade)
    elseif inst.AnimState:IsCurrentAnimation(inst.trailname.."_pst") then
        inst:Remove()
    end
end

local function OnInit(inst, _exclude_tags, scale)
    local x, y, z = inst.Transform:GetWorldPosition()
    if scale == nil then
        scale = inst.Transform:GetScale()
    end
    inst.task:Cancel()
    local onupdatefn = TheWorld.ismastersim and OnUpdateServer or OnUpdateClient
    inst.task = inst:DoPeriodicTask(0, onupdatefn, nil, x, y, z, scale, _exclude_tags)
    onupdatefn(inst, x, y, z, scale, _exclude_tags)
end

local function OverrideSearchParams(inst, registered_tags, filterfn)
	inst.registered_tags = registered_tags
	inst.filterfn = filterfn
end

local function MakeFx(name, data)
	local assets =
	{
		Asset("ANIM", "anim/honey_trail.zip"),
	}
	if data.build ~= "honey_trail" then
		table.insert(assets, Asset("ANIM", "anim/"..data.build..".zip"))
	end

	local function SetVariation(inst, rand, scale, duration)
		if inst.trailname == nil then
			inst.Transform:SetScale(scale, scale, scale)

			inst.trailname = "trail"..tostring(rand)
			inst.duration = duration
			inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/honey_drip")
			inst.AnimState:PlayAnimation(inst.trailname.."_pre")
			inst:ListenForEvent("animover", OnAnimOver)

			OnInit(inst, data.server_exclude_tags, scale)
		end
	end

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		inst:AddTag("FX")

		inst.AnimState:SetBank("honey_trail")
		inst.AnimState:SetBuild(data.build)
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(3)
		if data.light_override then
			inst.AnimState:SetLightOverride(data.light_override)
		end

		inst._isfading = net_bool(inst.GUID, name.."._isfading", "isfadingdirty")

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			inst:ListenForEvent("isfadingdirty", OnIsFadingDirty)
			inst.task = inst:DoPeriodicTask(0, OnInit, nil, data.client_exclude_tags)

			return inst
		end

		inst.SetVariation = SetVariation
		inst.OverrideSearchParams = OverrideSearchParams

		inst.persists = false
		inst.task = inst:DoTaskInTime(0, inst.Remove)

		return inst
	end

	return Prefab(name, fn, assets)
end

return MakeFx("honey_trail", {
		build = "honey_trail",
		client_exclude_tags = CLIENT_EXCLUDE_TAGS,
		server_exclude_tags = HONEYTRAILSLOWDOWN_CANT_TAGS,
	}),
	MakeFx("honey_trail_shrouden_fx", {
		build = "honey_trail_shrouden",
		client_exclude_tags = CLIENT_EXCLUDE_TAGS_SHROUDEN,
		server_exclude_tags = HONEYTRAILSLOWDOWN_CANT_TAGS_SHROUDEN,
		light_override = 1,
	})
