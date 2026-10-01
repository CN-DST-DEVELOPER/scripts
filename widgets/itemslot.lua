local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local ItemSlot = Class(Widget, function(self, atlas, bgim, owner)
    Widget._ctor(self, "ItemSlot")
    self.owner = owner
    self.bgimage = self:AddChild(Image(atlas, bgim))
    self.tile = nil

    self.highlight_scale = 1.3
    self.base_scale = 1
end)

function ItemSlot:LockHighlight()
    if not self.highlight then
        self:ScaleTo(self.base_scale, self.highlight_scale, .125)
        self.highlight = true
    end
end

function ItemSlot:UnlockHighlight()
    if self.highlight then
        if self.big then
            self:ScaleTo(self.base_scale, self.highlight_scale, .125)
        else
            self:ScaleTo(self.highlight_scale, self.base_scale, .125)
        end
        self.highlight = false
    end
end

function ItemSlot:Highlight()
    if not self.big then
        self:ScaleTo(self.base_scale, self.highlight_scale, .125)
        self.big = true
    end
end

function ItemSlot:DeHighlight()
    if self.big then
        if not self.highlight then
            self:ScaleTo(self.highlight_scale, self.base_scale, .25)
        end
        self.big = false
    end
end

function ItemSlot:OnGainFocus()
    self:Highlight()
end

function ItemSlot:OnLoseFocus()
    self:DeHighlight()
end

function ItemSlot:SetTile(tile)
    if self.tile ~= tile then
        if self.tile ~= nil then
            self.tile:Kill()
            self.tile = nil
        end
        if tile ~= nil then
            self.tile = self:AddChild(tile)
            if self.label ~= nil then
                self.label:MoveToFront()
            end
            if self.readonlyvisual ~= nil then
                self.readonlyvisual:MoveToFront()
            end
        end
        if self.ontilechangedfn ~= nil then
            self:ontilechangedfn(tile)
        end
    end
end

function ItemSlot:SetOnTileChangedFn(fn)
    self.ontilechangedfn = fn
end

function ItemSlot:SetBGImage2(atlas, img, tint)
    if atlas ~= nil and img ~= nil then
        if self.bgimage2 ~= nil then
            self.bgimage2:SetTexture(atlas, img)
        else
            self.bgimage2 = self:AddChild(Image(atlas, img))
            if self.tile ~= nil then
                self.tile:MoveToFront()
            end
            if self.label ~= nil then
                self.label:MoveToFront()
            end
            if self.readonlyvisual ~= nil then
                self.readonlyvisual:MoveToFront()
            end
        end
        if tint ~= nil then
            self.bgimage2:SetTint(unpack(tint))
        end
    elseif self.bgimage2 ~= nil then
        self.bgimage2:Kill()
        self.bgimage2 = nil
    end
end

function ItemSlot:SetLabel(msg, colour)
    if msg ~= nil then
        if self.label ~= nil then
            self.label:SetString(msg)
            self.label:SetColour(colour)
        else
            self.label = self:AddChild(Text(NUMBERFONT, 26, msg, colour))
            self.label:SetPosition(3, -36)
        end
    elseif self.label ~= nil then
        self.label:Kill()
        self.label = nil
    end
end

local READONLYCONTAINER_DARKNESS_SCALE = 0.4

function ItemSlot:SetReadOnlyVisuals(enabled)
    if enabled then
        if not self.readonlyvisual then
            self.readonlyvisual = self:AddChild(Image("images/ui.xml", "white.tex"))
            local w, h = self.bgimage:GetSize()
            self.readonlyvisual:SetSize(w, h)
            self.readonlyvisual:SetTint(0, 0, 0, READONLYCONTAINER_DARKNESS_SCALE)
            self.readonlyvisual:SetClickable(false)
        end
    else
        if self.readonlyvisual then
            self.readonlyvisual:Kill()
            self.readonlyvisual = nil
        end
    end
end

return ItemSlot
