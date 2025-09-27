local assets =
{
	Asset("ANIM", "anim/yots_lantern_post.zip"),
	Asset("ANIM", "anim/ui_chest_1x1.zip"),	
	Asset("ANIM", "anim/reticuledash.zip"),
}

local prefabs =
{
	"yots_lantern_light",
	"yots_lantern_light_chain",
}

-------------------------------------------------------------------------
local sounds_1 =
{
    toggle = "dontstarve/common/together/mushroom_lamp/lantern_1_on",
    craft = "dontstarve/common/together/mushroom_lamp/craft_1",
}

local CHAIN_DIST =  8
local CHAIN_LEN = 11
local LANTERNS = 5

local LIGHT_RADIUS = 3
local LIGHT_COLOUR = Vector3(200 / 255, 100 / 255, 100 / 255)
local LIGHT_INTENSITY = .8
local LIGHT_FALLOFF = .5

local function OnUpdateFlicker(inst, starttime)
    local time = starttime ~= nil and (GetTime() - starttime) * 15 or 0
    local flicker = (math.sin(time) + math.sin(time + 2) + math.sin(time + 0.7777)) * .5 -- range = [-1 , 1]
    flicker = (1 + flicker) * .5 -- range = 0:1
    inst.Light:SetRadius(LIGHT_RADIUS + .1 * flicker)
    flicker = flicker * 2 / 255
    inst.Light:SetColour(LIGHT_COLOUR.x + flicker, LIGHT_COLOUR.y + flicker, LIGHT_COLOUR.z + flicker)
end

--------------------------------------------------------------------------

local function Pillar_PlayAnimation(inst, anim, loop)
	inst.AnimState:PlayAnimation(anim, loop)
end

local function Pillar_PushAnimation(inst, anim, loop)
	inst.AnimState:PushAnimation(anim, loop)
end

--------------------------------------------------------------------------

local function is_battery_type(item)
    return item:HasTag("lightbattery")
        or item:HasTag("spore")
        or item:HasTag("lightcontainer")
end

local function IsLightOn(inst)
    return #inst.components.container:FindItems(is_battery_type) > 0 
end

--------------------------------------------------------------------------

local function OnWorked(inst, worker, workleft, numworks)

	Pillar_PlayAnimation(inst, "hit")
	Pillar_PushAnimation(inst, "idle")

	--Dedicated server does not need to spawn the local fx
	inst.SoundEmitter:KillSound("vibrate_loop")
	inst.SoundEmitter:KillSound("chain_vibrate_loop")
end

local function OnWorkFinished(inst, worker)
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

--------------------------------------------------------------------------

local function GetStatus(inst)
	return inst:HasTag("burnt") and "BURNT" or nil -- Unused, it isn't burnable.
end
--[[
local function OnLoadPostPass(inst)

    local partner1 = inst.components.entitytracker:GetEntity("partner1")
    if partner1 ~= nil then
        inst:SetPartner(inst.partner1, partner1, "partner1")
		if not TheNet:IsDedicated() then
			Partner1Dirty(inst)
		end	        
    end
    local partner2 = inst.components.entitytracker:GetEntity("partner2")
    if partner2 ~= nil then
    	inst:SetPartner(inst.partner2, partner2, "partner2")
		if not TheNet:IsDedicated() then
			Partner2Dirty(inst)
		end	    	
    end    

    inst:checklights()
end
]]
--------------------------------------------------------------------------
local POST_MUST = {"yots_post"}

local function FindPartners(inst)
	local x,y,z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, CHAIN_DIST, POST_MUST)

	local target1=nil
	local target2=nil
	local dist = 99999
	local dist2 = 99999

	if #ents > 0 then		
		for i,ent in ipairs(ents)do			
			local entdist = ent:GetDistanceSqToInst(inst)
			
			if ent ~= inst and dist > entdist then									
				target2 = target1
				dist2 = dist

				target1 = ent
				dist = entdist
			elseif ent ~= inst and dist2 > entdist then									
				target2 = ent
				dist2 = entdist
			end
		end		
	end	

	local function spawnlight(inst, partner)
		inst.SoundEmitter:PlaySound("meta2/pillar/scaffold_place")
		local px,py,pz = partner.Transform:GetWorldPosition()
		local xdiff = px - x
		local zdiff = pz - z
		
		local newlight = SpawnPrefab("yots_lantern_light_chain")
		newlight.Transform:SetPosition(x+(xdiff/2),0,z+(zdiff/2))
		newlight.partner1:set(inst)
		newlight.partner2:set(partner)

		if IsLightOn(inst) then
			newlight.enablelight:set( newlight.enablelight:value() + 1 )
		end
		if IsLightOn(partner) then
			newlight.enablelight:set( newlight.enablelight:value() + 1 )
		end		

		if not TheNet:IsDedicated() then
			newlight:PartnerDirty()
		end

		newlight.components.entitytracker:TrackEntity("partner1", inst)
		newlight.components.entitytracker:TrackEntity("partner2", partner)

		if not inst.neighbour_lights then
			inst.neighbour_lights = {}
		end

		inst.neighbour_lights[newlight] = true

		if not partner.neighbour_lights then
			partner.neighbour_lights ={}
		end
		partner.neighbour_lights[newlight] = true
	end 

	if target1 then
		spawnlight(inst, target1)
	end

	if target2 then
		spawnlight(inst, target2)
	end
end

local function lightson(inst)
	inst.AnimState:Show("light_on")
	if not inst.light_obj then
		local newlight = SpawnPrefab("yots_lantern_light")
		inst:AddChild(newlight)
		inst.light_obj = newlight
		
		if inst.neighbour_lights then
			for light,i in pairs(inst.neighbour_lights)do
				light.enablelight:set( light.enablelight:value() + 1 )
				if not TheNet:IsDedicated() then
					light:OnLightDirty()
				end
			end
		end		
	end
end

local function lightsoff(inst)
	inst.AnimState:Hide("light_on")
	if inst.light_obj then
		inst.light_obj:Remove()
		inst.light_obj = nil

		if inst.neighbour_lights then
			for light,i in pairs(inst.neighbour_lights)do
				if light.enablelight:value() > 0 then
					light.enablelight:set( light.enablelight:value() - 1 )
					if not TheNet:IsDedicated() then
						light:OnLightDirty()
					end
				end
			end
		end			
	end
end

--------------------------------------------------------------------------

local function checklights(inst)
    if #inst.components.container:FindItems(is_battery_type) > 0 then
        lightson(inst)
    else
    	lightsoff(inst)
    end
end

-------------------------------------------------------------------------

local function onbuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle")

    inst.SoundEmitter:PlaySound("dontstarve/common/together/town_portal/craft")

   	local light = SpawnPrefab("lightbulb")
   	inst.components.container:GiveItem(light)

    inst:FindPartners()
    inst:checklights()
end

local function onremove(inst)
	if inst.neighbour_lights then
		for light,i in pairs(inst.neighbour_lights)do
			light:Remove()
		end
	end
end

-------------------------

local function is_fulllighter(item)
    return item:HasTag("fulllighter")
end

local function UpdateLightState(inst)
    if inst:HasTag("burnt") then
        return
    end

    local sound = sounds_1 
    local num_batteries = #inst.components.container:FindItems(is_battery_type)

    if num_batteries > 0 then
        local num_fulllights = #inst.components.container:FindItems(is_fulllighter)

        local new_perishrate = (num_fulllights > 0 and 0) or TUNING.PERISH_MUSHROOM_LIGHT_MULT
        inst.components.preserver:SetPerishRateMultiplier(new_perishrate)        
    else
        inst.components.preserver:SetPerishRateMultiplier(TUNING.PERISH_MUSHROOM_LIGHT_MULT)
    end

    inst:checklights()
end

-------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	MakeObstaclePhysics(inst, .25)
	inst.Physics:CollidesWith(COLLISION.OBSTACLES) --for ocean to block boats

	inst.AnimState:SetBank("yots_lantern_post")
	inst.AnimState:SetBuild("yots_lantern_post")
	inst.AnimState:PlayAnimation("idle", true)

	inst:AddTag("yots_post")

	inst.AnimState:Hide("light_on")

	inst.MiniMapEntity:SetIcon("yots_lantern_post.png")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(3)
	inst.components.workable:SetOnWorkCallback(OnWorked)
	inst.components.workable:SetOnFinishCallback(OnWorkFinished)

	inst:AddComponent("lootdropper")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("yots_lantern_post")

    inst:AddComponent("preserver")
	inst.components.preserver:SetPerishRateMultiplier(TUNING.PERISH_MUSHROOM_LIGHT_MULT)

	inst:AddComponent("entitytracker")

	inst:ListenForEvent("onbuilt", onbuilt)

	inst:ListenForEvent("onremove", onremove)

    inst:ListenForEvent("itemget", UpdateLightState)
    inst:ListenForEvent("itemlose", UpdateLightState)	

	inst.checklights = checklights
	inst.FindPartners = FindPartners	

	return inst
end

--------------------------------------------------------------------------

local sway_pos = math.random()*2
local sway_time_scale = math.random()*0.04 + 0.03
local sway_dist_scale = math.random()*0.02 + 0.06

local function calcswayoffset(inst, sway, drop, theta)	
	local radius = drop * sway * sway_dist_scale
	local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
	return offset
end

local function wallupdatepartner(inst, dt, chain, lanterns, old_chain_end_pos )
	sway_pos = sway_pos + (dt*sway_time_scale)
	if sway_pos > 2 then
		sway_pos = 0
	end

	if inst.partner1:value() ~= nil and inst.partner2:value() ~= nil then
		local x1, y1, z1 = TheSim:GetScreenPos(inst.partner1:value().Transform:GetWorldPosition())
		local x2, y2, z2 = TheSim:GetScreenPos(inst.partner2:value().Transform:GetWorldPosition())
		old_chain_end_pos = Vector3(x2, y2, z2)

		local w, h = TheSim:GetWindowSize()
		local dfront = (y2 - y1) * RESOLUTION_Y / h
		local front = dfront > -10

		x1, y1, z1 = inst.partner1:value().AnimState:GetSymbolPosition("swap_shackle")
		x2, y2, z2 = inst.partner2:value().AnimState:GetSymbolPosition("swap_shackle")

		local xdif = x1-x2
		local ydif = y1-y2
		local zdif = z1-z2

		local theta = (inst.partner1:value():GetAngleToPoint(x2, 0, z2) -90) /RADIANS

		for i, v in ipairs(chain) do
			local p = i/(#chain+1)

			local drop = math.sin(PI*p)

			local off = calcswayoffset(inst, math.sin(PI*sway_pos), drop, theta)

			v.Transform:SetPosition(x1-(xdif*p)+off.x,y1-(ydif*p)-drop,z1-(zdif*p)+off.z)
			if not v.components.timer:TimerExists("hide") then
				v:Show()
			end
		end

		for i, v in ipairs(lanterns) do
			local p = i/(#lanterns+1)

			local drop = math.sin(PI*p)

			local off = calcswayoffset(inst, math.sin(PI*sway_pos), drop, theta)
				
			v.Transform:SetPosition(x1-(xdif*p)+off.x,y1-(ydif*p)-drop,z1-(zdif*p)+off.z)
			if not v.components.timer:TimerExists("hide") then
				v:Show()
			end
		end		
	else
		for i, v in ipairs(chain) do
			if not old_chain_end_pos then
				v:Hide()
			end
		end
		for i, v in ipairs(lanterns) do
			if not old_chain_end_pos then
				v:Hide()
			end
		end		
	end

	return old_chain_end_pos
end

local function OnWallUpdate(inst, dt)
	dt = dt * TheSim:GetTimeScale()

	if inst.partner1:value() and inst.partner2:value() and inst.chain and #inst.chain > 0 then
		inst.old_chain_end_pos = wallupdatepartner(inst, dt, inst.chain, inst.lanterns, inst.old_chain_end_pos )
	end                                          
end

local function CreateChainLink(variation)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("yots_lantern_post")
	inst.AnimState:SetBuild("yots_lantern_post")
	inst.variation = variation
	inst.AnimState:PlayAnimation("link_"..inst.variation, true)

	inst:AddComponent("timer")

	inst:Hide()

	return inst
end

local function CreateLantern()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("yots_lantern_post")
	inst.AnimState:SetBuild("yots_lantern_post")
	inst.AnimState:PlayAnimation("lantern", true)

	inst.AnimState:Hide("light_on")

	inst:AddComponent("timer")

	inst:ListenForEvent("animover", function()
			if inst.AnimState:IsCurrentAnimation("break") then
				inst:Remove()
			end
		end)

	inst:Hide()

	return inst
end

local og = {"1","2"}
local copy = deepcopy(og)

local function SpawnChain(inst)

	copy = deepcopy(og)
	local chain = {}	
	for i = 1, CHAIN_LEN do
		table.insert(chain, CreateChainLink(copy[1]))
		chain[#chain].components.timer:StartTimer("hide",((#chain)/CHAIN_LEN-1)*0.2)

		table.remove(copy,1)
		if #copy <= 0 then
			copy = deepcopy(og)
		end
	end

	local lanterns = {}
	for i = 1, LANTERNS do
		local lantern = CreateLantern()
		if inst.enablelight:value() > 0 then
			lantern.AnimState:Show("light_on")
		else
			lantern.AnimState:Hide("light_on")
		end
		table.insert(lanterns, lantern)
		lantern.components.timer:StartTimer("hide",((#lanterns)/CHAIN_LEN-1)*0.2)		
	end	

	return chain, lanterns	
end

local function RemoveChain(inst, chain, lanterns)

	if chain ~= nil and #chain > 0 then
		for i=#chain,1,-1 do
			local v = chain[i]
			local t = i
			if not inst:HasTag("removing") then
				t = CHAIN_LEN - i
			end
			
			if not inst:IsAsleep() then			
				local fx = CreateChainLink(v.variation)
				fx:Show(true)
				local x,y,z = v.Transform:GetWorldPosition()
				fx.Transform:SetPosition(x,y,z)
				fx:DoTaskInTime( ((t+1)/CHAIN_LEN)*0.2 , function() 
						fx:Remove()
					end)
			end

			v:Remove()
		end
		chain = nil
	end

	if lanterns ~= nil and #lanterns > 0 then
		for i=#lanterns,1,-1 do
			local v = lanterns[i]
			local t = i
			if not inst:HasTag("removing") then
				t = LANTERNS - i
			end
			
			if not inst:IsAsleep() then	
				local fx = CreateLantern()
				fx:Show(true)
				local x,y,z = v.Transform:GetWorldPosition()
				fx.Transform:SetPosition(x,y,z)
				fx:DoTaskInTime( ((t+1)/LANTERNS)*0.2 , function() 
						fx.AnimState:PlayAnimation("break")
					end)
			end

			v:Remove()
		end
		lanterns = nil
	end
	return chain, lanterns
end

local function PartnerDirty(inst)
	if inst.partner1:value() and inst.partner2:value() then
		if not inst.chain then
			inst.chain, inst.lanterns = SpawnChain(inst)
		end
	else
		if inst.chain then
			inst.chain, inst.lanterns = RemoveChain(inst, inst.chain, inst.lanterns)
		end
	end
end

local function OnLightDirty(inst)
	if inst.enablelight:value() > 0 then
		if inst.lanterns and #inst.lanterns> 0 then
			for i, lantern in ipairs(inst.lanterns)do
				lantern.AnimState:Show("light_on")
			end
		end
		inst.Light:Enable(true)
	else		
		if inst.lanterns and #inst.lanterns > 0 then
			for i, lantern in ipairs(inst.lanterns)do
				lantern.AnimState:Hide("light_on")
			end
		end
		inst.Light:Enable(false)
	end	
end

local function breakthechain(inst)
	inst:AddTag("removing")
	inst.Light:Enable(false)	
end

--------------------------------------------------------------------------

local function onNear(inst,player)
	if not inst.chain and inst.partner1:value() and inst.partner2:value() then
		inst.chain, inst.lanterns = SpawnChain(inst)
	end	
end

local function onFar(inst,player)
	if inst.chain then
		inst.chain, inst.lanterns = RemoveChain(inst, inst.chain, inst.lanterns)
	end		
end

local function OnRemoveEntity_Client(inst)
	inst:AddTag("removing")
	RemoveChain(inst, inst.chain, inst.lanterns)
end

local near_prox = 39*39
local far_prox = 41*41
local function OnUpdateFn(inst, dt)
	local dist = inst:GetDistanceSqToInst(ThePlayer)

	if dist < near_prox and not inst.near then
		onNear(inst)
		inst.near = true
	elseif dist > far_prox and inst.near == true then
		onFar(inst)
		inst.near = false
	end
end
------------------------------------------------------------------------------

local function OnLoadPostPass(inst)

	local partner1 = inst.components.entitytracker:GetEntity("partner1")
	local partner2 = inst.components.entitytracker:GetEntity("partner2")

	inst.partner1:set(partner1)
	inst.partner2:set(partner2)

	if IsLightOn(partner1) then
		inst.enablelight:set( inst.enablelight:value() + 1 )
	end
	if IsLightOn(partner2) then
		inst.enablelight:set( inst.enablelight:value() + 1 )
	end		

	if not TheNet:IsDedicated() then
		inst:PartnerDirty()
	end

	if not partner1.neighbour_lights then
		partner1.neighbour_lights = {}
	end
	partner1.neighbour_lights[inst] = true

	if not partner2.neighbour_lights then
		partner2.neighbour_lights ={}
	end
	partner2.neighbour_lights[inst] = true
end

-------------------------------------------------------------------------------

local function lightchainfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()	
	inst.entity:AddLight()	
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.Light:SetIntensity(.85)	
	inst.Light:SetFalloff(.7)	
    inst.Light:EnableClientModulation(true)
    inst.light_radius = 3

    inst:DoPeriodicTask(.1, OnUpdateFlicker, nil, GetTime())
    OnUpdateFlicker(inst)

	inst.partner1 = net_entity(inst.GUID, "yots_lantern_light.partner1", "partner1dirty")
	inst.partner2 = net_entity(inst.GUID, "yots_lantern_light.partner2", "partner2dirty")
	inst.enablelight = net_tinybyte(inst.GUID, "yots_lantern_light.enablelight", "lightdirty")
	inst.enablelight:set(0)

	inst.entity:SetPristine()

 	if not TheWorld.ismastersim or not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")		
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateFn)
		inst.components.updatelooper:AddOnWallUpdateFn(OnWallUpdate)
		
		inst.near = nil

		inst.OnLightDirty = OnLightDirty
		inst.OnRemoveEntity = OnRemoveEntity_Client	
		inst.PartnerDirty = PartnerDirty
 	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("partner1dirty", PartnerDirty)
		inst:ListenForEvent("partner2dirty", PartnerDirty)
		inst:ListenForEvent("lightdirty", OnLightDirty)
	
		return inst
	end

	inst:AddComponent("entitytracker")

	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

-------------------------------------------------------------

local function lightfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()	
	inst.entity:AddLight()	
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	inst.Light:SetIntensity(.85)	
	inst.Light:SetFalloff(.7)	
    inst.Light:EnableClientModulation(true)
    inst.light_radius = 3

    inst:DoPeriodicTask(.1, OnUpdateFlicker, nil, GetTime())
    OnUpdateFlicker(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

    inst.persists = false
	return inst
end

-------------------------------------------------------

local function placer_onupdatetransform(inst)

	local x,y,z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, CHAIN_DIST, POST_MUST)

	local target=nil
	local target2=nil
	local dist = 99999
	local dist2 = 99999

	if #ents > 0 then		
		for i,ent in ipairs(ents)do			
			local entdist = ent:GetDistanceSqToInst(inst)
			
			if ent ~= inst and dist > entdist then									
				target2 = target
				dist2 = dist

				target = ent
				dist = entdist
			elseif ent ~= inst and dist2 > entdist then									
				target2 = ent
				dist2 = entdist
			end
		end		
	end

	if inst.line then
		if target then
			local tx,ty,tz = target.Transform:GetWorldPosition()
			inst.line.Transform:SetRotation(inst:GetAngleToPoint(tx,ty,tz))
			inst.line:Show()

			local chunk = 0.73
			local num = math.floor(math.sqrt(dist)/chunk)

			for i=1,13 do
				if i > num +1 then
					inst.line.AnimState:Hide("target"..i)
				else
					inst.line.AnimState:Show("target"..i)
				end
			end
		else
			inst.line:Hide()
		end
	end

-----------------------

	if inst.line2 then
		if target2 then
			local tx,ty,tz = target2.Transform:GetWorldPosition()
			inst.line2.Transform:SetRotation(inst:GetAngleToPoint(tx,ty,tz))
			inst.line2:Show()

			local chunk = 0.73
			local num = math.floor(math.sqrt(dist2)/chunk)

			for i=1,13 do
				if i > num +1 then
					inst.line2.AnimState:Hide("target"..i)
				else
					inst.line2.AnimState:Show("target"..i)
				end
			end

		else
			inst.line2:Hide()
		end
	end
end

local function placer_postinit_fn(inst)
	inst.AnimState:Hide("light_on")
	inst.components.placer.onupdatetransform = placer_onupdatetransform

	local function makeline()
		local l = CreateEntity()

	    --[[Non-networked entity]]
	    l.entity:SetCanSleep(false)
	    l.persists = false

	    l.entity:AddTransform()
	    l.entity:AddAnimState()

	    l:AddTag("CLASSIFIED")
	    l:AddTag("NOCLICK")
	    l:AddTag("placer")

	    l.AnimState:SetBank("reticuledash")
	    l.AnimState:SetBuild("reticuledash")
	    l.AnimState:PlayAnimation("idle")
	    l.AnimState:SetLightOverride(1)
		l.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

	    l.entity:SetParent(inst.entity)
	   
	    l:Hide()

	    return l
	end

	inst.line = makeline()
	inst.line2 = makeline()
    
end

local deployable_data =
{
	deploymode = DEPLOYMODE.CUSTOM,
	custom_candeploy_fn = function(inst, pt, mouseover, deployer)
		local x, y, z = pt:Get()
		return TheWorld.Map:CanDeployAtPoint(pt, inst, mouseover) and TheWorld.Map:IsAboveGroundAtPoint(x, y, z, false)
	end,
}

return Prefab("yots_lantern_post", fn, assets, prefabs),
		Prefab("yots_lantern_light", lightfn, assets, prefabs),
		Prefab("yots_lantern_light_chain", lightchainfn, assets, prefabs),
		MakeDeployableKitItem("yots_lantern_post_item", "yots_lantern_post", "yots_lantern_post", "yots_lantern_post", "kit", {Asset("ANIM", "anim/yots_lantern_post.zip")}, {size = "med", scale = 0.77}, nil, {fuelvalue = TUNING.LARGE_FUEL}, deployable_data),
		MakePlacer("yots_lantern_post_item_placer", "yots_lantern_post", "yots_lantern_post", "placer", nil, nil, nil, nil, nil, nil, placer_postinit_fn)