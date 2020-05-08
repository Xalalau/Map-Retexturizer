-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommand = MR.Concommand

-- Run a console command on server
function Concommand:RunOnSV(command, value)
	if MR.Ply:IsAdmin(LocalPlayer()) then
		net.Start("SV.Concommand:Run")
			net.WriteString(command)
			net.WriteString(isstring(value) and value or tostring(value))
		net.SendToServer()
	end
end

-- mr_changeall
concommand.Add("internal_mr_changeall", function ()
	-- Note: this window code is used more than once but I can't put it inside
	-- a function because the buttons never return true or false on time.
	local qPanel = vgui.Create( "DFrame" )
		qPanel:SetTitle("Loading Confirmation")
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
		text:SetText("Are you sure you want to change all the map materials?")

	local buttonYes = vgui.Create("DButton", qPanel)
		buttonYes:SetPos(24, 50)
		buttonYes:SetText("Yes")
		buttonYes:SetSize(120, 30)
		buttonYes.DoClick = function()
			net.Start("SV.Materials:SetAll")
			net.SendToServer()
			qPanel:Close()
		end

	local buttonNo = vgui.Create("DButton", qPanel)
		buttonNo:SetPos(144, 50)
		buttonNo:SetText("No")
		buttonNo:SetSize(120, 30)
		buttonNo.DoClick = function()
			qPanel:Close()
		end
end)
