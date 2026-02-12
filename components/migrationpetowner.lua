local MigrationPetOwner = Class(function(self, inst)
    -- A lightweight component to easily pass through a prefab
    -- capable of migrating alongside an inventory item.

    self.inst = inst

    --self.get_pet_fn = nil
end)

function MigrationPetOwner:SetPetFn(petfn)
    self.get_pet_fn = petfn
end

function MigrationPetOwner:GetPet() -- Partial deprecation useful for checking if a pet exists but nothing else.
    if self.get_pet_fn then
        local pets = self.get_pet_fn(self.inst)
        if type(pets) == "table" then -- Backwards compatability.
            return pets[1]
        end
        return pets
    end
    return nil
end

function MigrationPetOwner:GetAllPets()
    if self.get_pet_fn then
        local pets = self.get_pet_fn(self.inst)
        if type(pets) ~= "table" then -- Backwards compatability.
            return {pets}
        end
        return pets
    end
    return nil
end

return MigrationPetOwner
