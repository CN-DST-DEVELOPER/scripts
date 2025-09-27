local Widget           = require "widgets/widget"
local SanityBadge      = require "widgets/sanitybadge"
local HealthBadge      = require "widgets/healthbadge"
local HungerBadge      = require "widgets/hungerbadge"
local WereBadge        = require "widgets/werebadge"
local MoistureMeter    = require "widgets/moisturemeter"
local BoatMeter        = require "widgets/boatmeter"
local PetHealthBadge   = require "widgets/pethealthbadge"
local PetHungerBadge   = require "widgets/pethungerbadge"
local AvengingGhostBadge = require "widgets/avengingghostbadge"
local InspirationBadge = require "widgets/inspirationbadge"
local MightyBadge      = require "widgets/mightybadge"
local ResurrectButton  = require "widgets/resurrectbutton"
local UIAnim           = require "widgets/uianim"

local function OnSetPlayerMode(inst, self)
    self.modetask = nil

    if self.onhealthdelta == nil then
        self.onhealthdelta = function(owner, data) self:HealthDelta(data) end
        self.inst:ListenForEvent("healthdelta", self.onhealthdelta, self.owner)
        self:SetHealthPercent(self.owner.replica.health:GetPercent())
    end

    if self.onhungerdelta == nil then
        self.onhungerdelta = function(owner, data) self:HungerDelta(data) end
        self.inst:ListenForEvent("hungerdelta", self.onhungerdelta, self.owner)
        self:SetHungerPercent(self.owner.replica.hunger:GetPercent())
    end

    if self.onsanitydelta == nil then
        self.onsanitydelta = function(owner, data) self:SanityDelta(data) end
        self.inst:ListenForEvent("sanitydelta", self.onsanitydelta, self.owner)
        self:SetSanityPercent(self.owner.replica.sanity:GetPercent())
    end

    if self.onmoisturedelta == nil then
        self.onmoisturedelta = function(owner, data) self:MoistureDelta(data) end
        self.inst:ListenForEvent("moisturedelta", self.onmoisturedelta, self.owner)
        self:SetMoisturePercent(self.owner:GetMoisture())
    end

    if self.ongotonplatform == nil then
        local my_platform = self.owner:GetCurrentPlatform()
        if my_platform ~= nil and my_platform.components.healthsyncer ~= nil then
            self.boatmeter:Enable(my_platform)
        else
            self.boatmeter:Disable(self.instantboatmeterclose)
        end
        self.instantboatmeterclose = nil

        self.ongotonplatform = function(owner, platform) if platform.components.healthsyncer ~= nil then self.boatmeter:Enable(platform) end end
        self.inst:ListenForEvent("got_on_platform", self.ongotonplatform, self.owner)

        self.ongotoffplatform = function(owner, platform) if platform.components.healthsyncer ~= nil then self.boatmeter:Disable() end end
        self.inst:ListenForEvent("got_off_platform", self.ongotoffplatform, self.owner)
    end

    if self.wereness ~= nil and self.onwerenessdelta == nil then
        self.onwerenessdelta = function(owner, data) self:WerenessDelta(data) end
        self.inst:ListenForEvent("werenessdelta", self.onwerenessdelta, self.owner)
        self:SetWerenessPercent(self.owner:GetWereness())
    end

    if self.inspirationbadge ~= nil and self.oninspirationdelta == nil then
        self.oninspirationdelta = function(owner, data) self:SetInspiration(data ~= nil and data.newpercent or 0, data ~= nil and data.slots_available or nil, data ~= nil and data.draining) end
        self.inst:ListenForEvent("inspirationdelta", self.oninspirationdelta, self.owner)

        self.oninspirationsongchanged = function(owner, data) self:OnInspirationSongChanged(data ~= nil and data.slotnum or 0, data ~= nil and data.songdata ~= nil and data.songdata.NAME or nil) end
		self.inst:ListenForEvent("inspirationsongchanged", self.oninspirationsongchanged, self.owner)

        self:SetInspiration(self.owner:GetInspiration(), nil, false)
		self:OnInspirationSongChanged(1, (self.owner:GetInspirationSong(1) or {}).NAME)
		self:OnInspirationSongChanged(2, (self.owner:GetInspirationSong(2) or {}).NAME)
		self:OnInspirationSongChanged(3, (self.owner:GetInspirationSong(3) or {}).NAME)
    end

    if self.mightybadge ~= nil and self.onmightinessdelta == nil then
        self.onmightinessdelta = function(owner, data) self:MightinessDelta(data) end
        self.inst:ListenForEvent("mightinessdelta", self.onmightinessdelta, self.owner)
        self:SetMightiness(self.owner:GetMightiness())
    end

    if self.pethealthbadge ~= nil and self.onpethealthdirty == nil then
        self.onpethealthdirty = function() self:RefreshPetHealth() end
        inst:ListenForEvent("clientpethealthdirty", self.onpethealthdirty, self.owner)
        inst:ListenForEvent("clientpethealthsymboldirty", self.onpethealthdirty, self.owner)
        inst:ListenForEvent("clientpetmaxhealthdirty", self.onpethealthdirty, self.owner)
        inst:ListenForEvent("clientpethealthpulsedirty", self.onpethealthdirty, self.owner)
        inst:ListenForEvent("clientpethealthstatusdirty", self.onpethealthdirty, self.owner)
        inst:ListenForEvent("clientpetbonusdirty", self.onpethealthdirty, self.owner)

        self:RefreshPetHealth()
    end

	if self.heart ~= nil and self.onheartbuffdirty == nil then
        self.onheartbuffdirty = function() self:RefreshHealthBuff() end
        inst:ListenForEvent("clienthealthbuffdirty", self.onheartbuffdirty, self.owner)
        self:RefreshHealthBuff()
    end

    if self.onavengetimedirty ~= nil then
        inst:RemoveEventCallback("clientavengetimedirty", self.onavengetimedirty, self.owner)
        self.onavengetimedirty = nil
        self:RefreshAvengingGhost()
    end

    if self.pethealthbadge ~= nil and self.onpetskindirty == nil then
        self.onpetskindirty = function() self:RefreshPetSkin() end
        inst:ListenForEvent("clientpetskindirty", self.onpetskindirty, self.owner)
        self:RefreshPetSkin()
    end

	if self.pethungerbadge and self.onpethungerdelta == nil then
		self.onpethungerdelta = function(owner, data) self:PetHungerDelta(data) end
		self.onpethungerflags = function(owner, flags) self:SetPetHungerFlags(flags) end
		self.onpethungerbuild = function(owner, data) self:SetPetHungerBuild(data and data.build, data and data.instant) end
		self.onshowpethunger = function(owner, shown)
			if shown and owner.pet_hunger_classified then
				self:SetPetHungerPercent(owner.pet_hunger_classified:GetPercent(), owner.pet_hunger_classified:Max())
				self:SetPetHungerFlags(owner.pet_hunger_classified:GetFlags(), true)
				self:SetPetHungerBuild(owner.pet_hunger_classified:GetBuild(), true)
				self.pethungerbadge:Show()
			else
				self.pethungerbadge:Hide()
			end
		end
		self.inst:ListenForEvent("pet_hungerdelta", self.onpethungerdelta, self.owner)
		self.inst:ListenForEvent("pet_hunger_flags", self.onpethungerflags, self.owner)
		self.inst:ListenForEvent("pet_hunger_build", self.onpethungerbuild, self.owner)
		self.inst:ListenForEvent("show_pet_hunger", self.onshowpethunger, self.owner)
		self.onshowpethunger(self.owner, self.owner.pet_hunger_classified ~= nil)
	end
end

local function OnSetGhostMode(inst, self)
    self.modetask = nil

    if self.onhealthdelta ~= nil then
        self.inst:RemoveEventCallback("healthdelta", self.onhealthdelta, self.owner)
        self.onhealthdelta = nil
    end

    if self.onhungerdelta ~= nil then
        self.inst:RemoveEventCallback("hungerdelta", self.onhungerdelta, self.owner)
        self.onhungerdelta = nil
    end

    if self.onsanitydelta ~= nil then
        self.inst:RemoveEventCallback("sanitydelta", self.onsanitydelta, self.owner)
        self.onsanitydelta = nil
    end

    if self.onmoisturedelta ~= nil then
        self.inst:RemoveEventCallback("moisturedelta", self.onmoisturedelta, self.owner)
        self.onmoisturedelta = nil
    end

    if self.ongotonplatform ~= nil then

        self.inst:RemoveEventCallback("got_on_platform", self.ongotonplatform, self.owner)
        self.ongotonplatform = nil

        self.inst:RemoveEventCallback("got_off_platform", self.ongotoffplatform, self.owner)
        self.ongotoffplatform = nil

    end

    if self.onwerenessdelta ~= nil then
        self.inst:RemoveEventCallback("werenessdelta", self.onwerenessdelta, self.owner)
        self.onwerenessdelta = nil
    end

    if self.oninspirationdelta ~= nil then
        self.inst:RemoveEventCallback("inspirationdelta", self.oninspirationdelta, self.owner)
        self.oninspirationdelta = nil
    end

    if self.onupgrademodulesenergylevelupdated ~= nil then
        self.inst:RemoveEventCallback("energylevelupdate", self.onupgrademodulesenergylevelupdated, self.owner)
        self.onupgrademodulesenergylevelupdated = nil
    end

    if self.onpethealthdirty ~= nil then
        self.inst:RemoveEventCallback("clientpethealthdirty", self.onpethealthdirty, self.owner)
        self.inst:RemoveEventCallback("clientpethealthsymboldirty", self.onpethealthdirty, self.owner)
        self.inst:RemoveEventCallback("clientpetmaxhealthdirty", self.onpethealthdirty, self.owner)
        self.inst:RemoveEventCallback("clientpethealthstatusdirty", self.onpethealthdirty, self.owner)
        self.inst:RemoveEventCallback("clientpetbonusdirty", self.onpethealthdirty, self.owner)
        self.onpethealthdirty = nil
    end


    if self.onheartbuffdirty ~= nil then
        self.inst:RemoveEventCallback("clienthealthbuffdirty", self.onheartbuffdirty, self.owner)
        self.onheartbonusdirty = nil
        self:RefreshHealthBuff()
    end

    if self.avengingghostbadge ~= nil and self.onavengetimedirty == nil then
        self.onavengetimedirty = function() self:RefreshAvengingGhost() end
        inst:ListenForEvent("clientavengetimedirty", self.onavengetimedirty, self.owner)
        self:RefreshAvengingGhost()
    end

    if self.onpetskindirty ~= nil then
        self.inst:RemoveEventCallback("clientpetskindirty", self.onpetskindirty, self.owner)
        self.onpetskindirty = nil
    end

	if self.onpethungerdelta then
		self.inst:RemoveEventCallback("pet_hungerdelta", self.onpethungerdelta, self.owner)
		self.inst:RemoveEventCallback("pet_hunger_flags", self.onpethungerflags, self.owner)
		self.inst:RemoveEventCallback("pet_hunger_build", self.onpethungerbuild, self.owner)
		self.inst:RemoveEventCallback("show_pet_hunger", self.onshowpethunger, self.owner)
		self.onpethungerdelta = nil
		self.onpethungerflags = nil
		self.onpethungerbuild = nil
		self.onshowpethunger = nil
		self.pethungerbadge:Hide()
	end
end

local function UpdateRezButton_Enable(inst, self, proxy_is_gravestone)
    self.rezbutton_new_task = nil
    local effigy_type = (proxy_is_gravestone and "grave") or nil
    self:EnableResurrect(true, effigy_type)
end

local function UpdateRezButton_Disable(inst, self, proxy_is_gravestone)
    self.rezbutton_lost_task = nil
    local effigy_type = (proxy_is_gravestone and "grave") or nil
    local was_button_visible = self.isghostmode and self.resurrectbutton:IsVisible()
    self:EnableResurrect(false, effigy_type)
    if was_button_visible and not self.resurrectbutton:IsVisible() then
        self.resurrectbuttonfx:GetAnimState():PlayAnimation("break")
        self.resurrectbuttonfx:Show()
        if self.resurrectbuttonfx:IsVisible() then
            TheFocalPoint.SoundEmitter:PlaySound(self.heart.effigybreaksound)
        end
    end
end

local function OnFinishSeamlessPlayerSwap(owner)
    local self = owner.HUD.controls.status
    self.inst:RemoveEventCallback("finishseamlessplayerswap", OnFinishSeamlessPlayerSwap, owner)

    if self.modetask ~= nil then
        self.modetask:Cancel()
        self.modetask = nil
    end
    if self.isghostmode then
        OnSetGhostMode(self.inst, self)
    else
        OnSetPlayerMode(self.inst, self)
    end
end

local StatusDisplays = Class(Widget, function(self, owner)
    Widget._ctor(self, "Status")
    self:UpdateWhilePaused(false)
    self.owner = owner

    if owner.isseamlessswaptarget then
        self.inst:ListenForEvent("finishseamlessplayerswap", OnFinishSeamlessPlayerSwap, owner)
    end

    local is_splitscreen = IsSplitScreen()
    if is_splitscreen and IsGameInstance(Instances.Player1) then
        self.column1 = 80
        self.column2 = 40
        self.column3 = 0
        self.column4 = -40
        self.column5 = 120
    else
        self.column1 = -80
        self.column2 = -40
        self.column3 = 0
        self.column4 = 40
        self.column5 = -120
    end

    self.wereness = nil
    self.onwerenessdelta = nil

	self.inspirationbadge = nil
	self.oninspirationdelta = nil

    self.brain = self:AddChild(owner.CreateSanityBadge ~= nil and owner.CreateSanityBadge(owner) or SanityBadge(owner))
    self.brain:SetPosition(self.column3, -40, 0)
    self.onsanitydelta = nil

    self.stomach = self:AddChild(owner.CreateHungerBadge ~= nil and owner.CreateHungerBadge(owner) or HungerBadge(owner))
    self.stomach:SetPosition(self.column2, 20, 0)
    self.onhungerdelta = nil

	if owner:HasTag("dogrider") then
		self:AddPetHunger()
		self:SetupWobyPetHunger()
	end

    self.heart = self:AddChild(owner.CreateHealthBadge ~= nil and owner.CreateHealthBadge(owner) or HealthBadge(owner, nil, "status_abigail"))
    self.heart:SetPosition(self.column4, 20, 0)
    self.heart.effigybreaksound = "dontstarve/creatures/together/lavae/egg_deathcrack"
    self.onhealthdelta = nil
    self.healthpenalty = 0

    self.moisturemeter = self:AddChild(owner.CreateMoistureMeter ~= nil and owner.CreateMoistureMeter(owner) or MoistureMeter(owner))
    self.moisturemeter:SetPosition(self.column3, -115, 0)
    self.onmoisturedelta = nil

    self.boatmeter = self:AddChild(BoatMeter(owner))
    self.boatmeter:SetPosition(self.column1, -40, 0)
    self.ongotonplatform = nil
    self.ongotoffplatform = nil

    self.resurrectbutton = self:AddChild(ResurrectButton(owner))
    self.resurrectbutton:SetScale(.75, .75, .75)
    self.resurrectbutton:SetTooltip(STRINGS.UI.HUD.ACTIVATE_RESURRECTION)

    self.resurrectbuttonfx = self:AddChild(UIAnim())
    self.resurrectbuttonfx:SetScale(.75, .75, .75)
    self.resurrectbuttonfx:GetAnimState():SetBank("effigy_break")
    self.resurrectbuttonfx:GetAnimState():SetBuild("effigy_button")
    self.resurrectbuttonfx:GetAnimState():AnimateWhilePaused(false)
    self.resurrectbuttonfx:Hide()
    self.resurrectbuttonfx.inst:ListenForEvent("animover", function(inst) inst.widget:Hide() end)

    --NOTE: Can't rely on order of getting and losing attunement,
    --      especially in the same frame when switching effigies.

    --Delay button updates so it doesn't draw focus from entity anims/fx
    --Also helps flatten messages from the same frame to its final value
    local rezbuttondelay = 15 * FRAMES

    self.inst:ListenForEvent("gotnewattunement", function(owner, data)
        --can safely assume we are attuned if we just "got" an attunement
        local proxy = data.proxy
        local proxy_is_gravestone = proxy:IsAttunableType("gravestoneresurrector")
        if proxy:IsAttunableType("remoteresurrector") or proxy_is_gravestone then
            if self.rezbutton_new_task ~= nil then
                self.rezbutton_new_task:Cancel()
            end
            self.rezbutton_new_task = self.inst:DoTaskInTime(rezbuttondelay, UpdateRezButton_Enable, self, proxy_is_gravestone)
        end
    end, owner)

    self.inst:ListenForEvent("attunementlost", function(owner, data)
        --cannot assume that we are no longer attuned
        --to a type when we lose a single attunement!
        local proxy = data.proxy
        local proxy_is_gravestone = proxy:IsAttunableType("gravestoneresurrector")
        if (proxy:IsAttunableType("remoteresurrector") and
                not (owner.components.attuner ~= nil and owner.components.attuner:HasAttunement("remoteresurrector")))
                or (proxy_is_gravestone and
                not (owner.components.attuner ~= nil and owner.components.attuner:HasAttunement("gravestoneresurrector"))) then
            if self.rezbutton_lost_task ~= nil then
                self.rezbutton_lost_task:Cancel()
            end
            self.rezbutton_lost_task = self.inst:DoTaskInTime(rezbuttondelay, UpdateRezButton_Disable, self, proxy_is_gravestone)
        end
    end, owner)

    self.rezbutton_new_task = nil
    self.rezbutton_lost_task = nil
    self.modetask = nil
    self.isghostmode = true --force the initial SetGhostMode call to be dirty
    self.instantboatmeterclose = true
    self:SetGhostMode(false)

    if owner:HasTag("wereness") then
        self:AddWereness()
    end

    if owner.components.avengingghost then
        self.avengingghostbadge = self:AddChild(AvengingGhostBadge(owner, nil, "status_abigail" ))
        self.avengingghostbadge:SetPosition(self.column3, -40, 0)
        self.avengingghostbadge:Hide()
    end

	if owner.components.pethealthbar ~= nil then
		if owner.prefab == "wendy" then
			self.pethealthbadge = self:AddChild(PetHealthBadge(owner, { 254 / 255, 253 / 255, 237 / 255, 1 }, "status_abigail", { 35 / 255, 152 / 255, 156 / 255, 1 } ))
			self.pethealthbadge:SetPosition(self.column4, -100, 0)

		    self.moisturemeter:SetPosition(self.column2, -100, 0)
		end
	end

    if owner:HasTag("battlesinger") then
        self:AddInspiration()
    end

    if owner:HasTag("strongman") then
        self:AddMightiness()
    end

    if owner:HasTag("upgrademoduleowner") then
        -- Not adding the display here, but we need to move some stuff around in single player.
        if not is_splitscreen then
            self.moisturemeter:SetPosition(self.column1, -120, 0)
        end
    end
end)

function StatusDisplays:ShowStatusNumbers()
    self.brain.num:Show()
    self.stomach.num:Show()
    self.heart.num:Show()
    self.moisturemeter.num:Show()
    if self.boatmeter.boat then
        self.boatmeter.num:Show()
    end
	if self.pethealthbadge then
		self.pethealthbadge.num:Show()
	end
    if self.wereness ~= nil then
        self.wereness.num:Show()
    end
end

function StatusDisplays:HideStatusNumbers()
    self.brain.num:Hide()
    self.stomach.num:Hide()
    self.heart.num:Hide()
    self.moisturemeter.num:Hide()
    self.boatmeter.num:Hide()
	if self.pethealthbadge then
		self.pethealthbadge.num:Hide()
	end
    if self.wereness ~= nil then
        self.wereness.num:Hide()
    end
end

function StatusDisplays:Layout()
end

--------------------------------------------------------------------------
--[[ Deprecated ]]
function StatusDisplays:AddBeaverness() end
function StatusDisplays:RemoveBeaverness() end
function StatusDisplays:SetBeaverMode() end
function StatusDisplays:SetBeavernessPercent() end
function StatusDisplays:BeavernessDelta() end
--------------------------------------------------------------------------

function StatusDisplays:AddWereness()
    if self.wereness == nil then
        self.wereness = self:AddChild(WereBadge(self.owner))
        self.wereness:SetPosition(self.stomach:GetPosition())

        if self.isghostmode then
            self.wereness:Hide()
        elseif self.modetask == nil and self.onwerenessdelta == nil then
            self.onwerenessdelta = function(owner, data) self:WerenessDelta(data) end
            self.inst:ListenForEvent("werenessdelta", self.onwerenessdelta, self.owner)
            self:SetWerenessPercent(self.owner:GetWereness())
        end
    end
end

function StatusDisplays:RemoveWereness()
    if self.wereness ~= nil then
        if self.onwerenessdelta ~= nil then
            self.inst:RemoveEventCallback("werenessdelta", self.onwerenessdelta, self.owner)
            self.onwerenessdelta = nil
        end

        self:SetWereMode(false)
        self.wereness:Kill()
        self.wereness = nil
    end
end

function StatusDisplays:SetWereMode(weremode, nofx)
    if self.isghostmode or self.wereness == nil then
        return
    elseif weremode then
        self.stomach:Hide()
        self.wereness:Show()
        self.wereness:SetPosition(self.stomach:GetPosition())
        if not nofx then
            self.wereness:SpawnNewFX()
        end
    else
        self.stomach:Show()
        self.wereness:Hide()
        if not nofx then
            self.wereness:SpawnShatterFX()
        end
    end
end

function StatusDisplays:AddInspiration()
    if self.inspirationbadge == nil then
        self.inspirationbadge = self:AddChild(InspirationBadge(self.owner, { 151 / 255, 30 / 255, 180 / 255, 1 }))
        self.inspirationbadge:SetPosition(self.column3, -130, 0)
		self:SetInspiration(self.owner:GetInspiration(), nil, false)

        self.moisturemeter:SetPosition(self.column1, -130, 0)
    end
end

function StatusDisplays:AddMightiness()
    if self.mightybadge == nil then
        self.mightybadge = self:AddChild(MightyBadge(self.owner))
        self.mightybadge:SetPosition(self.column5, 20, 0)
        self:SetMightiness(self.owner:GetMightiness())
    end
end

function StatusDisplays:SetGhostMode(ghostmode)
    if not self.isghostmode == not ghostmode then --force boolean
        return
    elseif ghostmode then
        self.isghostmode = true

        self.heart:Hide()
        self.stomach:Hide()
        self.brain:Hide()
        self.moisturemeter:Hide()
        self.boatmeter:Hide()

        self.heart:StopWarning()
        self.stomach:StopWarning()
        self.brain:StopWarning()

        if self.wereness ~= nil then
            self.wereness:Hide()
            self.wereness:StopWarning()
        end

		if self.pethealthbadge ~= nil then
			self.pethealthbadge:Hide()
		end

        if self.inspirationbadge ~= nil then
            self.inspirationbadge:Hide()
        end

        if self.mightybadge ~= nil then
            self.mightybadge:Hide()
        end

		if self.pethungerbadge then
			self.pethungerbadge:Hide()
		end
    else
        self.isghostmode = nil

        self.heart:Show()
        self.stomach:Show()
        self.brain:Show()
        self.moisturemeter:Show()
        self.boatmeter:Show()

        if self.wereness ~= nil then
            self.wereness:Show()
        end

		if self.pethealthbadge ~= nil then
			self.pethealthbadge:Show()
		end

        if self.inspirationbadge ~= nil then
            self.inspirationbadge:Show()
        end

        if self.mightybadge ~= nil then
            self.mightybadge:Show()
        end

        if self.avengingghostbadge then
            self.avengingghostbadge:Hide()
        end

		if self.pethungerbadge and self.owner.pet_hunger_classified then
			self.pethungerbadge:Show()
		end
    end

    if self.rezbutton_new_task ~= nil then
        self.rezbutton_new_task:Cancel()
        self.rezbutton_new_task = nil
    end
    if self.rezbutton_lost_task ~= nil then
        self.rezbutton_lost_task:Cancel()
        self.rezbutton_lost_task = nil
    end
    local owner_attuner = self.owner.components.attuner
    self:EnableResurrect(
        owner_attuner ~= nil and (owner_attuner:HasAttunement("remoteresurrector") or owner_attuner:HasAttunement("gravestoneresurrector")),
        (owner_attuner:HasAttunement("gravestoneresurrector") and "grave") or nil
    )

    if self.modetask ~= nil then
        self.modetask:Cancel()
    end
    self.modetask = self.inst:DoStaticTaskInTime(0, ghostmode and OnSetGhostMode or OnSetPlayerMode, self)
end

function StatusDisplays:SetHealthPercent(pct)
    local health = self.owner.replica.health
    self.healthpenalty = health:GetPenaltyPercent()
    self.heart:SetPercent(pct, health:Max(), self.healthpenalty)

    if pct <= (self.heart.warning_precent or .33) then
        self.heart:StartWarning()
    else
        self.heart:StopWarning()
    end
end

function StatusDisplays:HealthDelta(data)
    local oldpenalty = self.healthpenalty
    self:SetHealthPercent(data.newpercent)

    if self.heart ~= nil and self.heart.HealthDelta ~= nil then
        self.heart:HealthDelta(data)
    else
        --health penalty pulse takes priority
        if oldpenalty > self.healthpenalty then
            self.heart:PulseGreen()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/health_up")
        elseif oldpenalty < self.healthpenalty then
            self.heart:PulseRed()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/health_down")
        elseif data.overtime then
            -- Ignore red pulse and green pulse sound for healthdelta overtime
            if data.newpercent > data.oldpercent then
                self.heart:PulseGreen()
            end
        elseif data.newpercent > data.oldpercent then
            self.heart:PulseGreen()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/health_up")
        elseif data.newpercent < data.oldpercent then
            self.heart:PulseRed()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/health_down")
        end
    end
end

function StatusDisplays:SetHungerPercent(pct)
    self.stomach:SetPercent(pct, self.owner.replica.hunger:Max())

    if pct <= 0 then
        self.stomach:StartWarning()
    else
        self.stomach:StopWarning()
    end
end

function StatusDisplays:HungerDelta(data)
    self:SetHungerPercent(data.newpercent)
    if self.stomach ~= nil and self.stomach.HungerDelta then
        self.stomach:HungerDelta(data)
    else
        if not data.overtime then
            if data.newpercent > data.oldpercent then
                self.stomach:PulseGreen()
                TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/hunger_up")
            elseif data.newpercent < data.oldpercent then
                TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/hunger_down")
                self.stomach:PulseRed()
            end
        end
    end
end

function StatusDisplays:AddPetHunger()
	if self.pethungerbadge == nil then
		self.pethungerbadge = self:AddChild(PetHungerBadge(self.owner, RGB(198, 198, 0), "status_woby"))
		self.pethungerbadge:SetPosition(self.column5, 20, 0)
		self.pethungerbadge:Hide()
	end
end

function StatusDisplays:SetPetHungerPercent(pct, max)
	self.pethungerbadge:SetPercent(pct, max)
end

function StatusDisplays:PetHungerDelta(data)
	local max = self.owner.pet_hunger_classified and self.owner.pet_hunger_classified:Max() or nil
	self:SetPetHungerPercent(data.newpercent, max)

	if self.pethungerbadge.HungerDelta then
		self.pethungerbadge:HungerDelta(data)
	--[[elseif not data.overtime then
		if data.newpercent > data.oldpercent then
			self.pethungerbadge:PulseGreen()
			--TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/hunger_up")
		elseif data.newpercent < data.oldpercent then
			--TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/hunger_down")
			self.pethungerbadge:PulseRed()
		end]]
	end
end

function StatusDisplays:SetPetHungerFlags(flags, instant)
	self.pethungerbadge:OnFlagsChanged(flags, instant)
end

function StatusDisplays:SetPetHungerBuild(build, instant)
	self.pethungerbadge:OnBuildChanged(build, instant)
end

function StatusDisplays:SetupWobyPetHunger()
	local WobyCommon = require("prefabs/wobycommon")
	local layers =
	{
		"big_woby",
		"big_woby_lunar",
		"big_woby_shadow",
		"small_woby",
		"small_woby_lunar",
		"small_woby_shadow",
	}

	--Don't animate frame as meter level changes, otherwise it may interrupt transition anims.
	self.pethungerbadge.dont_animate_circleframe = true

	--Frames match Woby's build colours, so we'll want to apply colourcube
	--[[self.pethungerbadge.circleframe:GetAnimState():SetDefaultEffectHandle("shaders/ui_anim_cc.ksh")
	self.pethungerbadge.circleframe:GetAnimState():UseColourCube(true)
	self.pethungerbadge.circleframe:GetAnimState():SetUILightParams(2.0, 4.0, 4.0, 20.0)]]

	--Switch frames for big vs small woby
	local _OnFlagsChanged = self.pethungerbadge.OnFlagsChanged
	self.pethungerbadge.OnFlagsChanged = function(self, flags, instant)
		--self is pethungerbadge
		_OnFlagsChanged(self, flags, instant)

		local isbig = checkbit(flags, bit.lshift(1, WobyCommon.FLAGBITS.BIG))
		local islunar = checkbit(flags, bit.lshift(1, WobyCommon.FLAGBITS.LUNAR))
		local isshadow = checkbit(flags, bit.lshift(1, WobyCommon.FLAGBITS.SHADOW))

		local layer = isbig and "big_woby" or "small_woby"
		if islunar then
			layer = layer.."_lunar"
		elseif isshadow then
			layer = layer.."_shadow"
		end

		if self.layer ~= layer then
			self.layer = layer
			for i, v in ipairs(layers) do
				if v == layer then
					self.circleframe:GetAnimState():Show(v)
				else
					self.circleframe:GetAnimState():Hide(v)
				end
			end
			if not instant and self.shown then
				self.circleframe:GetAnimState():PlayAnimation(self.isbig == isbig and "alignment_change" or "state_change")
				self.circleframe:GetAnimState():PushAnimation("frame", false)
			end
			self.isbig = isbig
		end
	end

	self.pethungerbadge.build = "status_woby"

	--Switch frame build for skins
	local _OnBuildChanged = self.pethungerbadge.OnBuildChanged
	self.pethungerbadge.OnBuildChanged = function(self, build, instant)
		--self is pethungerbadge
		_OnBuildChanged(self, build, instant)

		if build == nil or build == 0 or build == "" then
			build = "status_woby"
		end
		if self.build ~= build then
			self.build = build
			self.circleframe:GetAnimState():SetBank(build)
			self.circleframe:GetAnimState():SetBuild(build)
			if not instant and self.shown then
				self.circleframe:GetAnimState():PlayAnimation("alignment_change")
				self.circleframe:GetAnimState():PushAnimation("frame", false)
			end
		end
	end

	--Arrow for sprinting hunger drain
	local iscave = TheWorld:HasTag("cave")
	self.pethungerbadge:SetArrowAnimFn(function(self)
		--self is pethungerbadge
		if self.owner then
			if self.owner.sg then
				--Assumes we can only ride our own woby!
				if self.owner.sg:HasStateTag("sprint_woby") then
					if self.owner.components.skilltreeupdater then
						if self.owner.components.skilltreeupdater:IsActivated("walter_woby_lunar") then
							if not iscave and TheWorld.state.isnight and not TheWorld.state.isnewmoon then
								return --lunar powered, no drain
							end
							local sanity = self.owner.replica.sanity
							if sanity and sanity:IsLunacyMode() then
								return --lunar powered, no drain
							end
						end
						if self.owner.components.skilltreeupdater:IsActivated("walter_woby_endurance") then
							return "arrow_loop_decrease"
						end
					end
					return "arrow_loop_decrease_more"
				end
			elseif self.owner.pet_hunger_classified then
				--non-predicting client, server will clear the sprint drain flag when lunar powered
				if self.owner.pet_hunger_classified:GetFlagBit(1) then --sprint drain
					if self.owner.pet_hunger_classified:GetFlagBit(2) then --endurance
						return "arrow_loop_decrease"
					end
					return "arrow_loop_decrease_more"
				end
			end
		end
	end)
end

function StatusDisplays:SetSanityPercent(pct)
	local oldpenalty = self.brain.penaltypercent or 0
	local newpenalty = self.owner.replica.sanity:GetPenaltyPercent()
	self.brain:SetPercent(pct, self.owner.replica.sanity:Max(), newpenalty)

    if self.owner.replica.sanity:IsInsane() or self.owner.replica.sanity:IsEnlightened() then
        self.brain:StartWarning()
    else
        self.brain:StopWarning()
    end
	return oldpenalty, newpenalty
end

function StatusDisplays:SanityDelta(data)
	local oldpenalty, newpenalty = self:SetSanityPercent(data.newpercent)

    if self.brain ~= nil and self.brain.SanityDelta then
        self.brain:SanityDelta(data)
    else
		local green, red
        if not data.overtime then
            if data.newpercent > data.oldpercent then
				green = true
            elseif data.newpercent < data.oldpercent then
				red = true
            end
        end
		if newpenalty > oldpenalty then
			red = true
		elseif newpenalty < oldpenalty then
			green = true
		end
		if red then
			self.brain:PulseRed()
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/sanity_down")
		elseif green then
			self.brain:PulseGreen()
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/sanity_up")
		end
    end
end

function StatusDisplays:SetWerenessPercent(pct)
    self.wereness:SetPercent(pct)
end

function StatusDisplays:WerenessDelta(data)
    self:SetWerenessPercent(data.newpercent)

    if not data.overtime then
        if data.newpercent > data.oldpercent then
            self.wereness:PulseGreen()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/health_up")
        elseif data.newpercent < data.oldpercent then
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/health_down")
            self.wereness:PulseRed()
        end
    end
end

function StatusDisplays:SetInspiration(pct, slots_available, draining)
    self.inspirationbadge:SetPercent(pct)
	self.inspirationbadge:OnUpdateSlots(slots_available or self.owner:CalcAvailableSlotsForInspiration(pct))
	self.inspirationbadge:EnableClientPredictedDraining(pct > 0 and draining)
end

function StatusDisplays:OnInspirationSongChanged(slot_num, song_name)
    self.inspirationbadge:OnBuffChanged(slot_num, song_name)
end

function StatusDisplays:SetMightiness(percent)
    self.mightybadge:SetPercent(percent)
end

function StatusDisplays:MightinessDelta(data)
    local newpercent = data ~= nil and data.newpercent or 0
    local oldpercent = data ~= nil and data.oldpercent or 0

    self:SetMightiness(newpercent)

    if newpercent > oldpercent then
        self.mightybadge:PulseGreen()
    elseif newpercent < oldpercent and (self.previous_pulse == nil or (self.previous_pulse - oldpercent >= 0.009)) then
        self.mightybadge:PulseRed()
        self.previous_pulse = newpercent
    end
end

----------------------------------------------------------------------------------------------------------

function StatusDisplays:SetMoisturePercent(pct)
    self.moisturemeter:SetValue(pct, self.owner:GetMaxMoisture(), self.owner:GetMoistureRateScale())
end

function StatusDisplays:MoistureDelta(data)
    self:SetMoisturePercent(data.new)
end

function StatusDisplays:GetResurrectButton()
    return self.resurrectbutton:IsVisible() and self.resurrectbutton or nil
end

function StatusDisplays:RefreshPetHealth()
    local pethealthbar = self.owner.components.pethealthbar
	self.pethealthbadge:SetValues(pethealthbar:GetSymbol(), pethealthbar:GetSymbol2(), pethealthbar:GetPercent(), pethealthbar:GetOverTime(), pethealthbar:GetMaxHealth(), pethealthbar:GetPulse(), pethealthbar:GetMaxBonus(), pethealthbar:GetPercentBonus())
	pethealthbar:ResetPulse()
end

function StatusDisplays:RefreshHealthBuff()   
    self.heart:UpdateBuff(self.owner._buffsymbol:value())
end

function StatusDisplays:RefreshAvengingGhost()
    local avengeingghost = self.owner.components.avengingghost
    if avengeingghost:GetTime() > 0 then
        self.avengingghostbadge:Show()
        self.avengingghostbadge:SetValues(avengeingghost:GetSymbol(), avengeingghost:GetTime(),  avengeingghost:GetMaxTime())
    else
        self.avengingghostbadge:Hide()
    end
end

function StatusDisplays:RefreshPetSkin()
    local pethealthbar = self.owner.components.pethealthbar
    local skinname = TheInventory:LookupSkinname( pethealthbar._petskin:value() )
    self.pethealthbadge:SetIconSkin( skinname )
end

function StatusDisplays:EnableResurrect(enable, effigy_type)
    if enable then
        self.heart:ShowEffigy(effigy_type)
        if effigy_type == "grave" then
            self.resurrectbuttonfx:GetAnimState():SetBank("wendy_gravestone_button")
            self.resurrectbuttonfx:GetAnimState():SetBuild("wendy_gravestone_button")
        else
            self.resurrectbuttonfx:GetAnimState():SetBank("effigy_break")
            self.resurrectbuttonfx:GetAnimState():SetBuild("effigy_button")
        end
        self.resurrectbutton:SetType(effigy_type)
        if self.isghostmode then
            self.resurrectbutton:Show()
        else
            self.resurrectbutton:Hide()
        end
    else
        self.heart:HideEffigy(effigy_type)
        self.resurrectbutton:Hide()
    end
end

return StatusDisplays
