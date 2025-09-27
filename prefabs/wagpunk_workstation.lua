local assets = {
    Asset("ANIM", "anim/wagpunk_workstation.zip"),
    Asset("SOUND", "sound/together.fsb"), -- FIXME(JBK): WA: Sounds.
}

local sounds = { -- FIXME(JBK): WA: Sounds.
    idle = "rifts5/wagpunk_station/proximity_LP",
    use = "rifts5/wagpunk_station/use",
}

local function OnTurnOn(inst)
    if inst.prototyper_activatedtask then
        return
    end

    inst.AnimState:PushAnimation("proximity_loop", true)
    if not inst.SoundEmitter:PlayingSound("idlesound") then
        inst.SoundEmitter:PlaySound(sounds.idle, "idlesound")
    end

    if TheWorld.components.wagpunk_arena_manager then
        TheWorld.components.wagpunk_arena_manager:WorkstationToggled(inst, true)
    end
end

local function OnTurnOff(inst)
    if inst.prototyper_activatedtask then
        return
    end

    inst.AnimState:PlayAnimation("idle", false)
    inst.SoundEmitter:KillSound("idlesound")

    if TheWorld.components.wagpunk_arena_manager then
        TheWorld.components.wagpunk_arena_manager:WorkstationToggled(inst, false)
    end
end

local function FinishUseAnim(inst)
    inst.prototyper_activatedtask = nil
    if inst.components.prototyper.on then
        inst.AnimState:PlayAnimation("proximity_loop", true)
        if not inst.SoundEmitter:PlayingSound("idlesound") then
            inst.SoundEmitter:PlaySound(sounds.idle, "idlesound")
        end
    else
        inst.AnimState:PushAnimation("idle")
        inst.SoundEmitter:KillSound("idlesound")
    end
end

local function OnActivate(inst)
    inst.AnimState:PlayAnimation("use")
    inst.SoundEmitter:PlaySound(sounds.use)

    if inst.prototyper_activatedtask ~= nil then
        inst.prototyper_activatedtask:Cancel()
        inst.prototyper_activatedtask = nil
    end
    inst.prototyper_activatedtask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), FinishUseAnim)
end

local function OnLoad(inst, data)
    -- NOTES(JBK): This is to retrofit recipes added as a baseline to the workstation and is not normally needed.
    local craftingstation = inst.components.craftingstation
    craftingstation:LearnItem("wagpunk_workstation_blueprint_moonstorm_goggleshat", "wagpunk_workstation_blueprint_moonstorm_goggleshat")
    craftingstation:LearnItem("wagpunk_workstation_blueprint_moon_device_construction1", "wagpunk_workstation_blueprint_moon_device_construction1")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 0.4)

    inst.MiniMapEntity:SetPriority(5)
    inst.MiniMapEntity:SetIcon("wagpunk_workstation.png")

    inst.AnimState:SetBank("wagpunk_workstation")
    inst.AnimState:SetBuild("wagpunk_workstation")
    inst.AnimState:PlayAnimation("idle")

    --prototyper (from prototyper component) added to pristine state for optimization
    inst:AddTag("prototyper")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    local craftingstation = inst:AddComponent("craftingstation")
    craftingstation:LearnItem("wagpunk_workstation_blueprint_moonstorm_goggleshat", "wagpunk_workstation_blueprint_moonstorm_goggleshat")
    craftingstation:LearnItem("wagpunk_workstation_blueprint_moon_device_construction1", "wagpunk_workstation_blueprint_moon_device_construction1")

    inst:AddComponent("prototyper")
    inst.components.prototyper.onturnon = OnTurnOn
    inst.components.prototyper.onturnoff = OnTurnOff
    inst.components.prototyper.onactivate = OnActivate
    inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.WAGPUNK_WORKSTATION

    inst.OnLoad = OnLoad

    return inst
end

return Prefab("wagpunk_workstation", fn, assets)