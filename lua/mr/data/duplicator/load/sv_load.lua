-------------------------------------
--- LOAD
-------------------------------------

local Load = {}
Load.__index = Load
MR.SV.Load = Load

-- Networking
util.AddNetworkString("Load:SetList")
util.AddNetworkString("CL.Load:Delete")
util.AddNetworkString("SV.Load:SetAuto")
util.AddNetworkString("SV.Load:Delete")
util.AddNetworkString("SV.Load:Start")

net.Receive("SV.Load:SetAuto", function(_, ply)
	Load:SetAuto(ply, net.ReadString())
end)

net.Receive("SV.Load:Start", function(_, ply)
	Load:Start(MR.SV.Ply:GetFakeHostPly(), net.ReadString())
end)

net.Receive("SV.Load:Delete", function(_, ply)
	Load:Delete(ply, net.ReadString())
end)

-- First spawn hook
-- Wait until the player fully loads (https://github.com/Facepunch/garrysmod-requests/issues/718)
hook.Add("PlayerInitialSpawn", "MRPlyfirstSpawn", function(ply)
	-- Load tool modifications BEFORE the player is fully ready
	Load:PlayerJoined(ply)

	-- Load tool modifications AFTER the player is fully ready
	hook.Add("SetupMove", ply, function(self, ply, _, cmd)
		if self == ply and not cmd:IsForced() then
			-- Wait just a bit more for players with weaker hardware
			timer.Create("MRFirstSpawnApplyDelay"..tostring(ply), 1, 1, function()
				Load:FirstSpawn(ply);
			end)

			hook.Remove("SetupMove",self)
		end
	end)
end)

function Load:Init()
	-- Fill the load list on the server
	local files = file.Find(MR.Base:GetSaveFolder().."*", "Data")

	for k,v in pairs(files) do
		MR.Load:SetOption(string.lower(v):sub(1, -5), MR.Base:GetSaveFolder()..string.lower(v):sub(1, -5)..".txt") -- lowercase to adjust old save names
	end

	-- Set the autoLoad command
	local value = file.Read(MR.Base:GetAutoLoadFile(), "Data")

	if value then
		RunConsoleCommand("internal_mr_autoload", value)
		MR.CPanel:Set("load", "autoloadtext", value)
	else
		RunConsoleCommand("internal_mr_autoload", "")
	end
end

-- Load modifications
function Load:Start(ply, loadName)
	-- General first steps
	local check = {
		type = "Load"
	}

	if not MR.Materials:SetFirstSteps(ply) then
		return false
	end

	-- Check if there is a load name
	if not loadName or loadName == "" then
		return false
	end

	-- Get the load file
	local loadFile = MR.Load:GetOption(loadName) or MR.Base:GetSaveFolder() .. loadName .. ".txt"

	-- Check if it exists
	if !file.Exists(loadFile, "Data") then
		return false
	end

	-- Get the its contents
	loadTable = util.JSONToTable(file.Read(loadFile, "Data"))

	-- Start the loading
	if loadTable then
		MR.SV.Duplicator:Start(ply, nil, loadTable, loadName)

		return true
	end

	return false
end

-- Load tool modifications BEFORE the player is fully ready
function Load:PlayerJoined(ply)
	-- Set the player load list
	net.Start("Load:SetList")
		net.WriteTable(MR.Load:GetList())
	net.Send(ply)
end

-- Load tool modifications AFTER the player is fully ready
function Load:FirstSpawn(ply)
	-- Index the player control
	MR.Ply:Set(ply)

	-- wait until the player has our table attached to him
	timer.Create("MRWaitToSetPly", 0.5, 1, function()
		-- Start an ongoing load from the beggining
		if MR.Duplicator:IsRunning() then
			Load:Start(ply, MR.Duplicator:IsRunning())
		-- Send the current modifications
		elseif MR.Base:GetInitialized() then
			MR.SV.Duplicator:Start(ply)
		-- Run an autoload
		elseif GetConVar("internal_mr_autoload"):GetString() ~= "" then
			-- Set the spawn as done since The fakeHostPly will take care of this load
			MR.Ply:SetFirstSpawn(ply)
			net.Start("Ply:SetFirstSpawn")
			net.Send(ply)

			Load:Start(MR.SV.Ply:GetFakeHostPly(), GetConVar("internal_mr_autoload"):GetString())
		-- Nothing to send, finish the joining process
		else
			MR.Ply:SetFirstSpawn(ply)
			net.Start("Ply:SetFirstSpawn")
			net.Send(ply)
		end
	end)
end

-- Delete a saved file
function Load:Delete(ply, loadName)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	local loadFile = MR.Load:GetOption(loadName)

	-- Check if the file exists
	if loadFile == nil then
		return false
	end

	-- Remove the load entry
	MR.Load:SetOption(loadName, nil)

	-- Unset autoload if needed
	if GetConVar("internal_mr_autoload"):GetString() == loadName then
		Load:SetAuto(ply, "")
	end

	-- Delete the file
	file.Delete(loadFile)

	-- Updates the load list on every client
	net.Start("CL.Load:Delete")
		net.WriteString(loadName)
	net.Broadcast()
	
	return true
end

-- Set an auto load for the map
function Load:SetAuto(ply, loadName)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Check if the load name is valid
	if not loadName or not MR.Load:GetOption(loadName) and loadName ~= "" then
		return false
	end

	-- Apply the value to every client
	MR.SV.Sync:Replicate(ply, "internal_mr_autoload", loadName, "load", "autoloadtext")

	timer.Create("MRWaitToSave", 0.3, 1, function()
		file.Write(MR.Base:GetAutoLoadFile(), GetConVar("internal_mr_autoload"):GetString())
	end)

	return true
end
