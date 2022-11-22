
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"


-------------------------------------------------------------------------------
local Wheel = Class(Widget, function(self, name, owner, options)
    Widget._ctor(self, name)

	self.owner = owner

	self.selected_label = self:AddChild(Text(UIFONT, 38, ""))
	self.selected_label:SetPosition(0, 0)
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

	for i, v in ipairs(dataset) do
		v.pos_dir = Vector3(math.sin((i-1) * cell_size_rad), math.cos((i-1) * cell_size_rad), 0)  -- Note: these are rotated 90 degrees so that item 1 is at the top, and the items are clockwise
		v.pos		= v.pos_dir * radius
		v.focus_pos = v.pos_dir * focus_radius

		if v.nestedwheel ~= nil then
			self:SetItems(v.nestedwheel.items, v.nestedwheel.r, v.nestedwheel.f, v.nestedwheel.name)
		end

		local w = self:AddChild(ImageButton( v.atlas, v.normal, v.focus, v.disabled, v.down, v.selected, v.scale, v.offset ))
		
		w:SetImageNormalColour(.8, .8, .8, 1)
		w:SetImageFocusColour( 1, 1, 1, 1)
		w:SetImageDisabledColour(0.7, 0.7, 0.7, 0.7)

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
					self:OnExecute()
					v.execute()
				end
			end
		
		w.ondown = function()
				if self.iscontroller then
					self:StopUpdating()
					for j, k in ipairs(dataset) do
						if i ~= j then
							k.widget:Hide()
						end
					end
				end
			end
		
		w.ongainfocus = function()
				w:MoveTo(v.pos, v.focus_pos, 0.1)
				self.selected_label:SetString(v.label)
				if v.onfocus ~= nil then
					v.onfocus()
				end
			end
			
		w.onlosefocus = function()
				w:MoveTo( v.focus_pos, v.pos, 0.25 )
				self.selected_label:SetString("")
			end
		
		if v.helptext ~= nil then
			w:SetHelpTextMessage(v.helptext)
		end
				
		v.widget = w
		v.widget:Hide()
	end

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
	self.cur_cell_index = 1

	self.selected_label:SetPosition(0, self.activeitems[1].pos.y * -0.5 )

	local selected = self.activeitems[1]
	for i, v in ipairs(self.activeitems) do
		if v.checkenabled == nil or v.checkenabled() then
			v.widget:Enable()
		else
			v.widget:Disable()
		end
		if v.selected then
			selected = v
		end
		v.widget:MoveTo( Vector3(0,0,0), v.pos, 0.25 )
		v.widget:Show()
	end
	if selected ~= nil then
		local focus = selected.widget.enabled and self.iscontroller
		if focus then
			selected.widget:SetFocus()
		end
		selected.widget:MoveTo( Vector3(0,0,0), focus and selected.focus_pos or selected.pos, 0.25,
			function()
				self:SetClickable(true)
				self:Enable()
				if self.iscontroller then
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
		xdir = xdir + TheInput:GetAnalogControlValue(CONTROL_INVENTORY_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_LEFT)
		ydir = ydir + TheInput:GetAnalogControlValue(CONTROL_INVENTORY_UP) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_DOWN)
	end
    local xmag = xdir * xdir + ydir * ydir
    local deadzonesq = 0.3 * 0.3 -- TODO(JBK): Global controller deadzone setting.
	if xmag < deadzonesq then
		return
	end
	xmag = math.sqrt(xmag)
	xdir = xdir / xmag
	ydir = ydir / xmag
	
	local cell_size_rad = CalcCellSize(self.activeitemscount)

	-- intentionally inverted to make life easier
 	local angle =  math.atan2( xdir, ydir ) + cell_size_rad * 0.5
 	local base_angle = angle
	if angle < 0 then
		angle = (2 * math.pi) + angle 
	end

	local cell_index =  math.floor(angle / cell_size_rad) + 1

	if self.cur_cell_index ~= cell_index then
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