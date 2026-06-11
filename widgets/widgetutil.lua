
function ShouldHintRecipe(recipetree, buildertree)
	if Profile:GetCraftingHintAllRecipesEnabled() then
		return true;
	end

    for k, v in pairs(recipetree) do
        local v1 = buildertree[tostring(k)]
        if v ~= nil and v1 ~= nil and v > v1 + 1 then
            return false
        end
    end
    return true
end

function CanPrototypeRecipe(recipetree, buildertree)
    for k, v in pairs(recipetree) do
        local v1 = buildertree[tostring(k)]
        if v ~= nil and v1 ~= nil and v > v1 then
            return false
        end
    end
    return true
end

local function BuilderCanAccessIngredientRecipe(builder, ing_prefab, ing_recipe, tech_level)
	return builder:KnowsRecipe(ing_recipe) or (CanPrototypeRecipe(ing_recipe.level, tech_level) and builder:CanLearn(ing_prefab))
end

local function CanCraftIngredient(owner, ing, tech_level)
	local builder = owner.replica.builder
	if owner.replica.inventory:Has(ing.type, math.max(1, RoundBiasedUp(ing.amount * builder:IngredientMod())), true) then
		return false
	end
	local ing_recipe = GetValidRecipe(ing.type)
	if ing_recipe == nil then
		return false
	elseif BuilderCanAccessIngredientRecipe(builder, ing.type, ing_recipe, tech_level) then
		return builder:HasIngredients(ing_recipe)
	elseif ing_recipe.forward_ingredients then
		--V2C: skill tree might've locked basic ingredient recipe. try the forwarded ingredient recipes.
		for i, v in ipairs(ing_recipe.forward_ingredients) do
			ing_recipe = GetValidRecipe(v)
			if ing_recipe and BuilderCanAccessIngredientRecipe(builder, v, ing_recipe, tech_level) then
				return builder:HasIngredients(ing_recipe)
			end
		end
	end
	return false
end

local lastsoundtime = nil
-- return values: "keep_crafting_menu_open", "error message"
function DoRecipeClick(owner, recipe, skin)
	local builder = owner and owner.replica.builder
	if builder and recipe then
        if skin == recipe.name then
            skin = nil
        end
		if owner:HasTag("busy") or builder:IsBusy() then
            return true
        end
        if owner.components.playercontroller ~= nil then
            local iscontrolsenabled, ishudblocking = owner.components.playercontroller:IsEnabled()
            if not (iscontrolsenabled or ishudblocking) then
                --Ignore button click when controls are disabled
                --but not just because of the HUD blocking input
                return true
            end
        end

		local buffered = builder:IsBuildBuffered(recipe.name)
		local knows = buffered or builder:KnowsRecipe(recipe)
		local has_ingredients = buffered or builder:HasIngredients(recipe)

        if not has_ingredients and TheWorld.ismastersim then
            owner:PushEvent("cantbuild", { owner = owner, recipe = recipe })
            --You might have the materials now. Check again.
			has_ingredients = builder:HasIngredients(recipe)
        end

		if buffered then
			SetCraftingAutopaused(false)
			Profile:SetLastUsedSkinForItem(recipe.name, skin)

            if recipe.placer == nil then
				builder:MakeRecipeFromMenu(recipe, skin)
            elseif owner.components.playercontroller ~= nil then
                owner.components.playercontroller:StartBuildPlacementMode(recipe, skin)
            end
			return false -- close the crafting menu
		elseif knows then
			if has_ingredients then
                --TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
				SetCraftingAutopaused(false)
				Profile:SetLastUsedSkinForItem(recipe.name, skin)

                if recipe.placer == nil then
					builder:MakeRecipeFromMenu(recipe, skin)
                    return true
                elseif owner.components.playercontroller ~= nil then
                    --owner.HUD.controls.craftingmenu.tabs:DeselectAll()
					builder:BufferBuild(recipe.name)
					if not builder:IsBuildBuffered(recipe.name) then
                        return true
                    end
                    owner.components.playercontroller:StartBuildPlacementMode(recipe, skin)
                end
			else
				-- check if we can craft sub ingredients
				local tech_level = builder:GetTechTrees()
				for i, ing in ipairs(recipe.ingredients) do
					if CanCraftIngredient(owner, ing, tech_level) then
						builder:MakeRecipeFromMenu(recipe, skin) -- tell the server to build the current recipe, not the ingredient
						return true
					end
				end
			
				return true, "NO_INGREDIENTS"
			end
		else
			local tech_level = builder:GetTechTrees()
            if CanPrototypeRecipe(recipe.level, tech_level) then
				if has_ingredients then
					SetCraftingAutopaused(false)
					Profile:SetLastUsedSkinForItem(recipe.name, skin)

					if recipe.placer == nil then
						builder:MakeRecipeFromMenu(recipe, skin)
						if recipe.nounlock then
							return true
						end
					elseif owner.components.playercontroller ~= nil then
						builder:BufferBuild(recipe.name)
						if not builder:IsBuildBuffered(recipe.name) then
							return true
						end
						owner.components.playercontroller:StartBuildPlacementMode(recipe, skin)
						if owner.components.builder ~= nil then
							owner.components.builder:ActivateCurrentResearchMachine(recipe)
							owner.components.builder:UnlockRecipe(recipe.name)
						end
					end
					if not recipe.nounlock then
						if lastsoundtime == nil or GetStaticTime() - lastsoundtime >= 1 then
							lastsoundtime = GetStaticTime()
							TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/research_unlock")
						end
					end

					return recipe.placer == nil -- close the crafting menu if there is a placer
				else
					-- check if we can craft sub ingredients
					for i, ing in ipairs(recipe.ingredients) do
						if CanCraftIngredient(owner, ing, tech_level) then
							builder:MakeRecipeFromMenu(recipe, skin) -- tell the server to build the current recipe, not the ingredient
							return true
						end
					end

					return true, "NO_INGREDIENTS"
				end
            else
                return true, recipe.nounlock and "NO_STATION" or "NO_TECH"
            end
        end
    end
end

local function GetXCoord(angle, width)
    if angle >= 90 and angle <= 180 then -- left side
        return 0
    elseif angle <= 0 and angle >= -90 then -- right side
        return width
    else -- middle somewhere
        if angle < 0 then
            angle = -angle - 90
        end
        local pctX = 1 - (angle / 90)
        return pctX * width
    end
end

local function GetYCoord(angle, height)
    if angle <= -90 and angle >= -180 then -- top side
        return height
    elseif angle >= 0 and angle <= 90 then -- bottom side
        return 0
    else -- middle somewhere
        if angle < 0 then
            angle = -angle
        end
        if angle > 90 then
            angle = angle - 90
        end
        local pctY = (angle / 90)
        return pctY * height
    end
end

function GetIndicatorLocationAndAngle(owner, targX, targZ, w, h, bufferoverrides)
    local angleToTarget = owner:GetAngleToPoint(targX, 0, targZ)
    local downVector = TheCamera:GetDownVec()
    local downAngle = -math.atan2(downVector.z, downVector.x) / DEGREES
    local indicatorAngle = (angleToTarget - downAngle) + 45
    while indicatorAngle > 180 do indicatorAngle = indicatorAngle - 360 end
    while indicatorAngle < -180 do indicatorAngle = indicatorAngle + 360 end

    local screenWidth, screenHeight = TheSim:GetScreenSize()

    local x = GetXCoord(indicatorAngle, screenWidth)
    local y = GetYCoord(indicatorAngle, screenHeight)

    local TOP_EDGE_BUFFER = 20
    local BOTTOM_EDGE_BUFFER = 40
    local LEFT_EDGE_BUFFER = 67
    local RIGHT_EDGE_BUFFER = 80
    if bufferoverrides then
        TOP_EDGE_BUFFER = bufferoverrides.TOP_EDGE_BUFFER or TOP_EDGE_BUFFER
        BOTTOM_EDGE_BUFFER = bufferoverrides.BOTTOM_EDGE_BUFFER or BOTTOM_EDGE_BUFFER
        LEFT_EDGE_BUFFER = bufferoverrides.LEFT_EDGE_BUFFER or LEFT_EDGE_BUFFER
        RIGHT_EDGE_BUFFER = bufferoverrides.RIGHT_EDGE_BUFFER or RIGHT_EDGE_BUFFER
    elseif bufferoverrides == false then
        TOP_EDGE_BUFFER = 0
        BOTTOM_EDGE_BUFFER = 0
        LEFT_EDGE_BUFFER = 0
        RIGHT_EDGE_BUFFER = 0
    end

    if x <= LEFT_EDGE_BUFFER + w then
        x = LEFT_EDGE_BUFFER + w
    elseif x >= screenWidth - RIGHT_EDGE_BUFFER - w then
        x = screenWidth - RIGHT_EDGE_BUFFER - w
    end

    if y <= BOTTOM_EDGE_BUFFER + h then
        y = BOTTOM_EDGE_BUFFER + h
    elseif y >= screenHeight - TOP_EDGE_BUFFER - h then
        y = screenHeight - TOP_EDGE_BUFFER - h
    end

    return x, y, indicatorAngle
end
