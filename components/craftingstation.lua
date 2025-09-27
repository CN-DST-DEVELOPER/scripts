local CraftingStation = Class(function(self, inst)
    self.inst = inst
    self.items = {} -- [i] = itemname
    self.recipes = {} -- [i] = recipename
    self.recipecraftinglimit = {} -- [recipename] = amount
    --self.nosave = false
end)

function CraftingStation:LearnItem(itemname, recipetouse)
    if not table.contains(self.items, itemname) then
        table.insert(self.items, itemname)
        table.insert(self.recipes, recipetouse)
    end
end

function CraftingStation:KnowsItem(itemname)
    return table.contains(self.items, itemname)
end

function CraftingStation:GetItems()
    return self.items
end

function CraftingStation:GetRecipes()
    return self.recipes
end

function CraftingStation:GetRecipeCraftingLimit(recipename)
    return self.recipecraftinglimit[recipename]
end

function CraftingStation:SetRecipeCraftingLimit(recipename, amount)
    self.recipecraftinglimit[recipename] = amount
end

function CraftingStation:RecipeCrafted(doers, recipename)
    local amount = self.recipecraftinglimit[recipename]
    if amount then
        amount = amount - 1
        if amount <= 0 then
            self:ForgetRecipe(recipename)
            for doer, _ in pairs(doers) do
                if doer.components.builder then
                    doer.components.builder:EvaluateTechTrees()
                end
            end
        else
            self.recipecraftinglimit[recipename] = amount
        end
    end
end

function CraftingStation:ForgetItem(itemname)
    for i, v in ipairs(self.items) do
        if v == itemname then
            local recipename = self.recipes[i]
            self.recipecraftinglimit[recipename] = nil
            table.remove(self.items, i)
            table.remove(self.recipes, i)
            break
        end
    end
end

function CraftingStation:ForgetRecipe(recipename)
    for i, v in ipairs(self.recipes) do
        if v == recipename then
            self.recipecraftinglimit[recipename] = nil
            table.remove(self.items, i)
            table.remove(self.recipes, i)
            break
        end
    end
end

function CraftingStation:ForgetAllItems()
    self.items = {}
    self.recipes = {}
    self.recipecraftinglimit = {}
end

function CraftingStation:OnSave()
    return not self.nosave and {
        items = self.items,
        recipes = self.recipes,
        recipecraftinglimit = self.recipecraftinglimit,
    } or nil
end

function CraftingStation:OnLoad(data)
    if not self.nosave then
        self.items = data.items or self.items
        self.recipes = data.recipes or self.recipes
        self.recipecraftinglimit = data.recipecraftinglimit or self.recipecraftinglimit

        if #self.items ~= #self.recipes then
            self:ForgetAllItems()
        end
    end
end

return CraftingStation
