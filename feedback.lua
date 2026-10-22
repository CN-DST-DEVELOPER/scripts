local FeedbackScreen = require "screens/redux/feedbackscreen"
local PauseScreen = require "screens/redux/pausescreen"


local feedback = {}

local function OnFeedbackScreenshotReady(texture, texture_string )
	local screen = FeedbackScreen(texture, texture_string)
	TheFrontEnd:PushScreen(screen)
	TheFeedbackScreen = screen
end

function feedback.StartFeedback()
	if TheScreenshotter:HasPendingScreenshot() then
		print("Screenshot already in progress. Ignoring StartFeedback...")
		return
	end

	if TheFrontEnd.error_widget then
		-- Would be nice to do the work to make feedback work after
		-- errors, but not for now.
		local msg = "Feedback doesn't work after hitting an error\n\n"
		if DEV_MODE then
			msg = "Feedback doesn't work after hitting an error. Comment on your crash in #dst-crashes to tell us what happened or reload and send feedback.\n\n"
		end
		local text = TheFrontEnd.error_widget.text:GetText() or ""
		TheFrontEnd.error_widget.text:SetText(msg .. text)
		return
	end

	local feed = TheFrontEnd:FindScreen(FeedbackScreen)
	if not feed then
		TheScreenshotter:RequestScreenshot(OnFeedbackScreenshotReady)
	end
end

return feedback
