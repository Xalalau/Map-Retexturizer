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
	-- Note: loads can be done by normal players too, like when they enter the
	-- server, but only admins can pass through this net!
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	Load:Start(MR.SV.Ply:GetFakeHostPly() , net.ReadString())
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
			timer.Simple(1, function()
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
		MR.Sync:Set(value, "load", "autoloadtext")
	else
		RunConsoleCommand("internal_mr_autoload", "")
	end
end

-- Load modifications
-- Note: use MR.SV.Ply:GetFakeHostPly() as ply to broadcast materials
function Load:Start(ply, loadName)
	local loadTable

	-- Don't load in the middle of an unloading
	if MR.Materials:IsRunningProgressiveCleanup() then
		return false
	end

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

	-- The current map modifications
	if loadName == "currentMaterials" then
		loadTable = table.Copy(MR.Materials:GetCurrentModifications(true))
	-- Ongoing loads
	elseif loadName == "changeAllMaterials" or loadName == "currentLoading" then
		loadTable = table.Copy(MR.SV.Duplicator:GetCurrentTable())
	-- Loadings from files
	else
		-- Get the load file
		local loadFile = MR.Load:GetOption(loadName) or MR.Base:GetSaveFolder() .. loadName .. ".txt"

		-- Check if it exists
		if !file.Exists(loadFile, "Data") then
			return false
		end

		-- Get the its contents
		loadTable = util.JSONToTable(file.Read(loadFile, "Data"))
	end

	-- Start the loading
	if loadTable then
		MR.SV.Duplicator:Start(ply, nil, loadTable, loadName)

		return true
	end

	return false
end

-- Load tool modifications BEFORE the player is fully ready
function Load:PlayerJoined(ply)
	-- Set the player internal controls
	MR.SV.Duplicator:InitNewDupTable(ply)
	MR.Duplicator:InitProcessedList(ply)
	MR.Ply:InitStatesList(ply)

	-- Set the player load list
	net.Start("Load:SetList")
		net.WriteTable(MR.Load:GetList())
	net.Send(ply)

	-- Set the player load list
	net.Start("CL.Displacements:InitDetected")
		net.WriteTable(MR.Displacements:GetDetected())
	net.Send(ply)

	-- Initialize server materials detail list
	if not file.Exists(MR.Base:GetDetectedDetailsFile(), "Data") and not MR.SV.Materials:GetDetailFix("Initialized") then
		print("[Map Retexturizer] Building details list for the first time...")

		MR.SV.Materials:SetDetailFix("Initialized", 1)

		net.Start("CL.Materials:SetDetailFixList")
		net.Send(ply)
	end
end

-- Load tool modifications AFTER the player is fully ready
function Load:FirstSpawn(ply)
	-- Validate the preview material
	MR.Materials:Validate(MR.Materials:GetSelected(ply))

	-- Start an ongoing load from the beggining
	if MR.Duplicator:IsRunning() then
		Load:Start(ply, "currentLoading")
	-- Send the current modifications
	elseif MR.Base:GetInitialized() then
		Load:Start(ply, "currentMaterials")
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

	timer.Simple(0.3, function()
		file.Write(MR.Base:GetAutoLoadFile(), GetConVar("internal_mr_autoload"):GetString())
	end)

	return true
end

-- Upgrade format 1.0 to 2.0
function Load:Upgrade1to2(savedTable, isDupStarting, currentFormat)
	if savedTable and not savedTable.savingFormat then
		-- Rebuild map materials structure from GMod saves
		if savedTable[1] and savedTable[1].oldMaterial then
			local aux = table.Copy(savedTable)

			savedTable = {}

			if MR.Materials:IsDisplacement(aux[1].oldMaterial) then
				savedTable.displacements = aux
			else
				savedTable.map = aux
			end
		-- Rebuild decals structure from GMod saves
		elseif savedTable[1] and savedTable[1].mat then
			local aux = table.Copy(savedTable)

			savedTable = {}
			savedTable.decals = aux
		end

		-- Map and displacements tables from saved files and rebuilt GMod saves:
		if savedTable.map then
			-- Remove all the disabled elements
			MR.DataList:Clean(savedTable.map)

			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.map do
				savedTable.map[i].backup.newMaterial, _ = string.gsub(savedTable.map[i].backup.newMaterial, "%mapretexturizer", "mr")
			end
		end

		if savedTable.displacements then
			-- Change "mapretexturizer" to "mr"
			local i

			for i = 1,#savedTable.displacements do

				savedTable.displacements[i].backup.newMaterial, _ = string.gsub(savedTable.displacements[i].backup.newMaterial, "%mapretexturizer", "mr")
				savedTable.displacements[i].backup.newMaterial2, _ = string.gsub(savedTable.displacements[i].backup.newMaterial2, "%mapretexturizer", "mr")
			end
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "2.0"
		end
		currentFormat = "2.0"
	end

	return currentFormat
end

-- Upgrade format 2.0 to 3.0
function Load:Upgrade2to3(savedTable, isDupStarting, currentFormat)
	if savedTable and savedTable.savingFormat == "2.0" or currentFormat == "2.0" then
		-- Update decals structure
		if savedTable.decals then
			for k,v in pairs(savedTable.decals) do
				local new = {
					oldMaterial = v.mat,
					newMaterial = v.mat,
					scalex = "1",
					scaley = "1",
					position = v.pos,
					normal = v.hit
				}
			
				savedTable.decals[k] = new
			end
		end

		-- Update skybox structure
		if savedTable.skybox and savedTable.skybox ~= "" then
			savedTable.skybox = {
				MR.Data:CreateFromMaterial(savedTable.skybox)
			}

			savedTable.skybox[1].newMaterial = savedTable.skybox[1].oldMaterial
			savedTable.skybox[1].oldMaterial = MR.Skybox:GetGenericName()
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "3.0"
		end
		currentFormat = "3.0"
	end

	return currentFormat
end

-- Upgrade format 3.0 to 4.0
function Load:Upgrade3to4(savedTable, isDupStarting, currentFormat)
	if savedTable and savedTable.savingFormat == "3.0" or currentFormat == "3.0" then
		-- For each data block...
		for _,section in pairs(savedTable) do
			if istable(section) then
				for _,data in pairs(section) do
					-- Remove the backups
					data.backup = nil

					-- Adjust rotation
					if data.rotation then
						data.rotation = string.format("%.2f", data.rotation)
					end

					-- Adjust variable names
					if data.offsetx then
						data.offsetX = data.offsetx
						data.offsetx = nil
					end

					if data.offsety then
						data.offsetY = data.offsety
						data.offsety = nil
					end

					if data.scalex then
						data.scaleX = data.scalex
						data.scalex = nil
					end

					if data.scaley then
						data.scaleY = data.scaley
						data.scaley = nil
					end

					-- Disable unused fields
					MR.Data:RemoveDefaultValues(data)
				end
			end
		end

		-- Set the new format number before fully loading the table in the duplicator
		if isDupStarting then
			savedTable.savingFormat = "4.0"
		end
		currentFormat = "4.0"
	end

	return currentFormat
end

-- Format upgrading
-- Note: savedTable will come in parts from RecreateTable if we are receiving a GMod save, otherwise it'll be full
function Load:Upgrade(savedTable, isGModSave, isDupStarting, loadName)
	if not savedTable then return; end

	local startFormat = savedTable.savingFormat or "1.0"
	local currentFormat = startFormat

	-- Upgrade
	currentFormat = Load:Upgrade1to2(savedTable, isDupStarting, currentFormat)
	currentFormat = Load:Upgrade2to3(savedTable, isDupStarting, currentFormat)
	currentFormat = Load:Upgrade3to4(savedTable, isDupStarting, currentFormat)

	-- Backup the old save file and create a new one with the convertion
	if isDupStarting and
		not isGModSave and
		startFormat ~= currentFormat then

		local pathCurrent = MR.Base:GetSaveFolder()..loadName..".txt"
		local pathBackup = MR.Base:GetConvertedFolder().."/"..loadName.."_format_"..startFormat..".txt"

		file.Rename(pathCurrent, pathBackup)
		file.Write(pathCurrent, util.TableToJSON(savedTable, true))
	end

	return savedTable
end
