-------------------------------------
--- CONCOMMANDS
-------------------------------------

local Concommands = {}
MR.SV.Concommands = Concommands

-- Networking
util.AddNetworkString("SV.Concommands:Run")
util.AddNetworkString("CL.Concommands:PrintDisplacementsHelp")

net.Receive("SV.Concommands:Run", function(_, ply)
	Concommands:Run(ply, net.ReadString(), net.ReadString() or "")
end)

function Concommands:Run(ply, command, value)
	-- Admin only
	if not MR.Ply:IsAllowed(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "[Map Retexturizer] This command is for admins only.")

		return
	end

	RunConsoleCommand(command, value)
end

-- Printing success messages
function Concommands:PrintSuccess(message)
	print(message)

	if GetConVar("mr_notifications"):GetBool() then
		PrintMessage(HUD_PRINTTALK, message)
	end
end

-- Printing fail messages
function Concommands:PrintFail(plyIndex, message)
	print(message)
	if plyIndex then
		for k,v in pairs(player.GetAll()) do
			if tonumber(plyIndex) == v:EntIndex() then
				v:PrintMessage(HUD_PRINTCONSOLE, message)

				break
			end
		end		
	end
end

