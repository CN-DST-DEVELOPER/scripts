require "class"

local TileBG = require "widgets/tilebg"
local InventorySlot = require "widgets/invslot"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local TabGroup = require "widgets/tabgroup"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"

local RecipeTile = Class(Widget, function(self, recipe)
    Widget._ctor(self, "RecipeTile")
    self.img = self:AddChild(Image())
    if GetGameModeProperty("icons_use_cc") then
        self.img:SetEffect("shaders/ui_cc.ksh")
    end
    self:SetClickable(false)
    if recipe ~= nil then
		self:SetRecipe(recipe)
        --self:MakeNonClickable()
    end
end)

--NOTE: keep in sync with ItemTile.sSetImageFromItem
local function SetImageFromRecipe(im, recipe, skin_name, r, g, b)
	r, g, b = r or 1, g or r or 1, b or r or 1

    if skin_name == nil and PREFAB_SKINS_SHOULD_NOT_SELECT[recipe.product] then
        skin_name = GetNextOwnedSkin(recipe.product)
    end
    local skin_custom = nil
    local unlockableskins = TheInventory:GetUnlockableItems()
    if unlockableskins[skin_name] then
        skin_custom = unlockableskins[skin_name].skin_custom
    end
    im:SetTint(r, g, b, 1)
	local layers = recipe.layeredimagefn and recipe.layeredimagefn(skin_name, skin_custom) or nil
	if layers and #layers > 0 then
		local row = layers[1]
		im:SetTexture(row.atlas or GetInventoryItemAtlas(row.image), row.image)
		if row.offset then
			print("WARNING: offset not supported on layer 1 of layered icon.  Recipe = "..recipe.name)
			assert(BRANCH ~= "dev")
		end

		local j = 1

		if #layers > 1 then
			im.layers = im.layers or {}

			for i = 2, #layers do
				row = layers[i]
				local w = im.layers[j]
				if w then
					w:SetTexture(row.atlas or GetInventoryItemAtlas(row.image), row.image)
				else
					w = im:AddChild(Image(row.atlas or GetInventoryItemAtlas(row.image), row.image))
					im.layers[j] = w
				end
				if row.offset then
					w:SetPosition(row.offset)
				else
					w:SetPosition(0, 0, 0)
				end
				w:SetTint(r, g, b, 1)
				j = j + 1
			end
		end

		if im.layers then
			for i = j, #im.layers do
				im.layers[i]:Kill()
				im.layers[i] = nil
			end
		end
	else
		if im.layers then
			for i, v in ipairs(im.layers) do
				v:Kill()
			end
			im.layers = nil
		end
		if skin_name then
			local image = GetSkinInvIconName(skin_name)..".tex"
			local atlas = GetInventoryItemAtlas(image, true) or recipe:GetAtlas()
			im:SetTexture(atlas, image, "default.tex")
		else
			local image = recipe.imagefn and recipe.imagefn() or recipe.image
			im:SetTexture(recipe:GetAtlas(), image, image ~= recipe.image and recipe.image or nil)
		end
	end

	if recipe.fxover then
		if im.fxover then
			im.fxover:MoveToFront()
		else
			im.fxover = im:AddChild(UIAnim())
			im.fxover:SetClickable(false)
			im.fxover:SetScale(0.25)
			im.fxover:GetAnimState():AnimateWhilePaused(false)
		end
		im.fxover:GetAnimState():SetBank(recipe.fxover.bank)
		im.fxover:GetAnimState():SetBuild(recipe.fxover.build)
		im.fxover:GetAnimState():PlayAnimation(recipe.fxover.anim, true)
		im.fxover:GetAnimState():SetMultColour(r, g, b, 1)
	elseif im.fxover then
		im.fxover:Kill()
		im.fxover = nil
	end
end

--static function so we can share it to other files without making it global
RecipeTile.sSetImageFromRecipe = SetImageFromRecipe

function RecipeTile:SetRecipe(recipe)
    self.recipe = recipe
	SetImageFromRecipe(self.img, recipe)
end

function RecipeTile:SetCanBuild(canbuild)
    --[[if canbuild then
        local image = recipe.imagefn ~= nil and recipe.imagefn() or recipe.image
        self.img:SetTexture(self.recipe:GetAtlas(), image, image ~= recipe.image and recipe.image or nil)
        self.img:SetTint(1,1,1,1)
    elseif self.recipe ~= nil and self.recipe.lockedatlas ~= nil then
        self.img:SetTexture(self.recipe.lockedatlas, self.recipe.lockedimage)
    else
        self.img:SetTint(0,0,0,1)
    end]]
end

return RecipeTile
