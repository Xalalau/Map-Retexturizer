-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommands = {}
Concommands.__index = Concommands
MR.SV.Concommands = Concommands

-- Networking
util.AddNetworkString("SV.Concommands:Run")
util.AddNetworkString("CL.Concommands:PrintDisplacementsHelp")

net.Receive("SV.Concommands:Run", function(_, ply)
	Concommands:Run(ply, net.ReadString(), net.ReadString() or "", "@@" .. tostring(ply:EntIndex())) --"@@" is used to help me explode the arguments
end)

-- Printing success messages
function Concommands:PrintSuccess(message)
	print(message)
	PrintMessage(HUD_PRINTTALK, message)
end

-- Printing fail messages
function Concommands:PrintFail(plyIndex, message)
	print(message)
	if plyIndex then
		player.GetAll()[tonumber(plyIndex)]:PrintMessage(HUD_PRINTCONSOLE, message)
	end
end

function Concommands:Run(ply, command, value, plyIndex)
	-- Admin only
	if not MR.Ply:IsAdmin(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "[Map Retexturizer] This command is for admins only.")

		return false
	end

	RunConsoleCommand(command, value, plyIndex)
end

