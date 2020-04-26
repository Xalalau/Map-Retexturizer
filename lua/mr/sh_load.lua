-------------------------------------
--- LOAD
-------------------------------------

local Load = {}
Load.__index = Load
MR.Load = Load

-- List of save names
local load = {
	list = {}
}

-- Networking
if SERVER then
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
elseif CLIENT then
	net.Receive("Load:SetList", function()
		 Load:SetList(net.ReadTable())
	end)

	net.Receive("Load:Delete_CL2", function()
		Load:Delete_CL2(net.ReadString())
	end)
end

-- First spawn hook
if SERVER then	-- Wait until the player fully loads (https://github.com/Facepunch/garrysmod-requests/issues/718)
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
end

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
		RunConsoleCommand("mr_autoload", value)
		MR.GUI:Set("load", "autoloadtext", value)
	else
		RunConsoleCommand("mr_autoload", "")
	end
end

-- Get the laod list
function Load:GetList()
	return load.list
end

-- Receive the full load list after the first spawn
function Load:SetList(list)
	load.list = list
end

-- Set a new load on the list
function Load:SetOption(saveName, saveFile)
	load.list[saveName] = saveFile
end

-- Print the load list in the console
function Load:PrintList()
	if CLIENT then return; end

	print("----------------------------")
	print("[Map Retexturizer] Saves:")
	print("----------------------------")
	for k,v in pairs(load.list) do
		print(k)
	end
	print("----------------------------")
end

-- Load modifications
function Load:Start(ply, loadName)
	if CLIENT then return; end

	-- General first steps
	MR.Materials:SetFirstSteps(ply)

	-- Check if there is a load name
	if not loadName or loadName == "" then
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

	-- Start the loading
	if loadTable then
		MR.Duplicator:Start(ply, nil, loadTable, loadName)

		return true
	end

	return false
end

-- Load tool modifications BEFORE the player is fully ready
function Load:PlayerJoined(ply)
	if CLIENT then return; end

	-- Set the player load list
	net.Start("Load:SetList")
		net.WriteTable(load.list)
	net.Send(ply)
end

-- Load tool modifications AFTER the player is fully ready
function Load:FirstSpawn(ply)
	if CLIENT then return; end

	-- Index the player control
	MR.Ply:Set(ply)

	-- Start an ongoing load from the beggining
	if MR.Duplicator:IsRunning() then
		Load:Start(ply, MR.Duplicator:IsRunning())
	-- Send the current modifications
	elseif MR.Base:GetInitialized() then
		MR.Duplicator:Start(ply)
	-- Run an autoload
	elseif GetConVar("mr_autoload"):GetString() ~= "" then
		-- Set the spawn as done since The fakeHostPly will take care of this load
		MR.Ply:SetFirstSpawn(ply)
		net.Start("Ply:SetFirstSpawn")
		net.Send(ply)

		Load:Start(MR.Ply:GetFakeHostPly(), GetConVar("mr_autoload"):GetString())
	-- Nothing to send, finish the joining process
	else
		MR.Ply:SetFirstSpawn(ply)
		net.Start("Ply:SetFirstSpawn")
		net.Send(ply)
	end
end

-- Delete a saved file: client
function Load:Delete_CL(ply)
	if SERVER then return; end

	-- Get the load name and check if it's no empty
	local loadName = MR.GUI:GetLoadText():GetSelected()

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
		text:SetText("Are you sure you want to delete "..MR.GUI:GetLoadText():GetSelected().."?")

	local buttonYes = vgui.Create("DButton", qPanel)
		buttonYes:SetPos(24, 50)
		buttonYes:SetText("Yes")
		buttonYes:SetSize(120, 30)
		buttonYes.DoClick = function()
			-- Remove the load on every client
			qPanel:Close()
			net.Start("Load:Delete_SV")
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

-- Delete a saved file: server
function Load:Delete_SV(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
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
	if GetConVar("mr_autoload"):GetString() == loadName then
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

-- Delete a saved file: client part 2
function Load:Delete_CL2(loadName)
	load.list[loadName] = nil
	MR.GUI:GetLoadText():Clear()

	for k,v in pairs(load.list) do
		MR.GUI:GetLoadText():AddChoice(k)
	end
end

-- Set an auto load for the map
function Load:SetAuto(ply, loadName)
	if CLIENT then return; end

	-- Admin only
	if not MR.Utils:PlyIsAdmin(ply) then
		return false
	end

	-- Check if the load name is valid
	if not loadName or not load.list[loadName] and loadName ~= "" then
		return false
	end

	-- Apply the value to every client
	MR.CVars:Replicate_SV(ply, "mr_autoload", loadName, "load", "autoloadtext")

	timer.Create("MRWaitToSave", 0.3, 1, function()
		file.Write(MR.Base:GetAutoLoadFile(), GetConVar("mr_autoload"):GetString())
	end)

	return true
end
