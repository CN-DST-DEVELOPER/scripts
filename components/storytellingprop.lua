local StoryTellingProp = Class(function(self, inst)
    self.inst = inst

	--V2C: Recommended to explicitly add tag to prefab pristine state
	self.inst:AddTag("storytellingprop")
end)

function StoryTellingProp:OnRemoveFromEntity()
    self.inst:RemoveTag("storytellingprop")
end

return StoryTellingProp