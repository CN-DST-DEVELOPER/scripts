local assets = {
    Asset("ANIM", "anim/vault_lobby_exit.zip"),
}

local function StartTravelSound(inst, doer)
    inst.SoundEmitter:PlaySound("dontstarve/cave/tentapiller_hole_enter") -- FIXME(JBK): rifts6 sounds
    doer:PushEvent("wormholetravel", WORMHOLETYPE.VAULTLOBBYEXIT) --Event for playing local travel sound
end

local function OnActivate(inst, doer)
    if doer:HasTag("player") then
        if doer.components.talker ~= nil then
            doer.components.talker:ShutUp()
        end
        --Sounds are triggered in player's stategraph
    elseif inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/cave/tentapiller_hole_enter") -- FIXME(JBK): rifts6 sounds
    end
end

local function SetExitTarget(inst, targetinst)
    local oldtarget = inst.components.teleporter:GetTarget()
    if oldtarget then
        inst:RemoveEventCallback("onremove", inst._exittarget_onremove, targetinst)
    end

    inst.components.teleporter:Target(targetinst)
    if not targetinst then
        inst.components.teleporter:SetEnabled(false)
        return
    end
    
    inst.components.teleporter:SetEnabled(true)
    inst:ListenForEvent("onremove", inst._exittarget_onremove, targetinst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst:AddTag("groundhole")
    inst:AddTag("blocker")

    inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
	inst.Physics:SetCollisionMask(
		COLLISION.ITEMS,
		COLLISION.CHARACTERS,
		COLLISION.GIANTS
	)
    inst.Physics:SetCylinder(1.8, 6)

    inst.AnimState:SetBank("vault_lobby_exit")
    inst.AnimState:SetBuild("vault_lobby_exit")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(2)
    --NOTE: Shadows are on WORLD_BACKGROUND sort order 1
    --      Hole goes above to hide shadows
    --      Surface goes below to reveal shadows

    inst.MiniMapEntity:SetIcon("vault_lobby_exit.png")

    inst.Transform:SetEightFaced()

	inst:SetDeploySmartRadius(3)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_facing = FACING_LEFT

    inst:AddComponent("inspectable")

    local teleporter = inst:AddComponent("teleporter")
    teleporter.onActivate = OnActivate
    teleporter.overrideteleportarrivestate = "abyss_drop"
    teleporter.offset = 3
    teleporter:SetSelfManaged(true)
    teleporter:SetEnabled(false)
    inst.StartTravelSound = StartTravelSound
    inst:ListenForEvent("starttravelsound", inst.StartTravelSound) -- triggered by player stategraph

    inst.SetExitTarget = SetExitTarget
    inst._exittarget_onremove = function()
        inst:SetExitTarget(nil)
    end
    TheWorld:PushEvent("ms_register_vault_lobby_exit", inst)

    return inst
end

return Prefab("vault_lobby_exit", fn, assets)
