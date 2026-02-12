--------------------------------------------------------------------------
--[[ CorpsePersistManager class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "CorpsePersistManager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local CHECK_CORPSE_TIME_BASE = 10
local CHECK_CORPSE_TIME_VAR = 5

local MAX_CORPSES = 200 -- This is the ABSOLUTE max across the entire world.

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _corpses = {} -- array
local _persist_fns = {}

local check_corpses_cooldown = 0

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRemoveCorpse(corpse)
	for i, v in ipairs(_corpses) do
		if v == corpse then
			table.remove(_corpses, i)
			return
		end
	end
end

local function RegisterCorpse(inst, corpse)
	table.insert(_corpses, corpse)
	inst:ListenForEvent("onremove", OnRemoveCorpse, corpse)
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Register events
inst:ListenForEvent("ms_registercorpse", RegisterCorpse)

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:AddPersistSourceFn(key, fn)
    _persist_fns[key] = fn

    if self.inst.updatecomponents[self] == nil then
        self.inst:StartUpdatingComponent(self)
    end
end

function self:RemovePersistSourceFn(key)
    _persist_fns[key] = nil

    for i, v in ipairs(_corpses) do
        v:RemovePersistSource(key)
    end

    if self.inst.updatecomponents[self] ~= nil and next(_persist_fns) == nil then
        self.inst:StopUpdatingComponent(self)
    end
end

function self:ShouldRetainCreatureAsCorpse(creature)
    -- Hey we have too many! Stop it!
    if self:IsMaxReached() then
        return false
    end
    --
    for persist_key, persist_fn in pairs(_persist_fns) do
        if persist_fn(creature) then
            return true
        end
    end
    --
    return false
end

function self:IsMaxReached()
    return #_corpses >= MAX_CORPSES
end

function self:AnyCorpseExists()
    return next(_corpses) ~= nil
end

function self:OnUpdate(dt)
    if check_corpses_cooldown <= 0 then
        -- Persist up to this many corpses
        for i = 1, math.min(#_corpses, MAX_CORPSES) do
            local corpse = _corpses[i]
            for persist_key, persist_fn in pairs(_persist_fns) do
                local should_persist = persist_fn(corpse)
                if should_persist then
                    corpse:SetPersistSource(persist_key, true)
                else
                    corpse:RemovePersistSource(persist_key)
                end
            end
        end

        -- Too much. Get rid of the rest.
        if self:IsMaxReached() then
            for i = MAX_CORPSES + 1, #_corpses do
                local corpse = _corpses[i]
                for persist_key in pairs(_persist_fns) do -- Need to go!
                    corpse:RemovePersistSource(persist_key)
                end
            end
        end

        check_corpses_cooldown = CHECK_CORPSE_TIME_BASE + math.random() * CHECK_CORPSE_TIME_VAR
    else
        check_corpses_cooldown = check_corpses_cooldown - dt
    end
end
-- LongUpdate is not supported for now due to issues with the order code can be ran in.
--self.LongUpdate = self.OnUpdate

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    return string.format("Persisting %d corpses", #_corpses)
end

end)