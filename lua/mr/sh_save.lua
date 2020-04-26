--------------------------------
--- SAVE
--------------------------------

local Save = {}
Save.__index = Save
MR.Save = Save

-- A table to join all the information about the modified materials to be saved
local save = {
	list = {}
}

-- Networking
if SERVER then
	util.AddNetworkString("Save:Set_SV")
	util.AddNetworkString("Save:Set_CL2")
	util.AddNetworkString("Save:SetAuto")

	net.Receive("Save:SetAuto", function(_, ply)
		Save:SetAuto(ply, net.ReadBool(value))
	end)

	net.Receive("Save:Set_SV", function(_, ply)
		Save:Set_SV(ply, net.ReadString())
	end)
elseif CLIENT then
	net.Receive("Save:Set_CL2", function()
		Save:Set_CL2(net.ReadString())
	end)
end

function Save:Init()
	if SERVER then return; end

	-- Default save location
	RunConsoleCommand("mr_savename", MR.Base:GetSaveDefaultName())
end

-- Save the modifications to a file: client
function Save:Set_CL(ply)
	if SERVER then return; end

	-- Don't use the tool in the middle of a loading
	if MR.Duplicator:IsRunning(ply) or MR.Duplicator:IsStopping() then
		return false
	end

	-- Send the save name to the sever
	local saveName = GetConVar("mr_savename"):GetString()

	if saveName == "" then
		return
	end

	net.Start("Save:Set_SV")
		net.WriteString(saveName)
	net.SendToServer()
end

-- Save the modifications to a file: server
function Save:Set_SV(ply, saveName)
	if CLIENT then return; end

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
	save.list[saveName] = {
		decals = MR.Decals:GetList(),
		map = MR.MapMaterials:GetList(),
		displacements = MR.MapMaterials.Displacements:GetList(),
		skybox = GetConVar("mr_skybox"):GetString(),
		savingFormat = "2.0"
	}

	-- Remove all the disabled elements
	MR.MML:Clean(save.list[saveName].decals)
	MR.MML:Clean(save.list[saveName].map)
	MR.MML:Clean(save.list[saveName].displacements)

	-- Save it in a file
	file.Write(saveFile, util.TableToJSON(save.list[saveName]))

	-- Server alert
	print("[Map Retexturizer] Saved the current materials as \""..saveName.."\".")

	-- Associate a name with the saved file
	MR.Load:SetOption(saveName, saveFile)

	-- Update the load list on every client
	net.Start("Save:Set_CL2")
		net.WriteString(saveName)
	net.Broadcast()
end

-- Save the modifications to a file: client part 2
function Save:Set_CL2(saveName)
	-- Add the save as an option in the player's menu
	if MR.Load:GetList()[saveName] == nil then
		MR.GUI:GetLoadText():AddChoice(saveName)
		MR.Load:SetOption(saveName, MR.Base:GetMapFolder()..saveName..".txt")
	end
end

-- Set autoLoading for the map
function Save:SetAuto(ply, value)
	if CLIENT then return; end

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
	MR.CVars:Replicate_SV(ply, "mr_autosave", value and "1" or "0", "save", "box")
end
