-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommand = {}
Concommand.__index = Concommand
MR.SV.Concommand = Concommand

-- Networking
util.AddNetworkString("SV.Concommand:Run")

net.Receive("SV.Concommand:Run", function(_, ply)
	Concommand:Run(ply, net.ReadString(), net.ReadString() or "", "@@" .. tostring(ply:EntIndex())) --"@@" is used to help me explode the arguments
end)

-- Printing success messages
function Concommand:PrintSuccess(message)
	print(message)
	PrintMessage(HUD_PRINTTALK, message)
end

-- Printing fail messages
function Concommand:PrintFail(plyIndex, message)
	print(message)
	if plyIndex then
		player.GetAll()[tonumber(plyIndex)]:PrintMessage(HUD_PRINTCONSOLE, message)
	end
end

function Concommand:Run(ply, command, value, plyIndex)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "[Map Retexturizer] This command is for admins only.")

		return false
	end

	RunConsoleCommand(command, value, plyIndex)
end

