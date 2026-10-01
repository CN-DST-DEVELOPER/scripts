
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local UIAnimButton = require("widgets/uianimbutton")
local UIAnim = require("widgets/uianim")

-------------------------------------------------------------------------------
local Wheel = Class(Widget, function(self, name, owner, options)
    Widget._ctor(self, name)

	self.owner = owner

	self.selected_label = self:AddChild(Text(UIFONT, 38, ""))
	self.selected_label:SetPosition(0, 0)
	self.selected_label:SetClickable(false)
	self.items = {}
	self.isopen = false
	self.iscontroller = false
	if options ~= nil then
		self.ignoreleftstick = options.ignoreleftstick
		self.ignorerightstick = options.ignorerightstick
	end
end)

function Wheel:IsOpen()
	return self.isopen
end

local function CalcCellSize( dataset_count )
	return math.rad(360 / dataset_count)
end

-------------------------------------------------------------------------------
-- dataset_name (optional): this is only optional for the root dataset, if there are nested datasets, then you must specify this for the nested ones.
--
local function SetUIAnimButtonData(w, fn, data)
	if data then
		fn(w, data.anim, data.loop)
	end
end

function Wheel:SetItems( dataset, radius, focus_radius, dataset_name )
	dataset_name = dataset_name or "root"

	if self.items[dataset_name] ~= nil then
		for i, v in ipairs(self.items[dataset_name]) do
			if v.widget ~= nil then
				v.widget:Kill()
				v.widget = nil
			end
		end
	end

	self.items[dataset_name] = dataset

	local cell_size_rad = CalcCellSize(#dataset)

	self.numspacers = 0

	for i, v in ipairs(dataset) do
		v.pos_dir = Vector3(math.sin((i-1) * cell_size_rad), math.cos((i-1) * cell_size_rad), 0)  -- Note: these are rotated 90 degrees so that item 1 is at the top, and the items are clockwise
		v.pos		= v.pos_dir * radius
		v.focus_pos = v.pos_dir * focus_radius

		if v.nestedwheel ~= nil then
			self:SetItems(v.nestedwheel.items, v.nestedwheel.r, v.nestedwheel.f, v.nestedwheel.name)
		end

		local w
		if v.anims then
			w = self:AddChild(UIAnimButton(v.bank, v.build))
			w.animstate:Hide("mouseover")
			w.overrideclicksound = v.clicksound
			--helpers to basically do this:
			--    w:SetIdleAnim(v.anims.idle.anim, v.anims.idle.anim.loop)
			--(except the anim data might be nil!!!)
			SetUIAnimButtonData(w, w.SetIdleAnim, FunctionOrValue(v.anims.idle, self.owner))
			SetUIAnimButtonData(w, w.SetFocusAnim, FunctionOrValue(v.anims.focus, self.owner))
			SetUIAnimButtonData(w, w.SetDisabledAnim, FunctionOrValue(v.anims.disabled, self.owner))
			SetUIAnimButtonData(w, w.SetDownAnim, FunctionOrValue(v.anims.down, self.owner))
			SetUIAnimButtonData(w, w.SetSelectedAnim, FunctionOrValue(v.anims.selected, self.owner))

			if v.checkcooldown then
				w.cooldown = w:AddChild(UIAnim())
				w.cooldown:SetClickable(false)
				w.cooldown:GetAnimState():SetBank(v.bank)
				w.cooldown:GetAnimState():SetBuild(v.build)
				if v.cooldowncolor then
					w.cooldown:GetAnimState():SetMultColour(unpack(v.cooldowncolor))
				end
				w.cooldown:Hide()
			end
		else
			w = self:AddChild(ImageButton(v.atlas, v.normal, v.focus, v.disabled, v.down, v.selected, v.scale, v.offset))
			w:SetImageNormalColour(.8, .8, .8, 1)
			w:SetImageFocusColour( 1, 1, 1, 1)
			w:SetImageDisabledColour(0.7, 0.7, 0.7, 0.7)
		end
		
		if v.widget_scale ~= nil then
			w:SetScale(v.widget_scale)
		end
		if v.hit_radius ~= nil then
			w.image:SetRadiusForRayTraces(v.hit_radius)
		end

		w.onclick = function()
				if v.nestedwheel ~= nil then
					self:Close()
					self:Open(v.nestedwheel.name)
				elseif v.execute then
					if v.execute() then
						return --callback returned true: halt operation
					end
					self:OnExecute()
				end
			end
		
		w.ondown = function()
				if v.ondown and v.ondown() then
					return --callback returned true: halt operation
				elseif self.iscontroller then
					self:StopUpdating()
					for j, k in ipairs(dataset) do
						if i ~= j then
							k.widget:Hide()
						end
					end
				end
			end
		
		w.ongainfocus = function()
				if w:IsEnabled() and not (w:IsSelected() or w:IsDisabledState()) then
					if v.onfocus and v.onfocus() then
						return --callback returned true: halt operation
					end
					w:MoveTo(v.pos, v.focus_pos, 0.1)
					self.selected_label:SetString(v.label)
					self.selected_label._currentwidget = w

					local offset = Vector3(0,50,0)
					local newpos = v.pos + offset
					local newfocuspos = v.focus_pos + offset

					self.selected_label:MoveTo(newpos, newfocuspos, 0.1)
				end
			end
			
		w.onlosefocus = function()
				if w:IsEnabled() and not (w:IsSelected() or w:IsDisabledState()) then
					w:MoveTo( v.focus_pos, v.pos, 0.25 )
				end
				if self.selected_label._currentwidget == w then
					self.selected_label:SetString("")
				end
			end

		if v.helptext ~= nil then
			w:SetHelpTextMessage(v.helptext)
		end
				
		v.widget = w
		v.widget:Hide()

		if v.postinit then
			v.postinit(w)
		end

		if v.spacer then
			self.numspacers = self.numspacers + 1
		end
	end

	self.selected_label:MoveToFront()
	self:Hide()

	self.cur_cell_index = 0
	self.isopen = false
	
	self.activeitems = dataset
	self.activeitemscount = #dataset
end

-------------------------------------------------------------------------------
-- dataset_name (optional): if nil, will open the first dataset passed in
--
function Wheel:Open(dataset_name)
	self.activeitems = self.items[dataset_name or "root"]
	if self.activeitems == nil then
		return
	end

	self.activeitemscount = #self.activeitems
	if self.activeitemscount == 0 then
		return
	end

	self.isopen = true
	self.iscontroller = TheInput:ControllerAttached()

	if self.iscontroller then
		TheFrontEnd:LockFocus(true)
		self:SetFocus()
	end

	self:Show()
	self:Disable()
	self:SetClickable(false)
	self.cur_cell_index = 0

	self.selected_label:SetPosition(0, 0)
	self.selected_label:SetString("")
	self.selected_label._currentwidget = nil

	local selected
	for i, v in ipairs(self.activeitems) do
		local disabled = v.checkenabled and not v.checkenabled(self.owner)
		if v.checkcooldown and v.anims then --cooldowns only supported with anims
			SetUIAnimButtonData(v.widget, v.widget.SetDisabledAnim, disabled and FunctionOrValue(v.anims.disabled, self.owner) or FunctionOrValue(v.anims.cooldown, self.owner))
			v.widget.cooldown.OnUpdate = function(cooldown, dt, forceinit)
				local cd = v.checkcooldown(self.owner)
				if cd then
					if forceinit or v.widget.enabled then
						v.widget:Disable()
					end
					if self.cur_cell_index == i then
						self.cur_cell_index = 0
					end
					cooldown:GetAnimState():SetPercent("cooldown", math.clamp(1 - cd, 0, 1))
					cooldown:Show()
				else
					if disabled then
						if forceinit or v.widget.enabled then
							v.widget:Disable()
						end
						if self.cur_cell_index == i then
							self.cur_cell_index = 0
						end
					elseif forceinit or not v.widget.enabled then
						v.widget:Enable()
					end
					cooldown:Hide()
				end
			end
			v.widget.cooldown:StartUpdating()
			v.widget.cooldown:OnUpdate(0, true)
		elseif disabled then
			if v.anims then
				SetUIAnimButtonData(v.widget, v.widget.SetDisabledAnim, FunctionOrValue(v.anims.disabled, self.owner))
			end
			v.widget:Disable()
		else
			v.widget:Enable()
		end
		if (v.selected or selected == nil) and v.widget.enabled then
			selected = v
			self.cur_cell_index = i
		end
		v.widget:MoveTo( Vector3(0,0,0), v.pos, 0.25 )
		v.widget:Show()
	end
	if selected ~= nil then
		selected.widget:MoveTo(Vector3(0,0,0), self.iscontroller and not selected.widget:IsDisabledState() and selected.focus_pos or selected.pos, 0.25,
			function()
				self:SetClickable(true)
				self:Enable()
				if self.iscontroller then
					if not selected.widget:IsDisabledState() then
						selected.widget:SetFocus()
					elseif self.activeitems[self.cur_cell_index] == selected then
						self.cur_cell_index = 0
					end
					self:StartUpdating()
				end
			end)
	end
end

-------------------------------------------------------------------------------
function Wheel:Close()
	if not self.isopen then
		return
	end

	self:StopUpdating()

	if self.cur_cell_index > 0 then
		if self.owner.HUD.last_focus == self.activeitems[self.cur_cell_index].widget then
			self.owner.HUD.last_focus = nil
		end

		self.activeitems[self.cur_cell_index].widget:ClearFocus()
		self.cur_cell_index = 0
	end
	
	for i, v in ipairs(self.activeitems) do
		if v.widget.cooldown then
			v.widget.cooldown:StopUpdating()
		end
		v.widget:CancelMoveTo()
		v.widget:Hide()
	end
	self:SetClickable(true)
	self:ClearFocus()
	self:Disable()
	self:Hide()
	self.isopen = false
	TheFrontEnd:LockFocus(false)
end

-------------------------------------------------------------------------------
function Wheel:OnUpdate(dt)
	if not self.iscontroller then
		return -- Mouse will rely on hovering on the buttons and not a pie slice.
	end

    local xdir, ydir = 0, 0
	if not self.ignoreleftstick then
		xdir = xdir + TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
		ydir = ydir + TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
	end
	if not self.ignorerightstick then
		--V2C: wheel ignores CONTROL_CAM_AND_INV_MODIFIER by not using the virtual controls
		xdir = xdir + TheInput:GetAnalogControlValue(CONTROL_PRESET_RSTICK_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_PRESET_RSTICK_LEFT)
		ydir = ydir + TheInput:GetAnalogControlValue(CONTROL_PRESET_RSTICK_UP) - TheInput:GetAnalogControlValue(CONTROL_PRESET_RSTICK_DOWN)
	end
	local magsq = math.min(1, xdir * xdir + ydir * ydir)
    local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
	if magsq < deadzone * deadzone then
		self.lastmagsq = nil
		return
	elseif self.lastxmagsq and magsq < self.lastmagsq then
		self.lastmagsq = magsq
		return
	end
	self.lastmagsq = magsq

	--V2C: quick implementation of "spacers" only supports:
	--     -same (odd) number of spacers on top and bottom
	--     -they are centered and mirrored, basically splitting the wheel into L/R halves
	assert(self.numspacers <= 0 or (
		bit.band(self.numspacers, 3) == 2 and
		bit.band(self.activeitemscount, 1) == 0
	))
	local non_spacer_count = self.activeitemscount - self.numspacers
	local cell_size_rad = CalcCellSize(non_spacer_count)

	-- intentionally inverted to make life easier
	local angle = math.atan2(xdir, ydir)
	if self.numspacers <= 0 then
		angle = angle + cell_size_rad * 0.5
	end
	if angle < 0 then
		angle = TWOPI + angle 
	end

	local cell_index =  math.floor(angle / cell_size_rad) + 1
	if self.numspacers > 0 then
		local spaceroffset = math.ceil(self.numspacers / 4)
		local halfcount = non_spacer_count / 2
		if cell_index <= halfcount then
			cell_index = cell_index + spaceroffset
		else
			cell_index = cell_index - halfcount + self.activeitemscount / 2 + spaceroffset
		end
	end

	if self.cur_cell_index ~= cell_index and not (cell_index <= self.activeitemscount and self.activeitems[cell_index].noselect) then
		if self.cur_cell_index > 0 then
			self.activeitems[self.cur_cell_index].widget:ClearFocus()
			self.cur_cell_index = 0
		end

		if cell_index > 0 and cell_index <= self.activeitemscount then
			if self.activeitems[cell_index].widget:IsEnabled() then
				self.activeitems[cell_index].widget:SetFocus()
				self.cur_cell_index = cell_index
			end
		end
	end
end

-------------------------------------------------------------------------------
function Wheel:OnControl(control, down)
   	if Wheel._base.OnControl(self, control, down) then return true end

	if not (self.iscontroller and self:IsEnabled()) then return end

    if down then
        if control == CONTROL_CANCEL then
			self:OnCancel()
            return true
        end
	end
end

-------------------------------------------------------------------------------
--Override these

function Wheel:OnCancel()
end

function Wheel:OnExecute()
end

-------------------------------------------------------------------------------
function Wheel:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
   	table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL, false, false ) .. " " .. STRINGS.UI.OPTIONS.CLOSE)	
	return table.concat(t, "  ")
end


-------------------------------------------------------------------------------
return Wheel