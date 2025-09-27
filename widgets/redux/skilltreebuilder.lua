
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local skilltreedefs = require "prefabs/skilltree_defs"
local UIAnim = require "widgets/uianim"

require("util")

local TILESIZE = 32
local TILESIZE_FRAME = TILESIZE + 8
local INFOGRAPHIC_RATIO = 80 / 64 -- frame size / background size
local TILESIZE_INFOGRAPHIC = TILESIZE - 5
local TILESIZE_INFOGRAPHIC_CIRCLE = TILESIZE_INFOGRAPHIC * SQRT2
local TILESIZE_INFOGRAPHIC_FRAME = TILESIZE_INFOGRAPHIC_CIRCLE * INFOGRAPHIC_RATIO - 4 -- Small overlap for icon frame to cover edges.
local LOCKSIZE = 24
local SPACE = 5 

local ATLAS = "images/skilltree.xml"
local IMAGE_LOCKED = "locked.tex"
local IMAGE_LOCKED_OVER = "locked_over.tex"
local IMAGE_UNLOCKED = "unlocked.tex"
local IMAGE_UNLOCKED_OVER = "unlocked_over.tex"

local IMAGE_QUESTION = "question.tex"
local IMAGE_QUESTION_OVER = "question_over.tex"

local IMAGE_SELECTED = "selected.tex"
local IMAGE_SELECTED_OVER = "selected_over.tex"
local IMAGE_UNSELECTED = "unselected.tex"
local IMAGE_UNSELECTED_OVER = "unselected_over.tex"
local IMAGE_SELECTABLE = "selectable.tex"
local IMAGE_SELECTABLE_OVER = "selectable_over.tex"
local IMAGE_X = "locked.tex"
local IMAGE_FRAME = "frame.tex"
local IMAGE_FRAME_LOCK = "frame_octagon.tex"

local IMAGE_INFOGRAPHIC = "infographic.tex"
local IMAGE_INFOGRAPHIC_OVER = "infographic_over.tex"
local IMAGE_INFOGRAPHIC_ON = "infographic_on.tex"
local IMAGE_INFOGRAPHIC_ON_OVER = "infographic_on_over.tex"
local IMAGE_INFOGRAPHIC_OFF = "infographic_off.tex"
local IMAGE_INFOGRAPHIC_OFF_OVER = "infographic_off_over.tex"
local IMAGE_INFOGRAPHIC_FRAME = "frame_infographic.tex"

local TEMPLATES = require "widgets/redux/templates"

local function getSizeOfList(list)
	local size = 0
	for i,entry in pairs(list)do
		size = size+1
	end
	return size
end

local skills = {}

local TILEUNIT = 37

-------------------------------------------------------------------------------------------------------
local SkillTreeBuilder = Class(Widget, function(self, infopanel, fromfrontend, skilltreewidget)
    Widget._ctor(self, "SkillTreeBuilder")

    self.skilltreewidget = skilltreewidget
	self.fromfrontend = fromfrontend
    self.skilltreedef = nil
    self.skillgraphics = {}
    self.buttongrid = {}
    self.infopanel = infopanel
    self.selectedskill = nil
    self.root = self:AddChild(Widget("root"))
    self.root.panels = {}

	self.root.xp = self.root:AddChild(Widget("xp"))
	self.root.xp:SetPosition(3,215) 

	local COLOR = UICOLOURS.BLACK
	if self.fromfrontend then
		COLOR = UICOLOURS.GOLD
	end

    self.root.xpicon = self.root.xp:AddChild(Image("images/skilltree.xml", "skill_icon_textbox_white.tex"))
    self.root.xpicon:SetPosition(0,0)
    self.root.xpicon:ScaleToSize(50,50)
    self.root.xpicon:SetTint(COLOR[1],COLOR[2],COLOR[3],1)

    self.root.xptotal =self.root.xp:AddChild(Text(HEADERFONT, 20, 0, COLOR)) 
    self.root.xptotal:SetPosition(0,-4)

    self.root.xp_tospend = self.root.xp:AddChild(Text(HEADERFONT,15, 0, COLOR))
    self.root.xp_tospend:SetHAlign(ANCHOR_LEFT)  
    self.root.xp_tospend:SetString(STRINGS.SKILLTREE.SKILLPOINTS_TO_SPEND)


    local w, h = self.root.xp_tospend:GetRegionSize()
    self.root.xp_tospend:SetPosition(30+(w/2),-3)

    if not TheSkillTree.synced then
        local msg = not TheInventory:HasSupportForOfflineSkins() and (TheFrontEnd ~= nil and TheFrontEnd:GetIsOfflineMode() or not TheNet:IsOnlineMode()) and STRINGS.SKILLTREE.ONLINE_DATA_USER_OFFLINE or STRINGS.SKILLTREE.ONLINE_DATA_DOWNLOAD_FAILED
        self.sync_status = self.root:AddChild(Text(HEADERFONT, 24, msg, UICOLOURS.GOLD_UNIMPORTANT))
        self.sync_status:SetVAnchor(ANCHOR_TOP)
        self.sync_status:SetHAnchor(ANCHOR_RIGHT)
        local w, h = self.sync_status:GetRegionSize()
        self.sync_status:SetPosition(-w/2 - 2, -h/2 - 2) -- 2 Pixel padding, top right screen justification.
    end

    
end)

local function _ScreenToLocal(x, y, xoffs, yoffs, centerjustifed)
    local w, h = TheSim:GetScreenSize()
    --print("MOUSE",x,y,w,h,RESOLUTION_X, RESOLUTION_Y)
    if w > 0 and h > 0 then
        local propscale = math.max(RESOLUTION_X / w, RESOLUTION_Y / h)

        if centerjustifed then 
        	return (x - w/2) * propscale - xoffs, (y - h / 2) * propscale - yoffs
        else	-- THIS ONE IS RIGHT JUSTIFIED
			return (x - w) * propscale - xoffs, (y - h / 2) * propscale - yoffs
		end
    end
    return 0, 0
end

function SkillTreeBuilder:UpdatePosition(x, y)
	local x1, y1 = 0, 0
	local parent = self.root:GetParent()
	while parent do
		local x2, y2 = parent:GetPositionXYZ()
		x1 = x1 + x2
		y1 = y1 + y2
		parent = parent:GetParent()
	end
	x1, y1 = _ScreenToLocal(x, y, x1, y1, self.fromfrontend)

    local xnew = math.clamp(x1, -230,230 )
    local ynew = math.clamp(y1, -12,213)  

	--print(xnew, ynew)
    if xnew > -230 and xnew < 230 and ynew > -12 and ynew < 213 then
    	self.root.puck.pucktarget = {x=xnew,y=ynew} --root.puck:SetPosition(xnew,ynew,0)
	end
end

function SkillTreeBuilder:PuckFollowMouse()
    if self.followhandler == nil then
        self.followhandler = TheInput:AddMoveHandler(function(x, y) self:UpdatePosition(x, y) end)
        local pos = TheInput:GetScreenPosition()
        self:UpdatePosition(pos.x,pos.y)
    end
end

function SkillTreeBuilder:SpawnPuck()
    self.root.puck = self:AddChild(Image("images/skilltree4.xml", "wendy_puck.tex"))
    self.root.puck.idletime = 0
    self.root.puck.lastpos = {x=0,y=0}
    self.root.puck:SetClickable(false)

  	if TheInput:ControllerAttached() then
  		self.root.puck:SetPosition(0,0,0)  		
  		self:StartUpdating()
    else
    	self:PuckFollowMouse()
    	self:StartUpdating()
    end

    self.root.dialogue = self:AddChild(Text(TALKINGFONT, 32))
    self.root.dialogue:SetPosition(-123,-30)
    self.root.dialogue:SetMultilineTruncatedString(STRINGS.CHARACTERS.WENDY.WENDY_SKILLTREE_EASTEREGG,1, 200, 40, nil, true)
    self.root.dialogue:SetHAlign(ANCHOR_MIDDLE)
    self.root.dialogue:Hide() 
end

function SkillTreeBuilder:OnUpdate(dt)
	self.root.puck.idletime = self.root.puck.idletime and self.root.puck.idletime + dt or 0

	if TheInput:ControllerAttached() then
		self.root.puck.controlpos = self.root.puck.buttonpos or {x=0,y=0}
	else
		self.root.puck.controlpos = TheInput:GetScreenPosition()
	end
	
	local dist = distsq(self.root.puck.controlpos.x, self.root.puck.controlpos.y, self.root.puck.lastpos.x, self.root.puck.lastpos.y)

	if dist > 1 then
		self.root.puck.idletime = 0
		if self.root.puck.override then
			self:clearwendyeasteregg()
		end
	end 

	self.root.puck.lastpos = self.root.puck.controlpos

	if self.root.puck.idletime > 5 then
		self:triggerwendyeasteregg()
	end

	local newx, newy = nil, nil
	if TheInput:ControllerAttached() then
		for i,item in pairs(self.skillgraphics)do
			if item.button.focus == true then
				
				local pos = self.root.puck:GetPosition()
				local post = item.button:GetPosition()
				self.root.puck.buttonpos = item.button:GetPosition()

				newx = pos.x + ((post.x-pos.x) *(5*dt))
				newy = pos.y + ((post.y-pos.y) *(5*dt))
			end
		end
	else
		if self.root.puck.pucktarget then
			local pos = self.root.puck:GetPosition()
			local post = Vector3(self.root.puck.pucktarget.x,self.root.puck.pucktarget.y,0)

			newx = pos.x + ((post.x-pos.x) *(15*dt))
			newy = pos.y + ((post.y-pos.y) *(15*dt))
			--print(newx,newy)
		end
	end
	if not self.root.puck.override and newx and newy then	
		self.root.puck:SetPosition(newx,newy,0)
	end
	if self.root.puck.override then
		local pos = self.root.puck:GetPosition()
		local post = Vector3(self.root.puck.override.x,self.root.puck.override.y,0)

		local newx = pos.x + ((post.x-pos.x) *(2*dt))
		local newy = pos.y + ((post.y-pos.y) *(2*dt))
		--print(newx,newy)
		self.root.puck:SetPosition(newx,newy,0)
	end
end

function SkillTreeBuilder:triggerwendyeasteregg()
	if self.root.puck and not self.root.puck.easteregg then
		self.root.puck.override = {x=2,y=213}
		self.root.puck.easteregg = true
		
		self.inst.wendyeasteregg = {}


		local task1 = self.inst:DoTaskInTime(2.5, function()  				
			self.root.dialogue:Show()
			TheFrontEnd:GetSound():PlaySound("dontstarve/characters/wendy/talk_LP_HUD", "HUD_talk")
		end)
		
		local task2 = self.inst:DoTaskInTime(5.5, function()
			self.root.puck.override = {x=-123,y=173}
		end)
		
		local task3 = self.inst:DoTaskInTime(6.3, function()  			
			self.root.dialogue:Hide()
			TheFrontEnd:GetSound():KillSound("HUD_talk")
		end)

		local task4 = self.inst:DoTaskInTime(10, function()  			
			self.root.puck.override = nil
			self.inst.wendyeasteregg = nil
		end)	

		table.insert(self.inst.wendyeasteregg, task1)
		table.insert(self.inst.wendyeasteregg, task2)
		table.insert(self.inst.wendyeasteregg, task3)
		table.insert(self.inst.wendyeasteregg, task4)
	end
end

function SkillTreeBuilder:clearwendyeasteregg()
	self.root.puck.override = nil
	TheFrontEnd:GetSound():KillSound("HUD_talk")
	self.root.dialogue:Hide()
	if self.inst.wendyeasteregg then
		for i,task in ipairs(self.inst.wendyeasteregg)do
			if task then
				task:Cancel()
			end
		end
        self.inst.wendyeasteregg = nil
	end	
end

function SkillTreeBuilder:countcols(cols, data)
	for i,branch in pairs(data)do
		local size = getSizeOfList(branch)
		if size > 0 then
			cols = cols + (size-1)
			cols = self:countcols(cols, branch)
		end
	end
	return cols
end

function SkillTreeBuilder:GetDefaultFocus()	
    for _, data in ipairs(self.buttongrid) do
        if data.defaultfocus then
            return data.button
        end
    end
	-- find the lowest x and y
	local current = math.huge
	local list = {}
	for i,data in ipairs(self.buttongrid)do
		if data.x < current then
			current = data.x
			list = {}
			table.insert(list,data)
		elseif data.x == current then
			table.insert(list,data)
		end		
	end
	local current = - math.huge
	local newlist = {}
	for i,data in ipairs(list)do
		if data.y > current then
			current = data.y
			newlist = {}
			table.insert(newlist,data)
		elseif data.y == current then
			table.insert(newlist,data)
		end
	end

	if #newlist > 0 then
		return newlist[1].button
	end
end

local function GetFocusChangeButton(self, current, fn, boost_dir, dir)
	local list = {}

    local forced_focus = current.forced_focus and current.forced_focus[dir] or nil
	for i, data in ipairs(self.buttongrid) do
		if current ~= data then
            if forced_focus == data.skill then
                return data.button
            elseif fn(current,data) then
                table.insert(list, data)
            end
		end
	end

	local choice = nil
	local currentdist = math.huge

	if #list > 0 then
		for i=#list, 1, -1 do
			local xdiff = math.abs(list[i].x - current.x) * (boost_dir == "X" and 0.65 or 1)
			local ydiff = math.abs(list[i].y - current.y) * (boost_dir == "Y" and 0.65 or 1)
			local dist = (xdiff*xdiff) + (ydiff*ydiff)

			if dist < currentdist then
				choice = list[i]
				currentdist = dist
			end
		end
	end
	
	return choice and choice.button or nil
end

function SkillTreeBuilder:SetFocusChangeDirs()
	-- Find the button absolute positions relative to the skill tree widget.
	for i, data in ipairs(self.buttongrid) do
		data.x = data.x + data.button.parent:GetPosition().x
		data.y = data.y + data.button.parent:GetPosition().y
	end

	for i, data in ipairs(self.buttongrid) do
		local up = GetFocusChangeButton(self, data, function(a,b) return b.y > a.y and math.abs(b.x - a.x) <= TILEUNIT/0.5 end, "Y", "up")
		if up ~= nil then
			data.button:SetFocusChangeDir(MOVE_UP, up)
		end
		
		local down = GetFocusChangeButton(self, data, function(a,b) return b.y < a.y and math.abs(b.x - a.x) <= TILEUNIT/0.5 end, "Y", "down")
		if down ~= nil then
			data.button:SetFocusChangeDir(MOVE_DOWN, down)
		end

		local left = GetFocusChangeButton(self, data, function(a,b) return b.x < a.x and math.abs(b.y - a.y) <= TILEUNIT/0.5 end, "X", "left")
		if left ~= nil then
			data.button:SetFocusChangeDir(MOVE_LEFT, left)
		end

		local right = GetFocusChangeButton(self, data, function(a,b) return b.x > a.x and math.abs(b.y - a.y) <= TILEUNIT/0.5 end, "X", "right")
		if right ~= nil then
			data.button:SetFocusChangeDir(MOVE_RIGHT, right)
		end
	end
end

function SkillTreeBuilder:Kill()
	if self.root.puck ~= nil then
		self:clearwendyeasteregg()
	end

    self._base.Kill(self)
end

function SkillTreeBuilder:buildbuttons(panel, pos, data, offset, root)	
	for skill,subdata in pairs(data)do

		local TILEUNIT = 37

		local skillbutton = nil
		local skillicon = nil
		local skillimage = nil

		skillbutton = self:AddChild(ImageButton(ATLAS,IMAGE_SELECTED,IMAGE_SELECTED,IMAGE_SELECTED,IMAGE_SELECTED,IMAGE_SELECTED))
        if subdata.infographic then
            skillbutton:ForceImageSize(TILESIZE_INFOGRAPHIC_CIRCLE, TILESIZE_INFOGRAPHIC_CIRCLE)
        else
            skillbutton:ForceImageSize(TILESIZE, TILESIZE)
        end
		skillbutton:Hide()
		skillbutton:SetOnGainFocus(function()
			if TheInput:ControllerAttached() then
				self.selectedskill = skill
				self:RefreshTree()
			end
		end)
	
		skillbutton:SetOnClick(function()
			if TheInput:ControllerAttached() then
				if not self.selectedskill or not self.skillgraphics[self.selectedskill].status.activatable or not self.infopanel.activatebutton:IsVisible() then
					return
				end

				local skilltreeupdater = nil
				if self.fromfrontend then
		        	skilltreeupdater = TheSkillTree
		    	else
		    		skilltreeupdater = ThePlayer and ThePlayer.components.skilltreeupdater or nil
		    	end
		    	
				self:LearnSkill(skilltreeupdater, self.target)
			else
				self.selectedskill = skill
				self:RefreshTree()
			end
		end)

		if subdata.icon then
			local tex = subdata.icon..".tex"
			skillicon = skillbutton:AddChild(Image( GetSkilltreeIconAtlas(tex), tex ))
            if subdata.infographic then
                skillicon:ScaleToSize(TILESIZE_INFOGRAPHIC, TILESIZE_INFOGRAPHIC)
            else
                skillicon:ScaleToSize(TILESIZE-4, TILESIZE-4)
            end
			skillicon:MoveToFront()
		end

		local frame = IMAGE_FRAME
        if subdata.infographic then -- Higher priority than lock_open.
            frame = IMAGE_INFOGRAPHIC_FRAME
        elseif subdata.lock_open then
            frame = IMAGE_FRAME_LOCK
            skillbutton:SetScale(0.8, 0.8, 1)
        end
		skillimage = self:AddChild(Image(ATLAS,frame))
        if subdata.infographic then
            skillimage:ScaleToSize(TILESIZE_INFOGRAPHIC_FRAME, TILESIZE_INFOGRAPHIC_FRAME)
        else
            skillimage:ScaleToSize(TILESIZE_FRAME, TILESIZE_FRAME)
        end
		skillimage:Hide()

		local newpos = Vector3(subdata.pos[1],subdata.pos[2]+ offset,0)
		skillbutton:SetPosition(newpos.x,newpos.y)
		skillimage:SetPosition(newpos.x,newpos.y)

        skillbutton.clickoffset = Vector3(0, -1, 0)

		self.skillgraphics[skill] = {}
		self.skillgraphics[skill].button = skillbutton
		self.skillgraphics[skill].frame = skillimage
        self.skillgraphics[skill].button_decorations = subdata.button_decorations
		table.insert(self.buttongrid,{button=skillbutton,x=newpos.x,y=newpos.y,skill=skill,forced_focus=subdata.forced_focus,defaultfocus=subdata.defaultfocus,})
	end	
end

function getMax(data,index)
	local max = 0
	for i,node in pairs(data)do
		if math.abs(node.pos[index]) > max then
			max = math.abs(node.pos[index])
		end
	end
	return max+1
end

function SkillTreeBuilder:CreatePanel(data, offset)

	local panel = self:AddChild(Widget(data.name))
	self.root.panels[data.name]  = panel
	panel.title = self:AddChild(Text(HEADERFONT, 18, STRINGS.SKILLTREE.PANELS[string.upper(panel.name)], UICOLOURS.GOLD))
	
	local maxcols = getMax(data.data,1)
	local maxrows = getMax(data.data,2)

	self:buildbuttons(panel, {x=0,y=0}, data.data, offset, self.skilltreewidget.midlay)
	
	panel.c_width = maxcols * TILESIZE + ((maxcols -1) * SPACE)

    local pos = nil
    for i, namedata in ipairs(skilltreedefs.SKILLTREE_ORDERS[self.target]) do
        if namedata[1] == data.name then
            pos = namedata[2]
            break
        end
    end
    if pos then
        panel.title:SetPosition(pos[1], pos[2] + offset)
    end

	panel.c_height = maxrows * TILESIZE + ((maxrows -1) * SPACE)


	return panel
end

local function createtreetable(skilltreedef)
	local tree = {}

	for i,node in pairs(skilltreedef) do
		if not tree[node.group] then
			tree[node.group] = {}
		end

		tree[node.group][i] = node
	end

	return tree
end

---------------------------------------------------------------

function gettitle(skill, prefabname, skillgraphics)
	local skilldata = skilltreedefs.SKILLTREE_DEFS[prefabname][skill]
	if skilldata.lock_open and not skilldata.infographic then
		local lockstatus = skillgraphics[skill].status.lock_open
		if lockstatus then
			if lockstatus == "question"  then
				return STRINGS.SKILLTREE.UNKNOWN
			else
				return STRINGS.SKILLTREE.UNLOCKED
			end
		else
			return STRINGS.SKILLTREE.LOCKED
		end
	else
		return skilldata.title
	end
end

function getdesc(skill, prefabname)
	local skilldata = skilltreedefs.SKILLTREE_DEFS[prefabname][skill]
	return skilldata.desc
end

function SkillTreeBuilder:RefreshTree(skillschanged)
    local characterprefab, availableskillpoints, activatedskills, skilltreeupdater
    local frontend = self.fromfrontend
    local readonly = self.readonly

    if readonly then
        -- Read only content uses self.target and self.targetdata to infer what it knows.
        self.root.xp:Hide()

        characterprefab = self.targetdata.prefab
        activatedskills = TheSkillTree:GetNamesFromSkillSelection(self.targetdata.skillselection, characterprefab)
        availableskillpoints = 0
    else
    	characterprefab = self.target
        -- Write enabled content uses ThePlayer to use what it knows.
        self.root.xp:Show()

        if frontend then
        	skilltreeupdater = TheSkillTree
    	else
    		skilltreeupdater = ThePlayer and ThePlayer.components.skilltreeupdater or nil
    	end

        if skilltreeupdater == nil then
            print("Weird state for skilltreebuilder missing skilltreeupdater component?")
            return -- FIXME(JBK): See if this panel should disappear at this time?
        end

        availableskillpoints = skilltreeupdater:GetAvailableSkillPoints(characterprefab)
        -- NOTES(JBK): This is not readonly so the player accessing it has access to its state and it is safe to assume TheSkillTree here.
        activatedskills = TheSkillTree:GetActivatedSkills(characterprefab)
    end
    
    if not self.button_decorations_init then
        self.button_decorations_init = true
        for _, graphics in pairs(self.skillgraphics) do
            if graphics.button_decorations ~= nil then
                if graphics.button_decorations.init ~= nil then
                    graphics.button_decorations.init(graphics.button, self.skilltreewidget.midlay, self.fromfrontend, characterprefab, activatedskills)
                end
            end
        end
    end
    
	local function make_connected_clickable(skill)
		if self.skilltreedef[skill].connects then
			for i,connected_skill in ipairs(self.skilltreedef[skill].connects)do
				self.skillgraphics[connected_skill].status.activatable = true
			end
		end
	end

	for skill,graphics in pairs(self.skillgraphics) do
		if graphics.status then
			graphics.oldstatus = graphics.status
		end
		graphics.status = {}
	end

	for skill,graphics in pairs(self.skillgraphics) do
		-- ROOT ITEMS ARE ACTIVATABLE
        -- NOTES(JBK): But only if they have an rpc_id.
		if self.skilltreedef[skill].root then
			graphics.status.activatable = self.skilltreedef[skill].rpc_id ~= nil
		end
        -- NOTES(JBK): All infographics are highlighted.
        if self.skilltreedef[skill].infographic then
            graphics.status.activated = true
            graphics.status.infographic = true
            -- Make them not resize or move when hovering or clicking.
            graphics.button.scale_on_focus = false
            graphics.button.move_on_click = false
        end
	end

	for skill,graphics in pairs(self.skillgraphics) do
        if readonly then
            if activatedskills[skill] then
                graphics.status.activated = true
                --make_connected_clickable(skill)
            end
            if self.skilltreedef[skill].lock_open then
            	graphics.status.lock = true
            	local lockstatus = self.skilltreedef[skill].lock_open(characterprefab, activatedskills, readonly)
				graphics.status.lock_open = lockstatus
				
			end
        else
        	if self.skilltreedef[skill].lock_open then
        		-- MARK LOCKS and ACTIVATE CONNECTED ITEMS WHEN NOT LOCKED
				graphics.status.lock = true
				if self.skilltreedef[skill].lock_open(characterprefab, activatedskills, readonly) then
					graphics.status.lock_open = true
					make_connected_clickable(skill)
				end
            elseif skilltreeupdater:IsActivated(skill, characterprefab) then
				graphics.status.activated = true
				make_connected_clickable(skill)
            end
        end
	end

	for skill,graphics in pairs(self.skillgraphics) do
		if self.skilltreedef[skill].locks then
			graphics.status.activatable = self.skilltreedef[skill].rpc_id ~= nil
			for i,lock in ipairs(self.skilltreedef[skill].locks) do
				if not self.skillgraphics[lock].status.lock_open then
					graphics.status.activatable = false
					break
				end
			end
		end
	end

	for skill,graphics in pairs(self.skillgraphics) do
		graphics.button:Hide()
		graphics.frame:Hide()

		if self.selectedskill and self.selectedskill == skill and not TheInput:ControllerAttached() then
			graphics.frame:Show()
		end

		if graphics.status.lock then
			graphics.button:Show()
			if graphics.status.lock_open then
				if graphics.status.lock_open == "question" then
					graphics.button:SetTextures(ATLAS, IMAGE_QUESTION, IMAGE_QUESTION_OVER,IMAGE_QUESTION,IMAGE_QUESTION,IMAGE_QUESTION)
				else
                    if graphics.status.infographic then
                        graphics.button:SetTextures(ATLAS, IMAGE_INFOGRAPHIC_ON, IMAGE_INFOGRAPHIC_ON_OVER, IMAGE_INFOGRAPHIC_ON, IMAGE_INFOGRAPHIC_ON, IMAGE_INFOGRAPHIC_ON)
                    else
                        graphics.button:SetTextures(ATLAS, IMAGE_UNLOCKED, IMAGE_UNLOCKED_OVER, IMAGE_UNLOCKED, IMAGE_UNLOCKED, IMAGE_UNLOCKED)
                    end
				end

				
				if graphics.oldstatus and graphics.oldstatus.lock_open == nil then

                    if graphics.status.infographic then
                        graphics.button:SetTextures(ATLAS, IMAGE_INFOGRAPHIC_OFF, IMAGE_INFOGRAPHIC_OFF_OVER, IMAGE_INFOGRAPHIC_OFF, IMAGE_INFOGRAPHIC_OFF, IMAGE_INFOGRAPHIC_OFF)
                    else
                        graphics.button:SetTextures(ATLAS, IMAGE_LOCKED, IMAGE_LOCKED_OVER, IMAGE_LOCKED, IMAGE_LOCKED, IMAGE_LOCKED)
                    end
					self.inst:DoTaskInTime(0.5, function()
						TheFrontEnd:GetSound():PlaySound("wilson_rework/ui/unlock_gatedskill")
						local pos = graphics.button:GetPosition()
					    local unlockfx = self:AddChild(UIAnim())
					    unlockfx:GetAnimState():SetBuild("skill_unlock")
					    unlockfx:GetAnimState():SetBank("skill_unlock")
					    unlockfx:GetAnimState():PushAnimation("idle")
					    unlockfx:SetPosition(pos.x,pos.y)
					    unlockfx.inst:ListenForEvent("animover", function()
					    	unlockfx:Kill()
					    end)
					end)
					self.inst:DoTaskInTime(13/30, function()
                        if graphics.status.infographic then
                            graphics.button:SetTextures(ATLAS, IMAGE_INFOGRAPHIC_ON, IMAGE_INFOGRAPHIC_ON_OVER, IMAGE_INFOGRAPHIC_ON, IMAGE_INFOGRAPHIC_ON, IMAGE_INFOGRAPHIC_ON)
                        else
                            graphics.button:SetTextures(ATLAS, IMAGE_UNLOCKED, IMAGE_UNLOCKED_OVER, IMAGE_UNLOCKED, IMAGE_UNLOCKED, IMAGE_UNLOCKED)
                        end
					end)
                    if graphics.button_decorations ~= nil then
                        if graphics.button_decorations.onunlocked ~= nil then
                            graphics.button_decorations.onunlocked(graphics.button, false, self.fromfrontend)
                        end
                    end
                else
                    if graphics.button_decorations ~= nil then
                        if graphics.button_decorations.onunlocked ~= nil then
                            graphics.button_decorations.onunlocked(graphics.button, true, self.fromfrontend)
                        end
                    end
				end
			else
                if graphics.status.infographic then
                    graphics.button:SetTextures(ATLAS, IMAGE_INFOGRAPHIC_OFF, IMAGE_INFOGRAPHIC_OFF_OVER, IMAGE_INFOGRAPHIC_OFF, IMAGE_INFOGRAPHIC_OFF, IMAGE_INFOGRAPHIC_OFF)
                else
                    graphics.button:SetTextures(ATLAS, IMAGE_LOCKED, IMAGE_LOCKED_OVER, IMAGE_LOCKED, IMAGE_LOCKED, IMAGE_LOCKED)
                end
                if graphics.button_decorations ~= nil then
                    if graphics.button_decorations.onlocked ~= nil then
                        graphics.button_decorations.onlocked(graphics.button, graphics.oldstatus == nil or graphics.oldstatus.lock_open == graphics.status.lock_open, self.fromfrontend)
                    end
                end
			end
		elseif graphics.status.activated then
			graphics.button:Show()
            if graphics.status.infographic then
                graphics.button:SetTextures(ATLAS, IMAGE_INFOGRAPHIC, IMAGE_INFOGRAPHIC_OVER, IMAGE_INFOGRAPHIC, IMAGE_INFOGRAPHIC, IMAGE_INFOGRAPHIC)
            else
                graphics.button:SetTextures(ATLAS, IMAGE_SELECTED, IMAGE_SELECTED_OVER, IMAGE_SELECTED, IMAGE_SELECTED, IMAGE_SELECTED)
            end
            if graphics.button_decorations ~= nil then
                if graphics.button_decorations.onunlocked ~= nil then
                    graphics.button_decorations.onunlocked(graphics.button, true, self.fromfrontend)
                end
            end
		elseif graphics.status.activatable and availableskillpoints > 0 then
			graphics.button:Show()
			graphics.button:SetTextures(ATLAS, IMAGE_SELECTABLE, IMAGE_SELECTABLE_OVER,IMAGE_SELECTABLE,IMAGE_SELECTABLE,IMAGE_SELECTABLE)
            if graphics.button_decorations ~= nil then
                if graphics.button_decorations.onlocked ~= nil then
                    graphics.button_decorations.onlocked(graphics.button, true, self.fromfrontend)
                end
            end
		else
			graphics.button:Show()
			graphics.button:SetTextures(ATLAS, IMAGE_UNSELECTED, IMAGE_UNSELECTED_OVER,IMAGE_UNSELECTED,IMAGE_UNSELECTED,IMAGE_UNSELECTED)
            if graphics.button_decorations ~= nil then
                if graphics.button_decorations.onlocked ~= nil then
                    graphics.button_decorations.onlocked(graphics.button, true, self.fromfrontend)
                end
            end
		end
	end

    if skillschanged then
        for _, graphics in pairs(self.skillgraphics) do
            if graphics.button_decorations ~= nil then
                if graphics.button_decorations.onskillschanged ~= nil then
                    graphics.button_decorations.onskillschanged(graphics.button, self.selectedskill, self.fromfrontend, characterprefab, activatedskills)
                end
            end
        end
    end

	self.root.xptotal:SetString(availableskillpoints)
	if availableskillpoints <= 0 and TheSkillTree:GetSkillXP(characterprefab) >= TUNING.FIXME_DO_NOT_USE_FOR_MODS_NEW_MAX_XP_VALUE then -- >= TheSkillTree:GetMaximumExperiencePoints() then
		self.root.xp_tospend:SetString(STRINGS.SKILLTREE.KILLPOINTS_MAXED)
		local w, h = self.root.xp_tospend:GetRegionSize()
   		self.root.xp_tospend:SetPosition(30+(w/2),-3)		
	else	   	
		self.root.xp_tospend:SetString(STRINGS.SKILLTREE.SKILLPOINTS_TO_SPEND)
		local w, h = self.root.xp_tospend:GetRegionSize()
		self.root.xp_tospend:SetPosition(30+(w/2),-3)
	end


	if self.selectedskill  then
		if TheInput:ControllerAttached() then
			self.skillgraphics[self.selectedskill].button:SetHelpTextMessage("")
		end
	end

	if self.infopanel then
		self.infopanel.title:Hide()
		self.infopanel.activatebutton:Hide()
		self.infopanel.activatedtext:Hide()
		self.infopanel.respec_button:Hide()
		self.infopanel.activatedbg:Hide()

		if self.fromfrontend then
            if skilltreedefs.FN.CountSkills(self.target, activatedskills) > 0 then
                self.infopanel.respec_button:Show()
            end
            if self.sync_status then
                self.sync_status:Show()
            end
        else
            if self.sync_status then
                self.sync_status:Hide()
            end
		end

		if self.selectedskill  then
			self.infopanel.title:Show()
			self.infopanel.title:SetString(gettitle(self.selectedskill, self.target, self.skillgraphics) )
			self.infopanel.desc:Show()
			self.infopanel.desc:SetMultilineTruncatedString(getdesc(self.selectedskill, self.target), 3, 400, nil, nil, true, 6)
			self.infopanel.intro:Hide()
			
            if not readonly then
                if availableskillpoints > 0 and self.skillgraphics[self.selectedskill].status.activatable and not skilltreeupdater:IsActivated(self.selectedskill, characterprefab) then

                	self.infopanel.activatedbg:Hide()
                    self.infopanel.activatebutton:Show()                    
                    self.infopanel.activatebutton:SetOnClick(function()
                    	self:LearnSkill(skilltreeupdater,characterprefab)
                    end)
					if TheInput:ControllerAttached() then
						self.skillgraphics[self.selectedskill].button:SetHelpTextMessage(STRINGS.SKILLTREE.ACTIVATE)
						self.infopanel.activatebutton:SetText(TheInput:GetLocalizedControl(TheInput:GetControllerID(), self.infopanel.activatebutton.control, false, false ).." "..STRINGS.SKILLTREE.ACTIVATE)
					end
                end
            end

			if self.skillgraphics[self.selectedskill].status.activated and not self.skilltreedef[self.selectedskill].infographic then
				self.infopanel.activatedtext:Show()
				self.infopanel.activatedbg:Show()
			end
		else
			self.infopanel.desc:SetMultilineTruncatedString(STRINGS.SKILLTREE.INFOPANEL_DESC, 3, 240, nil,nil,true,6)
		end
	end
end

function SkillTreeBuilder:LearnSkill(skilltreeupdater, characterprefab)
	if self.selectedskill then
		if TheInput:ControllerAttached() and self.skillgraphics[self.selectedskill].status.lock then
			return
		end
	    skilltreeupdater:ActivateSkill(self.selectedskill, characterprefab)

	    local pos = self.skillgraphics[self.selectedskill].button:GetPosition()
	    local clickfx = self:AddChild(UIAnim())
	    clickfx:GetAnimState():SetBuild("skills_activate")
	    clickfx:GetAnimState():SetBank("skills_activate")
	    clickfx:GetAnimState():PushAnimation("idle")
	    clickfx.inst:ListenForEvent("animover", function() clickfx:Kill() end)
	    clickfx:SetPosition(pos.x,pos.y + 15)

		local isshadow = skilltreedefs.FN.SkillHasTags( self.selectedskill, "shadow_favor", self.target)
		local islunar =  skilltreedefs.FN.SkillHasTags( self.selectedskill, "lunar_favor",  self.target)

		local sound = 
			(isshadow and "wilson_rework/ui/shadow_skill") or
			(islunar  and "wilson_rework/ui/lunar_skill") or
			"wilson_rework/ui/skill_mastered"
			
		TheFrontEnd:GetSound():PlaySound(sound)

	    if isshadow or islunar then
	    	self.skilltreewidget:SpawnFavorOverlay(true)
		end

	    self:RefreshTree(true)
	end
end

function SkillTreeBuilder:CreateTree(prefabname, targetdata, readonly)
	self.skilltreedef = skilltreedefs.SKILLTREE_DEFS[prefabname]

	self.target = prefabname
	self.targetdata = targetdata
	self.readonly = readonly

	local treedata = createtreetable(self.skilltreedef)

	for panel,subdata in pairs (treedata) do
		self:CreatePanel({name=panel,data=subdata}, -30)
	end

	local current_x = -260
	local last_width = 0

	--for i,panel in ipairs(self.root.panels)do
	for i,paneldata in ipairs(skilltreedefs.SKILLTREE_ORDERS[self.target]) do
        local panelname = paneldata[1]
        local panel = self.root.panels[panelname]
        if panel then
            current_x = current_x + last_width + TILESIZE
            last_width = panel.c_width
            panel:SetPosition(current_x , 170 )
        else
            print(string.format("FIXME: Skill tree order named %s has no skill data!", panelname))
        end
	end

	if prefabname == "wendy" then
		self:SpawnPuck()
	end

	self:RefreshTree()
end

function SkillTreeBuilder:GetSelectedSkill()

end

return SkillTreeBuilder