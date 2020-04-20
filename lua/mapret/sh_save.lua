--------------------------------
--- SAVE
--------------------------------

-- A table to join all the information about the modified materials to be saved
local save = {
	list = {}
}

Save = {}
Save.__index = Save

function Save:Init()
	if SERVER then return; end

	-- Default save location
	RunConsoleCommand("mapret_savename", Base:GetSaveDefaultName())
end

-- Save the modifications to a file and reload the menu
function Save:Start(ply, forceName)
	if SERVER then return; end

	-- Don't use the tool in the middle of a loading
	if Duplicator:IsRunning(ply) then
		return false
	end

	local saveName = GetConVar("mapret_savename"):GetString()

	if saveName == "" then
		return
	end

	net.Start("MapRetSave")
		net.WriteString(saveName)
	net.SendToServer()
end
function Save:Set(saveName, saveFile)
	if CLIENT then return; end

	-- Don't save in the middle of a loading
	if Duplicator:IsRunning(ply) then
		return false
	end

	-- Create a save table
	save.list[saveName] = {
		decals = Decals:GetList(),
		map = MapMaterials:GetList(),
		displacements = MapMaterials.Displacements:GetList(),
		skybox = GetConVar("mapret_skybox"):GetString(),
		savingFormat = "2.0"
	}

	-- Remove all the disabled elements
	MML:Clean(save.list[saveName].decals)
	MML:Clean(save.list[saveName].map)
	MML:Clean(save.list[saveName].displacements)

	-- Save it in a file
	file.Write(saveFile, util.TableToJSON(save.list[saveName]))

	-- Server alert
	print("[Map Retexturizer] Saved the current materials as \""..saveName.."\".")

	-- Associte a name with the saved file
	Load:Set(saveName, saveFile)

	-- Update the load list on every client
	net.Start("MapRetSaveAddToLoadList")
		net.WriteString(saveName)
	net.Broadcast()
end
if SERVER then
	util.AddNetworkString("MapRetSave")
	util.AddNetworkString("MapRetSaveAddToLoadList")

	net.Receive("MapRetSave", function(_, ply)
		-- Admin only
		if not Utils:PlyIsAdmin(ply) then
			return false
		end

		local saveName = net.ReadString()

		Save:Set(saveName, Base:GetMapFolder()..saveName..".txt")
	end)
end
if CLIENT then
	net.Receive("MapRetSaveAddToLoadList", function()
		local saveName = net.ReadString()
		local saveFile = Base:GetMapFolder()..saveName..".txt"

		if Load:GetList()[saveName] == nil then
			GUI:GetLoadText():AddChoice(saveName)
			Load:Set(saveName, saveFile)
		end
	end)
end

-- Set autoLoading for the map
function Save:Auto_Start(ply, value)
	if SERVER then return; end

	-- Set the autoSave option on every client
	net.Start("MapRetAutoSaveSet")
		net.WriteBool(value)
	net.SendToServer()
end
function Save:Auto_Set(ply, value)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Remove the autoSave timer
	if not value then
		if timer.Exists("MapRetAutoSave") then
			timer.Remove("MapRetAutoSave")
		end
	end
 
	-- Apply the change on clients
	CVars:Replicate(ply, "mapret_autosave", value and "1" or "0", "save", "box")
end
if SERVER then
	util.AddNetworkString("MapRetAutoSaveSet")

	net.Receive("MapRetAutoSaveSet", function(_, ply)
		Save:Auto_Set(ply, net.ReadBool(value))
	end)
end
