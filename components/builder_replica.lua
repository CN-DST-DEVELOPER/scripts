local TechTree = require("techtree")

--------------------------------------------------------------------------

local Builder = Class(function(self, inst)
    self.inst = inst

    if TheWorld.ismastersim then
        self.classified = inst.player_classified
    elseif self.classified == nil and inst.player_classified ~= nil then
        self:AttachClassified(inst.player_classified)
    end
end)

--------------------------------------------------------------------------

--V2C: OnRemoveFromEntity not supported
--[[function Builder:OnRemoveFromEntity()
    if self.classified ~= nil then
        if TheWorld.ismastersim then
            self.classified = nil
        else
            self.inst:RemoveEventCallback("onremove", self.ondetachclassified, self.classified)
            self:DetachClassified()
        end
    end
end

Builder.OnRemoveEntity = Builder.OnRemoveFromEntity]]

function Builder:AttachClassified(classified)
    self.classified = classified
    self.ondetachclassified = function() self:DetachClassified() end
    self.inst:ListenForEvent("onremove", self.ondetachclassified, classified)
end

function Builder:DetachClassified()
    self.classified = nil
    self.ondetachclassified = nil
end

--------------------------------------------------------------------------

function Builder:GetTechBonuses()
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:GetTechBonuses()
    elseif self.classified ~= nil then
		local bonus = {}
        for i, v in ipairs(TechTree.BONUS_TECH) do
            local bonus_netvar = self.classified[TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[v] or string.lower(v).."bonus"]
			bonus[v] = bonus_netvar ~= nil and bonus_netvar:value() or nil

            local tempbonus_netvar = self.classified[TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[v] or string.lower(v).."tempbonus"]
            if tempbonus_netvar ~= nil then
                if bonus[v] ~= nil then
                    bonus[v] = bonus[v] + tempbonus_netvar:value()
                else
                    bonus[v] = tempbonus_netvar:value()
                end
            end
        end
		return bonus
    end
	return {}
end

function Builder:SetTechBonus(tech, bonus)
	if self.classified ~= nil  then
		local netvar = self.classified[TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[tech] or string.lower(tech).."bonus"]
		if netvar ~= nil then
			netvar:set(bonus)
		end
	end
end

function Builder:SetTempTechBonus(tech, bonus)
    if self.classified ~= nil  then
		local netvar = self.classified[TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[tech] or string.lower(tech).."tempbonus"]
		if netvar ~= nil then
			netvar:set(bonus)
		end
	end
end

function Builder:SetIngredientMod(ingredientmod)
    if self.classified ~= nil then
        self.classified.ingredientmod:set(INGREDIENT_MOD[ingredientmod])
    end
end

function Builder:IngredientMod()
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder.ingredientmod
    elseif self.classified ~= nil then
        return INGREDIENT_MOD_LOOKUP[self.classified.ingredientmod:value()]
    else
        return 1
    end
end

function Builder:SetIsFreeBuildMode(isfreebuildmode)
    if self.classified ~= nil then
        self.classified.isfreebuildmode:set(isfreebuildmode)
    end
end

function Builder:IsFreeBuildMode()
    if self.classified ~= nil then
        return self.classified.isfreebuildmode:value()
    end
end

function Builder:SetCurrentPrototyper(prototyper)
    if self.classified ~= nil then
        self.classified.current_prototyper:set(prototyper)
    end
end

function Builder:GetCurrentPrototyper()
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder.current_prototyper
    elseif self.classified ~= nil then
        return self.classified.current_prototyper:value()
    end
end

function Builder:OpenCraftingMenu()
    if self.classified ~= nil then
        self.classified.opencraftingmenuevent:push()
    end
end

function Builder:SetTechTrees(techlevels)
    if self.classified ~= nil then
        for i, v in ipairs(TechTree.AVAILABLE_TECH) do
            self.classified[TechTree.AVAILABLE_TECH_LEVEL_CLASSIFIED[v] or string.lower(v).."level"]:set(techlevels[v] or 0)
        end
    end
end

function Builder:GetTechTrees()
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder.accessible_tech_trees
    elseif self.classified ~= nil then
        return self.classified.techtrees
    else
        return TECH.NONE
    end
end

function Builder:GetTechTreesNoTemp()
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder.accessible_tech_trees_no_temp
    elseif self.classified ~= nil then
        return self.classified.techtrees_no_temp
    else
        return TECH.NONE
    end
end

function Builder:AddRecipe(recipename)
    if self.classified ~= nil and self.classified.recipes[recipename] ~= nil then
        self.classified.recipes[recipename]:set(true)
    end
end

function Builder:RemoveRecipe(recipename)
    if self.classified ~= nil and self.classified.recipes[recipename] ~= nil then
        self.classified.recipes[recipename]:set(false)
    end
end

function Builder:SetRecipeCraftingLimit(index, recipename, amount)
    if self.classified ~= nil then
        local recipe = CRAFTINGSTATION_LIMITED_RECIPES_LOOKUPS[recipename] or 0
        if recipe == 0 then
            amount = 0
        end
        self.classified.craftinglimit_recipe[index]:set(recipe)
        self.classified.craftinglimit_amount[index]:set(amount)
    end
end
function Builder:GetAllRecipeCraftingLimits()
    local craftinglimits = {}
    if self.classified ~= nil then
        for i = 1, CRAFTINGSTATION_LIMITED_RECIPES_COUNT do
            local recipename = CRAFTINGSTATION_LIMITED_RECIPES[self.classified.craftinglimit_recipe[i]:value()]
            if recipename then
                local amount = self.classified.craftinglimit_amount[i]:value()
                craftinglimits[recipename] = amount
            end
        end
    end
    return craftinglimits
end

function Builder:BufferBuild(recipename)
    if self.inst.components.builder ~= nil then
        self.inst.components.builder:BufferBuild(recipename)
    elseif self.classified ~= nil then
        self.classified:BufferBuild(recipename)
    end
end

function Builder:SetIsBuildBuffered(recipename, isbuildbuffered)
    if self.classified ~= nil then
        self.classified.bufferedbuilds[recipename]:set(isbuildbuffered)
    end
end

function Builder:IsBuildBuffered(recipename)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:IsBuildBuffered(recipename)
    elseif self.classified ~= nil then
        return recipename ~= nil and
            (self.classified.bufferedbuilds[recipename] ~= nil and
            self.classified.bufferedbuilds[recipename]:value()) or
            self.classified._bufferedbuildspreview[recipename] == true
    else
        return false
    end
end

function Builder:HasCharacterIngredient(ingredient)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:HasCharacterIngredient(ingredient)
    elseif self.classified ~= nil then
        if ingredient.type == CHARACTER_INGREDIENT.HEALTH then
            local health = self.inst.replica.health
            if health ~= nil then
                --round up health to match UI display
				local amount_required = self.inst:HasTag("health_as_oldage") and math.ceil(ingredient.amount * TUNING.OLDAGE_HEALTH_SCALE) or ingredient.amount
                local current = math.ceil(health:GetCurrent())
                return current > amount_required, current --Don't die from crafting!
            end
        elseif ingredient.type == CHARACTER_INGREDIENT.MAX_HEALTH then
            local health = self.inst.replica.health
            if health ~= nil then
                local penalty = health:GetPenaltyPercent()
                return penalty + ingredient.amount <= TUNING.MAXIMUM_HEALTH_PENALTY, 1 - penalty
            end
        elseif ingredient.type == CHARACTER_INGREDIENT.SANITY then
            local sanity = self.inst.replica.sanity
            if sanity ~= nil then
                --round up sanity to match UI display
                local current = math.ceil(sanity:GetCurrent())
                return current >= ingredient.amount, current
            end
        elseif ingredient.type == CHARACTER_INGREDIENT.MAX_SANITY then
            local sanity = self.inst.replica.sanity
            if sanity ~= nil then
                local penalty = sanity:GetPenaltyPercent()
                return penalty + ingredient.amount <= TUNING.MAXIMUM_SANITY_PENALTY, 1 - penalty
            end
        end
    end
    return false, 0
end

function Builder:HasTechIngredient(ingredient)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:HasTechIngredient(ingredient)
    elseif self.classified ~= nil and IsTechIngredient(ingredient.type) and ingredient.type:sub(-9) == "_material" then
        local level = self.classified.techtrees[ingredient.type:sub(1, -10):upper()] or 0
        return level >= ingredient.amount, level
    end
    return false, 0
end

function Builder:KnowsRecipe(recipe, ignore_tempbonus, cached_tech_trees)
    if type(recipe) == "string" then
		recipe = GetValidRecipe(recipe)
	end

    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:KnowsRecipe(recipe, ignore_tempbonus, cached_tech_trees)
    elseif self.classified ~= nil then
        if recipe ~= nil then
			if self.classified.isfreebuildmode:value() then
				return true
			end

			--the following builder_tag/skill checks are require due to character swapping
			if (recipe.builder_tag and not self.inst:HasTag(recipe.builder_tag)) or
				(recipe.no_builder_tag and self.inst:HasTag(recipe.no_builder_tag))
			then
				return false
			end
			local skilltreeupdater = self.inst.components.skilltreeupdater
			if (recipe.builder_skill and not (skilltreeupdater and skilltreeupdater:IsActivated(recipe.builder_skill))) or
				(recipe.no_builder_skill and skilltreeupdater and skilltreeupdater:IsActivated(recipe.no_builder_skill))
			then
				return false
			end
			--

			if self.classified.recipes[recipe.name] and self.classified.recipes[recipe.name]:value() then
				return true
			end

            if cached_tech_trees and cached_tech_trees[recipe.level] ~= nil then
                return cached_tech_trees[recipe.level]
            end
            for i, v in ipairs(TechTree.AVAILABLE_TECH) do
                local bonus = self.classified[TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[v] or string.lower(v).."bonus"]
                local tempbonus = not ignore_tempbonus and self.classified[TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[v] or string.lower(v).."tempbonus"] or nil
                if recipe.level[v] > (bonus ~= nil and bonus:value() or 0) + (tempbonus ~= nil and tempbonus:value() or 0) then
                    if cached_tech_trees then
                        cached_tech_trees[recipe.level] = false
                    end
                    return false
                end
            end

            if cached_tech_trees then
                cached_tech_trees[recipe.level] = true
            end
			return true
        end
    end
    return false
end

function Builder:HasIngredients(recipe)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:HasIngredients(recipe)
    elseif self.classified ~= nil then
        if type(recipe) == "string" then 
            recipe = GetValidRecipe(recipe)
        end
		if recipe ~= nil then
			if self.classified.isfreebuildmode:value() then
				return true
			end
            for i, v in ipairs(recipe.ingredients) do
                if not self.inst.replica.inventory:Has(v.type, math.max(1, RoundBiasedUp(v.amount * self:IngredientMod())), true) then
                    return false
                end
            end
			for i, v in ipairs(recipe.character_ingredients) do
				if not self:HasCharacterIngredient(v) then
					return false
				end
			end
			for i, v in ipairs(recipe.tech_ingredients) do
				if not self:HasTechIngredient(v) then
					return false
				end
			end
			return true
		end
	end

	return false
end


function Builder:CanBuild(recipe_name) -- deprecated
	return self:HasIngredients(GetValidRecipe(recipe_name))
end

function Builder:CanLearn(recipename)
    if self.inst.components.builder ~= nil then
        return self.inst.components.builder:CanLearn(recipename)
    elseif self.classified ~= nil then
        local recipe = GetValidRecipe(recipename)
		if recipe == nil then
			return false
		elseif (recipe.builder_tag and not self.inst:HasTag(recipe.builder_tag)) or
			(recipe.no_builder_tag and self.inst:HasTag(recipe.no_builder_tag))
		then
			return false
		end
		local skilltreeupdater = self.inst.components.skilltreeupdater
		if (recipe.builder_skill and not (skilltreeupdater and skilltreeupdater:IsActivated(recipe.builder_skill))) or
			(recipe.no_builder_skill and skilltreeupdater and skilltreeupdater:IsActivated(recipe.no_builder_skill))
		then
			return false
		end
		return true
    else
        return false
    end
end

function Builder:CanBuildAtPoint(pt, recipe, rot)
    return TheWorld.Map:CanDeployRecipeAtPoint(pt, recipe, rot)
end

function Builder:MakeRecipeFromMenu(recipe, skin)
    if self.inst.components.builder ~= nil then
        self.inst.components.builder:MakeRecipeFromMenu(recipe, skin)
    elseif self.inst.components.playercontroller ~= nil then
        self.inst.components.playercontroller:RemoteMakeRecipeFromMenu(recipe, skin)
    end
end

function Builder:MakeRecipeAtPoint(recipe, pt, rot, skin)
    if self.inst.components.builder ~= nil then
        self.inst.components.builder:MakeRecipeAtPoint(recipe, pt, rot, skin)
    elseif self.inst.components.playercontroller ~= nil then
        self.inst.components.playercontroller:RemoteMakeRecipeAtPoint(recipe, pt, rot, skin)
    end
end

function Builder:IsBusy()
    if self.inst.components.builder ~= nil then
        return false
    end
    local inventory = self.inst.replica.inventory
    if inventory == nil or inventory.classified == nil then
        return false
    elseif inventory.classified:IsBusy() then
        return true
    end
    local overflow = inventory.classified:GetOverflowContainer()
    return overflow ~= nil and overflow.classified ~= nil and overflow.classified:IsBusy()
end

return Builder
