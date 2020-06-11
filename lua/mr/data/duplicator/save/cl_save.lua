--------------------------------
--- SAVE
--------------------------------

local Save = {}
Save.__index = Save
MR.CL.Save = Save

-- Networking
net.Receive("CL.Save:Set_Finish", function()
	Save:Set_Finish(net.ReadString())
end)

function Save:Init()
	-- Default save location
	RunConsoleCommand("internal_mr_savename", MR.Base:GetSaveDefaultName())
end

-- Save the modifications to a file: client
function Save:Set()
	-- Don't use the tool in the middle of a loading
	if MR.Duplicator:IsRunning(LocalPlayer()) or MR.Duplicator:IsStopping() then
		return false
	end

	-- Send the save name to the sever
	local saveName = GetConVar("internal_mr_savename"):GetString()

	if saveName == "" then
		return
	end

	net.Start("SV.Save:Set")
		net.WriteString(saveName)
	net.SendToServer()
end

-- Save the modifications to a file: client part 2
function Save:Set_Finish(saveName)
	-- Add the save as an option in the player's menu
	if MR.Load:GetList()[saveName] == nil then
		loadList = MR.CL.CPanel:GetLoadText()
		if loadList and not isstring(loadList) and IsValid(loadList) then
			loadList:AddLine(saveName)
			loadList:SortByColumn(1)
		end

		MR.Load:SetOption(saveName, MR.Base:GetSaveFolder()..saveName..".txt")
	end
end
