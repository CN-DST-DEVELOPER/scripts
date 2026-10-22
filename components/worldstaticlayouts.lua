local obj_layout = require("map/object_layout")

local WorldStaticLayouts = Class(function(self, inst)
    self.inst = inst

    self.placedlayouts = {}
    self.desiredlayouts = {}
    self.layoutorder = {}
end)

function WorldStaticLayouts:RegisterLayout(layoutname, fn)
    if not self.desiredlayouts[layoutname] then
        self.desiredlayouts[layoutname] = fn
        table.insert(self.layoutorder, layoutname)
    end
end

function WorldStaticLayouts:PlaceLayouts()
    for _, layoutname in ipairs(self.layoutorder) do
        if not self.placedlayouts[layoutname] then
            local fn = self.desiredlayouts[layoutname]
            local success = fn(self.inst)
            if success then
                self.placedlayouts[layoutname] = true
            else
                assert(false, string.format("Your world failed to place a required layout %s after worldgen. Please add your map to a bug report!", layoutname))
            end
        end
    end
    -- NOTES(JBK): Free up these tables and cause a crash if something tries to register a layout too late in the game logic.
    self.desiredlayouts = nil
    self.layoutorder = nil
end

function WorldStaticLayouts:OnSave()
    if next(self.placedlayouts) ~= nil then
        return {
            placedlayouts = self.placedlayouts,
        }
    end
end

function WorldStaticLayouts:OnLoad(data)
    if data then
        if data.placedlayouts then
            self.placedlayouts = data.placedlayouts
        end
    end
end

return WorldStaticLayouts
