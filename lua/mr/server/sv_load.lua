-------------------------------------
--- LOAD
-------------------------------------

local Load = MR.Load

-- Networking
util.AddNetworkString("Load:Start")
util.AddNetworkString("Load:SetList")
util.AddNetworkString("Load:Delete_SV")
util.AddNetworkString("Load:Delete_CL2")
util.AddNetworkString("Load:SetAuto")

net.Receive("Load:SetAuto", function(_, ply)
	Load:SetAuto(ply, net.ReadString())
end)

net.Receive("Load:Start", function(_, ply)
	Load:Start(MR.Ply:GetFakeHostPly(), net.ReadString())
end)

net.Receive("Load:Delete_SV", function(_, ply)
	Load:Delete_SV(ply, net.ReadString())
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
	local files = file.Find(MR.Base:GetMapFolder().."*", "Data")

	for k,v in pairs(files) do
		Load:SetOption(v:sub(1, -5), MR.Base:GetMapFolder()..v)
	end

	-- Set the autoLoad command
	local value = file.Read(MR.Base:GetAutoLoadFile(), "Data")

	if value then
		RunConsoleCommand("internal_mr_autoload", value)
		MR.GUI:Set("load", "autoloadtext", value)
	else
		RunConsoleCommand("internal_mr_autoload", "")
	end
end

-- Print the load list in the console
function Load:PrintList()
	print("----------------------------")
	print("[Map Retexturizer] Saves:")
	print("----------------------------")
	for k,v in pairs(Load:GetList()) do
		print(k)
	end
	print("----------------------------")
end

-- Load modifications
function Load:Start(ply, loadName)
	-- General first steps
	MR.Materials:SetFirstSteps(ply)

	-- Check if there is a load name
	if not loadName or loadName == "" then
		return false
	end

	-- Get the load file
	local loadFile = Load:GetOption(loadName) or MR.Base:GetMapFolder() .. loadName .. ".txt"

	-- Check if it exists
	if !file.Exists(loadFile, "Data") then
		return false
	end

	-- Get the its contents
	loadTable = util.JSONToTable(file.Read(loadFile, "Data"))

	-- Start the loading
	if loadTable then
		MR.Duplicator:Start(ply, nil, loadTable, loadName)

		return true
	end

	return false
end

-- Load tool modifications BEFORE the player is fully ready
function Load:PlayerJoined(ply)
	-- Set the player load list
	net.Start("Load:SetList")
		net.WriteTable(Load:GetList())
	net.Send(ply)
end

-- Load tool modifications AFTER the player is fully ready
function Load:FirstSpawn(ply)
	-- Index the player control
	MR.Ply:Set(ply)

	-- Start an ongoing load from the beggining
	if MR.Duplicator:IsRunning() then
		Load:Start(ply, MR.Duplicator:IsRunning())
	-- Send the current modifications
	elseif MR.Base:GetInitialized() then
		MR.Duplicator:Start(ply)
	-- Run an autoload
	elseif GetConVar("internal_mr_autoload"):GetString() ~= "" then
		-- Set the spawn as done since The fakeHostPly will take care of this load
		MR.Ply:SetFirstSpawn(ply)
		net.Start("Ply:SetFirstSpawn")
		net.Send(ply)

		Load:Start(MR.Ply:GetFakeHostPly(), GetConVar("internal_mr_autoload"):GetString())
	-- Nothing to send, finish the joining process
	else
		MR.Ply:SetFirstSpawn(ply)
		net.Start("Ply:SetFirstSpawn")
		net.Send(ply)
	end
end

-- Delete a saved file: server
function Load:Delete_SV(ply, loadName)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	local loadFile = Load:GetOption(loadName)

	-- Check if the file exists
	if loadFile == nil then
		return false
	end

	-- Remove the load entry
	Load:SetOption(loadName, nil)

	-- Unset autoload if needed
	if GetConVar("internal_mr_autoload"):GetString() == loadName then
		Load:SetAuto(ply, "")
	end

	-- Delete the file
	file.Delete(loadFile)

	-- Updates the load list on every client
	net.Start("Load:Delete_CL2")
		net.WriteString(loadName)
	net.Broadcast()
	
	return true
end

-- Set an auto load for the map
function Load:SetAuto(ply, loadName)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Check if the load name is valid
	if not loadName or not Load:GetOption(loadName) and loadName ~= "" then
		return false
	end

	-- Apply the value to every client
	MR.CVars:Replicate_SV(ply, "internal_mr_autoload", loadName, "load", "autoloadtext")

	timer.Create("MRWaitToSave", 0.3, 1, function()
		file.Write(MR.Base:GetAutoLoadFile(), GetConVar("internal_mr_autoload"):GetString())
	end)

	return true
end
