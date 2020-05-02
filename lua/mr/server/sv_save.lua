--------------------------------
--- SAVE
--------------------------------

local Save = {}
Save.__index = Save
MR.Save = Save

-- Networking
util.AddNetworkString("Save:Set_SV")
util.AddNetworkString("Save:Set_CL2")
util.AddNetworkString("Save:SetAuto")

net.Receive("Save:SetAuto", function(_, ply)
	Save:SetAuto(ply, net.ReadBool(value))
end)

net.Receive("Save:Set_SV", function(_, ply)
	Save:Set_SV(ply, net.ReadString())
end)

-- Save the modifications to a file: server
function Save:Set_SV(ply, saveName, blcokAlert)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Don't save in the middle of a loading
	if MR.Duplicator:IsRunning(ply) or MR.Duplicator:IsStopping() then
		return false
	end

	-- Get the save full path
	local saveFile = saveName and MR.Base:GetMapFolder()..saveName..".txt" or MR.Base:GetAutoSaveFile()

	-- Create a save table
	local save = {
		decals = MR.Decals:GetList(),
		map = MR.MapMaterials:GetList(),
		displacements = MR.MapMaterials.Displacements:GetList(),
		skybox = GetConVar("internal_mr_skybox"):GetString(),
		savingFormat = "3.0"
	}

	-- Remove all the disabled elements
	MR.MML:Clean(save.decals)
	MR.MML:Clean(save.map)
	MR.MML:Clean(save.displacements)

	-- Save it in a file
	file.Write(saveFile, util.TableToJSON(save))

	-- Server alert
	if not blcokAlert then
		print("[Map Retexturizer] Saved the current materials as \""..saveName.."\".")
	end

	-- Associate a name with the saved file
	MR.Load:SetOption(saveName, saveFile)

	-- Update the load list on every client
	net.Start("Save:Set_CL2")
		net.WriteString(saveName)
	net.Broadcast()

	return true
end

-- Set autoLoading for the map
function Save:SetAuto(ply, value)
	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Remove the autoSave timer
	if not value then
		if timer.Exists("MRAutoSave") then
			timer.Remove("MRAutoSave")
		end
	end
 
	-- Apply the change on clients
	MR.CVars:Replicate_SV(ply, "internal_mr_autosave", value and "1" or "0", "save", "box")

	return true
end
