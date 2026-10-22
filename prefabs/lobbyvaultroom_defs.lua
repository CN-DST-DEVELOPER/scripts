local defs = {
    internal = {},
    layouts = {},
}

--------------------------------------------------------------------------

local CURRENT_VERSION = 1
defs.InitializeLayout = function(virtualroomset)
    virtualroomset:SetVersion(CURRENT_VERSION) -- Mandatory call for InitializeLayout to have proper versioning control for this file.
end

defs.DeleteLayout = function(virtualroomset)
end

return defs
