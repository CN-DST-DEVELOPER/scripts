local assets =
{
    Asset("ANIM", "anim/chandelier_archives.zip"),
    Asset("ANIM", "anim/chandelier_fire.zip"),
}

local assets_vault =
{
	Asset("ANIM", "anim/chandelier_vault.zip"),
}

local assets_crawler =
{
	Asset("ANIM", "anim/chandelier_vault2.zip"),
}

local prefabs_crawler =
{
	"vault_crawler",
}

local OFF = 0
local ON = 1
local DROP = 2

local LIGHT_PARAMS =
{
	[ON] =
    {
		id = ON,
        radius = 5,
        intensity = .6,
        falloff = .6,
        colour = { 131/255, 194/255, 255/255 },
        time = 3,
    },

	[OFF] =
    {
		id = OFF,
        radius = 0,
        intensity = 0,
        falloff = 1,
        colour = { 0, 0, 0 },
        time = 3,
    },
}

local LIGHT_PARAMS_VAULT =
{
	[ON] =
	{
		id = ON,
		radius = 4.5,
		intensity = 0.7,
		falloff = 0.65,
		colour = { 180/255, 240/255, 255/255 },
		time = 3,
	},

	[OFF] =
	{
		id = OFF,
		radius = 0,
		intensity = 0,
		falloff = 1,
		colour = { 0, 0, 0 },
		time = 3,
	},

	[DROP] =
	{
		id = DROP,
		radius = 4.5,
		intensity = 0.7,
		falloff = 0.8,
		colour = { 180/255, 240/255, 255/255 },
		time = 9 * FRAMES,
	},
}

local FLAMEDATA = {
    "flame1",
    "flame2",
    "flame3",
    "flame4",
}

--------------------------------------------------------------------------

local function CreateFireFx()
	local inst = CreateEntity()

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetBank("chandelier_fire")
	inst.AnimState:SetBuild("chandelier_fire")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	return inst
end

--------------------------------------------------------------------------

local function sfx_StartSound(inst, level)
	if not inst.SoundEmitter:PlayingSound("firesfx") then
		inst.SoundEmitter:PlaySound("grotto/common/chandelier_LP", "firesfx")
	end
	inst.SoundEmitter:SetParameter("firesfx", "intensity", level)
end

local function sfx_SetSoundLevel(inst, level)
	if inst.level ~= level then
		inst.level = level
		if not inst:IsAsleep() then
			if level > 0 then
				sfx_StartSound(inst, level)
			else
				inst.SoundEmitter:KillSound("firesfx")
			end
		end
	end
end

local function sfx_OnEntitySleep(inst)
	if inst.level > 0 then
		inst.SoundEmitter:KillSound("firesfx")
	end
end

local function sfx_OnEntityWake(inst)
	if inst.level > 0 then
		sfx_StartSound(inst, inst.level)
	end
end

local function CreateSfxProp()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	if TheWorld.ismastersim then
		inst.OnEntitySleep = sfx_OnEntitySleep
		inst.OnEntityWake = sfx_OnEntityWake
	else
		inst.entity:SetCanSleep(false)
	end
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()

	inst.level = 0
	inst.SetSoundLevel = sfx_SetSoundLevel

	return inst
end

--------------------------------------------------------------------------

local function pushparams(inst, params)
    inst.Light:SetRadius(params.radius * inst.widthscale)
    inst.Light:SetIntensity(params.intensity)
    inst.Light:SetFalloff(params.falloff)
    inst.Light:SetColour(unpack(params.colour))

    if TheWorld.ismastersim then
		if params.intensity > 0 and not inst.detached then
            inst.Light:Enable(true)
        else
            inst.Light:Enable(false)
        end
    end

	if inst.sfxprop then
		inst.sfxprop:SetSoundLevel(params.intensity)
	end
end

-- Not using deepcopy because we want to copy in place
local function copyparams(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            copyparams(dest[k], v)
        else
            dest[k] = v
        end
    end
end

local function lerpparams(pout, pstart, pend, lerpk)
    for k, v in pairs(pend) do
        if type(v) == "table" then
            lerpparams(pout[k], pstart[k], v, lerpk)
        else
            pout[k] = pstart[k] * (1 - lerpk) + v * lerpk
        end
    end
end

local function UpdateFlames(inst)
	if inst.flamedata and not TheNet:IsDedicated() then
		for k, v in pairs(inst.flamedata) do
			local val = Remap(inst._currentlight.intensity, inst.light_params[OFF].intensity, inst.light_params[ON].intensity, 0, 1)
			local fx = inst[v]
			if val > 0 then
				if fx == nil then
					fx = CreateFireFx()
					fx.entity:SetParent(inst.entity)
					fx.Follower:FollowSymbol(inst.GUID, v)
					inst[v] = fx
				end
				fx.AnimState:SetLightOverride(val)
				fx.AnimState:SetScale(val, val, val)
			elseif fx then
				fx:Remove()
				inst[v] = nil
			end
		end
	end
end

local function OnUpdateLight(inst, dt)
    inst._currentlight.time = inst._currentlight.time + dt
    if inst._currentlight.time >= inst._endlight.time then
        inst._currentlight.time = inst._endlight.time
        inst._lighttask:Cancel()
        inst._lighttask = nil
    end

    lerpparams(inst._currentlight, inst._startlight, inst._endlight, inst._endlight.time > 0 and inst._currentlight.time / inst._endlight.time or 1)
    pushparams(inst, inst._currentlight)

	if TheWorld.ismastersim then
		--only used by clients construction/oninit, so just use set_local
		inst._lightlerp:set_local(math.min(7, math.ceil(inst._currentlight.time / inst._endlight.time * 7)))

		inst.AnimState:SetLightOverride(Remap(inst._currentlight.intensity, inst.light_params[OFF].intensity, inst.light_params[ON].intensity, 0,1))
	end

	UpdateFlames(inst)
end

local function OnLightPhaseDirty(inst)
	local params = inst.light_params[inst._lightphase:value()]
	if params and params ~= inst._endlight then
		copyparams(inst._startlight, inst._currentlight)
		if TheWorld.ismastersim then
			inst._lightlerp:set(0)
		end
		inst._currentlight.time = 0
		inst._startlight.time = 0
		inst._endlight = params
		if inst._lighttask == nil then
			inst._lighttask = inst:DoPeriodicTask(FRAMES, OnUpdateLight, nil, FRAMES)
		end
		return true
	end
end

local function OnSpawnTask(inst, cavephase)
    inst._spawntask = nil
    if cavephase == "day" then
        inst.components.hideout:StartSpawning()
    else
        inst.components.hideout:StopSpawning()
    end
end

local function _updatelight(inst)
	local powered
	if inst.vaultpowered then
		local vaultroommanager = TheWorld.components.vaultroommanager
		powered = vaultroommanager ~= nil and vaultroommanager:NumPlayersInVault() > 0
	else
		local archivemanager = TheWorld.components.archivemanager
		local playerprox = inst.components.playerprox
		powered = (playerprox == nil or playerprox:IsPlayerClose()) and (archivemanager == nil or archivemanager:GetPowerSetting())
	end
	if powered then
        if inst._lightphase:value() ~= ON then
            inst._lightphase:set(ON)
            OnLightPhaseDirty(inst)
        end
    else
        if inst._lightphase:value() ~= OFF then
            inst._lightphase:set(OFF)
            OnLightPhaseDirty(inst)
        end
    end
end

local function OnInit(inst)
	if not TheWorld.ismastersim then
        inst:ListenForEvent("lightphasedirty", OnLightPhaseDirty)
		if inst._lightlerp:value() < 7 then
			--resume lerping from when it was serialized on server
			if OnLightPhaseDirty(inst) then
				inst._currentlight.time = inst._endlight.time * inst._lightlerp:value() / 7
				OnUpdateLight(inst, FRAMES)
			end
			return
		end
    end

	--Skip lerping the lights
	local params = inst.light_params[inst._lightphase:value()]
	if params and params ~= inst._endlight then
		copyparams(inst._currentlight, params)
		inst._endlight = params
		if inst._lighttask then
			inst._lighttask:Cancel()
			inst._lighttask = nil
		end
		pushparams(inst, inst._currentlight)
		UpdateFlames(inst)
	end
end

local function MakeChandelier(name, build, light_params, flamedata, sfxheight, common_postinit, master_postinit, assets, prefabs)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddLight()
		inst.entity:AddNetwork()

		inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		inst.AnimState:SetBank(build)
		inst.AnimState:SetBuild(build)
		inst.AnimState:PlayAnimation("idle", true)

		inst.Light:EnableClientModulation(true)

		inst:AddTag("NOCLICK")
		inst:AddTag("FX")
		inst:AddTag("archive_chandelier")

		inst.light_params = light_params
		inst.flamedata = flamedata
		inst.widthscale = 1
		inst._endlight = light_params[OFF]
		inst._startlight = {}
		inst._currentlight = {}
		copyparams(inst._startlight, inst._endlight)
		copyparams(inst._currentlight, inst._endlight)
		pushparams(inst, inst._currentlight)

		inst._lightphase = net_tinybyte(inst.GUID, "archive_chandelier._lightphase", "lightphasedirty")
		inst._lightphase:set(inst._currentlight.id)
		inst._lighttask = nil

		--only used by clients on init
		inst._lightlerp = net_tinybyte(inst.GUID, "archive_chandelier._lightlerp")

		if not TheNet:IsDedicated() then
			inst.sfxprop = CreateSfxProp()
			inst.sfxprop.entity:SetParent(inst.entity)
			inst.sfxprop.Transform:SetPosition(0, sfxheight, 0)
		end

		inst:DoTaskInTime(0, OnInit)

		if common_postinit then
			common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

		inst.updatelight = _updatelight

		if master_postinit then
			master_postinit(inst)
		end

		return inst
	end
	return Prefab(name, fn, assets, prefabs)
end

--------------------------------------------------------------------------

local function archive_master_postinit(inst)
	inst:AddComponent("playerprox")
	inst.components.playerprox:SetDist(20, 23) --15,17
	inst.components.playerprox:SetOnPlayerNear(inst.updatelight)
	inst.components.playerprox:SetOnPlayerFar(inst.updatelight)

	inst:ListenForEvent("arhivepoweron", function() inst:updatelight() end, TheWorld)
	inst:ListenForEvent("arhivepoweroff", function() inst:updatelight() end, TheWorld)
end

--------------------------------------------------------------------------

local function vault_SetVariation(inst, variation)
	inst.variation = variation
	local anim = variation == 1 and "idle" or "idle_2"
	if not inst.AnimState:IsCurrentAnimation(anim) then
		local t = inst.AnimState:GetCurrentAnimationTime()
		inst.AnimState:PlayAnimation(anim, true)
		inst.AnimState:SetTime(t)
	end
	return inst
end

local function vault_OnSave(inst, data)
	data.variation = inst.variation ~= 1 and inst.variation or nil
end

local function vault_OnLoad(inst, data)--, ents)
	if data and data.variation then
		inst:SetVariation(data.variation)
	end
end

local function vault_master_postinit(inst)
	inst.vaultpowered = true
	inst.variation = 1
	inst.SetVariation = vault_SetVariation
	inst.OnSave = vault_OnSave
	inst.OnLoad = vault_OnLoad

	inst:ListenForEvent("ms_vaultroom_vault_playerleft", function() inst:updatelight() end, TheWorld)
	inst:ListenForEvent("ms_vaultroom_vault_playerentered", function() inst:updatelight() end, TheWorld)
	inst:updatelight()
end

--------------------------------------------------------------------------

local function crawler_OnClawSfxDirty(inst)
	if inst.sfxprop then
		if inst.clawsfx:value() == 1 then
			inst.sfxprop.SoundEmitter:PlaySound("rifts7/vault_claw/open")
		elseif inst.clawsfx:value() == 2 then
			inst.sfxprop.SoundEmitter:PlaySound("rifts7/vault_claw/withdraw")
		end
	end
end

local function crawler_TriggerClawSfx(inst, id)
	inst.clawsfx:set_local(id)
	inst.clawsfx:set(id)
	crawler_OnClawSfxDirty(inst)
end

local function crawler_UpdateLight(inst)
	if not inst.dropped then
		_updatelight(inst)
	elseif inst._lightphase:value() ~= DROP then
		inst._lightphase:set(DROP)
		OnLightPhaseDirty(inst)
	end
end

local function crawler_OnAnimOver(inst)
	if inst.AnimState:IsCurrentAnimation("fall") then
		inst.persists = false
		inst.detached = true
		inst.Light:Enable(false)
		inst.AnimState:ClearBloomEffectHandle()
		inst.AnimState:SetFinalOffset(2)

		local x, _, z = inst.Transform:GetWorldPosition()
		local crawler = SpawnPrefab("vault_crawler")
		crawler.Transform:SetPosition(x, 0, z)
		crawler.sg:GoToState("spawn")

		inst:PushEvent("ms_vaultcrawler_dropped", crawler)

		if inst:IsAsleep() then
			inst:Remove()
		else
			inst.OnEntitySleep = inst.Remove
			inst.AnimState:PlayAnimation("fall_pst")
		end
	elseif inst.AnimState:IsCurrentAnimation("fall_pst") then
		inst.AnimState:PlayAnimation("withdraw")
		crawler_TriggerClawSfx(inst, 2)
	elseif inst.AnimState:IsCurrentAnimation("withdraw") then
		inst:Remove()
	end
end

local function crawler_DropCrawler(inst)
	if inst.dropped then
		return
	end
	inst.dropped = true
	inst:ListenForEvent("animover", crawler_OnAnimOver)
	inst.AnimState:PlayAnimation("fall")
	crawler_TriggerClawSfx(inst, 1)
	inst:updatelight()
end

local function crawler_common_postinit(inst)
	inst.clawsfx = net_tinybyte(inst.GUID, "vault_crawler_chandelier.clawsfx", "clawsfxdirty")

	if not TheWorld.ismastersim then
		inst:DoTaskInTime(0, inst.ListenForEvent, "clawsfxdirty", crawler_OnClawSfxDirty)
	end
end

local function crawler_master_postinit(inst)
	inst.vaultpowered = true
	inst.updatelight = crawler_UpdateLight
	inst.DropCrawler = crawler_DropCrawler

	inst:ListenForEvent("ms_vaultroom_vault_playerleft", function() inst:updatelight() end, TheWorld)
	inst:ListenForEvent("ms_vaultroom_vault_playerentered", function() inst:updatelight() end, TheWorld)
	inst:updatelight()
end

--------------------------------------------------------------------------

return MakeChandelier("archive_chandelier", "chandelier_archives", LIGHT_PARAMS, FLAMEDATA, 8, nil, archive_master_postinit, assets),
	MakeChandelier("vault_chandelier", "chandelier_vault", LIGHT_PARAMS_VAULT, nil, 6, nil, vault_master_postinit, assets_vault),
	MakeChandelier("vault_crawler_chandelier", "chandelier_vault2", LIGHT_PARAMS_VAULT, nil, 6, crawler_common_postinit, crawler_master_postinit, assets_crawler, prefabs_crawler)
