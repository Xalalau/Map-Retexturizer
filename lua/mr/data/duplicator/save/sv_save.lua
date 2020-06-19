--------------------------------
--- SAVE
--------------------------------

local Save = {}
Save.__index = Save
MR.SV.Save = Save

local save = {
	-- The current save formating
	currentVersion = 4.0
}

-- Networking
util.AddNetworkString("CL.Save:Set_Finish")
util.AddNetworkString("SV.Save:Set")
util.AddNetworkString("SV.Save:SetAuto")

net.Receive("SV.Save:SetAuto", function(_, ply)
	Save:SetAuto(ply, net.ReadBool(value))
end)

net.Receive("SV.Save:Set", function(_, ply)
	Save:Set(ply, net.ReadString())
end)

-- Get the current save formating
function Save:GetCurrentVersion()
	return save.currentVersion
end

-- Save the modifications to a file
function Save:Set(ply, saveName, blockAlert)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Don't save in the middle of a loading
	if MR.Duplicator:IsRunning(ply) or MR.Duplicator:IsStopping() then
		return false
	end

	-- Get the save full path
	local saveFile = saveName and MR.Base:GetSaveFolder()..string.lower(saveName)..".txt" or MR.Base:GetAutoSaveFile()

	-- Create a save table
	local save = {
		decals = MR.Decals:GetList(),
		map = MR.Map:GetList(),
		displacements = MR.Displacements:GetList(),
		skybox = { MR.Skybox:GetList()[1] } ,
		savingFormat = Save:GetCurrentVersion()
	}

	-- Remove all the disabled elements
	MR.DataList:Clean(save.decals)
	MR.DataList:Clean(save.map)
	MR.DataList:Clean(save.displacements)
	MR.DataList:Clean(save.skybox)

	-- Remove the backups
	for _,section in pairs(save) do
		if istable(section) then
			for _,data in pairs(section) do
				data.backup = nil
			end
		end
	end

	-- Save it in a file
	file.Write(saveFile, util.TableToJSON(save, true))

	-- Server alert
	if not blockAlert then
		print("[Map Retexturizer] Saved the current materials as \""..saveName.."\".")
	end

	-- Associate a name with the saved file
	MR.Load:SetOption(saveName, saveFile)

	-- Update the load list on every client
	net.Start("CL.Save:Set_Finish")
		net.WriteString(saveName)
	net.Broadcast()

	return true
end

-- Set autoLoading for the map
function Save:SetAuto(ply, value)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Remove the autoSave timer
	if not value then
		if timer.Exists("MRAutoSave") then
			timer.Remove("MRAutoSave")
		end
	end
 
	-- Apply the change on clients
	MR.SV.Sync:Replicate(ply, "internal_mr_autosave", value and "1" or "0", "save", "box")

	return true
end
