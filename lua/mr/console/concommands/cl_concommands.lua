-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommands = {}
Concommands.__index = Concommands
MR.CL.Concommands = Concommands

-- Run a console command on server
function Concommands:RunOnSV(command, value)
	if MR.Ply:IsAdmin(LocalPlayer()) then
		net.Start("SV.Concommands:Run")
			net.WriteString(command)
			net.WriteString(isstring(value) and value or tostring(value))
		net.SendToServer()
	end
end
