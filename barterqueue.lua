if not TheItems:IsBarterQueueEnabled() then
	return false
end

local dirty = false

local PopupDialogScreen = require "screens/redux/popupdialog"
local BarterWidget = require "widgets/redux/barterwidget"
local UnravelDupesScreen = require 'screens/redux/unraveldupesscreen'

local BarterQueue = Class(function()
end)

function BarterQueue.GetInfo()
    local totItems, totSpool, items = TheItems:SetupBarterLoseAllDuplicateItems()
    return totItems, totSpool, items
end

ValidateLineNumber(19)
function BarterQueue.UnravelDuplicates()
    local totDupes, totSpool, dupes = BarterQueue.GetInfo()
	local function okCallback(dupes)
		local totSpool = 0
		local totDupes = #dupes
		for _,item in pairs(dupes) do
			totSpool = totSpool + item.value
		end
		TheFrontEnd:PushScreen(PopupDialogScreen(
			STRINGS.UI.BARTER_QUEUE.UNRAVEL_DUPES_TITLE,
			subfmt(STRINGS.UI.BARTER_QUEUE.UNRAVEL_DUPES_BODY, {count = totDupes, doodad_count = totSpool, doodad_net = TheInventory:GetCurrencyAmount() + totSpool}),
			{
				{ text=STRINGS.UI.BARTER_QUEUE.UNRAVEL_DUPES_YES, cb = function() 
					TheFrontEnd:PopScreen()
					local result = TheItems:BarterLoseAllDuplicateItems(totDupes, totSpool, dupes)
					TheFrontEnd:PopScreen()
					if not result then
						local unravel_error = PopupDialogScreen(STRINGS.UI.BARTER_QUEUE.UNRAVEL_ERROR_TITLE, STRINGS.UI.BARTER_QUEUE.UNRAVEL_ERROR_BODY, {
						{
							text=STRINGS.UI.BARTERSCREEN.OK,
							cb = function()
			                    SimReset()
							end
							},
						})
						TheFrontEnd:PushScreen( unravel_error )
					end
				end },
				{ text=STRINGS.UI.BARTER_QUEUE.UNRAVEL_DUPES_NO, cb = function() TheFrontEnd:PopScreen() end },
			}
		))
	end

	TheFrontEnd:PushScreen(UnravelDupesScreen(dupes, 
		okCallback,
		function()
			TheFrontEnd:PopScreen()
		end
    ))
	do
		return
	end
end
ValidateLineNumber(63)

function BarterQueue.CancelUnravelDuplicates()
	TheItems:CancelBarterLoseAllDuplicateItems()
end

function BarterQueue.UpdateScreen()
	local frontScreen = TheFrontEnd:GetActiveScreen()
	if frontScreen and frontScreen.BarterQueueUpdate then
		frontScreen:BarterQueueUpdate()
	end
end

function BarterQueueStart()
	BarterWidget.Show()
	BarterQueue.UpdateScreen()
end

function BarterQueueFinish()
	BarterWidget.Hide()
	BarterQueue.UpdateScreen()
end

function BarterQueueFail(status)
    local server_error = PopupDialogScreen(STRINGS.UI.BARTERSCREEN.FAILED_TITLE, STRINGS.UI.BARTERSCREEN.FAILED_BODY, {
            {
                text=STRINGS.UI.BARTERSCREEN.OK,
                cb = function()
                    print("ERROR: Failed to contact the item server. status=", status )
                    TheFrontEnd:PopScreen()
                    SimReset()
                end
            },
        })
	TheFrontEnd:PushScreen( server_error )
end

function BarterQueueStartTask(command, item_id, index, tot_index)
	BarterWidget.UpdateStart(command, item_id, index, tot_index)
	BarterQueue.UpdateScreen()
end

function BarterQueueEndTask(command, item_id, index, tot_index)
	BarterQueue.UpdateScreen()
end

return BarterQueue
