local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local UIAnim = require("widgets/uianim")
local UIAnimButton = require("widgets/uianimbutton")

local TEMPLATES = require("widgets/redux/templates")

require("util")
local BALATRO_UTIL = require("prefabs/balatro_util")

local DISCARD_REQUEST_TIMEOUT = 1.5

local colors ={
    {  0/255,   0/255,   0/255}, -- spades
    {171/255,  64/255,  61/255}, -- hearts
    {  0/255,  95/255,  15/255}, -- clubs
    { 25/255, 135/255, 195/255}, -- diamonds
}
local MULTSND ={
    0.15,
    0.25,
    0.35,
    0.45,
    0.55,
    0.65,
    0.75,
}

local SUITS = {
    SPADES = 1,
    HEARTS = 2,
    CLUBS = 3,
    DIAMONDS = 4,
}

local hands = {
    STRINGS.BALATRO.HANDS.HIGHCARD,
    STRINGS.BALATRO.HANDS.PAIR,
    STRINGS.BALATRO.HANDS.TWOPAIR,
    STRINGS.BALATRO.HANDS.THREEOFKIND,
    STRINGS.BALATRO.HANDS.STRAIT,
    STRINGS.BALATRO.HANDS.FLUSH,
    STRINGS.BALATRO.HANDS.FULLHOUSE,
    STRINGS.BALATRO.HANDS.FOUROFAKIND,
    STRINGS.BALATRO.HANDS.STRAITFLUSH,
    STRINGS.BALATRO.HANDS.ROYALFLUSH,
}

local jokers = {}

jokers["wilson"] = {name="wilson", desc=STRINGS.BALATRO.JOKER_WILSON }
jokers["wathgrithr"] = {name="wathgrithr", desc=STRINGS.BALATRO.JOKER_WIGFRID }
jokers["wanda"] = {name="wanda", desc=STRINGS.BALATRO.JOKER_WANDA }
jokers["wormwood"] = {name="wormwood", desc=STRINGS.BALATRO.JOKER_WORMWOOD }
jokers["walter"] = {name="walter", desc=STRINGS.BALATRO.JOKER_WALTER }
jokers["waxwell"] = {name="waxwell", desc=STRINGS.BALATRO.JOKER_MAXWELL } -- each discarded heart +1 mult
jokers["wickerbottom"] = {name="wickerbottom", desc=STRINGS.BALATRO.JOKER_WICKERBOTTOM  } -- each queen +2 mult
jokers["wx78"] = {name="wx78", desc=STRINGS.BALATRO.JOKER_WX78 }-- each card kept once then discarded +2 mult
jokers["willow"] = {name="willow", desc=STRINGS.BALATRO.JOKER_WILLOW }
jokers["wolfgang"] = {name="wolfgang", desc=STRINGS.BALATRO.JOKER_WOLFGANG }
jokers["woodie"] = {name="woodie", desc=STRINGS.BALATRO.JOKER_WOODIE }
jokers["webber"] = {name="webber", desc=STRINGS.BALATRO.JOKER_WEBBER, textsize=18 } -- for each heart or diamond replaced by a club or spade +2 mult
jokers["wendy"] = {name="wendy", desc=STRINGS.BALATRO.JOKER_WENDY, textsize=18 } -- discards that becomes same suit +3 mult
jokers["wes"] = {name="wes", desc=STRINGS.BALATRO.JOKER_WES } -- hand is worse after discard +30 chips
jokers["winona"] = {name="winona", desc=STRINGS.BALATRO.JOKER_WINONA } -- each heart kept +1 mult
jokers["warly"] = {name="warly", desc=STRINGS.BALATRO.JOKER_WARLY, textsize=18 }
jokers["wortox"] = {name="wortox", desc=STRINGS.BALATRO.JOKER_WORTOX, textsize=18 }
jokers["wurt"] =  {name="wurt", desc=STRINGS.BALATRO.JOKER_WURT }


local JOKER_SCALE = 0.7

-------------------------------------------------------------------------------------------------------
local BalatroWidget = Class(Widget, function(self, owner, parentscreen, target, jokers, cards)
    Widget._ctor(self, "BalatroWidget")

    self.root = self:AddChild(Widget("root"))
    self.owner = owner
    self.target = target
    self.parentscreen = parentscreen -- NOTES(JBK): Set self.parentscreen.solution for each thing changed in this game widget.
    self.discard = {}
    self.joker_choice = nil
    self.joker_choice_id = nil
    self.round = 1

    self._score = nil

    self.chips = 0
    self.mult = 0

    self.slots = {}
    self.newslots = nil
    self.jokerchoices = jokers

    self.joker = "waxwell"

    self.queue = {}

    for i, card_id in ipairs(cards) do
        self.slots[i] = BALATRO_UTIL.AVAILABLE_CARDS[card_id]
    end

    self.root.bg = self.root:AddChild(UIAnim())
    self.root.bg:GetAnimState():SetBuild("ui_balatro")
    self.root.bg:GetAnimState():SetBank("ui_balatro")
    self.root.bg:GetAnimState():PlayAnimation("joker_idle", true)
    self.root.bg:SetPosition(150,-40,0)

    self.mode = "joker"
    ------
    self.root.notes = self.root:AddChild(ImageButton("images/balatro.xml", "button_normal.tex",  "button_focus.tex", "button_disabled.tex", "button_normal.tex", "button_focus.tex",{0.7,0.7,0.7}))
    self.root.notes:SetPosition(15,-230,0)
    self.root.notes:SetScale(1)
    self.root.notes:SetTextSize(25)
    self.root.notes:SetOnClick( function()
        if not self.root.game_notes.showing then
            self.root.game_notes:MoveToFront()
            self.root.game_notes:Show()
            self.root.game_notes.showing = true
        else
            self.root.game_notes:Hide()
            self.root.game_notes.showing = false
        end
    end )
    self.root.notes:SetNormalScale(0.7,0.7,0.7)
    self.root.notes:SetFocusScale(0.75,0.75,0.75)
    self:settextwithcontroll(self.root.notes, STRINGS.BALATRO.BUTTON_NOTES, CONTROL_MENU_MISC_2)

    ------

    self.root.deal = self.root:AddChild(ImageButton("images/balatro.xml", "button_normal.tex",  "button_focus.tex", "button_disabled.tex", "button_normal.tex", "button_focus.tex",{0.7,0.7,0.7}))
    self.root.deal:SetPosition(148,-230,0)
    self.root.deal:SetScale(1)
    self.root.deal:SetTextSize(25)
    self.root.deal:SetOnClick( function()
        if self.mode == "deal" then
            self:EnableDealButton(false)
            self:Deal()
        else
            self:choose()
        end
    end )
    self.root.deal:SetNormalScale(0.7,0.7,0.7)
    --self.root.deal:SetFocusScale(0.75,0.75,0.75)
    self.root.deal:SetFocusScale(0.7,0.7,0.7)
    self.root.deal:Disable()
    self:settextwithcontroll(self.root.deal, STRINGS.BALATRO.BUTTON_CHOOSE, CONTROL_ACCEPT)

    ------
    self.root.close = self.root:AddChild(ImageButton("images/balatro.xml", "button_normal.tex",  "button_focus.tex", "button_disabled.tex", "button_normal.tex", "button_focus.tex",{0.7,0.7,0.7}))
    self.root.close:SetPosition(280,-230,0)
    self.root.close:SetScale(1)
    self.root.close:SetTextSize(25)
    self.root.close:SetOnClick( function()
        self.root.joker_name:Hide()
        self.root.joker:Hide()
        self.root.score_head:Hide()
        self.root.score:Hide()
        self.root.mult_head:Hide()
        self.root.mult:Hide()
        self.root.chips_head:Hide()
        self.root.chips:Hide()
        self.root.ex:Hide()
        self.root.game_notes:Hide()

        self.parentscreen:TryToCloseWithAnimations()
    end )
    self.root.close:SetNormalScale(0.7,0.7,0.7)
    self.root.close:SetFocusScale(0.75,0.75,0.75)
    self:settextwithcontroll(self.root.close, STRINGS.BALATRO.BUTTON_CLOSE, CONTROL_CANCEL)




    self.root.machine = self.root:AddChild(UIAnim())
    self.root.machine:GetAnimState():SetBuild("balatro_machine")
    self.root.machine:GetAnimState():SetBank("balatro_machine")
    self.root.machine:GetAnimState():PlayAnimation("idle", true)
    self.root.machine:SetScale(0.7)
    self.root.machine:SetPosition(-200,-250,0)
    self.root.machine:GetAnimState():Hide("LEVER")

    for i=1,5 do
        self.root.machine:GetAnimState():OverrideSymbol("swap_card"..i, "balatro_machine", "null")
        self.root.machine:GetAnimState():OverrideSymbol("swap_suit"..i, "balatro_machine", "null")
        self.root.machine:GetAnimState():OverrideSymbol("swap_number"..i, "balatro_machine", "null")
    end

    local card_y = 550
    local card_pos = {
        {-195,card_y},
        {-95,card_y},
        {5,card_y},
        {105,card_y},
        {202,card_y},
    }

    local createdcard = function(i)
        local card = self.root.machine:AddChild(UIAnimButton("balatro_machine", "balatro_machine", "card_idle", "card_idle", "card_idle", "card_idle", "card_idle" ))
        card:SetPosition(card_pos[i][1],card_pos[i][2],0)

        card.uianim:GetAnimState():OverrideSymbol("swap_card1", "balatro_machine", "null")
        card.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        card.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        card:Hide()
        card:SetOnClick( function()
            if self.discard[i] then
                self:UnmarkForDiscard(i)
            else
                self:MarkForDiscard(i)
            end
        end )
        card:Disable()

        return card
    end

    self.root.machine.card1 = createdcard(1)
    self.root.machine.card2 = createdcard(2)
    self.root.machine.card3 = createdcard(3)
    self.root.machine.card4 = createdcard(4)
    self.root.machine.card5 = createdcard(5)

    self.root.machine.frame = self.root.machine:AddChild(UIAnim())
    self.root.machine.frame:GetAnimState():SetBuild("balatro_machine")
    self.root.machine.frame:GetAnimState():SetBank("balatro_machine")
    self.root.machine.frame:GetAnimState():PlayAnimation("frame_idle", true)

    local createbuttontext = function(i)
        local text = self.root.machine:AddChild(Text(NUMBERFONT, 40, TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_ACCEPT) , UICOLOURS.WHITE))
        text:SetPosition(card_pos[i][1],card_pos[i][2]-70,0)
        text:Hide()
        return text
    end

    self.root.machine.buttontext1 = createbuttontext(1)
    self.root.machine.buttontext2 = createbuttontext(2)
    self.root.machine.buttontext3 = createbuttontext(3)
    self.root.machine.buttontext4 = createbuttontext(4)
    self.root.machine.buttontext5 = createbuttontext(5)

    self.root.speech= self.root.bg:AddChild(Text(HEADERFONT, 25, "", UICOLOURS.BLACK))
    self.root.speech:SetPosition(0,-100)
    self.root.speech:SetSize(20)

    self.root.chips_head= self.root.bg:AddChild(Text(NUMBERFONT, 25, "CHIPS", UICOLOURS.WHITE))
    self.root.chips_head:SetPosition(-143,57)
    self.root.chips_head:SetSize(25)
    self.root.chips= self.root.bg:AddChild(Text(NUMBERFONT, 25, "0", UICOLOURS.WHITE))
    self.root.chips:SetPosition(-143,10)
    self.root.chips:SetSize(40)
    self.root.chips:Hide()
    self.root.chips_head:Hide()

    self.root.mult_head= self.root.bg:AddChild(Text(NUMBERFONT, 25, "MULT", UICOLOURS.WHITE))
    self.root.mult_head:SetPosition(-10,57)
    self.root.mult_head:SetSize(25)
    self.root.mult= self.root.bg:AddChild(Text(NUMBERFONT, 25, "0", UICOLOURS.WHITE))
    self.root.mult:SetPosition(-10,10)
    self.root.mult:SetSize(40)
    self.root.mult_head:Hide()
    self.root.mult:Hide()

    self.root.ex= self.root.bg:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    self.root.ex:SetPosition(-76,10)
    self.root.ex:SetSize(30)

    self.root.score_head= self.root.bg:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    self.root.score_head:SetPosition(120,57)
    self.root.score_head:SetSize(25)
    self.root.score= self.root.bg:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    self.root.score:SetPosition(120,10)
    self.root.score:SetSize(40)
    self.root.score_head:Hide()
    self.root.score:Hide()

    self.root.joker_name = self.root.bg:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    self.root.joker_name:SetVAlign(ANCHOR_TOP)
    self.root.joker_name:SetSize(25)

    self.root.joker= self.root.bg:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    self.root.joker:SetVAlign(ANCHOR_TOP)
    self.root.joker:EnableWordWrap(true)
    self.root.joker:SetRegionSize(280,120)

    self.root.joker:SetSize(25)

    table.insert(self.queue,{time=2*FRAMES, fn=function()
        self.root.machine.card1:Show()
        self.root.machine.card1.uianim:GetAnimState():ClearOverrideSymbol("swap_card1")
        self.root.machine.card1.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        self.root.machine.card1.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        self.root.machine.card1.uianim:GetAnimState():PlayAnimation("card_draw")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
    end})
    table.insert(self.queue,{time=2*FRAMES, fn=function()
        self.root.machine.card2:Show()
        self.root.machine.card2.uianim:GetAnimState():ClearOverrideSymbol("swap_card1")
        self.root.machine.card2.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        self.root.machine.card2.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        self.root.machine.card2.uianim:GetAnimState():PlayAnimation("card_draw")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
    end})
    table.insert(self.queue,{time=2*FRAMES, fn=function()
        self.root.machine.card3:Show()
        self.root.machine.card3.uianim:GetAnimState():ClearOverrideSymbol("swap_card1")
        self.root.machine.card3.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        self.root.machine.card3.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        self.root.machine.card3.uianim:GetAnimState():PlayAnimation("card_draw")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
    end})
    table.insert(self.queue,{time=2*FRAMES, fn=function()
        self.root.machine.card4:Show()
        self.root.machine.card4.uianim:GetAnimState():ClearOverrideSymbol("swap_card1")
        self.root.machine.card4.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        self.root.machine.card4.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        self.root.machine.card4.uianim:GetAnimState():PlayAnimation("card_draw")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
    end})
    table.insert(self.queue,{time=2*FRAMES, fn=function()
        self.root.machine.card5:Show()
        self.root.machine.card5.uianim:GetAnimState():ClearOverrideSymbol("swap_card1")
        self.root.machine.card5.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        self.root.machine.card5.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        self.root.machine.card5.uianim:GetAnimState():PlayAnimation("card_draw")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
    end})

    self:JimboTalk(STRINGS.BALATRO.JIMBO_CHOOSE_JOKER)

    BALATRO_UTIL.SetAnimState(self.root.machine.frame.inst, self.root.machine.frame:GetAnimState())
    BALATRO_UTIL.SetLightMode_Idle(self.root.machine.frame.inst)

    self.root.game_notes = self.root:AddChild(UIAnim())
    self.root.game_notes:GetAnimState():SetBuild("ui_balatro")
    self.root.game_notes:GetAnimState():SetBank("ui_balatro")
    self.root.game_notes:GetAnimState():PlayAnimation("green_idle", true)
    self.root.game_notes:SetPosition(150,-40,0)
    self.root.game_notes:Hide()
    self:setupgamenotes()

    self:StartSelectJoker()

    self:StartUpdating()

    self.onpopupmessage = function(doer, data)
        self:OnPopupMessage(doer, data)
    end

    self.inst:ListenForEvent("client_popupmessage", self.onpopupmessage, self.owner)
end)

function BalatroWidget:OnPopupMessage(doer, data)
    if data.popup ~= POPUPS.BALATRO then
        return
    end

    local args = data ~= nil and data.args or nil

    if args == nil then
        return
    end

    local meesage_id = args[1]

    self.newslots = {}

    if meesage_id == BALATRO_UTIL.POPUP_MESSAGE_TYPE.NEW_CARDS then
        for i=1, #self.slots do
            self.newslots[i] = BALATRO_UTIL.AVAILABLE_CARDS[args[i+1]] -- +1 because arg[1] is the id.
        end

        BALATRO_UTIL.ClientDebugPrint("Received new cards: ", { unpack(args, 2) })

        self:ReceiveDeal()
    end
end

function BalatroWidget:GetFinalScore()
    return self._score
end

function BalatroWidget:calcMultSnd(s)
    if s > 7 then s = 7 end
    return MULTSND[s]
end

function BalatroWidget:settextwithcontroll(wiget,text,control)
    if TheInput:ControllerAttached() then
        wiget:SetText(TheInput:GetLocalizedControl(TheInput:GetControllerID(), control).." "..text)
    else
        wiget:SetText(text)
    end
end

function BalatroWidget:setupgamenotes()

    local txt = STRINGS.BALATRO.NOTES_HANDS .."\n------------------------------\n"
    for i, hand in ipairs(hands)do
        txt = txt ..hand.."\n"
    end
    txt = txt .."------------------------------"

    local texthands = self.root.game_notes:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    texthands:SetString(txt)
    texthands:SetPosition(-80,25)
    texthands:SetHAlign(ANCHOR_LEFT)
    texthands:SetVAlign(ANCHOR_TOP)


    txt = STRINGS.BALATRO.NOTES_MULT .."\n\n"
    for i, hand in ipairs(hands)do
        txt = txt .."+"..i.."\n"
    end
    txt = txt .." "

    local textmult = self.root.game_notes:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    textmult:SetString(txt)
    textmult:SetPosition(0,25)
    textmult:SetHAlign(ANCHOR_RIGHT)
    textmult:SetVAlign(ANCHOR_TOP)


    txt = STRINGS.BALATRO.NOTES_RANKS .."\n---------------\n"
    for i, rank in ipairs(BALATRO_UTIL.SCORE_RANKS)do
        txt = txt ..rank.."\n"
    end
    txt = txt .."---------------"


    local textrank = self.root.game_notes:AddChild(Text(NUMBERFONT, 25, "", UICOLOURS.WHITE))
    textrank:SetString(txt)
    textrank:SetPosition(120,25)
    textrank:SetHAlign(ANCHOR_RIGHT)
    textrank:SetVAlign(ANCHOR_TOP)
end

function BalatroWidget:UnselectJoker(i)
    local pos =  self.root["joker_card"..i]:GetPosition()
    self.root["joker_card"..i]:SetPosition(pos.x,pos.y-30,pos.z)
    self.root["joker_card"..i]:SetScale(JOKER_SCALE * 1,JOKER_SCALE * 1,JOKER_SCALE * 1)
    self.root["joker_card"..i]:Enable()
    self.root["joker_card"..i].selected = nil
    self.joker_choice = nil
    self.joker_choice_id = nil

    self.root.joker:SetString("")
end

function BalatroWidget:SelectJoker(i)

    if not self.root["joker_card"..i].selected then

        self.root.deal:Show()
        self.root.deal:Enable()

        self:settextwithcontroll(self.root.deal,STRINGS.BALATRO.BUTTON_CHOOSE,CONTROL_ACCEPT)

        for t=1,3 do
            if self.root["joker_card"..t].selected and t~=i then
                self:UnselectJoker(t)
            end
        end

        local pos =  self.root["joker_card"..i]:GetPosition()
        self.root["joker_card"..i]:SetPosition(pos.x,pos.y+30,pos.z)
        self.root["joker_card"..i]:SetScale(JOKER_SCALE * 1.2, JOKER_SCALE * 1.2, JOKER_SCALE * 1.2)
        self.root["joker_card"..i]:Disable()
        self.root["joker_card"..i]:MoveToFront()

        self.joker_choice = self.root["joker_card"..i].joker_selected
        self.joker_choice_id = self.root["joker_card"..i].joker_id

        self.root.joker:SetString(self.joker_choice.desc)
        self.root.joker_name:SetString(string.upper(STRINGS.NAMES[string.upper(self.joker_choice.name)]) )

        --[[
        if self.joker_choice.textsize then
            self.root.joker:SetSize(self.joker_choice.textsize)
        else
            self.root.joker:SetSize(25)
        end
        ]]

        self.root["joker_card"..i].selected = true
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
    end
end

--------------------------------------------------------------------------------START SELECT JOKER
function BalatroWidget:StartSelectJoker()
    self.root.bg:GetAnimState():PlayAnimation("joker_open", false)
    self.root.bg:GetAnimState():PushAnimation("joker_idle", true)

    self.root.joker_name:SetPosition(0,55)
    self.root.joker:SetPosition(0,-20)

    local createdcard = function(i)
        local card = self.joker_cards_root:AddChild(UIAnimButton("balatro_machine", "balatro_machine", "card_idle", "card_idle", "card_idle", "card_idle", "card_idle" ))

        card.joker_id = self.jokerchoices[i]
        card.joker_selected = jokers[BALATRO_UTIL.AVAILABLE_JOKERS[card.joker_id]]

        card.uianim:GetAnimState():OverrideSymbol("swap_card1", "balatro_jokers", "joker_"..card.joker_selected.name)
        card.uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
        card.uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
        card:SetOnClick( function()
            if card.selected == true then
                self:UnselectJoker(i)
            else
                self:SelectJoker(i)
            end
        end )

        card.uianim:GetAnimState():SetBuild("balatro_machine")
        card.uianim:GetAnimState():SetBank("balatro_machine")
        card.uianim:GetAnimState():PlayAnimation("card_idle", true)
        card:SetScale(JOKER_SCALE * 1)
        card:SetPosition(80 + (i-1)*100,120,0)
        card:SetRotation(-5 + ((i-1) * 5))
        card:SetOnFocus(function()
            if not card.selected then
                card:SetScale(JOKER_SCALE * 1.1)
            end
            card:MoveToFront()
        end)
        card:SetOnLoseFocus(function()
            if not card.selected then
                card:SetScale(JOKER_SCALE * 1)
                card:MoveToBack()
            end
        end)

        return card
    end

    self.joker_cards_root = self.root:AddChild(Widget("joker_cards_root"))

    for i=1, BALATRO_UTIL.NUM_JOKER_CHOICES do
        self.root["joker_card"..i] = createdcard(i)
    end

    if TheInput:ControllerAttached() then
        --self.focus_forward = self.root.joker_card1
        self:SelectJoker(1)
    end
end

function BalatroWidget:ClearJokerSelection()
    for i=1,3 do
        self.root["joker_card"..i]:Hide()
    end
end

-----------------------------------------------------START DISCARDING

function BalatroWidget:ControllerUnselectCard()
    if self.current_selected_card then
        self.root.machine["card".. self.current_selected_card]:SetScale(1, 1, 1)
        self.root.machine["buttontext".. self.current_selected_card]:Hide()
        self.current_selected_card = nil
    end
end

function BalatroWidget:ControllerSelectCard(card)
    self:ControllerUnselectCard()
    self.root.machine["card"..card]:SetScale(1.1, 1.1, 1.1)
    self.current_selected_card = card
    self.root.machine["buttontext".. self.current_selected_card]:Show()
    TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
end

function BalatroWidget:StartPlayGame()
    self:ClearJokerSelection()
    self.root.bg:GetAnimState():PlayAnimation("joker_close", false)
    self.root.bg:GetAnimState():PushAnimation("bg", true)

    self.root.chips:Show()
    self.root.chips_head:Show()

    self.root.mult_head:Show()
    self.root.mult:Show()

    self.root.score_head:Show()
    self.root.score:Show()

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        self.root.machine["card"..i]:Enable()
    end

    self.mode = "deal"

    local OFFSET = 120

    self.root.joker:SetString(jokers[self.joker].desc)
    self.root.joker:SetPosition(0,-20 +OFFSET)

    self.root.joker_name:SetString(string.upper(STRINGS.NAMES[string.upper(jokers[self.joker].name)]) )
    self.root.joker_name:SetPosition(0,55 +OFFSET)

    self:settextwithcontroll(self.root.deal,STRINGS.BALATRO.BUTTON_SKIP,CONTROL_MENU_MISC_1)

    self.root.joker_card = self.root.bg:AddChild(UIAnim())
    self.root.joker_card:GetAnimState():SetBuild("balatro_machine")
    self.root.joker_card:GetAnimState():SetBank("balatro_machine")
    self.root.joker_card:GetAnimState():PlayAnimation("card_idle", true)
    self.root.joker_card:SetScale(JOKER_SCALE * 1)
    self.root.joker_card:SetPosition(135,230,0)
    self.root.joker_card:SetRotation(12)
    self.root.joker_card:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
    self.root.joker_card:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")

    self.root.joker_card:GetAnimState():OverrideSymbol("swap_card1", "balatro_jokers", "joker_"..self.joker)

    self.focus_forward = self.root.card1

    table.insert(self.queue,{time=3*FRAMES, fn=function()
        self.root.machine.card1.uianim:GetAnimState():PlayAnimation("card_flip")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})
    table.insert(self.queue,{time=6*FRAMES, fn=function()
        self:UpdateCardArt(1)
    end})
    table.insert(self.queue,{time=3*FRAMES, fn=function()
        self.root.machine.card2.uianim:GetAnimState():PlayAnimation("card_flip")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})
    table.insert(self.queue,{time=6*FRAMES, fn=function()
        self:UpdateCardArt(2)
    end})
    table.insert(self.queue,{time=3*FRAMES, fn=function()
        self.root.machine.card3.uianim:GetAnimState():PlayAnimation("card_flip")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})
    table.insert(self.queue,{time=6*FRAMES, fn=function()
        self:UpdateCardArt(3)
    end})
    table.insert(self.queue,{time=3*FRAMES, fn=function()
        self.root.machine.card4.uianim:GetAnimState():PlayAnimation("card_flip")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})
    table.insert(self.queue,{time=6*FRAMES, fn=function()
        self:UpdateCardArt(4)
    end})
    table.insert(self.queue,{time=3*FRAMES, fn=function()
        self.root.machine.card5.uianim:GetAnimState():PlayAnimation("card_flip")
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})
    table.insert(self.queue,{time=9*FRAMES, fn=function()
        self:UpdateCardArt(5)
    end})

    if self.joker == "wanda" then
        self:ScoreWanda_start()
    end

    self:JimboTalk(STRINGS.BALATRO.JIMBO_START)

    table.insert(self.queue,{time=0*FRAMES, fn=function()
        self:EnableDealButton(true)
        self.root.deal:Show()

        if TheInput:ControllerAttached() then
           self:ControllerSelectCard(1)
        end
    end})

end


function BalatroWidget:OpenWithAnimations()
    self.root.bg:GetAnimState():PlayAnimation("open")
    self.root.bg.inst:ListenForEvent("animover", function()

    end)
end

function BalatroWidget:CloseWithAnimations()
    self:StopUpdating()
    self:KillSounds()

    self.root.bg:GetAnimState():PlayAnimation("close")

    self.root.bg.inst:ListenForEvent("animover", function()
        TheFrontEnd:PopScreen(self.parentscreen)
    end)
end


function BalatroWidget:MarkForDiscard(slot)
    self.discard[slot] = true
    local pos =  self.root.machine["card"..slot]:GetPosition()
    self.root.machine["card"..slot]:SetPosition(pos.x,pos.y+10,pos.z)
    self.root.machine["card"..slot].uianim:GetAnimState():SetSymbolMultColour("swap_card1", 0.7, 0.7, 0.7, 1)

    self:settextwithcontroll(self.root.deal, STRINGS.BALATRO.BUTTON_DEAL, CONTROL_MENU_MISC_1)
end

function BalatroWidget:UnmarkForDiscard(slot)
    self.discard[slot] = false
    local pos =  self.root.machine["card"..slot]:GetPosition()
    self.root.machine["card"..slot]:SetPosition(pos.x,pos.y-10,pos.z)
    self.root.machine["card"..slot].uianim:GetAnimState():SetSymbolMultColour("swap_card1", 1, 1, 1, 1)
    local skip = true
    for t=1,5 do
        if self.discard[t] then
            skip = false
            break
        end
    end
    if skip then
        self:settextwithcontroll(self.root.deal, STRINGS.BALATRO.BUTTON_SKIP, CONTROL_MENU_MISC_1)
    end
end

function BalatroWidget:AddMult(amt)
    self.mult = self.mult + amt
    self.root.mult:SetString(self.mult)
end

function BalatroWidget:AddChips(amt)
    self.chips = math.max(0,self.chips + amt)
    self.root.chips:SetString(self.chips)
end

function BalatroWidget:calcrank(score)
   for i=#BALATRO_UTIL.SCORE_RANKS, 1, -1 do
        if score >= BALATRO_UTIL.SCORE_RANKS[i] then
            return i
        end
   end
end

function BalatroWidget:EnableDealButton(set)
    if set then
        self.root.deal:Enable()
        if self.current_selected_card then
            self:ControllerSelectCard(self.current_selected_card)
        end
    else
        self.root.deal:Disable()
        if self.current_selected_card then
            self.root.machine["card".. self.current_selected_card]:SetScale(1, 1, 1)
            self.root.machine["buttontext".. self.current_selected_card]:Hide()
        end
    end
end

function BalatroWidget:choose()
    self._score = 0 -- Started the game.
    self:EnableDealButton(false)
    self:JimboTalk("")
    self.joker = self.joker_choice.name

    BALATRO_UTIL.ClientDebugPrint("Sending joker: ", nil, { self.joker_choice_id })

    POPUPS.BALATRO:SendMessageToServer(self.owner, BALATRO_UTIL.POPUP_MESSAGE_TYPE.CHOOSE_JOKER, self.joker_choice_id)

    self:StartPlayGame()
end

function BalatroWidget:ScoreWarly()
    local set = {}

    for i=1,5 do
        local suit = math.floor(self.slots[i]/100)
        if not set[suit] then
            set[suit] = 0
        end
        set[suit] = set[suit] +1
    end

    if set[1] and set[1] > 0 and
       set[2] and set[2] > 0 and
       set[3] and set[3] > 0 and
       set[4] and set[4] > 0  then
        table.insert(self.queue,{time=0.3, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
        end})

        for s=1,4 do
            table.insert(self.queue,{time=0.5*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
                TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", self:calcMultSnd(s))
                self:AddMult(1)
            end})
        end

        table.insert(self.queue,{time=1})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
        end})

        table.insert(self.queue,{time=1})
    end
end

function BalatroWidget:ScoreWilson()
    local pairs = {}

    local cards = {1,2,3,4,5}

    while #cards > 0 do
        local current = cards[1]
        table.remove(cards,1)

        local currentsuit = math.floor(self.slots[current]/100)
        local currentnum = self.slots[current] - (currentsuit * 100)

        if #cards > 0 then
            for i, testcard in ipairs(cards)do
                local tsuit = math.floor(self.slots[testcard]/100)
                local tnum = self.slots[testcard] - (tsuit * 100)

                if tnum == currentnum then
                    table.insert(pairs,{current,testcard})
                    table.remove(cards,i)
                    break
                end
            end
        end
    end

    if #pairs > 0 then

        for i=1,#pairs do
            table.insert(self.queue,{time=0.3, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
                self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
                self.root.joker_card:SetRotation(15)
                self.root.machine["card"..pairs[i][1]]:SetRotation(15)
                self.root.machine["card"..pairs[i][2]]:SetRotation(15)
            end})

            for s=1,3 do
                table.insert(self.queue,{time=0.5*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
                TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", self:calcMultSnd(s))
                    self:AddMult(1)
                end})
            end

            table.insert(self.queue,{time=1})

            table.insert(self.queue,{time=0, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
                self.root.joker_card:SetScale(JOKER_SCALE * 1)
                self.root.joker_card:SetRotation(12)
                self.root.machine["card"..pairs[i][1]]:SetRotation(0)
                self.root.machine["card"..pairs[i][2]]:SetRotation(0)
            end})

            table.insert(self.queue,{time=1})
        end
    end
end

function BalatroWidget:ScoreWanda_start()

    table.insert(self.queue,{time=0.3, fn=function()
        self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
        self.root.joker_card:SetRotation(15)
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
    end})

    for s=1,80 do
        table.insert(self.queue,{time=0.3*FRAMES, fn=function()
            self:AddChips(1)
        end})
    end

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():KillSound("LP")
    end})

    table.insert(self.queue,{time=1})

    table.insert(self.queue,{time=0, fn=function()
        self.root.joker_card:SetScale(JOKER_SCALE * 1)
        self.root.joker_card:SetRotation(12)
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})

end

function BalatroWidget:ScoreWanda_discard(card)

    table.insert(self.queue,{time=0.3, fn=function()
        self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
        self.root.joker_card:SetRotation(15)
        self.root.machine["card"..card]:SetRotation(15)
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
    end})

    for s=1,15 do
        table.insert(self.queue,{time=0.3*FRAMES, fn=function()
            self:AddChips(-1)
        end})
    end

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():KillSound("LP")
    end})

    table.insert(self.queue,{time=1})

    table.insert(self.queue,{time=0, fn=function()
        self.root.joker_card:SetScale(JOKER_SCALE * 1)
        self.root.joker_card:SetRotation(12)
        self.root.machine["card"..card]:SetRotation(0)
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})

end

function BalatroWidget:ScoreWigfrid(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)
    if suit == SUITS.SPADES then

        table.insert(self.queue,{time=0.3, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,25 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1})

        table.insert(self.queue,{time=0, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWickerbottom(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)
    if num == 12 then

        table.insert(self.queue,{time=0.3, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0.5*FRAMES, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
            TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", 0.05)
            self:AddMult(1)
        end})

        table.insert(self.queue,{time=1})

        table.insert(self.queue,{time=0, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWolfgang(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)
    if num == 13 then

        table.insert(self.queue,{time=0.3, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,25 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1})

        table.insert(self.queue,{time=0, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWx78(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)

    if suit == SUITS.HEARTS then
        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
            TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", 2/10)
        end})

        for s=1,2 do
            table.insert(self.queue,{time=0.5*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
                TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", self:calcMultSnd(s))
                self:AddMult(1)
            end})
        end

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end
function BalatroWidget:ScoreWormwood(card)

    local suit = math.floor(self.slots[card]/100)

    if not self.discard[card] and suit == SUITS.CLUBS then

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,15 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

    end
end

function BalatroWidget:ScoreWinona(card)

    local suit = math.floor(self.slots[card]/100)

    if not self.discard[card] and suit == SUITS.HEARTS then

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0.5*FRAMES, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
            TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", 0.05)
            self:AddMult(1)
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

    end
end

function BalatroWidget:ScoreWendy(card, oldcard)

    local oldsuit = math.floor(oldcard/100)
    local suit = math.floor(self.slots[card]/100)

    if oldsuit == suit then

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})


        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,5 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})


        for s=1,2 do
            table.insert(self.queue,{time=0.5*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
                TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", self:calcMultSnd(s))
                self:AddMult(1)
            end})
        end

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

    end
end

function BalatroWidget:ScoreWebber(card, oldcard)

    local oldsuit = math.floor(oldcard/100)
    local suit = math.floor(self.slots[card]/100)

    if (oldsuit == 2 or oldsuit == 4) and (suit == 1 or suit ==3) then

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        for s=1,2 do
            table.insert(self.queue,{time=0.5*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
                TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", self:calcMultSnd(s))
                self:AddMult(1)
            end})
        end

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

    end
end

function BalatroWidget:ScoreWoodie(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)

    table.insert(self.queue,{time=15*FRAMES, fn=function()
        self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
        self.root.joker_card:SetRotation(15)
        self.root.machine["card"..card]:SetRotation(15)
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
    end})

    for s=1,7 do
        table.insert(self.queue,{time=0.3*FRAMES, fn=function()
            self:AddChips(1)
        end})
    end

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():KillSound("LP")
    end})

    table.insert(self.queue,{time=1*FRAMES})

    table.insert(self.queue,{time=0*FRAMES, fn=function()
        self.root.joker_card:SetScale(JOKER_SCALE * 1)
        self.root.joker_card:SetRotation(12)
        self.root.machine["card"..card]:SetRotation(0)
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
    end})
end

function BalatroWidget:ScoreWortox_deal(card)
    local suit = math.floor(self.slots[card]/100)
    if suit ==  SUITS.HEARTS then
        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,15 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWortox_hand(card)
    local suit = math.floor(self.slots[card]/100)
    if suit ==  SUITS.HEARTS then
        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,11 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(-1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=0.5*FRAMES, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
            TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", 0.05)
            self:AddMult(1)
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWillow(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)
    if num > 10 then

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,20 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()

            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreMaxwell(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)
    if suit == SUITS.HEARTS then

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=0.5*FRAMES, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
            TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", 0.05)
            self:AddMult(1)
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWes()

    for card=1,5 do
        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end

    table.insert(self.queue,{time=15*FRAMES})

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
    end})

    for s=1,30 do
        table.insert(self.queue,{time=0.3*FRAMES, fn=function()
            self:AddChips(1)
        end})
    end

    table.insert(self.queue,{time=0, fn=function()
        TheFrontEnd:GetSound():KillSound("LP")
    end})

    table.insert(self.queue,{time=1*FRAMES})

    for card=1,5 do
        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})
    end
end

function BalatroWidget:ScoreWurt(card)
    local suit = math.floor(self.slots[card]/100)
    local num = self.slots[card] - (suit * 100)

    if num > 10 and not self.discard[card] then
        local facecards = 0

        for i=1, 5 do
            local tsuit = math.floor(self.slots[i]/100)
            local tnum = self.slots[i] - (tsuit * 100)

            if tnum > 10 and not self.discard[i] then
                facecards = facecards +1
            end
        end

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
            self.root.joker_card:SetRotation(15)
            self.root.machine["card"..card]:SetRotation(15)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

        table.insert(self.queue,{time=15*FRAMES})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,facecards*10 do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1*FRAMES})

        table.insert(self.queue,{time=0*FRAMES, fn=function()
            self.root.joker_card:SetScale(JOKER_SCALE * 1)
            self.root.joker_card:SetRotation(12)
            self.root.machine["card"..card]:SetRotation(0)
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
        end})

    end
end

function BalatroWidget:ScoreWalter()

    local suits = {}
    for card=1,5 do
        if self.discard[card] then
            local suit = math.floor(self.slots[card]/100)
            suits[suit] = true
        end
    end
    local suitcount = 0

    for i,suit in pairs(suits)do
        suitcount = suitcount + 1
    end

    if suitcount > 0 then

        for card=1,5 do
            if self.discard[card] then
                table.insert(self.queue,{time=0*FRAMES, fn=function()
                    self.root.joker_card:SetScale(JOKER_SCALE * 1.3)
                    self.root.joker_card:SetRotation(15)
                    self.root.machine["card"..card]:SetRotation(15)
                    TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
                end})
            end
        end

        table.insert(self.queue,{time=15*FRAMES})

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
        end})

        for s=1,15 * suitcount do
            table.insert(self.queue,{time=0.3*FRAMES, fn=function()
                self:AddChips(1)
            end})
        end

        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():KillSound("LP")
        end})

        table.insert(self.queue,{time=1*FRAMES})

        for card=1,5 do
            if self.discard[card] then
                table.insert(self.queue,{time=0*FRAMES, fn=function()
                    self.root.joker_card:SetScale(JOKER_SCALE * 1)
                    self.root.joker_card:SetRotation(12)
                    self.root.machine["card"..card]:SetRotation(0)
                    TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
                end})
            end
        end
    end
end

function BalatroWidget:Deal()
    self:EnableDealButton(false)

    local discarddata = {}

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        discarddata[i] = self.discard[i] == true
    end

    local byte = BALATRO_UTIL.EncodeDiscardData(discarddata)

    if byte > 0 then
        self.waitingtime = 0  -- Only wait for a response if we are expecting one.
    end

    BALATRO_UTIL.ClientDebugPrint("Requesting discard: ", nil, nil, unpack(discarddata))

    -- This needs to be after setting waitingtime.
    POPUPS.BALATRO:SendMessageToServer(self.owner, BALATRO_UTIL.POPUP_MESSAGE_TYPE.DISCARD_CARDS, byte)

    if byte == 0 then
        self:ReceiveDeal() -- We are not waiting for a server response.
    end
end

function BalatroWidget:ReceiveDeal()
    self.waitingtime = nil

    local discarded = false

    local oldhandscore = self:Calchand()

    local wxtracker = {}
    if self.notdiscarded then
        for i=1,5 do
            if self.notdiscarded[i] and self.discard[i] then
                wxtracker[i] = true
            end
        end
    end

    self.notdiscarded = {}
    for i=1,5 do
        if not self.discard[i] then
            self.notdiscarded[i] = true
        end
    end

    if self.joker == "walter" then
        self:ScoreWalter()
    end

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if self.joker == "winona" then
            self:ScoreWinona(i)
        end

        if self.joker == "wormwood" then
            self:ScoreWormwood(i)
        end

        if self.joker == "wurt" then
            self:ScoreWurt(i)
        end

        if self.discard[i] == true then
            discarded = true

            if self.joker == "woodie" then
                self:ScoreWoodie(i)
            end
            if self.joker == "willow" then
                self:ScoreWillow(i)
            end
            if self.joker == "waxwell" then
                self:ScoreMaxwell(i)
            end
            if self.joker == "wortox" then
                self:ScoreWortox_deal(i)
            end
            if self.joker == "wanda" then
                self:ScoreWanda_discard(i)
            end
            if wxtracker[i] and self.joker == "wx78" then
                self:ScoreWx78(i)
            end

            local oldcard = self.slots[i]

            self.slots[i] = self.newslots[i] -- Simulating a draw.

            table.insert(self.queue,{time=11*FRAMES, fn=function()
                self.root.machine["card"..i].uianim:GetAnimState():PlayAnimation("card_discard")
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/discard_HUD")
            end})

            table.insert(self.queue,{time=0*FRAMES, fn=function()
                self.root.machine["card"..i].uianim:GetAnimState():OverrideSymbol("swap_card1", "balatro_machine", "null")
                self.root.machine["card"..i].uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "null")
                self.root.machine["card"..i].uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "null")
                self.root.machine["card"..i].uianim:GetAnimState():PlayAnimation("card_idle")
                self:UnmarkForDiscard(i)
            end})

            table.insert(self.queue,{time=5*FRAMES})

            table.insert(self.queue,{time=11*FRAMES, fn=function()
                self.root.machine["card"..i].uianim:GetAnimState():ClearOverrideSymbol("swap_card1")
                self.root.machine["card"..i].uianim:GetAnimState():PlayAnimation("card_draw")
                self.root.machine["card"..i].uianim:GetAnimState():PushAnimation("card_idle")
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
            end})

            table.insert(self.queue,{time=3*FRAMES, fn=function()
                self.root.machine["card"..i].uianim:GetAnimState():PlayAnimation("card_flip")
                self.root.machine["card"..i].uianim:GetAnimState():PushAnimation("card_idle")
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_flip_HUD")
            end})
            table.insert(self.queue,{time=5*FRAMES, fn=function()
                self:UpdateCardArt(i)
            end})

            if self.joker == "webber" then
                self:ScoreWebber(i, oldcard)
            end

            if self.joker == "wendy" then
                self:ScoreWendy(i, oldcard)
            end
        end
    end

    self.newslots = nil -- Clear this table.

    local newhandscore = self:Calchand()
    if self.joker == "wes" and oldhandscore > newhandscore then
        self:ScoreWes()
    end

    table.insert(self.queue,{time=0*FRAMES, fn=function()
        if self.round < 3 then
            if self.current_selected_card then
                self:ControllerSelectCard(self.current_selected_card)
            end
            self:EnableDealButton(true)
        end
    end})

    self._score = 0 -- Played a hand.

    self.round = self.round + 1
    if self.round == 2 then
        self:settextwithcontroll(self.root.deal, STRINGS.BALATRO.BUTTON_SKIP, CONTROL_MENU_MISC_1)

        self:JimboTalk(STRINGS.BALATRO.JIMBO_DISCARD1)
    elseif self.round == 3 then

        if discarded == true then
            table.insert(self.queue,{time=1*FRAMES})
        end

        for i=1,5 do
            self.root.machine["card"..i].enabled = false
        end
        self:EnableDealButton(false)
        self.root.deal:Disable()

        if self.current_selected_card then
            self.root.machine["card".. self.current_selected_card]:SetScale(1, 1, 1)
        end

        BALATRO_UTIL.SetLightMode_Blink(self.root.machine.frame.inst)

        self:JimboTalk(STRINGS.BALATRO.JIMBO_DISCARD2)

        table.insert(self.queue,{time=1})

        for i=1,5 do
            local suit = math.floor(self.slots[i]/100)
            local num = self.slots[i] - (suit * 100)
            if num == 1 then
                num = 11
            end

            table.insert(self.queue,{time=3*FRAMES, fn=function()
                local pos =  self.root.machine["card"..i]:GetPosition()
                self.root.machine["card"..i]:SetPosition(pos.x,pos.y+10,pos.z)
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
            end})

            table.insert(self.queue,{time=0, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
            end})

            for i=1,num do
                table.insert(self.queue,{time=1*FRAMES, fn=function()
                    self:AddChips(1)
                end})
            end

            table.insert(self.queue,{time=0, fn=function()
                TheFrontEnd:GetSound():KillSound("LP")
            end})

            for i=1,12-num do
                table.insert(self.queue,{time=1*FRAMES})
            end

            if self.joker == "wickerbottom" then
                self:ScoreWickerbottom(i)
            end

            if self.joker == "wolfgang" then
                self:ScoreWolfgang(i)
            end

            if self.joker == "wathgrithr" then
                self:ScoreWigfrid(i)
            end

            if self.joker == "wortox" then
                self:ScoreWortox_hand(i)
            end
        end

        table.insert(self.queue,{time=5*FRAMES, fn=function()
            for i=1,5 do
                local pos =  self.root.machine["card"..i]:GetPosition()
                self.root.machine["card"..i]:SetPosition(pos.x,pos.y-10,pos.z)
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
            end
        end})

        if self.joker == "warly" then
            self:ScoreWarly()
        end

        local hand =  self:Calchand()

        self:JimboTalk(subfmt(STRINGS.BALATRO.JIMBO_HANDMULT, { hand = string.upper(hands[hand]), mult=hand }))

        for i=1,hand do
            table.insert(self.queue,{time=0.7/hand, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/mult_HUD", "mult")
                TheFrontEnd:GetSound():SetParameter("mult", "mult_amt", self:calcMultSnd(i))
                self:AddMult(1)
            end})
        end

        table.insert(self.queue,{time=1.5})

        if self.joker == "wilson" then
            self:ScoreWilson()
        end

        self:JimboTalk(STRINGS.BALATRO.JIMBO_FINALSCORE)

        table.insert(self.queue,{time=1})

        table.insert(self.queue,{time=15*FRAMES, fn=function()
            local score = self.chips * self.mult

            BALATRO_UTIL.ClientDebugPrint("Final numeric score: ", nil, nil, score)

            self._score = self:calcrank(score)

            local printscore = 0

            table.insert(self.queue,{time=0, fn=function()
                self.root.ex:SetString("X")
                self.root.score_head:SetString("SCORE")
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/chips_LP_HUD", "LP")
            end})

            local COUNTS = 5

            for i=1, COUNTS do
                table.insert(self.queue,{time=0.5/COUNTS, fn=function()
                    printscore = math.min(printscore + math.floor(score/COUNTS),score)
                    if i == COUNTS then
                        self.root.score:SetString( score )
                    else
                        self.root.score:SetString( math.max(0,math.min(printscore + math.random(1,10) -5, score)) )
                    end
                end})
            end
            --[[
            for i=1, math.ceil(score/10) do
                table.insert(self.queue,{time=0.1, fn=function()
                    printscore = math.min(printscore + 10,score)
                    if i == math.ceil(score/10) then
                        self.root.score:SetString(  score )
                    else
                        self.root.score:SetString( math.max(0,math.min(printscore + math.random(1,10) -5, score)) )
                    end
                end})
            end
            ]]

            table.insert(self.queue,{time=0, fn=function()
                TheFrontEnd:GetSound():KillSound("LP")
            end})

            table.insert(self.queue,{time=6*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/jingle")
            end})

            table.insert(self.queue,{time=1*FRAMES, fn=function()
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/confetti")
                self.root.machine.frame:Hide()
                self.root.machine:GetAnimState():PlayAnimation("confetti", false)
                self.root.machine:GetAnimState():PushAnimation("idle", true)

                for s=1,5 do
                    self.root.machine["card"..s]:Hide()

                    local suit = math.floor(self.slots[s]/100)
                    local num = self.slots[s] - (suit * 100)
                    self.root.machine:GetAnimState():OverrideSymbol("swap_card"..s, "balatro_machine", "swap_card_front")
                    self.root.machine:GetAnimState():OverrideSymbol("swap_suit"..s, "balatro_machine", "suit"..suit)
                    self.root.machine:GetAnimState():OverrideSymbol("swap_number"..s, "balatro_machine", "number"..num)
                    self.root.machine:GetAnimState():SetSymbolMultColour("swap_suit"..s, colors[suit][1], colors[suit][2], colors[suit][3], 1)
                    self.root.machine:GetAnimState():SetSymbolMultColour("swap_number"..s, colors[suit][1], colors[suit][2], colors[suit][3], 1)
                end

            end})

            table.insert(self.queue,{time=3})

            table.insert(self.queue,{time=0, fn=function()
                self.parentscreen:TryToCloseWithAnimations()
            end})
        end})
    end
end

function BalatroWidget:UpdateCardArt(slot)

    if self.slots[slot] then
        local suit = math.floor(self.slots[slot]/100)
        local num = self.slots[slot] - (suit * 100)
        self.root.machine["card"..slot].uianim:GetAnimState():OverrideSymbol("swap_card1", "balatro_machine", "swap_card_front")
        self.root.machine["card"..slot].uianim:GetAnimState():OverrideSymbol("swap_suit1", "balatro_machine", "suit"..suit)
        self.root.machine["card"..slot].uianim:GetAnimState():OverrideSymbol("swap_number1", "balatro_machine", "number"..num)
        self.root.machine["card"..slot].uianim:GetAnimState():SetSymbolMultColour("swap_suit1", colors[suit][1], colors[suit][2], colors[suit][3], 1)
        self.root.machine["card"..slot].uianim:GetAnimState():SetSymbolMultColour("swap_number1", colors[suit][1], colors[suit][2], colors[suit][3], 1)
    end
end

function BalatroWidget:JimboTalk(st)
    local newstring = ""
    local len = string.len(st)
--[[
    if st ~= "" then
        table.insert(self.queue,{time=0, fn=function()
            TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/jimbo_talk_2D_HUD", "talk")
        end})
    end
    ]]

    for i=1,len do
        newstring = newstring.. string.sub(st,1,1)
        st = string.sub(st,2,string.len(st))

        local forscreen = newstring
        table.insert(self.queue,{time=0.5*FRAMES, fn=function()
            if not self.root.machine:GetAnimState():IsCurrentAnimation("talk1") and not self.root.machine:GetAnimState():IsCurrentAnimation("talk2") and not self.root.machine:GetAnimState():IsCurrentAnimation("talk3") then

                if not TheFrontEnd:GetSound():PlayingSound("talking") then
                    TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/jimbo_talk_2D_HUD", "talking")
                end

                self.root.machine:GetAnimState():PlayAnimation("talk"..math.random(1,3), false)
                self.root.machine:GetAnimState():PushAnimation("idle", true)
            end
            self.root.speech:SetString(forscreen)
        end})
    end
    if newstring == "" then
        self.root.speech:SetString("")
    end
end

function BalatroWidget:OnUpdate(dt)
    if self.waitingtime ~= nil then
        self.waitingtime = self.waitingtime + dt

        if self.waitingtime > DISCARD_REQUEST_TIMEOUT then
            self.waitingtime = nil

            self.parentscreen:TryToCloseWithAnimations()

            BALATRO_UTIL.ClientDebugPrint("Discard request timeout!")
        end
    end

    if #self.queue > 0 then
            if self.queue[1].id then
                print("PROCESS ID",self.queue[1].id)
            end
        if self.queue[1].fn then
            self.queue[1].fn(self)
            self.queue[1].fn = nil
        elseif self.queue[1].time >= 0 then
            self.queue[1].time = self.queue[1].time - dt
        end
        if self.queue[1].time <= 0 then
            table.remove(self.queue,1)
        end
    end

    BALATRO_UTIL.UpdateLoop(self.root.machine.frame.inst, dt)
end

local HIGH_STRAIGHT = {1, 10, 11, 12, 13} -- Already sorted.

function BalatroWidget:Calchand()
    local suit_counts = {}
    local num_counts = {}
    local nums = {}
    local is_flush = true

    local NUM_CARDS = BALATRO_UTIL.NUM_SELECTED_CARDS
    local first_suit = math.floor(self.slots[1]/100)

    -- Count suits and numbers
    for i = 1, NUM_CARDS do
        local suit = math.floor(self.slots[i]/100)
        local num = self.slots[i] % 100

        suit_counts[suit] = (suit_counts[suit] or 0) + 1
        num_counts[num] = (num_counts[num] or 0) + 1

        table.insert(nums, num)

        if suit ~= first_suit then
            is_flush = false
        end
    end

    -- Count pairs, trips, quads
    local _pairs, three_of_kind, four_of_kind = 0, 0, 0
    for num, count in pairs(num_counts) do
        if count == 4 then
            four_of_kind = num
        elseif count == 3 then
            three_of_kind = num
        elseif count == 2 then
            _pairs = _pairs + 1
        end
    end

    -- Sort numbers
    table.sort(nums)

    -- Check straight
    local is_straight = true
    for i = 1, NUM_CARDS - 1 do
        if nums[i + 1] - nums[i] ~= 1 then
            is_straight = false
            break
        end
    end

	-- Check high straight
    local is_royal = true
    for i = 1, NUM_CARDS do
		if nums[i] ~= HIGH_STRAIGHT[i] then
            is_royal = false
            break
        end
    end
	if is_royal then
		is_straight = true
	end

    -- Assign score
    local score
    if is_flush and is_royal then
        score = 10 -- Royal Flush
    elseif is_flush and is_straight then
        score = 9 -- Straight Flush
    elseif four_of_kind ~= 0 then
        score = 8
    elseif three_of_kind ~= 0 and _pairs > 0 then
        score = 7 -- Full House
    elseif is_flush then
        score = 6
    elseif is_straight then
        score = 5
    elseif three_of_kind ~= 0 then
        score = 4
    elseif _pairs >= 2 then
        score = 3
    elseif _pairs == 1 then
        score = 2
    else
        score = 1
    end

    return score
end

function BalatroWidget:OnControl(control, down)
    if BalatroWidget._base.OnControl(self, control, down) then
        return true
    end

    if not down and (control == CONTROL_MENU_BACK or control == CONTROL_CANCEL) then
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        self.parentscreen:TryToCloseWithAnimations()
        return true
    end

    if not down and control == CONTROL_MENU_MISC_2 then
        TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
        self.root.notes:onclick()
        return true
    end

    if self.mode == "joker" and TheInput:ControllerAttached() then
        if self.root.deal:IsEnabled() then
            if not down and control == CONTROL_ACCEPT then
                self:choose()
                return true
            end

            if not down and control == CONTROL_MOVE_RIGHT then
                local joker = nil
                for t=1,3 do
                    if self.root["joker_card"..t].selected then
                        joker = t
                        break
                    end
                end
                joker = math.min(3,joker +1)

                self:SelectJoker(joker)
                return true
            end
            if not down and control == CONTROL_MOVE_LEFT then
                local joker = nil
                for t=1,3 do
                    if self.root["joker_card"..t].selected then
                        joker = t
                        break
                    end
                end
                joker = math.max(1,joker -1)

                self:SelectJoker(joker)
                return true
            end
        end
    end

    if self.mode == "deal" and TheInput:ControllerAttached() then
        if self.root.deal:IsEnabled() then
            if not down and control == CONTROL_MENU_MISC_1 then
                TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
                self:Deal()
                return true
            end

            if not down and control == CONTROL_ACCEPT then
                TheFrontEnd:GetSound():PlaySound("balatro/balatro_cabinet/cards_deal_HUD")
                self.root.machine["card"..self.current_selected_card]:onclick()
                return true
            end

            if not down and control == CONTROL_MOVE_RIGHT then
                local new = math.min(5, self.current_selected_card + 1)
                self:ControllerSelectCard(new)

                return true
            end

            if not down and control == CONTROL_MOVE_LEFT then
                local new = math.max(1, self.current_selected_card - 1)
                self:ControllerSelectCard(new)
                return true
            end
        end
    end

    return false
end

function BalatroWidget:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

    table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.BALATRO.BUTTON_CLOSE)
    table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_2) .. " " .. STRINGS.BALATRO.BUTTON_NOTES)

    if self.root.deal:IsEnabled() then
        if self.mode == "joker" then
            local joker = ""
            for t=1,3 do
                if self.root["joker_card"..t].selected then
                    joker = self.root["joker_card"..t].joker_selected
                    break
                end
            end

            table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT) .. " " .. subfmt(STRINGS.BALATRO.CHOOSE_JOKER, { joker=string.upper(STRINGS.NAMES[string.upper(joker.name)] or "??")} ))
        end

        if self.mode == "deal" then
            local skip = true
            for t=1,5 do
                if self.discard[t] then
                    skip = false
                    break
                end
            end
            if skip then
                table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_1) .. " " .. STRINGS.BALATRO.BUTTON_SKIP)
            else
                table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_1) .. " " .. STRINGS.BALATRO.BUTTON_DEAL)
            end
            if self.discard[self.current_selected_card] then
                table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT) .. " " .. STRINGS.BALATRO.BUTTON_UNDISCARD)
            else
                table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT) .. " " .. STRINGS.BALATRO.BUTTON_DISCARD)
            end
        end
    end

    return table.concat(t, "  ")
end

function BalatroWidget:KillSounds()
    local sound = TheFrontEnd:GetSound()

    if sound ~= nil then
        sound:KillSound("LP")
        sound:KillSound("mult")
        sound:KillSound("talking")
    end
end

return BalatroWidget
