--------------------------------
--- SAVE
--------------------------------

local Save = {}
Save.__index = Save
MR.Save = Save

-- Networking
net.Receive("Save:Set_CL2", function()
	Save:Set_CL2(net.ReadString())
end)

function Save:Init()
	-- Default save location
	RunConsoleCommand("internal_mr_savename", MR.Base:GetSaveDefaultName())
end

-- Save the modifications to a file: client
function Save:Set_CL()
	-- Don't use the tool in the middle of a loading
	if MR.Duplicator:IsRunning(LocalPlayer()) or MR.Duplicator:IsStopping() then
		return false
	end

	-- Send the save name to the sever
	local saveName = GetConVar("internal_mr_savename"):GetString()

	if saveName == "" then
		return
	end

	net.Start("Save:Set_SV")
		net.WriteString(saveName)
	net.SendToServer()
end

-- Save the modifications to a file: client part 2
function Save:Set_CL2(saveName)
	-- Add the save as an option in the player's menu
	if MR.Load:GetList()[saveName] == nil then
		MR.GUI:GetLoadText():AddChoice(saveName)
		MR.Load:SetOption(saveName, MR.Base:GetSaveFolder()..saveName..".txt")
	end
end
