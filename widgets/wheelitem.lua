
local ImageButton = require "widgets/imagebutton"
local VirtualKeyboard = IsConsole() and require("screens/virtualkeyboard") or nil
local UserCommands = require('usercommands')

local WheelItem = nil
WheelItem ={

	-- helper function to create setup the data for emote wheel entries
	EmoteItem = function(emote, character)
		return	{	label=STRINGS.UI.EMOTES[emote:upper()],
					helptext=STRINGS.UI.EMOTES.HELPTEXTPREFIX .. (STRINGS.UI.EMOTES[emote:upper()] or ""), 
					execute=function()
							UserCommands.RunUserCommand(emote, {}, ThePlayer)
							AwardPlayerAchievement( "party_time", ThePlayer )
						end, 
					atlas="images/emotes_" ..character.. ".xml", 
					normal="gesture_" ..character.."_"..emote..".tex"
				}
	end,
}
if IsConsole() then
    WheelItem.TextChatItem = function( whisper, image )
		return	{	label=whisper and STRINGS.UI.COMMANDWHEEL.WHISPER or STRINGS.UI.COMMANDWHEEL.SAY,
					execute = function() 
						TheFrontEnd:PushScreen( 
							VirtualKeyboard( whisper and STRINGS.UI.COMMANDWHEEL.WHISPER or STRINGS.UI.COMMANDWHEEL.SAY, "", "", 64, true, true, 
								function( new_text ) 
									if new_text ~= nil and new_text ~= "" then 
										TheNet:Say(new_text, whisper)
									end
								end
							)
						) end,
					atlas="images/command_wheel.xml",
					normal=image
				}
	end
end

return WheelItem