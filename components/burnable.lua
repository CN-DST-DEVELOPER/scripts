local SMOLDER_TICK_TIME = 2
local SourceModifierList = require("util/sourcemodifierlist")

local willow_ember_common = require("prefabs/willow_ember_common")

local function oncanlight(self)
    local can_light_state = not self.burning and self.canlight
    self.inst:AddOrRemoveTag("canlight", can_light_state)
    self.inst:AddOrRemoveTag("nolight", not can_light_state)
end

local function onburning(self, burning)
    self.inst:AddOrRemoveTag("fire", burning)
    oncanlight(self)
end

local function onsmoldering(self, smoldering)
    self.inst:AddOrRemoveTag("smolder", smoldering)
end

local function onignorefuel(self, ignorefuel)
    self.inst:AddOrRemoveTag("burnableignorefuel", ignorefuel)
end

local function onstokeablefire(self, stokeablefire)
    self.inst:AddOrRemoveTag("stokeablefire", stokeablefire)
end

local Burnable = Class(function(self, inst)
    self.inst = inst

    self.flammability = 1

    self.fxdata = {}
    self.fxlevel = 1
    self.fxchildren = {}
    self.fxoffset = nil
    self.burning = false
    self.burntime = nil
    self.extinguishimmediately = true
    self.smoldertimeremaining = nil
    self.smoldering = false
    self.stokeablefire = false

    self.onignite = nil
    self.onextinguish = nil
    self.onburnt = nil
    self.onsmoldering = nil
    self.onstopsmoldering = nil
    self.canlight = true

    self.lightningimmune = false

    --self.nocharring = false --default almost everything chars
    --self.ignorefuel = false --set true if igniting/extinguishing should not start/stop fuel consumption
	--self.fastextinguish = false --set true to use fast version of extinguish fx if available

    self.task = nil
    self.smolder_task = nil
end,
nil,
{
    burning = onburning,
    canlight = oncanlight,
    smoldering = onsmoldering,
    ignorefuel = onignorefuel,
    stokeablefire = onstokeablefire,
})

--- Set the function that will be called when the object stops smoldering
function Burnable:SetOnStopSmolderingFn(fn)
    self.onstopsmoldering = fn
end

--- Set the function that will be called when the object starts smoldering
function Burnable:SetOnSmolderingFn(fn)
    self.onsmoldering = fn
end

--- Set the function that will be called when the object starts burning
function Burnable:SetOnIgniteFn(fn)
    self.onignite = fn
end

function Burnable:OnBurnt_Internal()
    self.inst:RemoveComponent("lunarhailbuildup")
end

--- Set the function that will be called when the object has burned completely
function Burnable:SetOnBurntFn(fn)
    -- NOTES(JBK): Because most of the game has been calling burnable.onburnt in loading and other places directly
    -- we will wrap this function with our own so that we get our internal part called whenever onburnt is called.
    -- Mods can hook the internal function to get similar customizability.
    if fn then
        self.onburnt = function(inst)
            fn(inst)
            if inst:IsValid() then
                self:OnBurnt_Internal()
            end
        end
    else
        self.onburnt = nil
    end
end

--- Set the function that will be called when the object stops burning
function Burnable:SetOnExtinguishFn(fn)
    self.onextinguish = fn
end

--- Set the prefab to use for the burning effect. Overrides the default
function Burnable:SetBurningFX(name)
    self.fxprefab = name
end

function Burnable:SetBurnTime(time)
    self.burntime = time
end

function Burnable:IsBurning()
    return self.burning
end

function Burnable:IsSmoldering()
    return self.smoldering
end

--- Add an effect to be spawned when burning
-- @param prefab The prefab to spawn as the effect
-- @param offset The offset from the burning entity/symbol that the effect should appear at
-- @param followsymbol Optional symbol for the effect to follow
-- @param followaschild Optional flag to force fx to be a child even when it has a follow symbol
-- @param scale Optional scale for the fx
-- @param followlayered Optional flag to follow the symbol's transform and layering
function Burnable:AddBurnFX(prefab, offset, followsymbol, followaschild, scale, followlayered)
	table.insert(self.fxdata, { prefab = prefab, x = offset.x, y = offset.y, z = offset.z, follow = followsymbol, followaschild = followaschild or nil, followlayered = followlayered or nil, scale = scale or 1 })
end

function Burnable:OverrideBurnFXBuild(build)
    for i, v in ipairs(self.fxdata) do
        v.build = build
    end
    for i, v in ipairs(self.fxchildren) do
        v.AnimState:SetBank(build)
        v.AnimState:SetBuild(build)
    end
end

function Burnable:OverrideBurnFXFinalOffset(offs)
    for i, v in ipairs(self.fxdata) do
        v.finaloffset = offs
    end
    for i, v in ipairs(self.fxchildren) do
        v.AnimState:SetFinalOffset(offs)
    end
end

function Burnable:OverrideBurnFXRadius(radius_levels)
    for i, v in ipairs(self.fxdata) do
        v.radius_levels = radius_levels
    end
    for i, v in ipairs(self.fxchildren) do
        if v.components.firefx ~= nil then
            v.components.firefx.radius_levels = radius_levels
            v.components.firefx:UpdateRadius()
        end
    end
end

--Set an optional offset to be added on top of all individually registered offsets from AddBurnFX
function Burnable:SetFXOffset(x, y, z)
    self.fxoffset = x ~= nil and (y ~= nil and z ~= nil and Vector3(x, y, z) or Vector3(x:Get())) or nil
end

--- Set the level of any current or future burning effects
function Burnable:SetFXLevel(level, percent)
    self.fxlevel = level
    for i, v in ipairs(self.fxchildren) do
        if v.components.firefx ~= nil then
            v.components.firefx:SetLevel(level)
            v.components.firefx:SetPercentInLevel(percent or 1)
        end
    end
end

function Burnable:GetLargestLightRadius()
    local largestRadius = nil
    for i, v in ipairs(self.fxchildren) do
        local light = v.components.firefx ~= nil and v.components.firefx.light ~= nil and v.components.firefx.light.Light or v.Light
        if light ~= nil and light:IsEnabled() then
            local radius = light:GetCalculatedRadius()
            if largestRadius == nil or radius > largestRadius then
                largestRadius = radius
            end
        end
    end
    return largestRadius
end

function Burnable:GetDebugString()
    return (self.smoldering and string.format("SMOLDERING %.2f", self.smoldertimeremaining))
        or (self.burning and "BURNING")
        or "NOT BURNING"
end

function Burnable:OnRemoveEntity()
    self:StopSmoldering()
	self.fastextinguish = true
    self:KillFX()
end

local function SmolderUpdate(inst, self)
    local x, y, z = inst.Transform:GetWorldPosition()
    -- this radius should be larger than the propogation, so that once
    -- there's a lot of blazes in an area, fire starts spreading quickly
    local ents = TheSim:FindEntities(x, y, z, 12)
    local nearbyheat = 0
    for i, v in ipairs(ents) do
        if v.components.propagator ~= nil then
            nearbyheat = nearbyheat + v.components.propagator.currentheat
        end
    end

	if TheWorld.state.israining and inst.components.rainimmunity == nil then
        -- smolder more slowly, or even unsmolder, if we're being rained on.
        if nearbyheat > 0 then
            local rainmod = 1.8 * TheWorld.state.precipitationrate
            self.smoldertimeremaining = self.smoldertimeremaining + SMOLDER_TICK_TIME * rainmod
        else
            -- Un-smolder at a fixed rate when there's no more heat, otherwise it takes foreeeever during gentle rain.
            self.smoldertimeremaining = self.smoldertimeremaining + SMOLDER_TICK_TIME * 3.0
        end
    end

    -- smolder about twice as fast if there's lots of heat nearby
    local heatmod = math.clamp(Remap(nearbyheat, 20, 90, 1, 2.2), 1, 2.2)

    self.smoldertimeremaining = self.smoldertimeremaining - SMOLDER_TICK_TIME * heatmod
    if self.smoldertimeremaining <= 0 then
        self:StopSmoldering() --JUST in case ignite fails...
        self:Ignite()
    elseif self.inst.components.propagator
        and self.inst.components.propagator.flashpoint
        and self.smoldertimeremaining > self.inst.components.propagator.flashpoint * 1.1 -- a small buffer to prevent flickering
        then
        -- extinguished by rain
        self:StopSmoldering()
    end
end

function Burnable:StartWildfire()
    if not (self.burning or self.smoldering or self.inst:HasTag("fireimmune")) then
        self.smoldering = true
        if self.onsmoldering then
            self.onsmoldering(self.inst)
        end

        self.smoke = SpawnPrefab("smoke_plant")
        if self.smoke ~= nil then
			local fxdata1 = #self.fxdata == 1 and self.fxdata[1] or nil
			if fxdata1 ~= nil and fxdata1.follow ~= nil then
				if fxdata1.followaschild then
                    self.inst:AddChild(self.smoke)
                end
                local follower = self.smoke.entity:AddFollower()
				local xoffs, yoffs, zoffs = fxdata1.x, fxdata1.y, fxdata1.z
                if self.fxoffset ~= nil then
                    xoffs = xoffs + self.fxoffset.x
                    yoffs = yoffs + self.fxoffset.y
                    zoffs = zoffs + self.fxoffset.z
                end
				follower:FollowSymbol(self.inst.GUID, fxdata1.follow, xoffs, yoffs, zoffs, fxdata1.followlayered)
            else
                self.inst:AddChild(self.smoke)
            end
            self.smoke.Transform:SetPosition(0, 0, 0)
        end

        self.smoldertimeremaining =
            self.inst.components.propagator ~= nil and
            self.inst.components.propagator.flashpoint or
            math.random(TUNING.MIN_SMOLDER_TIME, TUNING.MAX_SMOLDER_TIME)

        if self.smolder_task ~= nil then
            self.smolder_task:Cancel()
        end
        self.smolder_task = self.inst:DoPeriodicTask(SMOLDER_TICK_TIME, SmolderUpdate, math.random() * SMOLDER_TICK_TIME, self)
    end
end

local function DoneBurning(inst, self)
    local isplant = inst:HasTag("plant") and not (inst.components.diseaseable ~= nil and inst.components.diseaseable:IsDiseased())
    local pos = isplant and inst:GetPosition() or nil

    inst:PushEvent("onburnt")

    if self.onburnt ~= nil then
        self.onburnt(inst)
    end

	if self.inst:IsValid() then
		if inst.components.explosive ~= nil then
			--explosive explode
			inst.components.explosive:OnBurnt()
		end

		if self.extinguishimmediately then
			self:Extinguish()
		end
	end

    if isplant then
        TheWorld:PushEvent("plantkilled", { pos = pos }) --this event is pushed in other places too
    end
end

local function OnHealthErodeAway(inst)
	local self = inst.components.burnable
	self.fastextinguish = true
	self:KillFX()
end

local function OnKilled(inst)
    local self = inst.components.burnable
    if self ~= nil and self:IsBurning() and not self.nocharring then
        inst.AnimState:SetMultColour(.2, .2, .2, 1)
    end

	--@V2C: #HACK, sync up burn fx to health component's auto-ErodeAway
	if inst.components.health ~= nil and not inst.components.health.nofadeout then
		if self.task ~= nil then
			self.task:Cancel()
		end
		self.task = inst:DoTaskInTime(inst.components.health.destroytime or 2, OnHealthErodeAway)
	end
end

function Burnable:IsControlledBurn()
    return self.controlled_burn ~= nil
end

function Burnable:GetControlledBurn()
    return self.controlled_burn
end

function Burnable:StokeControlledBurn()
    self.controlled_burn = nil
    self.stokeablefire = false
    self:SetFXLevel(self.fxlevel, 1)
end

function Burnable:Ignite(immediate, source, doer)
    -- NOTE ON DAMAGE: Burning damage is done in the propagator component going to Health:GetFireDamageScale(), not the burnable component.
    if not (self.burning or self.inst:HasTag("fireimmune")) then

        local controlled_burn_source = doer and doer:HasTag("controlled_burner") and doer or source and source:HasTag("controlled_burner") and source

        if controlled_burn_source then
            self.controlled_burn = {
                duration_creature = controlled_burn_source.components.skilltreeupdater:IsActivated("willow_controlled_burn_2") and TUNING.CONTROLLED_BURN_DURATION_CREATURE_MULT or nil,                
                damage = controlled_burn_source.components.skilltreeupdater:IsActivated("willow_controlled_burn_3") and TUNING.CONTROLLED_BURN_DAMAGE_MULT or nil
            }
            self.stokeablefire = self.inst.components.health == nil -- NOTES(JBK): There is no benefit to uncontrolled creature fires.
        else
            self.controlled_burn = nil
            self.stokeablefire = false
        end

        self:StopSmoldering()

        self.burning = true
        self.inst:ListenForEvent("death", OnKilled)
        self:SpawnFX(immediate)

        self.inst:PushEvent("onignite", {doer = doer})
        if self.onignite ~= nil then
            self.onignite(self.inst, source, doer)
        end

        if self.inst.components.fueled ~= nil and not self.ignorefuel then
            self.inst.components.fueled:StartConsuming()
        end

        if self.inst.components.propagator ~= nil then
            self.inst.components.propagator:StartSpreading(source)
        end

        self:ExtendBurning()
    end
end

function Burnable:CalculateControlledBurnDuration()
    if self.controlled_burn.duration_creature and self.inst.components.health then
        return self.controlled_burn.duration_creature
    end
end


function Burnable:ExtendBurning()
    if self.task ~= nil then
        self.task:Cancel()
    end
    self.task = self.burntime ~= nil and self.inst:DoTaskInTime(self.burntime * (self.controlled_burn and self:CalculateControlledBurnDuration() or 1), DoneBurning, self) or nil
end

function Burnable:LongUpdate(dt)
    --kind of a coarse assumption...
    if self.burning then
        if self.task ~= nil then
            self.task:Cancel()
            self.task = nil
        end
        DoneBurning(self.inst, self)
    end
end

function Burnable:SmotherSmolder(smotherer)
    if smotherer ~= nil then
        if smotherer.components.finiteuses ~= nil then
            smotherer.components.finiteuses:Use()
        elseif smotherer.components.stackable ~= nil then
            smotherer.components.stackable:Get():Remove()
        elseif smotherer.components.health ~= nil and smotherer.components.combat ~= nil then
            smotherer.components.health:DoFireDamage(TUNING.SMOTHER_DAMAGE, nil, true)
            smotherer:PushEvent("burnt")
        end
    end
    self:StopSmoldering(-1) -- After you smother something, it has a bit of forgiveness before it will light again
end

function Burnable:StopSmoldering(heatpct)
    if self.smoldering then
        if self.smoke ~= nil then
            self.smoke.SoundEmitter:KillSound("smolder")
            self.smoke:Remove()
        end
        self.smoldering = false
        if self.smolder_task ~= nil then
            self.smolder_task:Cancel()
            self.smolder_task = nil
        end
        self.smoldertimeremaining = nil

        if self.inst.components.propagator ~= nil then
            self.inst.components.propagator:StopSpreading(true, heatpct)
        end

        if self.onstopsmoldering ~= nil then
            self.onstopsmoldering(self.inst)
        end
    end
end

function Burnable:Extinguish(resetpropagator, heatpct, smotherer)
    self:StopSmoldering(heatpct)

    if smotherer ~= nil then
        if smotherer.components.finiteuses ~= nil then
            smotherer.components.finiteuses:Use()
        elseif smotherer.components.stackable ~= nil then
            smotherer.components.stackable:Get():Remove()
        end
    end

    if self.burning then
        if self.task ~= nil then
            self.task:Cancel()
            self.task = nil
        end

        self.inst:RemoveEventCallback("death", OnKilled)

        if self.inst.components.propagator ~= nil then
            if resetpropagator then
                self.inst.components.propagator:StopSpreading(true, heatpct)
            else
                self.inst.components.propagator:StopSpreading()
            end
        end

        self.controlled_burn = nil
        self.stokeablefire = false

        self.burning = false
        self:KillFX()
        if self.inst.components.fueled ~= nil and not self.ignorefuel then
            self.inst.components.fueled:StopConsuming()
        end
        if self.onextinguish ~= nil then
            self.onextinguish(self.inst)
        end
        self.inst:PushEvent("onextinguish")
    end
end

function Burnable:SpawnFX(immediate)
    self:KillFX()

    if self.fxdata == nil then
        self.fxdata = { x = 0, y = 0, z = 0, level = self:GetDefaultFXLevel() }
    end

    local fxoffset = self.fxoffset or Vector3(0, 0, 0)
    for k, v in pairs(self.fxdata) do
        local fx = v.prefab ~= nil and SpawnPrefab(v.prefab) or nil
        if fx ~= nil then
            if v.build ~= nil then
                fx.AnimState:SetBank(v.build)
                fx.AnimState:SetBuild(v.build)
            end
            if v.finaloffset ~= nil then
                fx.AnimState:SetFinalOffset(v.finaloffset)
            end

            local scale = self.inst.Transform:GetScale()
            if v.scale then
                scale = scale * v.scale
            end

            fx.Transform:SetScale(scale,scale,scale)
            
            local xoffs, yoffs, zoffs = v.x + fxoffset.x, v.y + fxoffset.y, v.z + fxoffset.z
            if v.follow ~= nil then
                if v.followaschild then
                    self.inst:AddChild(fx)
                end
                fx.entity:AddFollower()
				fx.Follower:FollowSymbol(self.inst.GUID, v.follow, xoffs, yoffs, zoffs, v.followlayered)
            else
                self.inst:AddChild(fx)
                fx.Transform:SetPosition(xoffs, yoffs, zoffs)
            end
            fx.persists = false
            table.insert(self.fxchildren, fx)
            if fx.components.firefx ~= nil then
                fx.components.firefx.radius_levels = v.radius_levels
                fx.components.firefx:SetLevel(self.fxlevel, immediate, self.controlled_burn)
                fx.components.firefx:AttachLightTo(self.inst)
            end
        end
    end
end

--If fx were spawned during entity construction, follow symbols may not
--be hooked up properly. Call this to fix them.
function Burnable:FixFX()
    local fxoffset = self.fxoffset or Vector3(0, 0, 0)
    for i, fx in ipairs(self.fxchildren) do
        if fx.Follower ~= nil then
            for k, v in pairs(self.fxdata) do
                if v.prefab == fx.prefab and v.follow ~= nil then
					fx.Follower:FollowSymbol(self.inst.GUID, v.follow, v.x + fxoffset.x, v.y + fxoffset.y, v.z + fxoffset.z, v.followlayered)
                    break
                end
            end
        end
    end
end

function Burnable:KillFX()
    for i = #self.fxchildren, 1, -1 do
        local fx = self.fxchildren[i]
		if fx.components.firefx ~= nil and fx.components.firefx:Extinguish(self.fastextinguish) then
            --remove once the pst animation has finished
            --schedule it as well in case it goes asleep
            fx:ListenForEvent("animover", fx.Remove)
            fx:DoTaskInTime(fx.AnimState:GetCurrentAnimationLength() + FRAMES, fx.Remove)
        else
            fx:Remove()
        end
        table.remove(self.fxchildren, i)
    end
end

function Burnable:HasEndothermicHeat()
    for i, v in ipairs(self.fxchildren) do
        if v.components.heater ~= nil and v.components.heater:IsEndothermic() then
            return true
        end
    end
    return false
end

function Burnable:HasExothermicHeat()
    for i, v in ipairs(self.fxchildren) do
        if v.components.heater ~= nil and v.components.heater:IsExothermic() then
            return true
        end
    end
    return false
end

function Burnable:OnRemoveFromEntity()
    --self:StopSmoldering()
    --Extinguish() already calls StopSmoldering()
    self:Extinguish()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
    self.inst:RemoveTag("canlight")
    self.inst:RemoveTag("nolight")
    self.inst:RemoveTag("burnableignorefuel")
end

return Burnable
