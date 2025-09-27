--------------------------------------------------------------------------
--[[ LunarHailBirdSoundManager class definition ]]
--------------------------------------------------------------------------

--Handled by birdmanager.lua
return Class(function(self, inst)

local _world = TheWorld
local _map = _world.Map

local HAIL_BIRD_SOUND_NAME = "hailbirdsoundname"

self.inst = inst

self.birds_dropping_param = net_tinybyte(self.inst.GUID, "lunarhailbirdsoundmanager.birds_dropping", "hailbirddirty")
self.birds_dropping_param:set(0)

self.sound_level = 0

-- Common.

--[[
0 = no sound
1 = first level of hail bird event sound
2 = second level of hail bird event sound (corpses are dropping)
3 = bird ambience is dead from turf ambience, eerie quiet...
]]

local HAIL_SOUND_LEVELS = {
    NONE            = 0,    --No Ambience
    SCUFFLES        = 1,    --Scuffling in the sky, and fighting with gestalts
    CORPSES         = 2,    --Corpses are falling
    NO_AMBIENCE     = 3,    --The bird chirps have left the ambience
}
self.HAIL_SOUND_LEVELS = HAIL_SOUND_LEVELS

local function PlaySoundLevel(level)
    --ambientsound.lua handles getting rid of bird ambience
    TheWorld:PushEvent("updateambientsoundparams")

    if level == HAIL_SOUND_LEVELS.NONE or level == HAIL_SOUND_LEVELS.NO_AMBIENCE then
        TheFocalPoint.SoundEmitter:KillSound(HAIL_BIRD_SOUND_NAME)
    elseif level == HAIL_SOUND_LEVELS.SCUFFLES or level == HAIL_SOUND_LEVELS.CORPSES then
        if not TheFocalPoint.SoundEmitter:PlayingSound(HAIL_BIRD_SOUND_NAME) then
            TheFocalPoint.SoundEmitter:PlaySound("lunarhail_event/amb/gestalt_attack_storm", HAIL_BIRD_SOUND_NAME)
        end
        TheFocalPoint.SoundEmitter:SetParameter(HAIL_BIRD_SOUND_NAME, "birds_dropping", level)
    end
end

local function OnHailBirdDirty()
    self.sound_level = self.birds_dropping_param:value()
    PlaySoundLevel(self.sound_level)
end

if not _world.ismastersim then
    inst:ListenForEvent("hailbirddirty", OnHailBirdDirty)
end

function self:GetIsBirdlessAmbience()
    return self.sound_level > HAIL_SOUND_LEVELS.NONE
end

-- Server.

function self:SetLevel(level)
    self.sound_level = level
    self.birds_dropping_param:set(level)

    if not TheNet:IsDedicated() then --Server doesn't need to play sound
        PlaySoundLevel(self.sound_level)
    end
end

end)