local MAX_SAVED_COMMANDS = 20

ConsoleScreenSettings = Class(function(self)
    self.persistdata = {}
	self.profanityservers = {}

    self.dirty = true
end)

function ConsoleScreenSettings:Reset()
    self.persistdata = {}
	self.dirty = true
	self:Save()
end

function ConsoleScreenSettings:GetConsoleHistory()
	return self.persistdata["history"] or {}
end

function ConsoleScreenSettings:GetConsoleLocalRemoteHistory()
	return self.persistdata["localremotehistory"] or {}
end

function ConsoleScreenSettings:AddLastExecutedCommand(command_str, toggle_remote_execute)
	if self.persistdata["history"] == nil then
		self.persistdata["history"] = {}
	end
	table.insert(self.persistdata["history"], command_str)

	if self.persistdata["localremotehistory"] == nil then
		self.persistdata["localremotehistory"] = {}
	end
	table.insert(self.persistdata["localremotehistory"], toggle_remote_execute)

	-- Remove the oldest executed command if over the max number of saved commands
	if #self.persistdata["history"] > MAX_SAVED_COMMANDS then
		table.remove(self.persistdata["history"], 1)
	end

	if #self.persistdata["localremotehistory"] > MAX_SAVED_COMMANDS then
		table.remove(self.persistdata["localremotehistory"], 1)
	end

	self.dirty = true
end

function ConsoleScreenSettings:IsWordPredictionWidgetExpanded()
	return self.persistdata["expanded"] or false
end

function ConsoleScreenSettings:SetWordPredictionWidgetExpanded(value)
	self.persistdata["expanded"] = value
	self.dirty = true
end

----------------------------

function ConsoleScreenSettings:GetSaveName()
    return BRANCH ~= "dev" and "consolescreen" or ("consolescreen_"..BRANCH)
end

function ConsoleScreenSettings:Save(callback)
    if self.dirty then
		self.dirty = false

        local str = json.encode(self.persistdata)
        local insz, outsz = SavePersistentString(self:GetSaveName(), str, ENCODE_SAVES, callback)
    else
		if callback then
			callback(true)
		end
    end
end

function ConsoleScreenSettings:Load(callback)
    TheSim:GetPersistentString(self:GetSaveName(),
        function(load_success, str)
        	-- Can ignore the successfulness cause we check the string
			self:OnLoad( str, callback )
        end, false)
end

function ConsoleScreenSettings:OnLoad(str, callback)
	if str == nil or string.len(str) == 0 then
		print ("ConsoleScreenSettings could not load ".. self:GetSaveName())
		if callback then
			callback(false)
		end
	else
		print ("ConsoleScreenSettings loaded ".. self:GetSaveName(), #str)

		self.persistdata = TrackedAssert("TheSim:GetPersistentString ConsoleScreenSettings",  json.decode, str)

		self.dirty = false
		self:Save()
		if callback then
			callback(true)
		end
	end
end
