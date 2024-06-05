-------------------------------------
--- LOAD
-------------------------------------

MR.SV.Load = MR.SV.Load or {}
local Load = MR.SV.Load


-- Networking
util.AddNetworkString("CL.Load:Delete")
util.AddNetworkString("SV.Load:SetAuto")
util.AddNetworkString("SV.Load:Delete")
util.AddNetworkString("SV.Load:Start")

net.Receive("SV.Load:SetAuto", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Load:SetAuto(ply, net.ReadString())
	end
end)

net.Receive("SV.Load:Start", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Load:Start(MR.SV.Ply:GetFakeHostPly() , net.ReadString())
	end
end)

net.Receive("SV.Load:Delete", function(_, ply)
	if MR.Ply:IsAllowed(ply) then
		Load:Delete(ply, net.ReadString())
	end
end)

-- First spawn hook
-- Wait until the player fully loads (https://github.com/Facepunch/garrysmod-requests/issues/718)
hook.Add("PlayerInitialSpawn", "MRPlyfirstSpawn", function(ply)
	-- Load tool modifications BEFORE the player is fully ready
	Load:PlayerJoined(ply)

	-- Load tool modifications AFTER the player is fully ready
	local hookName = "MR" .. tostring(ply)
	hook.Add("SetupMove", hookName, function(ply, mv, cmd)
		if hookName == "MR" .. tostring(ply) and not cmd:IsForced() then
			-- Wait just a bit more for players with weaker hardware
			timer.Simple(1, function()
				Load:FirstSpawn(ply);
			end)

			hook.Remove("SetupMove", hookName)
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
function Load:Start(ply, loadName)
	-- !!!!!!ALERT!!!!!!
	-- The system was originaly designed so users could use this function to load materials when
	-- they joined the game and the map was already modified, but it was extremely confusing and
	-- I scrapted everything! Now users simply load all materials at once the moment they join and
	-- immediately start accepting broadcasted materials from here.
	ply =  MR.SV.Ply:GetFakeHostPly()


	local loadTable

	-- Don't load in the middle of an unloading
	if MR.Materials:IsRunningProgressiveCleanup() then
		return false
	end

	-- Check if there is a load name
	if not loadName or loadName == "" then
		return false
	end

	-- The current map modifications
	-- if loadName == "currentMaterials" then
	-- 	loadTable = MR.DataList:CleanAll(table.Copy(MR.Materials:GetCurrentModifications()))
	-- Ongoing change all load
	if loadName == "changeAllMaterials" then
		loadTable = table.Copy(MR.SV.Duplicator:GetCurrentTable(ply))
	-- Loading from files
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
	MR.Duplicator:InitProcessedList(ply)
	MR.Ply:InitStatesList(ply)

	-- Set the player load list
	MR.Net:SendString(util.TableToJSON(MR.Load:GetList()), "NET_LoadSetList", ply)

	-- Set the player load list
	MR.Net:SendString(util.TableToJSON(MR.Displacements:GetDetected()), "NET_CLDisplacementsInitDetected", ply)
end

-- Load tool modifications AFTER the player is fully ready
function Load:FirstSpawn(ply)
	-- Initialize server materials detail list
	local detailsFile = MR.Base:GetDetectedDetailsFile()
	-- [bug] detail lists created before 2021.02.5 are invalid and must be replaced
	if file.Exists(detailsFile, "Data") then
		local dateParts = string.Explode(".", os.date("%d.%m.%Y", file.Time(detailsFile, "DATA")))
		for k,v in pairs(dateParts) do dateParts[k] = tonumber(v); end
		if dateParts[3] < 2021 or dateParts[2] < 2 or dateParts[1] < 5 then
			file.Delete(detailsFile)
		end
	end
	-- [/bug]
	if not file.Exists(detailsFile, "Data") and not MR.SV.Detail:GetFix("Initialized") then
		print("[Map Retexturizer] Building details list for the first time...")

		MR.SV.Detail:SetFix("Initialized", 1)

		net.Start("CL.Detail:SetFixList")
		net.Send(ply)
	end

	-- Validate the preview material
	MR.Materials:Validate(MR.Materials:GetSelected(ply))

	-- Set to auto validate the tool state
	MR.Ply:SetAutoValidateTool(ply)

	-- Send the current modifications / keep loading an ongoing load
	-- if MR.Base:GetInitialized() or MR.Duplicator:IsRunning(MR.SV.Ply:GetFakeHostPly()) then
	--	Load:Start(ply, "currentMaterials")

	-- Initialize the materials on the client realm
	if MR.Base:GetInitialized() then
		local loadTable = table.Copy(MR.Materials:GetCurrentModifications())
		for listName, list in pairs(loadTable) do
			if listName ~= "savingFormat" and #list > 0 then
				MR.DataList:RemoveDisabled(list)
			end
		end
		MR.Net:SendString(util.TableToJSON(loadTable), "NET_ForceApplyAllMaterials", ply)
		timer.Simple(2, function()
			if IsValid(ply) then
				MR.Ply:SetFirstSpawn(ply, false)
			end
		end)
	--Run an autoload
	elseif GetConVar("internal_mr_autoload"):GetString() ~= "" then
		-- Set the spawn as done since The fakeHostPly will take care of this load
		MR.Ply:SetFirstSpawn(ply, false)

		Load:Start(MR.SV.Ply:GetFakeHostPly(), GetConVar("internal_mr_autoload"):GetString())
	-- Nothing to send, finish the joining process
	else
		MR.Ply:SetFirstSpawn(ply, false)
	end
end

-- Delete a saved file
function Load:Delete(ply, loadName)
	-- Admin only
	if not MR.Ply:IsAllowed(ply) then
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
	if not MR.Ply:IsAllowed(ply) then
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