local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Screen = require "widgets/screen"
local Text = require "widgets/text"
local TextEdit = require "widgets/textedit"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local RadioButtons = require "widgets/radiobuttons"
local Panel = require "widgets/panel"
local PopupDialogScreen = require "screens/redux/popupdialog"

local Category = {
	AUDIO = "AUDIO",
	VISUAL = "VISUAL",
	WORDS = "WORDS",
	OTHER = "OTHER",
}

-- NOTES(JBK): With this being for beta feedback the strings do not need localized.
local FEEDBACK_SCREEN = {
    UI_TITLE = "Send Us Your Beta Feedback",
    SUMMARY_HELPERTEXT = "What happened?",
    DETAILS_HELPERTEXT = "A short summary of your feedback",

    SUBMIT = "Submit",
    CANCEL = "Cancel",
    REQUIRE_SUMMARY = "Briefly describe your issue in the Summary field!",
    CATEGORY = 
    {
        AUDIO = "Audio",
        VISUAL = "Visual",
        WORDS = "Words",
        OTHER = "Other",
    },
    CATEGORY_PROMPT =
    {
        -- These must fit on a single line.
        AUDIO = "Does something sound wrong? Or amazing?",
        VISUAL = "Tell us about what you saw.",
        WORDS = "Loved some dialogue? Found a typo? Confused?",
        OTHER = "What happened?",
    },
    SEND_LOG = "Send Log Files",
    SEND_SCREENSHOT = "Send Screenshot",
    SEND_SAVE = "Send Savegame",

    SUBMITTING_BODY = "Sending feedback",

    SUBMITTED_TITLE = "Feedback submitted",
    SUBMITTED_BODY = "Thank you for your feedback. You are helping to make this game better!",
    SUBMITTED_OK = "OK",

    SUBMIT_ERROR_TITLE = "Unexpected Error",
    SUBMIT_ERROR_BODY = "Something went wrong. Please try again later.",
    SUBMIT_ERROR_OK = "OK",

    DISCARD_TITLE = "Discard changes?",
    DISCARD_BODY = "Are you sure you want to cancel your feedback?",
    DISCARD_YES = "Yes",
    DISCARD_NO = "No",

    NOT_AUTOPAUSED = "Warning - the game is not auto-paused.",
}


local PANEL_WIDTH = 1000
local PANEL_HEIGHT = 530

local label_width = 150
local spinner_width = 50
local spinner_height = 36 --nil -- use default
local space_between = 5
local narrow_field_nudge = -50

local titlesize = 22
local fontsize = 20
local text_color = {0, 0, 0, 1}

local function CreateCheckBox(labeltext, onclicked, checked, tooltip_text)
	local w = TEMPLATES.OptionsLabelCheckbox(onclicked, labeltext, checked, label_width, spinner_width, spinner_height, spinner_height + 15, space_between, CHATFONT, nil, narrow_field_nudge, tooltip_text)
	return w
end

local function CreateCheckBoxNew(parent, data_owner, param, labeltext, tooltip_text)
	local checked = data_owner[param]
	local onclicked = function()
						data_owner[param]= not data_owner[param]
					    return data_owner[param]
			    end

	local w = TEMPLATES.OptionsLabelCheckbox(onclicked, labeltext, checked, label_width, spinner_width, spinner_height, spinner_height + 15, space_between, CHATFONT, nil, narrow_field_nudge, tooltip_text)
	return parent:AddChild(w)
end

local function TextWithBg(text, prompt, w, h)
	local wdg = Widget("TextWithBg")

	local bg = wdg:AddChild(Panel("images/global_redux.xml", "textbox3_gold_normal.tex"))
	bg:SetNineSliceCoords(36, 20, 620, 63)
	bg:SetNineSliceBorderScale(0.5)
	bg:SetSize(w + 30, h + 20)
	wdg.bg = bg

	local text = wdg:AddChild(TextEdit( CHATFONT, fontsize, text, WHITE ) )
	wdg.text = text
	text:SetForceEdit(true)
	text:SetColour(unpack(text_color))

	text:SetFocusedImage( bg, "images/global_redux.xml", "textbox3_gold_normal.tex", "textbox3_gold_hover.tex", "textbox3_gold_focus.tex" )

	text:SetEditCursorColour(text_color)
	text:SetRegionSize(w, h)
	text:SetHAlign(ANCHOR_LEFT)
	text:SetVAlign(ANCHOR_TOP)

	text:SetTextPrompt(prompt, UICOLOURS.GREY)
	text.prompt:SetVAlign(ANCHOR_TOP)

	if h > fontsize * 2 then
		text:EnableScrollEditWindow(false)
		text:EnableRegionSizeLimit(true)
		text:EnableWhitespaceWrap(true)
		text:EnableWordWrap(true)
		text:SetAllowNewline(true)
	end

	return wdg
end

FeedbackScreen = Class(Screen, function(self, gamestate, screen_shot_texture)
	Screen._ctor(self, "FeedbackScreen")

	self.active = true
	SetPause(true, "feedback")
	SetAutopaused(true)

	self.root = self:AddChild(TEMPLATES.ScreenRoot("ScrapBook"))

	-- Only some very minor darkening. It kinda obsures that the game goes on while we are in here
	self.black = self.root:AddChild(Image("images/global.xml", "square.tex"))
	self.black:SetVRegPoint(ANCHOR_MIDDLE)
	self.black:SetHRegPoint(ANCHOR_MIDDLE)
	self.black:SetVAnchor(ANCHOR_MIDDLE)
	self.black:SetHAnchor(ANCHOR_MIDDLE)
	self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
	self.black:SetTint(0,0,0,.7)

    self.dialog = self.root:AddChild(TEMPLATES.RectangleWindow(PANEL_WIDTH, PANEL_HEIGHT))
    self.dialog:SetPosition(0, 0)
    local r,g,b = unpack(UICOLOURS.BROWN_DARK)
    self.dialog:SetBackgroundTint(r,g,b,0.95)


    self.fixed_root = self:AddChild(Widget("root"))
    self.fixed_root:SetVAnchor(ANCHOR_MIDDLE)
    self.fixed_root:SetHAnchor(ANCHOR_MIDDLE)
    self.fixed_root:SetScaleMode(SCALEMODE_PROPORTIONAL)

	self.title = self.dialog:AddChild(Text(BUTTONFONT, 40))
	self.title:SetPosition(0, 235, 0)
	self.title:SetColour(UICOLOURS.GOLD)
	self.title:SetString(FEEDBACK_SCREEN.UI_TITLE)

    do -- Scope block.
        local title_str = STRINGS.UI.MAINSCREEN.MAINBANNER_BETA_TITLE
        local x, y = 80, 0
        local text_width = 880
        local font_size = 22
        local font = BODYTEXTFONT

        local shadow = self.title:AddChild(Text(font, font_size, title_str, UICOLOURS.BLACK))
        local title  = self.title:AddChild(Text(font, font_size, title_str, UICOLOURS.HIGHLIGHT_GOLD))

        shadow:SetRegionSize(text_width, 2*(font_size + 2))
        title:SetRegionSize(text_width, 2*(font_size + 2))
        shadow:SetHAlign(ANCHOR_RIGHT)
        title:SetHAlign(ANCHOR_RIGHT)
        
        shadow:SetPosition(x + 2, y - 2)
        title:SetPosition(x, y)
    end

    self.send_log = true
    self.send_screenshot = true
    self.send_savegame = true

	local SummaryTitle = self.dialog:AddChild(Text(CHATFONT, titlesize, "Summary", UICOLOURS.GOLD))
	SummaryTitle:SetRegionSize(480,30)
	SummaryTitle:SetHAlign(ANCHOR_LEFT)
	SummaryTitle:SetPosition(-260, 230 - 40)
	self.subject = self.dialog:AddChild(TextWithBg("", FEEDBACK_SCREEN.SUMMARY_HELPERTEXT, 480, 24) )
	self.subject:SetPosition(-260,200 - 40)
	self.subject.text.prompt:SetString(FEEDBACK_SCREEN.CATEGORY_PROMPT.OTHER)

	self.subject.text:SetFn(function()
		self:_RefreshSendButton()
		self:DoFocusHookup()
	end)

	local label_height = 40
	local radiosize = 22

	local category_buttons = {
		width = 130,
		height = label_height,
		font = NEWFONT,
		font_size = radiosize,
		image_scale = 0.5,
		atlas = "images/global_redux.xml",
		on_image = "radiobutton_gold_on.tex",
		off_image = "radiobutton_gold_off.tex",
		normal_colour = UICOLOURS.GOLD,
		hover_colour = UICOLOURS.HIGHLIGHT_GOLD,
		selected_colour = UICOLOURS.GOLD,
		disabled_colour = GREY,
	}

	local category_options = {
		{text=FEEDBACK_SCREEN.CATEGORY.AUDIO,  data=Category.AUDIO},
		{text=FEEDBACK_SCREEN.CATEGORY.VISUAL, data=Category.VISUAL},
		{text=FEEDBACK_SCREEN.CATEGORY.WORDS,  data=Category.WORDS},
		{text=FEEDBACK_SCREEN.CATEGORY.OTHER,  data=Category.OTHER},
	}
	local category_width = #category_options * 120

	self.category_type = Widget("Report Category")
	self.category_type.buttons = self.category_type:AddChild(RadioButtons(category_options, category_width, 50, category_buttons, true))
	self.category_type.buttons:SetSelected(Category.OTHER)
	self.category_type.buttons:SetOnChangedFn(function(data)
		self.category = data
		local prompt = FEEDBACK_SCREEN.CATEGORY_PROMPT[data]
		self.subject.text.prompt:SetString(prompt)
	end)
	self.category_type.focus_forward = self.category_type.buttons
	self.dialog:AddChild(self.category_type)
	self.category_type:SetPosition(-266,125)

	local DetailsTitle = self.dialog:AddChild(Text(CHATFONT, titlesize, "Details", UICOLOURS.GOLD))
	DetailsTitle:SetRegionSize(480,30)
	DetailsTitle:SetHAlign(ANCHOR_LEFT)
	DetailsTitle:SetPosition(-260, 130 - 40)

	self.details = self.dialog:AddChild(TextWithBg("", FEEDBACK_SCREEN.DETAILS_HELPERTEXT, 480, 304) )
	self.details:SetPosition(-260,10 - 90)

	self.details.text:SetOnTabGoToTextEditWidget(self.subject.text)
	self.subject.text:SetOnTabGoToTextEditWidget(self.details.text)

	local image_x = 260
	local image_y = 0 + 60
	local image_w = 500

	local padding  = 10
	local screen_grab = Image("images/screen_capture.xml","screen_capture.tex")
	screen_grab:SetScale(0.25, 0.25)
	self.dialog:AddChild(screen_grab)

	local x,y = screen_grab:GetSize()
	local w = image_w/x
	screen_grab:SetScale(w, w)
	screen_grab:SetPosition(image_x,image_y)

	self.autopause_status = self.root:AddChild(Text(UIFONT, 40))
	self.autopause_status:SetPosition(0, 320)
	self:_UpdateAutopauseStatus()
	self.inst:ListenForEvent("serverpauseddirty", function() self:_UpdateAutopauseStatus() end, TheWorld)

	self.checkbox_send_screenshot = CreateCheckBoxNew(self.root, self, "send_screenshot", FEEDBACK_SCREEN.SEND_SCREENSHOT,
			STRINGS.UI.OPTIONS.TOOLTIPS.DATACOLLECTION
			)
	self.checkbox_send_screenshot:SetPosition(300,-100)

	self.checkbox_send_log = CreateCheckBoxNew(self.root, self, "send_log", FEEDBACK_SCREEN.SEND_LOG,
			STRINGS.UI.OPTIONS.TOOLTIPS.DATACOLLECTION
			)
	self.checkbox_send_log:SetPosition(300,-130)

	self.send_btn = self.root:AddChild(
		TEMPLATES.StandardButton(
			function()
				self:SendFeedback()
			end,
			FEEDBACK_SCREEN.SUBMIT,
			{200, 50}
		)
	)
	self.send_btn:SetPosition(360, -240)

	self.cancel_btn = self.root:AddChild(
		TEMPLATES.StandardButton(
			function() 
				self:TryCancelFeedback()
			end,
			FEEDBACK_SCREEN.CANCEL,
			{200, 50}
		)
	)
	self.cancel_btn:SetPosition(160, -240)

	self:_RefreshSendButton()
	self:DoFocusHookup()

end)

function FeedbackScreen:OnControl(control, down)
    if FeedbackScreen._base.OnControl(self, control, down) then return true end

    if not down and control == CONTROL_CANCEL then
		self:TryCancelFeedback()
        return true
    end
end


function FeedbackScreen:_GetFeedbackName()
	for i,player in ipairs(AllPlayers) do
		local name = player.Network:GetClientName()
		if name and name:len() > 0 then
			return player.Network:GetClientName()
		end
	end
	-- In main menu, we have no players so we'll keep a cached name.
	return Profile:GetFeedbackName()
end

function FeedbackScreen:SetDefaultFocus()
	self.subject.text:SetFocus()
end

function FeedbackScreen:SendFeedback()
	if self.submitting then
		print("Can't send feedback: already sending.")
		return
	end
	self.submitting = true

	local GenericWaitingPopup = require "screens/redux/genericwaitingpopup"
    local cancelfn = function()
		self:CancelFeedback()
	end
	local submit_popup= GenericWaitingPopup("SubmitFeedbackPopup", FEEDBACK_SCREEN.SUBMITTING_BODY, nil, false, cancelfn)
    TheFrontEnd:PushScreen(submit_popup)

	local gamestatus = "" -- string to populate a txt file
	local infodotlua = "" -- string to populate a lua file
	local postfix = ""
	local player_name = "Anonymous"
	local category = self.category or Category.OTHER
	local emoticon = 1
	local send_savegame = self.send_savegame
	local send_log = self.send_log
	local send_screenshot = self.send_screenshot
	local res = TheSim:CreateFeedback(
		self.subject.text:GetString() or "",
		(self.details.text:GetString() or "")..postfix,
		player_name,
		category,
		gamestatus,
		infodotlua,
		emoticon,
		send_savegame,
		send_screenshot,
		send_log
		)

	if res == "" then
		local feedback_error = PopupDialogScreen(
			FEEDBACK_SCREEN.SUBMIT_ERROR_TITLE,
			FEEDBACK_SCREEN.SUBMIT_ERROR_BODY,
			{
				{
					text = FEEDBACK_SCREEN.SUBMIT_ERROR_OK,
					cb = function()
						TheFrontEnd:PopScreen()	-- This dialog
						TheFrontEnd:PopScreen()	-- The waiting popup 

						self:CancelFeedback()
					end
				}
			}
		)
		TheFrontEnd:PushScreen(feedback_error)

	end
end

function FeedbackScreen:HasTextEntered()
	local subject = self.subject.text:GetString() or ""
	local details = self.details.text:GetString() or ""
	return subject:len() > 0 or details:len() > 0
end

function FeedbackScreen:TryCancelFeedback()
	if self:HasTextEntered() then
		local dialog = PopupDialogScreen(
			FEEDBACK_SCREEN.DISCARD_TITLE,
			FEEDBACK_SCREEN.DISCARD_BODY,
			{
				{
					text = FEEDBACK_SCREEN.DISCARD_YES,
					cb = function()
						TheFrontEnd:PopScreen()
						self:CancelFeedback()
					end
				},
				{
					text = FEEDBACK_SCREEN.DISCARD_NO,
					cb = function()
						TheFrontEnd:PopScreen()
					end
				},
			}
		)
		TheFrontEnd:PushScreen(dialog)
	else
		self:CancelFeedback()
	end
end

function FeedbackScreen:CancelFeedback()
	self.active = false
	SetAutopaused(false)
	SetPause(false)
	TheFeedbackScreen = nil
    TheSim:CancelFeedback()
    TheFrontEnd:PopScreen(self)
end

function FeedbackScreen:SubmitFeedbackResult(response_code, response)
	if self.submitting then
		self.submitting = false
		print("Feedback response code:", response_code)
		print("response:", response)
		TheFrontEnd:PopScreen() -- pop the sending... dialog
		-- Show the thank you for submitting dialog:

        local thankyou = PopupDialogScreen( FEEDBACK_SCREEN.SUBMITTED_TITLE, FEEDBACK_SCREEN.SUBMITTED_BODY,
        {
            {text=FEEDBACK_SCREEN.SUBMITTED_OK, cb = function()
                 TheFrontEnd:PopScreen()
                 self:CancelFeedback()
            end },
        })
        TheFrontEnd:PushScreen(thankyou)

	else
		TheLog.ch.Feedback:print("Not submitting - ignore result")
	end
end


function FeedbackScreen:_UpdateAutopauseStatus()
	if ThePlayer == nil or TheNet:IsServerPaused() then
		self.autopause_status:Hide()
	else
		self.autopause_status:SetString(FEEDBACK_SCREEN.NOT_AUTOPAUSED)
		self.autopause_status:Show()
	end
end

function FeedbackScreen:_RefreshSendButton()
	if self.subject.text:GetString():len() < 1 then
		self.send_btn:Disable()
		self.send_btn:SetHoverText(FEEDBACK_SCREEN.REQUIRE_SUMMARY)
	else
		self.send_btn:Enable()
		self.send_btn:ClearHoverText()
	end
end

function FeedbackScreen:SetCategory(cat)
	for k, v in pairs(self.category_checks) do
		v:SetValue(k == cat, true)
	end
	self.category = cat

	self.message_inputbox:SetTextPrompt(FEEDBACK_SCREEN.CATEGORY_PROMPT[cat])
end

function FeedbackScreen:HandleControlUp(control)
	if control:Has(Controls.Digital.MENU_CANCEL) then
		TheFrontEnd:PopScreen(self)
		return true

	elseif control:Has(Controls.Digital.MENU_SUBMIT) then
		if self.subject_inputbox:IsEnabled() then
			self:SendFeedback()
		end
		return true
	end

	return false
end

function FeedbackScreen:DoFocusHookup()
	self.send_btn:SetFocusChangeDir(MOVE_LEFT, self.cancel_btn)
	self.cancel_btn:SetFocusChangeDir(MOVE_RIGHT, self.send_btn)

	self.checkbox_send_screenshot.button:SetFocusChangeDir(MOVE_DOWN, self.checkbox_send_log.button)
	self.checkbox_send_log.button:SetFocusChangeDir(MOVE_UP, self.checkbox_send_screenshot.button)

	self.send_btn:SetFocusChangeDir(MOVE_UP, self.checkbox_send_log.button)
	self.cancel_btn:SetFocusChangeDir(MOVE_UP, self.checkbox_send_log.button)

	if self.send_btn:IsEnabled() then
		self.checkbox_send_log.button:SetFocusChangeDir(MOVE_DOWN, self.send_btn)
	else
		self.checkbox_send_log.button:SetFocusChangeDir(MOVE_DOWN, self.cancel_btn)
	end

	self.checkbox_send_screenshot.button:SetFocusChangeDir(MOVE_LEFT, self.details.text)
	self.checkbox_send_log.button:SetFocusChangeDir(MOVE_LEFT, self.details.text)

	self.cancel_btn:SetFocusChangeDir(MOVE_LEFT, self.details.text)

	self.details.text:SetFocusChangeDir(MOVE_RIGHT, self.checkbox_send_screenshot.button)
	if self.send_btn:IsEnabled() then
		self.details.text:SetFocusChangeDir(MOVE_DOWN, self.send_btn)
	else
		self.details.text:SetFocusChangeDir(MOVE_DOWN, self.cancel_btn)
	end

	self.subject.text:SetFocusChangeDir(MOVE_DOWN, self.category_type)

	self.category_type:SetFocusChangeDir(MOVE_DOWN, self.details.text)
	self.category_type:SetFocusChangeDir(MOVE_UP, self.subject.text)

	self.details.text:SetFocusChangeDir(MOVE_UP, self.category_type)

	self.category_type:SetFocusChangeDir(MOVE_RIGHT, self.checkbox_send_screenshot.button)
	self.subject.text:SetFocusChangeDir(MOVE_RIGHT, self.checkbox_send_screenshot.button)

end

function FeedbackScreen:OnBecomeActive()
	FeedbackScreen._base.OnBecomeActive(self)
	self.subject.text:SetFocus()
end

function FeedbackScreen:OnUpdate()
	if self.active then
		SetPause(true)
	end
end

return FeedbackScreen
