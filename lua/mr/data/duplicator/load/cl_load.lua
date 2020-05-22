-------------------------------------
--- LOAD
-------------------------------------

local Load = {}
Load.__index = Load
MR.CL.Load = Load

net.Receive("CL.Load:Delete_Finish", function()
	Load:Delete_Finish(net.ReadString())
end)

-- Delete a saved file: client
function Load:Delete(loadName)
	if not loadName or loadName == "" then
		return
	end

	-- Ask if the player really wants to delete the file
	-- Note: this window code is used more than once but I can't put it inside
	-- a function because the buttons never return true or false on time.
	local qPanel = vgui.Create("DFrame")
		qPanel:SetTitle("Deletion Confirmation")
		qPanel:SetSize(285, 110)
		qPanel:SetPos(10, 10)
		qPanel:SetDeleteOnClose(true)
		qPanel:SetVisible(true)
		qPanel:SetDraggable(true)
		qPanel:ShowCloseButton(true)
		qPanel:MakePopup(true)
		qPanel:Center()

	local text = vgui.Create("DLabel", qPanel)
		text:SetPos(40, 25)
		text:SetSize(275, 25)
		text:SetText("Are you sure you want to delete this file?")

	local panel = vgui.Create("DPanel", qPanel)
		panel:SetPos(5, 50)
		panel:SetSize(275, 20)
		panel:SetBackgroundColor(MR.CL.GUI:GetFrameBackgroundColor())

	local save = vgui.Create("DLabel", panel)
		save:SetPos(10, -2)
		save:SetSize(275, 25)
		save:SetText(MR.CL.CPanel:GetLoadText(true))
		save:SetTextColor(Color(0, 0, 0, 255))

	local buttonYes = vgui.Create("DButton", qPanel)
		buttonYes:SetPos(22, 75)
		buttonYes:SetText("Yes")
		buttonYes:SetSize(120, 30)
		buttonYes.DoClick = function()
			-- Remove the load on every client
			qPanel:Close()
			net.Start("SV.Load:Delete")
				net.WriteString(loadName)
			net.SendToServer()
		end

	local buttonNo = vgui.Create("DButton", qPanel)
		buttonNo:SetPos(146, 75)
		buttonNo:SetText("No")
		buttonNo:SetSize(120, 30)
		buttonNo.DoClick = function()
			qPanel:Close()
		end
end

-- Delete a saved file: client part 2
function Load:Delete_Finish(loadName)
	MR.Load:SetOption(loadName, nil)
	MR.CL.CPanel:GetLoadText():Clear()

	for k,v in pairs(MR.Load:GetList()) do
		MR.CL.CPanel:GetLoadText():AddLine(k)
	end

	MR.CL.CPanel:GetLoadText():SortByColumn(1)
end
