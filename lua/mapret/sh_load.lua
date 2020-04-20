-------------------------------------
--- LOAD
-------------------------------------

-- List of save names
local load = {
	list = {}
}

Load = {}
Load.__index = Load

function Load:Init()
	if CLIENT then return; end

	-- Fill the load list on the server
	local files = file.Find(MR.Base:GetMapFolder().."*", "Data")

	for k,v in pairs(files) do
		load.list[v:sub(1, -5)] = MR.Base:GetMapFolder()..v
	end

	-- Set the autoLoad command
	local value = file.Read(MR.Base:GetAutoLoadFile(), "Data")

	if value then
		RunConsoleCommand("mapret_autoload", value)
		GUI:Set("load", "autoloadtext", value)
	else
		RunConsoleCommand("mapret_autoload", "")
	end
end

function Load:Set(saveName, saveFile)
	load.list[saveName] = saveFile
end

-- Load modifications
function Load:Start(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Check if there is a load name
	if not loadName or loadName == "" then
		return false
	end

	-- Don't start a loading if we are stopping one
	if Duplicator:IsStopping() then
		return false
	end

	-- Get the load file
	local loadFile = load.list[loadName] or MR.Base:GetMapFolder() .. loadName .. ".txt"

	-- Check if it exists
	if !file.Exists(loadFile, "Data") then
		return false
	end

	-- Get the its contents
	loadTable = util.JSONToTable(file.Read(loadFile, "Data"))

	-- Extra: remove all the disabled elements (Compatibility with the saving format 1.0)
	if not loadTable.savingFormat then
		MML:Clean(loadTable.decals)
		MML:Clean(loadTable.map)
	end

	-- Start the loading
	if loadTable then
		Duplicator:Start(ply, nil, loadTable, loadName)

		return true
	end

	return false
end
if SERVER then
	util.AddNetworkString("MapRetLoad")

	net.Receive("MapRetLoad", function(_, ply)
		Load:Start(Ply:GetFakeHostPly(), net.ReadString())
	end)
end

function Load:GetList()
	return load.list
end

-- Load the server modifications on the first spawn (start)
function Load:FirstSpawn(ply)
	if CLIENT then return; end

	-- Fill up the player load list
	net.Start("MapRetLoadFillList")
		net.WriteTable(load.list)
	net.Send(ply)

	-- Index the player control
	Ply:Set(ply)

	-- Start an ongoing load from the beggining
	if Duplicator:IsRunning() then
		Load:Start(ply, Duplicator:IsRunning())
	-- Send the current modifications
	elseif MR.Base:GetInitialized() then
		Duplicator:Start(ply)
	-- Run an autoload
	elseif GetConVar("mapret_autoload"):GetString() ~= "" then
		Ply:SetFirstSpawn(ply)
		net.Start("MapRetPlyfirstSpawnEnd")
		net.Send(ply)

		Load:Start(Ply:GetFakeHostPly(), GetConVar("mapret_autoload"):GetString())
	-- Nothing to send, finish the joining process
	else
		Ply:SetFirstSpawn(ply)
		net.Start("MapRetPlyfirstSpawnEnd")
		net.Send(ply)
	end
end
if SERVER then
	util.AddNetworkString("MapRetPlyfirstSpawnEnd")

	-- Wait until the player fully loads (https://github.com/Facepunch/garrysmod-requests/issues/718)
	hook.Add("PlayerInitialSpawn", "MapRetPlyfirstSpawn", function(ply)
		hook.Add("SetupMove", ply, function(self, ply, _, cmd)
			if self == ply and not cmd:IsForced() then
				-- Wait just a bit more for players with weaker hardware
				timer.Create("MapRetfirstSpawnApplyDelay"..tostring(ply), 1, 1, function()
					Load:FirstSpawn(ply);
				end)

				hook.Remove("SetupMove",self)
			end
		end)
	end)
elseif CLIENT then
	net.Receive("MapRetPlyfirstSpawnEnd", function()
		Ply:SetFirstSpawn(LocalPlayer())
	end)
end

-- Fill the clients load combobox with saves
function Load:FillList(mr)
	if SERVER then return; end

	GUI:GetLoadText():AddChoice("")

	for k,v in pairs(load.list) do
		GUI:GetLoadText():AddChoice(k)
	end
end
if SERVER then
	util.AddNetworkString("MapRetLoadFillList")
end
if CLIENT then
	net.Receive("MapRetLoadFillList", function()
		load.list = net.ReadTable()
	end)
end

-- Prints the load list in the console
function Load:ShowList()
	if CLIENT then return; end

	print("----------------------------")
	print("[Map Retexturizer] Saves:")
	print("----------------------------")
	for k,v in pairs(load.list) do
		print(k)
	end
	print("----------------------------")
end

-- Delete a saved file and reload the menu
function Load:Delete_Start(ply)
	if SERVER then return; end

	-- Get the load name and check if it's no empty
	local loadName = GUI:GetLoadText():GetSelected()

	if not loadName or loadName == "" then
		return
	end

	-- Ask if the player really wants to delete the file
	-- Note: this window code is used more than once but I can't put it inside
	-- a function because the buttons never return true or false on time.
	local qPanel = vgui.Create("DFrame")
		qPanel:SetTitle("Deletion Confirmation")
		qPanel:SetSize(284, 95)
		qPanel:SetPos(10, 10)
		qPanel:SetDeleteOnClose(true)
		qPanel:SetVisible(true)
		qPanel:SetDraggable(true)
		qPanel:ShowCloseButton(true)
		qPanel:MakePopup(true)
		qPanel:Center()

	local text = vgui.Create("DLabel", qPanel)
		text:SetPos(10, 25)
		text:SetSize(300, 25)
		text:SetText("Are you sure you want to delete "..GUI:GetLoadText():GetSelected().."?")

	local buttonYes = vgui.Create("DButton", qPanel)
		buttonYes:SetPos(24, 50)
		buttonYes:SetText("Yes")
		buttonYes:SetSize(120, 30)
		buttonYes.DoClick = function()
			-- Remove the load on every client
			qPanel:Close()
			net.Start("MapRetLoadDeleteSV")
				net.WriteString(loadName)
			net.SendToServer()
		end

	local buttonNo = vgui.Create("DButton", qPanel)
		buttonNo:SetPos(144, 50)
		buttonNo:SetText("No")
		buttonNo:SetSize(120, 30)
		buttonNo.DoClick = function()
			qPanel:Close()
		end
end
function Load:Delete_Set(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	local loadFile = load.list[loadName]

	-- Check if the file exists
	if loadFile == nil then
		return false
	end

	-- Remove the load entry
	load.list[loadName] = nil

	-- Unset autoload if needed
	if GetConVar("mapret_autoload"):GetString() == loadName then
		Load:Auto_Set(ply, "")
	end

	-- Delete the file
	file.Delete(loadFile)

	-- Updates the load list on every client
	net.Start("MapRetLoadDeleteCL")
		net.WriteString(loadName)
	net.Broadcast()
	
	return true
end
if SERVER then
	util.AddNetworkString("MapRetLoadDeleteSV")
	util.AddNetworkString("MapRetLoadDeleteCL")

	net.Receive("MapRetLoadDeleteSV", function(_, ply)
		Load:Delete_Set(ply, net.ReadString())
	end)
end
if CLIENT then
	net.Receive("MapRetLoadDeleteCL", function()
		local loadName = net.ReadString()

		load.list[loadName] = nil
		GUI:GetLoadText():Clear()

		for k,v in pairs(load.list) do
			GUI:GetLoadText():AddChoice(k)
		end
	end)
end

-- Set autoloading for the map
function Load:Auto_Set(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Check if the load name is valid
	if not loadName or not load.list[loadName] and loadName ~= "" then
		return false
	end

	-- Apply the value to every client
	CVars:Replicate(ply, "mapret_autoload", loadName, "load", "autoloadtext")

	timer.Create("MapRetWaitToSave", 0.3, 1, function()
		file.Write(MR.Base:GetAutoLoadFile(), GetConVar("mapret_autoload"):GetString())
	end)

	return true
end
if SERVER then
	util.AddNetworkString("MapRetAutoLoadSet")

	net.Receive("MapRetAutoLoadSet", function(_, ply)
		Load:Auto_Set(ply, net.ReadString())
	end)
end
