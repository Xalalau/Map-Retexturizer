--------------------------------
--- SAVE
--------------------------------

local Save = {}
Save.__index = Save
MR.SV.Save = Save

-- Networking
util.AddNetworkString("CL.Save:Set_Finish")
util.AddNetworkString("SV.Save:Set")
util.AddNetworkString("SV.Save:SetAuto")

net.Receive("SV.Save:SetAuto", function(_, ply)
	Save:SetAuto(ply, net.ReadString(value))
end)

net.Receive("SV.Save:Set", function(_, ply)
	Save:Set(ply, net.ReadString())
end)

-- Save the modifications to a file
function Save:Set(ply, saveName, blockAlert)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		return false
	end

	-- Don't save in the middle of a(n) (un)loading
	if MR.Duplicator:IsRunning(ply) or MR.Duplicator:IsStopping() or MR.Materials:IsRunningProgressiveCleanup() then
		return false
	end

	-- Get the save full path
	local saveFile = saveName and MR.Base:GetSaveFolder()..string.lower(saveName)..".txt" or MR.Base:GetAutoSaveFile()

	-- Create a save table
	local save = MR.DataList:CleanFullLists(table.Copy(MR.DataList:GetCurrentModifications()))

	-- Remove the backups
	MR.DataList:DeleteBackups(save)

	-- Remove models
	save.models = nil

	-- Count modifications
	local total = 0

	if save then
		for listName, list in pairs(save) do
			if listName ~= "savingFormat" then
				total = total + MR.DataList:Count(list)
			end
		end
	end

	if total == 0 then
		print("[Map Retexturizer] No map changes were found.")

		return false
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
	MR.SV.Sync:Replicate(ply, "internal_mr_autosave", value, "save", "box")

	return true
end
