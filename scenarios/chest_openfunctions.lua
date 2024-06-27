local function sanitydelta(inst, scenariorunner, data) --Changes sanity up or down
	local tar = data.doer or data.worker

	if not tar then
		return
	end

	local sanity = tar.components.sanity
	if sanity then
		sanity:DoDelta(math.random(-20, 20))
	end
end

local function hungerdelta(inst, scenariorunner, data) --Changes hunger up or down
	local tar = data.doer or data.worker

	if not tar then
		return
	end

	local hunger = tar.components.hunger
	if hunger then
		hunger:DoDelta(math.random(-20, 20))
	end
end

local function healthdelta(inst, scenariorunner, data) --Changes health (For the better! We don't want the player to die from this)
	local tar = data.doer or data.worker

	if not tar then
		return
	end

	local health = tar.components.health
	if health then
		health:DoDelta(math.random(0, 20))
	end
end

local function inventorydelta(inst, scenariorunner, data) --Does some sort of effect on an item in your inventory
	local tar = data.doer or data.worker

	if not tar then
		return
	end

	local inv = tar.components.inventory
	if inv then
		local rnd = math.random()
		if rnd < 0.25 then
			local items = inv:FindItems(function(item) return item.components.finiteuses end)
			local item = GetRandomItem(items)
			if not item then return end
			item.components.finiteuses:SetPercent(math.min(GetRandomWithVariance(item.components.finiteuses:GetPercent(), 0.2), 1.0))
		elseif rnd >= 0.25 and rnd < 0.5 then
			local items = inv:FindItems(function(item) return item.components.perishable end)
			local item = GetRandomItem(items)
			if not item then return end
			item.components.perishable:SetPercent(math.min(GetRandomWithVariance(item.components.perishable:GetPercent(), 0.2)))
		elseif rnd >= 0.5 and rnd < 0.75 then
			local items = inv:FindItems(function(item) return item.components.armor end)
			local item = GetRandomItem(items)
			if not item then return end
			item.components.armor:SetPercent(math.min(GetRandomWithVariance(item.components.armor:GetPercent(), 0.2)))
		else
			local items = inv:FindItems(function(item) return item.components.fueled end)
			local item = GetRandomItem(items)
			if not item then return end
			item.components.fueled:SetPercent(math.min(GetRandomWithVariance(item.components.fueled:GetPercent(), 0.2)))
		end
	end
end


local function summonmonsters(inst, scenariorunner, data)
	local monsterlist =
	{
		spider_dropper = function(inst) inst.sg:GoToState("dropper_enter") end,
	}

	local monster, initfn = GetRandomItemWithIndex(monsterlist)

	local tospawn = math.random(1, 3)

	local pt = inst:GetPosition()
    local theta = math.random() * TWOPI
    local radius = 4
    local steps = 12
	local step_decrement = (TWOPI / steps)
    local ground = TheWorld


    for _ = 1, steps do
        local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
        local wander_point = pt + offset

        if ground.Map and TileGroupManager:IsLandTile(ground.Map:GetTileAtPoint(wander_point.x, wander_point.y, wander_point.z)) then
			local spawn = SpawnPrefab(monster)
            spawn.Transform:SetPosition( wander_point.x, wander_point.y, wander_point.z )
			if initfn then
				initfn(spawn)
			end

			tospawn = tospawn - 1

			if tospawn <= 0 then
				break
			end
        end
        theta = theta - step_decrement
    end
end

local functions =
{
	sanity = sanitydelta,
	hunger = hungerdelta,
	health = healthdelta,
	inventory = inventorydelta,
	summonmonsters = summonmonsters
}

return functions