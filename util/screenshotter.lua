require "class"


local is_first_instance = true

-- A wrapper around TheSim's screenshot callback to add some extra validation
-- and functionality.
local Screenshotter = Class(function(self)
	assert(is_first_instance, "Only one Screenshotter can exist.")
	is_first_instance = false

	self.cb = nil
end)

function Screenshotter:HasPendingScreenshot()
	return self.cb ~= nil
end

function Screenshotter:RequestScreenshot(cb)
	assert(cb, "Must pass a callback.")
	assert(not self.cb, "Screenshot already in progress. Try checking HasPendingScreenshot before calling.")
	self.cb = cb
	if TheSim.RequestScreenshot then
		TheSim:RequestScreenshot()
	end
end

function Screenshotter:_ScreenshotReady()
	assert(self.cb, "No screenshot in progress?")
	local cb = self.cb
	self.cb = nil
	cb()
end

function OnScreenshotReady()
	TheScreenshotter:_ScreenshotReady()
end

return Screenshotter
