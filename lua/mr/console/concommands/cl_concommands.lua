-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommand = {}
Concommand.__index = Concommand
MR.CL.Concommand = Concommand

-- Run a console command on server
function Concommand:RunOnSV(command, value)
	if MR.Ply:IsAdmin(LocalPlayer()) then
		net.Start("SV.Concommand:Run")
			net.WriteString(command)
			net.WriteString(isstring(value) and value or tostring(value))
		net.SendToServer()
	end
end
